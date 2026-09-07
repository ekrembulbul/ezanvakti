import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/presentation/services/reminder_list_preferences.dart';
import 'package:ezanvakti/presentation/widgets/reminders/alarms_section.dart';
import 'package:ezanvakti/presentation/widgets/reminders/reminder_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

const _alarms = [
  Alarm(id: 'early', kind: AlarmKind.fixed, hour: 6, label: 'Erken'),
  Alarm(id: 'middle', kind: AlarmKind.fixed, hour: 8, label: 'Orta'),
  Alarm(id: 'late', kind: AlarmKind.fixed, hour: 10, label: 'Geç'),
];

Finder _row(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(ReminderRow));

double _top(WidgetTester tester, String label) =>
    tester.getTopLeft(_row(label)).dy;

Future<void> _toggle(WidgetTester tester, String label) =>
    tester.tap(find.descendant(of: _row(label), matching: find.byType(Switch)));

Future<void> _pumpAlarms(
  WidgetTester tester, {
  bool reduceMotion = false,
  ReminderSortMode sortMode = ReminderSortMode.nextFire,
  void Function(String, bool)? onToggle,
}) async {
  var alarms = _alarms.toList();
  await tester.pumpWidget(
    wrapWithTheme(
      MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduceMotion,
          alwaysUse24HourFormat: true,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            final nextFire = {
              for (final alarm in alarms)
                alarm.id: DateTime(2026, 9, 8, alarm.hour),
            };
            return AlarmsSection(
              alarms: sortReminderItems(
                items: alarms,
                preferences: ReminderListPreferences(sortMode: sortMode),
                idOf: (alarm) => alarm.id,
                nameOf: (alarm) => alarm.label,
                nextFireOf: (alarm) =>
                    alarm.isActive ? nextFire[alarm.id] : null,
              ),
              nextFireByAlarm: nextFire,
              now: DateTime(2026, 9, 8, 4),
              isSupported: true,
              isPermissionGranted: true,
              onRequestPermission: () {},
              onEdit: (_) {},
              onDelete: (_) async {},
              onToggle: (alarm, active) {
                onToggle?.call(alarm.id, active);
                setState(
                  () => alarms = [
                    for (final item in alarms)
                      item.id == alarm.id
                          ? item.copyWith(isActive: active)
                          : item,
                  ],
                );
              },
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kapatılan alarm yeni sırasına atlamadan kayar', (tester) async {
    await _pumpAlarms(tester);
    final start = _top(tester, 'Erken');
    final middleStart = _top(tester, 'Orta');
    final lateStart = _top(tester, 'Geç');

    await _toggle(tester, 'Erken');
    await tester.pump();
    expect(_top(tester, 'Erken'), closeTo(start, 0.5));
    expect(
      tester
          .widget<Switch>(
            find.descendant(of: _row('Erken'), matching: find.byType(Switch)),
          )
          .value,
      isFalse,
    );

    await tester.pump(const Duration(milliseconds: 180));
    final during = _top(tester, 'Erken');
    expect(during, greaterThan(start));
    expect(during, lessThan(lateStart));
    expect(_top(tester, 'Orta'), lessThan(middleStart));
    await tester.pumpAndSettle();
    expect(_top(tester, 'Erken'), greaterThan(_top(tester, 'Geç')));
    expect(_top(tester, 'Orta'), lessThan(_top(tester, 'Geç')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hareket eden alarmın anahtarı aynı alarmı yeniden açar', (
    tester,
  ) async {
    final toggles = <(String, bool)>[];
    await _pumpAlarms(
      tester,
      onToggle: (id, active) => toggles.add((id, active)),
    );
    final start = _top(tester, 'Erken');
    await _toggle(tester, 'Erken');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final movingTop = _top(tester, 'Erken');
    expect(movingTop, greaterThan(start));

    await _toggle(tester, 'Erken');
    await tester.pump();
    expect(_top(tester, 'Erken'), closeTo(movingTop, 0.5));
    await tester.pumpAndSettle();
    expect(toggles, [('early', false), ('early', true)]);
    expect(_top(tester, 'Erken'), closeTo(start, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('özel sıralamada alarm kapatmak sırayı değiştirmez', (
    tester,
  ) async {
    await _pumpAlarms(tester, sortMode: ReminderSortMode.custom);
    final start = _top(tester, 'Erken');
    await _toggle(tester, 'Erken');
    await tester.pumpAndSettle();
    expect(_top(tester, 'Erken'), closeTo(start, 0.5));
    expect(_top(tester, 'Erken'), lessThan(_top(tester, 'Orta')));
  });

  testWidgets('hareket azaltma açıksa alarm sırası animasyonsuz güncellenir', (
    tester,
  ) async {
    await _pumpAlarms(tester, reduceMotion: true);
    await _toggle(tester, 'Erken');
    await tester.pump();
    expect(_top(tester, 'Erken'), greaterThan(_top(tester, 'Geç')));
    expect(tester.takeException(), isNull);
  });
}
