import 'package:ezanvakti/core/services/device_settings_service.dart';
import 'package:ezanvakti/features/alarms/domain/battery_advice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BatteryStatus status({
    String m = 'xiaomi',
    String b = 'redmi',
    bool ignoring = false,
  }) =>
      BatteryStatus(manufacturer: m, brand: b, ignoringOptimizations: ignoring);

  test('bilinen markada, optimizasyon aciksa ve alarm varsa uyarir', () {
    expect(
      BatteryAdvice.shouldWarn(
        status: status(),
        dismissed: false,
        hasActiveAlarm: true,
      ),
      isTrue,
    );
    expect(
      BatteryAdvice.shouldWarn(
        status: status(m: 'google', b: 'redmi'),
        dismissed: false,
        hasActiveAlarm: true,
      ),
      isTrue,
    );
  });

  test('muaf, kapatilmis, alarmsiz ya da bilinmeyen markada uyarmaz', () {
    expect(
      BatteryAdvice.shouldWarn(
        status: status(ignoring: true),
        dismissed: false,
        hasActiveAlarm: true,
      ),
      isFalse,
    );
    expect(
      BatteryAdvice.shouldWarn(
        status: status(),
        dismissed: true,
        hasActiveAlarm: true,
      ),
      isFalse,
    );
    expect(
      BatteryAdvice.shouldWarn(
        status: status(),
        dismissed: false,
        hasActiveAlarm: false,
      ),
      isFalse,
    );
    expect(
      BatteryAdvice.shouldWarn(
        status: status(m: 'google', b: 'google'),
        dismissed: false,
        hasActiveAlarm: true,
      ),
      isFalse,
    );
  });

  test('bilinmeyen durum uyari uretmez', () {
    expect(
      BatteryAdvice.shouldWarn(
        status: BatteryStatus.unknown,
        dismissed: false,
        hasActiveAlarm: true,
      ),
      isFalse,
    );
  });
}
