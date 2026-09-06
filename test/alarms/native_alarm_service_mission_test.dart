import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/alarm_theme.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/features/alarms/data/native_alarm_service.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_time_tuner.dart';
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

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final example in [(tune: 0, minute: 0), (tune: 5, minute: 5)]) {
      test(
        '${platform.name}: güneş -30 ve tune ${example.tune} doğru native zamanı üretir',
        () async {
          debugDefaultTargetPlatformOverride = platform;
          final day = DateTime(2026, 9, 6);
          final raw = PrayerTime(
            date: day,
            fajr: DateTime(2026, 9, 6, 5),
            sunrise: DateTime(2026, 9, 6, 6, 30),
            dhuhr: DateTime(2026, 9, 6, 13),
            asr: DateTime(2026, 9, 6, 16, 30),
            maghrib: DateTime(2026, 9, 6, 19, 45),
            isha: DateTime(2026, 9, 6, 21, 15),
          );
          final tuned = PrayerTimeTuner.applyOne(raw, {
            PrayerType.sunrise: example.tune,
          });
          const alarm = Alarm(
            id: 'sunrise',
            kind: AlarmKind.anchored,
            anchor: PrayerType.sunrise,
            offsetMinutes: -30,
          );
          final fire = AlarmScheduler.computeNextFire(
            alarm: alarm,
            now: day,
            prayerTimesByDate: {day: tuned},
          )!;

          await NativeAlarmService().scheduleAlarm(
            id: alarm.id,
            scheduledTime: fire,
            label: alarm.label,
            soundId: alarm.soundId,
            vibrate: alarm.vibrate,
            snoozeEnabled: alarm.snoozeEnabled,
            snoozeMinutes: alarm.snoozeMinutes,
            theme: theme,
            mission: alarm.mission,
            missionLevel: alarm.missionLevel,
            chainConfig: const {},
          );

          final args = calls.single.arguments as Map;
          expect(calls.single.method, 'scheduleAlarm');
          expect(
            args['timeMillis'],
            DateTime(2026, 9, 6, 6, example.minute).millisecondsSinceEpoch,
          );
          expect(tuned.sunrise.difference(fire), const Duration(minutes: 30));
        },
      );
    }
  }

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

  test('Native missionStopped cagrisi dinleyiciye ulasir', () async {
    final service = NativeAlarmService();
    final seen = <String>[];
    final sub = service.missionStops.listen((e) => seen.add(e.alarmId));
    addTearDown(sub.cancel);

    // Native tarafin yaptigi gibi Dart'a dogru bir cagri gonder.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('missionStopped', {
              'alarmId': 'sahur',
              'stoppedAt': 1786883326000,
            }),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);

    expect(seen, ['sahur']);
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
