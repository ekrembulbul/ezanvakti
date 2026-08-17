import 'package:flutter/material.dart';

import '../../core/models/alarm.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';

const Key kMissionAbortKey = Key('mission_abort');
const Key kMissionSnoozeKey = Key('mission_snooze');
const Key kMissionSnoozedOkKey = Key('mission_snoozed_ok');

/// Görev ekranının kabuğu: başlık, kalan süre, görev gövdesi, erteleme ve
/// acil çıkış. Görev tipini bilmez — gövdeyi [child] olarak alır.
class MissionScreen extends StatelessWidget {
  final Alarm alarm;

  /// Görev süresinden kalan saniye. Ekranda görünür olmalı: alarmın geri
  /// dönmesi sürpriz olmamalı.
  final int remainingSeconds;

  /// Kalan erteleme hakkı. 0 ise erteleme düğmesi hiç çizilmez.
  final int snoozeRemaining;

  /// Erteleme yapıldıysa alarmın tekrar çalacağı an. Doluysa ekran görev
  /// yerine erteleme bilgisini gösterir.
  final DateTime? snoozedUntil;

  /// Erteleme bilgisi ekranındaki "Tamam".
  final VoidCallback? onDismissSnoozed;

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
    this.snoozedUntil,
    this.onDismissSnoozed,
  });

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  String get _countdown {
    final s = remainingSeconds < 0 ? 0 : remainingSeconds;
    final minutes = s ~/ 60;
    final seconds = (s % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _snoozedBody(AppTokens tokens) {
    final at = snoozedUntil!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Alarm ertelendi',
          style: AppTypography.screenTitle.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          '${_clock(at)}\'te tekrar çalacak',
          style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          snoozeRemaining > 0
              ? '$snoozeRemaining erteleme hakkın kaldı'
              : 'Erteleme hakkın kalmadı; alarm bir daha çalınca görevi yapman gerekecek',
          textAlign: TextAlign.center,
          style: AppTypography.tabLabel.copyWith(color: tokens.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = alarm.label.isEmpty ? 'Alarm' : alarm.label;
    final showSnooze = onSnooze != null && snoozeRemaining > 0;

    return Scaffold(
      backgroundColor: tokens.backgroundStops.last,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.screenTitle.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                switch (snoozedUntil) {
                  final DateTime t => 'Ertelendi · ${_clock(t)}',
                  // Sure dolduysa alarm geri donuyor; sayac 0'da donmus gibi
                  // gorunmesin.
                  _ when remainingSeconds <= 0 =>
                    'Süre doldu, alarm geri dönüyor',
                  _ => 'Kalan süre $_countdown',
                },
                textAlign: TextAlign.center,
                style: AppTypography.tabLabel.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: snoozedUntil == null ? child : _snoozedBody(tokens)),
              if (snoozedUntil != null)
                FilledButton(
                  key: kMissionSnoozedOkKey,
                  onPressed: onDismissSnoozed,
                  child: const Text('Tamam'),
                ),
              if (snoozedUntil == null && showSnooze)
                TextButton(
                  key: kMissionSnoozeKey,
                  onPressed: onSnooze,
                  child: Text('Ertele ($snoozeRemaining hakkın kaldı)'),
                ),
              if (snoozedUntil == null)
                TextButton(
                  key: kMissionAbortKey,
                  onPressed: onAbortRequested,
                  child: Text(
                    'Alarmı tamamen kapat',
                    style: TextStyle(color: tokens.textTertiary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
