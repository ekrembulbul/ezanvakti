import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/features/notifications/domain/skip_rules.dart';
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

  group('isSkipped', () {
    final skips = {
      SkippedOccurrence(
        kind: SkipKind.alarm,
        reference: 'sahur',
        fireAt: DateTime(2026, 8, 5, 3, 43),
      ),
    };

    test('Ucu de eslesince atlanmis', () {
      expect(
        isSkipped(
          skips,
          kind: SkipKind.alarm,
          reference: 'sahur',
          fireAt: DateTime(2026, 8, 5, 3, 43),
        ),
        isTrue,
      );
    });

    test('Saat kayarsa eslesmez', () {
      // Spec: vakit verisi guncellenip saat kayarsa alarm CALAR ve anahtar
      // acik gorunur. Ikisi de bu ayni sorgudan turedigi icin ayrisamaz.
      expect(
        isSkipped(
          skips,
          kind: SkipKind.alarm,
          reference: 'sahur',
          fireAt: DateTime(2026, 8, 5, 3, 45),
        ),
        isFalse,
      );
    });

    test('Farkli referans eslesmez', () {
      expect(
        isSkipped(
          skips,
          kind: SkipKind.alarm,
          reference: 'isyerine-cikis',
          fireAt: DateTime(2026, 8, 5, 3, 43),
        ),
        isFalse,
      );
    });

    test('Bos kumede hicbir sey atlanmis degil', () {
      expect(
        isSkipped(
          const {},
          kind: SkipKind.alarm,
          reference: 'sahur',
          fireAt: DateTime(2026, 8, 5, 3, 43),
        ),
        isFalse,
      );
    });
  });

  group('withoutExpired', () {
    SkippedOccurrence at(DateTime fireAt) => SkippedOccurrence(
      kind: SkipKind.notification,
      reference: 'x',
      fireAt: fireAt,
    );

    test('Zamani gecmis kayit elenir', () {
      final now = DateTime(2026, 8, 5, 12);
      final kept = at(DateTime(2026, 8, 5, 13));

      final result = withoutExpired([at(DateTime(2026, 8, 5, 11)), kept], now);

      expect(result, {kept});
    });

    test('Tam su anda tetiklenecek kayit korunur', () {
      final now = DateTime(2026, 8, 5, 12);
      final borderline = at(now);

      expect(withoutExpired([borderline], now), {borderline});
    });

    test('Hepsi gecmisse bos kume', () {
      final now = DateTime(2026, 8, 5, 12);

      expect(withoutExpired([at(DateTime(2026, 8, 4))], now), isEmpty);
    });
  });

  group('Kimlik uretimi tek noktadan', () {
    test('Gun ici saat kimligi degistirmez', () {
      // "Anahtar yalan soylemez" kuralinin temeli: kart ve planlayici ayni
      // fonksiyondan ayni gunle kimlik uretir, saatten bagimsiz.
      final fromCard = NotificationScheduler.notificationIdFor(
        date: DateTime(2026, 8, 3),
        prayerType: PrayerType.maghrib,
        minutesBefore: 10,
      );
      final fromScheduler = NotificationScheduler.notificationIdFor(
        date: DateTime(2026, 8, 3, 23, 59),
        prayerType: PrayerType.maghrib,
        minutesBefore: 10,
      );

      expect(fromCard, fromScheduler);
    });

    test('Farkli gun farkli kimlik', () {
      final today = NotificationScheduler.notificationIdFor(
        date: DateTime(2026, 8, 3),
        prayerType: PrayerType.maghrib,
        minutesBefore: 10,
      );
      final tomorrow = NotificationScheduler.notificationIdFor(
        date: DateTime(2026, 8, 4),
        prayerType: PrayerType.maghrib,
        minutesBefore: 10,
      );

      expect(today, isNot(tomorrow));
    });
  });
}
