import 'dart:async';

import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/alarm_plan.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import 'fakes/fake_alarm_service.dart';

class _PlanService extends FakeAlarmService {
  final cancellations = <String>[];
  final failures = <String, String>{};
  Completer<void>? gate;

  @override
  Future<Map<String, String>> reconcileAlarms(AlarmPlan plan) async {
    plans.add(plan);
    await gate?.future;
    return Map.of(failures);
  }

  @override
  Future<void> cancelAlarm(String id) async => cancellations.add(id);
}

void main() {
  late FakeStorage storage;
  late _PlanService service;
  late AlarmScheduler scheduler;
  setUp(() async {
    storage = FakeStorage();
    await storage.init();
    service = _PlanService();
    scheduler = AlarmScheduler(storage: storage, alarmService: service);
  });

  test('Refresh sends desired records without cancelling all alarms', () async {
    await storage.saveAlarm(
      const Alarm(id: 'work', kind: AlarmKind.fixed, hour: 8),
    );
    await scheduler.scheduleAlarms(prayerTimes: const []);
    expect(service.cancelAllCount, 0);
    expect(service.plans.single.enabledAlarmIds, {'work'});
    expect(service.plans.single.records.single.id, 'work');
  });

  test(
    'A queued refresh reads storage after deletion and cannot resurrect the alarm',
    () async {
      await storage.saveAlarm(
        const Alarm(id: 'copy', kind: AlarmKind.fixed, hour: 8),
      );
      service.gate = Completer<void>();
      final first = scheduler.scheduleAlarms(prayerTimes: const []);
      await pumpEventQueue();
      expect(service.plans, hasLength(1));
      final deleted = scheduler.deleteDefinition('copy');
      final refresh = scheduler.scheduleAlarms(prayerTimes: const []);
      service.gate!.complete();
      await Future.wait([first, deleted, refresh]);
      expect(service.cancellations, ['copy']);
      expect(service.plans.last.enabledAlarmIds, isEmpty);
      expect(service.plans.last.records, isEmpty);
    },
  );

  test(
    'Missing prayer data preserves anchored root and still plans fixed alarm',
    () async {
      await storage.saveAlarm(const Alarm(id: 'sun', kind: AlarmKind.anchored));
      await storage.saveAlarm(
        const Alarm(id: 'work', kind: AlarmKind.fixed, hour: 8),
      );
      await scheduler.scheduleAlarms(prayerTimes: const []);
      expect(service.plans.single.preserveAlarmIds, {'sun'});
      expect(service.plans.single.records.single.alarm.id, 'work');
    },
  );

  test('Every alarm gets its nearest primary before distant days', () async {
    await storage.saveAlarm(
      const Alarm(
        id: 'a',
        kind: AlarmKind.anchored,
        anchor: PrayerType.sunrise,
        offsetMinutes: -30,
        mission: AlarmMission.qr,
      ),
    );
    await storage.saveAlarm(
      const Alarm(id: 'b', kind: AlarmKind.fixed, hour: 8),
    );
    final now = DateTime.now();
    final days = [
      for (var i = 1; i <= 7; i++)
        _day(DateTime(now.year, now.month, now.day + i)),
    ];
    await scheduler.scheduleAlarms(prayerTimes: days);
    final records = service.plans.single.records;
    expect(records.take(2).map((r) => r.alarm.id).toSet(), {'a', 'b'});
    expect(records.skip(2).every((r) => !r.isFirstOccurrence), isTrue);
  });

  test(
    'Partial prayer cache preserves missing source days without freezing known days',
    () async {
      await storage.saveAlarm(
        const Alarm(
          id: 'sun',
          kind: AlarmKind.anchored,
          anchor: PrayerType.sunrise,
          offsetMinutes: -30,
        ),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      await scheduler.scheduleAlarms(prayerTimes: [_day(tomorrow)]);
      final payload = service.plans.single.toMap();
      final periods = (payload['preservedPeriods'] as List).cast<Map>();
      bool kept(DateTime date) => periods.any(
        (p) =>
            p['alarmId'] == 'sun' &&
            (p['fromMillis'] as int) <= date.millisecondsSinceEpoch &&
            date.millisecondsSinceEpoch < (p['untilMillis'] as int),
      );
      expect(kept(today.add(const Duration(hours: 6))), isTrue);
      expect(kept(tomorrow.add(const Duration(hours: 6))), isFalse);
      expect(service.plans.single.records, hasLength(1));
    },
  );

  test(
    'Native root failures are persisted without hiding other root status',
    () async {
      await storage.saveAlarm(
        const Alarm(id: 'a', kind: AlarmKind.fixed, hour: 8),
      );
      service.failures['a'] = 'cancel_failed';
      await scheduler.scheduleAlarms(prayerTimes: const []);
      expect(await storage.getAlarmScheduleFailures(), {'a': 'cancel_failed'});
    },
  );

  test(
    'Plan never serializes QR content to the native scheduling payload',
    () async {
      await storage.saveAlarm(
        const Alarm(
          id: 'a',
          kind: AlarmKind.fixed,
          hour: 8,
          mission: AlarmMission.qr,
          qrPayload: 'private-qr-content',
        ),
      );
      await scheduler.scheduleAlarms(prayerTimes: const []);
      expect(
        service.plans.single.toMap().toString(),
        isNot(contains('private-qr-content')),
      );
    },
  );
}

PrayerTime _day(DateTime d) => PrayerTime(
  date: d,
  fajr: DateTime(d.year, d.month, d.day, 4, 50),
  sunrise: DateTime(d.year, d.month, d.day, 6, 16),
  dhuhr: DateTime(d.year, d.month, d.day, 12, 50),
  asr: DateTime(d.year, d.month, d.day, 16, 30),
  maghrib: DateTime(d.year, d.month, d.day, 19, 15),
  isha: DateTime(d.year, d.month, d.day, 20, 35),
);
