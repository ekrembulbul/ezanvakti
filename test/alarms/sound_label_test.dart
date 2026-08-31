import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:ezanvakti/presentation/utils/alarm_labels.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/l10n_helper.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async => l10n = await loadTestL10n());

  test('default ve taninmayan degerler Varsayilan gosterilir', () {
    // 0.5.1 oncesinden kalan 'adhan'/'alarm' gibi degerler "Ozel ses" diye
    // gorunuyordu; gercekte sistem varsayilani caliyordu.
    expect(soundLabelFor('default', null, l10n), 'Varsayılan');
    expect(soundLabelFor('adhan', null, l10n), 'Varsayılan');
    expect(soundLabelFor('', null, l10n), 'Varsayılan');
  });

  test('ozel ses dosya adiyla gosterilir', () {
    expect(soundLabelFor('custom:ezan.caf', 'ezan.caf', l10n), 'ezan.caf');
    expect(soundLabelFor('custom:ezan.caf', null, l10n), 'Özel ses');
  });
}
