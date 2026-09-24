import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';

import '../../../core/models/alarm.dart';
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

  /// Satır alt metnindeki çalma saati. "Ertelendi" öneki artık rozette
  /// (spec 2026-09-22 D4); burada yalnız saat yazılır.
  static String label(DateTime until, AppLocalizations l10n) =>
      l10n.snoozeRingsAt(DateFormat('HH:mm').format(until));
}
