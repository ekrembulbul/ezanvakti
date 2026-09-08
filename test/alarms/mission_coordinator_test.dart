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

  test('açık ekran kendi snapshotını seçer, diğer oturum korunur', () async {
    await service.seedSession(MissionSession(alarmId: 'is', firedAt: firedAt));
    service.pendingEvents = [
      MissionStopEvent(alarmId: 'yedek', stoppedAt: firedAt),
      MissionStopEvent(alarmId: 'is', stoppedAt: firedAt),
    ];
    expect((await coordinator.resume(alarmId: 'is')).session!.alarmId, 'is');
    expect(
      (await service.getMissionSessions()).map((s) => s.alarmId),
      containsAll(['is', 'yedek']),
    );
    await coordinator.complete('is');
    expect((await coordinator.resume()).session!.alarmId, 'yedek');
  });

  test(
    'yanlış alarm kimliği erteleme sayacını veya native alarmı değiştirmez',
    () async {
      await service.seedSession(
        MissionSession(alarmId: 'yedek', firedAt: firedAt),
      );
      const other = Alarm(
        id: 'is',
        kind: AlarmKind.fixed,
        mission: AlarmMission.qr,
        maxSnoozes: 2,
      );
      expect(await coordinator.snooze(other), isFalse);
      expect(service.snoozed, isEmpty);
      expect(((await service.getMissionSessions()).firstOrNull)!.snoozeUsed, 0);
      expect(await coordinator.begin('is', AlarmMission.qr), isNull);
      expect(service.begun, isEmpty);
    },
  );

  test('bir alarmı tamamlamak başka alarmın oturumunu silmez', () async {
    await service.seedSession(
      MissionSession(alarmId: 'yedek', firedAt: firedAt),
    );
    await coordinator.complete('is');
    expect(
      ((await service.getMissionSessions()).firstOrNull)!.alarmId,
      'yedek',
    );
  });

  test('erteleme kapalıysa coordinator native erteleme yapmaz', () async {
    await service.seedSession(MissionSession(alarmId: 'is', firedAt: firedAt));
    const alarm = Alarm(
      id: 'is',
      kind: AlarmKind.fixed,
      mission: AlarmMission.qr,
      snoozeEnabled: false,
    );
    expect(await coordinator.snooze(alarm), isFalse);
    expect(service.snoozed, isEmpty);
  });

  test('native çalışma zamanı durdurma zamanından ayrı saklanır', () async {
    service.pendingEvents = [
      MissionStopEvent.fromMap({
        'alarmId': 'is',
        'firedAt': firedAt.millisecondsSinceEpoch,
        'stoppedAt': firedAt
            .add(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
        'snoozeUsed': 2,
        'rearmCount': 3,
      }),
    ];
    final session = (await coordinator.resume()).session!;
    expect(session.firedAt, firedAt);
    expect(session.stoppedAt, firedAt.add(const Duration(minutes: 5)));
    expect(session.snoozeUsed, 2);
    expect(session.rearmCount, 3);
  });

  test('aynı alarmın yeni günü önceki erteleme sayacını taşımaz', () async {
    await service.seedSession(
      MissionSession(alarmId: 'is', firedAt: firedAt, snoozeUsed: 2),
    );
    final nextDay = firedAt.add(const Duration(days: 1));
    service.pendingEvents = [
      MissionStopEvent.fromMap({
        'alarmId': 'is',
        'firedAt': nextDay.millisecondsSinceEpoch,
        'stoppedAt': nextDay.millisecondsSinceEpoch,
        'snoozeUsed': 0,
      }),
    ];
    final session = (await coordinator.resume()).session!;
    expect(session.firedAt, nextDay);
    expect(session.snoozeUsed, 0);
  });

  test('resume: native durdurma snapshotı oturum açar', () async {
    service.pendingEvents = [
      MissionStopEvent(alarmId: 'sahur', stoppedAt: firedAt),
    ];
    final session = (await coordinator.resume()).session;
    expect(session, isNotNull);
    expect(session!.alarmId, 'sahur');
    expect((await service.getMissionSessions()).firstOrNull, isNotNull);
  });

  /// Erteleme sonrasi ikinci durdurma: ara ekranin geri sayimi ve bayatlik
  /// kontrolu son durdurma anina bagli, ilk calisa degil.
  test('resume: yeni durdurma olayi stoppedAt i gunceller', () async {
    await service.seedSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    final again = firedAt.add(const Duration(minutes: 5));
    service.pendingEvents = [
      MissionStopEvent(alarmId: 'sahur', stoppedAt: again),
    ];

    final session = (await coordinator.resume()).session;

    expect(session!.firedAt, firedAt);
    expect(session.stoppedAt, again);
  });

  test('resume: olay yoksa mevcut oturum korunur', () async {
    await service.seedSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    final session = (await coordinator.resume()).session;
    expect(session!.alarmId, 'sahur');
  });

  /// Zincir tavana carpti (K3): oturum kapanmali, gorev ekrani acilmamali.
  test('resume: chainStopped olayi oturumu kapatir', () async {
    await service.seedSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    service.pendingEvents = [
      MissionStopEvent(
        alarmId: 'sahur',
        stoppedAt: firedAt,
        chainStopped: true,
      ),
    ];
    final result = await coordinator.resume();
    expect(result.chainStoppedAlarmId, isNull);
    expect(result.session, isNull);
    expect((await service.getMissionSessions()).firstOrNull, isNull);
  });

  test('begin native tarafa haber verir', () async {
    await service.seedSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    await coordinator.begin('sahur', AlarmMission.math);
    expect(service.begun, ['sahur']);
  });

  test('begin son tarihi bir kez koyar, tekrar acilista degistirmez', () async {
    await service.seedSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    final first = await coordinator.begin('sahur', AlarmMission.math);
    expect(first, isNotNull);
    // Ekran yeniden acilirsa geri sayim bastan baslamamali.
    final second = await coordinator.begin('sahur', AlarmMission.math);
    expect(second, first);
  });

  test('snooze alarmi gercekten erteler ve son tarihi siler', () async {
    await service.seedSession(
      MissionSession(
        alarmId: 'sahur',
        firedAt: firedAt,
        deadlineAt: firedAt.add(const Duration(seconds: 90)),
      ),
    );
    const alarm = Alarm(
      id: 'sahur',
      kind: AlarmKind.fixed,
      mission: AlarmMission.math,
      maxSnoozes: 2,
      snoozeMinutes: 10,
    );
    expect(await coordinator.snooze(alarm), isTrue);
    expect(service.snoozed.single.id, 'sahur');
    expect(service.snoozed.single.minutes, 10);
    expect(
      ((await service.getMissionSessions()).firstOrNull)!.deadlineAt,
      isNull,
    );
  });

  test('Hak bitince erteleme native tarafa hic gitmez', () async {
    await service.seedSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt, snoozeUsed: 1),
    );
    const alarm = Alarm(
      id: 'sahur',
      kind: AlarmKind.fixed,
      mission: AlarmMission.math,
      maxSnoozes: 1,
    );
    expect(await coordinator.snooze(alarm), isFalse);
    expect(service.snoozed, isEmpty);
  });

  test('complete oturumu silip native temizler', () async {
    await service.seedSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    await coordinator.complete('sahur');
    expect(service.completed, ['sahur']);
    expect((await service.getMissionSessions()).firstOrNull, isNull);
  });

  test(
    'snooze tekrarı hak tüketmez, yeni durdurma sonraki hakkı kullanır',
    () async {
      await service.seedSession(
        MissionSession(alarmId: 'sahur', firedAt: firedAt),
      );
      const alarm = Alarm(
        id: 'sahur',
        kind: AlarmKind.fixed,
        mission: AlarmMission.math,
        maxSnoozes: 2,
      );
      expect(await coordinator.snooze(alarm), isTrue);
      expect(((await service.getMissionSessions()).firstOrNull)!.snoozeUsed, 1);
      expect(await coordinator.snooze(alarm), isTrue);
      expect((await service.getMissionSessions()).single.snoozeUsed, 1);
      service.pendingEvents = [
        MissionStopEvent(alarmId: alarm.id, stoppedAt: DateTime.now()),
      ];
      expect(await coordinator.snooze(alarm), isTrue);
      service.pendingEvents = [
        MissionStopEvent(
          alarmId: alarm.id,
          stoppedAt: DateTime.now().add(const Duration(minutes: 10)),
        ),
      ];
      expect(await coordinator.snooze(alarm), isFalse);
      expect(((await service.getMissionSessions()).firstOrNull)!.snoozeUsed, 2);
    },
  );

  test('abort kademeyi yukseltir ve zinciri temizler', () async {
    await service.seedSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    await coordinator.abort('sahur', firedAt);
    expect(service.aborted, ['sahur']);
    expect((await service.getMissionSessions()).firstOrNull, isNull);
    final state = await storage.getAbortState();
    expect(state.level, 1);
    expect(state.lastUsedAt, firedAt);
  });
}
