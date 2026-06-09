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
