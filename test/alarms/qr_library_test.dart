import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/features/alarms/domain/qr_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const qrAlarm = Alarm(
    id: 'a1',
    kind: AlarmKind.fixed,
    hour: 6,
    label: 'Sahur',
    mission: AlarmMission.qr,
    qrPayload: 'KOD-1',
  );
  const otherQr = Alarm(
    id: 'a2',
    kind: AlarmKind.anchored,
    anchor: PrayerType.fajr,
    mission: AlarmMission.qr,
    qrPayload: 'KOD-2',
  );
  const mathAlarm = Alarm(
    id: 'a3',
    kind: AlarmKind.fixed,
    hour: 7,
    mission: AlarmMission.math,
    qrPayload: 'KOD-1', // gorev QR degil: kod pasif kopya, kullanim sayilmaz
  );

  test('kodu kullanan QR gorevli alarmlarin etiketleri doner', () {
    expect(alarmsUsingQrPayload([qrAlarm, otherQr, mathAlarm], 'KOD-1'), [
      'Sahur',
    ]);
  });

  test('etiketsiz alarm generik adla doner, kullanilmayan kod bos doner', () {
    expect(alarmsUsingQrPayload([otherQr], 'KOD-2'), ['Alarm']);
    expect(alarmsUsingQrPayload([qrAlarm, otherQr], 'KOD-9'), isEmpty);
  });
}
