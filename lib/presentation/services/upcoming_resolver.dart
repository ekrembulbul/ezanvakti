import '../../core/models/alarm.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../core/utils/prayer_utils.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';

/// Ana ekrandaki "SIRADAKİ" kartının bir satırı: bildirim.
///
/// [prayerDate] vaktin günü — [time] ise tetiklenme anı. Sapmalı bildirimde
/// ikisi farklı güne düşebilir; atlama kimliği **vaktin gününden** üretildiği
/// için (planlayıcıyla aynı kural) ayrıca taşınır.
typedef UpcomingNotification = ({
  NotificationSetting setting,
  DateTime prayerDate,
  DateTime time,
});

/// Ana ekrandaki "SIRADAKİ" kartının bir satırı: alarm.
typedef UpcomingAlarm = ({Alarm alarm, DateTime time});

/// [now]'dan sonra tetiklenecek ilk bildirimi döner.
///
/// Bildirimin anı, vaktin kendisinden [NotificationSetting.minutesBefore] kadar
/// önce. Yalnızca açık ayarlar dikkate alınır; hiçbiri yaklaşmıyorsa `null`.
UpcomingNotification? resolveNextNotification({
  required List<NotificationSetting> settings,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
}) {
  UpcomingNotification? earliest;

  for (final day in prayerTimes) {
    for (final setting in settings) {
      if (!setting.isActive) continue;

      final prayerAt = PrayerUtils.getPrayerTime(day, setting.prayerType);
      final fireAt = prayerAt.subtract(
        Duration(minutes: setting.minutesBefore),
      );
      if (!fireAt.isAfter(now)) continue;

      if (earliest == null || fireAt.isBefore(earliest.time)) {
        earliest = (setting: setting, prayerDate: day.date, time: fireAt);
      }
    }
  }

  return earliest;
}

/// Her bildirim ayarının **kendi** bir sonraki tetiklenme anı.
///
/// [resolveNextNotification] listedeki en yakın tek örneği döner; burada
/// listedeki her satırın kendi anı gerekiyor (tek seferlik atlama o örneğe
/// uygulanıyor). Atlama uygulanmadan hesaplanır: kullanıcı tam da o örneği
/// atlamak ya da geri almak istiyor.
Map<String, DateTime> resolveNextFirePerNotification({
  required List<NotificationSetting> settings,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
}) {
  final result = <String, DateTime>{};

  for (final day in prayerTimes) {
    for (final setting in settings) {
      if (!setting.isActive) continue;

      final prayerAt = PrayerUtils.getPrayerTime(day, setting.prayerType);
      final fireAt = prayerAt.subtract(
        Duration(minutes: setting.minutesBefore),
      );
      if (!fireAt.isAfter(now)) continue;

      final key = notificationKey(setting);
      final current = result[key];
      if (current == null || fireAt.isBefore(current)) result[key] = fireAt;
    }
  }

  return result;
}

/// Bildirim ayarının kimliği: vakit + kaç dakika önce.
String notificationKey(NotificationSetting setting) =>
    '${setting.prayerType.name}-${setting.minutesBefore}';

/// [now]'dan sonra çalacak ilk alarmı döner.
///
/// Tetiklenme anı, bildirimlerin planlanmasıyla aynı kuralı kullanır
/// ([AlarmScheduler.computeNextFire]); ekranda yazan saat ile gerçekten çalacak
/// saat böylece ayrışmaz. Kapalı alarmlar atlanır.
UpcomingAlarm? resolveNextAlarm({
  required List<Alarm> alarms,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
}) {
  final byDate = <DateTime, PrayerTime>{
    for (final day in prayerTimes)
      DateTime(day.date.year, day.date.month, day.date.day): day,
  };

  UpcomingAlarm? earliest;

  for (final alarm in alarms) {
    if (!alarm.isActive) continue;

    final fire = AlarmScheduler.computeNextFire(
      alarm: alarm,
      now: now,
      prayerTimesByDate: byDate,
    );
    if (fire == null) continue;

    if (earliest == null || fire.isBefore(earliest.time)) {
      earliest = (alarm: alarm, time: fire);
    }
  }

  return earliest;
}
