import 'package:ezanvakti/core/models/location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapped = Location(
    id: 'diyanet-9547',
    province: 'İstanbul',
    district: 'Şile',
    latitude: 41.1758,
    longitude: 29.6127,
    cityId: 9547,
    stateId: 539,
    countryId: 2,
    displayLabel: 'Şile, İstanbul',
  );

  test('isMapped yalniz cityId varsa', () {
    expect(mapped.isMapped, isTrue);
    expect(
      const Location(id: 'x', province: 'A', district: 'B').isMapped,
      isFalse,
    );
  });

  test('displayName: customName > displayLabel > ilce, il', () {
    expect(mapped.displayName, 'Şile, İstanbul');
    expect(mapped.copyWith(customName: 'Ev').displayName, 'Ev');
    expect(
      const Location(
        id: 'x',
        province: 'İstanbul',
        district: 'Kadıköy',
      ).displayName,
      'Kadıköy, İstanbul',
    );
    expect(
      const Location(
        id: 'c',
        province: 'İstanbul',
        district: 'İstanbul',
        displayLabel: 'İstanbul (Merkez)',
      ).displayName,
      'İstanbul (Merkez)',
    );
    // displayLabel yoksa yedek yol: il merkezinde tekrar eden ad tek yazılır,
    // boş ilçe yalnız ili bırakır.
    expect(
      const Location(
        id: 'a',
        province: 'Ankara',
        district: 'Ankara',
      ).displayName,
      'Ankara',
    );
    expect(
      const Location(id: 'b', province: 'Ankara', district: '  ').displayName,
      'Ankara',
    );
  });

  test('JSON gidis-donus yeni alanlari korur, eski JSON okunur', () {
    expect(Location.fromJson(mapped.toJson()), mapped);
    final legacy = Location.fromJson({
      'id': 'gps',
      'province': 'İstanbul',
      'district': 'Şile',
      'latitude': 41.1,
      'longitude': 29.6,
      'type': 'gps',
      'customName': null,
      'method': 13,
      'school': 0,
      'latitudeAdjustmentMethod': null,
    });
    expect(legacy.isMapped, isFalse);
    expect(legacy.cityId, isNull);
    expect(legacy.displayLabel, isNull);
  });

  test('copyWith ve esitlik yeni alanlari kapsar', () {
    final changed = mapped.copyWith(
      cityId: 9541,
      displayLabel: 'İstanbul (Merkez)',
    );
    expect(changed.cityId, 9541);
    expect(changed, isNot(mapped));
    expect(mapped.copyWith(), mapped);
  });
}
