import 'package:flutter/material.dart';
import '../../../l10n/l10n_extensions.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';
import '../../utils/alarm_labels.dart' show weekdaysLabel;
import '../../utils/reminder_labels.dart';
import '../../utils/time_format_context.dart';
import '../reminders/reminder_row.dart';

/// Bildirim listesindeki tek satır.
///
/// Kendi kartını çizmez; grup içindeki bir [ReminderRow] olarak gelir. Silme,
/// satırı sola kaydırarak yapılır (bkz. `SwipeToDelete`), bu yüzden ayrı bir
/// çöp kutusu düğmesi yoktur.
class NotificationTile extends StatelessWidget {
  final NotificationSetting setting;
  final bool hasPermission;
  final VoidCallback? onToggle;
  final Future<void> Function()? onDelete;
  final VoidCallback? onTap;

  /// Bir sonraki tetiklenme anı. Tek seferlik atlama bu örneğe uygulanır;
  /// `null` ise atlama eylemi çizilmez.
  final DateTime? nextFireAt;

  /// Bu örnek şu an atlanmış mı?
  final bool isSkipped;

  /// Tek seferlik atlama değiştirildiğinde çağrılır.
  final VoidCallback? onSkipToggle;
  final DateTime? now;
  final bool isReordering;

  const NotificationTile({
    super.key,
    required this.setting,
    required this.hasPermission,
    this.nextFireAt,
    this.isSkipped = false,
    this.onSkipToggle,
    this.onToggle,
    this.onDelete,
    this.onTap,
    this.now,
    this.isReordering = false,
  });

  /// Atlanan bildirim de kapalı görünür: kullanıcı için ikisi de "bu sefer
  /// gelmeyecek" demek. Atlanan örnek geçince satır kendiliğinden açılır.
  bool get _isOn => setting.isActive && !_skipping;

  bool get _skipping => isSkipped && nextFireAt != null;

  void _onSwitch(bool value) {
    if (!value) {
      onToggle?.call();
      return;
    }
    // Açılıyor: bekleyen tek seferlik atlama varsa önce o kalkar, yoksa
    // bildirim kalıcı olarak açılır.
    if (_skipping && onSkipToggle != null) {
      onSkipToggle!();
      return;
    }
    onToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fireAt = setting.isActive ? nextFireAt : null;
    final referenceTime = now ?? DateTime.now();
    return ReminderRow(
      icon: setting.isDerived
          ? Icons.hourglass_bottom_rounded
          : PrayerUtils.getPrayerIcon(setting.prayerType),
      time: notificationRuleLabel(setting, l10n),
      timing: fireAt != null
          ? '${reminderDayLabel(context, fireAt, referenceTime)} '
                '${context.formatTime(fireAt)}'
          : null,
      name: notificationTitle(setting, l10n),
      detail: [
        weekdaysLabel(setting.weekdays, l10n),
        if (fireAt != null && !_skipping)
          reminderRemaining(fireAt.difference(referenceTime), l10n),
        if (setting.isDerived) l10n.derivedHint(setting.derivedKind!),
      ].join(' · '),
      status: _skipping
          ? l10n.reminderSkippedOnce
          : !setting.isActive
          ? l10n.reminderOff
          : null,
      onTap: isReordering ? null : onTap,
      dimmed: !_isOn || !hasPermission,
      trailing: isReordering
          ? const SizedBox.shrink()
          : Switch(value: _isOn, onChanged: hasPermission ? _onSwitch : null),
    );
  }
}
