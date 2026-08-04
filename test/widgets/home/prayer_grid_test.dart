import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/widgets/home/prayer_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

PrayerTime _times() {
  DateTime at(int h, int m) => DateTime(2026, 8, 2, h, m);
  return PrayerTime(
    fajr: at(4, 8),
    sunrise: at(5, 53),
    dhuhr: at(13, 15),
    asr: at(17, 10),
    maghrib: at(20, 27),
    isha: at(22, 4),
    date: DateTime(2026, 8, 2),
  );
}

Widget _grid(DateTime now, {PrayerType? current}) => SizedBox(
  width: 360,
  child: PrayerGrid(prayerTime: _times(), now: now, currentPrayer: current),
);

void main() {
  testWidgets('Alti vakit adi ve saati gosterilir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        _grid(DateTime(2026, 8, 2, 17, 34), current: PrayerType.asr),
      ),
    );

    for (final name in ['İMSAK', 'GÜNEŞ', 'ÖĞLE', 'İKİNDİ', 'AKŞAM', 'YATSI']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('04:08'), findsOneWidget);
    expect(find.text('22:04'), findsOneWidget);
  });

  testWidgets('Aktif vakit vurgu rengiyle ve w800 cizilir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        _grid(DateTime(2026, 8, 2, 17, 34), current: PrayerType.asr),
      ),
    );

    final activeValue = tester.widget<Text>(find.text('17:10'));

    expect(activeValue.style!.color, tokensFor().accent);
    expect(activeValue.style!.fontWeight, FontWeight.w800);
  });

  testWidgets('Gecmis vakit deger rengini, gelecek vakit birincil rengi alir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        _grid(DateTime(2026, 8, 2, 17, 34), current: PrayerType.asr),
      ),
    );

    final tokens = tokensFor();

    expect(
      tester.widget<Text>(find.text('04:08')).style!.color,
      tokens.textValue,
    );
    expect(
      tester.widget<Text>(find.text('20:27')).style!.color,
      tokens.textPrimary,
    );
  });

  testWidgets('Aktif vakit yoksa hicbiri vurgulanmaz', (tester) async {
    await tester.pumpWidget(wrapWithTheme(_grid(DateTime(2026, 8, 2, 3, 0))));

    final tokens = tokensFor();
    for (final time in ['04:08', '22:04']) {
      expect(
        tester.widget<Text>(find.text(time)).style!.color,
        isNot(tokens.accent),
        reason: time,
      );
    }
  });

  testWidgets('Alt ve ust ayirac cizilir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        _grid(DateTime(2026, 8, 2, 17, 34), current: PrayerType.asr),
      ),
    );

    expect(find.byType(Divider), findsNWidgets(2));
  });
}
