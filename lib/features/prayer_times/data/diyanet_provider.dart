import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/vakit_api_config.dart';
import '../../../core/exceptions/api_exception.dart';
import '../../../core/exceptions/parse_exception.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/interfaces/prayer_time_provider.dart';
import '../../../core/models/hijri_date.dart';
import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/utils/app_logger.dart';

/// Konum henüz bir Diyanet ilçesine bağlanmadı (eski kayıt, migrasyon bekliyor).
class LocationNotMappedException implements Exception {
  final String locationId;
  LocationNotMappedException(this.locationId);
  @override
  String toString() => 'LocationNotMappedException: $locationId has no cityId';
}

/// vakit-api `/v1/prayer-times/{cityId}/{year}` sağlayıcısı.
///
/// Yılın tamamını döner; depo hepsini önbelleğe yazıp istenen pencereyi
/// keser. ETag saklanır; 304'te yıl önbellekten okunur, ağdan gövde inmez.
/// Vakitler yerel duvar saati olarak cihaz saat diliminde kurulur (Türkiye
/// tek dilim; `gmtOffset` şimdilik kullanılmaz).
class DiyanetProvider implements PrayerTimeProvider {
  final http.Client client;
  final LocalStorage storage;
  final String baseUrl;

  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxAttempts = 3;
  static const Duration _baseBackoff = Duration(seconds: 1);

  DiyanetProvider({
    required this.client,
    required this.storage,
    this.baseUrl = VakitApiConfig.baseUrl,
  });

  @override
  String get providerName => 'Diyanet (vakit-api)';

  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final cityId = location.cityId;
    if (cityId == null) throw LocationNotMappedException(location.id);
    final result = <PrayerTime>[];
    for (var year = startDate.year; year <= endDate.year; year++) {
      result.addAll(await _fetchYear(location, cityId, year));
    }
    return result;
  }

  @override
  Future<PrayerTime?> fetchDailyPrayerTime({
    required Location location,
    required DateTime date,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final times = await fetchPrayerTimes(
      location: location,
      startDate: day,
      endDate: day,
    );
    for (final t in times) {
      if (t.date.year == day.year &&
          t.date.month == day.month &&
          t.date.day == day.day) {
        return t;
      }
    }
    return null;
  }

  Future<List<PrayerTime>> _fetchYear(
    Location location,
    int cityId,
    int year,
  ) async {
    final logger = AppLogger();
    final uri = Uri.parse('$baseUrl/v1/prayer-times/$cityId/$year');
    final etagKey = 'etag:$cityId:$year';
    final headers = <String, String>{'Accept': 'application/json'};
    final etag = await storage.getSetting(etagKey);
    if (etag != null) headers['If-None-Match'] = etag;

    http.Response response;
    for (var attempt = 1; ; attempt++) {
      response = await client.get(uri, headers: headers).timeout(_timeout);
      final transient =
          response.statusCode == 429 || response.statusCode >= 500;
      if (!transient || attempt >= _maxAttempts) break;
      final wait = _baseBackoff * (1 << (attempt - 1));
      logger.warning(
        'vakit-api HTTP ${response.statusCode}; retry $attempt in ${wait.inSeconds}s',
      );
      await Future<void>.delayed(wait);
    }

    switch (response.statusCode) {
      case 200:
        final days = _parseYear(response, year);
        final newEtag = response.headers['etag'];
        if (newEtag != null && newEtag.isNotEmpty) {
          await storage.setSetting(etagKey, newEtag);
        }
        return days;
      case 304:
        logger.debug('vakit-api $cityId/$year unchanged; using cache');
        return storage.getPrayerTimes(
          locationId: location.id,
          startDate: DateTime(year, 1, 1),
          endDate: DateTime(year, 12, 31),
        );
      case 404:
        logger.info('vakit-api $cityId/$year not published yet');
        return const [];
      default:
        throw ApiException(response.statusCode, context: 'GET ${uri.path}');
    }
  }

  List<PrayerTime> _parseYear(http.Response response, int year) {
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('not an object');
      }
      final days = decoded['days'];
      if (days is! List) throw const FormatException('days missing');
      return days
          .map((raw) => _parseDay(raw as Map<String, dynamic>))
          .toList(growable: false);
    } on FormatException catch (e, stackTrace) {
      AppLogger().parseError(
        context: 'DiyanetProvider._parseYear',
        error: e,
        stackTrace: stackTrace,
        additionalData: {'year': year},
      );
      throw ParseException(
        message: 'vakit-api year payload is malformed',
        originalError: e,
        stackTrace: stackTrace,
        context: 'DiyanetProvider._parseYear',
      );
    } on TypeError catch (e, stackTrace) {
      AppLogger().parseError(
        context: 'DiyanetProvider._parseYear',
        error: e,
        stackTrace: stackTrace,
        additionalData: {'year': year},
      );
      throw ParseException(
        message: 'vakit-api year payload has unexpected types',
        originalError: e,
        stackTrace: stackTrace,
        context: 'DiyanetProvider._parseYear',
      );
    }
  }

  static PrayerTime _parseDay(Map<String, dynamic> raw) {
    final dateParts = (raw['date'] as String).split('-');
    if (dateParts.length != 3) throw FormatException('bad date ${raw['date']}');
    final date = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    DateTime clock(String key) {
      final parts = (raw[key] as String).split(':');
      if (parts.length < 2) {
        throw FormatException('bad clock $key=${raw[key]}');
      }
      return DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    final hijriRaw = raw['hijri'];
    return PrayerTime(
      date: date,
      fajr: clock('fajr'),
      sunrise: clock('sunrise'),
      dhuhr: clock('dhuhr'),
      asr: clock('asr'),
      maghrib: clock('maghrib'),
      isha: clock('isha'),
      hijri: hijriRaw is Map<String, dynamic>
          ? HijriDate.fromJson(hijriRaw)
          : null,
    );
  }
}
