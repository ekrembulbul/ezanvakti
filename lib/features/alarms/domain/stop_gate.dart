import '../../../core/config/mission_tuning.dart';
import '../../../core/models/alarm.dart';
import '../../../core/models/alarm_mission.dart';
import '../../../core/models/mission_session.dart';
import 'snooze_options.dart';

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

    // Görevli yolda da bayatlık sınırı: dünkü oturum bugünkü açılışta görev
    // ekranı açmamalı (31 Ağustos olayı). Eşik, zincirin sert tavanıyla aynı
    // pencere — tavan dolduktan sonra görev borcu da düşer.
    if (!now.isBefore(_staleAt(session))) return StopDecision.closeAndRearm;

    return hasChoice ? StopDecision.showStopScreen : StopDecision.openMission;
  }

  /// Alarmı kapatma girişimi önce görev ekranına uğramalı mı?
  ///
  /// Görevli alarmda görev borcu, alarmı listeden pasife alarak ya da tek
  /// seferlik kapatarak atlanabiliyordu; kapı yalnızca görev ekranındaydı.
  /// Bu sorgu aynı kapıyı o çağrı noktalarına da taşır — kullanıcı görevi
  /// yapar ya da kademeli acil çıkışı kullanır.
  ///
  /// [decide] ile kasıtlı olarak ayrıdır: erteleme sürerken [decide] ekran
  /// açmaz ([StopDecision.none]) ama borç durur, dolayısıyla kapı kapalıdır.
  /// Silme bu kapıya tabi değildir — kalıcı ve niyetli bir eylemdir.
  static bool blocksDismissal({
    required Alarm alarm,
    required Iterable<MissionSession> sessions,
    required DateTime now,
  }) {
    if (!alarm.mission.requiresGate) return false;
    final session = MissionSession.pendingForAlarm(sessions, alarm.id);
    if (session == null) return false;
    // Tavan dolduysa borç zaten düşmüştür; kapı da açılır.
    return now.isBefore(_staleAt(session));
  }

  /// Görev borcunun düştüğü an: zincirin sert tavanıyla aynı pencere.
  static DateTime _staleAt(MissionSession session) =>
      session.chainDeadlineAt ??
      session.firedAt.add(
        const Duration(minutes: MissionTuning.chainDeadlineMinutes),
      );

  /// Kalan erteleme hakkı. `null` = sınırsız; erteleme kapalıysa 0.
  static int? snoozeRemaining(Alarm alarm, MissionSession session) {
    if (!alarm.snoozeEnabled) return 0;
    final limit = effectiveSnoozeLimit(alarm);
    if (limit == null) return null;
    final left = limit - session.snoozeUsed;
    return left < 0 ? 0 : left;
  }
}
