import 'package:ezanvakti/core/models/quiet_interval.dart';
import 'package:ezanvakti/core/services/device_settings_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.ekrembulbul.ezanvakti/device');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Android disinda native cagrilmaz, guvenli varsayilan doner', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });
    final service = DeviceSettingsService(isAndroid: false);

    expect(await service.canUseFullScreenIntent(), isTrue);
    expect(await service.isQuietModeSupported(), isFalse);
    expect(await service.hasQuietModeAccess(), isFalse);
    expect((await service.batteryStatus()).ignoringOptimizations, isTrue);
    await service.setQuietSchedule(const []);
    expect(called, isFalse);
  });

  test('susturma plani milisaniye listesi olarak gider', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });

    await DeviceSettingsService(isAndroid: true).setQuietSchedule([
      QuietInterval(
        DateTime.fromMillisecondsSinceEpoch(1000),
        DateTime.fromMillisecondsSinceEpoch(5000),
      ),
    ]);

    expect(received!.method, 'setQuietSchedule');
    expect(received!.arguments, {
      'intervals': [
        {'startMillis': 1000, 'endMillis': 5000},
      ],
    });
  });

  test('pil durumu okunur; native hata guvenli varsayilana duser', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => {
        'manufacturer': 'Xiaomi',
        'brand': 'Redmi',
        'ignoringOptimizations': false,
      },
    );
    final status = await DeviceSettingsService(isAndroid: true).batteryStatus();
    expect(status.manufacturer, 'xiaomi');
    expect(status.brand, 'redmi');
    expect(status.ignoringOptimizations, isFalse);

    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'x'),
    );
    final service = DeviceSettingsService(isAndroid: true);
    expect((await service.batteryStatus()).ignoringOptimizations, isTrue);
    expect(await service.canUseFullScreenIntent(), isTrue);
    expect(await service.hasQuietModeAccess(), isFalse);
  });
}
