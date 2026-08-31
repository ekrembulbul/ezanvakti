import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/alarm.dart';

/// Alarmların depolama (CRUD) giriş noktası. Planlama [AlarmScheduler] ile,
/// tetikleme native [AlarmService] ile yapılır.
class AlarmsManager {
  final LocalStorage storage;

  AlarmsManager({required this.storage});

  Future<List<Alarm>> getAlarms() => storage.getAlarms();

  /// Ekler veya (aynı id ise) günceller.
  Future<void> save(Alarm alarm) => storage.saveAlarm(alarm);

  Future<void> delete(String id) => storage.deleteAlarm(id);

  Future<void> setActive(Alarm alarm, bool isActive) =>
      storage.saveAlarm(alarm.copyWith(isActive: isActive));
}

/// [source]'un yeni kimlikli kopyası; kopya açık başlar. **Kaydetmez** —
/// düzenleme ekranı kaydeder; kullanıcı vazgeçerse kopya kalmaz.
///
/// [copyLabel] etiketi "(kopya)" gibi bir ekle sarar; çeviri çağırandan gelir.
Alarm duplicateOf(
  Alarm source, {
  required String newId,
  required String Function(String label) copyLabel,
}) => Alarm(
  id: newId,
  kind: source.kind,
  label: source.label.isEmpty ? '' : copyLabel(source.label),
  isActive: true,
  hour: source.hour,
  minute: source.minute,
  anchor: source.anchor,
  offsetMinutes: source.offsetMinutes,
  weekdays: source.weekdays,
  soundId: source.soundId,
  vibrate: source.vibrate,
  snoozeEnabled: source.snoozeEnabled,
  snoozeMinutes: source.snoozeMinutes,
  mission: source.mission,
  missionLevel: source.missionLevel,
  qrPayload: source.qrPayload,
  maxSnoozes: source.maxSnoozes,
);
