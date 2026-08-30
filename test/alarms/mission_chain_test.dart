import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/features/alarms/domain/mission_chain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fired = DateTime(2026, 8, 17, 5, 0);

  ChainState state({int rearmCount = 0, Duration? deadlineIn}) => ChainState(
    rearmCount: rearmCount,
    chainDeadline: MissionChain.chainDeadline(fired),
    deadline: fired.add(deadlineIn ?? const Duration(seconds: 20)),
  );

  group('MissionChain.decide', () {
    test('Sinirlar dolmadiysa yeniden kurar', () {
      expect(
        MissionChain.decide(state: state(), now: fired),
        ChainDecision.rearm,
      );
    });

    test('Tekrar tavani dolduysa durur', () {
      expect(
        MissionChain.decide(
          state: state(rearmCount: MissionTuning.maxRearms),
          now: fired,
        ),
        ChainDecision.stop,
      );
    });

    test('Sure tavani dolduysa durur', () {
      final late = fired.add(
        const Duration(minutes: MissionTuning.chainDeadlineMinutes + 1),
      );
      expect(MissionChain.decide(state: state(), now: late), ChainDecision.stop);
    });

    test('Sure tavani tam sinirda durur', () {
      final exactly = MissionChain.chainDeadline(fired);
      expect(
        MissionChain.decide(state: state(), now: exactly),
        ChainDecision.stop,
      );
    });
  });

  group('Son tarih hesabi', () {
    test('Durdurma sonrasi grace kadar', () {
      expect(
        MissionChain.deadlineAfterStop(fired),
        fired.add(const Duration(seconds: MissionTuning.graceSeconds)),
      );
    });

    test('Gorev ekrani acilinca gorev suresi kadar', () {
      expect(
        MissionChain.deadlineAfterBegin(now: fired, mission: AlarmMission.math),
        fired.add(
          Duration(
            seconds: MissionTuning.timeoutSecondsFor(AlarmMission.math),
          ),
        ),
      );
    });

    /// Daha uzun gorev -> daha uzak son tarih. QR ile matematik artik esit
    /// (90 sn, kullanici karari); ayrim sallama (60) ile matematik arasinda.
    test('Uzun gorevin son tarihi daha uzak', () {
      final shake = MissionChain.deadlineAfterBegin(
        now: fired,
        mission: AlarmMission.shake,
      );
      final math = MissionChain.deadlineAfterBegin(
        now: fired,
        mission: AlarmMission.math,
      );
      expect(math.isAfter(shake), isTrue);
    });
  });

  group('Saglama merdiveni', () {
    test('Basamak sayisi ve araliklar sabitlerden gelir', () {
      final steps = MissionChain.ladder(fired);
      expect(steps, hasLength(MissionTuning.ladderCount));
      expect(
        steps.first,
        fired.add(const Duration(minutes: MissionTuning.ladderStepMinutes)),
      );
      expect(
        steps.last,
        fired.add(
          const Duration(
            minutes:
                MissionTuning.ladderStepMinutes * MissionTuning.ladderCount,
          ),
        ),
      );
    });

    test('Basamaklar artan sirada', () {
      final steps = MissionChain.ladder(fired);
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i].isAfter(steps[i - 1]), isTrue);
      }
    });
  });

  group('watchdogId', () {
    test('Ana id ile cakismaz ve indeksle ayrisir', () {
      expect(MissionChain.watchdogId('sahur', 1), 'sahur#w1');
      expect(MissionChain.watchdogId('sahur', 2), isNot('sahur#w1'));
      expect(MissionChain.watchdogId('sahur', 1), isNot('sahur'));
    });
  });
}
