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
    test('QR suresi 90 saniye', () {
      // Spec D13 QR'i en uzun tutmustu (yurume payi); cihazda 120 sn fazla
      // uzun geldi, kullanici karariyla 90'a indi -- matematikle esit.
      expect(MissionTuning.timeoutSecondsFor(AlarmMission.qr), 90);
    });

    test('Ara ekran sureleri', () {
      // Spec 2026-08-30 D12, kullanici karari: 20 sn okuyup basmak icin dar.
      expect(MissionTuning.graceSeconds, 30);
      expect(MissionTuning.stopScreenSeconds, 45);
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
