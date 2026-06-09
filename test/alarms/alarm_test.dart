import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';

PrayerTime _pt(DateTime day, {required DateTime fajr}) => PrayerTime(
  fajr: fajr,
  sunrise: DateTime(day.year, day.month, day.day, 7, 0),
  dhuhr: DateTime(day.year, day.month, day.day, 13, 0),
  asr: DateTime(day.year, day.month, day.day, 16, 0),
  maghrib: DateTime(day.year, day.month, day.day, 19, 0),
  isha: DateTime(day.year, day.month, day.day, 20, 30),
  date: day,
);

void main() {
  group('Alarm model', () {
    test('toMap/fromMap round-trip preserves all fields', () {
      const alarm = Alarm(
        id: 'a1',
        kind: AlarmKind.anchored,
        label: 'Sahur',
        isActive: true,
        anchor: PrayerType.fajr,
        offsetMinutes: -30,
        weekdays: {1, 3, 5},
        soundId: 'adhan',
        vibrate: true,
        snoozeEnabled: true,
        snoozeMinutes: 10,
      );

      final restored = Alarm.fromMap(alarm.toMap());
      expect(restored, equals(alarm));
      expect(restored.weekdays, equals({1, 3, 5}));
    });

    test('empty weekdays means fires every day', () {
      const alarm = Alarm(id: 'a', kind: AlarmKind.fixed);
      expect(alarm.repeats, isFalse);
      for (var wd = 1; wd <= 7; wd++) {
        expect(alarm.firesOnWeekday(wd), isTrue);
      }
    });

    test('copyWith changes only given fields', () {
      const alarm = Alarm(id: 'a', kind: AlarmKind.fixed, hour: 6);
      final updated = alarm.copyWith(hour: 7, isActive: false);
      expect(updated.hour, equals(7));
      expect(updated.isActive, isFalse);
      expect(updated.id, equals('a'));
    });
  });

  group('AlarmScheduler.computeNextFire — fixed', () {
    test('today if time is still ahead', () {
      final now = DateTime(2024, 1, 1, 7, 0); // Pazartesi
      const alarm = Alarm(id: 'a', kind: AlarmKind.fixed, hour: 8, minute: 0);
      final fire = AlarmScheduler.computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: const {},
      );
      expect(fire, equals(DateTime(2024, 1, 1, 8, 0)));
    });

    test('next day if time already passed', () {
      final now = DateTime(2024, 1, 1, 7, 0);
      const alarm = Alarm(id: 'a', kind: AlarmKind.fixed, hour: 6, minute: 0);
      final fire = AlarmScheduler.computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: const {},
      );
      expect(fire, equals(DateTime(2024, 1, 2, 6, 0)));
    });

    test('honors weekday filter', () {
      final now = DateTime(2024, 1, 1, 7, 0); // Pazartesi (1)
      // Sadece Carsamba (3)
      const alarm = Alarm(
        id: 'a',
        kind: AlarmKind.fixed,
        hour: 8,
        weekdays: {3},
      );
      final fire = AlarmScheduler.computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: const {},
      );
      expect(fire, equals(DateTime(2024, 1, 3, 8, 0))); // 3 Ocak = Carsamba
    });
  });

  group('AlarmScheduler.computeNextFire — anchored', () {
    test('anchor time plus negative offset (before)', () {
      final day = DateTime(2024, 1, 1);
      final now = DateTime(2024, 1, 1, 4, 0);
      final byDate = {day: _pt(day, fajr: DateTime(2024, 1, 1, 5, 30))};
      const alarm = Alarm(
        id: 'a',
        kind: AlarmKind.anchored,
        anchor: PrayerType.fajr,
        offsetMinutes: -30,
      );
      final fire = AlarmScheduler.computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: byDate,
      );
      expect(fire, equals(DateTime(2024, 1, 1, 5, 0)));
    });

    test('skips today if anchor already passed, uses next day', () {
      final d1 = DateTime(2024, 1, 1);
      final d2 = DateTime(2024, 1, 2);
      final now = DateTime(2024, 1, 1, 6, 0); // imsak (5:30) gecti
      final byDate = {
        d1: _pt(d1, fajr: DateTime(2024, 1, 1, 5, 30)),
        d2: _pt(d2, fajr: DateTime(2024, 1, 2, 5, 31)),
      };
      const alarm = Alarm(
        id: 'a',
        kind: AlarmKind.anchored,
        anchor: PrayerType.fajr,
        offsetMinutes: 0,
      );
      final fire = AlarmScheduler.computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: byDate,
      );
      expect(fire, equals(DateTime(2024, 1, 2, 5, 31)));
    });

    test('returns null if no prayer data in window', () {
      final now = DateTime(2024, 1, 1, 4, 0);
      const alarm = Alarm(id: 'a', kind: AlarmKind.anchored);
      final fire = AlarmScheduler.computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: const {},
      );
      expect(fire, isNull);
    });
  });

  group('AlarmScheduler.scheduleAlarms', () {
    test('cancels all then schedules only active alarms', () async {
      final storage = _FakeStorage([
        const Alarm(id: 'on', kind: AlarmKind.fixed, hour: 23, isActive: true),
        const Alarm(id: 'off', kind: AlarmKind.fixed, hour: 23, isActive: false),
      ]);
      final service = _MockAlarmService();
      final scheduler = AlarmScheduler(
        alarmService: service,
        storage: storage,
      );

      await scheduler.scheduleAlarms(prayerTimes: const []);

      expect(service.cancelAllCount, equals(1));
      expect(service.scheduled, equals(['on']));
    });

    test('empty alarms still cancels all (clears stale)', () async {
      final storage = _FakeStorage([]);
      final service = _MockAlarmService();
      final scheduler = AlarmScheduler(
        alarmService: service,
        storage: storage,
      );

      await scheduler.scheduleAlarms(prayerTimes: const []);

      expect(service.cancelAllCount, equals(1));
      expect(service.scheduled, isEmpty);
    });
  });
}

class _FakeStorage implements LocalStorage {
  final List<Alarm> alarms;
  _FakeStorage(this.alarms);

  @override
  Future<List<Alarm>> getAlarms() async => alarms;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _MockAlarmService implements AlarmService {
  int cancelAllCount = 0;
  final List<String> scheduled = [];

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
  }) async {
    scheduled.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
