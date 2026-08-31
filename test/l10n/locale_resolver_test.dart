import 'dart:ui';

import 'package:ezanvakti/l10n/locale_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desteklenen dil aynen secilir', () {
    expect(LocaleResolver.resolve(const Locale('tr')), const Locale('tr'));
    expect(LocaleResolver.resolve(const Locale('en')), const Locale('en'));
    expect(LocaleResolver.resolve(const Locale('ar')), const Locale('ar'));
  });

  test('ulke kodu goz ardi edilir', () {
    expect(LocaleResolver.resolve(const Locale('tr', 'CY')), const Locale('tr'));
    expect(LocaleResolver.resolve(const Locale('en', 'GB')), const Locale('en'));
    expect(LocaleResolver.resolve(const Locale('ar', 'EG')), const Locale('ar'));
  });

  test('desteklenmeyen dil ingilizceye duser', () {
    expect(LocaleResolver.resolve(const Locale('de')), LocaleResolver.fallback);
    expect(LocaleResolver.resolve(const Locale('fr')), const Locale('en'));
    expect(LocaleResolver.resolve(const Locale('ja')), const Locale('en'));
  });

  test('cihaz dili bilinmiyorsa ingilizce', () {
    expect(LocaleResolver.resolve(null), const Locale('en'));
  });

  test('geri dusme dili ingilizce', () {
    expect(LocaleResolver.fallback, const Locale('en'));
  });
}
