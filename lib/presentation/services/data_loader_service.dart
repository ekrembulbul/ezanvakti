import '../../core/interfaces/notification_service.dart';
import '../../core/models/location.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/skipped_occurrence.dart';
import '../../core/utils/app_logger.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../features/notifications/domain/skip_manager.dart';
import '../../features/prayer_times/domain/prayer_times_repository.dart';

/// Ana ekranın ihtiyaç duyduğu her şey tek yüklemede.
typedef PrayerData = ({
  PrayerTime? today,

  /// Ertesi günün vakti. Ana ekrandaki "YARIN" şeridi (spec §6.1/6) gün boyu
  /// görünür; palet de gece diliminin ertesi İmsak'ta bittiğini buradan
  /// öğrenir. Yalnızca veri penceresi ertesi günü kapsamıyorsa `null`.
  PrayerTime? tomorrow,

  List<PrayerTime> all,

  /// "Yalnızca bu sefer" atlanmış örnekler; süresi geçenler elenmiş hâlde.
  Set<SkippedOccurrence> skips,

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
  final SkipManager _skipManager;
  final AppLogger _logger;

  DataLoaderService({
    required PrayerTimesRepository prayerTimesRepository,
    required NotificationService notificationService,
    required NotificationSettingsManager settingsManager,
    required SkipManager skipManager,
    required AppLogger logger,
  }) : _prayerTimesRepository = prayerTimesRepository,
       _notificationService = notificationService,
       _settingsManager = settingsManager,
       _skipManager = skipManager,
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
    final tomorrow = _dayAt(all, todayDate.add(const Duration(days: 1)));

    final lastUpdate = await _prayerTimesRepository.getLastUpdateTime();
    final hasPermission = await _notificationService.isPermissionGranted();

    // Varsayılan bildirimler yalnızca ilk açılışta (bir kez) oluşturulur.
    // "Boşsa oluştur" mantığı, kullanıcı hepsini sildikten sonra konum değişince
    // bildirimleri geri getiriyordu; bunun yerine kalıcı bir bayrak kullanılır.
    await _settingsManager.ensureDefaultsSeeded();
    final settings = await _settingsManager.getSettings();
    final skips = await _skipManager.load();

    return (
      today: today,
      tomorrow: tomorrow,
      all: all,
      skips: skips,
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
