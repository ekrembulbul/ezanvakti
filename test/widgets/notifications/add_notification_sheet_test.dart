import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/presentation/widgets/notifications/add_notification_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    void Function(PrayerType, int)? onAdd,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(AddNotificationBottomSheet(onAdd: onAdd ?? (_, _) {})),
    );
    await tester.pump();
  }

  testWidgets('Alti vakit secenegi cizilir', (tester) async {
    await pumpSheet(tester);

    for (final name in ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('Bolum basliklari buyuk harf', (tester) async {
    await pumpSheet(tester);

    expect(find.text('NAMAZ VAKTİ'), findsOneWidget);
    expect(find.text('BİLDİRİM ZAMANI'), findsOneWidget);
  });

  testWidgets('Oncesinde secilince dakika tekerlegi acilir', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Dakika seçin'), findsNothing);

    await tester.tap(find.text('Öncesinde'));
    await tester.pumpAndSettle();

    expect(find.text('Dakika seçin'), findsOneWidget);
  });

  testWidgets('Tam vaktinde secilince sifir dakika ile eklenir', (
    tester,
  ) async {
    PrayerType? type;
    int? minutes;

    await pumpSheet(
      tester,
      onAdd: (t, m) {
        type = t;
        minutes = m;
      },
    );

    await tester.tap(find.text('Bildirim Ekle'));
    await tester.pumpAndSettle();

    expect(type, PrayerType.fajr);
    expect(minutes, 0);
  });

  testWidgets('Baska vakit secilince o vakit ile eklenir', (tester) async {
    PrayerType? type;

    await pumpSheet(tester, onAdd: (t, _) => type = t);

    await tester.tap(find.text('Akşam'));
    await tester.pump();
    await tester.tap(find.text('Bildirim Ekle'));
    await tester.pumpAndSettle();

    expect(type, PrayerType.maghrib);
  });
}
