import 'package:ezanvakti/presentation/widgets/common/delete_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  /// Kart: kenarlıklı `BoxDecoration` taşıyan `Container`.
  Finder frame() => find.descendant(
    of: find.byType(DeleteActionButton),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).border != null,
    ),
  );

  testWidgets('Yazı ve çöp kutusu hata renginde, en az 52 pt', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(DeleteActionButton('Alarmı sil', () {})),
    );
    final label = find.text('Alarmı sil');
    final error = Theme.of(tester.element(label)).colorScheme.error;

    expect(DefaultTextStyle.of(tester.element(label)).style.color, error);
    expect(
      IconTheme.of(
        tester.element(find.byIcon(Icons.delete_outline_rounded)),
      ).color,
      error,
    );
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(52),
    );
  });

  testWidgets('Basınca onPressed çağrılır', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      wrapWithTheme(DeleteActionButton('Alarmı sil', () => pressed++)),
    );

    await tester.tap(find.text('Alarmı sil'));

    expect(pressed, 1);
  });

  testWidgets('framed iken yüzey kartında durur', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(DeleteActionButton('Alarmı sil', () {})),
    );
    final tokens = tokensFor();
    final decoration =
        tester.widget<Container>(frame()).decoration! as BoxDecoration;

    expect(decoration.color, tokens.surface);
    expect(decoration.border, Border.all(color: tokens.border));
    expect(decoration.borderRadius, BorderRadius.circular(16));
  });

  testWidgets('framed: false iken kartsız çizilir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(DeleteActionButton('Konumu sil', () {}, framed: false)),
    );

    expect(frame(), findsNothing);
    expect(find.text('Konumu sil'), findsOneWidget);
  });
}
