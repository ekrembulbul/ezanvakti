import 'package:ezanvakti/core/models/location.dart';
import 'package:flutter_test/flutter_test.dart';

/// GPS reverse geocoding basarisiz oldugunda uretilen etiketin okunabilir
/// sirada olmasi gerekiyor. `Location.displayName` "$district, $province"
/// urettigi icin fallback'te koordinat province'a, etiket district'e konuyor.
void main() {
  test('GPS fallback etiketi okunabilir sirada', () {
    const coordsLabel = '41.008, 28.978';
    const location = Location(
      id: 'gps',
      province: coordsLabel,
      district: 'GPS Konumu',
      type: LocationType.gps,
    );

    expect(location.displayName, 'GPS Konumu, 41.008, 28.978');
  });

  test('Normal GPS etiketi ilce, il sirasinda', () {
    const location = Location(
      id: 'gps',
      province: 'İstanbul',
      district: 'Kadıköy',
      type: LocationType.gps,
    );

    expect(location.displayName, 'Kadıköy, İstanbul');
  });

  test('Ozel isim verilmisse displayName onu kullanir', () {
    const location = Location(
      id: '1',
      province: 'İstanbul',
      district: 'Kadıköy',
      customName: 'Ev',
    );

    expect(location.displayName, 'Ev');
  });
}
