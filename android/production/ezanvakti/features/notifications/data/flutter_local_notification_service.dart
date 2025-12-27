import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/interfaces/notification_service.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/app_logger.dart';

class FlutterLocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final AppLogger _logger = AppLogger();
  bool _requestedExactAlarmIntent = false;

  @override
  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      const androidChannel = AndroidNotificationChannel(
        'ezan_vakti_channel',
        'Ezan Vakti Bildirimleri',
        description: 'Namaz vakitlerini bildiren bildirimler',
        importance: Importance.high,
      );
      await androidPlugin.createNotificationChannel(androidChannel);
      _logger.info(
        '📢 Android notification channel ensured (ezan_vakti_channel)',
      );
    }
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    bool granted = true;

    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? false;
    }

    if (ios != null) {
      granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    return granted;
  }

  @override
  Future<bool> isPermissionGranted() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }

    if (ios != null) {
      final settings = await ios.checkPermissions();
      return settings?.isEnabled ?? false;
    }

    return false;
  }

  @override
  Future<void> scheduleNotification({
    required String id,
    required DateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ezan_vakti_channel',
      'Ezan Vakti Bildirimleri',
      channelDescription: 'Namaz vakitlerini bildiren bildirimler',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id.hashCode,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelNotification(String id) async {
    await _plugin.cancel(id.hashCode);
  }

  @override
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  @override
  Future<List<ScheduledNotification>> getPendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();

    return pending.map((notification) {
      return ScheduledNotification(
        id: notification.id.toString(),
        scheduledTime: DateTime.now(),
        prayerType: PrayerType.fajr,
        minutesBefore: 0,
      );
    }).toList();
  }

  @override
  Future<void> openExactAlarmSettings() async {
    if (_requestedExactAlarmIntent) return;
    _requestedExactAlarmIntent = true;
    try {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      );
      await intent.launch();
      _logger.info('⏱️ Launched exact alarm settings intent');
    } catch (e) {
      _logger.warning('⚠️ Could not open exact alarm settings', e);
    }
  }
}
