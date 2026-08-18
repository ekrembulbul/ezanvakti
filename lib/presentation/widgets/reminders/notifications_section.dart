import 'package:flutter/material.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../utils/prayer_name_helper.dart';
import '../common/grouped_list.dart';
import '../common/info_banner.dart';
import '../common/section_label.dart';
import '../common/state_widgets.dart';
import '../common/swipe_to_delete.dart';
import '../notifications/notification_tile.dart';
import '../notifications/permission_warning_card.dart';

/// Hatırlatıcılar ekranının "Bildirimler" bölümü.
///
/// Kendi durumunu tutmaz: liste dışarıdan gelir, kullanıcı eylemi callback ile
/// dışarı çıkar. Tek doğruluk kaynağı `AppState` (spec §6.2).
class NotificationsSection extends StatelessWidget {
  final List<NotificationSetting> settings;
  final bool hasPermission;
  final bool exactAlarmAllowed;
  final Future<bool> Function()? onRequestPermission;
  final ValueChanged<bool> onPermissionChanged;
  final VoidCallback onOpenExactAlarmSettings;
  final ValueChanged<NotificationSetting> onToggle;
  final ValueChanged<NotificationSetting> onEdit;
  final Future<void> Function(NotificationSetting) onDelete;

  const NotificationsSection({
    super.key,
    required this.settings,
    required this.hasPermission,
    required this.exactAlarmAllowed,
    this.onRequestPermission,
    required this.onPermissionChanged,
    required this.onOpenExactAlarmSettings,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasPermission)
          PermissionWarningCard(
            onRequestPermission: onRequestPermission,
            onPermissionGranted: onPermissionChanged,
          ),
        if (hasPermission && !exactAlarmAllowed) ...[
          InfoBanner(
            icon: Icons.alarm_off_rounded,
            text: 'Tam zamanlı alarm kapalı. Bildirimler gecikebilir.',
            action: TextButton(
              onPressed: onOpenExactAlarmSettings,
              child: const Text('Aç'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(child: settings.isEmpty ? _empty() : _list(context)),
      ],
    );
  }

  Widget _empty() => const EmptyState(
    icon: Icons.notifications_none_rounded,
    message: 'Henüz bildirim yok',
    subtitle: 'Namaz vakitlerinde hatırlatma almak için\nbildirim ekleyin.',
  );

  Widget _list(BuildContext context) {
    final tokens = context.tokens;
    final sorted = _sorted();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(
          'Her vakit için tam vaktinde veya X dakika önce hatırlatma '
          'alabilirsiniz.',
          style: AppTypography.hint.copyWith(
            color: tokens.textTertiary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        SectionLabel('${sorted.length} hatırlatma'),
        const SizedBox(height: 10),
        GroupedList(
          children: [
            for (final setting in sorted)
              SwipeToDelete(
                itemKey: ValueKey(
                  '${setting.prayerType.name}-${setting.minutesBefore}',
                ),
                onDelete: () => onDelete(setting),
                child: NotificationTile(
                  setting: setting,
                  hasPermission: hasPermission,
                  onToggle: () => onToggle(setting),
                  onTap: () => onEdit(setting),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Silmek için satırı sola kaydırın.',
          style: AppTypography.hint.copyWith(color: tokens.textTertiary),
        ),
      ],
    );
  }

  List<NotificationSetting> _sorted() {
    final sorted = [...settings];
    sorted.sort((a, b) {
      final orderCompare = PrayerNameHelper.getPrayerOrder(
        a.prayerType,
      ).compareTo(PrayerNameHelper.getPrayerOrder(b.prayerType));
      if (orderCompare != 0) return orderCompare;
      return a.minutesBefore.compareTo(b.minutesBefore);
    });
    return sorted;
  }
}
