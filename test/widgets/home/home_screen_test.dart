import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../theme_harness.dart';

PrayerTime _day(int day) {
  DateTime at(int h, int m) => DateTime(2026, 8, day, h, m);
  return PrayerTime(
    fajr: at(4, 8),
    sunrise: at(5, 53),
    dhuhr: at(13, 15),
    asr: at(17, 10),
    maghrib: at(20, 27),
    isha: at(22, 4),
    date: DateTime(2026, 8, day),
  );
}

const _location = Location(id: '1', province: 'İstanbul', district: 'Kadıköy');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  /// Ana ekran kaydirilmaz; gercek telefon boyutunda olculur.
  Future<void> pumpHome(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapWithTheme(screen));
    await tester.pump();
  }

  testWidgets('Yukleniyorken gostergeyi cizer', (tester) async {
    await pumpHome(
      tester,
      const HomeScreen(location: _location, isLoading: true),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Veri varken sayac, izgara ve SIRADAKI gorunur', (tester) async {
    await pumpHome(
      tester,
      HomeScreen(
        location: _location,
        todaysPrayerTime: _day(2),
        tomorrowsPrayerTime: _day(3),
        lastUpdateTime: DateTime(2026, 8, 2),
      ),
    );

    expect(find.text('Kadıköy, İstanbul'), findsOneWidget);
    expect(find.text('SONRAKİ'), findsOneWidget);
    // Izgaraya ozgu bir vakit: "İMSAK" geri sayim etiketinde de cikabilir,
    // hangi vaktin sirada oldugu testin calistigi saate bagli.
    expect(find.text('GÜNEŞ'), findsOneWidget);
    expect(find.text('SIRADAKİ'), findsOneWidget);
  });

  testWidgets('Hata mesaji varken hata durumu gosterilir', (tester) async {
    await pumpHome(
      tester,
      const HomeScreen(location: _location, errorMessage: 'Veri alınamadı'),
    );

    expect(find.textContaining('Veri alınamadı'), findsOneWidget);
  });

  testWidgets('Vakit verisi yok ama guncelleme zamani varsa bos durum', (
    tester,
  ) async {
    await pumpHome(
      tester,
      HomeScreen(location: _location, lastUpdateTime: DateTime(2026, 8, 2)),
    );

    expect(find.text('Veri bulunamadı'), findsOneWidget);
  });

  // Ayarlar'a artik ust cubuktaki disli ikonundan tek dokunusla gidiliyor;
  // hamburger menu kaldirildi (spec D5).
  testWidgets('Disli ikonu Ayarlar callback ini tetikler', (tester) async {
    var opened = false;

    await pumpHome(
      tester,
      HomeScreen(
        location: _location,
        todaysPrayerTime: _day(2),
        tomorrowsPrayerTime: _day(3),
        lastUpdateTime: DateTime(2026, 8, 2),
        onSettingsTap: () => opened = true,
      ),
    );

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('Veri varken yenileme ekrani bosaltmaz', (tester) async {
    await pumpHome(
      tester,
      HomeScreen(
        location: _location,
        todaysPrayerTime: _day(2),
        lastUpdateTime: DateTime(2026, 8, 2),
        isRefreshing: true,
      ),
    );

    // Vakitler yerinde; yenileme tam ekran yukleme ile degistirmiyor.
    expect(find.text('13:15'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Yenileme surerken ust cubukta ince gosterge cizilir', (
    tester,
  ) async {
    await pumpHome(
      tester,
      HomeScreen(
        location: _location,
        todaysPrayerTime: _day(2),
        lastUpdateTime: DateTime(2026, 8, 2),
        isRefreshing: true,
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('Yenileme bitince gosterge kaybolur', (tester) async {
    await pumpHome(
      tester,
      HomeScreen(
        location: _location,
        todaysPrayerTime: _day(2),
        lastUpdateTime: DateTime(2026, 8, 2),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
