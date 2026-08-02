import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/hijri_formatter.dart';
import '../../../core/utils/prayer_utils.dart';
import '../common/section_label.dart';

/// Yarının altı vakti ve takvime kısayol.
class TomorrowStrip extends StatelessWidget {
  final PrayerTime tomorrow;
  final VoidCallback onCalendarTap;

  const TomorrowStrip({
    super.key,
    required this.tomorrow,
    required this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final weekday = DateFormat('EEEE', 'tr_TR').format(tomorrow.date);
    final hijri = HijriFormatter.format(tomorrow.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(
          'Yarın',
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCalendarTap,
            child: Text(
              'Takvim',
              style: AppTypography.hint.copyWith(
                color: tokens.accent,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$weekday · $hijri',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.hint.copyWith(color: tokens.textTertiary),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: tokens.secondarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final type in PrayerType.values)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DateFormat(
                        'HH:mm',
                      ).format(PrayerUtils.getPrayerTime(tomorrow, type)),
                      style: AppTypography.tomorrowValue.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
