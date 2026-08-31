import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extensions.dart';
import 'package:intl/intl.dart';

import '../../core/config/mission_tuning.dart';
import '../../core/models/alarm.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../utils/alarm_labels.dart';
import '../widgets/missions/mission_metrics.dart';

const Key kStopPrimaryKey = Key('stop_primary');
const Key kStopSnoozeKey = Key('stop_snooze');
const Key kStopCountdownKey = Key('stop_countdown');

/// Alarm durdurulunca açılan karar ekranı. Salt sunum: sayaç ve eylemler
/// dışarıdan gelir.
///
/// Görevli alarmda "Görevi yap / Ertele", görevsizde "Tamam / Ertele". Görev
/// ekranıyla aynı dil (spec 2026-08-30 D13): uyku sersemi okunacak.
class AlarmStopScreen extends StatelessWidget {
  final Alarm alarm;
  final bool gated;

  /// Kalan saniye: görevlide alarmın dönmesine, görevsizde ekranın
  /// kapanmasına.
  final int remainingSeconds;

  /// Kalan erteleme hakkı; `null` sınırsız.
  final int? snoozeRemaining;

  final DateTime firedAt;
  final DateTime stoppedAt;
  final DateTime now;

  /// Görevlide görev ekranına geçer, görevsizde kapatır.
  final VoidCallback onPrimary;
  final VoidCallback? onSnooze;

  const AlarmStopScreen({
    super.key,
    required this.alarm,
    required this.gated,
    required this.remainingSeconds,
    required this.snoozeRemaining,
    required this.firedAt,
    required this.stoppedAt,
    required this.now,
    required this.onPrimary,
    this.onSnooze,
  });

  String get _countdown {
    final s = remainingSeconds < 0 ? 0 : remainingSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// Sabit alarmda kurulu saat; çıpalıda gerçek çalış anı (vakit her gün
  /// kayar, kullanıcı bugünkü saati görmeli).
  String _timeText(AppLocalizations l10n) => alarm.kind == AlarmKind.fixed
      ? alarmTimeLabel(alarm, l10n: l10n)
      : DateFormat('HH:mm').format(firedAt); // ekran icinde sabit 24 saat

  String _detailText(AppLocalizations l10n) {
    final ago = now.difference(stoppedAt).inMinutes;
    final agoText = ago < 1 ? l10n.stopJustNow : l10n.stopMinutesAgo(ago);
    final first = alarm.kind == AlarmKind.fixed
        ? weekdaysLabel(alarm.weekdays, l10n)
        : alarmTimeLabel(alarm, l10n: l10n);
    return '$first · $agoText';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: tokens.backgroundStops.last,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'ALARM DURDURULDU',
                textAlign: TextAlign.center,
                style: AppTypography.sectionLabel.copyWith(
                  color: tokens.textTertiary,
                ),
              ),
              const Spacer(),
              _header(tokens, l10n),
              if (gated) ...[const SizedBox(height: 24), _missionCard(tokens, l10n)],
              const Spacer(),
              _primaryButton(tokens, l10n),
              if (onSnooze != null) ...[
                const SizedBox(height: 12),
                _snoozeButton(tokens, l10n),
                if (snoozeRemaining != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.stopSnoozeLeft(snoozeRemaining ?? 0),
                    textAlign: TextAlign.center,
                    style: AppTypography.hint.copyWith(
                      fontSize: 14,
                      color: tokens.textTertiary,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
              _footer(tokens, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppTokens tokens, AppLocalizations l10n) {
    final title = alarm.label.isEmpty ? 'Alarm' : alarm.label;
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.screenTitle.copyWith(
            fontSize: 22,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            _timeText(l10n),
            style: AppTypography.counter.copyWith(color: tokens.textPrimary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _detailText(l10n),
          textAlign: TextAlign.center,
          style: AppTypography.hint.copyWith(
            fontSize: 15,
            color: tokens.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _missionCard(AppTokens tokens, AppLocalizations l10n) {
    final seconds = MissionTuning.timeoutSecondsFor(alarm.mission);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(kMissionButtonRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, color: tokens.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${missionLabel(alarm.mission, l10n)} · '
              '${alarm.missionLevel} · $seconds sn',
              style: AppTypography.rowTitle.copyWith(
                fontSize: kMissionSupportFontSize,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(AppTokens tokens, AppLocalizations l10n) {
    return SizedBox(
      height: kMissionButtonHeight,
      child: FilledButton(
        key: kStopPrimaryKey,
        onPressed: onPrimary,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.backgroundStops.last,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kMissionButtonRadius),
          ),
        ),
        child: Text(
          gated ? l10n.stopDoMission : 'Tamam',
          style: AppTypography.rowTitle.copyWith(
            fontSize: kMissionButtonFontSize,
          ),
        ),
      ),
    );
  }

  Widget _snoozeButton(AppTokens tokens, AppLocalizations l10n) {
    return SizedBox(
      height: kMissionButtonHeight,
      child: OutlinedButton(
        key: kStopSnoozeKey,
        onPressed: onSnooze,
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.accent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kMissionButtonRadius),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Ertele · ${alarm.snoozeMinutes} dk',
            style: AppTypography.rowTitle.copyWith(
              fontSize: kMissionButtonFontSize,
            ),
          ),
        ),
      ),
    );
  }

  /// Görevlide uyarı (alarm döner), görevsizde bilgi (kapanır).
  Widget _footer(AppTokens tokens, AppLocalizations l10n) {
    final text = gated
        ? l10n.stopReturnsIn(_countdown)
        : l10n.stopClosesIn(_countdown);
    return Text(
      text,
      key: kStopCountdownKey,
      textAlign: TextAlign.center,
      style: AppTypography.hint.copyWith(
        fontSize: 14,
        color: gated ? tokens.accent : tokens.textTertiary,
      ),
    );
  }
}
