import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final occurrence = SkippedOccurrence(
    kind: SkipKind.alarm,
    reference: 'sahur',
    fireAt: DateTime(2026, 8, 5, 3, 43),
  );

  group('SkippedOccurrence', () {
    test('JSON turu degeri korur', () {
      final restored = SkippedOccurrence.fromJson(occurrence.toJson());

      expect(restored, occurrence);
    });

    test('Ayni ucluye sahip iki kayit esit', () {
      final other = SkippedOccurrence(
        kind: SkipKind.alarm,
        reference: 'sahur',
        fireAt: DateTime(2026, 8, 5, 3, 43),
      );

      expect(other, occurrence);
      expect(other.hashCode, occurrence.hashCode);
    });

    test('Farkli fireAt farkli kayit', () {
      // Ayni alarmin farkli gunleri ayri kayitlardir (spec D1).
      final nextDay = SkippedOccurrence(
        kind: SkipKind.alarm,
        reference: 'sahur',
        fireAt: DateTime(2026, 8, 6, 3, 43),
      );

      expect(nextDay, isNot(occurrence));
    });

    test('Farkli tur farkli kayit', () {
      final asNotification = SkippedOccurrence(
        kind: SkipKind.notification,
        reference: 'sahur',
        fireAt: DateTime(2026, 8, 5, 3, 43),
      );

      expect(asNotification, isNot(occurrence));
    });
  });
}
