import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/location.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/prayer_utils.dart';
import '../../../features/ramadan/domain/ramadan_period.dart';
import '../../../l10n/l10n_extensions.dart';

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
    final locale = Localizations.localeOf(context).toLanguageTag();
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
            Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {0: FlexColumnWidth(1.5)},
              border: TableBorder(
                horizontalInside: BorderSide(color: tokens.divider),
              ),
              children: [
                TableRow(
                  children: [
                    const SizedBox(),
                    for (final type in PrayerType.values)
                      _cell(
                        context,
                        type == PrayerType.maghrib
                            ? context.l10n.imsakiyeIftar
                            : context.l10n.prayerName(type),
                        emphasized:
                            type == PrayerType.fajr ||
                            type == PrayerType.maghrib,
                      ),
                  ],
                ),
                for (var i = 0; i < days.length; i++)
                  TableRow(
                    children: [
                      _cell(
                        context,
                        '${i + 1}. ${DateFormat.MMMd(locale).format(days[i].date)}',
                        key: ValueKey('imsakiye-day-${i + 1}'),
                      ),
                      for (final type in PrayerType.values)
                        _cell(
                          context,
                          DateFormat(
                            'HH:mm',
                          ).format(PrayerUtils.getPrayerTime(days[i], type)),
                          emphasized:
                              type == PrayerType.fajr ||
                              type == PrayerType.maghrib,
                        ),
                    ],
                  ),
              ],
            ),
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

  Widget _cell(
    BuildContext context,
    String text, {
    bool emphasized = false,
    Key? key,
  }) => Container(
    key: key,
    constraints: const BoxConstraints(minHeight: 64),
    color: emphasized ? context.tokens.secondarySurface : null,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AppTypography.rowTitle.copyWith(
        color: emphasized ? context.tokens.accent : context.tokens.textValue,
        fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
  );
}
