import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/prayer_times/domain/kerahat_times.dart';
import 'package:ezanvakti/presentation/widgets/home/kerahat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

const _sourceUrl =
    'https://kurul.diyanet.gov.tr/tr/fetva/mekruh-vakitler-hangileridir-hangi-vakitlerde-kaza-ve-hangi-vakitlerde-nafile-namaz-kilinmaz/0193c42d-52b7-7186-d5b4-f1d3c950ad73';

PrayerTime _times() {
  DateTime at(int hour, [int minute = 0]) => DateTime(2026, 8, 2, hour, minute);
  return PrayerTime(
    fajr: at(4),
    sunrise: at(6),
    dhuhr: at(13),
    asr: at(17),
    maghrib: at(20),
    isha: at(22),
    date: DateTime(2026, 8, 2),
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  DateTime now, {
  Locale locale = const Locale('tr'),
  double textScale = 1,
}) async {
  final card = MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: SizedBox(
      width: 240,
      child: KerahatCard(intervals: KerahatTimes.forDay(_times()), now: now),
    ),
  );
  await tester.pumpWidget(wrapWithTheme(card, locale: locale));
  await tester.pump();
}

void main() {
  testWidgets('baslamadan once siradaki araligi ve kalan sureyi gosterir', (
    tester,
  ) async {
    await _pumpCard(tester, DateTime(2026, 8, 2, 5));

    expect(find.text('Sıradaki kerahat'), findsOneWidget);
    expect(find.textContaining('Güneş sonrası'), findsOneWidget);
    expect(find.textContaining('1 sa sonra başlar'), findsOneWidget);
  });

  testWidgets('baslangicta aktif olur ve bitiste sonraki araliga gecer', (
    tester,
  ) async {
    await _pumpCard(tester, DateTime(2026, 8, 2, 6));

    expect(find.text('Kerahat vakti'), findsOneWidget);
    expect(find.textContaining('45 dk sonra biter'), findsOneWidget);

    await _pumpCard(tester, DateTime(2026, 8, 2, 6, 45));

    expect(find.text('Kerahat vakti'), findsNothing);
    expect(find.text('Sıradaki kerahat'), findsOneWidget);
  });

  testWidgets('son araliktan sonra tamamlanmis durumu gosterir', (
    tester,
  ) async {
    await _pumpCard(tester, DateTime(2026, 8, 2, 20));

    expect(find.text('Bugünün kerahat vakitleri'), findsOneWidget);
  });

  testWidgets('dokununca uc aralik ve secilebilir Diyanet kaynagi acilir', (
    tester,
  ) async {
    await _pumpCard(tester, DateTime(2026, 8, 2, 6));

    await tester.tap(find.byType(KerahatCard));
    await tester.pumpAndSettle();

    expect(find.text('Kerahat vakitleri'), findsOneWidget);
    expect(find.text('Öğle öncesi'), findsOneWidget);
    expect(find.text('Akşam öncesi'), findsOneWidget);
    expect(find.textContaining('45/10/45'), findsOneWidget);
    expect(find.textContaining('mezhebe'), findsOneWidget);
    expect(find.textContaining('İkindi farzı'), findsOneWidget);
    expect(
      find.textContaining('Diyanet Din İşleri Yüksek Kurulu'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == _sourceUrl,
      ),
      findsOneWidget,
    );
  });

  testWidgets('dar alanda buyuk Arapca metinle tasmaz', (tester) async {
    await _pumpCard(
      tester,
      DateTime(2026, 8, 2, 6),
      locale: const Locale('ar'),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('وقت الكراهة'), findsOneWidget);
  });
}
