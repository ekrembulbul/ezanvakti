import '../models/notification_setting.dart';

class ScheduledNotification {
  final String id;
  final DateTime scheduledTime;
  final PrayerType prayerType;
  final int minutesBefore;

  const ScheduledNotification({
    required this.id,
    required this.scheduledTime,
    required this.prayerType,
    required this.minutesBefore,
  });
}

abstract class NotificationService {
  Future<void> init();

  Future<bool> requestPermission();

  Future<bool> isPermissionGranted();

  Future<void> scheduleNotification({
    required String id,
    required DateTime scheduledTime,
    required String title,
    required String body,
  });

  Future<void> cancelNotification(String id);

  Future<void> cancelAllNotifications();

  Future<List<ScheduledNotification>> getPendingNotifications();

  /// Android-specific: opens exact alarm settings if available.
  /// No-op on other platforms.
  Future<void> openExactAlarmSettings();
}
