import 'package:ezanvakti/features/qibla/domain/qibla_direction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Istanbul dan kible guneydogu yonunde', () {
    final bearing = QiblaDirection.bearing(
      latitude: 41.0082,
      longitude: 28.9784,
    );
    // Istanbul icin yaygin kabul ~151 derece.
    expect(bearing, closeTo(151, 2));
  });

  test('Kabe nin kuzeyinden bakinca kible tam guney', () {
    final bearing = QiblaDirection.bearing(
      latitude: QiblaDirection.kaabaLatitude + 10,
      longitude: QiblaDirection.kaabaLongitude,
    );
    expect(bearing, closeTo(180, 0.5));
  });

  test('Kabe nin guneyinden bakinca kible tam kuzey', () {
    final bearing = QiblaDirection.bearing(
      latitude: QiblaDirection.kaabaLatitude - 10,
      longitude: QiblaDirection.kaabaLongitude,
    );
    expect(bearing % 360, closeTo(0, 0.5));
  });

  test('sonuc her zaman 0-360 araliginda', () {
    for (final point in [
      (lat: -33.8688, lon: 151.2093), // Sidney
      (lat: 40.7128, lon: -74.0060), // New York
      (lat: 55.7558, lon: 37.6173), // Moskova
      (lat: -1.2921, lon: 36.8219), // Nairobi
    ]) {
      final bearing = QiblaDirection.bearing(
        latitude: point.lat,
        longitude: point.lon,
      );
      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
    }
  });

  test('New York tan kible kuzeydogu', () {
    final bearing = QiblaDirection.bearing(latitude: 40.7128, longitude: -74.0060);
    expect(bearing, closeTo(58, 3));
  });

  group('difference', () {
    test('en kisa yolu isaretli olarak verir', () {
      expect(QiblaDirection.difference(350, 10), closeTo(20, 0.001));
      expect(QiblaDirection.difference(10, 350), closeTo(-20, 0.001));
      expect(QiblaDirection.difference(0, 180), closeTo(180, 0.001));
    });

    test('sonuc -180 ile 180 arasinda', () {
      for (var heading = 0.0; heading < 360; heading += 17) {
        for (var qibla = 0.0; qibla < 360; qibla += 23) {
          final diff = QiblaDirection.difference(heading, qibla);
          expect(diff, greaterThanOrEqualTo(-180));
          expect(diff, lessThanOrEqualTo(180));
        }
      }
    });
  });
}
