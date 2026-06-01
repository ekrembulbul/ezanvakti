import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';

void main() {
  group('Location equality', () {
    test('Identical field values are equal and share a hash code', () {
      const a = Location(id: '1', province: 'İstanbul', district: 'Kadıköy');
      const b = Location(id: '1', province: 'İstanbul', district: 'Kadıköy');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('Differing field values are not equal', () {
      const a = Location(id: '1', province: 'İstanbul', district: 'Kadıköy');
      const b = Location(id: '2', province: 'İstanbul', district: 'Kadıköy');

      expect(a, isNot(equals(b)));
    });

    test('copyWith overrides only the given fields', () {
      const original = Location(
        id: '1',
        province: 'İstanbul',
        district: 'Kadıköy',
      );

      final updated = original.copyWith(type: LocationType.gps, latitude: 41.0);

      expect(updated.id, equals('1'));
      expect(updated.province, equals('İstanbul'));
      expect(updated.type, equals(LocationType.gps));
      expect(updated.latitude, equals(41.0));
    });
  });

  group('NotificationSetting equality', () {
    test('Identical settings are equal', () {
      const a = NotificationSetting(prayerType: PrayerType.fajr, isActive: true);
      const b = NotificationSetting(prayerType: PrayerType.fajr, isActive: true);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('Different minutesBefore makes settings unequal', () {
      const a = NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        minutesBefore: 0,
      );
      const b = NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        minutesBefore: 15,
      );

      expect(a, isNot(equals(b)));
    });
  });

  group('PrayerTime', () {
    final date = DateTime(2024, 1, 1);
    PrayerTime sample() => PrayerTime(
      fajr: DateTime(2024, 1, 1, 5, 30),
      sunrise: DateTime(2024, 1, 1, 7, 0),
      dhuhr: DateTime(2024, 1, 1, 13, 15),
      asr: DateTime(2024, 1, 1, 16, 30),
      maghrib: DateTime(2024, 1, 1, 19, 0),
      isha: DateTime(2024, 1, 1, 20, 30),
      date: date,
    );

    test('Identical prayer times are equal', () {
      expect(sample(), equals(sample()));
      expect(sample().hashCode, equals(sample().hashCode));
    });

    test('copyWith replaces a single prayer time', () {
      final updated = sample().copyWith(fajr: DateTime(2024, 1, 1, 6, 0));

      expect(updated.fajr, equals(DateTime(2024, 1, 1, 6, 0)));
      expect(updated.dhuhr, equals(sample().dhuhr));
      expect(updated, isNot(equals(sample())));
    });
  });
}
