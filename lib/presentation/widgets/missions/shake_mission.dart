import 'dart:async';
import '../../../l10n/l10n_extensions.dart';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import 'mission_metrics.dart';
import '../../../features/alarms/domain/shake_detector.dart';

const Key kShakeProgressKey = Key('shake_progress');
const Duration _kAnimation = Duration(milliseconds: 220);

/// Sallama görevi: hedef sayıya ulaşınca [onCompleted] çağrılır.
///
/// İvmeölçer akışı dışarıdan verilebiliyor ki test cihaz gerektirmesin.
class ShakeMission extends StatefulWidget {
  final int level;
  final VoidCallback onCompleted;

  /// Testler için; verilmezse cihazın ivmeölçeri dinlenir.
  final Stream<({double x, double y, double z})>? samples;

  /// Testler için; verilmezse gerçek saat. Bekleme süresi buna göre ölçülür,
  /// `tester.pump` gerçek saati ilerletmediği için enjekte edilebilir olmalı.
  final DateTime Function()? now;

  const ShakeMission({
    super.key,
    required this.level,
    required this.onCompleted,
    this.samples,
    this.now,
  });

  @override
  State<ShakeMission> createState() => _ShakeMissionState();
}

class _ShakeMissionState extends State<ShakeMission>
    with SingleTickerProviderStateMixin {
  final _detector = ShakeDetector();
  late final int _target = ShakeDetector.targetFor(widget.level);
  StreamSubscription<dynamic>? _sub;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _kAnimation,
    lowerBound: 0.94,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void initState() {
    super.initState();
    final custom = widget.samples;
    if (custom != null) {
      _sub = custom.listen((s) => _onSample(s.x, s.y, s.z));
    } else {
      _sub = accelerometerEventStream().listen((e) => _onSample(e.x, e.y, e.z));
    }
  }

  void _onSample(double x, double y, double z) {
    final counted = _detector.onSample(
      x: x,
      y: y,
      z: z,
      at: (widget.now ?? DateTime.now)(),
    );
    if (!counted || !mounted) return;

    _pulse.forward(from: 0.94);
    setState(() {});
    if (_detector.count >= _target) {
      _sub?.cancel();
      widget.onCompleted();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final remaining = (_target - _detector.count).clamp(0, _target);
    final progress = _target == 0 ? 1.0 : _detector.count / _target;

    // Sigdiginda dikeyde ortalanir, sigmadiginda kaydirilir: icerik ustte
    // kalip altinda kocaman bir bosluk birakmasin.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulse,
                child: Icon(
                  Icons.vibration_rounded,
                  size: 72,
                  color: tokens.accent,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '$remaining',
                key: kShakeProgressKey,
                style: AppTypography.counter.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                remaining > 0
                    ? context.l10n.missionShakeRemaining
                    : context.l10n.missionShakeDone,
                style: AppTypography.rowTitle.copyWith(
                  fontSize: kMissionLeadFontSize,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              _bar(tokens, progress),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(AppTokens tokens, double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(color: tokens.divider),
            AnimatedFractionallySizedBox(
              duration: _kAnimation,
              curve: Curves.easeOutCubic,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(color: tokens.accent),
            ),
          ],
        ),
      ),
    );
  }
}
