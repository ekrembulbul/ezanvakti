import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/interfaces/prayer_time_provider.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/location.dart';
import '../../../core/exceptions/parse_exception.dart';
import '../../../core/utils/app_logger.dart';

class AwqatSalahProvider implements PrayerTimeProvider {
  final http.Client httpClient;
  static const String baseUrl = 'https://api.aladhan.com/v1';

  AwqatSalahProvider({http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

  @override
  String get providerName => 'Diyanet (Awqat Salah)';

  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final logger = AppLogger();
    final List<PrayerTime> prayerTimes = [];

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      try {
        final prayerTime = await fetchDailyPrayerTime(
          location: location,
          date: currentDate,
        );
        if (prayerTime != null) {
          prayerTimes.add(prayerTime);
        }
      } on ParseException catch (e) {
        logger.warning(
          'Skipping date ${currentDate.toIso8601String()} due to parse error',
          e,
        );
      } catch (e) {
        logger.warning(
          'Skipping date ${currentDate.toIso8601String()} due to error',
          e,
        );
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return prayerTimes;
  }

  @override
  Future<PrayerTime?> fetchDailyPrayerTime({
    required Location location,
    required DateTime date,
  }) async {
    final logger = AppLogger();
    try {
      final timestamp = date.millisecondsSinceEpoch ~/ 1000;

      final uri = Uri.parse(
        '$baseUrl/timings/$timestamp?latitude=${location.latitude}&longitude=${location.longitude}&method=13',
      );

      final response = await httpClient.get(uri);

      if (response.statusCode != 200) {
        throw Exception('API error: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final timings = data['data']['timings'] as Map<String, dynamic>;

      final normalizedDate = DateTime(date.year, date.month, date.day);

      return PrayerTime(
        fajr: _parseTime(timings['Fajr'] as String, normalizedDate),
        sunrise: _parseTime(timings['Sunrise'] as String, normalizedDate),
        dhuhr: _parseTime(timings['Dhuhr'] as String, normalizedDate),
        asr: _parseTime(timings['Asr'] as String, normalizedDate),
        maghrib: _parseTime(timings['Maghrib'] as String, normalizedDate),
        isha: _parseTime(timings['Isha'] as String, normalizedDate),
        date: normalizedDate,
      );
    } on FormatException catch (e, stackTrace) {
      logger.parseError(
        context: 'AwqatSalahProvider.fetchDailyPrayerTime - JSON parsing',
        error: e,
        stackTrace: stackTrace,
        additionalData: {
          'location': location.toJson(),
          'date': date.toIso8601String(),
        },
      );
      throw ParseException(
        message: 'Failed to parse API response',
        originalError: e,
        stackTrace: stackTrace,
        context: 'AwqatSalahProvider.fetchDailyPrayerTime',
      );
    } on TypeError catch (e, stackTrace) {
      logger.parseError(
        context: 'AwqatSalahProvider.fetchDailyPrayerTime - Type casting',
        error: e,
        stackTrace: stackTrace,
        additionalData: {
          'location': location.toJson(),
          'date': date.toIso8601String(),
        },
      );
      throw ParseException(
        message: 'API response structure has changed',
        originalError: e,
        stackTrace: stackTrace,
        context: 'AwqatSalahProvider.fetchDailyPrayerTime',
      );
    } catch (e, stackTrace) {
      logger.error(
        'Unexpected error in AwqatSalahProvider.fetchDailyPrayerTime',
        e,
        stackTrace,
      );
      return null;
    }
  }

  DateTime _parseTime(String time, DateTime date) {
    try {
      final parts = time.split(':');
      if (parts.length < 2) {
        throw FormatException('Invalid time format: $time');
      }
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e, stackTrace) {
      final logger = AppLogger();
      logger.parseError(
        context: 'AwqatSalahProvider._parseTime',
        error: e,
        stackTrace: stackTrace,
        additionalData: {'time': time, 'date': date.toIso8601String()},
      );
      throw ParseException(
        message: 'Failed to parse time string',
        originalError: e,
        stackTrace: stackTrace,
        context: '_parseTime',
      );
    }
  }
}
