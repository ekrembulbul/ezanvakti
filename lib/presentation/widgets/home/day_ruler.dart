import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// [now] anının İmsak→Yatsı aralığındaki oranı (0..1).
///
/// Aralığın dışında kırpılır: İmsak'tan önce 0, Yatsı'dan sonra 1.
double dayProgress(PrayerTime prayerTime, DateTime now) {
  final span = prayerTime.isha.difference(prayerTime.fajr).inSeconds;
  if (span <= 0) return 0;
  final passed = now.difference(prayerTime.fajr).inSeconds;
  return (passed / span).clamp(0.0, 1.0);
}

/// Günün İmsak→Yatsı şeridi: ilerleme, vakit çentikleri ve şu anki saat.
class DayRuler extends StatelessWidget {
  final PrayerTime prayerTime;
  final DateTime now;

  const DayRuler({super.key, required this.prayerTime, required this.now});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final progress = dayProgress(prayerTime, now);
    final marks = <DateTime>[
      prayerTime.fajr,
      prayerTime.sunrise,
      prayerTime.dhuhr,
      prayerTime.asr,
      prayerTime.maghrib,
      prayerTime.isha,
    ];

    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final markerX = width * progress;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 16,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: tokens.mutedTrack,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 16,
                child: Container(
                  width: markerX,
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        tokens.accent.withValues(alpha: 0.4),
                        tokens.accent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              for (final mark in marks)
                Positioned(
                  left: (width - 2) * dayProgress(prayerTime, mark),
                  top: 12,
                  child: Container(
                    key: const Key('ruler_tick'),
                    width: 2,
                    height: 13,
                    decoration: BoxDecoration(
                      // Gecmis vakitler vurgulu, gelecek olanlar sonuk.
                      color: mark.isAfter(now)
                          ? tokens.mutedTrack
                          : tokens.accent.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              Positioned(
                left: markerX - 20,
                top: 0,
                child: SizedBox(
                  width: 40,
                  child: Text(
                    DateFormat('HH:mm').format(now),
                    textAlign: TextAlign.center,
                    style: AppTypography.rulerTime.copyWith(
                      color: tokens.accent,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: markerX - 8,
                top: 10.5,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tokens.backgroundStops[1],
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.accent.withValues(alpha: 0.5),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 27,
                child: Text(
                  DateFormat('HH:mm').format(prayerTime.fajr),
                  style: _edgeStyle(context),
                ),
              ),
              Positioned(
                right: 0,
                top: 27,
                child: Text(
                  DateFormat('HH:mm').format(prayerTime.isha),
                  style: _edgeStyle(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  TextStyle _edgeStyle(BuildContext context) {
    return AppTypography.rulerTime.copyWith(
      color: context.tokens.textTertiary,
      fontWeight: FontWeight.w600,
      fontVariations: const [FontVariation('wght', 600)],
    );
  }
}
