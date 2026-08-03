import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/di/service_locator.dart';
import '../../core/models/location.dart';
import '../../core/models/calculation_settings.dart';
import '../../core/interfaces/local_storage.dart';
import '../../core/utils/app_logger.dart';
import '../../features/prayer_times/domain/prayer_times_repository.dart';
import '../../features/notifications/domain/notification_scheduler.dart';
import '../../core/models/alarm.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
import '../../features/alarms/domain/alarms_manager.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../features/location/domain/location_repository.dart';
import '../../features/location/domain/location_service.dart';
import '../../features/location/domain/location_monitor_service.dart';
import '../../core/interfaces/notification_service.dart';
import '../screens/home_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/calculation_settings_screen.dart';
import '../screens/location_list_screen.dart';
import '../screens/alarms_screen.dart';
import '../services/location_service.dart';
import '../services/data_loader_service.dart';
import '../controllers/location_monitor_controller.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/tokens_context.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/sliding_segment.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  LocationMonitorController? _locationMonitorController;
  bool _isRefreshingGps = false;
  int _tabIndex = 0;
  DateTime? _lastResumeReschedule;
  late final GpsLocationService _locationService;
  late final DataLoaderService _dataLoaderService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final logger = AppLogger();
    logger.debug('HomePage initState called');
    _initializeServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      logger.debug('PostFrameCallback executing');
      _loadPrayerData();
      _startLocationMonitoring();
    });
  }

  void _initializeServices() {
    _locationService = GpsLocationService();
    _dataLoaderService = DataLoaderService(
      prayerTimesRepository: ServiceLocator().get<PrayerTimesRepository>(),
      notificationService: ServiceLocator().get<NotificationService>(),
      settingsManager: ServiceLocator().get<NotificationSettingsManager>(),
      logger: AppLogger(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationMonitorController?.stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Yerel bildirimler arka planda kendiliğinden uzamaz; her ön plana gelişte
    // mevcut vakitlerle yeniden planlamak, kullanıcı uzun süre açmasa bile
    // 7 günlük pencereyi güncel tutar.
    if (state == AppLifecycleState.resumed) {
      // Dilim sınırı timer'ı uygulama askıdayken tetiklenmez; ön plana
      // dönünce paleti yeniden hesaplat.
      ServiceLocator().get<ThemeController>().refresh();
      _rescheduleOnResume();
    }
  }

  Future<void> _rescheduleOnResume() async {
    final now = DateTime.now();
    // Gereksiz tekrar planlamayı önlemek için en fazla saatte bir.
    if (_lastResumeReschedule != null &&
        now.difference(_lastResumeReschedule!) < const Duration(hours: 1)) {
      return;
    }

    final appState = context.read<AppState>();
    final location = appState.activeLocation;
    final prayerTimes = appState.prayerTimes;
    if (location == null || prayerTimes.isEmpty) return;

    _lastResumeReschedule = now;
    try {
      final scheduler = ServiceLocator().get<NotificationScheduler>();
      await scheduler.scheduleNotifications(
        location: location,
        prayerTimes: prayerTimes,
      );
      await ServiceLocator().get<AlarmScheduler>().scheduleAlarms(
        prayerTimes: prayerTimes,
      );
      AppLogger().debug('Notifications + alarms rescheduled on resume');
    } catch (e) {
      AppLogger().warning('Resume reschedule failed (ignored)', e);
    }
  }

  Future<void> _startLocationMonitoring() async {
    final appState = context.read<AppState>();
    _locationMonitorController = LocationMonitorController(
      monitorService: ServiceLocator().get<LocationMonitorService>(),
      locationService: ServiceLocator().get<LocationService>(),
      logger: AppLogger(),
      onLocationChanged: (newLocation) async {
        appState.setActiveLocation(newLocation);
        await _loadPrayerData(forceRefresh: true);
      },
    );
    await _locationMonitorController?.startMonitoring(appState.activeLocation);
  }

  Future<void> _manualGpsRefresh() async {
    if (_isRefreshingGps) return;

    setState(() => _isRefreshingGps = true);

    final logger = AppLogger();
    final appState = context.read<AppState>();

    try {
      logger.debug('Manual GPS refresh triggered');

      final gpsLocation = await _locationService.getCurrentGpsLocation();

      final locationRepository = ServiceLocator().get<LocationRepository>();
      final savedLocation = await locationRepository.saveOrUpdateGpsLocation(
        gpsLocation,
      );
      await locationRepository.setActiveLocation(savedLocation);
      appState.setActiveLocation(savedLocation);

      await _loadPrayerData(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'GPS konumu güncellendi: ${gpsLocation.displayName}',
              ),
            ),
          );
      }

      logger.debug('Manual GPS refresh completed');
    } catch (e) {
      logger.error('Manual GPS refresh failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'GPS yenileme hatası: ${e.toString().replaceAll('Exception: ', '')}',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingGps = false);
      }
    }
  }

  /// Vakit penceresini yükler ve bildirim/alarm planlamasını tazeler.
  ///
  /// Tek giriş noktası: açılış, GPS güncellemesi, konum değişimi, hesaplama
  /// ayarı değişimi ve kullanıcının manuel yenilemesi hep buradan geçer.
  Future<void> _loadPrayerData({bool forceRefresh = false}) async {
    final logger = AppLogger();
    final appState = context.read<AppState>();
    final location = appState.activeLocation;

    if (location == null) {
      logger.warning('No active location found, skipping data load');
      return;
    }

    appState.setRefreshing(true);
    appState.clearError();

    try {
      final data = await _dataLoaderService.loadPrayerData(
        location,
        forceRefresh: forceRefresh,
      );

      appState.setTodaysPrayerTime(data.today);
      appState.setTomorrowsPrayerTime(data.tomorrow);
      appState.setPrayerTimes(data.all);
      appState.setLastUpdateTime(data.lastUpdate);
      appState.setNotificationPermission(data.hasPermission);
      appState.setNotificationSettings(data.settings);
      appState.setAlarms(
        await ServiceLocator().get<AlarmsManager>().getAlarms(),
      );
      appState.setRefreshing(false);

      // Palet gün dilimini vakitlerden hesaplar; beslenmezse hep akşam
      // fallback'inde (D5) kalır.
      ServiceLocator().get<ThemeController>().updatePrayerTimes(
        today: data.today,
        tomorrow: data.tomorrow,
      );

      logger.debug('Prayer data loaded: ${data.all.length} days');

      if (data.all.isEmpty) return;

      final scheduler = ServiceLocator().get<NotificationScheduler>();
      await scheduler.scheduleNotifications(
        location: location,
        prayerTimes: data.all,
      );
      await ServiceLocator().get<AlarmScheduler>().scheduleAlarms(
        prayerTimes: data.all,
      );
    } catch (e) {
      logger.error('Failed to load prayer data', e);
      appState.setError('Veri yüklenirken hata oluştu: $e');
      appState.setRefreshing(false);
    }
  }

  /// Kullanıcının tetiklediği yenileme (aşağı çekme, takvim ekranı).
  Future<void> _refreshData() => _loadPrayerData(forceRefresh: true);

  /// "SIRADAKİ" kartındaki alarm anahtarı. Alarmlar sekmesindekiyle aynı iş:
  /// kaydet, sonra güncel vakitlerle yeniden planla.
  Future<void> _toggleAlarm(Alarm alarm, bool isActive) async {
    final appState = context.read<AppState>();
    final manager = ServiceLocator().get<AlarmsManager>();

    await manager.setActive(alarm, isActive);
    appState.setAlarms(await manager.getAlarms());

    final prayerTimes = appState.prayerTimes;
    if (prayerTimes.isEmpty) return;
    try {
      await ServiceLocator().get<AlarmScheduler>().scheduleAlarms(
        prayerTimes: prayerTimes,
      );
    } catch (e) {
      AppLogger().warning('Alarm yeniden planlanamadı', e);
    }
  }

  void _navigateToCalendar() {
    final appState = context.read<AppState>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CalendarScreen(
          location: appState.activeLocation!,
          prayerTimes: appState.prayerTimes,
          onRefresh: _refreshData,
          isLoading: appState.isLoading,
          errorMessage: appState.errorMessage,
        ),
      ),
    );
  }

  void _navigateToNotificationSettings() async {
    final appState = context.read<AppState>();
    final prayerTime =
        appState.todaysPrayerTime ??
        (appState.prayerTimes.isNotEmpty ? appState.prayerTimes.first : null);

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationSettingsScreen(
          hasPermission: appState.hasNotificationPermission,
          prayerTime: prayerTime,
          onRequestPermission: () async {
            final service = ServiceLocator().get<NotificationService>();
            final granted = await service.requestPermission();
            appState.setNotificationPermission(granted);
            return granted;
          },
        ),
      ),
    );

    if (result == true) {
      await _reloadNotificationSettings();
    }
  }

  Future<void> _reloadNotificationSettings() async {
    final appState = context.read<AppState>();
    final manager = ServiceLocator().get<NotificationSettingsManager>();
    final settings = await manager.getSettings();
    appState.setNotificationSettings(settings);

    final location = appState.activeLocation;
    if (location != null && appState.prayerTimes.isNotEmpty) {
      final scheduler = ServiceLocator().get<NotificationScheduler>();
      await scheduler.scheduleNotifications(
        location: location,
        prayerTimes: appState.prayerTimes,
      );
    }
  }

  void _navigateToSettings() async {
    final appState = context.read<AppState>();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          currentLocation: appState.activeLocation!,
          onChangeLocation: _navigateToLocationList,
          onCalculationSettings: _navigateToCalculationSettings,
        ),
      ),
    );
  }

  void _navigateToCalculationSettings() async {
    final storage = ServiceLocator().get<LocalStorage>();
    final current = await storage.getCalculationSettings();
    if (!mounted) return;

    final result = await Navigator.of(context).push<CalculationSettings>(
      MaterialPageRoute(
        builder: (context) => CalculationSettingsScreen(initial: current),
      ),
    );

    if (result == null || result == current) return;

    await storage.saveCalculationSettings(result);
    await _applyGlobalCalculationChange();
  }

  Future<void> _applyGlobalCalculationChange() async {
    final appState = context.read<AppState>();
    // Global ayar değişti: tüm "inherit" konumların önbelleği geçersiz.
    await ServiceLocator().get<PrayerTimesRepository>().clearAllCache();
    await ServiceLocator().get<NotificationService>().cancelAllNotifications();

    appState.clearPrayerTimes();
    appState.setTodaysPrayerTime(null);
    appState.setTomorrowsPrayerTime(null);

    await _loadPrayerData(forceRefresh: true);
  }

  void _navigateToLocationList() async {
    final appState = context.read<AppState>();
    final locationRepository = ServiceLocator().get<LocationRepository>();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LocationListScreen(
          locationRepository: locationRepository,
          currentLocation: appState.activeLocation,
          onLocationSelected: (location) async {
            await _switchLocation(location);
          },
        ),
      ),
    );
  }

  Future<void> _switchLocation(Location newLocation) async {
    final logger = AppLogger();
    final appState = context.read<AppState>();
    final locationService = ServiceLocator().get<LocationService>();

    logger.debug('Switching location to: ${newLocation.displayName}');

    try {
      // Tek kanonik yol: aktif konumu ayarlama, hesaplama parametresi değişince
      // önbellek geçersizleştirme ve eski konumun bildirimlerini iptal etme
      // domain LocationService'e delege edilir. Vakit verisinin yüklenmesi ve
      // bildirimlerin yeniden planlanması aşağıdaki _loadPrayerData'da kalır
      // (tek veri yükleme penceresi; çift çekim olmaz).
      await locationService.changeLocation(newLocation);
      appState.setActiveLocation(newLocation);

      appState.clearPrayerTimes();
      appState.setTodaysPrayerTime(null);
      appState.setTomorrowsPrayerTime(null);

      await _loadPrayerData(forceRefresh: true);

      logger.debug('Location switched successfully');
    } catch (e) {
      logger.error('Failed to switch location', e);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('Konum değiştirilemedi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Alt gezinme AppSurface'in disinda kaldigi icin zemini Scaffold verir;
      // seffaf birakilirsa arkasinda hicbir sey boyanmiyor.
      backgroundColor: context.tokens.backgroundStops.last,
      body: AppSurface(
        safeAreaTop: false,
        safeAreaBottom: false,
        child: IndexedStack(
          index: _tabIndex,
          children: [
            Consumer<AppState>(
              builder: (context, appState, child) {
                return HomeScreen(
                  location: appState.activeLocation!,
                  todaysPrayerTime: appState.todaysPrayerTime,
                  tomorrowsPrayerTime: appState.tomorrowsPrayerTime,
                  lastUpdateTime: appState.lastUpdateTime,
                  isLoading: appState.isLoading,
                  isRefreshing: appState.isRefreshing,
                  prayerTimes: appState.prayerTimes,
                  notificationSettings: appState.notificationSettings,
                  alarms: appState.alarms,
                  onAlarmToggled: _toggleAlarm,
                  errorMessage: appState.errorMessage,
                  onRefresh: _refreshData,
                  onGpsRefresh: _manualGpsRefresh,
                  onCalendarTap: _navigateToCalendar,
                  onNotificationSettingsTap: _navigateToNotificationSettings,
                  onSettingsTap: _navigateToSettings,
                  onLocationTap: _navigateToLocationList,
                );
              },
            ),
            const AlarmsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SafeArea(
        top: false,
        child: SlidingSegment<int>(
          items: const [
            SegmentItem(
              value: 0,
              label: 'Vakitler',
              icon: Icons.schedule_rounded,
            ),
            SegmentItem(value: 1, label: 'Alarmlar', icon: Icons.alarm_rounded),
          ],
          selected: _tabIndex,
          onChanged: (index) => setState(() => _tabIndex = index),
        ),
      ),
    );
  }
}
