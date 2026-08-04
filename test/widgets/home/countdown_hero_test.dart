import 'package:ezanvakti/core/theme/app_typography.dart';
import 'package:ezanvakti/presentation/widgets/home/countdown_hero.dart';
import 'package:ezanvakti/presentation/widgets/home/home_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../theme_harness.dart';

void main() {
  setUpAll(() async {
    // HomeDateLine tr_TR bicimlendirmesi kullaniyor.
    await initializeDateFormatting('tr_TR', null);
  });

  group('CountdownHero', () {
    testWidgets('Kalan sureyi SS:DD:SS olarak tek satirda gosterir', (
      tester,
    ) async {
      final target = DateTime.now().add(
        const Duration(hours: 2, minutes: 53, seconds: 7),
      );

      await tester.pumpWidget(
        wrapWithTheme(
          CountdownHero(nextPrayerTime: target, nextPrayerName: 'Akşam'),
        ),
      );

      final counter = tester.widget<Text>(
        find.byKey(const Key('countdown_value')),
      );

      expect(counter.data, matches(RegExp(r'^02:5[23]:\d{2}$')));
    });

    testWidgets('SONRAKI etiketi ve vakit adi ustte yer alir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          CountdownHero(
            nextPrayerTime: DateTime.now().add(const Duration(minutes: 5)),
            nextPrayerName: 'Akşam',
          ),
        ),
      );

      expect(find.text('SONRAKİ'), findsOneWidget);
      expect(find.text('AKŞAM'), findsOneWidget);
    });

    testWidgets('Vakit adindaki noktali i buyuk İ olur', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          CountdownHero(
            nextPrayerTime: DateTime.now().add(const Duration(minutes: 5)),
            nextPrayerName: 'İkindi',
          ),
        ),
      );

      expect(find.text('İKİNDİ'), findsOneWidget);
    });

    testWidgets('Sayac vurgu rengini ve 62px olcegi kullanir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          CountdownHero(
            nextPrayerTime: DateTime.now().add(const Duration(minutes: 5)),
            nextPrayerName: 'Akşam',
          ),
        ),
      );

      final counter = tester.widget<Text>(
        find.byKey(const Key('countdown_value')),
      );

      expect(counter.style!.color, tokensFor().accent);
      expect(counter.style!.fontSize, AppTypography.counter.fontSize);
    });

    testWidgets('Vakit gectiyse sifira kirpar, negatif gostermez', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          CountdownHero(
            nextPrayerTime: DateTime.now().subtract(const Duration(hours: 1)),
            nextPrayerName: 'Akşam',
          ),
        ),
      );

      expect(find.text('00:00:00'), findsOneWidget);
    });

    testWidgets('Alt bilgi vaktin saatini yazar', (tester) async {
      final target = DateTime(2026, 8, 2, 20, 27);

      await tester.pumpWidget(
        wrapWithTheme(
          CountdownHero(nextPrayerTime: target, nextPrayerName: 'Akşam'),
        ),
      );

      expect(find.text("Akşam ezanı 20:27'de"), findsOneWidget);
    });
  });

  group('HomeTopBar', () {
    testWidgets('Konum adini gosterir ve dokununca callback cagirir', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        wrapWithTheme(
          HomeTopBar(
            locationName: 'Kadıköy, İstanbul',
            onLocationTap: () => tapped = true,
            onSettingsTap: () {},
          ),
        ),
      );

      expect(find.text('Kadıköy, İstanbul'), findsOneWidget);

      await tester.tap(find.text('Kadıköy, İstanbul'));
      expect(tapped, isTrue);
    });

    testWidgets('Ayarlar ikonuna dokunmak callback cagirir', (tester) async {
      var opened = false;

      await tester.pumpWidget(
        wrapWithTheme(
          HomeTopBar(
            locationName: 'Kadıköy',
            onLocationTap: null,
            onSettingsTap: () => opened = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.settings_rounded));
      expect(opened, isTrue);
    });
  });

  group('HomeDateLine', () {
    testWidgets('Miladi ve hicri tarihi ayrac ile yazar', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(HomeDateLine(date: DateTime(2026, 8, 1))),
      );

      expect(find.textContaining('1 Ağustos 2026'), findsOneWidget);
      expect(find.textContaining('Safer'), findsOneWidget);
    });
  });
}
