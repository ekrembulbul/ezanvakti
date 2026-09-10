import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
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
    expect(find.text('Sahur'), findsOneWidget);
    expect(find.text('Her gün'), findsOneWidget);
    // SectionLabel metni kendisi buyutur.
    expect(find.text('1 ALARM'), findsOneWidget);
  });

  testWidgets(
    'Çıpalı alarm etiketi üstte, kural ve sonraki zamanı aynı satırda gösterir',
    (tester) async {
      const alarm = Alarm(
        id: 'sunrise',
        kind: AlarmKind.anchored,
        label: 'Güne hazırlık',
        anchor: PrayerType.sunrise,
        offsetMinutes: -30,
        weekdays: {1, 2, 3, 4, 5},
        mission: AlarmMission.math,
      );
      await tester.pumpWidget(
        wrapWithTheme(
          AlarmsSection(
            alarms: const [alarm],
            isSupported: true,
            isPermissionGranted: true,
            onRequestPermission: () {},
            onToggle: (_, _) {},
            onEdit: (_) {},
            onDelete: (_) async {},
            now: DateTime(2026, 9, 6, 18),
            nextFireByAlarm: {'sunrise': DateTime(2026, 9, 7, 6, 17)},
          ),
        ),
      );
      final days = find.text('Hafta içi');
      final schedule = find.text('Güneş · 30 dk önce');
      final label = find.text('Güne hazırlık');
      // Sonraki zaman ve kalan süre tek satırda, etiketin altında.
      final details = find.text('yarın 06:17 · 12 sa 17 dk');
      expect(days, findsOneWidget);
      expect(schedule, findsOneWidget);
      expect(label, findsOneWidget);
      expect(details, findsOneWidget);
      expect(find.byIcon(Icons.calculate_rounded), findsOneWidget);
      expect(
        tester.getTopLeft(days).dy,
        lessThan(tester.getTopLeft(schedule).dy),
      );
      expect(
        tester.getTopLeft(schedule).dy,
        lessThan(tester.getTopLeft(label).dy),
      );
      expect(
        tester.getTopLeft(label).dy,
        lessThan(tester.getTopLeft(details).dy),
      );
    },
  );

  testWidgets('Uzun etiket kurulamadı durumunu görünmez yapmaz', (
    tester,
  ) async {
    const alarm = Alarm(
      id: 'failed',
      kind: AlarmKind.fixed,
      label:
          'Bu çok uzun alarm etiketi yalnızca ayrılmış etiket alanında kısalmalı',
      hour: 7,
      minute: 15,
    );
    await tester.pumpWidget(
      wrapWithTheme(
        SizedBox(
          width: 320,
          child: AlarmsSection(
            alarms: const [alarm],
            isSupported: true,
            isPermissionGranted: true,
            onRequestPermission: () {},
            onToggle: (_, _) {},
            onEdit: (_) {},
            onDelete: (_) async {},
            scheduleFailures: const {'failed': 'failed'},
          ),
        ),
      ),
    );

    expect(
      find.text('Kurulamadı — düzenleyip kaydederek yeniden dene'),
      findsOneWidget,
    );
  });

  for (final example in [
    (mission: AlarmMission.none, icon: null),
    (mission: AlarmMission.math, icon: Icons.calculate_rounded),
    (mission: AlarmMission.shake, icon: Icons.vibration_rounded),
    (mission: AlarmMission.qr, icon: Icons.qr_code_scanner_rounded),
  ]) {
    testWidgets('${example.mission.name} doğru görev ikonunu gösterir', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(alarms: [sahur.copyWith(mission: example.mission)]),
      );

      if (example.icon == null) {
        expect(find.byIcon(Icons.calculate_rounded), findsNothing);
        expect(find.byIcon(Icons.vibration_rounded), findsNothing);
        expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
      } else {
        expect(find.byIcon(example.icon!), findsOneWidget);
      }
    });
  }

  testWidgets('Liste bossa bos durum cizilir', (tester) async {
    await tester.pumpWidget(build(alarms: const []));

    expect(find.text('Henüz alarm yok'), findsOneWidget);
  });

  testWidgets('Desteklenmiyorsa bilgi karti cizilir, liste cizilmez', (
    tester,
  ) async {
    await tester.pumpWidget(build(isSupported: false));

    // Ayrintili davranis: alarms_section_unsupported_test.dart
    expect(find.textContaining('26.1'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('Izin yoksa izin uyarisi cizilir', (tester) async {
    await tester.pumpWidget(build(isPermissionGranted: false));

    expect(
      find.text('Alarmların çalması için izin gerekiyor.'),
      findsOneWidget,
    );
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
