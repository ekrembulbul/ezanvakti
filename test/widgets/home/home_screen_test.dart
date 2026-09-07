import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/screens/home_screen.dart';
import 'package:ezanvakti/presentation/widgets/home/prayer_grid.dart';
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

PrayerTime _dayForDate(DateTime date) {
  DateTime at(int hour, int minute) =>
      DateTime(date.year, date.month, date.day, hour, minute);
  return PrayerTime(
    fajr: at(4, 8),
    sunrise: at(5, 53),
    dhuhr: at(13, 15),
    asr: at(17, 10),
    maghrib: at(20, 27),
    isha: at(22, 4),
    date: DateTime(date.year, date.month, date.day),
  );
}

const _location = Location(id: '1', province: 'İstanbul', district: 'Kadıköy');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  /// Ana ekran gerçek telefon boyutunda ölçülür.
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
    expect(
      find.descendant(
        of: find.byType(PrayerGrid),
        matching: find.text('13:15'),
      ),
      findsOneWidget,
    );
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

  testWidgets('kerahat ayrıntıları yalnızca üst çubuktan açılınca görünür', (
    tester,
  ) async {
    final today = _dayForDate(DateTime.now());
    await pumpHome(
      tester,
      HomeScreen(
        location: _location,
        todaysPrayerTime: today,
        lastUpdateTime: today.date,
      ),
    );

    expect(find.text('Sıradaki kerahat'), findsNothing);
    expect(find.text('Bugünün kerahat vakitleri'), findsNothing);
    expect(find.text('Öğle öncesi'), findsNothing);
    await tester.tap(find.byTooltip('Kerahat vakitleri'));
    await tester.pumpAndSettle();
    expect(find.text('Güneş sonrası'), findsOneWidget);
    expect(find.text('Öğle öncesi'), findsOneWidget);
    expect(find.text('Akşam öncesi'), findsOneWidget);
  });

  testWidgets('eski günün verisinden kerahat ayrıntısı uydurmaz', (
    tester,
  ) async {
    await pumpHome(
      tester,
      HomeScreen(
        location: _location,
        todaysPrayerTime: _day(2),
        lastUpdateTime: DateTime(2026, 8, 2),
      ),
    );

    expect(find.byTooltip('Kerahat vakitleri'), findsNothing);
  });

  testWidgets('dar ekranda buyuk metinle Home kaydirilir ve tasmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final today = _dayForDate(DateTime.now());

    await tester.pumpWidget(
      wrapWithTheme(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: HomeScreen(
            location: _location,
            todaysPrayerTime: today,
            lastUpdateTime: today.date,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arapça RTL Home kerahat erişimini taşmadan çizer', (
    tester,
  ) async {
    final today = _dayForDate(DateTime.now());
    await tester.pumpWidget(
      wrapWithTheme(
        HomeScreen(
          location: _location,
          todaysPrayerTime: today,
          lastUpdateTime: today.date,
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('أوقات الكراهة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
