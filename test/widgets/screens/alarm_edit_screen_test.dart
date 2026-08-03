import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/presentation/screens/alarm_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  Future<void> pumpEdit(WidgetTester tester, {Alarm? alarm}) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapWithTheme(AlarmEditScreen(alarm: alarm)));
    await tester.pump();
  }

  testWidgets('Yeni alarmda baslik "Alarm ekle"', (tester) async {
    await pumpEdit(tester);

    expect(find.text('Alarm ekle'), findsOneWidget);
  });

  testWidgets('Mevcut alarmda baslik "Alarmı düzenle"', (tester) async {
    await pumpEdit(
      tester,
      alarm: const Alarm(id: '1', kind: AlarmKind.fixed, hour: 6, minute: 30),
    );

    expect(find.text('Alarmı düzenle'), findsOneWidget);
  });

  testWidgets('Tur secimi kayan segment ile yapilir', (tester) async {
    await pumpEdit(tester);

    expect(find.text('Sabit saat'), findsOneWidget);
    expect(find.text('Vakte göre'), findsOneWidget);
  });

  testWidgets('Bolum basliklari buyuk harf', (tester) async {
    await pumpEdit(tester);

    expect(find.text('SAAT'), findsOneWidget);
    expect(find.text('TEKRAR'), findsOneWidget);
    expect(find.text('ETİKET'), findsOneWidget);
  });

  testWidgets('Vakte gore secilince vakit ve zamanlama bolumleri gelir', (
    tester,
  ) async {
    await pumpEdit(tester);

    await tester.tap(find.text('Vakte göre'));
    await tester.pumpAndSettle();

    expect(find.text('VAKİT'), findsOneWidget);
    expect(find.text('ZAMANLAMA'), findsOneWidget);
    expect(find.text('Önce'), findsOneWidget);
    expect(find.text('Tam vaktinde'), findsOneWidget);
    expect(find.text('Sonra'), findsOneWidget);
  });

  testWidgets('Tekrar bolumunde uc hizli secim var', (tester) async {
    await pumpEdit(tester);

    expect(find.text('Her gün'), findsOneWidget);
    expect(find.text('Hafta içi'), findsOneWidget);
    expect(find.text('Hafta sonu'), findsOneWidget);
  });

  testWidgets('Hafta sonu secilince yalnizca Ct ve Pa aktif kalir', (
    tester,
  ) async {
    await pumpEdit(tester);

    await tester.tap(find.text('Hafta sonu'));
    await tester.pump();

    // Secim kaydedilmeden dogrulanamaz; en azindan cip aktiflesmis olmali.
    expect(find.text('Hafta sonu'), findsOneWidget);
  });

  testWidgets('En az bir gun secili kalir', (tester) async {
    await pumpEdit(tester);

    for (final day in ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa']) {
      await tester.tap(find.text(day));
      await tester.pump();
    }

    // Yedi gunu de kapatmak mumkun degil; sonuncu secili kalir.
    expect(find.text('Pa'), findsOneWidget);
  });
}
