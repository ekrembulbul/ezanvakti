import 'dart:async';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/prayer_times/domain/calendar_month_repository.dart';
import 'package:ezanvakti/presentation/screens/calendar_screen.dart';
import 'package:ezanvakti/presentation/widgets/calendar/calendar_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';
import '../../support/fakes.dart';

const location = Location(id: 'test', province: 'İstanbul', district: 'Fatih');
const previousKey = Key('calendar-previous-month');
const nextKey = Key('calendar-next-month');
const shareTooltip = 'Takvimi paylaş';

List<PrayerTime> monthDays(DateTime month) => [
  for (var day = 1; day <= DateTime(month.year, month.month + 1, 0).day; day++)
    prayerTimeFor(DateTime(month.year, month.month, day)),
];

Future<List<PrayerTime>> fullMonth({
  required Location location,
  required DateTime month,
  bool forceRefresh = false,
}) async => monthDays(month);

ScrollPosition verticalPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    )
    .position;

IconButton arrow(WidgetTester tester, Key key) =>
    tester.widget<IconButton>(find.byKey(key));

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    CalendarMonthLoader loader = fullMonth,
    DateTime? now,
    Locale locale = const Locale('tr'),
    Size size = const Size(402, 874),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixedNow = now ?? DateTime(2026, 9, 15, 10);
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: CalendarScreen(
              location: location,
              monthLoader: loader,
              clock: () => fixedNow,
            ),
          ),
        ),
        locale: locale,
      ),
    );
  }

  testWidgets('alt baslik ve ay cubugu acik ayi yazar; liste bugunden acilir', (
    tester,
  ) async {
    final requested = <DateTime>[];
    await pumpScreen(
      tester,
      loader:
          ({required location, required month, forceRefresh = false}) async {
            requested.add(month);
            return monthDays(month);
          },
    );
    await tester.pumpAndSettle();

    expect(requested, [DateTime(2026, 9)]);
    expect(find.text('${location.displayName} · Eylül 2026'), findsOneWidget);
    expect(find.byKey(const Key('calendar-month-label')), findsOneWidget);
    expect(find.text('Eylül 2026'), findsOneWidget);
    expect(find.byTooltip('Önceki ay'), findsOneWidget);
    expect(find.byTooltip('Sonraki ay'), findsOneWidget);
    expect(verticalPosition(tester).pixels, 13 * kCalendarRowHeight);
    expect(find.text('BUGÜN').hitTestable(), findsOneWidget);
    expect(find.byTooltip(shareTooltip), findsOneWidget);
  });

  testWidgets('oklar ayi degistirir; baska ay en ustten, bu ay yine bugunden', (
    tester,
  ) async {
    final requested = <DateTime>[];
    await pumpScreen(
      tester,
      loader:
          ({required location, required month, forceRefresh = false}) async {
            requested.add(month);
            return monthDays(month);
          },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(nextKey));
    await tester.pumpAndSettle();
    expect(requested.last, DateTime(2026, 10));
    expect(find.text('Ekim 2026'), findsOneWidget);
    expect(find.text('${location.displayName} · Ekim 2026'), findsOneWidget);
    expect(verticalPosition(tester).pixels, 0);

    await tester.tap(find.byKey(previousKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(previousKey));
    await tester.pumpAndSettle();
    expect(find.text('Ağustos 2026'), findsOneWidget);
    expect(requested, [
      DateTime(2026, 9),
      DateTime(2026, 10),
      DateTime(2026, 9),
      DateTime(2026, 8),
    ]);

    await tester.tap(find.byKey(nextKey));
    await tester.pumpAndSettle();
    expect(verticalPosition(tester).pixels, 13 * kCalendarRowHeight);
  });

  testWidgets('Ocak ayinda onceki ay oku pasif', (tester) async {
    await pumpScreen(tester, now: DateTime(2026, 1, 10));
    await tester.pumpAndSettle();

    expect(find.text('Ocak 2026'), findsOneWidget);
    expect(arrow(tester, previousKey).onPressed, isNull);
    expect(arrow(tester, nextKey).onPressed, isNotNull);
  });

  testWidgets('gelecek yilin Araliginda sonraki ay oku pasif', (tester) async {
    await pumpScreen(tester, now: DateTime(2026, 12, 3));
    await tester.pumpAndSettle();

    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byKey(nextKey));
      await tester.pumpAndSettle();
    }
    expect(find.text('Aralık 2027'), findsOneWidget);
    expect(arrow(tester, nextKey).onPressed, isNull);
    expect(arrow(tester, previousKey).onPressed, isNotNull);
  });

  testWidgets(
    'yuklenirken paylas gizli; ay gecisinde eski tablo ve ince cizgi kalir',
    (tester) async {
      final responses = <DateTime, Completer<List<PrayerTime>>>{};
      await pumpScreen(
        tester,
        loader: ({required location, required month, forceRefresh = false}) =>
            (responses[month] = Completer<List<PrayerTime>>()).future,
      );
      await tester.pump();
      expect(find.text('Takvim yükleniyor...'), findsOneWidget);
      expect(find.byTooltip(shareTooltip), findsNothing);

      responses[DateTime(2026, 9)]!.complete(monthDays(DateTime(2026, 9)));
      await tester.pump();
      expect(find.byType(CalendarTable), findsOneWidget);
      expect(find.byTooltip(shareTooltip), findsOneWidget);

      await tester.tap(find.byKey(nextKey));
      await tester.pump();
      expect(find.text('Ekim 2026'), findsOneWidget);
      expect(
        find.text('15 Eyl'),
        findsOneWidget,
        reason: 'onceki ayin tablosu yeni ay gelene kadar kalir',
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byTooltip(shareTooltip), findsNothing);

      responses[DateTime(2026, 10)]!.complete(monthDays(DateTime(2026, 10)));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('1 Eki'), findsOneWidget);
      expect(find.byTooltip(shareTooltip), findsOneWidget);
    },
  );

  testWidgets('sunucu ayi yayimlamamissa bilgi metni gorunur, paylas gizli', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      loader:
          ({required location, required month, forceRefresh = false}) async =>
              const <PrayerTime>[],
    );
    await tester.pumpAndSettle();

    expect(find.text('Bu ayın vakitleri henüz yayımlanmadı.'), findsOneWidget);
    expect(find.byType(CalendarTable), findsNothing);
    expect(find.byTooltip(shareTooltip), findsNothing);
    expect(
      arrow(tester, nextKey).onPressed,
      isNotNull,
      reason: 'kullanici baska aya gecebilmeli',
    );
  });

  testWidgets('hata durumunda Yeniden Dene ayi zorla yeniden yukler', (
    tester,
  ) async {
    final forced = <bool>[];
    var fail = true;
    await pumpScreen(
      tester,
      loader:
          ({required location, required month, forceRefresh = false}) async {
            forced.add(forceRefresh);
            if (fail) throw Exception('offline');
            return monthDays(month);
          },
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Veri alınamadı. Lütfen internet bağlantınızı kontrol edin.'),
      findsOneWidget,
    );
    expect(find.byTooltip(shareTooltip), findsNothing);

    fail = false;
    await tester.tap(find.text('Yeniden Dene'));
    await tester.pumpAndSettle();

    expect(forced, [false, true]);
    expect(find.byType(CalendarTable), findsOneWidget);
    expect(find.byTooltip(shareTooltip), findsOneWidget);
  });

  testWidgets(
    'dar RTL ekranda buyuk metinle ay cubugu tasmaz, oklar yon degistirir',
    (tester) async {
      await pumpScreen(
        tester,
        locale: const Locale('ar'),
        size: const Size(320, 640),
        textScale: 2,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.byKey(previousKey)).dx,
        greaterThan(tester.getCenter(find.byKey(nextKey)).dx),
        reason: 'RTL: onceki ay sagda',
      );
      // Chevron ikonları matchTextDirection taşır; Icon RTL'de kendini aynalar.
      expect(
        find.descendant(
          of: find.byIcon(Icons.chevron_left_rounded),
          matching: find.byType(Transform),
        ),
        findsOneWidget,
      );
    },
  );
}
