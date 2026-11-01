import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/core/models/notification_setting.dart'
    show PrayerType;
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:ezanvakti/features/alarms/domain/alarms_manager.dart';
import 'package:ezanvakti/features/alarms/domain/snooze_options.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import 'fakes/fake_alarm_service.dart';

/// Tek seferlik ("Bir kez") alarm: yalnız hedef günün çalışı kurulur, çalıp
/// zincir süresi geçince planlayıcı alarmı kapatır (ADR 0007).
void main() {
  // 2 Kasım 2026 Pazartesi.
  final monday = DateTime(2026, 11, 2);
  DateTime on(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 11, day, hour, minute);

  PrayerTime dayOf(DateTime day) {
    DateTime at(int hour, int minute) =>
        DateTime(day.year, day.month, day.day, hour, minute);
    return PrayerTime(
      date: DateTime(day.year, day.month, day.day),
      fajr: at(5, 0),
      sunrise: at(6, 30),
      dhuhr: at(12, 30),
      asr: at(15, 30),
      maghrib: at(18, 0),
      isha: at(19, 30),
    );
  }

  List<PrayerTime> days(int from, int count) => [
    for (var i = 0; i < count; i++) dayOf(DateTime(2026, 11, from + i)),
  ];

  Map<DateTime, PrayerTime> byDate(List<PrayerTime> list) => {
    for (final pt in list) pt.date: pt,
  };

  late FakeStorage storage;
  late FakeAlarmService service;

  setUp(() {
    storage = FakeStorage();
    service = FakeAlarmService();
  });

  AlarmScheduler schedulerAt(DateTime now) =>
      AlarmScheduler(alarmService: service, storage: storage, clock: () => now);

  group('Planlama', () {
    test('sabit tek seferlik alarm yalniz hedef gune tek tarihli kayit kurar, '
        'haftalik sablon gondermez', () async {
      // Gün kümesi {1} (Pazartesi) yok sayılır; hedef gün Salı.
      final alarm = Alarm(
        id: 'o1',
        kind: AlarmKind.fixed,
        hour: 7,
        minute: 30,
        weekdays: const {1},
        isOnce: true,
        onceDate: DateTime(2026, 11, 3),
      );
      await storage.saveAlarm(alarm);

      await schedulerAt(on(2, 6)).scheduleAlarms(prayerTimes: const []);

      final plan = service.plans.single;
      expect(plan.enabledAlarmIds, {'o1'});
      final record = plan.records.single;
      expect(record.scheduledTime, on(3, 7, 30));
      expect(record.id, 'o1#at${on(3, 7, 30).millisecondsSinceEpoch}');
      expect(record.repeatWeekdays, isEmpty);
      expect(
        record.chainConfig.containsKey('templateWeekdays'),
        isFalse,
        reason: 'sablon giderse native kaydi haftaliga cevirir',
      );
      expect(record.chainConfig['repeatHour'], 7);
      expect(record.chainConfig['repeatMinute'], 30);
    });

    test('sabit tek seferlik alarm bugunku saat ilerdeyken de hedef gunde '
        'kurulur', () async {
      final alarm = Alarm(
        id: 'o1',
        kind: AlarmKind.fixed,
        hour: 18,
        isOnce: true,
        onceDate: DateTime(2026, 11, 4),
      );
      await storage.saveAlarm(alarm);

      await schedulerAt(on(2, 6)).scheduleAlarms(prayerTimes: const []);

      expect(service.plans.single.records.single.scheduledTime, on(4, 18));
    });

    test('cipali tek seferlik alarm yalniz hedef gunde kurulur', () async {
      final alarm = Alarm(
        id: 'o2',
        kind: AlarmKind.anchored,
        anchor: PrayerType.fajr,
        offsetMinutes: -30,
        mission: AlarmMission.math,
        isOnce: true,
        onceDate: DateTime(2026, 11, 4),
      );
      await storage.saveAlarm(alarm);

      await schedulerAt(on(2, 6)).scheduleAlarms(prayerTimes: days(2, 8));

      final plan = service.plans.single;
      final record = plan.records.single;
      expect(record.scheduledTime, on(4, 4, 30));
      expect(record.repeatWeekdays, isEmpty);
      expect(record.chainConfig.containsKey('templateWeekdays'), isFalse);
      expect(plan.preservedPeriods, isEmpty);
      expect(plan.preserveAlarmIds, isEmpty);
    });

    test('hedef gunun vakti yoksa eksik vakit davranisi: korunur, tarama '
        'yalniz o gunu kapsar', () async {
      final alarm = Alarm(
        id: 'o2',
        kind: AlarmKind.anchored,
        anchor: PrayerType.fajr,
        offsetMinutes: -30,
        isOnce: true,
        onceDate: DateTime(2026, 11, 5),
      );
      await storage.saveAlarm(alarm);

      await schedulerAt(on(2, 6)).scheduleAlarms(prayerTimes: days(2, 2));

      final plan = service.plans.single;
      expect(plan.records, isEmpty);
      expect(plan.preserveAlarmIds, {'o2'});
      final period = plan.preservedPeriods.single;
      expect(period.alarmId, 'o2');
      expect(period.from, on(4, 23, 30));
      expect(period.until, on(5, 23, 30));
      expect((await storage.getAlarms()).single.isActive, isTrue);
    });
  });

  group('Kendini kapatma', () {
    final spent = Alarm(
      id: 'o1',
      kind: AlarmKind.fixed,
      hour: 10,
      isOnce: true,
      onceDate: monday,
    );

    test('calis ve zincir suresi gecmis, oturum yoksa alarm kapanir ve native '
        'kaydi kurulmaz', () async {
      await storage.saveAlarm(spent);
      final scheduler = schedulerAt(on(2, 11, 1));
      final closed = <Set<String>>[];
      final subscription = scheduler.onceAlarmsChanged.listen(closed.add);
      addTearDown(subscription.cancel);

      await scheduler.scheduleAlarms(prayerTimes: const []);
      await pumpEventQueue();

      expect((await storage.getAlarms()).single.isActive, isFalse);
      expect(service.plans.single.enabledAlarmIds, isEmpty);
      expect(service.plans.single.records, isEmpty);
      expect(closed, [
        {'o1'},
      ]);
    });

    test('zincir suresi icindeyken kapanmaz', () async {
      await storage.saveAlarm(spent);

      await schedulerAt(on(2, 10, 30)).scheduleAlarms(prayerTimes: const []);

      expect((await storage.getAlarms()).single.isActive, isTrue);
      expect(service.plans.single.enabledAlarmIds, {'o1'});
    });

    test('bekleyen oturum varken kapanmaz', () async {
      await storage.saveAlarm(spent);
      await service.seedSession(
        MissionSession(
          alarmId: 'o1',
          firedAt: on(2, 10),
          snoozedUntil: on(2, 11, 5),
        ),
      );

      await schedulerAt(on(2, 11, 1)).scheduleAlarms(prayerTimes: const []);

      expect((await storage.getAlarms()).single.isActive, isTrue);
      expect(service.plans.single.enabledAlarmIds, {'o1'});
    });

    test('oturumlar okunamazsa kapatilmaz, plan yine kurulur', () async {
      await storage.saveAlarm(spent);
      service.snapshotError = StateError('native unavailable');

      await schedulerAt(on(2, 11, 1)).scheduleAlarms(prayerTimes: const []);

      expect((await storage.getAlarms()).single.isActive, isTrue);
      expect(service.plans, hasLength(1));
    });

    Alarm anchoredOn(DateTime day) => Alarm(
      id: 'o2',
      kind: AlarmKind.anchored,
      anchor: PrayerType.isha,
      offsetMinutes: 240,
      isOnce: true,
      onceDate: day,
    );

    test('hedef gun 13 gun onceyse vakit verisi olmadan da kapanir', () async {
      await storage.saveAlarm(anchoredOn(DateTime(2026, 10, 20)));

      await schedulerAt(on(2, 11)).scheduleAlarms(prayerTimes: days(2, 3));

      expect((await storage.getAlarms()).single.isActive, isFalse);
      expect(service.plans.single.enabledAlarmIds, isEmpty);
    });

    test(
      'hedef gun tam iki gun onceyse gece yarisindan sonra kapanir',
      () async {
        // 31 Ekim yatsı + 240 dk + 60 dk zincir en geç 1 Kasım'da biter.
        await storage.saveAlarm(anchoredOn(DateTime(2026, 10, 31)));

        await schedulerAt(on(2, 0, 5)).scheduleAlarms(prayerTimes: const []);

        expect((await storage.getAlarms()).single.isActive, isFalse);
      },
    );

    test('hedef gun dunse ve vakti yoksa kapanmaz', () async {
      await storage.saveAlarm(anchoredOn(DateTime(2026, 11, 1)));

      await schedulerAt(on(2, 11)).scheduleAlarms(prayerTimes: days(2, 3));

      expect((await storage.getAlarms()).single.isActive, isTrue);
    });

    test('eski hedef gunde bekleyen oturum varsa kapanmaz', () async {
      await storage.saveAlarm(anchoredOn(DateTime(2026, 10, 20)));
      await service.seedSession(
        MissionSession(
          alarmId: 'o2',
          firedAt: DateTime(2026, 10, 20, 23),
          snoozedUntil: DateTime(2026, 10, 20, 23, 5),
        ),
      );

      await schedulerAt(on(2, 11)).scheduleAlarms(prayerTimes: days(2, 3));

      expect((await storage.getAlarms()).single.isActive, isTrue);
    });

    test('tekrarli ya da zaten kapali alarma dokunulmaz', () async {
      const repeating = Alarm(id: 'r1', kind: AlarmKind.fixed, hour: 10);
      await storage.saveAlarm(repeating);
      await storage.saveAlarm(spent.copyWith(isActive: false));
      final scheduler = schedulerAt(on(2, 11, 1));
      final closed = <Set<String>>[];
      final subscription = scheduler.onceAlarmsChanged.listen(closed.add);
      addTearDown(subscription.cancel);

      await scheduler.scheduleAlarms(prayerTimes: const []);
      await pumpEventQueue();

      expect(
        (await storage.getAlarms()).firstWhere((a) => a.id == 'r1').isActive,
        isTrue,
      );
      expect(closed, isEmpty);
    });
  });

  group('Bos hedef gunun onarilmasi', () {
    test(
      'acik sabit alarmin bos hedef gunu hesaplanip kaydedilir ve kurulur',
      () async {
        const alarm = Alarm(
          id: 'o1',
          kind: AlarmKind.fixed,
          hour: 7,
          minute: 30,
          isOnce: true,
        );
        await storage.saveAlarm(alarm);
        final scheduler = schedulerAt(on(2, 6));
        final changed = <Set<String>>[];
        final subscription = scheduler.onceAlarmsChanged.listen(changed.add);
        addTearDown(subscription.cancel);

        await scheduler.scheduleAlarms(prayerTimes: const []);
        await pumpEventQueue();

        final saved = (await storage.getAlarms()).single;
        expect(saved.onceDate, monday);
        expect(saved.isActive, isTrue);
        expect(service.plans.single.records.single.scheduledTime, on(2, 7, 30));
        expect(changed, [
          {'o1'},
        ]);
      },
    );

    test('bozuk tarihli sabit alarm da onarilir', () async {
      const valid = Alarm(
        id: 'o1',
        kind: AlarmKind.fixed,
        hour: 7,
        minute: 30,
        isOnce: true,
      );
      await storage.saveAlarm(
        Alarm.fromMap({...valid.toMap(), 'once_date': '2026-02-31'}),
      );

      await schedulerAt(on(2, 8)).scheduleAlarms(prayerTimes: const []);

      expect(
        (await storage.getAlarms()).single.onceDate,
        DateTime(2026, 11, 3),
      );
    });

    test(
      'cipali alarmin bos hedef gunu vakit verisi gelince onarilir',
      () async {
        const alarm = Alarm(
          id: 'o2',
          kind: AlarmKind.anchored,
          anchor: PrayerType.fajr,
          offsetMinutes: -30,
          isOnce: true,
        );
        await storage.saveAlarm(alarm);

        // 2 Kasım imsakı (04:30) geçti; ilk uygun gün 3 Kasım.
        await schedulerAt(on(2, 6)).scheduleAlarms(prayerTimes: days(2, 3));

        expect(
          (await storage.getAlarms()).single.onceDate,
          DateTime(2026, 11, 3),
        );
        expect(service.plans.single.records.single.scheduledTime, on(3, 4, 30));
      },
    );

    test('vakit verisi yoksa bos kalir, eksik vakit davranisi surer', () async {
      const alarm = Alarm(
        id: 'o2',
        kind: AlarmKind.anchored,
        anchor: PrayerType.fajr,
        isOnce: true,
      );
      await storage.saveAlarm(alarm);

      await schedulerAt(on(2, 6)).scheduleAlarms(prayerTimes: const []);

      final saved = (await storage.getAlarms()).single;
      expect(saved.onceDate, isNull);
      expect(saved.isActive, isTrue);
      expect(service.plans.single.preserveAlarmIds, {'o2'});
    });

    test('kapali alarm onarilmaz', () async {
      const alarm = Alarm(
        id: 'o1',
        kind: AlarmKind.fixed,
        hour: 7,
        isActive: false,
        isOnce: true,
      );
      await storage.saveAlarm(alarm);

      await schedulerAt(on(2, 6)).scheduleAlarms(prayerTimes: const []);

      expect((await storage.getAlarms()).single.onceDate, isNull);
    });
  });

  group('Hedef gun hesabi', () {
    test('sabit: bugunku saat gectiyse yarin; gun kumesi yok sayilir', () {
      const alarm = Alarm(
        id: 'o1',
        kind: AlarmKind.fixed,
        hour: 7,
        minute: 30,
        weekdays: {1},
        isOnce: true,
      );
      final next = AlarmScheduler.nextOnceOccurrence(
        alarm: alarm,
        now: on(2, 12),
        prayerTimesByDate: const {},
      )!;
      expect(next.day, DateTime(2026, 11, 3));
      expect(next.fire, on(3, 7, 30));
    });

    test('sabit: bugunku saat ilerdeyse bugun', () {
      const alarm = Alarm(
        id: 'o1',
        kind: AlarmKind.fixed,
        hour: 18,
        isOnce: true,
      );
      final next = AlarmScheduler.nextOnceOccurrence(
        alarm: alarm,
        now: on(2, 12),
        prayerTimesByDate: const {},
      )!;
      expect(next.day, monday);
    });

    test('atlanan ornek gecilir', () {
      const alarm = Alarm(
        id: 'o1',
        kind: AlarmKind.fixed,
        hour: 18,
        isOnce: true,
      );
      final next = AlarmScheduler.nextOnceOccurrence(
        alarm: alarm,
        now: on(2, 12),
        prayerTimesByDate: const {},
        skips: {
          SkippedOccurrence(
            kind: SkipKind.alarm,
            reference: 'o1',
            fireAt: on(2, 18),
          ),
        },
      )!;
      expect(next.day, DateTime(2026, 11, 3));
    });

    test('cipali: gece yarisini gecen ofsette kaynak gun saklanir', () {
      // Yarının imsakı 05:00, 7 saat önce = bugün 22:00. Kaynak gün yarın.
      const alarm = Alarm(
        id: 'o2',
        kind: AlarmKind.anchored,
        anchor: PrayerType.fajr,
        offsetMinutes: -420,
        isOnce: true,
      );
      final next = AlarmScheduler.nextOnceOccurrence(
        alarm: alarm,
        now: on(2, 21),
        prayerTimesByDate: byDate(days(2, 3)),
      )!;
      expect(next.day, DateTime(2026, 11, 3));
      expect(next.fire, on(2, 22));
    });

    test('cipali: vakit verisi yoksa null', () {
      const alarm = Alarm(
        id: 'o2',
        kind: AlarmKind.anchored,
        anchor: PrayerType.fajr,
        isOnce: true,
      );
      expect(
        AlarmScheduler.nextOnceOccurrence(
          alarm: alarm,
          now: on(2, 12),
          prayerTimesByDate: const {},
        ),
        isNull,
      );
    });
  });

  group('AlarmsManager', () {
    AlarmsManager managerAt(DateTime now) =>
        AlarmsManager(scheduler: schedulerAt(now));

    test('kaydederken hedef gunu hesaplar', () async {
      const alarm = Alarm(
        id: 'o1',
        kind: AlarmKind.fixed,
        hour: 7,
        minute: 30,
        isOnce: true,
      );

      await managerAt(
        on(2, 12),
      ).save(alarm, prayerTimes: const [], skips: const {});

      expect(
        (await storage.getAlarms()).single.onceDate,
        DateTime(2026, 11, 3),
      );
    });

    test('tekrarli alarmda hedef gun yazilmaz', () async {
      const alarm = Alarm(id: 'r1', kind: AlarmKind.fixed, hour: 7);

      await managerAt(
        on(2, 12),
      ).save(alarm, prayerTimes: const [], skips: const {});

      expect((await storage.getAlarms()).single.onceDate, isNull);
    });

    test('hedef gun hesaplanamazsa mevcut tarih korunur', () async {
      final alarm = Alarm(
        id: 'o2',
        kind: AlarmKind.anchored,
        anchor: PrayerType.fajr,
        isOnce: true,
        onceDate: DateTime(2026, 11, 5),
      );

      await managerAt(
        on(2, 12),
      ).save(alarm, prayerTimes: const [], skips: const {});

      expect(
        (await storage.getAlarms()).single.onceDate,
        DateTime(2026, 11, 5),
      );
    });

    test('kapali tek seferlik alarm yeniden acilinca hedef gun yeniden '
        'hesaplanir', () async {
      final closed = Alarm(
        id: 'o1',
        kind: AlarmKind.fixed,
        hour: 7,
        minute: 30,
        isActive: false,
        isOnce: true,
        onceDate: DateTime(2026, 10, 20),
      );
      await storage.saveAlarm(closed);

      await managerAt(
        on(2, 6),
      ).setActive(closed, true, prayerTimes: const [], skips: const {});

      final saved = (await storage.getAlarms()).single;
      expect(saved.isActive, isTrue);
      expect(saved.onceDate, monday);
    });

    test('kapatirken hedef gun degismez', () async {
      final active = Alarm(
        id: 'o1',
        kind: AlarmKind.fixed,
        hour: 7,
        isOnce: true,
        onceDate: DateTime(2026, 11, 5),
      );
      await storage.saveAlarm(active);

      await managerAt(
        on(2, 6),
      ).setActive(active, false, prayerTimes: const [], skips: const {});

      final saved = (await storage.getAlarms()).single;
      expect(saved.isActive, isFalse);
      expect(saved.onceDate, DateTime(2026, 11, 5));
    });
  });

  group('Kaydederken hedef gunun korunmasi', () {
    // 2 Kasım 10:00'da çalan tek seferlik alarm.
    final rang = Alarm(
      id: 'o1',
      kind: AlarmKind.fixed,
      hour: 10,
      isOnce: true,
      onceDate: monday,
    );

    Future<Alarm> saveAt(DateTime now, Alarm edited) async {
      await AlarmsManager(
        scheduler: schedulerAt(now),
      ).save(edited, prayerTimes: const [], skips: const {});
      return (await storage.getAlarms()).single;
    }

    test(
      'calis gecmis, zincir dolmamis ve zamanlama ayniysa korunur',
      () async {
        await storage.saveAlarm(rang);

        final saved = await saveAt(
          on(2, 10, 30),
          rang.copyWith(label: 'Toplanti'),
        );

        expect(saved.onceDate, monday);
      },
    );

    test('zamanlama degistiyse yeniden hesaplanir', () async {
      await storage.saveAlarm(rang);

      final saved = await saveAt(on(2, 10, 30), rang.copyWith(hour: 9));

      expect(saved.onceDate, DateTime(2026, 11, 3));
    });

    test('zincir dolduktan sonra bekleyen oturum varsa korunur', () async {
      await storage.saveAlarm(rang);
      await service.seedSession(
        MissionSession(
          alarmId: 'o1',
          firedAt: on(2, 10),
          snoozedUntil: on(2, 11, 35),
        ),
      );

      final saved = await saveAt(on(2, 11, 30), rang.copyWith(label: 'x'));

      expect(saved.onceDate, monday);
    });

    test('zincir dolmus ve oturum yoksa yeniden hesaplanir', () async {
      await storage.saveAlarm(rang.copyWith(isActive: false));

      final saved = await saveAt(on(2, 11, 30), rang);

      expect(saved.onceDate, DateTime(2026, 11, 3));
      expect(saved.isActive, isTrue);
    });

    test(
      'tekrarli alarm tek seferlige cevrilince yeniden hesaplanir',
      () async {
        await storage.saveAlarm(rang.copyWith(isOnce: false));

        final saved = await saveAt(on(2, 10, 30), rang);

        expect(saved.onceDate, DateTime(2026, 11, 3));
      },
    );
  });

  group('Alani yeniden kuran yardimcilar', () {
    final source = Alarm(
      id: 's1',
      kind: AlarmKind.fixed,
      hour: 5,
      isOnce: true,
      onceDate: DateTime(2026, 11, 3),
      maxSnoozes: 2,
    );

    test('duplicateOf tek seferlik alanlari tasir', () {
      final copy = duplicateOf(source, newId: 'n1', copyLabel: (l) => l);
      expect(copy.isOnce, isTrue);
      expect(copy.onceDate, DateTime(2026, 11, 3));
    });

    test('normalizeAlarmSnoozeLimit tek seferlik alanlari tasir', () {
      final normalized = normalizeAlarmSnoozeLimit(
        source.copyWith(snoozeEnabled: false),
      );
      expect(normalized.maxSnoozes, isNull);
      expect(normalized.isOnce, isTrue);
      expect(normalized.onceDate, DateTime(2026, 11, 3));
    });
  });
}
