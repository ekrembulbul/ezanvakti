import 'package:ezanvakti/core/data/religious_days.dart';
import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/religious_day.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/hijri_fixtures.dart';

void main() {
  /// [start]'tan itibaren [count] gün, ilk günün Hicri'si [first].
  List<PrayerTime> days(DateTime start, int count, HijriDate first) =>
      withSequentialHijri(
        List.generate(
          count,
          (i) =>
              prayerTimeFor(DateTime(start.year, start.month, start.day + i)),
        ),
        first,
      );

  test('Ramazan baslangici ve Kadir Gecesi Diyanet Hicrisinden bulunur', () {
    // 8 Şubat 2027 = 1 Ramazan; 6 Mart = 27 Ramazan (30 günlük sahte ay).
    final list = ReligiousDays.fromDays(
      days(
        DateTime(2027, 2, 6),
        40,
        const HijriDate(day: 29, month: 8, year: 1448),
      ),
    );
    final ramadan = list
        .where((d) => d.kind == ReligiousDayKind.ramadanStart)
        .single;
    expect(ramadan.date, DateTime(2027, 2, 8));
    final qadr = list.where((d) => d.id == ReligiousDayId.qadr).single;
    expect(qadr.date, DateTime(2027, 3, 6));
    final eid = list.where((d) => d.kind == ReligiousDayKind.bayram).single;
    expect(
      eid.date,
      DateTime(2027, 3, 10),
    ); // 30 günlük sahte Ramazan → 1 Şevval
  });

  test('Regaib: Recep ayinin ilk Persembesi', () {
    // 1 Recep = 9 Ocak 2027 (Cumartesi); ilk Perşembe 14 Ocak.
    final list = ReligiousDays.fromDays(
      days(
        DateTime(2027, 1, 9),
        10,
        const HijriDate(day: 1, month: 7, year: 1448),
      ),
    );
    final regaib = list.where((d) => d.id == ReligiousDayId.regaib).single;
    expect(regaib.date, DateTime(2027, 1, 14));
  });

  test('Hicrisi olmayan gunler yok sayilir; sonuc sirali ve tekrarsiz', () {
    final base = List.generate(
      5,
      (i) => prayerTimeFor(DateTime(2027, 2, 6 + i)),
    );
    expect(ReligiousDays.fromDays(base), isEmpty);
    final list = ReligiousDays.fromDays(
      days(
        DateTime(2026, 1, 1),
        400,
        const HijriDate(day: 12, month: 7, year: 1447),
      ),
    );
    for (var i = 1; i < list.length; i++) {
      expect(list[i].date.isBefore(list[i - 1].date), isFalse);
    }
    expect(
      list.map((d) => '${d.date}-${d.id.name}').toSet(),
      hasLength(list.length),
    );
  });
}
