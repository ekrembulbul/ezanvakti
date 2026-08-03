import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/widgets/calendar/calendar_table.dart';
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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  Future<void> pumpTable(WidgetTester tester, {List<PrayerTime>? days}) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        CalendarTable(
          days: days ?? [_day(2), _day(3), _day(4)],
          now: DateTime(2026, 8, 3, 17, 34),
        ),
      ),
    );
    await tester.pump();
  }

  /// Alti saat kolonu `Expanded` + `FittedBox` ile kolonu doldurdugu icin
  /// kolon ici bosluk verilmezse saatler bitisik goruntu veriyordu. Olcum,
  /// takvim ekraninin gercek ic genisliginde (402 - 2*12) yapilir.
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
      greaterThanOrEqualTo(7),
      reason: 'Kolon ici bosluk kaldirilirsa bu deger 6 pikselin altina duser',
    );
  });

  testWidgets('Sabit baslik satiri alti vakit adini gosterir', (tester) async {
    await pumpTable(tester);

    for (final name in ['İMSAK', 'GÜNEŞ', 'ÖĞLE', 'İKİNDİ', 'AKŞAM', 'YATSI']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('Her gun icin bir satir cizilir', (tester) async {
    await pumpTable(tester);

    expect(find.byKey(const Key('calendar_row')), findsNWidgets(3));
  });

  testWidgets('Bugun rozetle isaretlenir', (tester) async {
    await pumpTable(tester);

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
    expect(find.text('İMSAK'), findsOneWidget);
  });
}
