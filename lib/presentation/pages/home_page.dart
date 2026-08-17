import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';

import '../../core/di/service_locator.dart';
import '../../core/interfaces/alarm_service.dart';
import '../../core/models/mission_stop_event.dart';
import '../screens/mission_launcher.dart';
import '../../core/models/location.dart';
import '../../core/models/calculation_settings.dart';
import '../../core/interfaces/local_storage.dart';
import '../../core/utils/app_logger.dart';
import '../../features/prayer_times/domain/prayer_times_repository.dart';
import '../../core/models/skipped_occurrence.dart';
import '../../features/alarms/domain/alarms_manager.dart';
import '../../features/notifications/domain/skip_manager.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../features/location/domain/location_repository.dart';
import '../../features/location/domain/location_service.dart';
import '../../features/location/domain/location_monitor_service.dart';
import '../../core/interfaces/notification_service.dart';
import '../screens/home_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/calculation_settings_screen.dart';
import '../screens/location_list_screen.dart';
import '../screens/reminders_screen.dart';
import '../services/location_service.dart';
import '../services/data_loader_service.dart';
import '../services/day_rollover.dart';
import '../services/reminder_rescheduler.dart';
import '../controllers/location_monitor_controller.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/tokens_context.dart';
import '../widgets/common/app_nav_bar.dart';
import '../widgets/common/app_surface.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  LocationMonitorController? _locationMonitorController;
  Timer? _midnightTimer;
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
      _scheduleMidnightRefresh();
    });
  }

  void _initializeServices() {
    _locationService = GpsLocationService();
    _dataLoaderService = DataLoaderService(
      prayerTimesRepository: ServiceLocator().get<PrayerTimesRepository>(),
      notificationService: ServiceLocator().get<NotificationService>(),
      settingsManager: ServiceLocator().get<NotificationSettingsManager>(),
      skipManager: ServiceLocator().get<SkipManager>(),
      logger: AppLogger(),
    );
  }

  @override
  void dispose() {
    _missionStops?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _locationMonitorController?.stopMonitoring();
    super.dispose();
  }

  /// Gece yarısında vakit verisini tazeler.
  ///
  /// Vakit tablosu miladi takvim gününe bağlı; gün dönünce ekrandaki her şey
  /// (tarih satırı, ızgara, gün cetveli) dünü göstermeye devam ediyordu.
  /// Yeni günün verisi zaten önbellekteki pencerede olduğu için ağ gerekmez.
  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    _midnightTimer = Timer(delayToNextMidnight(DateTime.now()), () {
      if (!mounted) return;
      _loadPrayerData();
      _scheduleMidnightRefresh();
      openMissionIfPending(context);
    });

    // Uygulama on plandayken alarm durdurulursa hicbir yasam dongusu olayi
    // tetiklenmiyor; native bildirimi dinlemezsek gorev ekrani hic acilmaz.
    _missionStops = ServiceLocator().get<AlarmService>().missionStops.listen((
      _,
    ) {
      if (mounted) openMissionIfPending(context);
    });
  }

  StreamSubscription<MissionStopEvent>? _missionStops;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Yerel bildirimler arka planda kendiliğinden uzamaz; her ön plana gelişte
    // mevcut vakitlerle yeniden planlamak, kullanıcı uzun süre açmasa bile
    // 7 günlük pencereyi güncel tutar.
    if (state == AppLifecycleState.resumed) {
      // Dilim sınırı timer'ı uygulama askıdayken tetiklenmez; ön plana
      // dönünce paleti yeniden hesaplat.
      ServiceLocator().get<ThemeController>().refresh();

      // Alarm durdurulunca stopIntent uygulamayi one getiriyor; bekleyen
      // gorev varsa ekrani burada aciyoruz.
      openMissionIfPending(context);

      // Gün dönümü timer'ı da askıdayken tetiklenmez: uygulama gece açık
      // bırakılıp sabah öne getirilirse veri dünde kalırdı.
      _scheduleMidnightRefresh();
      final appState = context.read<AppState>();
      if (isPrayerDataStale(appState.todaysPrayerTime, DateTime.now())) {
        _loadPrayerData();
        return;
      }

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
      await ServiceLocator().get<ReminderRescheduler>().reschedule(
        location: location,
        prayerTimes: prayerTimes,
        skips: appState.skips,
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
      appState.setSkips(data.skips);
      appState.setRefreshing(false);

      // Palet gün dilimini vakitlerden hesaplar; beslenmezse hep akşam
      // fallback'inde (D5) kalır.
      ServiceLocator().get<ThemeController>().updatePrayerTimes(
        today: data.today,
        tomorrow: data.tomorrow,
      );

      logger.debug('Prayer data loaded: ${data.all.length} days');

      await ServiceLocator().get<ReminderRescheduler>().reschedule(
        location: location,
        prayerTimes: data.all,
        skips: data.skips,
      );
    } catch (e) {
      logger.error('Failed to load prayer data', e);
      appState.setError('Veri yüklenirken hata oluştu: $e');
      appState.setRefreshing(false);
    }
  }

  /// Kullanıcının tetiklediği yenileme (aşağı çekme, takvim ekranı).
  Future<void> _refreshData() => _loadPrayerData(forceRefresh: true);

  /// "SIRADAKİ" kartındaki tek seferlik kapatma.
  ///
  /// Kalıcı kapatma Bildirimler/Alarmlar ekranlarında kalır; buradaki anahtar
  /// yalnızca gösterilen örneği atlar.
  Future<void> _toggleSkip(SkippedOccurrence occurrence, bool skipped) async {
    final appState = context.read<AppState>();
    final manager = ServiceLocator().get<SkipManager>();

    final next = skipped
        ? await manager.skip(occurrence)
        : await manager.unskip(occurrence);
    appState.setSkips(next);

    try {
      await ServiceLocator().get<ReminderRescheduler>().reschedule(
        location: appState.activeLocation,
        prayerTimes: appState.prayerTimes,
        skips: next,
      );
    } catch (e) {
      AppLogger().warning('Atlama sonrasi yeniden planlama basarisiz', e);
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
    return PopScope(
      // Sekme gecmisi biriktirmek geri tusunu ongorulemez kilar; 2. veya 3.
      // sekmedeyken geri ilk sekmeye doner, orada uygulamadan cikar.
      canPop: _tabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tabIndex != 0) setState(() => _tabIndex = 0);
      },
      child: Scaffold(
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
                    skips: appState.skips,
                    onSkipChanged: _toggleSkip,
                    errorMessage: appState.errorMessage,
                    onRefresh: _refreshData,
                    onGpsRefresh: _manualGpsRefresh,
                    onSettingsTap: _navigateToSettings,
                    onSeeReminders: () => setState(() => _tabIndex = 2),
                    onLocationTap: _navigateToLocationList,
                  );
                },
              ),
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return CalendarScreen(
                    location: appState.activeLocation!,
                    prayerTimes: appState.prayerTimes,
                    onRefresh: _refreshData,
                    isLoading: appState.isLoading,
                    errorMessage: appState.errorMessage,
                  );
                },
              ),
              const RemindersScreen(),
            ],
          ),
        ),
        bottomNavigationBar: AppNavBar(
          items: const [
            NavItem(label: 'Vakitler', icon: Icons.schedule_rounded),
            NavItem(label: 'Takvim', icon: Icons.calendar_month_rounded),
            NavItem(label: 'Hatırlatıcılar', icon: Icons.notifications_rounded),
          ],
          selected: _tabIndex,
          onChanged: (index) => setState(() => _tabIndex = index),
        ),
      ),
    );
  }
}
