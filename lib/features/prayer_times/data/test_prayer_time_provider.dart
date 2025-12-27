import '../../../core/interfaces/prayer_time_provider.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/location.dart';

class TestPrayerTimeProvider implements PrayerTimeProvider {
  @override
  String get providerName => 'Test Provider (Hard-coded)';

  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final List<PrayerTime> times = [];
    DateTime currentDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

    while (currentDate.isBefore(normalizedEnd.add(const Duration(days: 1)))) {
      times.add(_generateTestPrayerTime(currentDate));
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return times;
  }

  @override
  Future<PrayerTime?> fetchDailyPrayerTime({
    required Location location,
    required DateTime date,
  }) async {
    return _generateTestPrayerTime(date);
  }

  PrayerTime _generateTestPrayerTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);

    final baseDate = DateTime(
      normalizedDate.year,
      normalizedDate.month,
      normalizedDate.day,
    );

    // For today: use dynamic times from now
    // For future dates: use times from midnight of that day
    final referenceTime = normalizedDate.isAtSameMomentAs(today)
        ? now
        : baseDate;

    final minutesFromNow = 15;
    final fajr = referenceTime.add(Duration(minutes: minutesFromNow));
    final sunrise = referenceTime.add(Duration(minutes: minutesFromNow + 15));
    final dhuhr = referenceTime.add(Duration(minutes: minutesFromNow + 30));
    final asr = referenceTime.add(Duration(minutes: minutesFromNow + 45));
    final maghrib = referenceTime.add(Duration(minutes: minutesFromNow + 60));
    final isha = referenceTime.add(Duration(minutes: minutesFromNow + 75));

    return PrayerTime(
      fajr: fajr,
      sunrise: sunrise,
      dhuhr: dhuhr,
      asr: asr,
      maghrib: maghrib,
      isha: isha,
      date: baseDate,
    );
  }
}
