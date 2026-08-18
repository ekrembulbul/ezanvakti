import 'package:intl/intl.dart';

import '../../../core/models/alarm.dart';
import '../../../core/models/alarm_mission.dart';
import '../../../core/models/mission_session.dart';

/// Bir alarmın ertelenmiş olup olmadığını ve arayüzde ne yazacağını çözer.
///
/// Erteleme bilgisi görev ekranında bir onay sayfası olarak değil, alarmın
/// kendi satırında ve ana ekrandaki sıradaki kartında gösterilir.
class SnoozeNotice {
  /// [alarm] şu an ertelenmiş mi?
  static DateTime? snoozedUntilFor(MissionSession? session, Alarm alarm) {
    if (session == null || !session.isPending) return null;
    if (session.alarmId != alarm.id) return null;
    return session.snoozedUntil;
  }

  /// Satır alt metninde gösterilecek erteleme cümlesi.
  static String label(DateTime until) =>
      'Ertelendi · ${DateFormat('HH:mm').format(until)}\'te çalacak';

  /// Alarm kapatılabilir mi?
  ///
  /// Ertelenmiş **ve görevli** bir alarm kapatılamaz: kapatmak, görevi yapmadan
  /// alarmdan kurtulmanın arka kapısı olurdu. Görevsiz alarm her zaman
  /// kapatılabilir.
  static bool canDisable(MissionSession? session, Alarm alarm) {
    if (!alarm.mission.requiresGate) return true;
    return snoozedUntilFor(session, alarm) == null;
  }
}
