import 'package:ezanvakti/features/qibla/data/heading_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.ekrembulbul.ezanvakti/heading';

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('okuma map ten cevrilir', () {
    final reading = HeadingReading.fromMap({
      'degrees': 123.5,
      'accuracy': 4.0,
    });
    expect(reading, isNotNull);
    expect(reading!.degrees, 123.5);
    expect(reading.accuracy, 4.0);
    expect(reading.needsCalibration, isFalse);
  });

  test('negatif dogruluk kalibrasyon gerektirir', () {
    final reading = HeadingReading.fromMap({'degrees': 10.0, 'accuracy': -1.0});
    expect(reading!.needsCalibration, isTrue);
  });

  test('esik ustu sapma da kalibrasyon gerektirir', () {
    final reading = HeadingReading.fromMap({
      'degrees': 10.0,
      'accuracy': HeadingReading.calibrationThreshold + 1,
    });
    expect(reading!.needsCalibration, isTrue);
  });

  test('bozuk olay null doner', () {
    expect(HeadingReading.fromMap({'degrees': 'abc'}), isNull);
    expect(HeadingReading.fromMap(null), isNull);
    expect(HeadingReading.fromMap({'accuracy': 1.0}), isNull);
  });

  test('desteklenmeyen platformda akis bos', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final readings = await HeadingService().headings.toList();
    expect(readings, isEmpty);
  });

  test('native olaylari okuma akisina cevrilir', () async {
    const channel = EventChannel(channelName);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          channel,
          MockStreamHandler.inline(
            onListen: (arguments, sink) {
              sink.success({'degrees': 45.0, 'accuracy': 2.0});
              // Bozuk olay akisi kirmamali, atlanmali.
              sink.success({'degrees': null});
              sink.success({'degrees': 90.0, 'accuracy': 3.0});
              sink.endOfStream();
            },
          ),
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(channel, null),
    );

    final readings = await HeadingService().headings.toList();
    expect(readings.map((r) => r.degrees), [45.0, 90.0]);
  });
}
