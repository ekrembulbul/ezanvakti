import '../../../core/models/mission_session.dart';
import '../../../core/models/alarm.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../utils/time_format_context.dart';
import '../reminders/snooze_notice.dart';
import 'package:flutter/material.dart';

import '../../../core/models/skipped_occurrence.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/notifications/domain/skip_rules.dart';
import '../../utils/alarm_labels.dart' show alarmTimeLabel;
import '../../utils/reminder_labels.dart';
import '../../services/upcoming_resolver.dart';
import '../common/grouped_list.dart';
import '../common/section_label.dart';

/// Kart satırının yüksekliği (spec §6.1/7). Boş durum kutusuyla aynı olsun
/// diye ayrı sabit: veri gelince kartın boyu zıplamıyor.
const double _kRowHeight = 62;

/// Sıradaki bildirim ve alarmı gösteren grup.
///
/// En fazla iki satır (spec §6.1/7): "sırada ne var" sorusu tek bakışta
/// cevaplanır, tamamı "Tümü" ile açılır.
class UpcomingCard extends StatelessWidget {
  final UpcomingNotification? notification;
  final UpcomingAlarm? alarm;

  /// Kalan sürenin hesaplandığı an. Ana ekran saniyede bir yeniden çizildiği
  /// için dışarıdan verilir; widget kendi saatini tutmaz.
  final DateTime now;

  final VoidCallback onSeeAll;

  /// Atlanmış örnekler. Satır **dışlanmaz**; yalnızca kapalı çizilir ki
  /// kullanıcı fikrini değiştirip geri açabilsin.
  final Set<SkippedOccurrence> skips;

  /// Bekleyen görev oturumu; ertelenmiş alarmı buradan okuyoruz.
  final MissionSession? missionSession;

  /// Anahtar değişince çağrılır. `skipped` true ise atlanacak.
  final void Function(SkippedOccurrence occurrence, bool skipped)?
  onSkipChanged;

  const UpcomingCard({
    this.missionSession,
    super.key,
    required this.now,
    required this.onSeeAll,
    this.notification,
    this.alarm,
    this.skips = const {},
    this.onSkipChanged,
  });

  /// Satırın sağındaki tek seferlik kapatma anahtarı.
  ///
  /// Açık = çalacak. Kapalı = yalnızca bu örnek atlanacak; kalıcı kapatma
  /// Bildirimler/Alarmlar ekranlarında.
  Widget _skipSwitch(SkippedOccurrence occurrence, bool isSkippedNow) {
    return Switch(
      value: !isSkippedNow,
      onChanged: onSkipChanged == null
          ? null
          : (value) => onSkipChanged!(occurrence, !value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(
          context.l10n.upcomingTitle,
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSeeAll,
            child: Text(
              context.l10n.upcomingAll,
              style: AppTypography.hint.copyWith(
                color: tokens.accent,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (notification == null && alarm == null)
          _emptyState(context, tokens)
        else
          GroupedList(
            children: [
              if (notification != null) _notificationRow(context),
              if (alarm != null) _alarmRow(context),
            ],
          ),
      ],
    );
  }

  Widget _emptyState(BuildContext context, AppTokens tokens) {
    return Container(
      height: _kRowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        context.l10n.upcomingEmpty,
        style: AppTypography.rowSubtitle.copyWith(color: tokens.textTertiary),
      ),
    );
  }

  Widget _notificationRow(BuildContext context) {
    final item = notification!;
    final offset = notificationRuleLabel(item.setting, context.l10n);
    final occurrence = notificationOccurrence(item);
    final skipped = isSkipped(
      skips,
      kind: SkipKind.notification,
      reference: occurrence.reference,
      fireAt: item.time,
    );

    return GroupedRow(
      height: _kRowHeight,
      icon: Icons.notifications_rounded,
      title: Text(
        notificationTitle(item.setting, context.l10n),
        style: AppTypography.upcomingRowTitle,
      ),
      subtitle: Text(
        skipped
            ? '${context.l10n.reminderSkippedOnce} · ${_clock(context, item.time)}'
            : '$offset · ${reminderDayLabel(context, item.time, now)} '
                  '${_clock(context, item.time)} · '
                  '${formatRemaining(item.time.difference(now), context.l10n)}',
      ),
      trailing: _skipSwitch(occurrence, skipped),
    );
  }

  Widget _alarmRow(BuildContext context) {
    final tokens = context.tokens;
    final item = alarm!;
    final label = alarmTimeLabel(
      item.alarm,
      l10n: context.l10n,
      formatHourMinute: context.formatHourMinute,
    );
    final name = item.alarm.label.trim();
    final title = name.isNotEmpty ? name : label;
    final day = reminderDayLabel(context, item.time, now);
    final schedule = item.alarm.kind == AlarmKind.fixed
        ? '${name.isEmpty ? day : '$day ${_clock(context, item.time)}'} · '
              '${formatRemaining(item.time.difference(now), context.l10n)}'
        : '${name.isEmpty ? '' : '$label · '}$day ${_clock(context, item.time)}';

    final occurrence = SkippedOccurrence(
      kind: SkipKind.alarm,
      reference: item.alarm.id,
      fireAt: item.time,
    );
    final skipped = isSkipped(
      skips,
      kind: SkipKind.alarm,
      reference: item.alarm.id,
      fireAt: item.time,
    );

    final snoozedUntil = SnoozeNotice.snoozedUntilFor(
      missionSession,
      item.alarm,
    );

    return GroupedRow(
      height: _kRowHeight,
      icon: Icons.alarm_rounded,
      iconColor: tokens.accent,
      title: Text(title, style: AppTypography.upcomingRowTitle),
      subtitle: Text(switch ((snoozedUntil, skipped)) {
        (final DateTime until, _) => SnoozeNotice.label(until, context.l10n),
        (_, true) =>
          '${context.l10n.reminderSkippedOnce} · '
              '${reminderDayLabel(context, item.time, now)} ${_clock(context, item.time)}',
        _ => schedule,
      }),
      // Ertelenmis gorevli alarm atlanamaz: gorev borcu duruyor.
      trailing: SnoozeNotice.canDisable(missionSession, item.alarm)
          ? _skipSwitch(occurrence, skipped)
          : const Switch(value: true, onChanged: null),
    );
  }

  String _clock(BuildContext context, DateTime time) =>
      context.formatTime(time);
}

/// Kalan süreyi tasarımın kısa biçimiyle yazar: "2s 43dk", "43dk", "<1dk".
String formatRemaining(Duration remaining, AppLocalizations l10n) {
  return reminderRemaining(remaining, l10n);
}
