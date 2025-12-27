import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
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
    _logger.info('🔔 Notifications plugin initialized');

    // Ensure notification channel exists upfront so it appears under system settings
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
      _logger.info('🔒 Android notification permission result: $granted');
    }

    if (ios != null) {
      granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
      _logger.info('🔒 iOS notification permission result: $granted');
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
      final enabled = await android.areNotificationsEnabled() ?? false;
      _logger.info('🔎 Android notification permission check: $enabled');
      return enabled;
    }

    if (ios != null) {
      final settings = await ios.checkPermissions();
      final enabled = settings?.isEnabled ?? false;
      _logger.info('🔎 iOS notification permission check: $enabled');
      return enabled;
    }

    _logger.warning(
      '⚠️ Notification permission check: platform plugin missing',
    );
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

    // Android 12+ can throw exact_alarms_not_permitted when exact scheduling
    // is not allowed. Fall back to inexact scheduling instead of crashing.
    final logTime =
        '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}:${scheduledTime.second.toString().padLeft(2, '0')}';
    _logger.info('📆 Scheduling notification $id for $logTime (title: $title)');

    try {
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
      _logger.info('⏱️ Scheduled notification $id at $logTime (title: $title)');
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        await _plugin.zonedSchedule(
          id.hashCode,
          title,
          body,
          tz.TZDateTime.from(scheduledTime, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        _logger.warning(
          '⚠️ exact alarms not permitted; scheduled inexact for $id at $logTime',
        );
      } else {
        _logger.error('❌ Failed to schedule notification $id', e);
        rethrow;
      }
    }
  }

  @override
  Future<void> cancelNotification(String id) async {
    await _plugin.cancel(id.hashCode);
    _logger.info('🗑️ Cancelled notification $id');
  }

  @override
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    _logger.info('🧹 Cancelled all notifications');
  }

  @override
  Future<List<ScheduledNotification>> getPendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    _logger.info('📋 Pending notifications count: ${pending.length}');

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
    await _maybeLaunchExactAlarmSettings();
  }

  Future<void> _maybeLaunchExactAlarmSettings() async {
    if (_requestedExactAlarmIntent) return;
    if (!Platform.isAndroid) return;
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
