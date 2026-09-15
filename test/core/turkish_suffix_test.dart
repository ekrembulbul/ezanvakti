import 'package:ezanvakti/core/utils/turkish_suffix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dakika sıfır değilse dakikanın son kelimesine göre ek gelir', () {
    expect(turkishLocativeSuffix(hour: 18, minute: 38), "'de"); // sekiz
    expect(turkishLocativeSuffix(hour: 19, minute: 23), "'te"); // üç
    expect(turkishLocativeSuffix(hour: 18, minute: 45), "'te"); // beş
    expect(turkishLocativeSuffix(hour: 18, minute: 46), "'da"); // altı
    expect(turkishLocativeSuffix(hour: 18, minute: 49), "'da"); // dokuz
    expect(turkishLocativeSuffix(hour: 18, minute: 40), "'ta"); // kırk
    expect(turkishLocativeSuffix(hour: 18, minute: 30), "'da"); // otuz
    expect(turkishLocativeSuffix(hour: 18, minute: 50), "'de"); // elli
    expect(turkishLocativeSuffix(hour: 18, minute: 10), "'da"); // on
  });

  test('dakika sıfırsa saat okunur', () {
    expect(turkishLocativeSuffix(hour: 13, minute: 0), "'te"); // on üç
    expect(turkishLocativeSuffix(hour: 10, minute: 0), "'da"); // on
    expect(turkishLocativeSuffix(hour: 20, minute: 0), "'de"); // yirmi
    expect(turkishLocativeSuffix(hour: 6, minute: 0), "'da"); // altı
    expect(turkishLocativeSuffix(hour: 0, minute: 0), "'da"); // sıfır
  });

  test('aralık dışı saat veya dakika hata fırlatır', () {
    expect(() => turkishLocativeSuffix(hour: 24, minute: 0), throwsRangeError);
    expect(() => turkishLocativeSuffix(hour: 1, minute: 60), throwsRangeError);
    expect(() => turkishLocativeSuffix(hour: -1, minute: 5), throwsRangeError);
  });
}
