import '../../../core/models/skipped_occurrence.dart';
import '../../utils/time_format_context.dart';
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
    this.scheduleFailures = const {},
    this.onSkipChanged,
    required this.onEdit,
    required this.onDelete,
    this.onDuplicate,
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

  /// Satırın alt metni.
  ///
  /// Tek seferlik atlama artık ayrı bir eylem değil: anahtar kapatılınca
  /// altta çıkan çubuktan seçiliyor. Burada yalnızca **hangi durumda**
  /// olduğu yazıyor.
  String _subtitle(Alarm alarm, DateTime? snoozedUntil, bool skipped) {
    if (alarm.isActive && scheduleFailures.containsKey(alarm.id)) {
      return 'Kurulamadı — düzenleyip kaydederek yeniden dene';
    }
    if (snoozedUntil != null) return SnoozeNotice.label(snoozedUntil);
    if (skipped) return 'Yalnızca bu sefer atlanacak';
    if (!alarm.isActive) return 'Kapalı';
    return alarmSubtitle(alarm);
  }

  Widget _alarmRow(BuildContext context, Alarm alarm) {
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

    return SwipeToDelete(
      itemKey: ValueKey(alarm.id),
      // Onay sorulmuyor: silme dogrudan uygulaniyor, geri alma altta
      // "Geri al" ile veriliyor.
      onDelete: () => onDelete(alarm),
      // GroupedRow'un kendi onTap'i InkWell'de; uzun basma dıştan yakalanıyor
      // ki satır API'sine dokunulmasın.
      child: GestureDetector(
        onLongPress: () => _showRowMenu(context, alarm),
        child: GroupedRow(
          icon: Icons.alarm_rounded,
          title: Text(
          alarmTimeLabel(
            alarm,
            formatHourMinute: context.formatHourMinute,
          ),
        ),
          subtitle: Text(_subtitle(alarm, snoozedUntil, skipped)),
          onTap: () => onEdit(alarm),
          dimmed: !isOn,
          trailing: Switch(
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
        ),
      ),
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
                title: const Text('Kopyala'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDuplicate!(alarm);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Sil'),
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

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        SectionLabel('${alarms.length} alarm'),
        const SizedBox(height: 10),
        GroupedList(
          children: [for (final alarm in alarms) _alarmRow(context, alarm)],
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
