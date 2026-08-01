import 'package:ezanvakti/core/theme/app_typography.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('paletteFor', () {
    test('Sekiz palet de tanimli ve zemin uc duraga sahip', () {
      for (final phase in DayPhase.values) {
        for (final brightness in Brightness.values) {
          final tokens = paletteFor(phase, brightness);
          expect(tokens.backgroundStops.length, 3, reason: '$phase/$brightness');
        }
      }
    });

    test('Koyu Aksam paleti spec degerlerini tasir', () {
      final tokens = paletteFor(DayPhase.evening, Brightness.dark);

      expect(tokens.accent, const Color(0xFFE09FB8));
      expect(tokens.textPrimary, const Color(0xFFF3EEF4));
      expect(tokens.textSecondary, const Color(0xFFB5A8C1));
      expect(tokens.textTertiary, const Color(0xFFA294AF));
      expect(tokens.textValue, const Color(0xFFCFC3D6));
      expect(tokens.backgroundStops, const [
        Color(0xFF4A2144),
        Color(0xFF241634),
        Color(0xFF120E1B),
      ]);
    });

    test('Koyu Sabah paleti spec degerlerini tasir', () {
      final tokens = paletteFor(DayPhase.morning, Brightness.dark);

      expect(tokens.accent, const Color(0xFF93C4E8));
      expect(tokens.backgroundStops.first, const Color(0xFF2C5279));
      expect(tokens.backgroundStops.last, const Color(0xFF08141F));
    });

    test('Acik temada murekkep paletin Metin1 rengidir', () {
      // Kural: acik tema yuzey/kenarlik/ayirac renkleri textPrimary uzerinden
      // turetilir. GULKURUSU'ndaki tasarim sapmasi kurala uyduruldu.
      for (final phase in DayPhase.values) {
        final tokens = paletteFor(phase, Brightness.light);

        expect(tokens.surface.a, lessThan(0.2), reason: '$phase yuzey alfasi');
        expect(tokens.surface.r, closeTo(tokens.textPrimary.r, 0.001));
        expect(tokens.surface.g, closeTo(tokens.textPrimary.g, 0.001));
        expect(tokens.surface.b, closeTo(tokens.textPrimary.b, 0.001));
      }
    });

    test('Koyu temada murekkep beyazdir', () {
      for (final phase in DayPhase.values) {
        final tokens = paletteFor(phase, Brightness.dark);

        expect(tokens.surface.r, closeTo(1.0, 0.001), reason: '$phase');
        expect(tokens.surface.g, closeTo(1.0, 0.001), reason: '$phase');
        expect(tokens.surface.b, closeTo(1.0, 0.001), reason: '$phase');
      }
    });

    test('Acik Gulkurusu murekkebi kurala uygun (#201A1E)', () {
      final tokens = paletteFor(DayPhase.evening, Brightness.light);

      expect(tokens.textPrimary, const Color(0xFF201A1E));
    });
  });

  group('AppTokens.lerp', () {
    test('t=0 ve t=1 uc degerleri dondurur', () {
      final a = paletteFor(DayPhase.morning, Brightness.dark);
      final b = paletteFor(DayPhase.night, Brightness.dark);

      expect(a.lerp(b, 0).accent, a.accent);
      expect(a.lerp(b, 1).accent, b.accent);
      expect(a.lerp(b, 0).backgroundStops, a.backgroundStops);
      expect(a.lerp(b, 1).backgroundStops, b.backgroundStops);
    });

    test('Ara degerde zemin duraklari kaybolmaz', () {
      final a = paletteFor(DayPhase.morning, Brightness.dark);
      final b = paletteFor(DayPhase.night, Brightness.dark);

      final mid = a.lerp(b, 0.5);

      expect(mid.backgroundStops.length, 3);
      expect(mid.accent, isNot(a.accent));
      expect(mid.accent, isNot(b.accent));
    });

    test('Farkli tipte extension verilirse kendini dondurur', () {
      final a = paletteFor(DayPhase.morning, Brightness.dark);

      expect(a.lerp(null, 0.5), same(a));
    });
  });

  group('AppTokens.backgroundGradient', () {
    test('Uc durak ve sabit geometri', () {
      final tokens = paletteFor(DayPhase.night, Brightness.dark);
      final gradient = tokens.backgroundGradient;

      expect(gradient.colors, tokens.backgroundStops);
      expect(gradient.stops, const [0.0, 0.44, 1.0]);
      expect(gradient.radius, 1.25);
    });
  });

  group('AppTypography', () {
    test('Tum boyutlar 10 basamakli olcek icinde', () {
      for (final style in AppTypography.all) {
        expect(
          AppTypography.scale,
          contains(style.fontSize),
          reason: '${style.fontSize}px olcek disi',
        );
      }
    });

    test('Saat gosteren stiller tabular figures kullanir', () {
      for (final style in [
        AppTypography.counter,
        AppTypography.gridValue,
        AppTypography.tomorrowValue,
        AppTypography.rulerTime,
      ]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    test('Tum stiller Manrope ailesini kullanir', () {
      for (final style in AppTypography.all) {
        expect(style.fontFamily, 'Manrope');
      }
    });

    test('Stiller renk tasimaz — renk AppTokens tan gelir', () {
      for (final style in AppTypography.all) {
        expect(style.color, isNull);
      }
    });

    test('Degisken font icin agirlik wght ekseninden secilir', () {
      // Yalnizca fontWeight vermek degisken fontta sentetik kalinlik uretir;
      // gercek eksen degeri fontVariations ile gelir ve ikisi tutarli olmali.
      for (final style in AppTypography.all) {
        final variations = style.fontVariations;
        expect(variations, isNotNull, reason: '${style.fontSize}px');
        expect(variations!.single.axis, 'wght');
        expect(variations.single.value, style.fontWeight!.value.toDouble());
      }
    });
  });
}
