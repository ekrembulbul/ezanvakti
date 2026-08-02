import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/widgets/home/countdown_hero.dart';
import 'package:ezanvakti/presentation/widgets/home/day_ruler.dart';
import 'package:ezanvakti/presentation/widgets/home/home_top_bar.dart';
import 'package:ezanvakti/presentation/widgets/home/prayer_grid.dart';
import 'package:ezanvakti/presentation/widgets/home/tomorrow_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../theme_harness.dart';

/// Silinen countdown_card / prayer_times_card / location_header testlerinden
/// devralinan kapsam: parcalar dar alanda tasmadan cizilmeli.
PrayerTime _times() {
  DateTime at(int h, int m) => DateTime(2026, 8, 2, h, m);
  return PrayerTime(
    fajr: at(4, 8),
    sunrise: at(5, 53),
    dhuhr: at(13, 15),
    asr: at(17, 10),
    maghrib: at(20, 27),
    isha: at(22, 4),
    date: DateTime(2026, 8, 2),
  );
}

/// Dar bir kutuda cizer ve tasma olup olmadigini dondurur.
Future<void> pumpInBox(WidgetTester tester, Widget child, Size size) async {
  await tester.pumpWidget(
    wrapWithTheme(
      Center(
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  testWidgets('CountdownHero dar kutuda tasmaz', (tester) async {
    await pumpInBox(
      tester,
      CountdownHero(
        nextPrayerTime: DateTime.now().add(const Duration(hours: 12)),
        nextPrayerName: 'Akşam',
      ),
      const Size(240, 140),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('PrayerGrid dar kutuda tasmaz', (tester) async {
    await pumpInBox(
      tester,
      PrayerGrid(
        prayerTime: _times(),
        now: DateTime(2026, 8, 2, 17, 34),
        currentPrayer: PrayerType.asr,
      ),
      const Size(240, 120),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeTopBar uzun konum adini kirpip tasmaz', (tester) async {
    await pumpInBox(
      tester,
      HomeTopBar(
        locationName: 'Çok Uzun Bir İlçe Adı, Çok Uzun Bir İl Adı Burada',
        onLocationTap: () {},
        onMenuTap: () {},
      ),
      const Size(200, 56),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeDateLine dar kutuda tasmaz', (tester) async {
    await pumpInBox(
      tester,
      HomeDateLine(date: DateTime(2026, 8, 2)),
      const Size(200, 20),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('DayRuler dar kutuda tasmaz', (tester) async {
    await pumpInBox(
      tester,
      DayRuler(prayerTime: _times(), now: DateTime(2026, 8, 2, 17, 34)),
      const Size(200, 40),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('TomorrowStrip dar kutuda tasmaz', (tester) async {
    await pumpInBox(
      tester,
      TomorrowStrip(tomorrow: _times(), onCalendarTap: () {}),
      const Size(220, 120),
    );

    expect(tester.takeException(), isNull);
  });
}
