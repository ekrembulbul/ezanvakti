import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/widgets/home/prayer_times_card.dart';

void main() {
  testWidgets('PrayerTimesCard fills constrained height without overflow', (
    tester,
  ) async {
    final prayerTime = PrayerTime(
      fajr: DateTime(2024, 1, 1, 5, 30),
      sunrise: DateTime(2024, 1, 1, 7, 0),
      dhuhr: DateTime(2024, 1, 1, 13, 15),
      asr: DateTime(2024, 1, 1, 16, 30),
      maghrib: DateTime(2024, 1, 1, 19, 0),
      isha: DateTime(2024, 1, 1, 20, 30),
      date: DateTime(2024, 1, 1),
    );

    // Küçük bir ekrandaki vakit kartı alanını taklit eder (scroll yok).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 340,
            child: Column(
              children: [
                Expanded(child: PrayerTimesCard(prayerTime: prayerTime)),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Namaz Vakitleri'), findsOneWidget);
  });
}
