import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/presentation/widgets/reminders/alarms_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  const sahur = Alarm(
    id: 'sahur',
    kind: AlarmKind.fixed,
    label: 'Sahur',
    hour: 6,
    minute: 30,
  );

  Widget build({
    List<Alarm> alarms = const [sahur],
    bool isSupported = true,
    bool isPermissionGranted = true,
    void Function(Alarm, bool)? onToggle,
  }) => wrapWithTheme(
    AlarmsSection(
      alarms: alarms,
      isSupported: isSupported,
      isPermissionGranted: isPermissionGranted,
      onRequestPermission: () {},
      onToggle: onToggle ?? (_, _) {},
      onEdit: (_) {},
      onDelete: (_) async {},
    ),
  );

  testWidgets('Alarm saati ve alt basligi cizilir', (tester) async {
    await tester.pumpWidget(build());

    expect(find.text('06:30'), findsOneWidget);
    expect(find.text('Sahur · Her gün'), findsOneWidget);
    // SectionLabel metni kendisi buyutur.
    expect(find.text('1 ALARM'), findsOneWidget);
  });

  testWidgets('Liste bossa bos durum cizilir', (tester) async {
    await tester.pumpWidget(build(alarms: const []));

    expect(find.text('Henüz alarm yok'), findsOneWidget);
  });

  testWidgets('Desteklenmiyorsa uyari cizilir', (tester) async {
    await tester.pumpWidget(build(isSupported: false));

    expect(find.textContaining('desteklenmiyor'), findsOneWidget);
  });

  testWidgets('Izin yoksa izin uyarisi cizilir', (tester) async {
    await tester.pumpWidget(build(isPermissionGranted: false));

    expect(find.text('Alarmların çalması için izin gerekiyor.'), findsOneWidget);
    expect(find.text('İzin ver'), findsOneWidget);
  });

  testWidgets('Anahtar onToggle i cagirir', (tester) async {
    Alarm? toggledAlarm;
    bool? toggledValue;
    await tester.pumpWidget(
      build(
        onToggle: (alarm, value) {
          toggledAlarm = alarm;
          toggledValue = value;
        },
      ),
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(toggledAlarm, sahur);
    expect(toggledValue, isFalse);
  });
}
