import 'dart:ui';

import 'app_localizations.dart';

/// Cihaz dilini uygulamanın desteklediği bir dile çözer.
///
/// Flutter'ın varsayılanı eşleşme bulamazsa `supportedLocales.first`e düşer;
/// o liste alfabetik olduğu için Arapça'ya düşüyordu. Desteklenmeyen bir
/// dilde en geniş anlaşılan dile — İngilizce'ye — düşmek doğru davranış.
class LocaleResolver {
  const LocaleResolver._();

  /// Desteklenmeyen dillerde kullanılan dil.
  static const Locale fallback = Locale('en');

  static Locale resolve(Locale? deviceLocale) {
    if (deviceLocale == null) return fallback;
    for (final supported in AppLocalizations.supportedLocales) {
      // Ülke kodu göz ardı edilir: tr_CY de Türkçe'dir.
      if (supported.languageCode == deviceLocale.languageCode) return supported;
    }
    return fallback;
  }
}
