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
  static const Duration _requestTimeout = Duration(seconds: 15);

  AwqatSalahProvider({http.Client? httpClient})
    : httpClient = httpClient ?? http.Client();

  @override
  String get providerName => 'Diyanet (Awqat Salah)';

  /// Konuma özel hesaplama parametrelerini Aladhan sorgu parçasına çevirir:
  /// method (otorite), school (İkindi mezhebi) ve varsa yüksek enlem düzeltmesi.
  String _calculationParams(Location location) {
    final buffer = StringBuffer(
      'method=${location.method}&school=${location.school}',
    );
    final latitudeAdjustment = location.latitudeAdjustmentMethod;
    if (latitudeAdjustment != null) {
      buffer.write('&latitudeAdjustmentMethod=$latitudeAdjustment');
    }
    return buffer.toString();
  }

  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final logger = AppLogger();

    final daysDiff = endDate.difference(startDate).inDays;

    if (daysDiff >= 7) {
      try {
        return await _fetchMonthlyPrayerTimes(
          location: location,
          startDate: startDate,
          endDate: endDate,
        );
      } catch (e) {
        logger.warning(
          'Calendar endpoint failed, falling back to daily (max 7 days)',
          e,
        );
        final limitedEndDate = startDate.add(const Duration(days: 6));
        final actualEndDate = endDate.isBefore(limitedEndDate)
            ? endDate
            : limitedEndDate;
        return await _fetchDailyPrayerTimes(
          location: location,
          startDate: startDate,
          endDate: actualEndDate,
        );
      }
    }

    return await _fetchDailyPrayerTimes(
      location: location,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<PrayerTime>> _fetchDailyPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final logger = AppLogger();
    final dayCount = endDate.difference(startDate).inDays + 1;
    logger.debug(
      'Fetching $dayCount days using DAILY endpoint (${startDate.toIso8601String().split('T')[0]} to ${endDate.toIso8601String().split('T')[0]})',
    );

    final List<PrayerTime> prayerTimes = [];

    DateTime currentDate = startDate;
    bool isFirstRequest = true;

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

      if (!isFirstRequest) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      isFirstRequest = false;
      currentDate = currentDate.add(const Duration(days: 1));
    }

    logger.debug('Daily fetch completed: ${prayerTimes.length} days retrieved');
    return prayerTimes;
  }

  Future<List<PrayerTime>> _fetchMonthlyPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final logger = AppLogger();
    final dayCount = endDate.difference(startDate).inDays + 1;
    logger.debug(
      'Fetching $dayCount days using CALENDAR endpoint (${startDate.toIso8601String().split('T')[0]} to ${endDate.toIso8601String().split('T')[0]})',
    );

    final List<PrayerTime> allPrayerTimes = [];

    DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);
    final endMonth = DateTime(endDate.year, endDate.month, 1);

    while (currentMonth.isBefore(endMonth) ||
        currentMonth.isAtSameMomentAs(endMonth)) {
      try {
        final uri = Uri.parse(
          '$baseUrl/calendar?latitude=${location.latitude}&longitude=${location.longitude}&${_calculationParams(location)}&month=${currentMonth.month}&year=${currentMonth.year}',
        );

        final response = await httpClient.get(uri).timeout(_requestTimeout);

        if (response.statusCode != 200) {
          throw Exception('API error: ${response.statusCode}');
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final daysData = data['data'] as List<dynamic>;

        for (final dayData in daysData) {
          final timings = dayData['timings'] as Map<String, dynamic>;
          final dateInfo = dayData['date']['gregorian'] as Map<String, dynamic>;

          final day = int.parse(dateInfo['day'] as String);
          final month = int.parse(dateInfo['month']['number'].toString());
          final year = int.parse(dateInfo['year'] as String);

          final date = DateTime(year, month, day);

          if (date.isBefore(startDate) || date.isAfter(endDate)) {
            continue;
          }

          final prayerTime = PrayerTime(
            fajr: _parseTime(timings['Fajr'] as String, date),
            sunrise: _parseTime(timings['Sunrise'] as String, date),
            dhuhr: _parseTime(timings['Dhuhr'] as String, date),
            asr: _parseTime(timings['Asr'] as String, date),
            maghrib: _parseTime(timings['Maghrib'] as String, date),
            isha: _parseTime(timings['Isha'] as String, date),
            date: date,
          );

          allPrayerTimes.add(prayerTime);
        }
      } on FormatException catch (e, stackTrace) {
        logger.parseError(
          context: 'AwqatSalahProvider._fetchMonthlyPrayerTimes - JSON parsing',
          error: e,
          stackTrace: stackTrace,
          additionalData: {
            'location': location.toJson(),
            'month': currentMonth.month,
            'year': currentMonth.year,
          },
        );
        throw ParseException(
          message: 'Failed to parse calendar API response',
          originalError: e,
          stackTrace: stackTrace,
          context: 'AwqatSalahProvider._fetchMonthlyPrayerTimes',
        );
      } on TypeError catch (e, stackTrace) {
        logger.parseError(
          context: 'AwqatSalahProvider._fetchMonthlyPrayerTimes - Type casting',
          error: e,
          stackTrace: stackTrace,
          additionalData: {
            'location': location.toJson(),
            'month': currentMonth.month,
            'year': currentMonth.year,
          },
        );
        throw ParseException(
          message: 'Calendar API response structure has changed',
          originalError: e,
          stackTrace: stackTrace,
          context: 'AwqatSalahProvider._fetchMonthlyPrayerTimes',
        );
      }

      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    logger.debug(
      'Calendar fetch completed: ${allPrayerTimes.length} days retrieved',
    );
    return allPrayerTimes;
  }

  @override
  Future<PrayerTime?> fetchDailyPrayerTime({
    required Location location,
    required DateTime date,
  }) async {
    final logger = AppLogger();
    logger.debug(
      'Fetching single day via DAILY endpoint for ${date.toIso8601String().split('T')[0]}',
    );
    try {
      final timestamp = date.millisecondsSinceEpoch ~/ 1000;

      final uri = Uri.parse(
        '$baseUrl/timings/$timestamp?latitude=${location.latitude}&longitude=${location.longitude}&${_calculationParams(location)}',
      );

      final response = await httpClient.get(uri).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw Exception('API error: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final dataField = data['data'] as Map<String, dynamic>?;
      final timings = dataField?['timings'] as Map<String, dynamic>?;
      if (timings == null) {
        throw const FormatException(
          'Missing "data.timings" field in API response',
        );
      }

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
    } on ParseException {
      // Parse failures (e.g. from _parseTime) must surface so the batch fetch
      // can skip the day; never swallowed into a null result.
      rethrow;
    } catch (e, stackTrace) {
      // Network/timeout/HTTP errors return null so the repository can fall
      // back to cached data instead of crashing.
      logger.error(
        'Network error in AwqatSalahProvider.fetchDailyPrayerTime',
        e,
        stackTrace,
      );
      return null;
    }
  }

  DateTime _parseTime(String time, DateTime date) {
    try {
      String cleanTime = time.trim();
      if (cleanTime.contains(' ')) {
        cleanTime = cleanTime.split(' ')[0];
      }

      final parts = cleanTime.split(':');
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
