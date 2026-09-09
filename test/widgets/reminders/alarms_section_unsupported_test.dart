import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/presentation/widgets/common/info_banner.dart';
import 'package:ezanvakti/presentation/widgets/reminders/alarms_section.dart';
import 'package:ezanvakti/presentation/widgets/reminders/reminder_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

/// iOS 26.1 altinda AlarmKit yok. Alarm kurdurup calmamasi yerine bolum
/// kapali: yalniz bilgi karti, veri korunur.
void main() {
  const sahur = Alarm(id: 'sahur', kind: AlarmKind.fixed, hour: 5, minute: 0);
  const ogle = Alarm(id: 'ogle', kind: AlarmKind.fixed, hour: 13, minute: 0);

  Widget build({List<Alarm> alarms = const [], bool isSupported = false}) =>
      wrapWithTheme(
        AlarmsSection(
          alarms: alarms,
          isSupported: isSupported,
          isPermissionGranted: true,
          onRequestPermission: () {},
          onToggle: (a, b) {},
          onEdit: (_) {},
          onDelete: (_) async {},
          nextFireByAlarm: const {},
          skips: const {},
        ),
      );

  testWidgets('Destek yokken yalniz bilgi karti: liste ve anahtar yok', (
    tester,
  ) async {
    await tester.pumpWidget(build(alarms: const [sahur, ogle]));

    expect(find.byType(InfoBanner), findsOneWidget);
    expect(find.textContaining('26.1'), findsOneWidget);
    expect(find.byType(ReminderList), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('05:00'), findsNothing);
  });

  testWidgets('Destek yokken kayitli alarm sayisi soylenir', (tester) async {
    await tester.pumpWidget(build(alarms: const [sahur, ogle]));

    expect(find.text('2 kayıtlı alarm korunuyor.'), findsOneWidget);
  });

  testWidgets('Destek yok ve kayit yoksa sayi satiri cizilmez', (tester) async {
    await tester.pumpWidget(build());

    expect(find.byType(InfoBanner), findsOneWidget);
    expect(find.textContaining('korunuyor'), findsNothing);
  });

  testWidgets('Destek varken liste ve anahtar gorunur', (tester) async {
    await tester.pumpWidget(build(alarms: const [sahur], isSupported: true));

    expect(find.byType(ReminderList), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.textContaining('26.1'), findsNothing);
  });
}
