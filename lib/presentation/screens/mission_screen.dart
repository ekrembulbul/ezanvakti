import 'package:flutter/material.dart';

import '../../core/models/alarm.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';

const Key kMissionAbortKey = Key('mission_abort');
const Key kMissionSnoozeKey = Key('mission_snooze');

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

  String get _countdown {
    final s = remainingSeconds < 0 ? 0 : remainingSeconds;
    final minutes = s ~/ 60;
    final seconds = (s % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
                'Kalan süre $_countdown',
                textAlign: TextAlign.center,
                style: AppTypography.tabLabel.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: child),
              if (showSnooze)
                TextButton(
                  key: kMissionSnoozeKey,
                  onPressed: onSnooze,
                  child: Text('Ertele ($snoozeRemaining hakkın kaldı)'),
                ),
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
