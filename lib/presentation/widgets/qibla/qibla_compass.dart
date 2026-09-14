import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens_context.dart';

const Key kQiblaArrowKey = Key('qibla_arrow');
const Key kQiblaCompassKey = Key('qibla_compass');

const Duration _kStateAnimation = Duration(milliseconds: 260);
const Duration _kNeedleAnimation = Duration(milliseconds: 180);

/// Kıble pusulası kadranı.
///
/// Çentik üstte sabittir; ibre kıbleye olan **farkı** gösterir, cihaz döndükçe
/// çentiğe yaklaşır. [turns] sürekli (sarmalanmamış) tur sayısıdır ki
/// ibre ±180 sınırında ters yönde tam tur atmasın. Hizalanınca halka, ibre
/// ve parıltı onay rengine döner, kadran hafifçe büyür.
class QiblaCompass extends StatelessWidget {
  /// Null: pusula henüz okuma vermedi; ibre yerine bekleme simgesi çizilir.
  final double? turns;
  final bool aligned;
  final double size;

  const QiblaCompass({
    super.key,
    required this.turns,
    required this.aligned,
    this.size = 264,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final ringColor = aligned ? tokens.success : tokens.border;
    final needleColor = aligned ? tokens.success : tokens.accent;
    final fill = aligned
        ? Color.alphaBlend(
            tokens.success.withValues(alpha: 0.10),
            tokens.surface,
          )
        : tokens.surface;
    final turns = this.turns;

    return AnimatedScale(
      scale: aligned ? 1.04 : 1,
      duration: _kStateAnimation,
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        key: kQiblaCompassKey,
        duration: _kStateAnimation,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: ringColor, width: aligned ? 3 : 2),
          boxShadow: [
            BoxShadow(
              color: tokens.success.withValues(alpha: aligned ? 0.35 : 0),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _DialPainter(
                tickColor: tokens.border,
                majorTickColor: tokens.textTertiary,
                targetColor: aligned ? tokens.success : tokens.accent,
              ),
            ),
            if (turns == null)
              Icon(Icons.explore_outlined, size: 64, color: tokens.border)
            else
              AnimatedRotation(
                key: kQiblaArrowKey,
                turns: turns,
                duration: _kNeedleAnimation,
                curve: Curves.easeOutCubic,
                child: CustomPaint(
                  size: Size(size * 0.40, size * 0.76),
                  painter: _NeedlePainter(
                    color: needleColor,
                    tailColor: tokens.mutedTrack,
                    hubColor: fill,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kadran: her 6°'de küçük, her 30°'de büyük çentik; üstte hedef işareti.
class _DialPainter extends CustomPainter {
  final Color tickColor;
  final Color majorTickColor;
  final Color targetColor;

  const _DialPainter({
    required this.tickColor,
    required this.majorTickColor,
    required this.targetColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final minor = Paint()
      ..color = tickColor
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final major = Paint()
      ..color = majorTickColor
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 60; i++) {
      // Üstteki hedef işaretiyle çakışmasın.
      if (i == 0) continue;
      final isMajor = i % 5 == 0;
      final angle = i * 6 * math.pi / 180 - math.pi / 2;
      final outer = radius - 10;
      final inner = outer - (isMajor ? 10 : 5);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        isMajor ? major : minor,
      );
    }

    final notch = Path()
      ..moveTo(center.dx - 8, 8)
      ..lineTo(center.dx + 8, 8)
      ..lineTo(center.dx, 24)
      ..close();
    canvas.drawPath(notch, Paint()..color = targetColor);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.tickColor != tickColor ||
      old.majorTickColor != majorTickColor ||
      old.targetColor != targetColor;
}

/// İbre: renkli ok üst yarıda, sönük kuyruk alt yarıda, ortada göbek.
class _NeedlePainter extends CustomPainter {
  final Color color;
  final Color tailColor;
  final Color hubColor;

  const _NeedlePainter({
    required this.color,
    required this.tailColor,
    required this.hubColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final w = size.width;
    final h = size.height;

    final head = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx + w * 0.5, h * 0.34)
      ..lineTo(cx + w * 0.16, h * 0.29)
      ..lineTo(cx + w * 0.16, cy)
      ..lineTo(cx - w * 0.16, cy)
      ..lineTo(cx - w * 0.16, h * 0.29)
      ..lineTo(cx - w * 0.5, h * 0.34)
      ..close();

    final tail = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx - w * 0.11, cy, cx + w * 0.11, h * 0.88),
      Radius.circular(w * 0.11),
    );

    canvas.drawShadow(head, const Color(0xFF000000), 6, true);
    canvas.drawRRect(tail, Paint()..color = tailColor);
    canvas.drawPath(
      head,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withValues(alpha: 0.78)],
        ).createShader(Rect.fromLTWH(0, 0, w, cy)),
    );

    final hubRadius = w * 0.12;
    canvas.drawCircle(Offset(cx, cy), hubRadius, Paint()..color = hubColor);
    canvas.drawCircle(
      Offset(cx, cy),
      hubRadius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter old) =>
      old.color != color ||
      old.tailColor != tailColor ||
      old.hubColor != hubColor;
}
