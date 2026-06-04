import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/presentation/widgets/home/countdown_card.dart';

void main() {
  testWidgets('CountdownCard scales into a small box without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 130,
            child: Column(
              children: [
                Expanded(
                  child: CountdownCard(
                    nextPrayerTime: DateTime.now().add(
                      const Duration(hours: 2, minutes: 15),
                    ),
                    nextPrayerName: 'Yatsı',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    // CountdownCard saniyelik bir Timer başlatır; widget'ı kaldırarak temizle.
    await tester.pumpWidget(const SizedBox());
  });
}
