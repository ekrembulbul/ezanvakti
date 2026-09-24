import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON gidis-donus', () {
    const h = HijriDate(day: 4, month: 4, year: 1448);
    expect(HijriDate.fromJson(h.toJson()), h);
    expect(h.toJson(), {'day': 4, 'month': 4, 'year': 1448});
  });

  test('gecersiz ay/gun FormatException', () {
    expect(
      () => HijriDate.fromJson({'day': 31, 'month': 4, 'year': 1448}),
      throwsFormatException,
    );
    expect(
      () => HijriDate.fromJson({'day': 1, 'month': 13, 'year': 1448}),
      throwsFormatException,
    );
    expect(
      () => HijriDate.fromJson({'day': 1, 'month': 1}),
      throwsFormatException,
    );
  });

  test('esitlik ve hash', () {
    expect(
      const HijriDate(day: 1, month: 9, year: 1447),
      const HijriDate(day: 1, month: 9, year: 1447),
    );
    expect(
      const HijriDate(day: 1, month: 9, year: 1447).hashCode,
      const HijriDate(day: 1, month: 9, year: 1447).hashCode,
    );
    expect(
      const HijriDate(day: 1, month: 9, year: 1447),
      isNot(const HijriDate(day: 2, month: 9, year: 1447)),
    );
  });
}
