import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';

class NotificationSettingTile extends StatelessWidget {
  final NotificationSetting setting;
  final bool hasPermission;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const NotificationSettingTile({
    super.key,
    required this.setting,
    required this.hasPermission,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = setting.isActive && hasPermission;
    final title = PrayerUtils.getPrayerName(setting.prayerType);
    final icon = PrayerUtils.getPrayerIcon(setting.prayerType);
    final subtitle = setting.minutesBefore == 0
        ? 'Tam vaktinde'
        : '${setting.minutesBefore} dk önce';

    return Container(
      key: Key('setting_${setting.prayerType.name}_${setting.minutesBefore}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isActive ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppTheme.gold.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.gold.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isActive ? AppTheme.gold : Colors.white54,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.white54,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.gold.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? AppTheme.gold
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: Key(
              'switch_${setting.prayerType.name}_${setting.minutesBefore}',
            ),
            value: setting.isActive,
            onChanged: hasPermission ? (_) => onToggle() : null,
            activeColor: AppTheme.gold,
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
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
    );
  }
}
