import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' hide Location;
import '../../core/providers/app_state.dart';
import '../../core/di/service_locator.dart';
import '../../core/models/location.dart';
import '../../core/models/notification_setting.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LocationMonitorService? _locationMonitor;
  bool _isRefreshingGps = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _startLocationMonitoring();
    });
  }

  @override
  void dispose() {
    _locationMonitor?.stopMonitoring();
    super.dispose();
  }

  Future<void> _startLocationMonitoring() async {
    final appState = context.read<AppState>();
    if (appState.activeLocation?.type == LocationType.gps) {
      _locationMonitor = ServiceLocator().get<LocationMonitorService>();

      _locationMonitor?.onLocationChanged.listen((newLocation) async {
        final logger = AppLogger();
        logger.info('🔄 GPS location changed, refreshing prayer times...');

        final locationRepository = ServiceLocator().get<LocationRepository>();
        await locationRepository.setActiveLocation(newLocation);
        appState.setActiveLocation(newLocation);

        await _loadInitialData();
      });

      await _locationMonitor?.startMonitoring();
    }
  }

  Future<void> _manualGpsRefresh() async {
    if (_isRefreshingGps) return;

    setState(() => _isRefreshingGps = true);

    final logger = AppLogger();
    final appState = context.read<AppState>();

    try {
      logger.info('🔄 Manual GPS refresh triggered');

      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission != LocationPermission.always &&
          hasPermission != LocationPermission.whileInUse) {
        throw Exception('Konum izni gerekli');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        throw Exception('Konum bilgisi alınamadı');
      }

      final placemark = placemarks.first;
      final province = placemark.administrativeArea ?? '';
      final district =
          placemark.subAdministrativeArea ?? placemark.locality ?? '';

      if (province.isEmpty || district.isEmpty) {
        throw Exception('İl veya ilçe bilgisi bulunamadı');
      }

      final matchedLocation = _findMatchingLocation(province, district);
      if (matchedLocation != null) {
        final gpsLocation = matchedLocation.copyWith(
          type: LocationType.gps,
          latitude: position.latitude,
          longitude: position.longitude,
        );

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
              content: Text(
                'GPS konumu güncellendi: ${gpsLocation.displayName}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }

        logger.info('✅ Manual GPS refresh completed');
      } else {
        throw Exception('$province/$district için veri bulunamadı');
      }
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

  Location? _findMatchingLocation(String province, String district) {
    final locationRepository = ServiceLocator().get<LocationRepository>();
    final allProvinces = locationRepository.getAllProvinces();

    String? matchedProvince;
    for (final p in allProvinces) {
      if (p.toLowerCase().contains(province.toLowerCase()) ||
          province.toLowerCase().contains(p.toLowerCase())) {
        matchedProvince = p;
        break;
      }
    }

    if (matchedProvince == null) return null;

    final districts = locationRepository.getDistrictsByProvince(
      matchedProvince,
    );
    for (final d in districts) {
      if (d.district.toLowerCase().contains(district.toLowerCase()) ||
          district.toLowerCase().contains(d.district.toLowerCase())) {
        return d;
      }
    }

    return districts.isNotEmpty ? districts.first : null;
  }

  Future<void> _loadInitialData() async {
    final logger = AppLogger();
    final appState = context.read<AppState>();
    final location = appState.activeLocation;

    if (location == null) {
      logger.warning('⚠️ No active location found, skipping initial data load');
      return;
    }

    logger.info(
      '🏠 HomePage: Loading initial data for ${location.province}/${location.district}',
    );

    appState.setLoading(true);
    appState.clearError();

    try {
      final repository = ServiceLocator().get<PrayerTimesRepository>();
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);

      final todayPrayer = await repository.getDailyPrayerTime(
        location: location,
        date: todayNormalized,
      );

      appState.setTodaysPrayerTime(todayPrayer);
      appState.setPrayerTimes(todayPrayer != null ? [todayPrayer] : []);

      final now = DateTime.now();
      if (todayPrayer != null && now.isAfter(todayPrayer.isha)) {
        logger.info(
          '⏰ After Isha, fetching tomorrow\'s prayer times for countdown',
        );
        final tomorrow = todayNormalized.add(const Duration(days: 1));
        final tomorrowPrayer = await repository.getDailyPrayerTime(
          location: location,
          date: tomorrow,
        );
        appState.setTomorrowsPrayerTime(tomorrowPrayer);
      }

      final lastUpdate = await repository.getLastUpdateTime();
      appState.setLastUpdateTime(lastUpdate);

      final notificationService = ServiceLocator().get<NotificationService>();
      final hasPermission = await notificationService.isPermissionGranted();
      appState.setNotificationPermission(hasPermission);

      final settingsManager = ServiceLocator()
          .get<NotificationSettingsManager>();
      final settings = await settingsManager.getSettings();
      appState.setNotificationSettings(settings);

      appState.setLoading(false);
      logger.info('✅ Initial data loaded successfully');

      _loadMoreDataInBackground(location, todayNormalized);
    } catch (e) {
      logger.error('❌ Failed to load initial data', e);
      appState.setError('Veri yüklenirken hata oluştu: $e');
      appState.setLoading(false);
    }
  }

  Future<void> _loadMoreDataInBackground(
    Location location,
    DateTime startDate,
  ) async {
    final logger = AppLogger();
    logger.info('🔄 Starting background data load for next 30 days');
    try {
      final repository = ServiceLocator().get<PrayerTimesRepository>();
      final prayerTimes = await repository.getPrayerTimes(
        location: location,
        startDate: startDate.add(const Duration(days: 1)),
        endDate: startDate.add(const Duration(days: 30)),
        forceRefresh: false,
      );

      if (mounted) {
        final appState = context.read<AppState>();
        final existingTimes = appState.prayerTimes;
        appState.setPrayerTimes([...existingTimes, ...prayerTimes]);
        logger.info(
          '✅ Background load completed: Total ${existingTimes.length + prayerTimes.length} days available',
        );
      }
    } catch (e) {
      logger.warning('⚠️ Background loading failed (ignored)', e);
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
          settings: appState.notificationSettings,
          hasPermission: appState.hasNotificationPermission,
          prayerTime: prayerTime,
          onSettingToggled: (setting) async {
            final manager = ServiceLocator().get<NotificationSettingsManager>();
            await manager.updateSetting(setting);
            await _reloadNotificationSettings();
          },
          onOffsetChanged: (prayer, offset) async {
            final manager = ServiceLocator().get<NotificationSettingsManager>();
            final newSetting = NotificationSetting(
              prayerType: prayer,
              isActive: true,
              minutesBefore: offset,
            );
            await manager.updateSetting(newSetting);
            await _reloadNotificationSettings();
          },
          onRequestPermission: () async {
            final service = ServiceLocator().get<NotificationService>();
            final granted = await service.requestPermission();
            appState.setNotificationPermission(granted);
            return granted;
          },
          onDeleteSetting: (prayer, minutesBefore) async {
            final manager = ServiceLocator().get<NotificationSettingsManager>();
            await manager.removeSetting(
              prayerType: prayer,
              minutesBefore: minutesBefore,
            );
            await _reloadNotificationSettings();
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
