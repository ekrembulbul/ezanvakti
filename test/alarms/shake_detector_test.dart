import 'package:ezanvakti/features/alarms/domain/shake_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 8, 18, 5, 0);

  /// Esigi acikca gecen bir ornek.
  bool strongShake(ShakeDetector d, DateTime at) =>
      d.onSample(x: 25, y: 0, z: 0, at: at);

  group('ShakeDetector', () {
    test('Durgun telefonda sallama sayilmaz', () {
      final d = ShakeDetector();
      // Yalnizca yercekimi.
      expect(d.onSample(x: 0, y: 0, z: 9.81, at: t0), isFalse);
      expect(d.count, 0);
    });

    test('Hafif hareket esigi gecmez', () {
      final d = ShakeDetector();
      expect(d.onSample(x: 3, y: 3, z: 9.81, at: t0), isFalse);
      expect(d.count, 0);
    });

    test('Guclu silkeleme sayilir', () {
      final d = ShakeDetector();
      expect(strongShake(d, t0), isTrue);
      expect(d.count, 1);
    });

    test('Bekleme suresi dolmadan ikinci kez sayilmaz', () {
      final d = ShakeDetector();
      strongShake(d, t0);
      final tooSoon = t0.add(ShakeDetector.cooldown - const Duration(milliseconds: 1));
      expect(strongShake(d, tooSoon), isFalse);
      expect(d.count, 1);
    });

    test('Bekleme dolunca tekrar sayilir', () {
      final d = ShakeDetector();
      strongShake(d, t0);
      expect(strongShake(d, t0.add(ShakeDetector.cooldown)), isTrue);
      expect(d.count, 2);
    });

    test('reset sayaci ve beklemeyi sifirlar', () {
      final d = ShakeDetector();
      strongShake(d, t0);
      d.reset();
      expect(d.count, 0);
      expect(strongShake(d, t0), isTrue);
    });
  });

  group('targetFor', () {
    test('Seviye yukseldikce hedef artar', () {
      expect(ShakeDetector.targetFor(2), greaterThan(ShakeDetector.targetFor(1)));
      expect(ShakeDetector.targetFor(3), greaterThan(ShakeDetector.targetFor(2)));
    });

    test('Aralik disi seviye kirpilir', () {
      expect(ShakeDetector.targetFor(0), ShakeDetector.targetFor(1));
      expect(ShakeDetector.targetFor(9), ShakeDetector.targetFor(3));
    });
  });
}
