import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/presentation/widgets/reminders/alarms_section.dart';
import 'package:ezanvakti/presentation/widgets/reminders/reminder_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  for (final locale in [const Locale('tr'), const Locale('ar')]) {
    testWidgets(
      '${locale.languageCode}: two snoozed rows retain their own time at large text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final now = DateTime(2026, 9, 8, 8, 1);
        await tester.pumpWidget(
          wrapWithTheme(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: AlarmsSection(
                alarms: const [
                  Alarm(
                    id: 'a',
                    label: 'A',
                    kind: AlarmKind.fixed,
                    hour: 8,
                    mission: AlarmMission.qr,
                  ),
                  Alarm(
                    id: 'b',
                    label: 'B',
                    kind: AlarmKind.fixed,
                    hour: 8,
                    mission: AlarmMission.qr,
                  ),
                ],
                now: now,
                missionSessions: [
                  MissionSession(
                    alarmId: 'a',
                    firedAt: now.subtract(const Duration(minutes: 1)),
                    snoozedUntil: DateTime(2026, 9, 8, 8, 5),
                  ),
                  MissionSession(
                    alarmId: 'b',
                    firedAt: now.subtract(const Duration(minutes: 1)),
                    snoozedUntil: DateTime(2026, 9, 8, 8, 10),
                  ),
                ],
                isSupported: true,
                isPermissionGranted: true,
                onRequestPermission: () {},
                onToggle: (_, _) {},
                onEdit: (_) {},
                onDelete: (_) async {},
              ),
            ),
            locale: locale,
          ),
        );
        final rows = tester
            .widgetList<ReminderRow>(find.byType(ReminderRow))
            .toList();
        expect(
          rows.singleWhere((r) => r.label == 'A').detail,
          contains('08:05'),
        );
        expect(
          rows.singleWhere((r) => r.label == 'B').detail,
          contains('08:10'),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
