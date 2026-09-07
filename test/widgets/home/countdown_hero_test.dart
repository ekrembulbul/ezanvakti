import 'package:ezanvakti/core/theme/app_typography.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/features/prayer_times/domain/kerahat_times.dart';
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
    for (final brightness in [Brightness.dark, Brightness.light]) {
      testWidgets(
        '${brightness.name} kerahat ilk açılışta başlık ve sayaç rengiyle belirginleşir',
        (tester) async {
          final now = DateTime(2026, 9, 7, 6, 35);
          await tester.pumpWidget(
            wrapWithTheme(
              CountdownHero(
                nextPrayerTime: DateTime(2026, 9, 7, 12, 52),
                nextPrayerName: 'Öğle',
                clock: () => now,
                kerahatIntervals: [
                  KerahatInterval(
                    kind: KerahatKind.afterSunrise,
                    start: DateTime(2026, 9, 7, 6, 15),
                    end: DateTime(2026, 9, 7, 7),
                  ),
                ],
              ),
              brightness: brightness,
              phase: DayPhase.morning,
            ),
          );

          final counter = tester.widget<Text>(
            find.byKey(const Key('countdown_value')),
          );
          final title = tester.widget<Text>(find.text('Kerahat vakti'));
          expect(
            counter.style?.color,
            tokensFor(
              brightness: brightness,
              phase: DayPhase.morning,
            ).kerahatText,
          );
          expect(
            title.style?.fontSize,
            greaterThanOrEqualTo(AppTypography.reminderPrimary.fontSize!),
          );
          expect(
            tester.getRect(find.text('Kerahat vakti')).bottom,
            lessThan(
              tester.getRect(find.byKey(const Key('countdown_value'))).top,
            ),
          );
          expect(find.text('Yaklaşık bitiş: 07:00'), findsOneWidget);
          expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
          expect(find.text('SONRAKİ'), findsOneWidget);
          expect(find.text('ÖĞLE'), findsOneWidget);
          expect(find.text('06:17:00'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final locale in [const Locale('tr'), const Locale('ar')]) {
      testWidgets(
        '${locale.languageCode} aktif kerahat uyarısı büyük metinde taşmaz',
        (tester) async {
          final now = DateTime(2026, 9, 7, 6, 15);
          await tester.pumpWidget(
            wrapWithTheme(
              MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: 280,
                      child: CountdownHero(
                        nextPrayerTime: DateTime(2026, 9, 7, 13),
                        nextPrayerName: locale.languageCode == 'ar'
                            ? 'الظهر'
                            : 'Öğle',
                        clock: () => now,
                        kerahatIntervals: [
                          KerahatInterval(
                            kind: KerahatKind.afterSunrise,
                            start: DateTime(2026, 9, 7, 6),
                            end: DateTime(2026, 9, 7, 6, 45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              locale: locale,
            ),
          );
          expect(
            find.text(
              locale.languageCode == 'ar' ? 'وقت الكراهة' : 'Kerahat vakti',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('countdown_value')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('kerahat uyarısı saniye tikinde başlar ve bitişte kaybolur', (
      tester,
    ) async {
      final start = DateTime(2026, 9, 7, 6);
      final end = start.add(const Duration(minutes: 45));
      var now = start.subtract(const Duration(seconds: 1));
      await tester.pumpWidget(
        wrapWithTheme(
          CountdownHero(
            nextPrayerTime: DateTime(2026, 9, 7, 13),
            nextPrayerName: 'Öğle',
            clock: () => now,
            kerahatIntervals: [
              KerahatInterval(
                kind: KerahatKind.afterSunrise,
                start: start,
                end: end,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Kerahat vakti'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('countdown_value')))
            .style
            ?.color,
        tokensFor().accent,
      );

      now = start;
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Kerahat vakti'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Kerahat vakti')).style?.color,
        tokensFor().kerahatText,
      );
      expect(find.byKey(const Key('countdown_value')), findsOneWidget);
      expect(find.text('Öğle vakti 13:00'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('countdown_value')))
            .style
            ?.color,
        tokensFor().kerahatText,
      );

      now = end;
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Kerahat vakti'), findsNothing);
      expect(find.textContaining('Yaklaşık bitiş:'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('countdown_value')))
            .style
            ?.color,
        tokensFor().accent,
      );
    });

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

    testWidgets('Alt bilgi bütün vakitlerde ezan yerine vakit ve saati yazar', (
      tester,
    ) async {
      final target = DateTime(2026, 8, 2, 20, 27);
      for (final (heading, caption) in [
        ('İmsak', null),
        ('Güneş', null),
        ('Öğle', null),
        ('İkindi', null),
        ('Akşam', null),
        ('Yatsı', null),
        ('İftara', 'İftar'),
        ('Sahurun bitişine', 'İmsak'),
      ]) {
        await tester.pumpWidget(
          wrapWithTheme(
            CountdownHero(
              nextPrayerTime: target,
              nextPrayerName: heading,
              timeCaptionName: caption,
            ),
          ),
        );
        expect(find.text('${caption ?? heading} vakti 20:27'), findsOneWidget);
        expect(find.textContaining('ezanı'), findsNothing);
      }
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

    testWidgets('Ayarlar düğmesi çubuğun sağ kenarına yaslanır', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const HomeTopBar(
            locationName: 'Ankara, Ankara',
            onLocationTap: null,
            onSettingsTap: _noop,
          ),
        ),
      );

      final bar = tester.getRect(find.byType(HomeTopBar));
      final gear = tester.getRect(
        find.widgetWithIcon(IconButton, Icons.settings_rounded),
      );

      expect(gear.right, moreOrLessEquals(bar.right, epsilon: 0.5));
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

void _noop() {}
