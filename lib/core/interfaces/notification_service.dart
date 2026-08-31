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

  /// [soundId] `NotificationSounds` değerlerinden biri ya da null (sistem).
  /// [silent] doğruysa ses hiç çalmaz (sessiz pencere ya da "Sessiz" seçimi).
  /// [timeSensitive] doğruysa bildirim Odak modunda da anında gösterilir —
  /// sessiz anahtarını **delmez**.
  Future<void> scheduleNotification({
    required String id,
    required DateTime scheduledTime,
    required String title,
    required String body,
    String? soundId,
    bool silent = false,
    bool timeSensitive = true,
  });

  Future<void> cancelNotification(String id);

  Future<void> cancelAllNotifications();

  Future<List<ScheduledNotification>> getPendingNotifications();

  /// Android-specific: opens exact alarm settings if available.
  /// No-op on other platforms.
  Future<void> openExactAlarmSettings();
}
