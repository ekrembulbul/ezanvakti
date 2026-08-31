import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/core/models/prayer_log.dart';
import 'package:ezanvakti/presentation/screens/dhikr_screen.dart';
import 'package:ezanvakti/presentation/screens/prayer_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

void main() {
  final today = DateTime(2026, 9, 4);

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapWithTheme(child));
    await tester.pumpAndSettle();
  }

  group('PrayerTrackingScreen', () {
    testWidgets('izgara ve kaza sayaci cizilir', (tester) async {
      final storage = FakeStorage();
      await pump(
        tester,
        PrayerTrackingScreen(storage: storage, today: today),
      );

      expect(find.byKey(kTrackingGridKey), findsOneWidget);
      expect(find.text('Kaza sayacı'.toUpperCase()), findsOneWidget);
      // Bes vakit hem izgarada hem kaza listesinde: ikiser kez.
      expect(find.text('İmsak'), findsNWidgets(2));
      expect(find.text('Güneş'), findsNothing, reason: 'gunes takip edilmez');
    });

    testWidgets('kaza sayaci artirilinca depoya yazilir', (tester) async {
      final storage = FakeStorage();
      await pump(
        tester,
        PrayerTrackingScreen(storage: storage, today: today),
      );

      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      final counts = await storage.getQadaCounts();
      expect(counts[PrayerType.fajr], 1);
    });

    testWidgets('yuklenen kayitlar izgarada gorunur', (tester) async {
      final storage = FakeStorage();
      await storage.setPrayerLog(today, PrayerType.dhuhr, PrayerStatus.done);
      await pump(
        tester,
        PrayerTrackingScreen(storage: storage, today: today),
      );

      final log = await storage.getPrayerLog(today, today);
      expect(log[prayerLogKey(today, PrayerType.dhuhr)], PrayerStatus.done);
    });
  });

  group('DhikrScreen', () {
    testWidgets('dokunusla sayac artar ve depoya yazilir', (tester) async {
      final storage = FakeStorage();
      await pump(tester, DhikrScreen(storage: storage, today: today));

      expect(find.byKey(kDhikrCountKey), findsOneWidget);
      await tester.tap(find.byKey(kDhikrTapAreaKey));
      await tester.pumpAndSettle();

      expect(await storage.getDhikrCount(today), 1);
    });

    testWidgets('gunun kayitli sayaci yuklenir', (tester) async {
      final storage = FakeStorage();
      await storage.setDhikrCount(today, 40);
      await pump(tester, DhikrScreen(storage: storage, today: today));

      // Hedef 33: 40 sayisi 1 tur + 7.
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Bugün toplam 40'), findsOneWidget);
    });

    testWidgets('geri al sayaci azaltir', (tester) async {
      final storage = FakeStorage();
      await storage.setDhikrCount(today, 5);
      await pump(tester, DhikrScreen(storage: storage, today: today));

      await tester.tap(find.byIcon(Icons.undo_rounded));
      await tester.pumpAndSettle();

      expect(await storage.getDhikrCount(today), 4);
    });
  });
}
