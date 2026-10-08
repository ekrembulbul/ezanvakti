import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/notification_setting.dart'
    show PrayerType;
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/core/services/device_settings_service.dart';
import 'package:ezanvakti/presentation/screens/quiet_windows_screen.dart';
import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

/// Native kanala gitmeden destek/erişim durumunu ve izin ekranı çağrılarını
/// taklit eder.
class _FakeDeviceSettings extends DeviceSettingsService {
  bool supported;
  bool access;
  int openAccessCalls = 0;

  _FakeDeviceSettings({required this.supported, required this.access})
    : super(isAndroid: false);

  @override
  Future<bool> isQuietModeSupported() async => supported;

  @override
  Future<bool> hasQuietModeAccess() async => access;

  @override
  Future<void> openQuietModeAccessSettings() async => openAccessCalls++;
}

void main() {
  late FakeStorage storage;
  late int changes;

  setUp(() async {
    storage = FakeStorage();
    await storage.init();
    changes = 0;
    ServiceLocator().register<LocalStorage>(storage);
  });

  Future<_FakeDeviceSettings> pumpScreen(
    WidgetTester tester,
    List<QuietWindow> windows, {
    required bool supported,
    required bool access,
  }) async {
    final device = _FakeDeviceSettings(supported: supported, access: access);
    ServiceLocator().register<DeviceSettingsService>(device);
    await storage.saveQuietWindows(windows);
    await tester.pumpWidget(
      wrapWithTheme(QuietWindowsScreen(onChanged: () async => changes++)),
    );
    await tester.pumpAndSettle();
    return device;
  }

  Future<bool> savedFridaySilence() async => (await storage.getQuietWindows())
      .firstWhere((w) => w.id == 'friday')
      .silencePhone;

  testWidgets('Desteklenmeyen surumde "Telefonu da sustur" satiri yok', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      [QuietWindow.fridayDefault()],
      supported: false,
      access: false,
    );

    expect(find.text('Cuma vaktinde sessiz'), findsOneWidget);
    expect(find.text('Telefonu da sustur'), findsNothing);
  });

  /// "Telefonu da sustur" satırındaki anahtar (en yakın satırın içinde).
  Finder silenceSwitch() => find.descendant(
    of: find
        .ancestor(
          of: find.text('Telefonu da sustur'),
          matching: find.byType(Row),
        )
        .first,
    matching: find.byType(Switch),
  );

  testWidgets(
    'Erisim yokken acmak izin ekranini acar, kayit degismez; donunce erisim varsa acilir',
    (tester) async {
      final device = await pumpScreen(
        tester,
        [QuietWindow.fridayDefault()],
        supported: true,
        access: false,
      );

      final tile = silenceSwitch();
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(device.openAccessCalls, 1);
      expect(await savedFridaySilence(), isFalse);
      expect(changes, 0);

      // Kullanici izni verip uygulamaya doner.
      device.access = true;
      final state = tester.state(find.byType(QuietWindowsScreen));
      (state as WidgetsBindingObserver).didChangeAppLifecycleState(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      expect(await savedFridaySilence(), isTrue);
      expect(changes, 1);
    },
  );

  testWidgets('Izin verilmeden donulurse anahtar kapali kalir', (tester) async {
    final device = await pumpScreen(
      tester,
      [QuietWindow.fridayDefault()],
      supported: true,
      access: false,
    );

    final tile = silenceSwitch();
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(QuietWindowsScreen));
    (state as WidgetsBindingObserver).didChangeAppLifecycleState(
      AppLifecycleState.resumed,
    );
    await tester.pumpAndSettle();

    expect(device.openAccessCalls, 1);
    expect(await savedFridaySilence(), isFalse);
  });

  testWidgets(
    'Erisim kapaliyken acik anahtar uyari gosterir; ozel satir eki yazilir',
    (tester) async {
      const dhuhr = QuietWindow(
        id: 'q1',
        trigger: QuietTrigger.prayer,
        prayerType: PrayerType.dhuhr,
        minutesBefore: 10,
        minutesAfter: 30,
        silencePhone: true,
      );
      await pumpScreen(
        tester,
        [QuietWindow.fridayDefault().copyWith(silencePhone: true), dhuhr],
        supported: true,
        access: false,
      );

      expect(
        find.text('Rahatsız Etme erişimi kapalı. Açmak için dokun.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.widgetWithText(GroupedRow, 'Öğle'),
          matching: find.textContaining('Telefon susar'),
        ),
        findsOneWidget,
      );
    },
  );
}
