import '../../../core/models/mission_session.dart';
import 'snooze_notice.dart';
import 'package:flutter/material.dart';

import '../../../core/models/alarm.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../utils/alarm_labels.dart';
import '../common/grouped_list.dart';
import '../common/info_banner.dart';
import '../common/section_label.dart';
import '../common/state_widgets.dart';
import '../common/swipe_to_delete.dart';

/// Hatırlatıcılar ekranının "Alarmlar" bölümü.
///
/// [NotificationsSection] ile aynı sözleşme: durum tutmaz, veri dışarıdan
/// gelir.
class AlarmsSection extends StatelessWidget {
  final List<Alarm> alarms;

  /// iOS 26 altında sesli alarm yok; kayıt tutulur ama çalmaz.
  final bool isSupported;
  final bool isPermissionGranted;
  final VoidCallback onRequestPermission;
  final void Function(Alarm alarm, bool isActive) onToggle;

  /// Bekleyen görev oturumu; ertelenmiş alarmı ve görev borcunu buradan
  /// okuyoruz.
  final MissionSession? missionSession;

  /// Ertelenmiş görevli alarm kapatılmak istendiğinde çağrılır.
  final void Function(Alarm alarm)? onDisableBlocked;
  final ValueChanged<Alarm> onEdit;
  final Future<void> Function(Alarm) onDelete;

  const AlarmsSection({
    super.key,
    required this.alarms,
    required this.isSupported,
    required this.isPermissionGranted,
    required this.onRequestPermission,
    required this.onToggle,
    this.missionSession,
    this.onDisableBlocked,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?_permissionBanner(),
        Expanded(child: alarms.isEmpty ? _empty() : _list(context)),
        _footer(context),
      ],
    );
  }

  Widget _empty() => const EmptyState(
    icon: Icons.alarm_off_rounded,
    message: 'Henüz alarm yok',
    subtitle: 'Sabit saatli veya vakte göre alarm ekle',
  );

  Widget _alarmRow(BuildContext context, Alarm alarm) {
    final snoozedUntil = SnoozeNotice.snoozedUntilFor(missionSession, alarm);
    final canDisable = SnoozeNotice.canDisable(missionSession, alarm);

    return SwipeToDelete(
      itemKey: ValueKey(alarm.id),
      confirmText: '${alarmTimeLabel(alarm)} alarmını silmek istiyor musunuz?',
      onDelete: () => onDelete(alarm),
      child: GroupedRow(
        icon: Icons.alarm_rounded,
        title: Text(alarmTimeLabel(alarm)),
        subtitle: Text(
          snoozedUntil != null
              ? SnoozeNotice.label(snoozedUntil)
              : alarmSubtitle(alarm),
        ),
        onTap: () => onEdit(alarm),
        dimmed: !alarm.isActive,
        trailing: Switch(
          value: alarm.isActive,
          onChanged: (value) {
            // Ertelenmis gorevli alarm kapatilamaz; gorev borcu duruyor.
            if (!value && !canDisable) {
              onDisableBlocked?.call(alarm);
              return;
            }
            onToggle(alarm, value);
          },
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        SectionLabel('${alarms.length} alarm'),
        const SizedBox(height: 10),
        GroupedList(
          children: [
            for (final alarm in alarms)
              _alarmRow(context, alarm),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            'Silmek için satırı sola kaydırın. Alarmlar vakit güncellendiğinde '
            'otomatik yeniden planlanır.',
            style: AppTypography.hint.copyWith(
              color: tokens.textTertiary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(Icons.bedtime_rounded, size: 16, color: tokens.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Alarmlar vakit verisi güncellendikçe yeniden planlanır.',
              style: AppTypography.hint.copyWith(color: tokens.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS < 26'da destek yok; izin verilmemişse uyarı + "İzin ver". Her şey
  /// yolundaysa null döner.
  Widget? _permissionBanner() {
    if (!isSupported) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: InfoBanner(
          icon: Icons.info_outline_rounded,
          text:
              'Sesli alarm bu cihazda desteklenmiyor (iOS 26 ve üzeri gerekir). '
              'Alarmlar kaydedilir ancak çalmaz.',
        ),
      );
    }
    if (!isPermissionGranted) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: InfoBanner(
          icon: Icons.notifications_off_rounded,
          text: 'Alarmların çalması için izin gerekiyor.',
          action: TextButton(
            onPressed: onRequestPermission,
            child: const Text('İzin ver'),
          ),
        ),
      );
    }
    return null;
  }
}
