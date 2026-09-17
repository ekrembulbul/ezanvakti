import 'package:ezanvakti/core/models/notification_setting.dart'
    show PrayerType;
import 'package:ezanvakti/presentation/screens/prayer_tune_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  testWidgets('Duzeltme ekrani baslik, ipucu ve vakit satirlarini gosterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(const PrayerTuneScreen(initial: {PrayerType.fajr: 2})),
    );

    expect(find.text('Vakit düzeltme'), findsOneWidget);
    expect(find.text('İmsak'), findsOneWidget);
    expect(find.text('Yatsı'), findsOneWidget);
    expect(find.text('+2 dk'), findsOneWidget);
  });

  testWidgets('Kaydet secilen haritayi geri doner', (tester) async {
    Map<PrayerType, int>? result;
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Map<PrayerType, int>>(
                MaterialPageRoute(
                  builder: (_) => const PrayerTuneScreen(initial: {}),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // İlk satır İmsak: ilk "+" düğmesi ona ait.
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(result, {PrayerType.fajr: 1});
  });
}
