import 'dart:math';

import 'package:ezanvakti/features/alarms/domain/math_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MathQuestion', () {
    test('Dort islem dogru hesaplanir', () {
      expect(const MathQuestion(a: 7, b: 5, op: MathOp.add).answer, 12);
      expect(const MathQuestion(a: 7, b: 5, op: MathOp.subtract).answer, 2);
      expect(const MathQuestion(a: 7, b: 5, op: MathOp.multiply).answer, 35);
    });

    test('Metin ekranda okunacak bicimde', () {
      expect(
        const MathQuestion(a: 12, b: 3, op: MathOp.multiply).text,
        '12 × 3',
      );
      expect(
        const MathQuestion(a: 12, b: 3, op: MathOp.subtract).text,
        '12 − 3',
      );
    });
  });

  group('MathChallenge.questionCount', () {
    test('Seviye yukseldikce is miktari artar', () {
      expect(
        MathChallenge.questionCount(2),
        greaterThan(MathChallenge.questionCount(1)),
      );
      expect(
        MathChallenge.questionCount(3),
        greaterThan(MathChallenge.questionCount(2)),
      );
    });

    test('Aralik disi seviye en yakin uca kirpilir', () {
      expect(MathChallenge.questionCount(0), MathChallenge.questionCount(1));
      expect(MathChallenge.questionCount(9), MathChallenge.questionCount(3));
    });
  });

  group('MathChallenge.generate', () {
    test('Seviyeye gore soru sayisi uretir', () {
      for (final level in [1, 2, 3]) {
        final qs = MathChallenge.generate(level: level, random: Random(1));
        expect(qs, hasLength(MathChallenge.questionCount(level)));
      }
    });

    test('Ayni seed ayni sorulari verir (deterministik)', () {
      final a = MathChallenge.generate(level: 2, random: Random(42));
      final b = MathChallenge.generate(level: 2, random: Random(42));
      expect([for (final q in a) q.text], [for (final q in b) q.text]);
    });

    test('Cikarmada sonuc negatif olmaz', () {
      // Uykulu kullaniciya negatif sayi sordurmak gereksiz zorluk.
      for (var seed = 0; seed < 200; seed++) {
        for (final level in [1, 2, 3]) {
          final qs = MathChallenge.generate(level: level, random: Random(seed));
          for (final q in qs) {
            expect(q.answer, greaterThanOrEqualTo(0), reason: q.text);
          }
        }
      }
    });

    test('Seviye 1 carpma icermez', () {
      for (var seed = 0; seed < 100; seed++) {
        final qs = MathChallenge.generate(level: 1, random: Random(seed));
        expect(qs.every((q) => q.op != MathOp.multiply), isTrue);
      }
    });

    test('Islemler tek haneli-asikar olmaz: en az bir operand > 9', () {
      for (var seed = 0; seed < 100; seed++) {
        final qs = MathChallenge.generate(level: 3, random: Random(seed));
        for (final q in qs) {
          expect(q.a > 9 || q.b > 9, isTrue, reason: q.text);
        }
      }
    });
  });
}
