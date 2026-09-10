import 'dart:math';

import 'package:ezanvakti/features/alarms/domain/math_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const levels = [1, 2, 3, 4];

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
    test('Dort seviye: 1, 2, 3, 3 soru', () {
      expect(levels.map(MathChallenge.questionCount), [1, 2, 3, 3]);
    });

    test('Seviye yukseldikce is miktari azalmaz', () {
      expect(
        MathChallenge.questionCount(2),
        greaterThan(MathChallenge.questionCount(1)),
      );
      expect(
        MathChallenge.questionCount(3),
        greaterThan(MathChallenge.questionCount(2)),
      );
      // Ekstrem soru sayisini degil islem zorlugunu artirir.
      expect(
        MathChallenge.questionCount(4),
        greaterThanOrEqualTo(MathChallenge.questionCount(3)),
      );
    });

    test('Aralik disi seviye en yakin uca kirpilir', () {
      expect(MathChallenge.questionCount(0), MathChallenge.questionCount(1));
      expect(
        MathChallenge.questionCount(9),
        MathChallenge.questionCount(MathChallenge.maxLevel),
      );
    });
  });

  group('MathChallenge.generate', () {
    test('Seviyeye gore soru sayisi uretir', () {
      for (final level in levels) {
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
        for (final level in levels) {
          final qs = MathChallenge.generate(level: level, random: Random(seed));
          for (final q in qs) {
            expect(q.answer, greaterThanOrEqualTo(0), reason: q.text);
          }
        }
      }
    });

    test('Kolay: iki haneli +/- tek haneli, carpma yok', () {
      for (var seed = 0; seed < 200; seed++) {
        for (final q in MathChallenge.generate(level: 1, random: Random(seed))) {
          expect(q.op, isNot(MathOp.multiply), reason: q.text);
          expect(q.a, inInclusiveRange(10, 99), reason: q.text);
          expect(q.b, inInclusiveRange(2, 9), reason: q.text);
          expect(q.answer, greaterThanOrEqualTo(1), reason: q.text);
        }
      }
    });

    test('Orta: iki haneli +/- iki haneli, carpma yok', () {
      for (var seed = 0; seed < 200; seed++) {
        for (final q in MathChallenge.generate(level: 2, random: Random(seed))) {
          expect(q.op, isNot(MathOp.multiply), reason: q.text);
          expect(q.a, inInclusiveRange(10, 99), reason: q.text);
          expect(q.b, inInclusiveRange(10, 99), reason: q.text);
        }
      }
    });

    test('Zor: iki haneli x tek haneli', () {
      for (var seed = 0; seed < 200; seed++) {
        for (final q in MathChallenge.generate(level: 3, random: Random(seed))) {
          expect(q.op, MathOp.multiply, reason: q.text);
          expect(q.a, inInclusiveRange(10, 99), reason: q.text);
          expect(q.b, inInclusiveRange(2, 9), reason: q.text);
        }
      }
    });

    test('Ekstrem: iki haneli x iki haneli', () {
      for (var seed = 0; seed < 200; seed++) {
        for (final q in MathChallenge.generate(level: 4, random: Random(seed))) {
          expect(q.op, MathOp.multiply, reason: q.text);
          expect(q.a, inInclusiveRange(11, 99), reason: q.text);
          expect(q.b, inInclusiveRange(11, 99), reason: q.text);
        }
      }
    });
  });
}
