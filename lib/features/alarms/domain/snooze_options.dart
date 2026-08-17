import '../../../core/models/alarm.dart';
import '../../../core/models/alarm_mission.dart';

/// Kullanıcıya sunulan erteleme süreleri (dk). Kapalı liste.
const List<int> kSnoozeMinuteOptions = [5, 10, 15, 20];

/// Kullanıcıya sunulan erteleme sayıları. Görev kapalıysa listeye ayrıca
/// "Sınırsız" (`null`) eklenir.
const List<int> kMaxSnoozeOptions = [1, 2, 3, 5];

/// Erteleme limitini kurallara uydurur.
///
/// - Erteleme kapalıysa limit anlamsız: `null`.
/// - Görev açıksa sınırsız erteleme kapıyı işlevsiz bırakır (kullanıcı görevi
///   hiç yapmadan sonsuza kadar erteleyebilirdi); en büyük sonlu seçeneğe
///   düşürülür.
Alarm normalizeAlarmSnoozeLimit(Alarm alarm) {
  if (!alarm.snoozeEnabled) {
    if (alarm.maxSnoozes == null) return alarm;
    // `copyWith` null'i "dokunma" saydigi icin temizlemek constructor ister.
    return Alarm(
      id: alarm.id,
      kind: alarm.kind,
      label: alarm.label,
      isActive: alarm.isActive,
      hour: alarm.hour,
      minute: alarm.minute,
      anchor: alarm.anchor,
      offsetMinutes: alarm.offsetMinutes,
      weekdays: alarm.weekdays,
      soundId: alarm.soundId,
      vibrate: alarm.vibrate,
      snoozeEnabled: alarm.snoozeEnabled,
      snoozeMinutes: alarm.snoozeMinutes,
      mission: alarm.mission,
      missionLevel: alarm.missionLevel,
    );
  }
  if (alarm.mission.requiresGate && alarm.maxSnoozes == null) {
    return alarm.copyWith(maxSnoozes: kMaxSnoozeOptions.last);
  }
  return alarm;
}
