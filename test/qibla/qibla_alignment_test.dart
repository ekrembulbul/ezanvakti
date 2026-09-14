import 'package:ezanvakti/features/qibla/domain/qibla_alignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QiblaAlignment.resolve', () {
    test('giris esigi dar: 2.5 dereceye kadar hizali', () {
      expect(QiblaAlignment.resolve(delta: 2.5, wasAligned: false), isTrue);
      expect(QiblaAlignment.resolve(delta: -2.5, wasAligned: false), isTrue);
      expect(QiblaAlignment.resolve(delta: 3, wasAligned: false), isFalse);
      expect(QiblaAlignment.resolve(delta: -3, wasAligned: false), isFalse);
    });

    test('hizadayken cikis esigi daha genis: 4 dereceye kadar kalir', () {
      expect(QiblaAlignment.resolve(delta: 3.9, wasAligned: true), isTrue);
      expect(QiblaAlignment.resolve(delta: -3.9, wasAligned: true), isTrue);
      expect(QiblaAlignment.resolve(delta: 4.1, wasAligned: true), isFalse);
    });

    test('eski 5 derecelik pay artik hizali sayilmaz', () {
      expect(QiblaAlignment.resolve(delta: 5, wasAligned: false), isFalse);
      expect(QiblaAlignment.resolve(delta: 5, wasAligned: true), isFalse);
    });
  });

  group('QiblaAlignment.shortestStep', () {
    test('kucuk degisim oldugu gibi gecer', () {
      expect(QiblaAlignment.shortestStep(from: 10, to: 13), 3);
      expect(QiblaAlignment.shortestStep(from: 10, to: 7), -3);
    });

    test('±180 sinirini gecerken en kisa yol secilir', () {
      expect(QiblaAlignment.shortestStep(from: 179, to: -179), 2);
      expect(QiblaAlignment.shortestStep(from: -179, to: 179), -2);
    });
  });
}
