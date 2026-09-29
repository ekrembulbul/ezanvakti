import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../l10n/l10n_extensions.dart';
import 'calendar_table.dart';

/// Paylaşım görüntüsünün mantıksal genişliği. Renderer 1000 px genişlikte
/// çizer; tablo telefon genişliğinde yerleşip 2.5 kat büyür. Eski ekran
/// yakalamasının (pixelRatio 2.5) okunurluğu korunur.
const double kCalendarShareLogicalWidth = 400;

/// "Eylül 2026": ekranın alt başlığı, ay çubuğu ve paylaşım görüntüsü aynı
/// biçimi kullanır.
String calendarMonthLabel(BuildContext context, DateTime month) =>
    DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(month);

/// Ayın bütün günlerini tembel olmadan çizer; ekran dışındaki satırlar da
/// boyanır (ay paylaşımı). Satırlar ekrandaki tabloyla aynı widget'tır.
class CalendarMonthShareTable extends StatelessWidget {
  final Location location;
  final DateTime month;
  final List<PrayerTime> days;

  const CalendarMonthShareTable({
    super.key,
    required this.location,
    required this.month,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ColoredBox(
      color: tokens.backgroundStops.last,
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: kCalendarShareLogicalWidth,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.calendarTitle,
                  style: AppTypography.screenTitle.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  location.displayName,
                  style: AppTypography.rowTitle.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  calendarMonthLabel(context, month),
                  style: AppTypography.hint.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  height: kCalendarRowHeight,
                  child: CalendarHeaderRow(),
                ),
                // `now` verilmez: paylaşılan çizelgede bugün vurgusu ve
                // soluk geçmiş günler yok.
                for (final day in days)
                  SizedBox(
                    height: kCalendarRowHeight,
                    child: CalendarDayRow(day: day),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
