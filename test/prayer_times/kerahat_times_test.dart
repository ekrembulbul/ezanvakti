import 'package:ezanvakti/core/models/derived_time.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/prayer_times/domain/derived_times.dart';
import 'package:ezanvakti/features/prayer_times/domain/kerahat_times.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerTime _day({
  DateTime? fajr,
  DateTime? sunrise,
  DateTime? dhuhr,
  DateTime? asr,
  DateTime? maghrib,
  DateTime? isha,
  DateTime? date,
}) {
  DateTime at(int hour, [int minute = 0]) => DateTime(2026, 8, 2, hour, minute);

  return PrayerTime(
    fajr: fajr ?? at(4),
    sunrise: sunrise ?? at(6),
    dhuhr: dhuhr ?? at(13),
    asr: asr ?? at(17),
    maghrib: maghrib ?? at(20),
    isha: isha ?? at(22),
    date: date ?? DateTime(2026, 8, 2),
  );
}

void main() {
  group('KerahatTimes.forDay', () {
    test('varsayilan 45/10/45 dakikalik uc araligi hesaplar', () {
      final intervals = KerahatTimes.forDay(_day());

      expect(intervals, hasLength(3));
      expect(intervals[0].kind, KerahatKind.afterSunrise);
      expect(intervals[0].start, DateTime(2026, 8, 2, 6));
      expect(intervals[0].end, DateTime(2026, 8, 2, 6, 45));
      expect(intervals[1].kind, KerahatKind.beforeDhuhr);
      expect(intervals[1].start, DateTime(2026, 8, 2, 12, 50));
      expect(intervals[1].end, DateTime(2026, 8, 2, 13));
      expect(intervals[2].kind, KerahatKind.beforeMaghrib);
      expect(intervals[2].start, DateTime(2026, 8, 2, 19, 15));
      expect(intervals[2].end, DateTime(2026, 8, 2, 20));
    });

    test('ozel ayarlarda bildirimlerle ayni turetilmis sinirlari kullanir', () {
      const settings = DerivedTimeSettings(
        ishraqMinutes: 35,
        istiwaMinutes: 7,
        preMaghribMinutes: 50,
      );
      final day = _day();
      final intervals = KerahatTimes.forDay(day, settings: settings);

      expect(
        intervals[0].end,
        DerivedTimes.resolve(
          kind: DerivedTimeKind.ishraq,
          day: day,
          settings: settings,
        ),
      );
      expect(
        intervals[1].start,
        DerivedTimes.resolve(
          kind: DerivedTimeKind.istiwa,
          day: day,
          settings: settings,
        ),
      );
      expect(
        intervals[2].start,
        DerivedTimes.resolve(
          kind: DerivedTimeKind.preMaghrib,
          day: day,
          settings: settings,
        ),
      );
    });

    test('baslangici dahil bitisi haric tutar', () {
      final interval = KerahatTimes.forDay(_day()).first;

      expect(interval.contains(DateTime(2026, 8, 2, 5, 59)), isFalse);
      expect(interval.contains(DateTime(2026, 8, 2, 6)), isTrue);
      expect(interval.contains(DateTime(2026, 8, 2, 6, 44, 59)), isTrue);
      expect(interval.contains(DateTime(2026, 8, 2, 6, 45)), isFalse);
    });

    test('ertesi takvim gununde bugunun araliklarini aktif saymaz', () {
      final intervals = KerahatTimes.forDay(_day());

      expect(
        intervals.any((interval) => interval.contains(DateTime(2026, 8, 3))),
        isFalse,
      );
    });

    test('vakit sirasi tersse aralik uydurmaz', () {
      final invalid = _day(asr: DateTime(2026, 8, 2, 12, 30));

      expect(KerahatTimes.forDay(invalid), isEmpty);
    });

    test('vakitlerden biri kaynak gunun disindaysa aralik uydurmaz', () {
      final invalid = _day(isha: DateTime(2026, 8, 3));

      expect(KerahatTimes.forDay(invalid), isEmpty);
    });
  });
}
