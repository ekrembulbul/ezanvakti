import 'package:ezanvakti/features/location/domain/location_monitor_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uygulama her acildiginda GPS akisindan ilk fix gelir. Referans koordinat
/// kayitli konumdan tohumlandigi icin, kullanici gercekten tasinmadikca bu fix
/// "onemli degisim" sayilmamalidir.
void main() {
  const istanbul = (latitude: 41.008, longitude: 28.978);
  final now = DateTime(2026, 8, 3, 12);

  test('Referans yokken ilk fix onemli sayilir', () {
    expect(
      isSignificantLocationChange(
        previous: null,
        current: istanbul,
        lastUpdate: null,
        now: now,
      ),
      isTrue,
    );
  });

  test('Ayni yerdeki ilk fix onemli sayilmaz', () {
    // 50 metre sapma: GPS gurultusu, tasinma degil.
    const nearby = (latitude: 41.0084, longitude: 28.9785);

    expect(
      isSignificantLocationChange(
        previous: istanbul,
        current: nearby,
        lastUpdate: null,
        now: now,
      ),
      isFalse,
    );
  });

  test('Bes kilometreden uzak fix onemli sayilir', () {
    // ~11 km kuzey.
    const faraway = (latitude: 41.108, longitude: 28.978);

    expect(
      isSignificantLocationChange(
        previous: istanbul,
        current: faraway,
        lastUpdate: null,
        now: now,
      ),
      isTrue,
    );
  });

  test('Son guncellemeden bu yana 30 dakika gecmediyse onemli sayilmaz', () {
    const faraway = (latitude: 41.108, longitude: 28.978);

    expect(
      isSignificantLocationChange(
        previous: istanbul,
        current: faraway,
        lastUpdate: now.subtract(const Duration(minutes: 5)),
        now: now,
      ),
      isFalse,
    );
  });
}
