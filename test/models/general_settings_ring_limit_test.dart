import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alarm calma suresi varsayilan 10, bozuk deger varsayilana duser', () {
    expect(const GeneralSettings().alarmRingLimitMinutes, 10);
    expect(
      GeneralSettings.fromMap({
        GeneralSettings.alarmRingLimitKey: '0',
      }).alarmRingLimitMinutes,
      0,
    );
    expect(
      GeneralSettings.fromMap({
        GeneralSettings.alarmRingLimitKey: '7',
      }).alarmRingLimitMinutes,
      10,
    );
    expect(
      GeneralSettings.fromMap(
        const GeneralSettings(alarmRingLimitMinutes: 30).toMap(),
      ).alarmRingLimitMinutes,
      30,
    );
  });

  test('calma suresi esitlige ve copyWith zincirine katilir', () {
    const base = GeneralSettings();
    expect(base.copyWith(alarmRingLimitMinutes: 15).alarmRingLimitMinutes, 15);
    expect(base.copyWith(alarmRingLimitMinutes: 15), isNot(base));
    expect(base.copyWith(ramadanMode: false).alarmRingLimitMinutes, 10);
  });
}
