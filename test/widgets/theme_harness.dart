import 'package:ezanvakti/core/theme/app_theme.dart';
import 'package:ezanvakti/core/theme/app_tokens.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:flutter/material.dart';

/// Widget testlerinde gercek palet altinda render etmek icin.
///
/// Token okuyan bir widget, `AppTokens` extension'i olmayan bir tema altinda
/// patlar; bu sarmalayici testin gercek kosullari taklit etmesini saglar.
Widget wrapWithTheme(
  Widget child, {
  DayPhase phase = DayPhase.evening,
  Brightness brightness = Brightness.dark,
}) {
  final tokens = paletteFor(phase, brightness);
  return MaterialApp(
    theme: AppTheme.build(tokens, brightness),
    home: Scaffold(body: child),
  );
}

/// Testte beklenen rengi hesaplamak icin ayni paleti dondurur.
AppTokens tokensFor({
  DayPhase phase = DayPhase.evening,
  Brightness brightness = Brightness.dark,
}) => paletteFor(phase, brightness);
