import 'package:ezanvakti/core/utils/hijri_formatter.dart';
import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 9, 15);

  test('ay adı verilen çeviriden gelir', () {
    expect(
      HijriFormatter.format(date, lookupAppLocalizations(const Locale('tr'))),
      '4 Rebiülahir 1448',
    );
    expect(
      HijriFormatter.format(date, lookupAppLocalizations(const Locale('en'))),
      '4 Rabi al-Thani 1448',
    );
  });

  test('çeviri verilmezse kaynak dil Türkçe kullanılır, İngilizce değil', () {
    expect(HijriFormatter.format(date), '4 Rebiülahir 1448');
  });
}
