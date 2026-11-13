import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/interfaces/widget_publisher.dart';
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/core/services/device_settings_service.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot.dart';
import 'package:ezanvakti/presentation/widgets/settings/notification_prefs_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

class _RecordingPublisher implements WidgetPublisher {
  final published = <bool>[];

  @override
  Future<void> publishNextPrayerNotification(bool enabled) async =>
      published.add(enabled);

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {}

  @override
  Future<void> publishAppearance(AppearanceSettings settings) async {}

  @override
  Future<void> publishTimeFormat(String storageValue) async {}
}

class _FakeDevice extends DeviceSettingsService {
  BatteryStatus status;
  int opened = 0;

  _FakeDevice(this.status) : super(isAndroid: true);

  @override
  Future<BatteryStatus> batteryStatus() async => status;

  @override
  Future<void> openBatteryOptimizationSettings() async => opened++;
}

const _warning =
    "Bu telefon bildirimi geç yenileyebilir. Ezan Vakti'yi pil "
    'optimizasyonundan çıkar.';

/// Ayarlar → Bildirim ve ses: "Bildirim çubuğunda sıradaki vakit" (Android).
void main() {
  late FakeStorage storage;
  late _RecordingPublisher publisher;
  late _FakeDevice device;

  setUp(() {
    device = _FakeDevice(BatteryStatus.unknown);
    ServiceLocator().register<DeviceSettingsService>(device);
    storage = FakeStorage();
    publisher = _RecordingPublisher();
    ServiceLocator().register<LocalStorage>(storage);
    ServiceLocator().register<WidgetPublisher>(publisher);
  });

  Future<AppState> pump(WidgetTester tester, {required bool show}) async {
    final appState = AppState();
    await tester.pumpWidget(
      wrapWithTheme(
        SingleChildScrollView(
          child: NotificationPrefsSection(
            showAlarmRingLimit: false,
            showNextPrayerNotification: show,
          ),
        ),
        appState: appState,
      ),
    );
    await tester.pump();
    return appState;
  }

  testWidgets('Android: anahtar açık gelir', (tester) async {
    await pump(tester, show: true);

    expect(find.text('Bildirim çubuğunda sıradaki vakit'), findsOneWidget);
    final row = find.ancestor(
      of: find.text('Bildirim çubuğunda sıradaki vakit'),
      matching: find.byType(Row),
    );
    final toggle = tester.widget<Switch>(
      find.descendant(of: row.first, matching: find.byType(Switch)),
    );
    expect(toggle.value, isTrue);
  });

  testWidgets('Android dışında satır yok', (tester) async {
    await pump(tester, show: false);
    expect(find.text('Bildirim çubuğunda sıradaki vakit'), findsNothing);
  });

  testWidgets('kapatınca depoya yazılır ve widget tarafına yayınlanır', (
    tester,
  ) async {
    final appState = await pump(tester, show: true);
    final row = find.ancestor(
      of: find.text('Bildirim çubuğunda sıradaki vakit'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: row.first, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(appState.generalSettings.nextPrayerNotification, isFalse);
    expect(
      (await storage.getGeneralSettings()).nextPrayerNotification,
      isFalse,
    );
    expect(publisher.published, [false]);
  });

  group('pil uyarısı', () {
    const restricted = BatteryStatus(
      manufacturer: 'samsung',
      brand: 'samsung',
      ignoringOptimizations: false,
    );

    testWidgets('kısıtlı markada anahtarın altında çıkar, Aç ayarı açar', (
      tester,
    ) async {
      device.status = restricted;
      await pump(tester, show: true);
      await tester.pump();

      expect(find.text(_warning), findsOneWidget);
      await tester.tap(find.text('Aç'));
      await tester.pump();
      expect(device.opened, 1);
    });

    testWidgets('uygulama muafsa çıkmaz', (tester) async {
      device.status = const BatteryStatus(
        manufacturer: 'samsung',
        brand: 'samsung',
        ignoringOptimizations: true,
      );
      await pump(tester, show: true);
      await tester.pump();

      expect(find.text(_warning), findsNothing);
    });

    testWidgets('anahtar kapatılınca kalkar', (tester) async {
      device.status = restricted;
      await pump(tester, show: true);
      await tester.pump();
      expect(find.text(_warning), findsOneWidget);

      final row = find.ancestor(
        of: find.text('Bildirim çubuğunda sıradaki vakit'),
        matching: find.byType(Row),
      );
      await tester.tap(
        find.descendant(of: row.first, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      expect(find.text(_warning), findsNothing);
    });

    testWidgets('ayarlardan dönünce durum yeniden okunur', (tester) async {
      device.status = restricted;
      await pump(tester, show: true);
      await tester.pump();
      expect(find.text(_warning), findsOneWidget);

      device.status = const BatteryStatus(
        manufacturer: 'samsung',
        brand: 'samsung',
        ignoringOptimizations: true,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(find.text(_warning), findsNothing);
    });
  });
}
