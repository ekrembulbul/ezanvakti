import 'package:ezanvakti/core/utils/turkish_fold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Turkce kucuk harf ve ASCII katlama', () {
    expect(foldTR('İSTANBUL'), 'istanbul');
    expect(foldTR('IĞDIR'), 'igdir');
    expect(foldTR('Şile'), 'sile');
    expect(foldTR('CUBUK'), foldTR('Çubuk'));
    expect(foldTR('Elâzığ'), foldTR('ELAZIĞ'));
    expect(foldTR('Büyük Orhan'), 'buyukorhan');
    expect(foldTR('Kemer (B)'), 'kemerb');
  });
}
