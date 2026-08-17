import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlarmMission', () {
    test('none disinda hepsi kapi ister', () {
      expect(AlarmMission.none.requiresGate, isFalse);
      expect(AlarmMission.math.requiresGate, isTrue);
      expect(AlarmMission.shake.requiresGate, isTrue);
      expect(AlarmMission.qr.requiresGate, isTrue);
    });
  });

  group('MissionTuning', () {
    test('QR suresi matematikten uzun', () {
      // Kodun bulundugu yere yurumek gerekiyor; spec D13.
      expect(
        MissionTuning.timeoutSecondsFor(AlarmMission.qr),
        greaterThan(MissionTuning.timeoutSecondsFor(AlarmMission.math)),
      );
    });

    test('Her gorev tipi icin pozitif sure tanimli', () {
      for (final m in AlarmMission.values.where((m) => m.requiresGate)) {
        expect(MissionTuning.timeoutSecondsFor(m), greaterThan(0));
      }
    });

    test('none icin sure sorulmaz, sifir doner', () {
      expect(MissionTuning.timeoutSecondsFor(AlarmMission.none), 0);
    });

    test('Acil cikis tavani en az bir kademe birakir', () {
      expect(MissionTuning.abortMaxLevel, greaterThanOrEqualTo(1));
    });
  });
}
