import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: AppTheme.glassDecoration(opacity: 0.08, borderRadius: 16),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.gold, size: 28),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionsRow extends StatelessWidget {
  final VoidCallback? onCalendarTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSettingsTap;

  const QuickActionsRow({
    super.key,
    this.onCalendarTap,
    this.onNotificationsTap,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: QuickActionCard(
            icon: Icons.calendar_month_rounded,
            label: 'Takvim',
            onTap: onCalendarTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: QuickActionCard(
            icon: Icons.notifications_active_rounded,
            label: 'Bildirimler',
            onTap: onNotificationsTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: QuickActionCard(
            icon: Icons.tune_rounded,
            label: 'Ayarlar',
            onTap: onSettingsTap,
          ),
        ),
      ],
    );
  }
}
