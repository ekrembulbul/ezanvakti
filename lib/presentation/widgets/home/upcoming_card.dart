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
import '../../utils/alarm_labels.dart';
import '../../utils/reminder_labels.dart';
import '../../services/upcoming_resolver.dart';
import '../common/grouped_list.dart';
import '../common/section_label.dart';

/// Etiketsiz kart satırı ve boş durumun ortak taban yüksekliği.
const double _kRowHeight = 70;
const double _kLabeledRowHeight = 84;

/// Sıradaki bildirim ve alarmı gösteren grup.
///
/// En fazla iki satır (spec §6.1/7): "sırada ne var" sorusu tek bakışta
/// cevaplanır, tamamı "Tümü" ile açılır.
class UpcomingCard extends StatelessWidget {
  final UpcomingNotification? notification;
  final UpcomingAlarm? alarm;

  /// Kalan sürenin hesaplandığı an. Ana ekranın yenilemesiyle güncellenir;
  /// widget kendi saatini tutmaz.
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
    final primary = notificationRuleLabel(item.setting, context.l10n);
    final customLabel = notificationCustomLabel(item.setting);
    final occurrence = notificationOccurrence(item);
    final skipped = isSkipped(
      skips,
      kind: SkipKind.notification,
      reference: occurrence.reference,
      fireAt: item.time,
    );

    return GroupedRow(
      height: customLabel == null ? _kRowHeight : _kLabeledRowHeight,
      growWithContent: true,
      icon: Icons.notifications_rounded,
      title: Text(primary, style: AppTypography.gridValue),
      subtitle: _details(
        context,
        important: skipped
            ? '${context.l10n.reminderSkippedOnce} · '
                  '${_clock(context, item.time)}'
            : '${reminderDayLabel(context, item.time, now)} '
                  '${_clock(context, item.time)} · '
                  '${formatRemaining(item.time.difference(now), context.l10n)}',
        label: customLabel,
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
    final customLabel = item.alarm.label.trim();

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
      height: customLabel.isEmpty ? _kRowHeight : _kLabeledRowHeight,
      growWithContent: true,
      icon: Icons.alarm_rounded,
      iconColor: tokens.accent,
      title: Row(
        children: [
          Flexible(child: Text(label, style: AppTypography.gridValue)),
          if (missionIcon(item.alarm.mission) case final icon?) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: missionLabel(item.alarm.mission, context.l10n),
              child: Icon(icon, size: 17, color: tokens.accent),
            ),
          ],
        ],
      ),
      subtitle: _details(
        context,
        important: switch ((snoozedUntil, skipped)) {
          (final DateTime until, _) =>
            '${SnoozeNotice.label(until, context.l10n)} · '
                '${formatRemaining(until.difference(now), context.l10n)}',
          (_, true) =>
            '${context.l10n.reminderSkippedOnce} · '
                '${reminderDayLabel(context, item.time, now)} '
                '${_clock(context, item.time)}',
          _ =>
            '${item.alarm.kind == AlarmKind.fixed ? reminderDayLabel(context, item.time, now) : '${reminderDayLabel(context, item.time, now)} ${_clock(context, item.time)}'} · '
                '${formatRemaining(item.time.difference(now), context.l10n)}',
        },
        label: customLabel.isEmpty ? null : customLabel,
      ),
      // Ertelenmis gorevli alarm atlanamaz: gorev borcu duruyor.
      trailing: SnoozeNotice.canDisable(missionSession, item.alarm)
          ? _skipSwitch(occurrence, skipped)
          : const Switch(value: true, onChanged: null),
    );
  }

  String _clock(BuildContext context, DateTime time) =>
      context.formatTime(time);

  Widget _details(
    BuildContext context, {
    required String important,
    String? label,
  }) {
    final tokens = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(important, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (label != null) ...[
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.hint.copyWith(color: tokens.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Kalan süreyi kısa biçimde yazar: "2 sa 43 dk", "43 dk", "1 gün", "<1dk".
String formatRemaining(Duration remaining, AppLocalizations l10n) {
  return reminderRemaining(remaining, l10n);
}
