import 'package:ezanvakti/core/data/religious_days.dart';
import 'package:ezanvakti/core/models/religious_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<ReligiousDay> range(DateTime start, DateTime end) =>
      ReligiousDays.forRange(start, end);

  test('Ramazan baslangici hicri takvimden bulunur', () {
    // 1448 Ramazan 1 = 8 Subat 2027 (tabular hicri hesap).
    final days = range(DateTime(2027, 2, 1), DateTime(2027, 2, 20));
    final ramadan = days.where((d) => d.kind == ReligiousDayKind.ramadanStart);
    expect(ramadan, hasLength(1));
    expect(ramadan.first.date, DateTime(2027, 2, 8));
  });

  test('Kadir Gecesi Ramazan 27 de', () {
    final days = range(DateTime(2027, 2, 1), DateTime(2027, 3, 15));
    final qadr = days.where((d) => d.id == ReligiousDayId.qadr);
    expect(qadr, hasLength(1));
    expect(qadr.first.date, DateTime(2027, 3, 6));
  });

  test('Ramazan Bayrami Sevval 1 de', () {
    final days = range(DateTime(2027, 3, 1), DateTime(2027, 3, 20));
    final eid = days.where((d) => d.kind == ReligiousDayKind.bayram);
    expect(eid, isNotEmpty);
    expect(eid.first.date, DateTime(2027, 3, 9));
  });

  test('aralik disindaki gunler donmez', () {
    final days = range(DateTime(2027, 5, 1), DateTime(2027, 5, 10));
    for (final day in days) {
      expect(day.date.isBefore(DateTime(2027, 5, 1)), isFalse);
      expect(day.date.isAfter(DateTime(2027, 5, 10)), isFalse);
    }
  });

  test('sonuclar tarihe gore sirali ve tekrarsiz', () {
    final days = range(DateTime(2026, 9, 1), DateTime(2028, 9, 1));
    expect(days, isNotEmpty);
    for (var i = 1; i < days.length; i++) {
      expect(days[i].date.isBefore(days[i - 1].date), isFalse);
    }
    final keys = days.map((d) => '${d.date}-${d.id.name}').toSet();
    expect(keys.length, days.length);
  });

  test('Regaib Recep ayinin ilk persembesi', () {
    final days = range(DateTime(2026, 12, 1), DateTime(2027, 1, 31));
    final regaib = days.where((d) => d.id == ReligiousDayId.regaib);
    expect(regaib, hasLength(1));
    expect(regaib.first.date.weekday, DateTime.thursday);
  });

  test('tum kayitlar hesaplanmis olarak isaretli', () {
    final days = range(DateTime(2026, 9, 1), DateTime(2027, 9, 1));
    expect(days.every((d) => d.isEstimated), isTrue);
  });

  test('bir yillik aralikta tum kandil ve bayramlar bulunur', () {
    // Hicri yil miladi yildan kisa oldugu icin bazi gunler iki kez dusebilir;
    // en az bir tam hicri yil kapsandigindan hepsi bulunmali.
    final days = range(DateTime(2026, 9, 1), DateTime(2027, 9, 1));
    final ids = days.map((d) => d.id).toSet();
    for (final expected in ReligiousDayId.values) {
      expect(ids, contains(expected), reason: expected.name);
    }
  });
}
