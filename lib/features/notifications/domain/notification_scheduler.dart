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

  /// iOS uygulama başına en fazla ~64 bekleyen yerel bildirim tutar; bu sayıyı
  /// aşanların en uzaktakilerini sessizce atar. Bu yüzden en yakın olanlardan
  /// bu kadarını planlarız (öngörülemez OS davranışı yerine kontrollü kapama).
  static const int maxScheduledNotifications = 64;

  NotificationScheduler({
    required this.notificationService,
    required this.storage,
  });

  Future<void> scheduleNotifications({
    required Location location,
    required List<PrayerTime> prayerTimes,
  }) async {
    final logger = AppLogger();
    logger.debug(
      'Scheduling notifications for ${location.province}/${location.district} (${prayerTimes.length} days)',
    );

    final settings = await storage.getNotificationSettings();

    if (settings.isEmpty) {
      logger.warning('No notification settings found, skipping');
      return;
    }

    logger.debug('Found ${settings.length} notification settings');
    await notificationService.cancelAllNotifications();
    logger.debug('Cancelled all existing notifications');

    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: scheduleDaysAhead));

    // Pencere içindeki (şimdi .. +scheduleDaysAhead) aktif bildirimleri topla.
    final candidates = <_NotificationCandidate>[];
    final seenIds = <String>{};

    for (final prayerTime in prayerTimes) {
      for (final setting in settings) {
        if (!setting.isActive) continue;

        final prayerDateTime = _getPrayerDateTime(
          prayerTime,
          setting.prayerType,
        );
        if (prayerDateTime == null) continue;

        // Geçmişi ve pencere dışını ele.
        if (prayerDateTime.isBefore(now) || prayerDateTime.isAfter(cutoff)) {
          continue;
        }

        final notificationTime = prayerDateTime.subtract(
          Duration(minutes: setting.minutesBefore),
        );
        if (notificationTime.isBefore(now)) continue;

        final id = _generateNotificationId(
          prayerTime.date,
          setting.prayerType,
          setting.minutesBefore,
        );
        if (!seenIds.add(id)) continue; // ayni (gun,vakit,offset) tekrari

        candidates.add(
          _NotificationCandidate(
            id: id,
            notificationTime: notificationTime,
            title: _getNotificationTitle(setting),
            body: _getNotificationBody(setting, prayerDateTime),
          ),
        );
      }
    }

    // En yakın bildirimlerden iOS sınırı kadarını planla.
    candidates.sort((a, b) => a.notificationTime.compareTo(b.notificationTime));
    final toSchedule = candidates.take(maxScheduledNotifications).toList();

    for (final candidate in toSchedule) {
      await notificationService.scheduleNotification(
        id: candidate.id,
        scheduledTime: candidate.notificationTime,
        title: candidate.title,
        body: candidate.body,
      );
      logger.debug(
        '${_formatTime(candidate.notificationTime)} icin bildirim planlandi (${candidate.id})',
      );
    }

    logger.debug(
      'Scheduled ${toSchedule.length}/${candidates.length} notifications '
      '(tavan $maxScheduledNotifications, pencere $scheduleDaysAhead gun)',
    );
  }

  Future<void> rescheduleNotifications({
    required Location location,
    required List<PrayerTime> prayerTimes,
  }) async {
    await scheduleNotifications(location: location, prayerTimes: prayerTimes);
  }

  /// (gün, vakit, offset) için 32-bit'e sığan, çakışmaya dayanıklı sayısal bir
  /// kimlik üretir. Eski "String + hashCode" yöntemi teorik olarak çakışabiliyordu;
  /// bu şema benzersizliği garanti eder ve id'den geri çözülebilir.
  String _generateNotificationId(
    DateTime date,
    PrayerType prayerType,
    int minutesBefore,
  ) {
    final dayOrdinal =
        DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final id = dayOrdinal * 10000 + prayerType.index * 1000 + minutesBefore;
    return id.toString();
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
      return '${_getPrayerName(setting.prayerType)} vakti yaklaşıyor';
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

  String _formatTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<bool> requestPermission() async {
    return await notificationService.requestPermission();
  }
}

class _NotificationCandidate {
  final String id;
  final DateTime notificationTime;
  final String title;
  final String body;

  const _NotificationCandidate({
    required this.id,
    required this.notificationTime,
    required this.title,
    required this.body,
  });
}
