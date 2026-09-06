import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/prayer_utils.dart';
import '../../../l10n/l10n_extensions.dart';

/// Builds every day so the screen and full-month export share the same rows.
class ImsakiyeTable extends StatelessWidget {
  final List<PrayerTime> days;
  final bool compact;

  const ImsakiyeTable({super.key, required this.days, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {0: FlexColumnWidth(1.5)},
      border: TableBorder(
        horizontalInside: BorderSide(color: context.tokens.divider),
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
                emphasized: _isFastingBoundary(type),
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
                  emphasized: _isFastingBoundary(type),
                ),
            ],
          ),
      ],
    );
  }

  bool _isFastingBoundary(PrayerType type) =>
      type == PrayerType.fajr || type == PrayerType.maghrib;

  Widget _cell(
    BuildContext context,
    String text, {
    bool emphasized = false,
    Key? key,
  }) {
    final style = compact
        ? (emphasized
              ? AppTypography.upcomingRemaining
              : AppTypography.rowSubtitle)
        : AppTypography.rowTitle;
    return Container(
      key: key,
      constraints: BoxConstraints(minHeight: compact ? 56 : 64),
      color: emphasized ? context.tokens.secondarySurface : null,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 6, vertical: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: style.copyWith(
            color: emphasized
                ? context.tokens.accent
                : context.tokens.textValue,
          ),
        ),
      ),
    );
  }
}
