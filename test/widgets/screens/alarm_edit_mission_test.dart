import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/features/alarms/domain/snooze_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Gorev ve erteleme kurallari', () {
    test('erteleme kapatılınca QR içeriği korunur', () {
      const alarm = Alarm(
        id: 'qr',
        kind: AlarmKind.fixed,
        mission: AlarmMission.qr,
        qrPayload: 'test-code',
        snoozeEnabled: false,
        maxSnoozes: 3,
      );
      expect(normalizeAlarmSnoozeLimit(alarm).qrPayload, 'test-code');
    });
    test('Gorev acikken sinirsiz erteleme kaydedilemez', () {
      // Gorev acikken Sinirsiz listelenmez; kayitta da en buyuk sonlu
      // secenege duser.
      const a = Alarm(
        id: 'a',
        kind: AlarmKind.fixed,
        mission: AlarmMission.math,
        maxSnoozes: null,
      );
      final normalized = normalizeAlarmSnoozeLimit(a);
      expect(normalized.maxSnoozes, kMaxSnoozeOptions.last);
    });

    test('Gorev kapaliyken sinirsiz korunur', () {
      const a = Alarm(id: 'a', kind: AlarmKind.fixed, maxSnoozes: null);
      expect(normalizeAlarmSnoozeLimit(a).maxSnoozes, isNull);
    });

    test('Erteleme kapaliysa limit yok sayilir', () {
      const a = Alarm(
        id: 'a',
        kind: AlarmKind.fixed,
        mission: AlarmMission.math,
        snoozeEnabled: false,
        maxSnoozes: 3,
      );
      expect(normalizeAlarmSnoozeLimit(a).maxSnoozes, isNull);
    });

    test('Secenek listeleri kapali ve artan', () {
      expect(kSnoozeMinuteOptions, [5, 10, 15, 20]);
      expect(kMaxSnoozeOptions, [1, 2, 3, 5]);
    });
  });
}
