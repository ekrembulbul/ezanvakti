import 'package:flutter/material.dart';
import '../../core/models/notification_setting.dart';
import '../utils/prayer_name_helper.dart';

class NotificationSettingTile extends StatelessWidget {
  final NotificationSetting setting;
  final bool hasPermission;
  final Future<void> Function(NotificationSetting) onToggled;
  final Future<void> Function()? onDelete;

  const NotificationSettingTile({
    super.key,
    required this.setting,
    required this.hasPermission,
    required this.onToggled,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAtTime = setting.minutesBefore == 0;
    final label = isAtTime
        ? '${PrayerNameHelper.getName(setting.prayerType)} • Vaktinde'
        : '${PrayerNameHelper.getName(setting.prayerType)} • ${setting.minutesBefore} dk önce';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        key: Key('setting_${setting.prayerType.name}_${setting.minutesBefore}'),
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              key: Key(
                'switch_${setting.prayerType.name}_${setting.minutesBefore}',
              ),
              value: setting.isActive && hasPermission,
              onChanged: hasPermission
                  ? (value) async {
                      await onToggled(setting.copyWith(isActive: value));
                    }
                  : null,
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Sil',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
