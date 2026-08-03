import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
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
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isHighlighted
              ? LinearGradient(
                  colors: [
                    AppTheme.gold.withValues(alpha: 0.2),
                    AppTheme.gold.withValues(alpha: 0.1),
                  ],
                )
              : null,
          color: isHighlighted ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted
                ? AppTheme.gold.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? AppTheme.gold.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isHighlighted ? AppTheme.gold : Colors.white70,
                      ),
                    )
                  : Icon(
                      icon,
                      color: isHighlighted ? AppTheme.gold : Colors.white70,
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
                      color: isHighlighted ? AppTheme.gold : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isHighlighted
                  ? AppTheme.gold.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.3),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 13),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.gold,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${location.province} / ${location.district}',
              style: const TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
