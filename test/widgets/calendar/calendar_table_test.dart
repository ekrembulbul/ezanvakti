import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/widgets/calendar/calendar_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fakes.dart';
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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  Future<void> pumpTable(
    WidgetTester tester, {
    List<PrayerTime>? days,
    DateTime? now,
    Locale locale = const Locale('tr'),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: CalendarTable(
            days: days ?? [_day(2), _day(3), _day(4)],
            now: now ?? DateTime(2026, 8, 3, 17, 34),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pump();
  }

  List<double> rowOpacities(WidgetTester tester) => tester
      .widgetList<Opacity>(find.byKey(const Key('calendar_row')))
      .map((row) => row.opacity)
      .toList();

  ScrollPosition verticalPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .position;

  /// Kompakt saatler arasındaki boşluk gerçek tablo genişliğinde ölçülür.
  testWidgets('Yan yana saatler arasinda bosluk kalir', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithTheme(
        Center(
          child: SizedBox(
            width: 378,
            child: CalendarTable(
              days: [_day(2)],
              now: DateTime(2026, 8, 3, 17, 34),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final fajr = tester.getRect(find.text('04:08'));
    final sunrise = tester.getRect(find.text('05:53'));

    expect(
      sunrise.left - fajr.right,
      greaterThanOrEqualTo(6),
      reason: 'Kolon ici bosluk kaldirilirsa bu deger 6 pikselin altina duser',
    );
  });

  testWidgets('Sabit baslik satiri alti vakit adini gosterir', (tester) async {
    await pumpTable(tester);

    for (final name in ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('Her gun icin bir satir cizilir', (tester) async {
    await pumpTable(tester, locale: const Locale('ar'), textScale: 2);

    expect(find.byKey(const Key('calendar_row')), findsNWidgets(3));
  });

  testWidgets('Bugun rozetle isaretlenir', (tester) async {
    await pumpTable(tester, textScale: 2);

    expect(find.text('BUGÜN'), findsOneWidget);
  });

  testWidgets('Bugun disindaki gunler gun adiyla yazilir', (tester) async {
    await pumpTable(tester);

    expect(find.text('Pazar'), findsOneWidget);
    expect(find.text('Salı'), findsOneWidget);
  });

  testWidgets('Gun tarihleri kisa ay adiyla yazilir', (tester) async {
    await pumpTable(tester);

    expect(find.textContaining('2 Ağu'), findsOneWidget);
  });

  testWidgets('Bos gun listesinde satir cizilmez', (tester) async {
    await pumpTable(tester, days: []);

    expect(find.byKey(const Key('calendar_row')), findsNothing);
    // Baslik satiri yine de durur.
    expect(find.text('İmsak'), findsOneWidget);
  });

  group('gecmis gunler', () {
    testWidgets('bugunden onceki gun soluk, bugun ve sonrasi tam opak', (
      tester,
    ) async {
      await pumpTable(tester);
      expect(rowOpacities(tester), [0.5, 1.0, 1.0]);
    });

    testWidgets('gecmis ayin butun gunleri soluk, gelecek ay tam opak', (
      tester,
    ) async {
      await pumpTable(tester, now: DateTime(2026, 9, 15));
      expect(rowOpacities(tester), [0.5, 0.5, 0.5]);

      await pumpTable(tester, now: DateTime(2026, 7, 20));
      expect(rowOpacities(tester), [1.0, 1.0, 1.0]);
    });
  });

  group('baslangic konumu', () {
    final september = [
      for (var day = 1; day <= 30; day++) prayerTimeFor(DateTime(2026, 9, day)),
    ];
    const tableHeight = 400.0;

    Future<ScrollPosition> pumpSeptember(
      WidgetTester tester,
      DateTime now,
    ) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapWithTheme(
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: tableHeight,
              child: CalendarTable(days: september, now: now),
            ),
          ),
        ),
      );
      await tester.pump();
      return verticalPosition(tester);
    }

    testWidgets('bugunun bir ust satiri en ustte acilir', (tester) async {
      final position = await pumpSeptember(tester, DateTime(2026, 9, 15, 9));
      // 15 Eylul 0 tabanli 14. satir; bir ustu (13.) en ustte.
      expect(position.pixels, 13 * kCalendarRowHeight);
      expect(find.text('BUGÜN').hitTestable(), findsOneWidget);
    });

    testWidgets(
      'ay sonuna yakin bugun icerik sonuna kisitlanir, acilista kayma olmaz',
      (tester) async {
        final position = await pumpSeptember(tester, DateTime(2026, 9, 29, 9));
        // 30 satir + 24 alt bosluk; gorunen alan = tablo - baslik satiri.
        const maxExtent =
            30 * kCalendarRowHeight + 24 - (tableHeight - kCalendarRowHeight);
        expect(position.maxScrollExtent, maxExtent);
        expect(
          position.pixels,
          maxExtent,
          reason: 'istenen 27 * 56 = 1512 kaydirilabilir alani asar',
        );
        await tester.pumpAndSettle();
        expect(
          position.pixels,
          maxExtent,
          reason: 'iOS yaylanmasi konumu geri cekmemeli',
        );
        expect(find.text('BUGÜN').hitTestable(), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('bugunu icermeyen ay en ustten baslar', (tester) async {
      final position = await pumpSeptember(tester, DateTime(2026, 10, 2));
      expect(position.pixels, 0);
    });

    test('bugun ilk gunse ya da liste bossa konum sifir', () {
      expect(
        CalendarTable.initialScrollOffset(
          days: september,
          now: DateTime(2026, 9, 1, 8),
          rowHeight: kCalendarRowHeight,
          viewportHeight: 300,
        ),
        0,
      );
      expect(
        CalendarTable.initialScrollOffset(
          days: const [],
          now: DateTime(2026, 9, 1),
          rowHeight: kCalendarRowHeight,
          viewportHeight: 300,
        ),
        0,
      );
    });
  });
}
