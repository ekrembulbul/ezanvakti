import 'package:hijri/hijri_calendar.dart';

import '../../l10n/app_localizations.dart';

/// Hicri tarihi biçimlendirir.
///
/// Ay adları çeviriden gelir; [l10n] verilmezse paketin İngilizce adı
/// kullanılır (widget snapshot'ı gibi çeviriye erişemeyen çağrılar için).
class HijriFormatter {
  const HijriFormatter._();

  static String format(DateTime date, [AppLocalizations? l10n]) {
    final hijri = HijriCalendar.fromDate(date);
    final month = l10n == null
        ? hijri.longMonthName
        : _monthName(hijri.hMonth, l10n) ?? hijri.longMonthName;
    return '${hijri.hDay} $month ${hijri.hYear}';
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
