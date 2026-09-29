import '../../core/models/alarm.dart';
import '../../core/models/mission_session.dart';
import '../../core/models/derived_time.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/skipped_occurrence.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
import '../../features/notifications/domain/notification_scheduler.dart';
import '../../features/notifications/domain/notification_time_rules.dart';
import '../../features/notifications/domain/skip_rules.dart';

/// Bir bildirim ayarının sıradaki örneği.
///
/// [prayerDate] vaktin günü — [time] ise tetiklenme anı. Sapmalı bildirimde
/// ikisi farklı güne düşebilir; atlama kimliği **vaktin gününden** üretildiği
/// için (planlayıcıyla aynı kural) ayrıca taşınır.
typedef UpcomingNotification = ({
  NotificationSetting setting,
  DateTime prayerDate,
  DateTime time,
});

/// Her aktif ayarın sıradaki örneği, kaynak vakit günüyle birlikte.
///
/// Gün filtresi ve türetilmiş vakit hesabı planlayıcıyla aynıdır. Kaynak gün,
/// gece noktalarında ve önceki güne taşan sapmalarda atlama kimliğini korur.
/// [skips] boşken atlanmış örnek de döner: satır ve "Yalnızca bu sefer" tam
/// o örneği gösterir. Sıralama anahtarı için [skips] verilir; atlanan örnek
/// planlayıcıyla aynı kimlikle (`notificationIdFor`) geçilir.
Map<String, UpcomingNotification> resolveNextOccurrencePerNotification({
  required List<NotificationSetting> settings,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
  Set<SkippedOccurrence> skips = const {},
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
      if (skips.isNotEmpty &&
          isSkipped(
            skips,
            kind: SkipKind.notification,
            reference: NotificationScheduler.notificationIdFor(
              date: day.date,
              pointIndex: NotificationScheduler.pointIndexOf(setting),
              minutesBefore: setting.minutesBefore,
            ),
            fireAt: fireAt,
          )) {
        continue;
      }

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

/// Her açık alarmın **gerçekten** çalacağı sıradaki an: atlanan çalış geçilir,
/// ertelenmiş alarm erteleme bitişini alır.
///
/// Yalnız "Sıradaki çalışa göre" sıralamanın anahtarıdır. Satırın gösterdiği
/// ve atlamanın uygulandığı örnek atlama uygulanmadan hesaplanır; kullanıcı
/// tam da o örneği atlıyor ya da geri alıyor. Kapalı alarmın anahtarı yoktur,
/// liste sonuna düşer.
Map<String, DateTime> resolveEffectiveNextFirePerAlarm({
  required List<Alarm> alarms,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
  List<MissionSession> missionSessions = const [],
  Set<SkippedOccurrence> skips = const {},
}) {
  final byDate = <DateTime, PrayerTime>{
    for (final day in prayerTimes)
      DateTime(day.date.year, day.date.month, day.date.day): day,
  };
  final result = <String, DateTime>{};
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
            skips: skips,
          );
    if (fire != null) result[alarm.id] = fire;
  }
  return result;
}
