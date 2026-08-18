import 'package:ezanvakti/presentation/widgets/common/option_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  const items = [
    OptionItem(value: 5, label: '5 dakika'),
    OptionItem(value: 10, label: '10 dakika', description: 'Biraz daha uzun'),
    OptionItem(value: 15, label: '15 dakika'),
  ];

  Widget build({int selected = 5, ValueChanged<int>? onChanged}) =>
      wrapWithTheme(
        OptionRow<int>(
          label: 'Erteleme süresi',
          selected: selected,
          items: items,
          onChanged: onChanged ?? (_) {},
        ),
      );

  testWidgets('Satirda etiket ve secili deger yazar', (tester) async {
    await tester.pumpWidget(build(selected: 10));
    expect(find.text('Erteleme süresi'), findsOneWidget);
    expect(find.text('10 dakika'), findsOneWidget);
  });

  testWidgets('Dokununca secenekler alt sayfada acilir', (tester) async {
    await tester.pumpWidget(build());
    await tester.tap(find.text('Erteleme süresi'));
    await tester.pumpAndSettle();

    expect(find.byKey(kOptionSheetKey), findsOneWidget);
    expect(find.text('15 dakika'), findsOneWidget);
    expect(find.text('Biraz daha uzun'), findsOneWidget);
  });

  testWidgets('Secim yapinca deger bildirilir ve sayfa kapanir', (
    tester,
  ) async {
    int? picked;
    await tester.pumpWidget(build(onChanged: (v) => picked = v));
    await tester.tap(find.text('Erteleme süresi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 dakika'));
    await tester.pumpAndSettle();

    expect(picked, 15);
    expect(find.byKey(kOptionSheetKey), findsNothing);
  });

  testWidgets('Iptalde deger degismez', (tester) async {
    int? picked;
    await tester.pumpWidget(build(onChanged: (v) => picked = v));
    await tester.tap(find.text('Erteleme süresi'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(kOptionSheetKey))).pop();
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });

  testWidgets('Secili deger satirin sagina yaslanir', (tester) async {
    await tester.pumpWidget(build(selected: 10));

    final row = tester.getRect(find.byType(OptionRow<int>));
    final value = tester.getRect(find.byKey(kOptionValueKey));
    // Deger kutusu satirin sag yarisinda bitmeli; ortada durmamali.
    expect(value.right, greaterThan(row.left + row.width * 0.8));
  });

  testWidgets('valueLabel satirdaki yaziyi belirler', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        OptionRow<int>(
          label: 'Süre',
          selected: 5,
          items: items,
          valueLabel: (v) => 'özel $v',
          onChanged: (_) {},
        ),
      ),
    );
    expect(find.text('özel 5'), findsOneWidget);
  });
}
