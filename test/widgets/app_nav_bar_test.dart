import 'package:ezanvakti/presentation/widgets/common/app_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_harness.dart';

void main() {
  const items = [
    NavItem(label: 'Vakitler', icon: Icons.schedule_rounded),
    NavItem(label: 'Takvim', icon: Icons.calendar_month_rounded),
    NavItem(label: 'Hatırlatıcılar', icon: Icons.notifications_rounded),
  ];

  Widget build({int selected = 0, ValueChanged<int>? onChanged}) =>
      wrapWithTheme(
        Align(
          alignment: Alignment.bottomCenter,
          child: AppNavBar(
            items: items,
            selected: selected,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      );

  testWidgets('Uc oge de etiketiyle cizilir', (tester) async {
    await tester.pumpWidget(build());

    expect(find.text('Vakitler'), findsOneWidget);
    expect(find.text('Takvim'), findsOneWidget);
    expect(find.text('Hatırlatıcılar'), findsOneWidget);
  });

  testWidgets('Secili oge vurgu rengini, digerleri notr rengi alir', (
    tester,
  ) async {
    await tester.pumpWidget(build(selected: 1));

    final tokens = tokensFor();
    expect(tester.widget<Text>(find.text('Takvim')).style!.color, tokens.accent);
    expect(
      tester.widget<Text>(find.text('Vakitler')).style!.color,
      tokens.textTertiary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.calendar_month_rounded)).color,
      tokens.accent,
    );
  });

  testWidgets('Dokunma onChanged i dogru indeksle cagirir', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(build(onChanged: tapped.add));

    await tester.tap(find.text('Hatırlatıcılar'));
    await tester.pump();

    expect(tapped, [2]);
  });

  testWidgets('Gosterge secili dilimin ortasinda durur', (tester) async {
    await tester.pumpWidget(build(selected: 1));
    await tester.pumpAndSettle();

    final indicator = tester.getCenter(find.byKey(kNavIndicatorKey));
    final label = tester.getCenter(find.text('Takvim'));

    expect(indicator.dx, closeTo(label.dx, 0.5));
  });

  testWidgets('Gosterge etiketin altinda kalir, uzerine binmez', (
    tester,
  ) async {
    await tester.pumpWidget(build(selected: 1));
    await tester.pumpAndSettle();

    final labelBottom = tester.getRect(find.text('Takvim')).bottom;
    final indicatorTop = tester.getRect(find.byKey(kNavIndicatorKey)).top;

    expect(
      indicatorTop,
      greaterThanOrEqualTo(labelBottom),
      reason: 'Column mainAxisSize.min olursa etiket asagi kayip gostergenin '
          'bandina giriyordu',
    );
  });

  testWidgets('Etiket dar dilimde tasmaz', (tester) async {
    // En dar desteklenen genislik; spec §10/V1.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(build(selected: 2));

    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.text('Hatırlatıcılar'));
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
