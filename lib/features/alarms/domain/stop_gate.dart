import '../../../core/config/mission_tuning.dart';
import '../../../core/models/alarm.dart';
import '../../../core/models/alarm_mission.dart';
import '../../../core/models/mission_session.dart';

/// Alarm durdurulduktan sonra ne olacağı.
enum StopDecision {
  /// Ortada çalan alarm yok (ertelenmiş); hiçbir şey yapma.
  none,

  /// Oturumu kapat, alarmları yeniden kur; ekran açma.
  closeAndRearm,

  /// Ara ekran: görevlide "Görevi yap / Ertele", görevsizde "Tamam / Ertele".
  showStopScreen,

  /// Görevli alarm, erteleme hakkı yok: doğrudan görev ekranı.
  openMission,
}

/// Ara ekranın kapısı. Spec 2026-08-30 §4 tablosu; saf, zamanı dışarıdan alır.
///
/// Kural: ekran **yalnızca gerçek bir seçim varsa** açılır (D6). Tek düğmelik
/// ekran uykulu kullanıcıya fazladan bir dokunuş.
class StopGate {
  const StopGate._();

  static StopDecision decide({
    required Alarm? alarm,
    required MissionSession session,
    required DateTime now,
  }) {
    final snoozedUntil = session.snoozedUntil;
    if (snoozedUntil != null && snoozedUntil.isAfter(now)) {
      return StopDecision.none;
    }
    if (alarm == null) return StopDecision.closeAndRearm;

    final remaining = snoozeRemaining(alarm, session);
    final hasChoice = remaining == null || remaining > 0;

    if (!alarm.mission.requiresGate) {
      if (!hasChoice) return StopDecision.closeAndRearm;
      // Görevsizde durdurma kesin (D3); saatler sonra eski bir Ertele
      // ekranıyla karşılaşılmasın (D7).
      final expiresAt = session.stoppedAt.add(
        const Duration(seconds: MissionTuning.stopScreenSeconds),
      );
      if (!now.isBefore(expiresAt)) return StopDecision.closeAndRearm;
      return StopDecision.showStopScreen;
    }

    return hasChoice ? StopDecision.showStopScreen : StopDecision.openMission;
  }

  /// Kalan erteleme hakkı. `null` = sınırsız; erteleme kapalıysa 0.
  static int? snoozeRemaining(Alarm alarm, MissionSession session) {
    if (!alarm.snoozeEnabled) return 0;
    final limit = alarm.maxSnoozes;
    if (limit == null) return null;
    final left = limit - session.snoozeUsed;
    return left < 0 ? 0 : left;
  }
}
