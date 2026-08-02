import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../common/section_label.dart';

/// Sıradaki bildirim ve alarmı gösteren grup.
///
/// Bu turda yalnızca yerleşim ve boş durum var; veri bağlama (sıradaki
/// bildirim/alarm hesabı) ayrı bir turda yapılacak.
class UpcomingCard extends StatelessWidget {
  final VoidCallback onSeeAll;

  const UpcomingCard({super.key, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(
          'Sıradaki',
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSeeAll,
            child: Text(
              'Tümü',
              style: AppTypography.hint.copyWith(
                color: tokens.accent,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.border),
          ),
          child: Text(
            'Yaklaşan bildirim veya alarm yok',
            style: AppTypography.rowSubtitle.copyWith(
              color: tokens.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
