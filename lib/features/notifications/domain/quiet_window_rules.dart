import '../../../core/models/notification_setting.dart' show PrayerType;
import '../../../core/models/quiet_window.dart';

/// Bir bildirim anının hangi sessiz pencereye düştüğünü çözer.
///
/// Saf: zamanı ve pencereleri dışarıdan alır. Planlayıcı bunu aday üretirken
/// çağırır — karar **tetiklenme anına** göre verilir, vaktin kendisine göre
/// değil: "45 dk önce" hatırlatması pencere dışındaysa sesli kalmalı.
class QuietWindowRules {
  const QuietWindowRules._();

  static QuietMode? modeFor({
    required List<QuietWindow> windows,
    required DateTime fireAt,
    required PrayerType prayerType,
    required DateTime prayerAt,
  }) {
    QuietMode? result;
    for (final window in windows) {
      if (!window.isActive) continue;
      if (!window.matchesPrayer(prayerType, prayerAt)) continue;
      if (!window.contains(fireAt, prayerAt)) continue;
      // Çakışmada daha güçlü olan kazanır: hiç planlamamak, sessiz
      // planlamaktan daha kapsayıcı bir istektir.
      if (window.mode == QuietMode.skip) return QuietMode.skip;
      result = QuietMode.silent;
    }
    return result;
  }
}
