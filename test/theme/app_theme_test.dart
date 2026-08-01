import 'package:ezanvakti/core/theme/app_theme.dart';
import 'package:ezanvakti/core/theme/app_tokens.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:ezanvakti/core/theme/tokens_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('build, tokenlari ThemeData extension olarak tasir', () {
    final tokens = paletteFor(DayPhase.evening, Brightness.dark);
    final theme = AppTheme.build(tokens, Brightness.dark);

    expect(theme.extension<AppTokens>(), same(tokens));
  });

  test('ColorScheme vurgu rengini kullanir', () {
    final tokens = paletteFor(DayPhase.morning, Brightness.dark);
    final theme = AppTheme.build(tokens, Brightness.dark);

    expect(theme.colorScheme.primary, tokens.accent);
    expect(theme.brightness, Brightness.dark);
  });

  test('Acik temada brightness light olur', () {
    final tokens = paletteFor(DayPhase.morning, Brightness.light);
    final theme = AppTheme.build(tokens, Brightness.light);

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.brightness, Brightness.light);
  });

  test('Font ailesi Manrope', () {
    final tokens = paletteFor(DayPhase.night, Brightness.dark);
    final theme = AppTheme.build(tokens, Brightness.dark);

    expect(theme.textTheme.bodyMedium?.fontFamily, 'Manrope');
  });

  test('Scaffold zemini gradyanin son duragidir', () {
    final tokens = paletteFor(DayPhase.night, Brightness.dark);
    final theme = AppTheme.build(tokens, Brightness.dark);

    expect(theme.scaffoldBackgroundColor, tokens.backgroundStops.last);
  });

  testWidgets('context.tokens aktif paleti dondurur', (tester) async {
    final tokens = paletteFor(DayPhase.morning, Brightness.dark);
    late AppTokens seen;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(tokens, Brightness.dark),
        home: Builder(
          builder: (context) {
            seen = context.tokens;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(seen, same(tokens));
  });
}
