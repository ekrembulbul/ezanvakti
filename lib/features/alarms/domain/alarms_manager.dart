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

/// [source]'un yeni kimlikli kopyası: etiket sonuna " (kopya)" eklenir,
/// kopya açık başlar. **Kaydetmez** — düzenleme ekranı kaydeder; kullanıcı
/// vazgeçerse kopya kalmaz.
Alarm duplicateOf(Alarm source, {required String newId}) => Alarm(
  id: newId,
  kind: source.kind,
  label: source.label.isEmpty ? '' : '${source.label} (kopya)',
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
