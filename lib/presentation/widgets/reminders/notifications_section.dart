import '../../../core/models/skipped_occurrence.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../features/notifications/domain/skip_rules.dart';
import '../../services/upcoming_resolver.dart';
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
  /// Bildirim anahtarı → bir sonraki tetiklenme anı.
  final Map<String, DateTime> nextFireByNotification;

  final Set<SkippedOccurrence> skips;

  /// Tek seferlik atlama değiştirildiğinde çağrılır.
  final void Function(SkippedOccurrence occurrence, bool skipped)?
  onSkipChanged;

  final List<NotificationSetting> settings;
  final bool hasPermission;
  final bool exactAlarmAllowed;
  final Future<bool> Function()? onRequestPermission;
  final ValueChanged<bool> onPermissionChanged;
  final VoidCallback onOpenExactAlarmSettings;
  final ValueChanged<NotificationSetting> onToggle;
  final ValueChanged<NotificationSetting> onEdit;
  final Future<void> Function(NotificationSetting) onDelete;

  /// "Cuma namazı" hazır şablonunu ekler; şablon zaten varsa düğme çıkmaz.
  final VoidCallback? onAddFridayReminder;

  const NotificationsSection({
    this.nextFireByNotification = const {},
    this.skips = const {},
    this.onSkipChanged,
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
    this.onAddFridayReminder,
  });

  /// Cuma öğle vaktine kurulmuş, yalnızca Cuma çalan bir satır var mı.
  bool get _hasFridayReminder => settings.any(
    (setting) =>
        setting.prayerType == PrayerType.dhuhr && setting.weekdays.contains(5),
  );

  SkippedOccurrence _occurrence(NotificationSetting setting) =>
      SkippedOccurrence(
        kind: SkipKind.notification,
        reference: notificationKey(setting),
        fireAt: nextFireByNotification[notificationKey(setting)]!,
      );

  bool _isSkipped(NotificationSetting setting) {
    final fireAt = nextFireByNotification[notificationKey(setting)];
    if (fireAt == null) return false;
    return isSkipped(
      skips,
      kind: SkipKind.notification,
      reference: notificationKey(setting),
      fireAt: fireAt,
    );
  }

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
            text: context.l10n.exactAlarmOff,
            action: TextButton(
              onPressed: onOpenExactAlarmSettings,
              child: Text(context.l10n.actionOpen),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: settings.isEmpty ? _empty(context) : _list(context),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) => EmptyState(
    icon: Icons.notifications_none_rounded,
    message: context.l10n.remindersNoNotifications,
    subtitle: context.l10n.remindersNoNotificationsHint,
  );

  Widget _list(BuildContext context) {
    final tokens = context.tokens;
    final sorted = _sorted();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(
          context.l10n.remindersIntro,
          style: AppTypography.hint.copyWith(
            color: tokens.textTertiary,
            height: 1.5,
          ),
        ),
        if (onAddFridayReminder != null && !_hasFridayReminder) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: onAddFridayReminder,
              icon: const Icon(Icons.mosque_rounded, size: 18),
              label: Text(context.l10n.remindersAddFriday),
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.accent,
                side: BorderSide(color: tokens.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SectionLabel(context.l10n.remindersCount(sorted.length)),
        const SizedBox(height: 10),
        GroupedList(
          children: [
            for (final setting in sorted)
              SwipeToDelete(
                itemKey: ValueKey(notificationKey(setting)),
                onDelete: () => onDelete(setting),
                child: NotificationTile(
                  setting: setting,
                  hasPermission: hasPermission,
                  nextFireAt: nextFireByNotification[notificationKey(setting)],
                  isSkipped: _isSkipped(setting),
                  onSkipToggle: onSkipChanged == null
                      ? null
                      : () => onSkipChanged!(
                          _occurrence(setting),
                          !_isSkipped(setting),
                        ),
                  onToggle: () => onToggle(setting),
                  onTap: () => onEdit(setting),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.remindersSwipeToDelete,
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
