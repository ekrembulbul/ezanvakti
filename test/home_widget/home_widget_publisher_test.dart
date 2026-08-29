import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/utils/app_logger.dart';
import 'package:ezanvakti/features/home_widget/data/home_widget_publisher.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final snapshot = WidgetSnapshot(
    locationLabel: 'Kadıköy, İstanbul',
    generatedAt: DateTime(2026, 8, 25, 14, 3),
    days: const [],
  );

  test('publish App Group kimligini ayarlar', () async {
    await HomeWidgetPublisher(logger: AppLogger()).publish(snapshot);

    final setGroup = calls.firstWhere((call) => call.method == 'setAppGroupId');
    expect(setGroup.arguments['groupId'], HomeWidgetPublisher.appGroupId);
  });

  test('publish snapshot key\'ine tek JSON string yazar', () async {
    await HomeWidgetPublisher(logger: AppLogger()).publish(snapshot);

    final save = calls.firstWhere((call) => call.method == 'saveWidgetData');
    expect(save.arguments['id'], HomeWidgetPublisher.snapshotKey);
    expect(save.arguments['data'], contains('"schemaVersion":1'));
  });

  test('publish widget kind ile guncelleme tetikler', () async {
    await HomeWidgetPublisher(logger: AppLogger()).publish(snapshot);

    // Paket iOSName'i kanala 'ios' anahtariyla gonderiyor
    // (home_widget-0.9.3/lib/src/home_widget.dart:70).
    final update = calls.firstWhere((call) => call.method == 'updateWidget');
    expect(update.arguments['ios'], HomeWidgetPublisher.widgetKind);
  });
}
