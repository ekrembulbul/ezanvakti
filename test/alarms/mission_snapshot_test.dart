import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/features/alarms/domain/mission_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import 'fakes/fake_alarm_service.dart';

class _UnavailableSessionCache extends FakeStorage {
  @override
  Future<MissionSession?> getMissionSession() async =>
      throw StateError('Legacy cache unavailable');
  @override
  Future<void> saveMissionSession(MissionSession? value) async =>
      throw StateError('Legacy cache unavailable');
}

class _ExactDeadlineService extends FakeAlarmService {
  final DateTime deadline;
  _ExactDeadlineService(this.deadline);
  @override
  Future<void> beginMission(String id, {DateTime? firedAt}) async {
    final session = (await getMissionSessions()).single;
    await seedSession(
      session.copyWith(deadlineAt: deadline, clearSnoozedUntil: true),
    );
  }
}

class _CleanupFailureService extends FakeAlarmService {
  bool failCleanup = true;
  @override
  Future<void> abortMission(String id, {DateTime? firedAt}) async {
    await super.abortMission(id, firedAt: firedAt);
    if (failCleanup) throw StateError('Injected cleanup failure');
  }
}

void main() {
  test(
    'Abort retries native cleanup after the pending snapshot is gone',
    () async {
      final service = _CleanupFailureService();
      final storage = FakeStorage();
      final now = DateTime.now();
      await service.seedSession(MissionSession(alarmId: 'a', firedAt: now));
      final coordinator = MissionCoordinator(
        alarmService: service,
        storage: storage,
      );
      await expectLater(
        coordinator.abort('a', now, firedAt: now),
        throwsStateError,
      );
      service.failCleanup = false;
      await coordinator.abort('a', now, firedAt: now);
      await coordinator.abort('a', now, firedAt: now);
      expect(service.aborted, hasLength(3));
      expect((await storage.getAbortState()).level, 1);
    },
  );

  test('Stale screen completion leaves a newer occurrence untouched', () async {
    final service = FakeAlarmService();
    final now = DateTime.now();
    await service.seedSession(MissionSession(alarmId: 'a', firedAt: now));
    final coordinator = MissionCoordinator(
      alarmService: service,
      storage: FakeStorage(),
    );
    await coordinator.complete(
      'a',
      firedAt: now.subtract(const Duration(days: 1)),
    );
    expect(service.completed, isEmpty);
    expect((await service.getMissionSessions()).single.firedAt, now);
  });
  test(
    'Native pending mission survives unavailable Flutter session cache',
    () async {
      final service = FakeAlarmService();
      final fire = DateTime.now();
      await service.seedSession(MissionSession(alarmId: 'a', firedAt: fire));
      final coordinator = MissionCoordinator(
        alarmService: service,
        storage: _UnavailableSessionCache(),
      );
      expect((await coordinator.resume()).session?.alarmId, 'a');
      expect((await coordinator.resume()).session?.firedAt, fire);
    },
  );

  test('A snoozed alarm does not hide another actionable mission', () async {
    final service = FakeAlarmService();
    final now = DateTime.now();
    await service.seedSession(
      MissionSession(
        alarmId: 'a',
        firedAt: now.subtract(const Duration(minutes: 1)),
        snoozedUntil: now.add(const Duration(minutes: 5)),
      ),
    );
    await service.seedSession(MissionSession(alarmId: 'b', firedAt: now));
    final coordinator = MissionCoordinator(
      alarmService: service,
      storage: FakeStorage(),
    );
    expect((await coordinator.resume()).session?.alarmId, 'b');
    await coordinator.complete('b');
    expect((await service.getMissionSessions()).single.alarmId, 'a');
  });

  test(
    'Begin uses the native deadline instead of starting a Flutter timeout',
    () async {
      final deadline = DateTime.now().add(const Duration(seconds: 47));
      final service = _ExactDeadlineService(deadline);
      await service.seedSession(
        MissionSession(alarmId: 'a', firedAt: DateTime.now()),
      );
      final coordinator = MissionCoordinator(
        alarmService: service,
        storage: FakeStorage(),
      );
      await coordinator.resume();
      expect(await coordinator.begin('a', AlarmMission.qr), deadline);
    },
  );

  test(
    'Completing another mission preserves every snoozed native session',
    () async {
      final now = DateTime.now();
      final service = FakeAlarmService();
      final coordinator = MissionCoordinator(
        alarmService: service,
        storage: FakeStorage(),
      );
      for (final id in ['a', 'b', 'c']) {
        await service.seedSession(MissionSession(alarmId: id, firedAt: now));
      }
      for (final id in ['a', 'b']) {
        await coordinator.resume(alarmId: id);
        expect(
          await coordinator.snooze(
            Alarm(
              id: id,
              kind: AlarmKind.fixed,
              mission: AlarmMission.qr,
              maxSnoozes: 1,
            ),
          ),
          isTrue,
        );
      }
      await coordinator.complete('c');
      final sessions = await service.getMissionSessions();
      expect(sessions.map((s) => s.alarmId).toSet(), {'a', 'b'});
      expect(
        sessions.every((s) => s.snoozedUntil != null && s.snoozeUsed == 1),
        isTrue,
      );
    },
  );
}
