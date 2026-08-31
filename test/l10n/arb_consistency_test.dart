import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ARB dosyaları elle düzenleniyor; bir dile anahtar eklemeyi unutmak
/// uygulamada boş metin değil, derleme hatası ya da yanlış dil demek.
/// Bu test üç dosyanın aynı anahtar kümesini taşıdığını garanti eder.
void main() {
  Map<String, dynamic> read(String locale) {
    final file = File('lib/l10n/app_$locale.arb');
    expect(file.existsSync(), isTrue, reason: 'app_$locale.arb bulunamadi');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  Set<String> keysOf(Map<String, dynamic> arb) => arb.keys
      .where((key) => !key.startsWith('@'))
      .toSet();

  test('uc dil ayni anahtarlari tasir', () {
    final tr = keysOf(read('tr'));
    final en = keysOf(read('en'));
    final ar = keysOf(read('ar'));

    expect(en.difference(tr), isEmpty, reason: 'ingilizcede fazla anahtar');
    expect(tr.difference(en), isEmpty, reason: 'ingilizcede eksik anahtar');
    expect(tr.difference(ar), isEmpty, reason: 'arapcada eksik anahtar');
    expect(ar.difference(tr), isEmpty, reason: 'arapcada fazla anahtar');
  });

  test('hicbir ceviri bos degil', () {
    for (final locale in ['tr', 'en', 'ar']) {
      final arb = read(locale);
      for (final key in keysOf(arb)) {
        expect(
          (arb[key] as String).trim(),
          isNotEmpty,
          reason: '$locale/$key bos',
        );
      }
    }
  });

  test('yer tutucular tum dillerde ayni', () {
    final pattern = RegExp(r'\{(\w+)\}');
    final tr = read('tr');
    for (final locale in ['en', 'ar']) {
      final other = read(locale);
      for (final key in keysOf(tr)) {
        final expected = pattern
            .allMatches(tr[key] as String)
            .map((m) => m.group(1))
            .toSet();
        final actual = pattern
            .allMatches(other[key] as String)
            .map((m) => m.group(1))
            .toSet();
        expect(actual, expected, reason: '$locale/$key yer tutucusu farkli');
      }
    }
  });

  test('cevirilerin dili karismamis (tr metni en dosyasinda kalmamis)', () {
    final tr = read('tr');
    final en = read('en');
    // Ozel adlar ve kisaltmalar ayni kalabilir; yalnizca uzun metinlerde
    // birebir ayniliga bakiyoruz.
    for (final key in keysOf(tr)) {
      final trValue = tr[key] as String;
      if (trValue.length < 20) continue;
      expect(
        en[key],
        isNot(trValue),
        reason: '$key ingilizceye cevrilmemis',
      );
    }
  });
}
