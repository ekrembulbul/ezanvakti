import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/features/alarms/domain/alarms_manager.dart';
import 'package:ezanvakti/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Uygulamayi gercek cihaz/simulatorde gezip her ekranin goruntusunu alir.
///
/// Calistirma:
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart \
///     -d `simulator-udid`
///
/// Not: Ana ekranda saniyelik geri sayim timer'i dondugu icin `pumpAndSettle`
/// asla durulmaz; bunun yerine sabit sureli [_wait] ile frame pompalanir.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Photon/Aladhan istekleri gercek agi kullanir; arama ve vakit cekme icin
  // comert bekleme sureleri.
  const searchQuery = 'Kadıköy';

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump();
    await binding.takeScreenshot(name);
  }

  testWidgets('ilk kurulum, vakitler, bildirim, ayar ve alarm ekranlari', (
    tester,
  ) async {
    app.main();
    await _wait(tester, const Duration(seconds: 5));

    Future<void> capture(String name) => shot(tester, name);

    await _captureOnboarding(tester, capture, searchQuery);
    await _captureHomeAndMenu(tester, capture);
    await _captureNotifications(tester, capture);
    await _captureSettings(tester, capture);
    await _captureAlarms(tester, capture);
  });

  // "Kaydet" akisi AlarmKit izin dialog'unu acar ve sistem dialog'u testten
  // kapatilamadigi icin kayit orada bloke olur. Dolu liste goruntusu icin
  // alarmlar dogrudan depoya yazilip agac yeniden kurulur (ServiceLocator ilk
  // testte hazirlandigi icin main() tekrar calistirilmaz).
  testWidgets('dolu alarm listesi', (tester) async {
    await _seedAlarms();
    await tester.pumpWidget(const app.MyApp());
    await _wait(tester, const Duration(seconds: 8));

    await tester.tap(find.byIcon(Icons.alarm_rounded));
    await _wait(tester, const Duration(seconds: 3));
    await shot(tester, '18-alarmlar-dolu');
  });
}

typedef Shot = Future<void> Function(String name);

/// Ilk acilis: konum secimi -> adres arama -> kaydet -> ana ekran.
Future<void> _captureOnboarding(
  WidgetTester tester,
  Shot shot,
  String query,
) async {
  expect(find.text('Yeni Konum Ekle'), findsOneWidget);
  await shot('01-konum-secimi');

  await tester.tap(find.text('Adres Ara'));
  await _wait(tester, const Duration(seconds: 1));
  await _dismissKeyboard(tester);
  await shot('02-adres-arama');

  await tester.enterText(find.byType(TextField).first, query);
  await _wait(tester, const Duration(seconds: 6));
  await _dismissKeyboard(tester);
  await shot('03-arama-sonuclari');

  // Ayni isimli birden fazla yer var; Istanbul'daki kayit secilir.
  await tester.tap(find.textContaining('İstanbul').first);
  await _wait(tester, const Duration(seconds: 2));
  await shot('04-konum-onay');

  await tester.tap(find.text('Kaydet'));
  await _wait(tester, const Duration(seconds: 15));
  await shot('05-ana-ekran');
}

/// Ana ekran menusu ve takvim.
Future<void> _captureHomeAndMenu(WidgetTester tester, Shot shot) async {
  await tester.tap(find.byIcon(Icons.menu_rounded));
  await _wait(tester, const Duration(seconds: 2));
  await shot('06-menu');

  // Ana ekranin "YARIN" seridinde de "Takvim" kisayolu var; menudeki ogeyi
  // yalnizca ona ait olan alt metinden hedefliyoruz.
  await tester.tap(find.text('30 günlük namaz vakitleri'));
  await _wait(tester, const Duration(seconds: 4));
  await shot('07-takvim');

  await _goBack(tester);
}

