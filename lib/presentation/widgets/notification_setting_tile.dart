import 'package:flutter/material.dart';
import '../../core/models/notification_setting.dart';
import '../utils/prayer_name_helper.dart';

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
    final isAtTime = setting.minutesBefore == 0;
    final title = PrayerNameHelper.getName(setting.prayerType);
    final subtitle = isAtTime
        ? 'Vaktinde'
        : '${setting.minutesBefore} dakika önce';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ListTile(
        key: Key('setting_${setting.prayerType.name}_${setting.minutesBefore}'),
        leading: CircleAvatar(
          backgroundColor: setting.isActive && hasPermission
              ? Colors.green.shade100
              : Colors.grey.shade200,
          child: Icon(
            setting.isActive && hasPermission
                ? Icons.notifications_active
                : Icons.notifications_off,
            color: setting.isActive && hasPermission
                ? Colors.green.shade700
                : Colors.grey.shade600,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              key: Key(
                'switch_${setting.prayerType.name}_${setting.minutesBefore}',
              ),
              value: setting.isActive && hasPermission,
              onChanged: hasPermission ? (_) => onToggle() : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Sil',
            ),
          ],
        ),
      ),
    );
  }
}
