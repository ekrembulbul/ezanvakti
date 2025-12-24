import '../../../core/interfaces/notification_service.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/models/location.dart';
import '../../../core/utils/app_logger.dart';

class NotificationScheduler {
  final NotificationService notificationService;
  final LocalStorage storage;

  static const int scheduleDaysAhead = 7;

  NotificationScheduler({
    required this.notificationService,
    required this.storage,
  });

  Future<void> scheduleNotifications({
    required Location location,
    required List<PrayerTime> prayerTimes,
  }) async {
    final logger = AppLogger();
    logger.info(
      '🔔 Scheduling notifications for ${location.province}/${location.district} (${prayerTimes.length} days)',
    );

    final settings = await storage.getNotificationSettings();

    if (settings.isEmpty) {
      logger.warning('⚠️ No notification settings found, skipping');
      return;
    }

    logger.info('📋 Found ${settings.length} notification settings');
    await notificationService.cancelAllNotifications();
    logger.info('🗑️ Cancelled all existing notifications');

    final scheduledIds = <String>{};

    for (final prayerTime in prayerTimes) {
      for (final setting in settings) {
        if (!setting.isActive) continue;

        final prayerDateTime = _getPrayerDateTime(
          prayerTime,
          setting.prayerType,
        );
        if (prayerDateTime == null) continue;

        if (prayerDateTime.isBefore(DateTime.now())) continue;

        final notificationTime = prayerDateTime.subtract(
          Duration(minutes: setting.minutesBefore),
        );

        if (notificationTime.isBefore(DateTime.now())) continue;

        final notificationId = _generateNotificationId(
          prayerTime.date,
          setting.prayerType,
          setting.minutesBefore,
        );

        if (scheduledIds.contains(notificationId)) continue;

        final title = _getNotificationTitle(setting);
        final body = _getNotificationBody(setting, prayerDateTime);

        await notificationService.scheduleNotification(
          id: notificationId,
          scheduledTime: notificationTime,
          title: title,
          body: body,
        );

        scheduledIds.add(notificationId);
      }
    }

    logger.info('✅ Scheduled ${scheduledIds.length} notifications');
  }

  Future<void> rescheduleNotifications({
    required Location location,
    required List<PrayerTime> prayerTimes,
  }) async {
    await scheduleNotifications(location: location, prayerTimes: prayerTimes);
  }

  String _generateNotificationId(
    DateTime date,
    PrayerType prayerType,
    int minutesBefore,
  ) {
    final dateStr =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final prayerStr = prayerType.name;
    final offsetStr = minutesBefore.toString().padLeft(3, '0');
    return '$dateStr-$prayerStr-$offsetStr';
  }

  DateTime? _getPrayerDateTime(PrayerTime prayerTime, PrayerType prayerType) {
    switch (prayerType) {
      case PrayerType.fajr:
        return prayerTime.fajr;
      case PrayerType.sunrise:
        return prayerTime.sunrise;
      case PrayerType.dhuhr:
        return prayerTime.dhuhr;
      case PrayerType.asr:
        return prayerTime.asr;
      case PrayerType.maghrib:
        return prayerTime.maghrib;
      case PrayerType.isha:
        return prayerTime.isha;
    }
  }

  String _getNotificationTitle(NotificationSetting setting) {
    if (setting.minutesBefore == 0) {
      return _getPrayerName(setting.prayerType);
    } else {
      return '${_getPrayerName(setting.prayerType)} Yaklaşıyor';
    }
  }

  String _getNotificationBody(
    NotificationSetting setting,
    DateTime prayerTime,
  ) {
    final timeStr =
        '${prayerTime.hour.toString().padLeft(2, '0')}:${prayerTime.minute.toString().padLeft(2, '0')}';

    if (setting.minutesBefore == 0) {
      return '$timeStr - ${_getPrayerName(setting.prayerType)} vakti girdi';
    } else {
      return '$timeStr - ${_getPrayerName(setting.prayerType)} vaktine ${setting.minutesBefore} dakika kaldı';
    }
  }

  String _getPrayerName(PrayerType type) {
    switch (type) {
      case PrayerType.fajr:
        return 'İmsak';
      case PrayerType.sunrise:
        return 'Güneş';
      case PrayerType.dhuhr:
        return 'Öğle';
      case PrayerType.asr:
        return 'İkindi';
      case PrayerType.maghrib:
        return 'Akşam';
      case PrayerType.isha:
        return 'Yatsı';
    }
  }

  Future<List<ScheduledNotification>> getPendingNotifications() async {
    return await notificationService.getPendingNotifications();
  }

  Future<void> cancelAllNotifications() async {
    await notificationService.cancelAllNotifications();
  }

  Future<bool> hasPermission() async {
    return await notificationService.isPermissionGranted();
  }

  Future<bool> requestPermission() async {
    return await notificationService.requestPermission();
  }
}
