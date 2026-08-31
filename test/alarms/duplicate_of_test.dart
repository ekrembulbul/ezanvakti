import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/features/alarms/domain/alarms_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = Alarm(
    id: 's1',
    kind: AlarmKind.fixed,
    hour: 5,
    minute: 30,
    label: 'Sahur',
    isActive: false,
    weekdays: {1, 5},
    soundId: 'custom:ezan.caf',
    mission: AlarmMission.qr,
    qrPayload: 'KOD-1',
    maxSnoozes: 2,
  );

  test('duplicateOf yeni id ve "(kopya)" etiketiyle birebir kopyalar', () {
    final copy = duplicateOf(source, newId: 'n1');
    expect(copy.id, 'n1');
    expect(copy.label, 'Sahur (kopya)');
    expect(copy.isActive, isTrue, reason: 'kopya acik baslar');
    expect(copy.hour, source.hour);
    expect(copy.minute, source.minute);
    expect(copy.weekdays, source.weekdays);
    expect(copy.soundId, source.soundId);
    expect(copy.mission, source.mission);
    expect(copy.qrPayload, source.qrPayload);
    expect(copy.maxSnoozes, source.maxSnoozes);
  });

  test('etiketsiz kaynakta kopya etiketi bos kalir', () {
    const plain = Alarm(id: 's2', kind: AlarmKind.fixed, hour: 8);
    expect(duplicateOf(plain, newId: 'n2').label, '');
  });
}
