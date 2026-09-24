import 'package:ezanvakti/presentation/widgets/reminders/snooze_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  group('formatCountdownSeconds', () {
    test('m:ss, saniye iki haneli', () {
      expect(formatCountdownSeconds(462), '7:42');
      expect(formatCountdownSeconds(65), '1:05');
      expect(formatCountdownSeconds(0), '0:00');
    });

    test('negatif sifira kirpilir', () {
      expect(formatCountdownSeconds(-3), '0:00');
    });
  });

  group('SnoozeCountdown', () {
    testWidgets('baslik ve kalan sure yazilir, saniyede bir ilerler', (
      tester,
    ) async {
      var now = DateTime(2026, 9, 22, 5, 41, 18);
      final until = DateTime(2026, 9, 22, 5, 49);
      await tester.pumpWidget(
        wrapWithTheme(SnoozeCountdown(until: until, clock: () => now)),
      );

      expect(find.byKey(kSnoozeCountdownKey), findsOneWidget);
      expect(find.text('ERTELENDİ'), findsOneWidget);
      expect(find.text('7:42'), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('7:41'), findsOneWidget);
    });

    testWidgets('sure dolunca 0:00 kalir', (tester) async {
      final until = DateTime(2026, 9, 22, 5, 49);
      await tester.pumpWidget(
        wrapWithTheme(
          SnoozeCountdown(
            until: until,
            clock: () => until.add(const Duration(seconds: 30)),
          ),
        ),
      );
      expect(find.text('0:00'), findsOneWidget);
    });

    testWidgets('erisilebilirlik etiketi saati soyler', (tester) async {
      final until = DateTime(2026, 9, 22, 5, 49);
      await tester.pumpWidget(
        wrapWithTheme(
          SnoozeCountdown(
            until: until,
            clock: () => until.subtract(const Duration(minutes: 2)),
          ),
        ),
      );
      expect(find.bySemanticsLabel(RegExp(r'05:49')), findsOneWidget);
    });
  });
}
