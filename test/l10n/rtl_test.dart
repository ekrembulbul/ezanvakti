import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:ezanvakti/presentation/screens/tools_screen.dart';
import 'package:ezanvakti/presentation/utils/directional_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/theme_harness.dart';

void main() {
  testWidgets('Arapca secilince yon RTL olur', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithTheme(const ToolsScreen(), locale: const Locale('ar')),
    );
    await tester.pump();

    final context = tester.element(find.byType(ToolsScreen));
    expect(Directionality.of(context), TextDirection.rtl);
    // Arapca metin gorunmeli (Turkce degil).
    expect(find.text('القبلة'), findsOneWidget);
    expect(find.text('Kıble'), findsNothing);
  });

  testWidgets('Ingilizce secilince metinler ingilizce ve yon LTR', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithTheme(const ToolsScreen(), locale: const Locale('en')),
    );
    await tester.pump();

    final context = tester.element(find.byType(ToolsScreen));
    expect(Directionality.of(context), TextDirection.ltr);
    expect(find.text('Qibla'), findsOneWidget);
  });

  testWidgets('ileri oku yone gore donuyor', (tester) async {
    for (final entry in [
      (locale: const Locale('tr'), expected: Icons.chevron_right_rounded),
      (locale: const Locale('ar'), expected: Icons.chevron_left_rounded),
    ]) {
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) => Icon(context.forwardChevron),
          ),
          locale: entry.locale,
        ),
      );
      await tester.pump();
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, entry.expected, reason: entry.locale.languageCode);
    }
  });

  test('desteklenen diller tam', () {
    final codes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();
    expect(codes, {'tr', 'en', 'ar'});
  });
}
