import '../../../core/models/skipped_occurrence.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../utils/time_format_context.dart';
import '../../../features/notifications/domain/skip_rules.dart';
import '../../../core/models/mission_session.dart';
import 'snooze_notice.dart';
import 'package:flutter/material.dart';

import '../../../core/models/alarm.dart';
import '../../../core/models/alarm_mission.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../utils/alarm_labels.dart';
import '../../utils/reminder_labels.dart';
import 'reminder_list.dart';
import 'reminder_row.dart';
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
  final List<MissionSession> missionSessions;

  /// Ertelenmiş görevli alarm kapatılmak istendiğinde çağrılır.
  final void Function(Alarm alarm)? onDisableBlocked;

  /// Alarm id'si → bir sonraki çalma anı. Tek seferlik atlama bu örneğe
  /// uygulanır; atlama uygulanmamış hâliyle hesaplanır.
  final Map<String, DateTime> nextFireByAlarm;

  final Set<SkippedOccurrence> skips;

  /// Son planlamada kurulamayan alarmlar (alarmId → mesaj); satırda uyarı
  /// olarak gösterilir.
  final Map<String, String> scheduleFailures;

  /// Tek seferlik atlama değiştirildiğinde çağrılır.
  final void Function(SkippedOccurrence occurrence, bool skipped)?
  onSkipChanged;
  final ValueChanged<Alarm> onEdit;
  final Future<void> Function(Alarm) onDelete;

  /// Uzun basma menüsünden "Kopyala"; null ise menü yalnızca silme sunar.
  final ValueChanged<Alarm>? onDuplicate;
  final DateTime? now;
  final bool isReordering;
  final ReorderCallback? onReorder;

  const AlarmsSection({
    super.key,
    required this.alarms,
    required this.isSupported,
    required this.isPermissionGranted,
    required this.onRequestPermission,
    required this.onToggle,
    this.missionSessions = const [],
    this.onDisableBlocked,
    this.nextFireByAlarm = const {},
    this.skips = const {},
    this.scheduleFailures = const {},
    this.onSkipChanged,
    required this.onEdit,
    required this.onDelete,
    this.onDuplicate,
    this.now,
    this.isReordering = false,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?_permissionBanner(context),
        Expanded(child: alarms.isEmpty ? _empty(context) : _list(context)),
        _footer(context),
      ],
    );
  }

  Widget _empty(BuildContext context) => EmptyState(
    icon: Icons.alarm_off_rounded,
    message: context.l10n.remindersNoAlarms,
    subtitle: context.l10n.remindersNoAlarmsHint,
  );

  /// Satırın alt metni.
  ///
  /// Tek seferlik atlama artık ayrı bir eylem değil: anahtar kapatılınca
  /// altta çıkan çubuktan seçiliyor. Burada yalnızca **hangi durumda**
  /// olduğu yazıyor.
  String? _status(
    Alarm alarm,
    DateTime? snoozedUntil,
    bool skipped,
    AppLocalizations l10n,
  ) {
    if (scheduleFailures.containsKey(alarm.id)) {
      return !alarm.isActive || scheduleFailures[alarm.id] == 'cancel_failed'
          ? l10n.alarmCancellationPending
          : l10n.reminderScheduleFailed;
    }
    if (snoozedUntil != null) return SnoozeNotice.label(snoozedUntil, l10n);
    if (skipped) return l10n.reminderSkippedOnce;
    if (!alarm.isActive) return l10n.reminderOff;
    return null;
  }

  Widget _alarmRow(BuildContext context, Alarm alarm) {
    final missionSession = MissionSession.pendingForAlarm(
      missionSessions,
      alarm.id,
    );
    final snoozedUntil = SnoozeNotice.snoozedUntilFor(missionSession, alarm);
    final canDisable = SnoozeNotice.canDisable(missionSession, alarm);

    final fireAt = nextFireByAlarm[alarm.id];
    final skipped =
        fireAt != null &&
        isSkipped(
          skips,
          kind: SkipKind.alarm,
          reference: alarm.id,
          fireAt: fireAt,
        );

    // Atlanan alarm da kapalı görünür: kullanıcı için ikisi de "bu sefer
    // çalmayacak" demek. Atlanan örnek geçince satır kendiliğinden açılır.
    final isOn = alarm.isActive && !skipped;

    final displayTime = alarm.isActive ? snoozedUntil ?? fireAt : null;
    final referenceTime = now ?? DateTime.now();
    final status =
        _status(alarm, snoozedUntil, skipped, context.l10n) ??
        (alarm.isActive &&
                displayTime == null &&
                alarm.kind == AlarmKind.anchored
            ? context.l10n.reminderTimeUnavailable
            : null);
    final label = alarm.label.trim();
    final detail = <String>[
      ?status,
      if (displayTime != null &&
          snoozedUntil == null &&
          !scheduleFailures.containsKey(alarm.id))
        alarm.kind == AlarmKind.fixed
            ? reminderDayLabel(context, displayTime, referenceTime)
            : '${reminderDayLabel(context, displayTime, referenceTime)} '
                  '${context.formatTime(displayTime)}',
    ];
    final row = ReminderRow(
      days: weekdaysLabel(alarm.weekdays, context.l10n),
      remaining: displayTime != null && (status == null || snoozedUntil != null)
          ? reminderRemaining(
              displayTime.difference(referenceTime),
              context.l10n,
            )
          : null,
      primary: alarmTimeLabel(
        alarm,
        l10n: context.l10n,
        formatHourMinute: context.formatHourMinute,
      ),
      primaryIcon: missionIcon(alarm.mission),
      primaryIconTooltip: alarm.mission.requiresGate
          ? missionLabel(alarm.mission, context.l10n)
          : null,
      label: label.isNotEmpty
          ? label
          : detail.isEmpty
          ? context.l10n.alarmDefaultLabel
          : null,
      detail: detail.isEmpty ? null : detail.join(' · '),
      onTap: isReordering ? null : () => onEdit(alarm),
      onLongPress: isReordering ? null : () => _showRowMenu(context, alarm),
      dimmed: !isOn,
      trailing: isReordering
          ? const SizedBox.shrink()
          : Switch(
              value: isOn,
              onChanged: (value) {
                if (!value) {
                  // Ertelenmis gorevli alarm kapatilamaz; gorev borcu duruyor.
                  if (!canDisable) {
                    onDisableBlocked?.call(alarm);
                    return;
                  }
                  onToggle(alarm, false);
                  return;
                }
                // Aciliyor: bekleyen tek seferlik atlama varsa once o kalkar,
                // yoksa alarm kalici olarak acilir.
                if (skipped && onSkipChanged != null) {
                  onSkipChanged!(
                    SkippedOccurrence(
                      kind: SkipKind.alarm,
                      reference: alarm.id,
                      fireAt: fireAt,
                    ),
                    false,
                  );
                  return;
                }
                onToggle(alarm, true);
              },
            ),
    );
    return isReordering
        ? row
        : SwipeToDelete(
            itemKey: ValueKey(alarm.id),
            onDelete: () => onDelete(alarm),
            child: row,
          );
  }

  /// Uzun basma menüsü: Kopyala / Sil. Silme swipe ile de yapılabiliyor;
  /// burada kopyalamanın yanında ikinci bir keşfedilebilir yol olarak durur.
  void _showRowMenu(BuildContext context, Alarm alarm) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDuplicate != null)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(context.l10n.alarmDuplicate),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDuplicate!(alarm);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(context.l10n.actionDelete),
              onTap: () {
                Navigator.pop(sheetContext);
                onDelete(alarm);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final tokens = context.tokens;

    return ReminderList(
      isReordering: isReordering,
      onReorder: onReorder,
      header: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 10),
        child: SectionLabel(context.l10n.remindersAlarmCount(alarms.length)),
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          isReordering
              ? context.l10n.reminderReorderHint
              : context.l10n.alarmsSwipeHint,
          style: AppTypography.hint.copyWith(
            color: tokens.textTertiary,
            height: 1.5,
          ),
        ),
      ),
      children: [
        for (final alarm in alarms)
          KeyedSubtree(
            key: ValueKey(alarm.id),
            child: _alarmRow(context, alarm),
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
              context.l10n.alarmsRescheduleNote,
              style: AppTypography.hint.copyWith(color: tokens.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS < 26'da destek yok; izin verilmemişse uyarı + "İzin ver". Her şey
  /// yolundaysa null döner.
  Widget? _permissionBanner(BuildContext context) {
    if (!isSupported) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: InfoBanner(
          icon: Icons.info_outline_rounded,
          text: context.l10n.alarmsUnsupported,
        ),
      );
    }
    if (!isPermissionGranted) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: InfoBanner(
          icon: Icons.notifications_off_rounded,
          text: context.l10n.alarmsNeedPermission,
          action: TextButton(
            onPressed: onRequestPermission,
            child: Text(context.l10n.permissionGrant),
          ),
        ),
      );
    }
    return null;
  }
}
