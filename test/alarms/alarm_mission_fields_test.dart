import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Alarm gorev alanlari', () {
    test('Varsayilan gorevsiz ve sinirsiz erteleme', () {
      const a = Alarm(id: 'a', kind: AlarmKind.fixed);
      expect(a.mission, AlarmMission.none);
      expect(a.missionLevel, 1);
      expect(a.maxSnoozes, isNull);
    });

    test('toMap/fromMap gorev alanlarini korur', () {
      const a = Alarm(
        id: 'a',
        kind: AlarmKind.fixed,
        mission: AlarmMission.math,
        missionLevel: 3,
        maxSnoozes: 2,
      );
      final round = Alarm.fromMap(a.toMap());
      expect(round.mission, AlarmMission.math);
      expect(round.missionLevel, 3);
      expect(round.maxSnoozes, 2);
      expect(round, a);
    });

    test('Eski kayit (gorev kolonlari yok) gorevsiz okunur', () {
      // v6 semasindan gelen satir: yeni kolonlar hic yok.
      final map = <String, dynamic>{
        'id': 'eski',
        'kind': 'fixed',
        'label': '',
        'is_active': 1,
        'hour': 5,
        'minute': 0,
        'anchor': 'fajr',
        'offset_minutes': 0,
        'weekdays': '',
        'sound_id': 'adhan',
        'vibrate': 1,
        'snooze_enabled': 1,
        'snooze_minutes': 5,
      };
      final a = Alarm.fromMap(map);
      expect(a.mission, AlarmMission.none);
      expect(a.missionLevel, 1);
      expect(a.maxSnoozes, isNull);
    });

    test('Bilinmeyen gorev adi gorevsize duser', () {
      const a = Alarm(id: 'a', kind: AlarmKind.fixed);
      final map = a.toMap()..['mission'] = 'telekinezi';
      expect(Alarm.fromMap(map).mission, AlarmMission.none);
    });

    test('copyWith maxSnoozes null verirse mevcut deger korunur', () {
      // Dart'ta null "degistirme" ile "temizle" ayirt edilemez; dokumante
      // edilmis davranis: null = dokunma.
      const a = Alarm(id: 'a', kind: AlarmKind.fixed, maxSnoozes: 3);
      expect(a.copyWith().maxSnoozes, 3);
      expect(a.copyWith(maxSnoozes: 1).maxSnoozes, 1);
    });
  });
}
