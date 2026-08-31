import 'package:ezanvakti/features/ramadan/domain/ramadan_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 1448 Ramazan: 8 Subat – 9 Mart 2027 (tabular hicri hesap).
  final firstDay = DateTime(2027, 2, 8);
  final midMonth = DateTime(2027, 2, 20);
  final lastDay = DateTime(2027, 3, 8);
  final afterEid = DateTime(2027, 3, 10);

  test('Ramazan gunlerinde aktif', () {
    expect(RamadanMode.isActive(firstDay), isTrue);
    expect(RamadanMode.isActive(midMonth), isTrue);
    expect(RamadanMode.isActive(lastDay), isTrue);
  });

  test('Ramazan disinda pasif', () {
    expect(RamadanMode.isActive(DateTime(2027, 2, 7)), isFalse);
    expect(RamadanMode.isActive(afterEid), isFalse);
    expect(RamadanMode.isActive(DateTime(2026, 9, 1)), isFalse);
  });

  test('gun ici saat sonucu degistirmez', () {
    expect(
      RamadanMode.isActive(DateTime(2027, 2, 20, 23, 59)),
      RamadanMode.isActive(DateTime(2027, 2, 20)),
    );
  });

  test('Ramazan gunu numarasi', () {
    expect(RamadanMode.dayOfRamadan(firstDay), 1);
    expect(RamadanMode.dayOfRamadan(DateTime(2027, 2, 10)), 3);
    expect(RamadanMode.dayOfRamadan(afterEid), isNull);
  });
}
