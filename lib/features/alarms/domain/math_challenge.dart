import 'dart:math';

enum MathOp { add, subtract, multiply }

/// Tek bir matematik sorusu. Değişmez; ekranda [text], doğrulamada [answer].
class MathQuestion {
  final int a;
  final int b;
  final MathOp op;

  const MathQuestion({required this.a, required this.b, required this.op});

  int get answer => switch (op) {
    MathOp.add => a + b,
    MathOp.subtract => a - b,
    MathOp.multiply => a * b,
  };

  /// Ekranda gösterilecek metin. Eksi işareti için U+2212 kullanılır; kısa
  /// tire rakamların yanında tire gibi okunuyor.
  String get text => switch (op) {
    MathOp.add => '$a + $b',
    MathOp.subtract => '$a − $b',
    MathOp.multiply => '$a × $b',
  };
}

/// Matematik görevinin soru üretimi ve zorluk kademeleri.
///
/// Dört seviye: Kolay (1), Orta (2), Zor (3), Ekstrem (4). Zorluk **soru
/// sayısı ve işlemle** artar, süreyle değil: görev süresi tipe göre sabittir.
/// Ekstrem soru sayısını değil işlemi ağırlaştırır — 90 saniyede üç iki
/// haneli çarpma zaten uyku sersemi biri için sınırda.
class MathChallenge {
  const MathChallenge._();

  static const int maxLevel = 4;

  static const Map<int, int> _counts = {1: 1, 2: 2, 3: 3, 4: 3};

  static int _clampLevel(int level) => level.clamp(1, maxLevel);

  static int questionCount(int level) => _counts[_clampLevel(level)]!;

  /// [level] için soru üretir. [random] dışarıdan verilir ki testler
  /// deterministik olsun.
  static List<MathQuestion> generate({
    required int level,
    required Random random,
  }) {
    final l = _clampLevel(level);
    return [for (var i = 0; i < questionCount(l); i++) _one(l, random)];
  }

  static MathQuestion _one(int level, Random random) {
    switch (level) {
      case 1:
        // Kolay: iki haneli ± tek haneli. a ≥ 10 > b oldugu icin cikarma
        // negatif olmaz.
        return MathQuestion(
          a: 10 + random.nextInt(90),
          b: 2 + random.nextInt(8),
          op: random.nextBool() ? MathOp.add : MathOp.subtract,
        );
      case 2:
        // Orta: iki haneli ± iki haneli. Cikarmada buyuk sayi one alinir ki
        // sonuc negatif olmasin.
        final op = random.nextBool() ? MathOp.add : MathOp.subtract;
        final x = 10 + random.nextInt(90);
        final y = 10 + random.nextInt(90);
        return op == MathOp.subtract
            ? MathQuestion(a: max(x, y), b: min(x, y), op: op)
            : MathQuestion(a: x, b: y, op: op);
      case 3:
        // Zor: iki haneli x tek haneli.
        return MathQuestion(
          a: 10 + random.nextInt(90),
          b: 2 + random.nextInt(8),
          op: MathOp.multiply,
        );
      default:
        // Ekstrem: iki haneli x iki haneli.
        return MathQuestion(
          a: 11 + random.nextInt(89),
          b: 11 + random.nextInt(89),
          op: MathOp.multiply,
        );
    }
  }
}
