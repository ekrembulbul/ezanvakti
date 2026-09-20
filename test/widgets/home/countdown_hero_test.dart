import 'package:ezanvakti/core/theme/app_typography.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/features/prayer_times/domain/kerahat_times.dart';
import 'package:ezanvakti/presentation/widgets/home/countdown_hero.dart';
import 'package:ezanvakti/presentation/widgets/home/home_top_bar.dart';
import 'package:ezanvakti/presentation/widgets/home/kerahat_band.dart';
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
        '${brightness.name} kerahatte bant dolgulu, sayaç kerahat renginde ve parıltılı',
        (tester) async {
          final now = DateTime(2026, 9, 7, 6, 35);
          final tokens = tokensFor(
            brightness: brightness,
            phase: DayPhase.morning,
          );
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
          expect(counter.style?.color, tokens.kerahatText);
          expect(find.text('Kerahat'), findsOneWidget);
          expect(find.text('25:00'), findsOneWidget);
          final band = tester.widget<Container>(find.byKey(kKerahatBandKey));
          expect((band.decoration! as BoxDecoration).color, tokens.kerahatLine);
          expect(
            tester.widget<Text>(find.text('Kerahat')).style?.color,
            Colors.white,
          );
          expect(
            tester
                .widget<Text>(find.byKey(kKerahatBandCountdownKey))
                .style
                ?.color,
            Colors.white,
          );
          expect(
            tester.getRect(find.byKey(kKerahatBandKey)).bottom,
            lessThan(
              tester.getRect(find.byKey(const Key('countdown_value'))).top,
            ),
          );
          expect(find.byKey(kKerahatGlowKey), findsOneWidget);
          final fill = tester.widget<FractionallySizedBox>(
            find.ancestor(
              of: find.byKey(kKerahatBandFillKey),
              matching: find.byType(FractionallySizedBox),
            ),
          );
          // 06:15–07:00 aralığının 20/45'i geçti.
          expect(fill.widthFactor, closeTo(20 / 45, 0.001));
          expect(find.text('SONRAKİ'), findsOneWidget);
          expect(find.text('ÖĞLE'), findsOneWidget);
          expect(find.text('06:17:00'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final locale in [const Locale('tr'), const Locale('ar')]) {
      testWidgets('${locale.languageCode} kerahat bandı büyük metinde taşmaz', (
        tester,
      ) async {
        final now = DateTime(2026, 9, 7, 6, 15);
        await tester.pumpWidget(
          wrapWithTheme(
            MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2),
                alwaysUse24HourFormat: true,
              ),
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
        expect(find.byKey(kKerahatBandKey), findsOneWidget);
        expect(
          find.text(locale.languageCode == 'ar' ? 'وقت الكراهة' : 'Kerahat'),
          findsOneWidget,
        );
        expect(find.text('30:00'), findsOneWidget);
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
      });
    }

    testWidgets(
      'bant yaklaşırken çerçeveli, başlangıçta dolguya döner, bitişte kaybolur',
      (tester) async {
        final start = DateTime(2026, 9, 7, 19, 41);
        final end = DateTime(2026, 9, 7, 20, 26);
        var now = start.subtract(const Duration(minutes: 31));
        await tester.pumpWidget(
          wrapWithTheme(
            CountdownHero(
              nextPrayerTime: end,
              nextPrayerName: 'Akşam',
              clock: () => now,
              kerahatIntervals: [
                KerahatInterval(
                  kind: KerahatKind.beforeMaghrib,
                  start: start,
                  end: end,
                ),
              ],
            ),
          ),
        );
        // 31 dakika kala bant yok.
        expect(find.byKey(kKerahatBandKey), findsNothing);
        expect(find.byKey(kKerahatGlowKey), findsNothing);

        now = start.subtract(const Duration(minutes: 20));
        await tester.pump(const Duration(seconds: 2));
        expect(find.byKey(kKerahatBandKey), findsOneWidget);
        expect(find.text('Kerahat'), findsOneWidget);
        expect(find.text('20:00'), findsOneWidget);
        // Yaklaşırken turuncu aile: metin, sayaç, yüzey ve çerçeve.
        expect(
          tester.widget<Text>(find.text('Kerahat')).style?.color,
          tokensFor().kerahatSoonText,
        );
        expect(
          tester
              .widget<Text>(find.byKey(kKerahatBandCountdownKey))
              .style
              ?.color,
          tokensFor().kerahatSoonText,
        );
        final band = tester.widget<Container>(find.byKey(kKerahatBandKey));
        final decoration = band.decoration! as BoxDecoration;
        expect(decoration.color, tokensFor().kerahatSoonSurface);
        expect(decoration.border!.top.color, tokensFor().kerahatSoonLine);
        // Sayaç etiketin hemen yanında, ikisi ortada.
        final label = tester.getRect(find.text('Kerahat'));
        final counter = tester.getRect(find.byKey(kKerahatBandCountdownKey));
        expect(counter.left - label.right, closeTo(8, 0.5));
        final bandRect = tester.getRect(find.byKey(kKerahatBandKey));
        expect(
          (label.left + counter.right) / 2,
          closeTo(bandRect.center.dx, 12),
        );
        expect(find.byIcon(Icons.wb_twilight_rounded), findsOneWidget);
        final fill = tester.widget<FractionallySizedBox>(
          find.ancestor(
            of: find.byKey(kKerahatBandFillKey),
            matching: find.byType(FractionallySizedBox),
          ),
        );
        // 30 dakikalık pencerenin 10 dakikası geçti.
        expect(fill.widthFactor, closeTo(10 / 30, 0.001));
        expect(find.byKey(kKerahatGlowKey), findsNothing);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('countdown_value')))
              .style
              ?.color,
          tokensFor().accent,
        );

        // Bant sayacı saniye saniye akar; büyük sayaç yine akşama sayar.
        now = start.subtract(const Duration(minutes: 14, seconds: 32));
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('14:32'), findsOneWidget);
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('14:31'), findsOneWidget);

        now = start;
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Kerahat'), findsOneWidget);
        expect(find.text('45:00'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(kKerahatBandCountdownKey)).data,
          '45:00',
        );
        expect(find.byKey(kKerahatGlowKey), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('countdown_value')))
              .style
              ?.color,
          tokensFor().kerahatText,
        );
        expect(find.text('Akşam vakti 20:26'), findsOneWidget);

        now = end;
        await tester.pump(const Duration(seconds: 2));
        expect(find.byKey(kKerahatBandKey), findsNothing);
        expect(find.byKey(kKerahatGlowKey), findsNothing);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('countdown_value')))
              .style
              ?.color,
          tokensFor().accent,
        );
      },
    );

    testWidgets('bant metni yalnız "Kerahat"; saat ve bitiş yazılmaz', (
      tester,
    ) async {
      final start = DateTime(2026, 9, 7, 13);
      await tester.pumpWidget(
        wrapWithTheme(
          CountdownHero(
            nextPrayerTime: DateTime(2026, 9, 7, 13, 10),
            nextPrayerName: 'Öğle',
            clock: () => start.subtract(const Duration(minutes: 5)),
            kerahatIntervals: [
              KerahatInterval(
                kind: KerahatKind.beforeDhuhr,
                start: start,
                end: DateTime(2026, 9, 7, 13, 10),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Kerahat'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.textContaining('13:00'), findsNothing);
      expect(find.textContaining('başlar'), findsNothing);
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

    testWidgets('GPS konumunda adın önünde hedef ikonu çizilir', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          HomeTopBar(
            locationName: 'Kadıköy',
            isGpsLocation: true,
            onLocationTap: null,
            onSettingsTap: () {},
          ),
        ),
      );

      expect(find.byKey(kHomeGpsIconKey), findsOneWidget);
    });

    testWidgets('Elle seçilen konumda GPS ikonu yok', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          HomeTopBar(
            locationName: 'Kadıköy',
            onLocationTap: null,
            onSettingsTap: () {},
          ),
        ),
      );

      expect(find.byKey(kHomeGpsIconKey), findsNothing);
    });

    testWidgets('Takvim düğmesi yalnızca callback verilince çizilir', (
      tester,
    ) async {
      var opened = false;

      await tester.pumpWidget(
        wrapWithTheme(
          HomeTopBar(
            locationName: 'Kadıköy',
            onLocationTap: null,
            onSettingsTap: () {},
            onCalendarTap: () => opened = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.calendar_month_rounded));
      expect(opened, isTrue);

      await tester.pumpWidget(
        wrapWithTheme(
          HomeTopBar(
            locationName: 'Kadıköy',
            onLocationTap: null,
            onSettingsTap: () {},
          ),
        ),
      );
      expect(find.byIcon(Icons.calendar_month_rounded), findsNothing);
    });

    testWidgets(
      'Sağdaki ikonlar eşit aralıklı, ayarlar kendi kutusunda ortalı',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            const HomeTopBar(
              locationName: 'Ankara, Ankara',
              onLocationTap: null,
              onSettingsTap: _noop,
              onCalendarTap: _noop,
              onKerahatTap: _noop,
            ),
          ),
        );

        final bar = tester.getRect(find.byType(HomeTopBar));
        final gearButton = tester.getRect(
          find.widgetWithIcon(IconButton, Icons.settings_rounded),
        );
        final gearIcon = tester.getRect(find.byIcon(Icons.settings_rounded));
        final kerahatIcon = tester.getRect(
          find.byIcon(Icons.wb_twilight_rounded),
        );
        final calendarIcon = tester.getRect(
          find.byIcon(Icons.calendar_month_rounded),
        );

        expect(gearButton.right, moreOrLessEquals(bar.right, epsilon: 0.5));
        expect(
          gearIcon.center.dx,
          moreOrLessEquals(gearButton.center.dx, epsilon: 0.5),
        );
        expect(
          gearIcon.center.dx - kerahatIcon.center.dx,
          moreOrLessEquals(
            kerahatIcon.center.dx - calendarIcon.center.dx,
            epsilon: 0.5,
          ),
        );
      },
    );
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
