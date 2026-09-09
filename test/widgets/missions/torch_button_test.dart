import 'package:ezanvakti/presentation/widgets/missions/torch_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme_harness.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    TorchState state, {
    VoidCallback? onPressed,
  }) => tester.pumpWidget(
    wrapWithTheme(
      Scaffold(
        body: TorchButton(state: state, onPressed: onPressed),
      ),
    ),
  );

  testWidgets('Flassiz cihazda dugme hic gorunmez', (tester) async {
    await pump(tester, TorchState.unavailable);

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('Kapaliyken acma etiketi tasir', (tester) async {
    await pump(tester, TorchState.off);

    expect(find.byTooltip('Flaşı aç'), findsOneWidget);
  });

  testWidgets('Acikken kapatma etiketi tasir', (tester) async {
    await pump(tester, TorchState.on);

    expect(find.byTooltip('Flaşı kapat'), findsOneWidget);
  });

  testWidgets('Acik ve kapali durum farkli ikon gosterir', (tester) async {
    await pump(tester, TorchState.off);
    final off = tester.widget<Icon>(find.byType(Icon)).icon;
    await pump(tester, TorchState.on);
    final on = tester.widget<Icon>(find.byType(Icon)).icon;

    expect(on, isNot(off));
  });

  testWidgets('Dokunus callbacki tetikler', (tester) async {
    var tapped = 0;
    await pump(tester, TorchState.off, onPressed: () => tapped++);
    await tester.tap(find.byType(IconButton));

    expect(tapped, 1);
  });
}
