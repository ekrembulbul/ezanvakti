import '../../core/interfaces/notification_service.dart';
import '../../core/models/location.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../core/utils/app_logger.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../features/prayer_times/domain/prayer_times_repository.dart';

/// Ana ekranın ihtiyaç duyduğu her şey tek yüklemede.
typedef PrayerData = ({
  PrayerTime? today,
  PrayerTime? tomorrow,
  List<PrayerTime> all,
  DateTime? lastUpdate,
  bool hasPermission,
  List<NotificationSetting> settings,
});

class DataLoaderService {
  /// Bugünden önce çekilen gün sayısı. Gece yarısı/timezone kenar durumları
  /// ve "dünün vakitleri" için küçük bir tampon.
  static const int _daysBefore = 2;

  /// Bugünden sonra çekilen gün sayısı. Bildirim planlama penceresini
  /// (NotificationScheduler.scheduleDaysAhead = 7 gün) tamponuyla kapsamalıdır;
  /// aksi halde ileri tarihli bildirimler için veri bulunamaz.
  static const int _daysAfter = 10;

  final PrayerTimesRepository _prayerTimesRepository;
  final NotificationService _notificationService;
  final NotificationSettingsManager _settingsManager;
  final AppLogger _logger;

  DataLoaderService({
    required PrayerTimesRepository prayerTimesRepository,
    required NotificationService notificationService,
    required NotificationSettingsManager settingsManager,
    required AppLogger logger,
  }) : _prayerTimesRepository = prayerTimesRepository,
       _notificationService = notificationService,
       _settingsManager = settingsManager,
       _logger = logger;

  /// Tek aralık çağrısıyla pencerenin tamamını çeker ve bugün/yarın'ı bu
  /// listeden türetir. Ayrı bir "bugün" isteği atılmaz: aralık çağrısı zaten
  /// bugünü de kapsıyor ve iki tur ağ trafiği rate-limit baskısını artırıyordu.
  Future<PrayerData> loadPrayerData(
    Location location, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    final all = await _prayerTimesRepository.getPrayerTimes(
      location: location,
      startDate: todayDate.subtract(const Duration(days: _daysBefore)),
      endDate: todayDate.add(const Duration(days: _daysAfter)),
      forceRefresh: forceRefresh,
    );
    _logger.debug('Prayer window loaded: ${all.length} days');

    final today = _dayAt(all, todayDate);

    // Yarın yalnızca Yatsı'dan sonra gösterilir; gün içinde doldurmak ana
    // ekrandaki "YARIN" şeridini sürekli görünür yapardı.
    final tomorrow = today != null && now.isAfter(today.isha)
        ? _dayAt(all, todayDate.add(const Duration(days: 1)))
        : null;

    final lastUpdate = await _prayerTimesRepository.getLastUpdateTime();
    final hasPermission = await _notificationService.isPermissionGranted();

    // Varsayılan bildirimler yalnızca ilk açılışta (bir kez) oluşturulur.
    // "Boşsa oluştur" mantığı, kullanıcı hepsini sildikten sonra konum değişince
    // bildirimleri geri getiriyordu; bunun yerine kalıcı bir bayrak kullanılır.
    await _settingsManager.ensureDefaultsSeeded();
    final settings = await _settingsManager.getSettings();

    return (
      today: today,
      tomorrow: tomorrow,
      all: all,
      lastUpdate: lastUpdate,
      hasPermission: hasPermission,
      settings: settings,
    );
  }

  PrayerTime? _dayAt(List<PrayerTime> times, DateTime date) {
    for (final time in times) {
      if (time.date.year == date.year &&
          time.date.month == date.month &&
          time.date.day == date.day) {
        return time;
      }
    }
    return null;
  }
}
