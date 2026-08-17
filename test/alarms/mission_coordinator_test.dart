import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/core/models/mission_stop_event.dart';
import 'package:ezanvakti/features/alarms/domain/mission_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_alarm_service.dart';
import 'fakes/fake_storage.dart';

void main() {
  late FakeAlarmService service;
  late FakeStorage storage;
  late MissionCoordinator coordinator;

  setUp(() {
    service = FakeAlarmService();
    storage = FakeStorage();
    coordinator = MissionCoordinator(alarmService: service, storage: storage);
  });

  final firedAt = DateTime(2026, 8, 17, 5, 0);

  test('resume: kuyruktaki durdurma olayi oturum acar', () async {
    service.pendingEvents = [
      MissionStopEvent(alarmId: 'sahur', stoppedAt: firedAt),
    ];
    final session = await coordinator.resume();
    expect(session, isNotNull);
    expect(session!.alarmId, 'sahur');
    expect(await storage.getMissionSession(), isNotNull);
  });

  test('resume: olay yoksa mevcut oturum korunur', () async {
    await storage.saveMissionSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    final session = await coordinator.resume();
    expect(session!.alarmId, 'sahur');
  });

  test('begin native tarafa haber verir', () async {
    await coordinator.begin('sahur');
    expect(service.begun, ['sahur']);
  });

  test('complete oturumu silip native temizler', () async {
    await storage.saveMissionSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    await coordinator.complete('sahur');
    expect(service.completed, ['sahur']);
    expect(await storage.getMissionSession(), isNull);
  });

  test('snooze limiti asilmadikca sayaci artirir', () async {
    await storage.saveMissionSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    const alarm = Alarm(
      id: 'sahur',
      kind: AlarmKind.fixed,
      mission: AlarmMission.math,
      maxSnoozes: 2,
    );
    expect(await coordinator.snooze(alarm), isTrue);
    expect((await storage.getMissionSession())!.snoozeUsed, 1);
    expect(await coordinator.snooze(alarm), isTrue);
    expect(await coordinator.snooze(alarm), isFalse);
    expect((await storage.getMissionSession())!.snoozeUsed, 2);
  });

  test('abort kademeyi yukseltir ve zinciri temizler', () async {
    await storage.saveMissionSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    await coordinator.abort('sahur', firedAt);
    expect(service.aborted, ['sahur']);
    expect(await storage.getMissionSession(), isNull);
    final state = await storage.getAbortState();
    expect(state.level, 1);
    expect(state.lastUsedAt, firedAt);
  });
}
