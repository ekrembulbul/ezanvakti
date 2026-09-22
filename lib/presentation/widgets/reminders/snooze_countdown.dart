import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../l10n/l10n_extensions.dart';

const Key kSnoozeCountdownKey = Key('snooze_countdown');

/// Kalan saniyeyi `m:ss` yazar; negatif "0:00". Ara ekranın sayacı ve rozet
/// aynı biçimi kullanır.
String formatCountdownSeconds(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Ertelenmiş alarmın satır ve karttaki rozeti: "ERTELENDİ" + geri sayım.
///
/// Anahtarın yerinde durur (spec 2026-09-22 D2). Kendi saniyelik
/// zamanlayıcısıyla işler; sayfanın 10 sn'lik saati değişmez (D3). Sıfıra
/// inince "0:00" kalır — alarm çalıp durdurulunca oturum tazelenir ve rozet
/// kalkar. [clock] testler içindir.
class SnoozeCountdown extends StatefulWidget {
  final DateTime until;
  final DateTime Function() clock;

  const SnoozeCountdown({
    super.key,
    required this.until,
    this.clock = DateTime.now,
  });

  @override
  State<SnoozeCountdown> createState() => _SnoozeCountdownState();
}

class _SnoozeCountdownState extends State<SnoozeCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final remaining = widget.until.difference(widget.clock()).inSeconds;
    final time = DateFormat('HH:mm').format(widget.until);
    // Buyuk metin olceginde rozet satiri yutmasin: kompakt rozet en fazla
    // 1.3x buyur; metin sutunu ellipsis ile zaten korunuyor.
    return Semantics(
      label: l10n.snoozeBadgeSemantics(time),
      excludeSemantics: true,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Container(
          key: kSnoozeCountdownKey,
          constraints: const BoxConstraints(minWidth: 78),
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
          decoration: BoxDecoration(
            color: tokens.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.snoozeBadgeLabel,
                maxLines: 1,
                style: AppTypography.sectionLabel.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: tokens.accent,
                ),
              ),
              Text(
                formatCountdownSeconds(remaining),
                maxLines: 1,
                style: AppTypography.counter.copyWith(
                  fontSize: 22,
                  letterSpacing: -0.6,
                  height: 1.2,
                  color: tokens.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
