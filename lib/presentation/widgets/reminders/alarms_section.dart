import '../../../core/models/skipped_occurrence.dart';
import '../../../features/notifications/domain/skip_rules.dart';
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

  /// Alarm id'si → bir sonraki çalma anı. Tek seferlik atlama bu örneğe
  /// uygulanır; atlama uygulanmamış hâliyle hesaplanır.
  final Map<String, DateTime> nextFireByAlarm;

  final Set<SkippedOccurrence> skips;

  /// Tek seferlik atlama değiştirildiğinde çağrılır.
  final void Function(SkippedOccurrence occurrence, bool skipped)?
  onSkipChanged;
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
    this.nextFireByAlarm = const {},
    this.skips = const {},
    this.onSkipChanged,
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

  /// Alt metin ve yanındaki tek seferlik atlama eylemi.
  ///
  /// Satırdaki anahtar **kalıcı** aç/kapa; atlama ayrı bir eylem olarak
  /// duruyor ki hangisinin ne yaptığı okunabilsin.
  Widget _subtitle(BuildContext context, Alarm alarm, DateTime? snoozedUntil) {
    final tokens = context.tokens;
    if (snoozedUntil != null) {
      return Text(SnoozeNotice.label(snoozedUntil));
    }

    final fireAt = nextFireByAlarm[alarm.id];
    final canSkip =
        alarm.isActive && fireAt != null && onSkipChanged != null;
    if (!canSkip) return Text(alarmSubtitle(alarm));

    final occurrence = SkippedOccurrence(
      kind: SkipKind.alarm,
      reference: alarm.id,
      fireAt: fireAt,
    );
    final skipped = isSkipped(
      skips,
      kind: SkipKind.alarm,
      reference: alarm.id,
      fireAt: fireAt,
    );

    return Row(
      children: [
        Flexible(
          child: Text(
            skipped ? 'Yalnızca bu sefer atlanacak' : alarmSubtitle(alarm),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Text(' · '),
        GestureDetector(
          onTap: () => onSkipChanged!(occurrence, !skipped),
          child: Text(
            skipped ? 'Geri al' : 'Bu seferi atla',
            style: TextStyle(color: tokens.accent),
          ),
        ),
      ],
    );
  }

  Widget _alarmRow(BuildContext context, Alarm alarm) {
    final snoozedUntil = SnoozeNotice.snoozedUntilFor(missionSession, alarm);
    final canDisable = SnoozeNotice.canDisable(missionSession, alarm);

    return SwipeToDelete(
      itemKey: ValueKey(alarm.id),
      // Onay sorulmuyor: silme dogrudan uygulaniyor, geri alma altta
      // "Geri al" ile veriliyor.
      onDelete: () => onDelete(alarm),
      child: GroupedRow(
        icon: Icons.alarm_rounded,
        title: Text(alarmTimeLabel(alarm)),
        subtitle: _subtitle(context, alarm, snoozedUntil),
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
            'Silmek için satırı sola kaydırın; yanlışlıkla silersen alttaki '
            '"Geri al" ile dönersin. Alarmlar vakit güncellendiğinde otomatik '
            'yeniden planlanır.',
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
