import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/alarm.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/skipped_occurrence.dart';
import 'alarm_scheduler.dart';

/// Alarmların depolama (CRUD) giriş noktası. Planlama [AlarmScheduler] ile,
/// tetikleme native [AlarmService] ile yapılır.
class AlarmsManager {
  final AlarmScheduler scheduler;
  LocalStorage get storage => scheduler.storage;

  AlarmsManager({required this.scheduler});

  Future<List<Alarm>> getAlarms() => storage.getAlarms();

  /// Ekler veya (aynı id ise) günceller. Tek seferlik alarmın hedef günü
  /// burada belirlenir ([AlarmScheduler.onceDateForSave]); [prayerTimes] ve
  /// [skips] bu yüzden zorunlu — verilmezse çıpalı alarmın günü bulunamaz,
  /// atlanan örnek hedef seçilirdi.
  Future<void> save(
    Alarm alarm, {
    required List<PrayerTime> prayerTimes,
    required Set<SkippedOccurrence> skips,
  }) async => scheduler.saveDefinition(
    await scheduler.onceDateForSave(
      alarm,
      prayerTimes: prayerTimes,
      skips: skips,
    ),
  );

  Future<void> delete(String id) => scheduler.deleteDefinition(id);

  /// Açılan tek seferlik alarm sıradaki uygun güne kurulur (eski hedef gün
  /// geçmiş olabilir); kapatırken hedef gün olduğu gibi kalır.
  Future<void> setActive(
    Alarm alarm,
    bool isActive, {
    required List<PrayerTime> prayerTimes,
    required Set<SkippedOccurrence> skips,
  }) {
    final changed = alarm.copyWith(isActive: isActive);
    return scheduler.saveDefinition(
      isActive
          ? scheduler.withOnceDate(
              changed,
              prayerTimes: prayerTimes,
              skips: skips,
            )
          : changed,
    );
  }
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
  isOnce: source.isOnce,
  onceDate: source.onceDate,
  soundId: source.soundId,
  vibrate: source.vibrate,
  snoozeEnabled: source.snoozeEnabled,
  snoozeMinutes: source.snoozeMinutes,
  mission: source.mission,
  missionLevel: source.missionLevel,
  qrPayload: source.qrPayload,
  maxSnoozes: source.maxSnoozes,
);
