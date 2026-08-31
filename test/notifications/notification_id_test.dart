import 'package:ezanvakti/core/models/derived_time.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String idFor(DateTime date, int pointIndex, int minutesBefore) =>
      NotificationScheduler.notificationIdFor(
        date: date,
        pointIndex: pointIndex,
        minutesBefore: minutesBefore,
      );

  test('id 32-bit sinirinda kalir', () {
    // En buyuk olasi bilesim: gun 9999, nokta 19, sapma 9999.
    final id = int.parse(idFor(DateTime(2026, 9, 4), 19, 9999));
    expect(id, lessThan(2147483647));
    expect(id, greaterThan(0));
  });

  test('farkli noktalar farkli id uretir', () {
    expect(idFor(DateTime(2026, 9, 4), 10, 45), isNot(idFor(DateTime(2026, 9, 4), 5, 45)));
  });

  test('ayni gun-nokta-offset ayni id uretir (gun ici saat onemsiz)', () {
    expect(
      idFor(DateTime(2026, 9, 4), 3, 0),
      idFor(DateTime(2026, 9, 4, 23, 59), 3, 0),
    );
  });

  test('ardisik gunler farkli id uretir', () {
    expect(
      idFor(DateTime(2026, 9, 4), 0, 0),
      isNot(idFor(DateTime(2026, 9, 5), 0, 0)),
    );
  });

  test('sapma id nin parcasi', () {
    expect(idFor(DateTime(2026, 9, 4), 2, 15), isNot(idFor(DateTime(2026, 9, 4), 2, 45)));
  });

  group('pointIndexOf', () {
    test('vakitler 0-5', () {
      for (final type in PrayerType.values) {
        expect(
          NotificationScheduler.pointIndexOf(
            NotificationSetting(prayerType: type, isActive: true),
          ),
          type.index,
        );
      }
    });

    test('turetilmis noktalar 6-10', () {
      for (final kind in DerivedTimeKind.values) {
        expect(
          NotificationScheduler.pointIndexOf(
            NotificationSetting(
              prayerType: kind.anchor,
              derivedKind: kind,
              isActive: true,
            ),
          ),
          6 + kind.index,
        );
      }
    });

    test('turetilmis nokta cipa vaktiyle cakismaz', () {
      const anchored = NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
      );
      const derived = NotificationSetting(
        prayerType: PrayerType.dhuhr,
        derivedKind: DerivedTimeKind.istiwa,
        isActive: true,
      );
      expect(
        NotificationScheduler.pointIndexOf(anchored),
        isNot(NotificationScheduler.pointIndexOf(derived)),
      );
    });
  });
}
