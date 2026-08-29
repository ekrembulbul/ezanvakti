import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/presentation/widgets/reminders/alarms_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  const plain = Alarm(id: 'ogle', kind: AlarmKind.fixed, hour: 13, minute: 0);
  const gated = Alarm(
    id: 'sahur',
    kind: AlarmKind.fixed,
    hour: 5,
    minute: 0,
    mission: AlarmMission.math,
  );
  final fireAt = DateTime(2026, 8, 19, 5, 0);

  Widget build({
    List<Alarm> alarms = const [plain],
    MissionSession? session,
    Set<SkippedOccurrence> skips = const {},
    void Function(SkippedOccurrence, bool)? onSkipChanged,
    void Function(Alarm)? onDisableBlocked,
    void Function(Alarm, bool)? onToggle,
  }) => wrapWithTheme(
    AlarmsSection(
      alarms: alarms,
      isSupported: true,
      isPermissionGranted: true,
      onRequestPermission: () {},
      onToggle: onToggle ?? (a, b) {},
      onEdit: (_) {},
      onDelete: (_) async {},
      missionSession: session,
      onDisableBlocked: onDisableBlocked,
      nextFireByAlarm: {'ogle': fireAt, 'sahur': fireAt},
      skips: skips,
      onSkipChanged: onSkipChanged ?? (a, b) {},
    ),
  );

  final skipOgle = {
    SkippedOccurrence(kind: SkipKind.alarm, reference: 'ogle', fireAt: fireAt),
  };

  bool switchValue(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch)).value;

  testWidgets('Satirda ayri bir atlama eylemi yok', (tester) async {
    await tester.pumpWidget(build());
    // Atlama artik anahtar kapatilinca alttaki cubuktan seciliyor.
    expect(find.text('Bu seferi atla'), findsNothing);
    expect(switchValue(tester), isTrue);
  });

  testWidgets('Atlanan alarm kapali gorunur', (tester) async {
    await tester.pumpWidget(build(skips: skipOgle));

    expect(find.text('Yalnızca bu sefer atlanacak'), findsOneWidget);
    expect(
      switchValue(tester),
      isFalse,
      reason: 'kullanici icin atlanmis da kapali da "bu sefer calmayacak"',
    );
  });

  testWidgets('Kapali alarmin alt metni "Kapalı"', (tester) async {
    await tester.pumpWidget(
      build(
        alarms: const [
          Alarm(id: 'ogle', kind: AlarmKind.fixed, isActive: false),
        ],
      ),
    );
    expect(find.text('Kapalı'), findsOneWidget);
  });

  testWidgets('Atlanan alarmi acmak atlamayi kaldirir, alarmi acmaz', (
    tester,
  ) async {
    SkippedOccurrence? seen;
    var value = true;
    var toggled = false;
    await tester.pumpWidget(
      build(
        skips: skipOgle,
        onSkipChanged: (o, s) {
          seen = o;
          value = s;
        },
        onToggle: (a, b) => toggled = true,
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(seen?.reference, 'ogle');
    expect(seen?.kind, SkipKind.alarm);
    expect(seen?.fireAt, fireAt);
    expect(value, isFalse, reason: 'atlama kalkiyor');
    expect(
      toggled,
      isFalse,
      reason: 'alarm zaten aktif; ayrica acilmaya calisilmamali',
    );
  });

  testWidgets('Ertelenmis alarmda atlama yerine erteleme bilgisi cikar', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(
        alarms: const [gated],
        session: MissionSession(
          alarmId: 'sahur',
          firedAt: fireAt,
          snoozedUntil: DateTime(2026, 8, 19, 5, 10),
        ),
      ),
    );
    expect(find.textContaining('Ertelendi'), findsOneWidget);
  });

  testWidgets('Ertelenmis gorevli alarm kapatilamaz', (tester) async {
    Alarm? blocked;
    var toggled = false;
    await tester.pumpWidget(
      build(
        alarms: const [gated],
        session: MissionSession(
          alarmId: 'sahur',
          firedAt: fireAt,
          snoozedUntil: DateTime(2026, 8, 19, 5, 10),
        ),
        onDisableBlocked: (a) => blocked = a,
        onToggle: (a, b) => toggled = true,
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(blocked?.id, 'sahur');
    expect(toggled, isFalse);
  });

  testWidgets('Gorevsiz alarm ertelenmis olsa da kapatilabilir', (
    tester,
  ) async {
    var toggled = false;
    await tester.pumpWidget(
      build(
        session: MissionSession(
          alarmId: 'ogle',
          firedAt: fireAt,
          snoozedUntil: DateTime(2026, 8, 19, 13, 10),
        ),
        onToggle: (a, b) => toggled = true,
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(toggled, isTrue);
  });
}
