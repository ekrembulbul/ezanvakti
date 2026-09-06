import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Etiket, zaman özeti ve diğer bilgilerden oluşan üç satır.
/// Metin ölçeği yüksekliği belirler; uzun metinler görsel olarak kısaltılır.
class ReminderRow extends StatelessWidget {
  final IconData icon;
  final String time;
  final String? timing;
  final String name;
  final String detail;
  final String? status;
  final Widget trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool dimmed;

  const ReminderRow({
    super.key,
    required this.icon,
    required this.time,
    this.timing,
    required this.name,
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
    final schedule = [time, ?timing].join(' · ');
    final metadata = [?status, detail].join(' · ');
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
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.rowTitle.copyWith(
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        schedule,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.rowSubtitle.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        metadata,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.hint.copyWith(
                          color: tokens.textTertiary,
                        ),
                      ),
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
