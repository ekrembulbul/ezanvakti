import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../l10n/l10n_extensions.dart';

/// Sessiz vaktin bir tarafının süresini değiştiren kart: üstte etiket
/// ("Vakitten önce"), altta eksi · değer · artı.
///
/// 5'er dakikalık adımlar; 0–180 dk arası. Bir namaz çevresi için üç saat
/// fazlasıyla yeterli, ötesi kazara tüm günü susturmak olurdu.
class QuietMinutesStepper extends StatelessWidget {
  static const int step = 5;
  static const int maxMinutes = 180;

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const QuietMinutesStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: value >= step ? () => onChanged(value - step) : null,
                icon: const Icon(Icons.remove_rounded, size: 20),
                color: tokens.accent,
                disabledColor: tokens.textTertiary,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatCompactMinutes(value, context.l10n),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: AppTypography.rowTitle.copyWith(
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: value <= maxMinutes - step
                    ? () => onChanged(value + step)
                    : null,
                icon: const Icon(Icons.add_rounded, size: 20),
                color: tokens.accent,
                disabledColor: tokens.textTertiary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
