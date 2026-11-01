import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Sessiz vaktin zaman çizgisi: ince bir çizgi, üstünde vurgulu sessiz
/// aralık ve vakit anında dikey işaret; altında başlangıç, vakit ve bitiş.
///
/// Vakit işareti her zaman ortadadır: uzun taraf yarım genişliğin büyük
/// kısmını doldurur, kısa taraf ona oranla çizilir. Böylece ortadaki kalın
/// vakit etiketi işaretin tam altında kalır. Sağdan sola dilde zaman sağdan
/// sola akar; "önce" tarafı sağa geçer.
class QuietTimeline extends StatelessWidget {
  final int minutesBefore;
  final int minutesAfter;

  /// Başlangıç saati; vakit verisi yoksa `null` (etiket boş kalır).
  final String? startLabel;

  /// Ortadaki kalın etiket, ör. "Öğle 12:22"; veri yoksa yalnız vakit adı.
  final String prayerLabel;

  /// Bitiş saati; vakit verisi yoksa `null`.
  final String? endLabel;

  const QuietTimeline({
    super.key,
    required this.minutesBefore,
    required this.minutesAfter,
    required this.prayerLabel,
    this.startLabel,
    this.endLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final secondary = AppTypography.rowSubtitle.copyWith(
      color: tokens.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 24,
          child: CustomPaint(
            painter: _TimelinePainter(
              minutesBefore: minutesBefore,
              minutesAfter: minutesAfter,
              textDirection: Directionality.of(context),
              trackColor: tokens.divider,
              rangeColor: tokens.accent,
              markerColor: tokens.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                startLabel ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
                style: secondary,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                prayerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.rowTitle.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              ),
            ),
            Expanded(
              child: Text(
                endLabel ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final int minutesBefore;
  final int minutesAfter;
  final TextDirection textDirection;
  final Color trackColor;
  final Color rangeColor;
  final Color markerColor;

  /// Uzun tarafın yarım genişlikten aldığı pay; uçlarda çizgi görünür kalsın.
  static const double _fill = 0.84;

  const _TimelinePainter({
    required this.minutesBefore,
    required this.minutesAfter,
    required this.textDirection,
    required this.trackColor,
    required this.rangeColor,
    required this.markerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = trackColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final longest = math.max(minutesBefore, minutesAfter);
    final half = centerX * _fill;
    final beforeLength = longest == 0 ? 0.0 : half * minutesBefore / longest;
    final afterLength = longest == 0 ? 0.0 : half * minutesAfter / longest;
    final rtl = textDirection == TextDirection.rtl;
    final left = centerX - (rtl ? afterLength : beforeLength);
    final right = centerX + (rtl ? beforeLength : afterLength);

    if (right > left) {
      canvas.drawLine(
        Offset(left, centerY),
        Offset(right, centerY),
        Paint()
          ..color = rangeColor
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawLine(
      Offset(centerX, 1),
      Offset(centerX, size.height - 1),
      Paint()
        ..color = markerColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.minutesBefore != minutesBefore ||
      old.minutesAfter != minutesAfter ||
      old.textDirection != textDirection ||
      old.trackColor != trackColor ||
      old.rangeColor != rangeColor ||
      old.markerColor != markerColor;
}
