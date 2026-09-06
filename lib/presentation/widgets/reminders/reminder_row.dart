import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Tekrar günleri, ana zaman ve ikincil bilgilerden oluşan hatırlatıcı satırı.
class ReminderRow extends StatelessWidget {
  final String days;
  final String? remaining;
  final String primary;
  final IconData? primaryIcon;
  final String? primaryIconTooltip;
  final String? label;
  final String? detail;
  final Widget trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool dimmed;

  const ReminderRow({
    super.key,
    required this.days,
    this.remaining,
    required this.primary,
    this.primaryIcon,
    this.primaryIconTooltip,
    this.label,
    this.detail,
    required this.trailing,
    this.onTap,
    this.onLongPress,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Opacity(
          opacity: dimmed ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        days,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.hint.copyWith(
                          color: tokens.accent,
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation('wght', 700)],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              primary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.reminderPrimary.copyWith(
                                color: tokens.textPrimary,
                              ),
                            ),
                          ),
                          if (primaryIcon != null) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: primaryIconTooltip ?? '',
                              child: Icon(
                                primaryIcon,
                                size: 19,
                                color: tokens.accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (label != null ||
                          detail != null ||
                          remaining != null) ...[
                        const SizedBox(height: 3),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 3,
                          children: [
                            if (label != null)
                              Text(
                                label!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.rowSubtitle.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            if (detail != null)
                              Text(
                                detail!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.rowSubtitle.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            if (remaining != null)
                              Text(
                                remaining!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.rowSubtitle.copyWith(
                                  color: tokens.textSecondary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
