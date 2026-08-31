import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/features/alarms/domain/stop_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final stoppedAt = DateTime(2026, 8, 30, 8, 45);
  final now = stoppedAt.add(const Duration(seconds: 5));

  const plain = Alarm(
    id: 'is',
    kind: AlarmKind.fixed,
    hour: 8,
    minute: 45,
    snoozeEnabled: true,
    snoozeMinutes: 10,
    maxSnoozes: 1,
  );
  const plainUnlimited = Alarm(
    id: 'is',
    kind: AlarmKind.fixed,
    hour: 8,
    snoozeEnabled: true,
  );
  const plainNoSnooze = Alarm(
    id: 'is',
    kind: AlarmKind.fixed,
    hour: 8,
    snoozeEnabled: false,
  );
  const gated = Alarm(
    id: 'sahur',
    kind: AlarmKind.fixed,
    hour: 5,
    mission: AlarmMission.qr,
    snoozeEnabled: true,
    maxSnoozes: 1,
  );

  MissionSession session({int snoozeUsed = 0, DateTime? snoozedUntil}) =>
      MissionSession(
        alarmId: 'x',
        firedAt: stoppedAt,
        snoozeUsed: snoozeUsed,
        snoozedUntil: snoozedUntil,
      );

  group('StopGate.decide', () {
    test('ertelenmis ve suresi dolmamis oturumda hicbir sey', () {
      expect(
        StopGate.decide(
          alarm: plain,
          session: session(snoozedUntil: now.add(const Duration(minutes: 3))),
          now: now,
        ),
        StopDecision.none,
      );
    });

    test('alarm silinmisse kapat ve yeniden kur', () {
      expect(
        StopGate.decide(alarm: null, session: session(), now: now),
        StopDecision.closeAndRearm,
      );
    });

    test('gorevsiz, erteleme kapali: kapat', () {
      expect(
        StopGate.decide(alarm: plainNoSnooze, session: session(), now: now),
        StopDecision.closeAndRearm,
      );
    });

    test('gorevsiz, bayat: kapat, ekran yok', () {
      final stale = stoppedAt.add(
        const Duration(seconds: MissionTuning.stopScreenSeconds + 1),
      );
      expect(
        StopGate.decide(alarm: plain, session: session(), now: stale),
        StopDecision.closeAndRearm,
      );
    });

    test('gorevsiz, sinirda taze: ekran', () {
      final edge = stoppedAt.add(
        const Duration(seconds: MissionTuning.stopScreenSeconds - 1),
      );
      expect(
        StopGate.decide(alarm: plain, session: session(), now: edge),
        StopDecision.showStopScreen,
      );
    });

    test('gorevsiz, taze, hak var: ekran', () {
      expect(
        StopGate.decide(alarm: plain, session: session(), now: now),
        StopDecision.showStopScreen,
      );
    });

    test('gorevsiz, taze, hak yok: kapat', () {
      expect(
        StopGate.decide(
          alarm: plain,
          session: session(snoozeUsed: 1),
          now: now,
        ),
        StopDecision.closeAndRearm,
      );
    });

    test('gorevsiz, sinirsiz erteleme: ekran', () {
      expect(
        StopGate.decide(
          alarm: plainUnlimited,
          session: session(snoozeUsed: 9),
          now: now,
        ),
        StopDecision.showStopScreen,
      );
    });

    test('gorevli, hak yok: dogrudan gorev', () {
      expect(
        StopGate.decide(
          alarm: gated,
          session: session(snoozeUsed: 1),
          now: now,
        ),
        StopDecision.openMission,
      );
    });

    test('gorevli, hak var: ekran', () {
      expect(
        StopGate.decide(alarm: gated, session: session(), now: now),
        StopDecision.showStopScreen,
      );
    });

    /// Zincir tavani (60 dk) icindeki eski oturum hala borctur.
    test('gorevli, eski ama tavan icindeki oturum yine acilir', () {
      final late = stoppedAt.add(const Duration(minutes: 20));
      expect(
        StopGate.decide(alarm: gated, session: session(), now: late),
        StopDecision.showStopScreen,
      );
    });

    /// Dunku oturum bugunku acilista ekran acmamali: 31 Agustos olayi.
    test('gorevli, tavani asan bayat oturum kapatilir', () {
      final stale = stoppedAt.add(
        const Duration(minutes: MissionTuning.chainDeadlineMinutes + 1),
      );
      expect(
        StopGate.decide(alarm: gated, session: session(), now: stale),
        StopDecision.closeAndRearm,
      );
    });

    test('gorevli, tavana bir dakika kala bayat sayilmaz', () {
      final fresh = stoppedAt.add(
        const Duration(minutes: MissionTuning.chainDeadlineMinutes - 1),
      );
      expect(
        StopGate.decide(alarm: gated, session: session(), now: fresh),
        isNot(StopDecision.closeAndRearm),
      );
    });
  });

  group('StopGate.snoozeRemaining', () {
    test('erteleme kapaliysa sifir', () {
      expect(StopGate.snoozeRemaining(plainNoSnooze, session()), 0);
    });

    test('sinirsizsa null', () {
      expect(
        StopGate.snoozeRemaining(plainUnlimited, session(snoozeUsed: 3)),
        isNull,
      );
    });

    test('kalan hak, eksiye dusmez', () {
      expect(StopGate.snoozeRemaining(plain, session()), 1);
      expect(StopGate.snoozeRemaining(plain, session(snoozeUsed: 5)), 0);
    });
  });
}
