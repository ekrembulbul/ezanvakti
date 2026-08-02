import 'package:ezanvakti/core/theme/app_typography.dart';
import 'package:ezanvakti/presentation/widgets/common/app_surface.dart';
import 'package:ezanvakti/presentation/widgets/common/section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_harness.dart';

void main() {
  group('SectionLabel', () {
    testWidgets('Metni buyuk harfe cevirip etiket stiliyle cizer', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithTheme(const SectionLabel('Sıradaki')));

      final text = tester.widget<Text>(find.byType(Text).first);

      expect(text.data, 'SIRADAKİ');
      expect(text.style!.fontSize, AppTypography.sectionLabel.fontSize);
      expect(text.style!.color, tokensFor().textTertiary);
    });

    testWidgets('Turkce buyuk harf donusumu dogru (i -> İ)', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const SectionLabel('bildirim')));

      expect(find.text('BİLDİRİM'), findsOneWidget);
    });

    testWidgets('Noktasiz i (I) korunur', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const SectionLabel('Sıradaki')));

      // "Sıradaki" -> "SIRADAKİ": noktasiz i buyuk I, noktali i buyuk İ olur.
      expect(find.text('SIRADAKİ'), findsOneWidget);
    });

    testWidgets('trailing verilince sagda cizilir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const SectionLabel('Yarın', trailing: Text('Takvim'))),
      );

      expect(find.text('YARIN'), findsOneWidget);
      expect(find.text('Takvim'), findsOneWidget);
    });
  });

  group('AppSurface', () {
    testWidgets('Paletin radial gradyanini zemin olarak kullanir', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(const AppSurface(child: Text('içerik'))),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppSurface),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.gradient, tokensFor().backgroundGradient);
      expect(find.text('içerik'), findsOneWidget);
    });
  });
}
