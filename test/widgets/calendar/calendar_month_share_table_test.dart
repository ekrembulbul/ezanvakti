import 'dart:ui' as ui;

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/services/widget_image_renderer.dart';
import 'package:ezanvakti/presentation/widgets/calendar/calendar_month_share_table.dart';
import 'package:ezanvakti/presentation/widgets/calendar/calendar_table.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';
import '../../support/fakes.dart';

const location = Location(id: 'test', province: 'İstanbul', district: 'Fatih');

List<PrayerTime> monthDays(DateTime month) => [
  for (var day = 1; day <= DateTime(month.year, month.month + 1, 0).day; day++)
    prayerTimeFor(DateTime(month.year, month.month, day)),
];

void main() {
  final october = DateTime(2026, 10);

  testWidgets('ayin butun gunleri tembel olmadan cizilir, bugun vurgusu yok', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        SingleChildScrollView(
          child: CalendarMonthShareTable(
            location: location,
            month: october,
            days: monthDays(october),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('calendar_row')), findsNWidgets(31));
    expect(find.text('Vakit Takvimi'), findsOneWidget);
    expect(find.text(location.displayName), findsOneWidget);
    expect(find.text('Ekim 2026'), findsOneWidget);
    expect(find.text('31 Eki'), findsOneWidget);
    // Paylaşılan çizelge aylık başvuru tablosu: bugün rozeti ve soluk
    // geçmiş günler yalnız ekranda.
    expect(find.text('BUGÜN'), findsNothing);
    expect(
      tester
          .widgetList<Opacity>(find.byKey(const Key('calendar_row')))
          .map((row) => row.opacity)
          .toSet(),
      {1.0},
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PNG son satiri da boyar ve 10000 px sinirina sigar', (
    tester,
  ) async {
    // Test fontu (Ahem) rakamlari ayni kutuyla cizer; son satir degisikligi
    // PNG'ye yansisin diye gercek font yuklenir.
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'));
    await tester.runAsync(() async {
      await font.load();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    late BuildContext renderContext;
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) {
            renderContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final days = monthDays(october);
    final bytes = await tester.runAsync(
      () => WidgetImageRenderer.render(
        context: renderContext,
        child: CalendarMonthShareTable(
          location: location,
          month: october,
          days: days,
        ),
      ),
    );
    final changed = List<PrayerTime>.of(days);
    changed[30] = changed[30].copyWith(
      maghrib: changed[30].maghrib.add(const Duration(minutes: 7)),
    );
    final changedBytes = await tester.runAsync(
      () => WidgetImageRenderer.render(
        context: renderContext,
        child: CalendarMonthShareTable(
          location: location,
          month: october,
          days: changed,
        ),
      ),
    );

    expect(bytes, isNotEmpty);
    expect(
      listEquals(bytes, changedBytes),
      isFalse,
      reason: 'Yalniz son satirin degismesi PNG\'yi degistirmeli',
    );
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1000);
      expect(
        frame.image.height,
        greaterThan(
          (31 * kCalendarRowHeight * 1000 / kCalendarShareLogicalWidth).round(),
        ),
      );
      expect(
        frame.image.height,
        lessThan(10000),
        reason: 'renderer tuvali 10000 px; 31 gun kesilmeden sigmali',
      );
      frame.image.dispose();
      codec.dispose();
    });
  });
}
