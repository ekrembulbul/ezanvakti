import 'dart:ui';

import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/derived_time.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:ezanvakti/presentation/services/upcoming_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../notifications/fakes/notification_storage.dart';
import '../notifications/fakes/recording_notification_service.dart';

PrayerTime _day(int day) => _dayAt(DateTime(2026, 8, day));

PrayerTime _dayAt(DateTime date) {
  DateTime at(int h, int m) => DateTime(date.year, date.month, date.day, h, m);
  return PrayerTime(
    fajr: at(4, 11),
    sunrise: at(5, 55),
    dhuhr: at(13, 15),
    asr: at(17, 9),
    maghrib: at(20, 25),
    isha: at(22, 1),
    date: DateTime(date.year, date.month, date.day),
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

    test('prayerDate vaktin gunu', () {
      final next = resolveNextNotification(
        settings: const [
          NotificationSetting(
            prayerType: PrayerType.fajr,
            isActive: true,
            minutesBefore: 30,
          ),
        ],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 23),
      );

      // Tetiklenme 4 Agustos 03:41; vaktin gunu de 4 Agustos.
      expect(next?.time, DateTime(2026, 8, 4, 3, 41));
      expect(next?.prayerDate, DateTime(2026, 8, 4));
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

    test('Cuma bildirimi perşembe günü için gösterilmez', () {
      const friday = NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 45,
        weekdays: {DateTime.friday},
        label: 'Cuma namazı',
      );

      final next = resolveNextNotification(
        settings: const [friday],
        prayerTimes: [_day(6), _day(7)],
        now: DateTime(2026, 8, 6, 10),
      );

      expect(next?.setting, friday);
      expect(next?.time, DateTime(2026, 8, 7, 12, 30));
      expect(next?.prayerDate, DateTime(2026, 8, 7));
    });

    test('uygun tekrar günü yoksa bildirim gösterilmez', () {
      final next = resolveNextNotification(
        settings: const [
          NotificationSetting(
            prayerType: PrayerType.dhuhr,
            isActive: true,
            weekdays: {DateTime.friday},
          ),
        ],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 10),
      );

      expect(next, isNull);
    });

    const regular = NotificationSetting(
      prayerType: PrayerType.dhuhr,
      isActive: true,
      minutesBefore: 45,
    );
    const friday = NotificationSetting(
      prayerType: PrayerType.dhuhr,
      isActive: true,
      minutesBefore: 45,
      weekdays: {DateTime.friday},
      label: 'Cuma namazı',
    );
    for (final settings in [
      [regular, friday],
      [friday, regular],
    ]) {
      test('Cuma çakışmasında gün kısıtlı satır seçilir: '
          '${settings.first.isDayScoped ? 'özel önce' : 'genel önce'}', () {
        final next = resolveNextNotification(
          settings: settings,
          prayerTimes: [_day(7)],
          now: DateTime(2026, 8, 7, 10),
        );

        expect(next?.setting, friday);
        expect(next?.time, DateTime(2026, 8, 7, 12, 30));
      });
    }

    test('vakit günleri sırasız olsa da Cuma satırı çakışmayı kazanır', () {
      final next = resolveNextNotification(
        settings: const [regular, friday],
        prayerTimes: [_day(8), _day(7)],
        now: DateTime(2026, 8, 7, 10),
      );

      expect(next?.setting, friday);
      expect(next?.time, DateTime(2026, 8, 7, 12, 30));
    });

    for (final example in [
      (
        kind: DerivedTimeKind.ishraq,
        anchor: PrayerType.sunrise,
        expected: DateTime(2026, 8, 6, 6, 35),
      ),
      (
        kind: DerivedTimeKind.istiwa,
        anchor: PrayerType.dhuhr,
        expected: DateTime(2026, 8, 6, 13),
      ),
      (
        kind: DerivedTimeKind.preMaghrib,
        anchor: PrayerType.maghrib,
        expected: DateTime(2026, 8, 6, 19, 35),
      ),
      (
        kind: DerivedTimeKind.midnight,
        anchor: PrayerType.maghrib,
        expected: DateTime(2026, 8, 7, 0, 13),
      ),
      (
        kind: DerivedTimeKind.lastThird,
        anchor: PrayerType.maghrib,
        expected: DateTime(2026, 8, 7, 1, 30, 40),
      ),
    ]) {
      test('${example.kind.name} için hesaplanan vakitten offset düşülür', () {
        final next = resolveNextNotification(
          settings: [
            NotificationSetting(
              prayerType: example.anchor,
              derivedKind: example.kind,
              isActive: true,
              minutesBefore: 5,
            ),
          ],
          prayerTimes: [_day(6), _day(7)],
          now: DateTime(2026, 8, 6),
        );

        expect(next?.time, example.expected);
        expect(next?.prayerDate, DateTime(2026, 8, 6));
      });
    }

    for (final kind in [DerivedTimeKind.midnight, DerivedTimeKind.lastThird]) {
      test('${kind.name} ertesi gün verisi olmadan gösterilmez', () {
        final next = resolveNextNotification(
          settings: [
            NotificationSetting(
              prayerType: PrayerType.maghrib,
              derivedKind: kind,
              isActive: true,
            ),
          ],
          prayerTimes: [_day(6)],
          now: DateTime(2026, 8, 6, 19),
        );

        expect(next, isNull);
      });
    }
  });

  group('resolveNextFirePerNotification', () {
    test('her satır kendi tekrar günündeki ilk vakti gösterir', () {
      final result = resolveNextFirePerNotification(
        settings: const [
          NotificationSetting(prayerType: PrayerType.dhuhr, isActive: true),
          NotificationSetting(
            prayerType: PrayerType.dhuhr,
            isActive: true,
            weekdays: {DateTime.friday},
          ),
        ],
        prayerTimes: [_day(6), _day(7)],
        now: DateTime(2026, 8, 6, 10),
      );

      expect(result, {
        'dhuhr--0-': DateTime(2026, 8, 6, 13, 15),
        'dhuhr--0-5': DateTime(2026, 8, 7, 13, 15),
      });
    });

    test('offset önceki güne taşsa da gün filtresi vakte uygulanır', () {
      final result = resolveNextFirePerNotification(
        settings: const [
          NotificationSetting(
            prayerType: PrayerType.fajr,
            isActive: true,
            minutesBefore: 300,
            weekdays: {DateTime.thursday},
          ),
          NotificationSetting(
            prayerType: PrayerType.fajr,
            isActive: true,
            minutesBefore: 300,
            weekdays: {DateTime.friday},
          ),
        ],
        prayerTimes: [_day(7)],
        now: DateTime(2026, 8, 6, 22),
      );

      expect(result, {'fajr--300-5': DateTime(2026, 8, 6, 23, 11)});
    });

    test('gece noktalarında gün filtresi hesaplanan vakte uygulanır', () {
      final result = resolveNextFirePerNotification(
        settings: const [
          NotificationSetting(
            prayerType: PrayerType.maghrib,
            derivedKind: DerivedTimeKind.lastThird,
            isActive: true,
            weekdays: {DateTime.thursday},
          ),
          NotificationSetting(
            prayerType: PrayerType.maghrib,
            derivedKind: DerivedTimeKind.lastThird,
            isActive: true,
            weekdays: {DateTime.friday},
          ),
        ],
        prayerTimes: [_day(6), _day(7)],
        now: DateTime(2026, 8, 6, 19),
      );

      expect(result, {
        'maghrib-last_third-0-5': DateTime(2026, 8, 7, 1, 35, 40),
      });
    });
  });

  group('notificationOccurrence', () {
    for (final example in [
      (
        name: 'önceki gün tetiklenen bildirim',
        setting: const NotificationSetting(
          prayerType: PrayerType.fajr,
          isActive: true,
          minutesBefore: 300,
        ),
        remainingCount: 1,
      ),
      (
        name: 'ertesi güne taşan gece noktası',
        setting: const NotificationSetting(
          prayerType: PrayerType.maghrib,
          derivedKind: DerivedTimeKind.lastThird,
          isActive: true,
          minutesBefore: 15,
        ),
        remainingCount: 0,
      ),
    ]) {
      test('${example.name} scheduler kimliğiyle atlanır', () async {
        final now = DateTime.now();
        final sourceDate = DateTime(now.year, now.month, now.day + 2);
        final prayerTimes = [
          _dayAt(sourceDate),
          _dayAt(
            DateTime(sourceDate.year, sourceDate.month, sourceDate.day + 1),
          ),
        ];
        final settings = [example.setting];
        final next = resolveNextOccurrencePerNotification(
          settings: settings,
          prayerTimes: prayerTimes,
          now: now,
        )[notificationKey(example.setting)]!;
        final occurrence = notificationOccurrence(next);
        final service = RecordingNotificationService();
        final storage = NotificationTestStorage()..settings = settings;
        final scheduler = NotificationScheduler(
          notificationService: service,
          storage: storage,
          localizations: (_) =>
              AppLocalizations.delegate.load(const Locale('tr')),
        );
        final location = Location(
          id: 'location',
          province: 'İstanbul',
          district: 'Fatih',
          type: LocationType.manual,
        );

        await scheduler.scheduleNotifications(
          location: location,
          prayerTimes: prayerTimes,
        );

        expect(next.prayerDate, sourceDate);
        expect(occurrence.kind, SkipKind.notification);
        expect(int.tryParse(occurrence.reference), isNotNull);
        expect(occurrence.reference, service.calls.first.id);
        expect(occurrence.fireAt, service.calls.first.scheduledTime);

        service.calls.clear();
        await scheduler.scheduleNotifications(
          location: location,
          prayerTimes: prayerTimes,
          skips: {occurrence},
        );

        expect(service.calls.length, example.remainingCount);
        expect(
          service.calls.any((call) => call.id == occurrence.reference),
          isFalse,
        );
      });
    }
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

    test('Atlanmis alarmi yine de dondurur', () {
      // D2: kart bir sonrakine gecmez, satir yerinde kalir ki kullanici geri
      // acabilsin. Bu yuzden resolveNextAlarm skip kumesi ALMAZ.
      final next = resolveNextAlarm(
        alarms: const [fixed],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 23),
      );

      expect(next?.alarm.id, 'fixed');
      expect(next?.time, DateTime(2026, 8, 4, 6, 30));
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
