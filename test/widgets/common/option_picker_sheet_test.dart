import 'package:ezanvakti/presentation/widgets/common/option_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  /// Kirk secenek: alt sayfa siniri olmasa ekrani boydan boya kaplar.
  final many = [
    for (var i = 1; i <= 40; i++)
      OptionItem(value: i, label: 'Seçenek $i', description: 'Açıklama $i'),
  ];

  Future<void> openSheet(
    WidgetTester tester, {
    ValueChanged<int>? onChanged,
  }) async {
    await tester.pumpWidget(
      wrapWithTheme(
        OptionRow<int>(
          label: 'Seçim',
          sheetTitle: 'Başlık',
          selected: 1,
          items: many,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    );
    await tester.tap(find.text('Seçim'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Uzun listede alt sayfa ekranin ustunde dokunulacak yer birakir',
    (tester) async {
      await openSheet(tester);

      final screen = tester.getSize(find.byType(MaterialApp));
      final sheet = tester.getRect(find.byKey(kOptionSheetKey));
      expect(sheet.top, greaterThanOrEqualTo(screen.height * 0.2 - 1));
    },
  );

  testWidgets('Alt sayfa durum cubugunun altina girmez', (tester) async {
    // Fiziksel 150 px ust bosluk = 3.0 DPR'de 50 mantiksal px (durum cubugu).
    tester.view.padding = const FakeViewPadding(top: 150);
    addTearDown(tester.view.resetPadding);
    await openSheet(tester);

    final sheet = tester.getRect(find.byKey(kOptionSheetKey));
    expect(sheet.top, greaterThanOrEqualTo(50));
  });

  testWidgets('Disina dokununca secim yapmadan kapanir', (tester) async {
    var changed = false;
    await openSheet(tester, onChanged: (_) => changed = true);
    expect(find.byKey(kOptionSheetKey), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byKey(kOptionSheetKey), findsNothing);
    expect(changed, isFalse);
  });

  testWidgets('Surukleme tutamaci cizilir', (tester) async {
    await openSheet(tester);
    expect(find.byKey(kOptionSheetHandleKey), findsOneWidget);
  });
}
