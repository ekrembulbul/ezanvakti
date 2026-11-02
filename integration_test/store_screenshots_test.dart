import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart'
    show PrayerType;
import 'package:ezanvakti/core/theme/theme_controller.dart';
import 'package:ezanvakti/features/alarms/domain/alarms_manager.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:ezanvakti/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Mağaza (App Store / Google Play) ekran görüntüleri.
///
/// Kurulum ekranını gezmek yerine konum ve örnek alarmlar doğrudan depoya
/// yazılır; vakitler canlı sunucudan gelir, bu yüzden adres verilmelidir:
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/store_screenshots_test.dart \
///     --dart-define=VAKIT_API_BASE_URL=https://ezanvakti.ekrembulbul.me \
///     -d `cihaz`
/// Görüntüler `screenshots/` altına düşer (git dışı). Kalıcı veri yazdığı
/// için koşudan sonra uygulamayı cihazdan kaldır.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mağaza ekranları', (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      await initializeDateFormatting(locale.languageCode, null);
    }
    final locator = ServiceLocator();
    await locator.initialize();
    locator.get<ThemeController>().observePlatformBrightness();

    await _seedLocation(locator.get<LocationRepository>());
    await _seedAlarms(locator.get<AlarmsManager>());

    // Görüntüler Türkçe kaydın; Android emülatöründe sistem dili kökten
    // değiştirilemediği için uygulamaya giden cihaz dili testte sabitlenir.
    binding.platformDispatcher.localesTestValue = const [Locale('tr', 'TR')];
    addTearDown(binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const app.MyApp());
    // İlk açılışta yıllık vakit dosyası iner; yükleme göstergesi kaybolana
    // kadar beklenir, ardından geçiş animasyonları için kısa bir pay.
    await _waitUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      const Duration(seconds: 90),
    );
    await _wait(tester, const Duration(seconds: 3));

    Future<void> shot(String name) async {
      await tester.pump();
      await binding.takeScreenshot(name);
    }

    await shot('01-vakitler');

    await tester.tap(find.text('Hatırlatıcılar'));
    await _wait(tester, const Duration(seconds: 4));
    await shot('02-hatirlaticilar');

    await tester.tap(find.text('Araçlar'));
    await _wait(tester, const Duration(seconds: 3));
    await shot('03-araclar');

    await tester.tap(find.text('Vakit takvimi'));
    await _wait(tester, const Duration(seconds: 6));
    await shot('04-takvim');
    await _goBack(tester);

    // Listede en yeni hutbe en üstte; tarih satırı ("… · Cuma") satıra
    // dokunmayı sağlar ve başlık her hafta değiştiği için ona bağlanmaz.
    await tester.tap(find.text('Hutbe'));
    await _wait(tester, const Duration(seconds: 6));
    await tester.tap(find.textContaining('Cuma').first);
    await _wait(tester, const Duration(seconds: 6));
    await shot('05-hutbe');
    await _goBack(tester);
    await _goBack(tester);

    await tester.tap(find.text('Zikirmatik'));
    await _wait(tester, const Duration(seconds: 3));
    for (var i = 0; i < 27; i++) {
      await tester.tapAt(tester.getCenter(find.byType(Scaffold).last));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await _wait(tester, const Duration(seconds: 2));
    await shot('06-zikirmatik');
    await _goBack(tester);
  });
}

/// İstanbul (Merkez); kimlikler `vakit-api` aramasındaki kayıtla aynı.
Future<void> _seedLocation(LocationRepository repository) async {
  const location = Location(
    id: 'store-istanbul',
    province: 'İstanbul',
    district: 'İstanbul',
    latitude: 41.006381,
    longitude: 28.9758715,
    cityId: 9541,
    stateId: 539,
    countryId: 2,
    displayLabel: 'İstanbul (Merkez)',
  );
  await repository.saveLocation(location);
  await repository.setActiveLocation(location);
}

Future<void> _seedAlarms(AlarmsManager manager) async {
  const alarms = [
    Alarm(
      id: 'store-sahur',
      kind: AlarmKind.anchored,
      label: 'Sahur',
      anchor: PrayerType.fajr,
      offsetMinutes: -45,
    ),
    Alarm(
      id: 'store-sabah',
      kind: AlarmKind.anchored,
      label: 'Sabah namazı',
      anchor: PrayerType.sunrise,
      offsetMinutes: -30,
    ),
    Alarm(
      id: 'store-is',
      kind: AlarmKind.fixed,
      label: 'İş',
      hour: 7,
      minute: 15,
      weekdays: {1, 2, 3, 4, 5},
    ),
  ];
  for (final alarm in alarms) {
    await manager.save(alarm, prayerTimes: const [], skips: const {});
  }
}

/// Ekranların geri düğmesi özel çizildiği için `pageBack` onu bulamıyor;
/// kök gezinme yığınından bir sayfa çıkılır.
Future<void> _goBack(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await _wait(tester, const Duration(seconds: 3));
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() done,
  Duration timeout,
) async {
  final end = DateTime.now().add(timeout);
  while (!done() && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Ana ekrandaki saniyelik geri sayım yüzünden `pumpAndSettle` hiç durulmaz;
/// gerçek zamanda frame pompalanır.
Future<void> _wait(WidgetTester tester, Duration duration) async {
  final steps = duration.inMilliseconds ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
