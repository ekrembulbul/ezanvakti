import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/features/ramadan/domain/ramadan_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ramazan ayinda aktif, disinda pasif, veri yoksa pasif', () {
    expect(
      RamadanMode.isActiveFor(const HijriDate(day: 1, month: 9, year: 1448)),
      isTrue,
    );
    expect(
      RamadanMode.isActiveFor(const HijriDate(day: 30, month: 9, year: 1448)),
      isTrue,
    );
    expect(
      RamadanMode.isActiveFor(const HijriDate(day: 1, month: 10, year: 1448)),
      isFalse,
    );
    expect(RamadanMode.isActiveFor(null), isFalse);
  });

  test('Ramazan gunu numarasi', () {
    expect(
      RamadanMode.dayOfRamadanFor(
        const HijriDate(day: 17, month: 9, year: 1448),
      ),
      17,
    );
    expect(
      RamadanMode.dayOfRamadanFor(
        const HijriDate(day: 17, month: 8, year: 1448),
      ),
      isNull,
    );
    expect(RamadanMode.dayOfRamadanFor(null), isNull);
  });
}
