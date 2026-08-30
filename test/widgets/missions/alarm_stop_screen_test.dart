import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/notification_setting.dart'
    show PrayerType;
import 'package:ezanvakti/presentation/screens/alarm_stop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  final firedAt = DateTime(2026, 8, 30, 8, 45);
  final stoppedAt = firedAt.add(const Duration(seconds: 30));
  final now = stoppedAt.add(const Duration(seconds: 7));

  const plain = Alarm(
    id: 'is',
    kind: AlarmKind.fixed,
    hour: 8,
    minute: 45,
    label: 'İş',
    snoozeEnabled: true,
    snoozeMinutes: 10,
    maxSnoozes: 1,
  );
  const gated = Alarm(
    id: 'sabah',
    kind: AlarmKind.anchored,
    anchor: PrayerType.sunrise,
    offsetMinutes: -60,
    label: 'Sabah Namazı',
    mission: AlarmMission.qr,
    missionLevel: 2,
    snoozeEnabled: true,
    snoozeMinutes: 10,
    maxSnoozes: 2,
  );

  Future<void> pump(
    WidgetTester tester, {
    required Alarm alarm,
    required bool gated,
    int remainingSeconds = 38,
    int? snoozeRemaining = 1,
    VoidCallback? onPrimary,
    VoidCallback? onSnooze,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        AlarmStopScreen(
          alarm: alarm,
          gated: gated,
          remainingSeconds: remainingSeconds,
          snoozeRemaining: snoozeRemaining,
          firedAt: firedAt,
          stoppedAt: stoppedAt,
          now: now,
          onPrimary: onPrimary ?? () {},
          onSnooze: onSnooze,
        ),
      ),
    );
  }

  testWidgets('gorevsiz: Tamam birincil, Ertele sure ve hak ile', (
    tester,
  ) async {
    await pump(tester, alarm: plain, gated: false, onSnooze: () {});

    expect(find.text('Tamam'), findsOneWidget);
    expect(find.text('Ertele · 10 dk'), findsOneWidget);
    expect(find.text('1 hak kaldı'), findsOneWidget);
    expect(find.textContaining('Dokunmazsan'), findsOneWidget);
    expect(find.text('İş'), findsOneWidget);
    expect(find.text('08:45'), findsOneWidget);
    expect(find.textContaining('Her gün'), findsOneWidget);
  });

  testWidgets('gorevli: Gorevi yap birincil, gorev karti ve uyari', (
    tester,
  ) async {
    await pump(tester, alarm: gated, gated: true, onSnooze: () {});

    expect(find.text('Görevi yap'), findsOneWidget);
    expect(find.text('Ertele · 10 dk'), findsOneWidget);
    expect(find.textContaining('QR okutma'), findsOneWidget);
    expect(find.textContaining('90 sn'), findsOneWidget);
    expect(find.textContaining('alarm'), findsWidgets);
    expect(find.textContaining('Güneş −60 dk'), findsOneWidget);
    expect(find.text('Sabah Namazı'), findsOneWidget);
  });

  testWidgets('sinirsiz ertelemede hak satiri yok', (tester) async {
    await pump(
      tester,
      alarm: plain,
      gated: false,
      snoozeRemaining: null,
      onSnooze: () {},
    );
    expect(find.textContaining('hak'), findsNothing);
    expect(find.byKey(kStopSnoozeKey), findsOneWidget);
  });

  testWidgets('onSnooze yoksa Ertele cizilmez', (tester) async {
    await pump(tester, alarm: plain, gated: false, onSnooze: null);
    expect(find.byKey(kStopSnoozeKey), findsNothing);
  });

  testWidgets('geri sayim m:ss biciminde', (tester) async {
    await pump(tester, alarm: plain, gated: false, remainingSeconds: 38);
    expect(find.byKey(kStopCountdownKey), findsOneWidget);
    expect(find.textContaining('0:38'), findsOneWidget);
  });

  testWidgets('dugmeler geri cagrilari tetikler', (tester) async {
    var primary = 0;
    var snooze = 0;
    await pump(
      tester,
      alarm: plain,
      gated: false,
      onPrimary: () => primary++,
      onSnooze: () => snooze++,
    );

    await tester.tap(find.byKey(kStopPrimaryKey));
    await tester.tap(find.byKey(kStopSnoozeKey));
    expect(primary, 1);
    expect(snooze, 1);
  });

  testWidgets('kac dakika once durduruldugu yazar', (tester) async {
    await pump(tester, alarm: plain, gated: false);
    expect(find.textContaining('az önce'), findsOneWidget);
  });
}
