import '../../l10n/app_localizations.dart';

const int _minutesPerHour = 60;
const int _minutesPerDay = 24 * _minutesPerHour;

/// Kullanıcıya gösterilen süreyi gün, saat ve dakika birimleriyle yazar.
///
/// Sıfır değer `0 dk` olarak gösterilir. Negatif değer geçersiz girdidir;
/// kalan süreler için [formatCompactDuration] kullanılmalıdır.
String formatCompactMinutes(int totalMinutes, AppLocalizations l10n) {
  if (totalMinutes < 0) {
    throw ArgumentError.value(
      totalMinutes,
      'totalMinutes',
      'cannot be negative',
    );
  }

  final days = totalMinutes ~/ _minutesPerDay;
  final hours = totalMinutes.remainder(_minutesPerDay) ~/ _minutesPerHour;
  final minutes = totalMinutes.remainder(_minutesPerHour);
  final parts = <String>[
    if (days > 0) l10n.durationDaysShort(days),
    if (hours > 0) l10n.durationHoursShort(hours),
    if (minutes > 0 || totalMinutes == 0) l10n.minutesShort(minutes),
  ];
  return parts.join(' ');
}

/// Sayaç süresini tam dakikaya indirger; geçmiş ve bir dakikadan kısa değerler
/// aynı kısa ifadeyi kullanır.
String formatCompactDuration(Duration duration, AppLocalizations l10n) {
  if (duration.inMinutes < 1) return l10n.countdownLessThanMinute;
  return formatCompactMinutes(duration.inMinutes, l10n);
}
