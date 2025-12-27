import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/location.dart';

class LocationTile extends StatelessWidget {
  final Location location;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const LocationTile({
    super.key,
    required this.location,
    required this.isActive,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [
                    AppTheme.gold.withOpacity(0.2),
                    AppTheme.gold.withOpacity(0.05),
                  ],
                )
              : null,
          color: isActive ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppTheme.gold.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            _LocationIcon(location: location, isActive: isActive),
            const SizedBox(width: 14),
            Expanded(
              child: _LocationInfo(location: location, isActive: isActive),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationIcon extends StatelessWidget {
  final Location location;
  final bool isActive;

  const _LocationIcon({required this.location, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.gold.withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        location.type == LocationType.gps
            ? Icons.my_location_rounded
            : Icons.location_on_rounded,
        color: isActive ? AppTheme.gold : Colors.white70,
        size: 24,
      ),
    );
  }
}

class _LocationInfo extends StatelessWidget {
  final Location location;
  final bool isActive;

  const _LocationInfo({required this.location, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                location.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? AppTheme.gold : Colors.white,
                ),
              ),
            ),
            if (isActive) const _ActiveBadge(),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${location.province} / ${location.district}',
          style: TextStyle(
            fontSize: 13,
            color: isActive
                ? AppTheme.gold.withOpacity(0.7)
                : Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        _LocationTypeBadge(location: location, isActive: isActive),
      ],
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.gold,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'AKTİF',
        style: TextStyle(
          color: AppTheme.primaryDark,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LocationTypeBadge extends StatelessWidget {
  final Location location;
  final bool isActive;

  const _LocationTypeBadge({required this.location, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.gold.withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            location.type == LocationType.gps
                ? Icons.gps_fixed_rounded
                : Icons.edit_location_rounded,
            size: 12,
            color: isActive ? AppTheme.gold : Colors.white.withOpacity(0.5),
          ),
          const SizedBox(width: 4),
          Text(
            location.type.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isActive ? AppTheme.gold : Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

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
                    AppTheme.gold.withOpacity(0.2),
                    AppTheme.gold.withOpacity(0.1),
                  ],
                )
              : null,
          color: isHighlighted ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted
                ? AppTheme.gold.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isHighlighted
                    ? AppTheme.gold.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
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
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isHighlighted
                  ? AppTheme.gold.withOpacity(0.5)
                  : Colors.white.withOpacity(0.3),
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
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
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
        color: AppTheme.gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
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
