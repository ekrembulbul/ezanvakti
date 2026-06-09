import '../../../core/interfaces/alarm_service.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/alarm.dart';
import '../../../core/models/notification_setting.dart' show PrayerType;
import '../../../core/models/prayer_time.dart';

/// Alarmların bir sonraki tetiklenme anını hesaplar ve native [AlarmService] ile
/// planlar. Tekrarlı alarmlarda yalnızca "bir sonraki" çalış planlanır; alarm
/// çalıp kapatılınca (veya uygulama açılış/yenilemesinde) yeniden planlanır.
class AlarmScheduler {
  final AlarmService alarmService;
  final LocalStorage storage;

  AlarmScheduler({required this.alarmService, required this.storage});

  /// Kayıtlı tüm alarmlar için önce mevcut planları temizler, sonra aktif
  /// alarmların bir sonraki tetiklenmesini planlar.
  Future<void> scheduleAlarms({required List<PrayerTime> prayerTimes}) async {
    final alarms = await storage.getAlarms();

    // Boş olsa bile önce temizle (silinen alarmlar ortada kalmasın).
    await alarmService.cancelAllAlarms();
    if (alarms.isEmpty) return;

    final byDate = <DateTime, PrayerTime>{};
    for (final pt in prayerTimes) {
      byDate[_dateKey(pt.date)] = pt;
    }

    final now = DateTime.now();
    for (final alarm in alarms) {
      if (!alarm.isActive) continue;
      final fire = computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: byDate,
      );
      if (fire == null) continue;
      await alarmService.scheduleAlarm(
        id: alarm.id,
        scheduledTime: fire,
        label: alarm.label,
        soundId: alarm.soundId,
        vibrate: alarm.vibrate,
        snoozeEnabled: alarm.snoozeEnabled,
        snoozeMinutes: alarm.snoozeMinutes,
      );
    }
  }

  /// [now]'dan sonraki ilk geçerli tetiklenme anını döner; [searchDays] gün
  /// içinde uygun gün/vakit bulunamazsa null. Çıpalı alarmlar için ilgili günün
  /// vakti [prayerTimesByDate]'te yoksa o gün atlanır.
  static DateTime? computeNextFire({
    required Alarm alarm,
    required DateTime now,
    required Map<DateTime, PrayerTime> prayerTimesByDate,
    int searchDays = 8,
  }) {
    final today = _dateKey(now);
    for (var i = 0; i < searchDays; i++) {
      final day = today.add(Duration(days: i));
      if (!alarm.firesOnWeekday(day.weekday)) continue;

      DateTime? candidate;
      if (alarm.kind == AlarmKind.fixed) {
        candidate = DateTime(
          day.year,
          day.month,
          day.day,
          alarm.hour,
          alarm.minute,
        );
      } else {
        final pt = prayerTimesByDate[day];
        if (pt == null) continue;
        candidate = _anchorTime(
          pt,
          alarm.anchor,
        ).add(Duration(minutes: alarm.offsetMinutes));
      }

      if (candidate.isAfter(now)) return candidate;
    }
    return null;
  }

  static DateTime _anchorTime(PrayerTime pt, PrayerType anchor) {
    switch (anchor) {
      case PrayerType.fajr:
        return pt.fajr;
      case PrayerType.sunrise:
        return pt.sunrise;
      case PrayerType.dhuhr:
        return pt.dhuhr;
      case PrayerType.asr:
        return pt.asr;
      case PrayerType.maghrib:
        return pt.maghrib;
      case PrayerType.isha:
        return pt.isha;
    }
  }

  static DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
