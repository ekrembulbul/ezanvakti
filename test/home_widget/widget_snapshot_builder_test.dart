import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot_builder.dart';

PrayerTime _day(DateTime date) => PrayerTime(
  date: date,
  fajr: DateTime(date.year, date.month, date.day, 4, 12),
  sunrise: DateTime(date.year, date.month, date.day, 5, 52),
  dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
  asr: DateTime(date.year, date.month, date.day, 16, 58),
  maghrib: DateTime(date.year, date.month, date.day, 20, 26),
  isha: DateTime(date.year, date.month, date.day, 21, 58),
);

List<PrayerTime> _range(DateTime start, int count) =>
    List.generate(count, (i) => _day(start.add(Duration(days: i))));

const _location = Location(
  id: 'loc-1',
  province: 'İstanbul',
  district: 'Kadıköy',
);

void main() {
  final today = DateTime(2026, 8, 25);

  group('WidgetSnapshotBuilder.build', () {
    test('bugunden onceki gunler elenir, bugun dahil edilir', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: _range(today.subtract(const Duration(days: 2)), 4),
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.days.first.date, today);
      expect(snapshot.days.length, 2);
    });

    test('gece yarisindan sonra bugunun gunu hala dahil edilir', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: _range(today, 3),
        now: DateTime(2026, 8, 25, 2, 0),
      );

      expect(snapshot.days.first.date, today);
    });

    test('pencere en fazla 7 gundur', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: _range(today, 30),
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.days.length, WidgetSnapshotBuilder.maxDays);
    });

    test('onbellekte daha az gun varsa pencere kisalir', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: _range(today, 3),
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.days.length, 3);
    });

    test('bos vakit listesi bos days uretir', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: const [],
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.days, isEmpty);
    });

    test('gunler tarihe gore sirali doner', () {
      final shuffled = [
        _day(today.add(const Duration(days: 2))),
        _day(today),
        _day(today.add(const Duration(days: 1))),
      ];

      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: shuffled,
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.days.map((day) => day.date).toList(), [
        today,
        today.add(const Duration(days: 1)),
        today.add(const Duration(days: 2)),
      ]);
    });

    test('locationLabel Location.displayName ile aynidir', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: _range(today, 1),
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.locationLabel, _location.displayName);
    });
  });
}