/// Bildirim ayarlari + bildirim ekleme sayfasi (tam vaktinde / oncesinde).
Future<void> _captureNotifications(WidgetTester tester, Shot shot) async {
  await tester.tap(find.byIcon(Icons.menu_rounded));
  await _wait(tester, const Duration(seconds: 2));
  await tester.tap(find.text('Bildirimler'));
  await _wait(tester, const Duration(seconds: 4));
  await shot('08-bildirimler');

  await tester.tap(find.byKey(const Key('add_notification_button')));
  await _wait(tester, const Duration(seconds: 2));
  await shot('09-bildirim-ekle');

  // "Oncesinde" secilince dakika tekerlegi acilir.
  await tester.tap(find.text('Öncesinde'));
  await _wait(tester, const Duration(seconds: 2));
  await shot('10-bildirim-ekle-oncesinde');

  // Modal barrier'a dokunarak sheet'i kapat.
  await tester.tapAt(const Offset(200, 60));
  await _wait(tester, const Duration(seconds: 2));

  await _goBack(tester);
}

/// Ayarlar -> hesaplama, konum listesi ve konum duzenleme.
Future<void> _captureSettings(WidgetTester tester, Shot shot) async {
  await tester.tap(find.byIcon(Icons.menu_rounded));
  await _wait(tester, const Duration(seconds: 2));
  await tester.tap(find.text('Ayarlar'));
  await _wait(tester, const Duration(seconds: 3));
  await shot('11-ayarlar');

  // Acik temanin gercek uygulamada calistigini kanitlar; sonra koyuya donulur
  // ki kalan kareler ayni palette kalsin.
  await tester.tap(find.text('Açık'));
  await _wait(tester, const Duration(seconds: 3));
  await shot('11b-ayarlar-acik');
  await tester.tap(find.text('Koyu'));
  await _wait(tester, const Duration(seconds: 2));

  await tester.tap(find.text('Hesaplama'));
  await _wait(tester, const Duration(seconds: 3));
  await shot('12-hesaplama');
  await _goBack(tester);

  await tester.tap(find.text('Konum'));
  await _wait(tester, const Duration(seconds: 3));
  await shot('13-konumlar');

  await tester.tap(find.byIcon(Icons.tune_rounded).last);
  await _wait(tester, const Duration(seconds: 3));
  await shot('14-konum-duzenle');

  await _goBack(tester); // konumlar
  await _goBack(tester); // ayarlar
  await _goBack(tester); // ana ekran
}

/// Alarm sekmesi: bos liste ve alarm ekleme (sabit saat / vakte gore).
Future<void> _captureAlarms(WidgetTester tester, Shot shot) async {
  await tester.tap(find.byIcon(Icons.alarm_rounded));
  await _wait(tester, const Duration(seconds: 3));
  await shot('15-alarmlar-bos');

  await tester.tap(find.byTooltip('Alarm ekle'));
  await _wait(tester, const Duration(seconds: 3));
  await shot('16-alarm-ekle-sabit-saat');

  await tester.tap(find.text('Vakte göre'));
  await _wait(tester, const Duration(seconds: 2));
  await tester.tap(find.text('Önce'));
  await _wait(tester, const Duration(seconds: 2));
  await shot('17-alarm-ekle-vakte-gore');

  await _goBack(tester);
}

Future<void> _seedAlarms() async {
  final manager = ServiceLocator().get<AlarmsManager>();
  await manager.save(
    const Alarm(
      id: 'screenshot-fixed',
      kind: AlarmKind.fixed,
      label: 'Sabah',
      hour: 6,
      minute: 30,
      weekdays: {1, 2, 3, 4, 5},
    ),
  );
  await manager.save(
    const Alarm(
      id: 'screenshot-anchored',
      kind: AlarmKind.anchored,
      label: 'Sahur',
      anchor: PrayerType.fajr,
      offsetMinutes: -30,
    ),
  );
  debugPrint('SCREENSHOT-SEED: ${(await manager.getAlarms()).length} alarm');
}

/// Yazilim klavyesi Flutter yuzeyine cizilmedigi icin ekran goruntusunde
/// siyah bir bosluk birakir; goruntu almadan once odak kaldirilir.
Future<void> _dismissKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await _wait(tester, const Duration(seconds: 2));
}

Future<void> _goBack(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
  await _wait(tester, const Duration(seconds: 3));
}

/// Gercek zamanda frame pompalar. `pumpAndSettle`, ana ekrandaki periyodik
/// timer yuzunden hicbir zaman donmeyecegi icin kullanilamaz.
Future<void> _wait(WidgetTester tester, Duration duration) async {
  final steps = duration.inMilliseconds ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
