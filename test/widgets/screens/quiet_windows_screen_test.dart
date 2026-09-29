import 'dart:async';

import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/notification_setting.dart'
    show PrayerType;
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/presentation/screens/quiet_windows_screen.dart';
import 'package:ezanvakti/presentation/widgets/common/delete_action_button.dart';
import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

void main() {
  const dhuhr = QuietWindow(
    id: 'q1',
    trigger: QuietTrigger.prayer,
    prayerType: PrayerType.dhuhr,
    minutesBefore: 10,
    minutesAfter: 30,
  );
  const asr = QuietWindow(
    id: 'q2',
    trigger: QuietTrigger.prayer,
    prayerType: PrayerType.asr,
    minutesBefore: 5,
    minutesAfter: 20,
  );

  late FakeStorage storage;
  late int changes;

  setUp(() async {
    storage = FakeStorage();
    await storage.init();
    changes = 0;
    ServiceLocator().register<LocalStorage>(storage);
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    List<QuietWindow> windows,
  ) async {
    await storage.saveQuietWindows(windows);
    await tester.pumpWidget(
      wrapWithTheme(QuietWindowsScreen(onChanged: () async => changes++)),
    );
    await tester.pumpAndSettle();
  }

  Future<List<String>> savedIds() async => [
    for (final window in await storage.getQuietWindows()) window.id,
  ];

  testWidgets(
    'Kaydırma yok; menü vakit ve süreyi yazar, Sil siler, Geri al eski sırasına koyar',
    (tester) async {
      await pumpScreen(tester, [QuietWindow.fridayDefault(), dhuhr, asr]);
      expect(find.byType(Dismissible), findsNothing);

      await tester.longPress(find.widgetWithText(GroupedRow, 'Öğle'));
      await tester.pumpAndSettle();
      expect(find.text('ÖĞLE · 10 DK ÖNCE – 30 DK SONRA'), findsOneWidget);
      expect(find.text('Kopyala'), findsNothing);
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(await savedIds(), ['friday', 'q2']);
      expect(find.widgetWithText(GroupedRow, 'Öğle'), findsNothing);
      expect(find.text('Sessiz aralık silindi'), findsOneWidget);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(await savedIds(), ['friday', 'q1', 'q2']);
      expect(find.widgetWithText(GroupedRow, 'Öğle'), findsOneWidget);
      expect(changes, 2, reason: 'silme ve geri alma ikisi de yeniden planlar');
    },
  );

  testWidgets('Cuma kartında basılı tutma menü açmaz', (tester) async {
    await pumpScreen(tester, [QuietWindow.fridayDefault(), dhuhr]);

    await tester.longPress(find.text('Cuma vaktinde sessiz'));
    await tester.pumpAndSettle();

    expect(find.text('Sil'), findsNothing);
  });

  testWidgets(
    'Paneldeki "Aralığı sil" paneli kapatır ve siler; Geri al geri getirir',
    (tester) async {
      await pumpScreen(tester, [dhuhr, asr]);

      await tester.tap(find.text('İkindi'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DeleteActionButton>(find.byType(DeleteActionButton))
            .framed,
        isTrue,
      );
      await tester.tap(find.text('Aralığı sil'));
      // İkinci dokunuş aynı karede gelir; ekran kapanmamalı.
      await tester.tap(find.text('Aralığı sil'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(QuietWindowsScreen), findsOneWidget);
      expect(await savedIds(), ['q1']);
      expect(find.text('Sessiz aralık silindi'), findsOneWidget);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(await savedIds(), ['q1', 'q2']);
    },
  );

  testWidgets('"Geri al" çubuğu yeniden planlamayı beklemeden çıkar', (
    tester,
  ) async {
    final reschedule = Completer<void>();
    await storage.saveQuietWindows([dhuhr, asr]);
    await tester.pumpWidget(
      wrapWithTheme(QuietWindowsScreen(onChanged: () => reschedule.future)),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.widgetWithText(GroupedRow, 'Öğle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(await savedIds(), ['q2']);
    expect(
      find.text('Sessiz aralık silindi'),
      findsOneWidget,
      reason: 'planlama sürerken de geri alma sunulur',
    );
    reschedule.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Yeniden planlama hata verse de silme kalır ve "Geri al" çıkar', (
    tester,
  ) async {
    await storage.saveQuietWindows([dhuhr, asr]);
    await tester.pumpWidget(
      wrapWithTheme(
        QuietWindowsScreen(onChanged: () async => throw Exception('plan')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.widgetWithText(GroupedRow, 'Öğle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(await savedIds(), ['q2']);
    expect(find.text('Sessiz aralık silindi'), findsOneWidget);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(await savedIds(), ['q1', 'q2']);
    expect(tester.takeException(), isNull);
  });
}
