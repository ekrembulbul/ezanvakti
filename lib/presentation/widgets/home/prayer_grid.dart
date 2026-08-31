import 'package:flutter/material.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../utils/time_format_context.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/prayer_utils.dart';
import '../common/section_label.dart';

/// Günün altı vaktini yatay ızgarada gösterir.
///
/// Her kolonun üstünde kolon genişliğinde 3px'lik bir gösterge barı vardır;
/// aktif vakitte bar, ad ve değer vurgu rengine geçer.
class PrayerGrid extends StatelessWidget {
  final PrayerTime prayerTime;
  final DateTime now;
  final PrayerType? currentPrayer;

  const PrayerGrid({
    super.key,
    required this.prayerTime,
    required this.now,
    this.currentPrayer,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 1, color: tokens.divider),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < PrayerType.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _column(context, PrayerType.values[i])),
              ],
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: tokens.divider),
      ],
    );
  }

  Widget _column(BuildContext context, PrayerType type) {
    final tokens = context.tokens;
    final time = PrayerUtils.getPrayerTime(prayerTime, type);
    final isActive = type == currentPrayer;
    final isPast = time.isBefore(now);

    final valueColor = isActive
        ? tokens.accent
        : isPast
        ? tokens.textValue
        : tokens.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: isActive ? tokens.accent : tokens.mutedTrack,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 9),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            SectionLabel.toTurkishUpperCase(context.l10n.prayerName(type)),
            style: AppTypography.gridPrayerName.copyWith(
              color: isActive ? tokens.accent : tokens.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: 9),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            context.formatTime(time),
            style: AppTypography.gridValue.copyWith(
              color: valueColor,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
              fontVariations: [FontVariation('wght', isActive ? 800 : 700)],
            ),
          ),
        ),
      ],
    );
  }
}
