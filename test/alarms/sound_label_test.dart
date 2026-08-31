import 'package:ezanvakti/presentation/utils/alarm_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default ve taninmayan degerler Varsayilan gosterilir', () {
    // 0.5.1 oncesinden kalan 'adhan'/'alarm' gibi degerler "Ozel ses" diye
    // gorunuyordu; gercekte sistem varsayilani caliyordu.
    expect(soundLabelFor('default', null), 'Varsayılan');
    expect(soundLabelFor('adhan', null), 'Varsayılan');
    expect(soundLabelFor('', null), 'Varsayılan');
  });

  test('ozel ses dosya adiyla gosterilir', () {
    expect(soundLabelFor('custom:ezan.caf', 'ezan.caf'), 'ezan.caf');
    expect(soundLabelFor('custom:ezan.caf', null), 'Özel ses');
  });
}
