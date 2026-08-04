import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_theme.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Belirli bir id'de patlayan, digerlerinde basarili olan servis.
class _FlakyAlarmService implements AlarmService {
  final List<String> scheduled = [];
  int cancelAllCount = 0;

  @override
  Future<void> cancelAllAlarms() async => cancelAllCount++;

  @override
  Future<void> scheduleAlarm({
    required String id,
    required DateTime scheduledTime,
    required String label,
    required String soundId,
    required bool vibrate,
    required bool snoozeEnabled,
    required int snoozeMinutes,
    required AlarmTheme theme,
  }) async {
    if (id == 'patlayan') {
      throw PlatformException(code: 'schedule_failed', message: 'izin yok');
    }
    scheduled.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StorageWithAlarms implements LocalStorage {
  final List<Alarm> alarms;

  _StorageWithAlarms(this.alarms);

  @override
  Future<List<Alarm>> getAlarms() async => alarms;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Alarm fixed(String id, int hour) =>
      Alarm(id: id, kind: AlarmKind.fixed, hour: hour, minute: 0);

  test('Bir alarm planlanamazsa digerleri planlanmaya devam eder', () async {
    final service = _FlakyAlarmService();
    final scheduler = AlarmScheduler(
      alarmService: service,
      storage: _StorageWithAlarms([fixed('patlayan', 6), fixed('saglam', 7)]),
    );

    // Yakalanmamis istisna firlatmamali.
    await scheduler.scheduleAlarms(prayerTimes: const []);

    expect(service.scheduled, ['saglam']);
  });

  test('Alarm listesi bos olsa da mevcut planlar temizlenir', () async {
    final service = _FlakyAlarmService();
    final scheduler = AlarmScheduler(
      alarmService: service,
      storage: _StorageWithAlarms([]),
    );

    await scheduler.scheduleAlarms(prayerTimes: const []);

    expect(service.cancelAllCount, 1);
  });

  test('Pasif alarmlar planlanmaz', () async {
    final service = _FlakyAlarmService();
    final scheduler = AlarmScheduler(
      alarmService: service,
      storage: _StorageWithAlarms([
        const Alarm(
          id: 'pasif',
          kind: AlarmKind.fixed,
          hour: 6,
          isActive: false,
        ),
        fixed('aktif', 7),
      ]),
    );

    await scheduler.scheduleAlarms(prayerTimes: const []);

    expect(service.scheduled, ['aktif']);
  });
}
