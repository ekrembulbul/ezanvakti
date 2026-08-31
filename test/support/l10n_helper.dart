import 'dart:ui';

import 'package:ezanvakti/l10n/app_localizations.dart';

/// Testlerde kaynak dildeki (Türkçe) çeviri örneği.
///
/// Etiket yardımcıları artık `AppLocalizations` istiyor; testler cihaz
/// diline bağlı kalmasın diye dil burada sabitleniyor.
Future<AppLocalizations> loadTestL10n([String languageCode = 'tr']) =>
    AppLocalizations.delegate.load(Locale(languageCode));
