import '../../core/models/alarm.dart';
import '../../core/models/mission_session.dart';
import '../../core/models/derived_time.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/skipped_occurrence.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
import '../../features/notifications/domain/notification_scheduler.dart';
import '../../features/notifications/domain/notification_time_rules.dart';

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

  final occurrences = resolveNextOccurrencePerNotification(
    settings: settings,
    prayerTimes: prayerTimes,
    now: now,
  );
  for (final occurrence in occurrences.values) {
    if (earliest == null || occurrence.time.isBefore(earliest.time)) {
      earliest = occurrence;
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
}) => resolveNextOccurrencePerNotification(
  settings: settings,
  prayerTimes: prayerTimes,
  now: now,
).map((key, occurrence) => MapEntry(key, occurrence.time));

/// Her aktif ayarın atlanmadan önceki ilk örneği, kaynak vakit günüyle birlikte.
///
/// Gün filtresi ve türetilmiş vakit hesabı planlayıcıyla aynıdır. Kaynak gün,
/// gece noktalarında ve önceki güne taşan sapmalarda atlama kimliğini korur.
Map<String, UpcomingNotification> resolveNextOccurrencePerNotification({
  required List<NotificationSetting> settings,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
}) {
  final result = <String, UpcomingNotification>{};
  final byDate = <DateTime, PrayerTime>{
    for (final day in prayerTimes)
      DateTime(day.date.year, day.date.month, day.date.day): day,
  };
  final orderedSettings = NotificationTimeRules.prioritizeSettings(settings);

  for (final setting in orderedSettings) {
    if (!setting.isActive) continue;

    for (final day in prayerTimes) {
      final prayerAt = NotificationTimeRules.pointTime(
        setting: setting,
        day: day,
        prayerTimesByDate: byDate,
      );
      if (prayerAt == null) continue;
      final fireAt = prayerAt.subtract(
        Duration(minutes: setting.minutesBefore),
      );
      if (!fireAt.isAfter(now)) continue;

      final key = notificationKey(setting);
      final current = result[key];
      if (current == null || fireAt.isBefore(current.time)) {
        result[key] = (setting: setting, prayerDate: day.date, time: fireAt);
      }
    }
  }

  return result;
}

/// Bildirim ayarının kimliği: vakit + kaç dakika önce + günler.
///
/// Günler kimliğin parçası: aynı vakit ve sapmada "her gün" ve "yalnızca
/// Cuma" satırları yan yana durabiliyor.
String notificationKey(NotificationSetting setting) =>
    '${setting.prayerType.name}-${setting.derivedKind?.storageValue ?? ''}-'
    '${setting.minutesBefore}-${setting.weekdaysCsv}';

/// Görünen örneği planlayıcının sayısal kimliğiyle atlama kaydına dönüştürür.
/// Kimlik, tetiklenme tarihi yerine vaktin kaynak gününden üretilir.
SkippedOccurrence notificationOccurrence(UpcomingNotification item) =>
    SkippedOccurrence(
      kind: SkipKind.notification,
      reference: NotificationScheduler.notificationIdFor(
        date: item.prayerDate,
        pointIndex: NotificationScheduler.pointIndexOf(item.setting),
        minutesBefore: item.setting.minutesBefore,
      ),
      fireAt: item.time,
    );

/// [now]'dan sonra çalacak ilk alarmı döner.
///
/// Tetiklenme anı, bildirimlerin planlanmasıyla aynı kuralı kullanır
/// ([AlarmScheduler.computeNextFire]); ekranda yazan saat ile gerçekten çalacak
/// saat böylece ayrışmaz. Kapalı alarmlar atlanır.
UpcomingAlarm? resolveNextAlarm({
  required List<Alarm> alarms,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
  List<MissionSession> missionSessions = const [],
}) {
  final byDate = <DateTime, PrayerTime>{
    for (final day in prayerTimes)
      DateTime(day.date.year, day.date.month, day.date.day): day,
  };

  UpcomingAlarm? earliest;

  for (final alarm in alarms) {
    if (!alarm.isActive) continue;

    final snoozedUntil = MissionSession.pendingForAlarm(
      missionSessions,
      alarm.id,
    )?.snoozedUntil;
    final fire = snoozedUntil?.isAfter(now) == true
        ? snoozedUntil
        : AlarmScheduler.computeNextFire(
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
