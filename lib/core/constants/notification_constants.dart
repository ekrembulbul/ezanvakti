import '../models/notification_setting.dart';

class NotificationConstants {
  static const Map<PrayerType, int> maxMinutesBefore = {
    PrayerType.fajr: 240,
    PrayerType.sunrise: 75,
    PrayerType.dhuhr: 240,
    PrayerType.asr: 120,
    PrayerType.maghrib: 120,
    PrayerType.isha: 60,
  };

  static const int defaultMaxMinutesBefore = 240;

  static int getMaxMinutesBefore(PrayerType prayerType) {
    return maxMinutesBefore[prayerType] ?? defaultMaxMinutesBefore;
  }
}
