import 'package:ezanvakti/core/theme/app_typography.dart';
import 'package:ezanvakti/presentation/widgets/common/app_surface.dart';
import 'package:ezanvakti/presentation/widgets/common/content_width.dart';
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

    Future<void> pumpAt(
      WidgetTester tester,
      Size size, {
      bool limitContentWidth = true,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapWithTheme(
          AppSurface(
            limitContentWidth: limitContentWidth,
            child: const SizedBox.expand(key: Key('content')),
          ),
        ),
      );
    }

    testWidgets('Tablette içerik ortada sınırlı genişlikte, zemin tam ekran', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1024, 1366));

      final content = tester.getRect(find.byKey(const Key('content')));
      expect(content.width, ContentWidth.max);
      expect(content.center.dx, 512);
      expect(tester.getSize(find.byType(AppSurface)).width, 1024);
    });

    testWidgets('Telefonda içerik ekranın tamamını kullanır', (tester) async {
      await pumpAt(tester, const Size(390, 844));

      expect(tester.getSize(find.byKey(const Key('content'))).width, 390);
    });

    testWidgets('Sınır kapatılınca içerik tam genişlikte kalır', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1024, 1366), limitContentWidth: false);

      expect(tester.getSize(find.byKey(const Key('content'))).width, 1024);
    });
  });
}
