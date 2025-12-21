import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/interfaces/prayer_time_provider.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/location.dart';

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
    final List<PrayerTime> prayerTimes = [];

    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      final prayerTime = await fetchDailyPrayerTime(
        location: location,
        date: currentDate,
      );
      if (prayerTime != null) {
        prayerTimes.add(prayerTime);
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
    } catch (e) {
      return null;
    }
  }

  DateTime _parseTime(String time, DateTime date) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
