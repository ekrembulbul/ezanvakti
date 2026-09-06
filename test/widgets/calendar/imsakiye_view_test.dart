import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/data/ramadan_periods.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/presentation/screens/calendar_screen.dart';
import 'package:ezanvakti/presentation/widgets/calendar/imsakiye_share_table.dart';
import 'package:ezanvakti/presentation/services/widget_image_renderer.dart';
import '../theme_harness.dart';
import '../../support/fakes.dart';

const location = Location(id: 'test', province: 'İstanbul', district: 'Fatih');
void main() {
  testWidgets(
    'full month is accessible year round and period selection reloads',
    (tester) async {
      final requested = <int>[];
      await tester.pumpWidget(
        wrapWithTheme(
          CalendarScreen(
            location: location,
            prayerTimes: [prayerTimeFor(DateTime(2026, 9, 6))],
            imsakiyeLoader:
                ({
                  required location,
                  required period,
                  forceRefresh = false,
                }) async {
                  requested.add(period.hijriYear);
                  return period.days.map(prayerTimeFor).toList();
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vakit Takvimi'), findsWidgets);
      await tester.tap(find.text('İmsakiye'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('imsakiye-day-29')), findsOneWidget);
      await tester.tap(find.byKey(const Key('imsakiye-period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1445 / 2024').last);
      await tester.pumpAndSettle();
      expect(requested.last, 1445);
      expect(find.byKey(const Key('imsakiye-day-30')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all-month export really paints last row beyond viewport; RTL and large text fit',
    (tester) async {
      final font = FontLoader('Manrope')
        ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'));
      await tester.runAsync(() async {
        await font.load();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final period = ramadanPeriods.first;
      const lastKey = ValueKey('imsakiye-day-30');
      late BuildContext renderContext;
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) {
              renderContext = context;
              return const SizedBox();
            },
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      final table = ImsakiyeShareTable(
        location: location,
        period: period,
        days: period.days.map(prayerTimeFor).toList(),
      );
      final bytes = await tester.runAsync(
        () => WidgetImageRenderer.render(context: renderContext, child: table),
      );
      expect(bytes, isNotEmpty);
      final changedDays = period.days.map(prayerTimeFor).toList();
      changedDays[29] = changedDays[29].copyWith(
        maghrib: changedDays[29].maghrib.add(const Duration(minutes: 7)),
      );
      final changedBytes = await tester.runAsync(
        () => WidgetImageRenderer.render(
          context: renderContext,
          child: ImsakiyeShareTable(
            location: location,
            period: period,
            days: changedDays,
          ),
        ),
      );
      expect(
        listEquals(bytes, changedBytes),
        isFalse,
        reason: 'Changing only the last row must change the exported PNG',
      );
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes!);
        final frame = await codec.getNextFrame();
        expect(frame.image.height, greaterThan(1800));
        expect(frame.image.width, 1000);
        frame.image.dispose();
        codec.dispose();
      });
      await tester.pumpWidget(
        wrapWithTheme(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1000,
                child: SingleChildScrollView(child: table),
              ),
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(lastKey), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(lastKey)).dy, greaterThan(1800));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar controls fit narrow RTL screen at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CalendarScreen(
            location: location,
            prayerTimes: const [],
            imsakiyeLoader:
                ({
                  required location,
                  required period,
                  forceRefresh = false,
                }) async => period.days.map(prayerTimeFor).toList(),
          ),
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('إمساكية رمضان'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
