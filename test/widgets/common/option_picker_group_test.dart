import 'package:ezanvakti/presentation/widgets/common/option_picker.dart';
import 'package:ezanvakti/presentation/widgets/common/section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  Future<void> openSheet(
    WidgetTester tester,
    List<OptionItem<int>> items,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        OptionRow<int>(
          label: 'Seçim',
          sheetTitle: 'Başlık',
          selected: 1,
          items: items,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('Seçim'));
    await tester.pumpAndSettle();
  }

  testWidgets('Grup verilince alt sayfada grup basliklari cizilir', (
    tester,
  ) async {
    await openSheet(tester, const [
      OptionItem(value: 1, label: 'Bir', group: 'Namaz'),
      OptionItem(value: 2, label: 'İki', group: 'Namaz'),
      OptionItem(value: 3, label: 'Üç', group: 'Hesaplanan'),
    ]);

    // Baslik + iki grup.
    expect(find.byType(SectionLabel), findsNWidgets(3));
    expect(find.text('NAMAZ'), findsOneWidget);
    expect(find.text('HESAPLANAN'), findsOneWidget);
    // "Bir" satirin secili degerinde de yaziyor; alt sayfadaki kopya sonda.
    expect(
      tester.getTopLeft(find.text('NAMAZ')).dy,
      lessThan(tester.getTopLeft(find.text('Bir').last).dy),
    );
    expect(
      tester.getTopLeft(find.text('İki')).dy,
      lessThan(tester.getTopLeft(find.text('HESAPLANAN')).dy),
    );
  });

  testWidgets('Grup yoksa yalnizca baslik cizilir', (tester) async {
    await openSheet(tester, const [
      OptionItem(value: 1, label: 'Bir'),
      OptionItem(value: 2, label: 'İki'),
    ]);

    expect(find.byType(SectionLabel), findsOneWidget);
  });
}
