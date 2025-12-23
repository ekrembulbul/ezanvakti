import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/di/service_locator.dart';
import '../../core/models/notification_setting.dart';
import '../../features/prayer_times/domain/prayer_times_repository.dart';
import '../../features/notifications/domain/notification_scheduler.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../core/interfaces/notification_service.dart';
import '../screens/home_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/settings_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final appState = context.read<AppState>();
    final location = appState.activeLocation;

    if (location == null) return;

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

      final prayerTimes = await repository.getPrayerTimes(
        location: location,
        startDate: todayNormalized,
        endDate: todayNormalized.add(const Duration(days: 30)),
      );

      appState.setPrayerTimes(prayerTimes);

      final lastUpdate = await ServiceLocator()
          .get<PrayerTimesRepository>()
          .getLastUpdateTime();
      appState.setLastUpdateTime(lastUpdate);

      final notificationService = ServiceLocator().get<NotificationService>();
      final hasPermission = await notificationService.isPermissionGranted();
      appState.setNotificationPermission(hasPermission);

      final settingsManager = ServiceLocator()
          .get<NotificationSettingsManager>();
      final settings = await settingsManager.getSettings();
      appState.setNotificationSettings(settings);
    } catch (e) {
      appState.setError('Veri yüklenirken hata oluştu: $e');
    } finally {
      appState.setLoading(false);
    }
  }

  Future<void> _refreshData() async {
    final appState = context.read<AppState>();
    final location = appState.activeLocation;

    if (location == null) return;

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

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationSettingsScreen(
          settings: appState.notificationSettings,
          hasPermission: appState.hasNotificationPermission,
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
          onChangeLocation: () {
            // TODO: Implement location change
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return HomeScreen(
          location: appState.activeLocation!,
          todaysPrayerTime: appState.todaysPrayerTime,
          lastUpdateTime: appState.lastUpdateTime,
          isLoading: appState.isLoading,
          errorMessage: appState.errorMessage,
          onRefresh: _refreshData,
          onCalendarTap: _navigateToCalendar,
          onNotificationSettingsTap: _navigateToNotificationSettings,
          onSettingsTap: _navigateToSettings,
        );
      },
    );
  }
}
