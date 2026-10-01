import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/sermons/domain/sermon.dart';
import 'package:ezanvakti/presentation/screens/home_screen.dart';
import 'package:ezanvakti/presentation/widgets/home/sermon_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../sermons/sermon_fixtures.dart';
import '../theme_harness.dart';

PrayerTime _day(int d) {
  DateTime at(int h, int m) => DateTime(2026, 8, d, h, m);
  return PrayerTime(
    fajr: at(4, 30),
    sunrise: at(6, 10),
    dhuhr: at(13, 15),
    asr: at(17, 10),
    maghrib: at(20, 27),
    isha: at(22, 4),
    date: DateTime(2026, 8, d),
  );
}

const _location = Location(id: '1', province: 'İstanbul', district: 'Kadıköy');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
    await initializeDateFormatting('en', null);
  });

  Future<void> pump(
    WidgetTester tester,
    SermonSummary? sermon, {
    Locale locale = const Locale('tr'),
    ValueChanged<SermonSummary>? onOpen,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        HomeScreen(
          location: _location,
          todaysPrayerTime: _day(2),
          tomorrowsPrayerTime: _day(3),
          lastUpdateTime: DateTime(2026, 8, 2),
          featuredSermon: sermon,
          onOpenSermon: onOpen,
        ),
        locale: locale,
      ),
    );
    await tester.pump();
  }

  testWidgets('Türkçede cuma kartı başlıkla görünür ve açar', (tester) async {
    SermonSummary? opened;
    final sermon = SermonSummary.fromJson(summaryJson());
    await pump(tester, sermon, onOpen: (s) => opened = s);
    expect(find.byType(SermonCard), findsOneWidget);
    expect(find.text('Bu haftanın hutbesi'), findsOneWidget);
    expect(find.text('Tebliğ Sorumluluğumuz'), findsOneWidget);
    await tester.tap(find.text('Oku'));
    expect(opened, same(sermon));
  });

  testWidgets('bayramda "Bayram hutbesi" etiketi', (tester) async {
    final sermon = SermonSummary.fromJson(
      summaryJson(
        id: '2027-03-10-bayram',
        date: '2027-03-10',
        kind: 'bayram',
        title: 'Ramazan Bayramı Hutbesi',
      ),
    );
    await pump(tester, sermon, onOpen: (_) {});
    expect(find.text('Bayram hutbesi'), findsOneWidget);
  });

  testWidgets('İngilizcede PDF başlığıyla görünür', (tester) async {
    await pump(
      tester,
      SermonSummary.fromJson(summaryJson()),
      locale: const Locale('en'),
      onOpen: (_) {},
    );
    expect(find.text('Our Responsibility to Convey Islam'), findsOneWidget);
  });

  testWidgets('Arapçada ikon sağda, kenar boşluğu sağdan 16', (tester) async {
    await initializeDateFormatting('ar', null);
    await pump(
      tester,
      SermonSummary.fromJson(summaryJson()),
      locale: const Locale('ar'),
      onOpen: (_) {},
    );
    final card = tester.getRect(find.byType(SermonCard));
    final icon = tester.getRect(
      find.descendant(
        of: find.byType(SermonCard),
        matching: find.byIcon(Icons.menu_book_rounded),
      ),
    );
    expect(card.right - icon.right, 16);
  });

  testWidgets('İngilizcede PDF yoksa kart yok', (tester) async {
    await pump(
      tester,
      SermonSummary.fromJson(summaryJson(pdfs: {})),
      locale: const Locale('en'),
      onOpen: (_) {},
    );
    expect(find.byType(SermonCard), findsNothing);
  });

  testWidgets('hutbe yoksa kart yok', (tester) async {
    await pump(tester, null);
    expect(find.byType(SermonCard), findsNothing);
  });
}
