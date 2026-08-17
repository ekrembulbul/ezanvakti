import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/alarm_theme.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/features/alarms/data/native_alarm_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.ekrembulbul.ezanvakti/alarm');
  final calls = <MethodCall>[];

  setUp(() {
    // NativeAlarmService yalnizca mobil hedefte channel'a gidiyor.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'consumeMissionEvents') {
            return [
              {'alarmId': 'sahur', 'stoppedAt': 1786883326000},
            ];
          }
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final theme = AlarmTheme.forPalette(DayPhase.night, Brightness.dark);

  test(
    'scheduleAlarm gorev alanlarini ve zincir yapilandirmasini gecirir',
    () async {
      await NativeAlarmService().scheduleAlarm(
        id: 'sahur',
        scheduledTime: DateTime.fromMillisecondsSinceEpoch(1786883326000),
        label: 'Sahur',
        soundId: 'adhan',
        vibrate: true,
        snoozeEnabled: true,
        snoozeMinutes: 5,
        theme: theme,
        mission: AlarmMission.math,
        missionLevel: 2,
        chainConfig: const {'graceSeconds': 20},
      );

      final args = calls.single.arguments as Map;
      expect(calls.single.method, 'scheduleAlarm');
      expect(args['mission'], 'math');
      expect(args['missionLevel'], 2);
      expect(args['missionEnabled'], isTrue);
      expect((args['chainConfig'] as Map)['graceSeconds'], 20);
    },
  );

  test('Gorevsiz alarmda missionEnabled false', () async {
    await NativeAlarmService().scheduleAlarm(
      id: 'ogle',
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(1786883326000),
      label: '',
      soundId: 'adhan',
      vibrate: true,
      snoozeEnabled: true,
      snoozeMinutes: 5,
      theme: theme,
      mission: AlarmMission.none,
      missionLevel: 1,
      chainConfig: const {},
    );

    final args = calls.single.arguments as Map;
    expect(args['missionEnabled'], isFalse);
  });

  test('consumeMissionEvents olaylari cozer', () async {
    final events = await NativeAlarmService().consumeMissionEvents();
    expect(events, hasLength(1));
    expect(events.single.alarmId, 'sahur');
    expect(
      events.single.stoppedAt,
      DateTime.fromMillisecondsSinceEpoch(1786883326000),
    );
  });

  test('Gorev yasam dongusu method adlari', () async {
    final s = NativeAlarmService();
    await s.beginMission('sahur');
    await s.completeMission('sahur');
    await s.abortMission('sahur');
    expect(calls.map((c) => c.method), [
      'beginMission',
      'completeMission',
      'abortMission',
    ]);
    expect((calls.first.arguments as Map)['id'], 'sahur');
  });
}
