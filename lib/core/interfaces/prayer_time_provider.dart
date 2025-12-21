import '../models/prayer_time.dart';
import '../models/location.dart';

abstract class PrayerTimeProvider {
  String get providerName;

  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<PrayerTime?> fetchDailyPrayerTime({
    required Location location,
    required DateTime date,
  });
}
