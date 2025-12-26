import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/di/service_locator.dart';
import '../../core/models/location.dart';
import '../../core/utils/app_logger.dart';
import '../../features/prayer_times/domain/prayer_times_repository.dart';
import '../../features/notifications/domain/notification_scheduler.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../features/location/domain/location_repository.dart';
import '../../features/location/domain/location_monitor_service.dart';
import '../../core/interfaces/notification_service.dart';
import '../screens/home_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/location_list_screen.dart';
import '../services/location_service.dart';
import '../services/data_loader_service.dart';
import '../controllers/location_monitor_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LocationMonitorController? _locationMonitorController;
  bool _isRefreshingGps = false;
  late final LocationService _locationService;
  late final DataLoaderService _dataLoaderService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _startLocationMonitoring();
    });
  }

  void _initializeServices() {
    final locationRepository = ServiceLocator().get<LocationRepository>();
    _locationService = LocationService(locationRepository);
    _dataLoaderService = DataLoaderService(
      prayerTimesRepository: ServiceLocator().get<PrayerTimesRepository>(),
      notificationService: ServiceLocator().get<NotificationService>(),
      settingsManager: ServiceLocator().get<NotificationSettingsManager>(),
      logger: AppLogger(),
    );
  }

  @override
  void dispose() {
    _locationMonitorController?.stopMonitoring();
    super.dispose();
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
      logger.info('🔄 Manual GPS refresh triggered');

      final gpsLocation = await _locationService.getCurrentGpsLocation();

      final locationRepository = ServiceLocator().get<LocationRepository>();
      final savedLocation = await locationRepository.saveOrUpdateGpsLocation(
        gpsLocation,
      );
      await locationRepository.setActiveLocation(savedLocation);
      appState.setActiveLocation(savedLocation);

      await _loadInitialData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS konumu güncellendi: ${gpsLocation.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      logger.info('✅ Manual GPS refresh completed');
    } catch (e) {
      logger.error('❌ Manual GPS refresh failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
      logger.warning('⚠️ No active location found, skipping initial data load');
      return;
    }

    appState.setLoading(true);
    appState.clearError();

    try {
      final data = await _dataLoaderService.loadInitialData(location);

      appState.setTodaysPrayerTime(data['todayPrayer']);
      appState.setTomorrowsPrayerTime(data['tomorrowPrayer']);
      appState.setPrayerTimes(data['prayerTimes']);
      appState.setLastUpdateTime(data['lastUpdate']);
      appState.setNotificationPermission(data['hasPermission']);
      appState.setNotificationSettings(data['settings']);

      appState.setLoading(false);
      logger.info('✅ Initial data loaded successfully');

      _loadMoreDataInBackground(location);
    } catch (e) {
      logger.error('❌ Failed to load initial data', e);
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
      final existingTimes = appState.prayerTimes;
      appState.setPrayerTimes([...existingTimes, ...prayerTimes]);
    }
  }

  Future<void> _refreshData() async {
    final logger = AppLogger();
    logger.info('🔄 User triggered refresh');
    final appState = context.read<AppState>();
    final location = appState.activeLocation;

    if (location == null) {
      logger.warning('⚠️ No location for refresh');
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
        ),
      ),
    );
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
    final locationRepository = ServiceLocator().get<LocationRepository>();

    logger.info('🔄 Switching location to: ${newLocation.displayName}');

    try {
      await locationRepository.setActiveLocation(newLocation);
      appState.setActiveLocation(newLocation);

      appState.clearPrayerTimes();
      appState.setTodaysPrayerTime(null);
      appState.setTomorrowsPrayerTime(null);

      await _loadInitialData();

      logger.info('✅ Location switched successfully');
    } catch (e) {
      logger.error('❌ Failed to switch location', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Konum değiştirilemedi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
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
        );
      },
    );
  }
}
