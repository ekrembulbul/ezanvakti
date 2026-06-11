import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/location.dart';
import '../../core/models/calculation_settings.dart';
import '../../core/interfaces/local_storage.dart';
import '../../core/utils/app_logger.dart';
import '../../features/prayer_times/domain/prayer_times_repository.dart';
import '../../features/notifications/domain/notification_scheduler.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
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
      _loadInitialData();
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
      locationRepository: ServiceLocator().get<LocationRepository>(),
      logger: AppLogger(),
      onLocationChanged: (newLocation) async {
        appState.setActiveLocation(newLocation);
        await _loadInitialData();
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

      await _loadInitialData();

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'GPS konumu güncellendi: ${gpsLocation.displayName}',
              ),
              backgroundColor: Colors.green,
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
              backgroundColor: Colors.red,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingGps = false);
      }
    }
  }

  Future<void> _loadInitialData() async {
    final logger = AppLogger();
    final appState = context.read<AppState>();
    final location = appState.activeLocation;

    if (location == null) {
      logger.warning('No active location found, skipping initial data load');
      return;
    }

    appState.setLoading(true);
    appState.clearError();

    try {
      final data = await _dataLoaderService.loadInitialData(location);

      logger.debug(
        'Data received - todayPrayer: ${data['todayPrayer'] != null ? "YES" : "NULL"}, prayerTimes count: ${(data['prayerTimes'] as List).length}',
      );

      appState.setTodaysPrayerTime(data['todayPrayer']);
      appState.setTomorrowsPrayerTime(data['tomorrowPrayer']);
      appState.setPrayerTimes(data['prayerTimes']);
      appState.setLastUpdateTime(data['lastUpdate']);
      appState.setNotificationPermission(data['hasPermission']);
      appState.setNotificationSettings(data['settings']);

      logger.debug(
        'AppState updated - todaysPrayerTime: ${appState.todaysPrayerTime != null ? "YES" : "NULL"}',
      );

      appState.setLoading(false);
      logger.debug('Initial data loaded successfully');

      _loadMoreDataInBackground(location);
    } catch (e) {
      logger.error('Failed to load initial data', e);
      appState.setError('Veri yüklenirken hata oluştu: $e');
      appState.setLoading(false);
    }
  }

  Future<void> _loadMoreDataInBackground(Location location) async {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    final prayerTimes = await _dataLoaderService.loadBackgroundData(
      location,
      todayNormalized,
    );

    if (mounted && prayerTimes.isNotEmpty) {
      final appState = context.read<AppState>();
      appState.setPrayerTimes(prayerTimes);

      // Prayer times are available only after background load; schedule notifications now.
      final scheduler = ServiceLocator().get<NotificationScheduler>();
      await scheduler.scheduleNotifications(
        location: location,
        prayerTimes: prayerTimes,
      );
      // Alarmları da güncel vakitlerle planla.
      await ServiceLocator().get<AlarmScheduler>().scheduleAlarms(
        prayerTimes: prayerTimes,
      );
    }
  }

  Future<void> _refreshData() async {
    final logger = AppLogger();
    logger.debug('User triggered refresh');
    final appState = context.read<AppState>();
    final location = appState.activeLocation;

    if (location == null) {
      logger.warning('No location for refresh');
      return;
    }

    try {
      final repository = ServiceLocator().get<PrayerTimesRepository>();
      await repository.refreshPrayerTimes(location);
      await _loadInitialData();
    } catch (e) {
      appState.setError('Yenileme başarısız: $e');
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

    await _loadInitialData();
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
      // bildirimlerin yeniden planlanması aşağıdaki _loadInitialData'da kalır
      // (tek veri yükleme penceresi; çift çekim olmaz).
      await locationService.changeLocation(newLocation);
      appState.setActiveLocation(newLocation);

      appState.clearPrayerTimes();
      appState.setTodaysPrayerTime(null);
      appState.setTomorrowsPrayerTime(null);

      await _loadInitialData();

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
      backgroundColor: AppTheme.primaryDark,
      body: IndexedStack(
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
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppTheme.primaryDark,
        indicatorColor: AppTheme.gold.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppTheme.gold
                : Colors.white60,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppTheme.gold
                : Colors.white60,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.access_time_outlined),
            selectedIcon: Icon(Icons.access_time_filled_rounded),
            label: 'Vakitler',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm_on_rounded),
            label: 'Alarmlar',
          ),
        ],
      ),
    );
  }
}
