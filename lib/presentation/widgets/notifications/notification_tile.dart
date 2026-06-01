import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';

class NotificationTile extends StatelessWidget {
  final NotificationSetting setting;
  final bool hasPermission;
  final VoidCallback? onToggle;
  final Future<void> Function()? onDelete;
  final VoidCallback? onTap;

  const NotificationTile({
    super.key,
    required this.setting,
    required this.hasPermission,
    this.onToggle,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = PrayerUtils.getPrayerName(setting.prayerType);
    final icon = PrayerUtils.getPrayerIcon(setting.prayerType);
    final offsetText = setting.minutesBefore == 0
        ? 'Tam vaktinde'
        : '${setting.minutesBefore} dk önce';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: setting.isActive ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: setting.isActive
                ? AppTheme.gold.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: setting.isActive
                    ? AppTheme.gold.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: setting.isActive ? AppTheme.gold : Colors.white54,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: setting.isActive ? Colors.white : Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: setting.isActive
                          ? AppTheme.gold.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      offsetText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: setting.isActive
                            ? AppTheme.gold
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: setting.isActive,
              onChanged: hasPermission ? (_) => onToggle?.call() : null,
              activeThumbColor: AppTheme.gold,
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white12,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
