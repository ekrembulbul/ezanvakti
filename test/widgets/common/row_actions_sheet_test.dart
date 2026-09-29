import 'package:ezanvakti/presentation/widgets/common/row_actions_sheet.dart';
import 'package:ezanvakti/presentation/widgets/common/section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  /// Sayfayı gerçek bir dokunuşla açar.
  Future<void> openSheet(
    WidgetTester tester, {
    String? title,
    VoidCallback? onDuplicate,
    VoidCallback? onDelete,
  }) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showRowActionsSheet(
              context,
              title: title,
              onDuplicate: onDuplicate,
              onDelete: onDelete ?? () {},
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('Başlık bölüm etiketi olarak Türkçe büyük harfle yazılır', (
    tester,
  ) async {
    await openSheet(tester, title: 'İkindi · 10 dk önce');

    expect(find.byType(SectionLabel), findsOneWidget);
    expect(find.text('İKİNDİ · 10 DK ÖNCE'), findsOneWidget);
  });

  testWidgets('Başlık verilmezse başlık satırı çizilmez', (tester) async {
    await openSheet(tester);

    expect(find.byType(SectionLabel), findsNothing);
    expect(find.text('Sil'), findsOneWidget);
  });

  testWidgets('onDuplicate yoksa Kopyala görünmez', (tester) async {
    await openSheet(tester);

    expect(find.text('Kopyala'), findsNothing);
  });

  testWidgets('Sil hata renginde ve çöp kutusu ikonuyla çizilir', (
    tester,
  ) async {
    await openSheet(tester);
    final error = Theme.of(tester.element(find.text('Sil'))).colorScheme.error;

    expect(tester.widget<Text>(find.text('Sil')).style!.color, error);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.delete_outline_rounded)).color,
      error,
    );
  });

  testWidgets('Sil önce sayfayı kapatır, sonra onDelete çağrılır', (
    tester,
  ) async {
    late Route<dynamic> sheetRoute;
    bool? sheetActiveAtDelete;
    await openSheet(
      tester,
      onDelete: () => sheetActiveAtDelete = sheetRoute.isActive,
    );
    sheetRoute = ModalRoute.of(tester.element(find.text('Sil')))!;

    await tester.tap(find.text('Sil'));
    // İkinci dokunuş aynı karede gelir; alttaki ekran kapanmamalı.
    await tester.tap(find.text('Sil'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(sheetActiveAtDelete, isFalse, reason: 'önce pop, sonra eylem');
    expect(find.text('Sil'), findsNothing);
    expect(find.text('aç'), findsOneWidget, reason: 'alttaki ekran kapanmaz');
  });

  testWidgets('Kopyala önce sayfayı kapatır, sonra onDuplicate çağrılır', (
    tester,
  ) async {
    late Route<dynamic> sheetRoute;
    bool? sheetActiveAtDuplicate;
    await openSheet(
      tester,
      onDuplicate: () => sheetActiveAtDuplicate = sheetRoute.isActive,
    );
    sheetRoute = ModalRoute.of(tester.element(find.text('Kopyala')))!;

    await tester.tap(find.text('Kopyala'));
    await tester.pumpAndSettle();

    expect(sheetActiveAtDuplicate, isFalse);
    expect(find.text('Kopyala'), findsNothing);
  });
}
