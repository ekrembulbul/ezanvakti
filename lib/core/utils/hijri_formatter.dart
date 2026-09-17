import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../models/hijri_date.dart';

/// Diyanet Hicri tarihini biçimlendirir.
///
/// Ay adları çeviriden gelir; [l10n] verilmezse kaynak dil (Türkçe)
/// kullanılır (widget snapshot'ı çeviriye erişemez). Tarih hesaplanmaz:
/// değer, sunucudan gelen vakit satırıyla birlikte saklanan Hicri'dir.
class HijriFormatter {
  const HijriFormatter._();

  static final AppLocalizations _sourceLanguage = lookupAppLocalizations(
    const Locale('tr'),
  );

  static String formatHijri(HijriDate hijri, [AppLocalizations? l10n]) {
    final month =
        _monthName(hijri.month, l10n ?? _sourceLanguage) ?? '${hijri.month}';
    return '${hijri.day} $month ${hijri.year}';
  }

  /// Hicri ay numarası (1–12) → çeviri.
  static String? _monthName(int month, AppLocalizations l10n) =>
      switch (month) {
        1 => l10n.hijriMuharram,
        2 => l10n.hijriSafar,
        3 => l10n.hijriRabiAwwal,
        4 => l10n.hijriRabiThani,
        5 => l10n.hijriJumadaAwwal,
        6 => l10n.hijriJumadaThani,
        7 => l10n.hijriRajab,
        8 => l10n.hijriShaban,
        9 => l10n.hijriRamadan,
        10 => l10n.hijriShawwal,
        11 => l10n.hijriDhulQadah,
        12 => l10n.hijriDhulHijjah,
        _ => null,
      };
}
