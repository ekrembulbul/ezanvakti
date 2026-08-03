import 'dart:math' as math;

import 'package:ezanvakti/core/theme/app_tokens.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec §8 / V4: sekiz paletin metin rampasi ve accent'i okunabilir olmali.
///
/// Olcum zemini `backgroundStops` **ortalamasi**dir: arka plan radyal bir
/// gradyan, metin ekranin herhangi bir yerinde durabiliyor; tek bir stop'u
/// secmek ya fazla iyimser ya fazla karamsar olurdu. Zeminin uzerine ayrica
/// `surface` bindirilir, cunku metinlerin cogu kart icinde.
const double _minTextRatio = 4.5;

/// Sayac ve vurgular icin tasarimin iddia ettigi daha yuksek esik.
const double _minAccentRatio = 5.1;

/// WCAG 2.1 goreli parlaklik.
double _relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// [top] rengini [bottom] uzerine alfasiyla harmanlar (src-over).
Color _composite(Color top, Color bottom) {
  final alpha = top.a;
  return Color.from(
    alpha: 1.0,
    red: top.r * alpha + bottom.r * (1 - alpha),
    green: top.g * alpha + bottom.g * (1 - alpha),
    blue: top.b * alpha + bottom.b * (1 - alpha),
  );
}

Color _measurementBackground(AppTokens tokens) {
  final stops = tokens.backgroundStops;
  final average = Color.from(
    alpha: 1.0,
    red: stops.map((c) => c.r).reduce((a, b) => a + b) / stops.length,
    green: stops.map((c) => c.g).reduce((a, b) => a + b) / stops.length,
    blue: stops.map((c) => c.b).reduce((a, b) => a + b) / stops.length,
  );
  return _composite(tokens.surface, average);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final phase in DayPhase.values) {
      final label = '${phase.name}/${brightness.name}';
      final tokens = paletteFor(phase, brightness);
      final background = _measurementBackground(tokens);

      test('$label metin rampasi 4.5:1 esigini geciyor', () {
        final ramp = <String, Color>{
          'Metin1': tokens.textPrimary,
          'Metin2': tokens.textSecondary,
          'Metin3': tokens.textTertiary,
          'Deger': tokens.textValue,
        };

        ramp.forEach((name, color) {
          final ratio = _contrastRatio(color, background);
          expect(
            ratio,
            greaterThanOrEqualTo(_minTextRatio),
            reason: '$label $name orani ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });

      test('$label accent 5.1:1 esigini geciyor', () {
        final ratio = _contrastRatio(tokens.accent, background);
        expect(
          ratio,
          greaterThanOrEqualTo(_minAccentRatio),
          reason: '$label accent orani ${ratio.toStringAsFixed(2)}:1',
        );
      });
    }
  }

  test('Kontrast hesabi bilinen uc degerlerde dogru', () {
    expect(
      _contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21.0, 0.01),
    );
    expect(
      _contrastRatio(const Color(0xFF808080), const Color(0xFF808080)),
      closeTo(1.0, 0.01),
    );
  });
}
