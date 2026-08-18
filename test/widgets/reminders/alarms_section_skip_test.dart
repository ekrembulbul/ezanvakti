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

  testWidgets('Satirda tek seferlik atlama eylemi gorunur', (tester) async {
    await tester.pumpWidget(build());
    expect(find.text('Bu seferi atla'), findsOneWidget);
  });

  testWidgets('Atlama eylemi dogru occurrence ile bildirir', (tester) async {
    SkippedOccurrence? seen;
    var value = false;
    await tester.pumpWidget(
      build(
        onSkipChanged: (o, s) {
          seen = o;
          value = s;
        },
      ),
    );
    await tester.tap(find.text('Bu seferi atla'));
    await tester.pump();

    expect(seen?.reference, 'ogle');
    expect(seen?.kind, SkipKind.alarm);
    expect(seen?.fireAt, fireAt);
    expect(value, isTrue);
  });

  testWidgets('Atlanmissa metin ve eylem tersine doner', (tester) async {
    await tester.pumpWidget(
      build(
        skips: {
          SkippedOccurrence(
            kind: SkipKind.alarm,
            reference: 'ogle',
            fireAt: fireAt,
          ),
        },
      ),
    );
    expect(find.text('Yalnızca bu sefer atlanacak'), findsOneWidget);
    expect(find.text('Geri al'), findsOneWidget);
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
    expect(find.text('Bu seferi atla'), findsNothing);
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
