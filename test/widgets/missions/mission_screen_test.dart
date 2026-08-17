import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/presentation/screens/mission_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  const alarm = Alarm(
    id: 'sahur',
    kind: AlarmKind.fixed,
    label: 'Sahur',
    mission: AlarmMission.math,
  );

  Widget build({
    int remainingSeconds = 90,
    int snoozeRemaining = 0,
    VoidCallback? onSnooze,
    VoidCallback? onAbort,
    DateTime? snoozedUntil,
  }) => wrapWithTheme(
    MissionScreen(
      alarm: alarm,
      remainingSeconds: remainingSeconds,
      snoozeRemaining: snoozeRemaining,
      snoozedUntil: snoozedUntil,
      onDismissSnoozed: () {},
      onCompleted: () {},
      onAbortRequested: onAbort ?? () {},
      onSnooze: onSnooze,
      child: const Text('gorev govdesi'),
    ),
  );

  testWidgets('Etiket, gorev govdesi ve geri sayim cizilir', (tester) async {
    await tester.pumpWidget(build(remainingSeconds: 75));
    expect(find.text('Sahur'), findsOneWidget);
    expect(find.text('gorev govdesi'), findsOneWidget);
    // Kalan sure gorunur olmali: alarm surpriz olmamali.
    expect(find.textContaining('1:15'), findsOneWidget);
  });

  testWidgets('Acil cikis her zaman gorunur', (tester) async {
    await tester.pumpWidget(build());
    expect(find.byKey(kMissionAbortKey), findsOneWidget);
  });

  testWidgets('Acil cikisa dokunmak istegi yukari bildirir', (tester) async {
    var asked = false;
    await tester.pumpWidget(build(onAbort: () => asked = true));
    await tester.tap(find.byKey(kMissionAbortKey));
    await tester.pump();
    expect(asked, isTrue);
  });

  testWidgets('Erteleme hakki varsa dugme ve kalan sayi gorunur', (
    tester,
  ) async {
    await tester.pumpWidget(build(snoozeRemaining: 2, onSnooze: () {}));
    expect(find.byKey(kMissionSnoozeKey), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);
  });

  testWidgets('Erteleme hakki bittiyse dugme hic cizilmez', (tester) async {
    await tester.pumpWidget(build(snoozeRemaining: 0, onSnooze: () {}));
    expect(find.byKey(kMissionSnoozeKey), findsNothing);
  });

  testWidgets('onSnooze verilmezse dugme cizilmez', (tester) async {
    await tester.pumpWidget(build(snoozeRemaining: 3));
    expect(find.byKey(kMissionSnoozeKey), findsNothing);
  });

  testWidgets('Sure dolunca sayac yerine alarmin dondugu soylenir', (
    tester,
  ) async {
    await tester.pumpWidget(build(remainingSeconds: 0));
    expect(find.textContaining('0:00'), findsNothing);
    expect(find.textContaining('Süre doldu'), findsOneWidget);
  });

  testWidgets('Ertelenince saat ve kalan hak gosterilir', (tester) async {
    await tester.pumpWidget(
      build(
        snoozedUntil: DateTime(2026, 8, 17, 23, 45),
        snoozeRemaining: 2,
        onSnooze: () {},
      ),
    );
    expect(find.textContaining('23:45'), findsWidgets);
    expect(find.textContaining('2 erteleme hakkın kaldı'), findsOneWidget);
    expect(find.byKey(kMissionSnoozedOkKey), findsOneWidget);
    // Ertelenmis durumda gorev govdesi ve diger eylemler gorunmez.
    expect(find.text('gorev govdesi'), findsNothing);
    expect(find.byKey(kMissionSnoozeKey), findsNothing);
    expect(find.byKey(kMissionAbortKey), findsNothing);
  });

  testWidgets('Hak bitmisse erteleme ekrani bunu soyler', (tester) async {
    await tester.pumpWidget(
      build(snoozedUntil: DateTime(2026, 8, 17, 23, 45), snoozeRemaining: 0),
    );
    expect(find.textContaining('hakkın kalmadı'), findsOneWidget);
  });
}
