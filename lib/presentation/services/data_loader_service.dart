import '../../core/models/location.dart';
import '../../core/models/prayer_time.dart';
import '../../features/prayer_times/domain/prayer_times_repository.dart';
import '../../core/interfaces/notification_service.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../core/utils/app_logger.dart';

class DataLoaderService {
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

  Future<Map<String, dynamic>> loadInitialData(Location location) async {
    _logger.info(
      '🏠 Loading initial data for ${location.province}/${location.district}',
    );

    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    final todayPrayer = await _prayerTimesRepository.getDailyPrayerTime(
      location: location,
      date: todayNormalized,
    );

    PrayerTime? tomorrowPrayer;
    final now = DateTime.now();
    if (todayPrayer != null && now.isAfter(todayPrayer.isha)) {
      _logger.info('⏰ After Isha, fetching tomorrow\'s prayer times');
      final tomorrow = todayNormalized.add(const Duration(days: 1));
      tomorrowPrayer = await _prayerTimesRepository.getDailyPrayerTime(
        location: location,
        date: tomorrow,
      );
    }

    final lastUpdate = await _prayerTimesRepository.getLastUpdateTime();
    final hasPermission = await _notificationService.isPermissionGranted();
    final settings = await _settingsManager.getSettings();

    return {
      'todayPrayer': todayPrayer,
      'tomorrowPrayer': tomorrowPrayer,
      'prayerTimes': todayPrayer != null ? [todayPrayer] : <PrayerTime>[],
      'lastUpdate': lastUpdate,
      'hasPermission': hasPermission,
      'settings': settings,
    };
  }

  Future<List<PrayerTime>> loadBackgroundData(
    Location location,
    DateTime startDate,
  ) async {
    _logger.info('🔄 Loading background data for next 30 days');
    try {
      final prayerTimes = await _prayerTimesRepository.getPrayerTimes(
        location: location,
        startDate: startDate.add(const Duration(days: 1)),
        endDate: startDate.add(const Duration(days: 30)),
        forceRefresh: false,
      );
      _logger.info('✅ Background load completed: ${prayerTimes.length} days');
      return prayerTimes;
    } catch (e) {
      _logger.warning('⚠️ Background loading failed (ignored)', e);
      return [];
    }
  }
}
