import 'package:flutter/material.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';
import '../common/grouped_list.dart';

/// Bildirim listesindeki tek satır.
///
/// Kendi kartını çizmez; grup içindeki bir [GroupedRow] olarak gelir. Silme,
/// satırı sola kaydırarak yapılır (bkz. `SwipeToDelete`), bu yüzden ayrı bir
/// çöp kutusu düğmesi yoktur.
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

  String get _offsetText => setting.minutesBefore == 0
      ? 'Tam vaktinde'
      : '${setting.minutesBefore} dk önce';

  @override
  Widget build(BuildContext context) {
    return GroupedRow(
      icon: PrayerUtils.getPrayerIcon(setting.prayerType),
      title: Text(PrayerUtils.getPrayerName(setting.prayerType)),
      subtitle: Text(_offsetText),
      onTap: onTap,
      dimmed: !setting.isActive || !hasPermission,
      trailing: Switch(
        value: setting.isActive,
        onChanged: hasPermission ? (_) => onToggle?.call() : null,
      ),
    );
  }
}
