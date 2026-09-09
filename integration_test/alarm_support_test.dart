import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/presentation/pages/app_root.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Gerçek native köprüyle Alarmlar sekmesi: AlarmKit varsa (iOS 26.1+,
/// Android) liste ve anahtar; yoksa (iOS 17–26.0) yalnız bilgi kartı ve
/// korunan alarm sayısı. Hangi dalın doğrulanacağını köprünün kendisi söyler,
/// bu yüzden aynı test her runtime'da anlamlıdır.
///
/// Çalıştırma:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/alarm_support_test.dart -d `<udid>`
///
/// Simülatör dili Türkçe olmalı (metinler TR). Ağ gerekmez: vakit isteği
/// başarısız olsa da sekme açılır; beklemeler sabit süre değil, widget
/// görünene kadar.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Alarmlar sekmesi platform desteğine göre açılır ya da kapanır', (
    tester,
  ) async {
    app.main();
    // main() beklenemiyor (void async); uygulamanın ayağa kalktığının işareti
    // ilk kurulum ekranı. Ondan önce depoya yazmak, initialize() ile yarışır.
    await _waitFor(tester, find.text('Konum ekle'));

    // İlk kurulum atlanır. Depoya yazmak yetmez: main() ağacı ayakta ve
    // AppRoot depoyu yalnız initState'te okuyor; aynı const MyApp ile yeniden
    // pumpWidget etmek de State'i korur. Bu yüzden konum ve alarm hem depoya
    // (HomePage yeniden yüklerken bulsun) hem doğrudan AppState'e yazılır.
    const location = Location(
      id: 'it-kadikoy',
      province: 'İstanbul',
      district: 'Kadıköy',
      latitude: 40.99,
      longitude: 29.03,
    );
    const alarm = Alarm(
      id: 'it-sabah',
      kind: AlarmKind.fixed,
      label: 'Sabah',
      hour: 6,
      minute: 30,
    );
    final locations = ServiceLocator().get<LocationRepository>();
    await locations.saveLocation(location);
    await locations.setActiveLocation(location);
    await ServiceLocator().get<LocalStorage>().saveAlarm(alarm);
    final supported = await ServiceLocator().get<AlarmService>().isSupported();

    final appState = Provider.of<AppState>(
      tester.element(find.byType(AppRoot)),
      listen: false,
    );
    appState.setAlarms(const [alarm]);
    appState.setActiveLocation(location);

    await _waitFor(tester, find.text('Hatırlatıcılar'));
    await tester.tap(find.text('Hatırlatıcılar'));
    await _waitFor(tester, find.text('Alarmlar'));
    await tester.tap(find.text('Alarmlar'));

    final expected = supported
        ? find.byType(Switch)
        : find.textContaining('26.1');
    await _waitFor(tester, expected);
    await binding.takeScreenshot(
      supported ? 'alarmlar-destekli' : 'alarmlar-kapali',
    );

    if (supported) {
      expect(find.byType(Switch), findsWidgets);
      expect(find.textContaining('26.1'), findsNothing);
    } else {
      expect(find.textContaining('26.1'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('1 kayıtlı alarm korunuyor.'), findsOneWidget);
    }
  });
}

/// [finder] görünene kadar kare pompalar; [timeout] dolarsa test düşer.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      // Hangi ekranda kalındığı hatadan okunabilsin.
      final visible = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .take(12)
          .join(' | ');
      fail(
        'Beklenen widget ${timeout.inSeconds} sn içinde gelmedi: $finder\n'
        'Ekrandaki metinler: $visible',
      );
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump();
}
