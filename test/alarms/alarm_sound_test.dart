import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/models/alarm.dart';

Map<String, dynamic> _map(String? soundId) => {
  'id': 'a1',
  'kind': AlarmKind.fixed.name,
  'hour': 5,
  'minute': 0,
  'sound_id': ?soundId,
};

void main() {
  group('Alarm ses varsayilani', () {
    test('yeni alarm sistem varsayilan sesini kullanir', () {
      const alarm = Alarm(id: 'a1', kind: AlarmKind.fixed, hour: 5);
      expect(alarm.soundId, 'default');
    });

    /// Projede hic ses dosyasi yok; 'adhan' ve 'alarm' zaten sessizce sistem
    /// varsayilanina dusuyordu (AppDelegate.swift:415-418). Secenekler
    /// kaldirildigi icin kayitli degerler de esleniyor, yoksa secicide
    /// "Ozel ses" diye gorunurlerdi.
    test('kayitli adhan degeri varsayilana eslenir', () {
      expect(Alarm.fromMap(_map('adhan')).soundId, 'default');
    });

    test('kayitli alarm degeri varsayilana eslenir', () {
      expect(Alarm.fromMap(_map('alarm')).soundId, 'default');
    });

    test('sound_id hic yoksa varsayilana duser', () {
      expect(Alarm.fromMap(_map(null)).soundId, 'default');
    });

    test('kullanicinin sectigi ozel ses korunur', () {
      expect(Alarm.fromMap(_map('custom:ezan.caf')).soundId, 'custom:ezan.caf');
    });
  });
}
