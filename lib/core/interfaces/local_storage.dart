import '../models/prayer_time.dart';
import '../models/location.dart';
import '../models/notification_setting.dart';

abstract class LocalStorage {
  Future<void> init();

  Future<void> savePrayerTimes(List<PrayerTime> prayerTimes, String locationId);

  Future<List<PrayerTime>> getPrayerTimes({
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<PrayerTime?> getDailyPrayerTime({
    required String locationId,
    required DateTime date,
  });

  Future<void> deleteOldPrayerTimes(DateTime cutoffDate);

  Future<void> saveActiveLocation(Location location);

  Future<Location?> getActiveLocation();

  Future<List<Location>> getSavedLocations();

  Future<void> saveLocation(Location location);

  Future<void> updateLocation(Location location);

  Future<void> deleteLocation(String locationId);

  Future<void> saveNotificationSettings(List<NotificationSetting> settings);

  Future<List<NotificationSetting>> getNotificationSettings();

  Future<void> saveLastUpdateTime(DateTime time);

  Future<DateTime?> getLastUpdateTime();
}
