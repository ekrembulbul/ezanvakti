import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/ramadan/domain/ramadan_period.dart';
import '../../../l10n/l10n_extensions.dart';
import 'imsakiye_table.dart';

String imsakiyeDateRange(BuildContext context, RamadanPeriod period) {
  final format = DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  );
  return '${format.format(period.start)} – ${format.format(period.lastDay)}';
}

/// Every row is built and painted, including rows outside the screen viewport.
class ImsakiyeShareTable extends StatelessWidget {
  final Location location;
  final RamadanPeriod period;
  final List<PrayerTime> days;
  const ImsakiyeShareTable({
    super.key,
    required this.location,
    required this.period,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ColoredBox(
      color: tokens.backgroundStops.last,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${context.l10n.imsakiyeTitle} · ${period.hijriYear}',
              style: AppTypography.screenTitle.copyWith(
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              location.displayName,
              style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
            ),
            Text(
              '${imsakiyeDateRange(context, period)} · ${context.l10n.calendarDayCount(period.dayCount)}',
              style: AppTypography.hint.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: 12),
            ImsakiyeTable(days: days),
            const SizedBox(height: 12),
            Text(
              context.l10n.imsakiyeSources,
              style: AppTypography.hint.copyWith(color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
