import 'package:ezanvakti/core/models/derived_time.dart';
import 'package:ezanvakti/core/models/notification_draft.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/reminder_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReminderPoint', () {
    test('Turetilmis nokta cipa vaktini tasir', () {
      final point = ReminderPoint.derivedPoint(DerivedTimeKind.istiwa);
      expect(point.anchor, PrayerType.dhuhr);
      expect(point.derived, DerivedTimeKind.istiwa);
      expect(point.isDerived, isTrue);
    });

    test('Vakit noktasinin turetilmis alani bos', () {
      const point = ReminderPoint.prayer(PrayerType.asr);
      expect(point.anchor, PrayerType.asr);
      expect(point.derived, isNull);
      expect(point.isDerived, isFalse);
    });

    test('Alti vakit ve bes hesaplanan nokta, bu sirayla', () {
      final all = ReminderPoint.all;
      expect(all, hasLength(11));
      expect(all.take(6).every((p) => !p.isDerived), isTrue);
      expect(all.skip(6).every((p) => p.isDerived), isTrue);
    });

    test('Esitlik deger bazli; vakit ile cipasi ayni nokta degil', () {
      expect(
        ReminderPoint.of(PrayerType.dhuhr, DerivedTimeKind.istiwa),
        ReminderPoint.derivedPoint(DerivedTimeKind.istiwa),
      );
      expect(
        ReminderPoint.of(PrayerType.dhuhr, null),
        const ReminderPoint.prayer(PrayerType.dhuhr),
      );
      expect(
        const ReminderPoint.prayer(PrayerType.dhuhr),
        isNot(ReminderPoint.derivedPoint(DerivedTimeKind.istiwa)),
      );
      expect({
        ReminderPoint.derivedPoint(DerivedTimeKind.midnight),
        ReminderPoint.derivedPoint(DerivedTimeKind.midnight),
      }, hasLength(1));
    });
  });

  group('NotificationDraft', () {
    test('Noktadan taslak: cipa vakti prayerType olarak yazilir', () {
      final draft = NotificationDraft.fromPoint(
        ReminderPoint.derivedPoint(DerivedTimeKind.lastThird),
        minutesBefore: 15,
        weekdays: const {5},
        label: 'Teheccüd',
      );
      expect(draft.prayerType, PrayerType.maghrib);
      expect(draft.derivedKind, DerivedTimeKind.lastThird);
      expect(draft.minutesBefore, 15);
      expect(draft.weekdays, {5});
      expect(draft.label, 'Teheccüd');
    });

    test('Varsayilan gunler bos kume (her gun), etiket yok', () {
      final draft = NotificationDraft.fromPoint(
        const ReminderPoint.prayer(PrayerType.fajr),
        minutesBefore: 0,
      );
      expect(draft.weekdays, isEmpty);
      expect(draft.label, isNull);
      expect(draft.derivedKind, isNull);
    });
  });
}
