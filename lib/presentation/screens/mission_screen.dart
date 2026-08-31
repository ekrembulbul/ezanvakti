import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extensions.dart';

import '../../core/models/alarm.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../widgets/missions/mission_metrics.dart';

const Key kMissionAbortKey = Key('mission_abort');
const Key kMissionSnoozeKey = Key('mission_snooze');
const Key kMissionCountdownKey = Key('mission_countdown');

/// Acil çıkış birincil eylem değil: erteleme düğmesinden bir tık küçük.
const double _kSecondaryButtonHeight = 56;

/// Görev ekranının kabuğu: başlık, kalan süre, görev gövdesi, erteleme ve
/// acil çıkış. Görev tipini bilmez — gövdeyi [child] olarak alır.
class MissionScreen extends StatelessWidget {
  final Alarm alarm;

  /// Görev süresinden kalan saniye. Ekranda görünür olmalı: alarmın geri
  /// dönmesi sürpriz olmamalı.
  final int remainingSeconds;

  /// Kalan erteleme hakkı. 0 ise erteleme düğmesi hiç çizilmez.
  final int snoozeRemaining;

  final Widget child;
  final VoidCallback onCompleted;
  final VoidCallback onAbortRequested;
  final VoidCallback? onSnooze;

  const MissionScreen({
    super.key,
    required this.alarm,
    required this.remainingSeconds,
    required this.child,
    required this.onCompleted,
    required this.onAbortRequested,
    this.onSnooze,
    this.snoozeRemaining = 0,
  });

  bool get _expired => remainingSeconds <= 0;

  String get _countdown {
    final s = remainingSeconds < 0 ? 0 : remainingSeconds;
    final minutes = s ~/ 60;
    final seconds = (s % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
              _header(tokens, l10n),
              const SizedBox(height: 20),
              Expanded(child: child),
              const SizedBox(height: 20),
              if (onSnooze != null && snoozeRemaining > 0) ...[
                _snoozeButton(tokens, l10n),
                const SizedBox(height: 12),
              ],
              _abortButton(tokens, l10n),
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
            fontSize: 20,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        // Süre dolduysa alarm geri dönüyor; sayaç 0'da donmuş gibi görünmesin.
        if (_expired)
          Text(
            l10n.missionTimeUp,
            textAlign: TextAlign.center,
            style: AppTypography.screenTitle.copyWith(
              fontSize: 22,
              color: tokens.accent,
            ),
          )
        else ...[
          FittedBox(
            child: Text(
              _countdown,
              key: kMissionCountdownKey,
              style: AppTypography.counter.copyWith(color: tokens.textPrimary),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.missionCountdownNote,
            textAlign: TextAlign.center,
            style: AppTypography.hint.copyWith(
              fontSize: 14,
              color: tokens.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  /// Erteleme süresi düğmenin üstünde yazıyor: uyanmamış biri "Ertele"nin kaç
  /// dakika olduğunu hatırlamak zorunda kalmasın.
  Widget _snoozeButton(AppTokens tokens, AppLocalizations l10n) {
    return SizedBox(
      height: kMissionButtonHeight,
      child: FilledButton(
        key: kMissionSnoozeKey,
        onPressed: onSnooze,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.backgroundStops.last,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kMissionButtonRadius),
          ),
        ),
        // Buyuk punto + uzun etiket dar ekranda iki satira dusuyordu; sigmazsa
        // sarmak yerine kuculsun.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${alarm.snoozeMinutes} dk ertele · $snoozeRemaining hak',
            style: AppTypography.rowTitle.copyWith(
              fontSize: kMissionButtonFontSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _abortButton(AppTokens tokens, AppLocalizations l10n) {
    return SizedBox(
      height: _kSecondaryButtonHeight,
      child: OutlinedButton(
        key: kMissionAbortKey,
        onPressed: onAbortRequested,
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textSecondary,
          side: BorderSide(color: tokens.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kMissionButtonRadius),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            l10n.missionCloseCompletely,
            style: AppTypography.rowTitle.copyWith(fontSize: 17),
          ),
        ),
      ),
    );
  }
}
