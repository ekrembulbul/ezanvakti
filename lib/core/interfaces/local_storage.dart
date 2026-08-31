import '../models/prayer_time.dart';
import '../models/location.dart';
import '../models/notification_setting.dart';
import '../models/calculation_settings.dart';
import '../models/appearance_settings.dart';
import '../models/general_settings.dart';
import '../models/prayer_log.dart';
import '../models/quiet_window.dart';
import '../models/abort_state.dart';
import '../models/mission_session.dart';
import '../models/alarm.dart';
import '../models/qr_code_entry.dart';
import '../models/skipped_occurrence.dart';

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

  /// [from]–[to] arasındaki namaz kayıtları; anahtar `prayerLogKey` biçiminde.
  Future<Map<String, PrayerStatus>> getPrayerLog(DateTime from, DateTime to);

  /// Tek bir kaydı yazar; [status] null ise kaydı siler.
  Future<void> setPrayerLog(
    DateTime date,
    PrayerType prayerType,
    PrayerStatus? status,
  );

  /// Vakit başına kaza sayıları; kayıt yoksa boş map.
  Future<Map<PrayerType, int>> getQadaCounts();

  Future<void> setQadaCount(PrayerType prayerType, int count);

  /// O günün zikir sayacı; kayıt yoksa 0.
  Future<int> getDhikrCount(DateTime date);

  Future<void> setDhikrCount(DateTime date, int count);

  /// Sessiz pencereler; kayıt yoksa boş liste.
  Future<List<QuietWindow>> getQuietWindows();

  /// Pencere listesinin tamamını değiştirir.
  Future<void> saveQuietWindows(List<QuietWindow> windows);

  /// Genel tercihler (saat biçimi, otomatik konum); kayıt yoksa varsayılanlar.
  Future<GeneralSettings> getGeneralSettings();

  Future<void> saveGeneralSettings(GeneralSettings settings);

  /// Görünüm tercihlerini döner; kayıt yoksa [AppearanceSettings] varsayılanları.
  Future<AppearanceSettings> getAppearanceSettings();

  /// Görünüm tercihlerini `settings` tablosuna yazar.
  Future<void> saveAppearanceSettings(AppearanceSettings settings);

  Future<void> saveActiveLocation(Location location);

  Future<Location?> getActiveLocation();

  Future<List<Location>> getSavedLocations();

  Future<void> saveLocation(Location location);

  Future<void> updateLocation(Location location);

  Future<void> deleteLocation(String locationId);

  Future<void> saveNotificationSettings(List<NotificationSetting> settings);

  Future<List<NotificationSetting>> getNotificationSettings();

  Future<void> addNotificationSetting(NotificationSetting setting);

  /// [weekdays] kimliğin parçası (CSV, boş = her gün); aynı vakit ve sapmada
  /// birden fazla satır olabildiği için gerekli.
  Future<void> deleteNotificationSetting({
    required PrayerType prayerType,
    required int minutesBefore,
    String weekdays = '',
    String derivedKind = '',
  });

  /// Varsayılan bildirimlerin daha önce bir kez oluşturulup oluşturulmadığını
  /// döner. Kullanıcı sonradan tüm bildirimleri silse bile varsayılanların
  /// yeniden üretilmemesi için kullanılır.
  Future<bool> isNotificationDefaultsInitialized();

  /// Varsayılan bildirimlerin oluşturulduğunu kalıcı olarak işaretler.
  Future<void> markNotificationDefaultsInitialized();

  Future<void> saveLastUpdateTime(DateTime time);

  Future<DateTime?> getLastUpdateTime();

  /// "Yalnızca bu sefer" atlanmış bildirim/alarm örnekleri.
  ///
  /// `settings` tablosunda tek anahtarda JSON liste olarak tutulur; aynı anda
  /// en fazla birkaç kayıt olduğu için ayrı tablo açılmadı.
  Future<List<SkippedOccurrence>> getSkippedOccurrences();

  /// Atlama listesinin tamamını değiştirir.
  Future<void> saveSkippedOccurrences(List<SkippedOccurrence> occurrences);

  /// Kayıtlı tüm alarmları döner.
  Future<List<Alarm>> getAlarms();

  /// Alarmı ekler veya (aynı id ise) günceller.
  Future<void> saveAlarm(Alarm alarm);

  /// Alarmı id'sine göre siler.
  Future<void> deleteAlarm(String id);

  /// Çalan alarmın görev oturumu. Aynı anda en fazla bir tane olduğu için
  /// `settings` tablosunda tek anahtarda JSON olarak tutulur.
  Future<MissionSession?> getMissionSession();

  /// Oturumu yazar; `null` verilirse kaydı siler.
  Future<void> saveMissionSession(MissionSession? session);

  /// Kayıtlı QR kodları, en yeni önce.
  Future<List<QrCodeEntry>> getQrCodes();

  /// Ekler veya (aynı id ise) günceller.
  Future<void> saveQrCode(QrCodeEntry entry);

  Future<void> deleteQrCode(String id);

  /// Son planlamada kurulamayan alarmlar: alarmId → kısa hata mesajı.
  /// Arayüz satırda "Kurulamadı" uyarısını buradan gösterir.
  Future<Map<String, String>> getAlarmScheduleFailures();

  /// Kaydın tamamını değiştirir; boş map kaydı siler.
  Future<void> saveAlarmScheduleFailures(Map<String, String> failures);

  /// Acil çıkışın global kademesi. Kayıt yoksa sıfır kademe döner.
  Future<AbortState> getAbortState();

  Future<void> saveAbortState(AbortState state);
}
