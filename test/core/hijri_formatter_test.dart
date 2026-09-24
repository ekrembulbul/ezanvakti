import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/core/utils/hijri_formatter.dart';
import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hijri = HijriDate(day: 4, month: 4, year: 1448);

  test('ay adı verilen çeviriden gelir', () {
    expect(
      HijriFormatter.formatHijri(
        hijri,
        lookupAppLocalizations(const Locale('tr')),
      ),
      '4 Rebiülahir 1448',
    );
    expect(
      HijriFormatter.formatHijri(
        hijri,
        lookupAppLocalizations(const Locale('en')),
      ),
      '4 Rabi al-Thani 1448',
    );
  });

  test('çeviri verilmezse kaynak dil Türkçe kullanılır, İngilizce değil', () {
    expect(HijriFormatter.formatHijri(hijri), '4 Rebiülahir 1448');
  });
}
