import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Yönetim listelerinde çalma saati, ad ve kural için ortak bilgi hiyerarşisi.
/// İçerik yüksekliği metin ölçeğiyle büyür; durum bilgisi kırpılmaz.
class ReminderRow extends StatelessWidget {
  final IconData icon;
  final String? time;
  final String? timing;
  final String? name;
  final String detail;
  final String? status;
  final Widget trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool dimmed;

  const ReminderRow({
    super.key,
    required this.icon,
    this.time,
    this.timing,
    this.name,
    required this.detail,
    this.status,
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
                Icon(icon, size: 20, color: tokens.textSecondary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (time != null)
                        Text(
                          time!,
                          style: AppTypography.reminderTime.copyWith(
                            color: tokens.textPrimary,
                          ),
                        ),
                      if (timing != null)
                        Text(
                          timing!,
                          style: AppTypography.hint.copyWith(
                            color: tokens.accent,
                          ),
                        ),
                      if (name != null && name!.isNotEmpty) ...[
                        if (time != null) const SizedBox(height: 4),
                        Text(
                          name!,
                          style: AppTypography.rowTitle.copyWith(
                            color: tokens.textPrimary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: AppTypography.rowSubtitle.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      if (status != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          status!,
                          style: AppTypography.hint.copyWith(
                            color: tokens.textSecondary,
                          ),
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
