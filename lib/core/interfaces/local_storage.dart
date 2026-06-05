import '../models/prayer_time.dart';
import '../models/location.dart';
import '../models/notification_setting.dart';
import '../models/calculation_settings.dart';

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

  /// Belirli bir konumun önbellekteki tüm vakitlerini siler. Hesaplama
  /// yöntemi/mezhebi değişince eski (artık geçersiz) vakitleri temizlemek için.
  Future<void> deletePrayerTimesForLocation(String locationId);

  /// Tüm konumların önbellekteki vakitlerini siler. Global hesaplama ayarı
  /// değişince (tüm "inherit" konumları etkiler) kullanılır.
  Future<void> deleteAllPrayerTimes();

  /// Uygulama genelindeki varsayılan hesaplama ayarını döner.
  Future<CalculationSettings> getCalculationSettings();

  /// Uygulama genelindeki varsayılan hesaplama ayarını kaydeder.
  Future<void> saveCalculationSettings(CalculationSettings settings);

  Future<void> saveActiveLocation(Location location);

  Future<Location?> getActiveLocation();

  Future<List<Location>> getSavedLocations();

  Future<void> saveLocation(Location location);

  Future<void> updateLocation(Location location);

  Future<void> deleteLocation(String locationId);

  Future<void> saveNotificationSettings(List<NotificationSetting> settings);

  Future<List<NotificationSetting>> getNotificationSettings();

  Future<void> addNotificationSetting(NotificationSetting setting);

  Future<void> deleteNotificationSetting({
    required PrayerType prayerType,
    required int minutesBefore,
  });

  /// Varsayılan bildirimlerin daha önce bir kez oluşturulup oluşturulmadığını
  /// döner. Kullanıcı sonradan tüm bildirimleri silse bile varsayılanların
  /// yeniden üretilmemesi için kullanılır.
  Future<bool> isNotificationDefaultsInitialized();

  /// Varsayılan bildirimlerin oluşturulduğunu kalıcı olarak işaretler.
  Future<void> markNotificationDefaultsInitialized();

  Future<void> saveLastUpdateTime(DateTime time);

  Future<DateTime?> getLastUpdateTime();
}
