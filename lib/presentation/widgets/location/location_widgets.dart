import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/models/location.dart';

class LocationChoiceButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const LocationChoiceButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLoading = false,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isHighlighted
              ? LinearGradient(
                  colors: [
                    tokens.accent.withValues(alpha: 0.2),
                    tokens.accent.withValues(alpha: 0.1),
                  ],
                )
              : null,
          color: isHighlighted ? null : tokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted
                ? tokens.accent.withValues(alpha: 0.3)
                : tokens.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? tokens.accent.withValues(alpha: 0.3)
                    : tokens.border,
                borderRadius: BorderRadius.circular(14),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isHighlighted
                            ? tokens.accent
                            : tokens.textSecondary,
                      ),
                    )
                  : Icon(
                      icon,
                      color: isHighlighted
                          ? tokens.accent
                          : tokens.textSecondary,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isHighlighted ? tokens.accent : tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: tokens.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isHighlighted
                  ? tokens.accent.withValues(alpha: 0.5)
                  : tokens.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class LocationErrorCard extends StatelessWidget {
  final String error;

  const LocationErrorCard({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: errorColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: AppTypography.rowSubtitle.copyWith(color: errorColor),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationSelectionConfirm extends StatelessWidget {
  final Location location;

  const LocationSelectionConfirm({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: tokens.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              // Uygulamanin her yerindeki tek bicim: "Kadıköy, İstanbul".
              location.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.rowTitle.copyWith(color: tokens.accent),
            ),
          ),
        ],
      ),
    );
  }
}
