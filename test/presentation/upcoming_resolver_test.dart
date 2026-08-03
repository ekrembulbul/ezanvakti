import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/services/upcoming_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerTime _day(int day) {
  DateTime at(int h, int m) => DateTime(2026, 8, day, h, m);
  return PrayerTime(
    fajr: at(4, 11),
    sunrise: at(5, 55),
    dhuhr: at(13, 15),
    asr: at(17, 9),
    maghrib: at(20, 25),
    isha: at(22, 1),
    date: DateTime(2026, 8, day),
  );
}

final _window = [_day(3), _day(4), _day(5)];

void main() {
  group('resolveNextNotification', () {
    test('Once gelen vakit secilir', () {
      final next = resolveNextNotification(
        settings: const [
          NotificationSetting(prayerType: PrayerType.isha, isActive: true),
          NotificationSetting(prayerType: PrayerType.maghrib, isActive: true),
        ],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 18),
      );

      expect(next?.setting.prayerType, PrayerType.maghrib);
      expect(next?.time, DateTime(2026, 8, 3, 20, 25));
    });

    test('minutesBefore kadar erken tetiklenir', () {
      final next = resolveNextNotification(
        settings: const [
          NotificationSetting(
            prayerType: PrayerType.maghrib,
            isActive: true,
            minutesBefore: 10,
          ),
        ],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 18),
      );

      expect(next?.time, DateTime(2026, 8, 3, 20, 15));
    });

    test('Kapali ayar atlanir', () {
      final next = resolveNextNotification(
        settings: const [
          NotificationSetting(prayerType: PrayerType.maghrib, isActive: false),
          NotificationSetting(prayerType: PrayerType.isha, isActive: true),
        ],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 18),
      );

      expect(next?.setting.prayerType, PrayerType.isha);
    });

    test('Gunun vakitleri gectiyse ertesi gune gecer', () {
      final next = resolveNextNotification(
        settings: const [
          NotificationSetting(prayerType: PrayerType.fajr, isActive: true),
        ],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 23),
      );

      expect(next?.time, DateTime(2026, 8, 4, 4, 11));
    });

    test('Aktif ayar yoksa null', () {
      final next = resolveNextNotification(
        settings: const [
          NotificationSetting(prayerType: PrayerType.fajr, isActive: false),
        ],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 12),
      );

      expect(next, isNull);
    });
  });

  group('resolveNextAlarm', () {
    const fixed = Alarm(
      id: 'fixed',
      kind: AlarmKind.fixed,
      label: 'Sabah',
      hour: 6,
      minute: 30,
    );
    const anchored = Alarm(
      id: 'anchored',
      kind: AlarmKind.anchored,
      label: 'Sahur',
      anchor: PrayerType.fajr,
      offsetMinutes: -30,
    );

    test('En erken calacak alarm secilir', () {
      final next = resolveNextAlarm(
        alarms: const [fixed, anchored],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 23),
      );

      // Sahur: 4 Agustos Imsak 04:11 - 30 dk = 03:41; sabit alarm 06:30.
      expect(next?.alarm.id, 'anchored');
      expect(next?.time, DateTime(2026, 8, 4, 3, 41));
    });

    test('Kapali alarm atlanir', () {
      final next = resolveNextAlarm(
        alarms: const [
          fixed,
          Alarm(id: 'off', kind: AlarmKind.fixed, isActive: false),
        ],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 23),
      );

      expect(next?.alarm.id, 'fixed');
    });

    test('Alarm yoksa null', () {
      final next = resolveNextAlarm(
        alarms: const [],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 12),
      );

      expect(next, isNull);
    });
  });
}
