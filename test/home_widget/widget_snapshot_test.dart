import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot.dart';

void main() {
  group('WidgetSnapshot.toJson', () {
    final snapshot = WidgetSnapshot(
      locationLabel: 'Kadıköy, İstanbul',
      generatedAt: DateTime(2026, 8, 25, 14, 3),
      days: [
        WidgetSnapshotDay(
          date: DateTime(2026, 8, 25),
          hijri: '13 Rebiülevvel 1448',
          times: WidgetDayTimes(
            fajr: DateTime(2026, 8, 25, 4, 12),
            sunrise: DateTime(2026, 8, 25, 5, 52),
            dhuhr: DateTime(2026, 8, 25, 13, 15),
            asr: DateTime(2026, 8, 25, 16, 58),
            maghrib: DateTime(2026, 8, 25, 20, 26),
            isha: DateTime(2026, 8, 25, 21, 58),
          ),
        ),
      ],
    );

    test('etiket verilmezse labels alani yazilmaz (v2 uyumlulugu)', () {
      expect(snapshot.toJson().containsKey('labels'), isFalse);
    });

    test('etiket verilirse labels alani yazilir', () {
      const labels = WidgetLabels(
        fajr: 'Fajr',
        sunrise: 'Sunrise',
        dhuhr: 'Dhuhr',
        asr: 'Asr',
        maghrib: 'Maghrib',
        isha: 'Isha',
        tomorrow: 'Tomorrow',
        stale: 'Out of date',
        openApp: 'Open the app',
        updateApp: 'Update the app',
        siriAnswer: '{prayer} at {time}, {remaining} left.',
        durationHourMinute: '{hours} h {minutes} min',
        durationHour: '{hours} h',
        durationMinute: '{minutes} min',
      );
      final withLabels = WidgetSnapshot(
        locationLabel: snapshot.locationLabel,
        generatedAt: snapshot.generatedAt,
        days: snapshot.days,
        labels: labels,
      );
      final json = withLabels.toJson()['labels'] as Map<String, String>;
      expect(json['fajr'], 'Fajr');
      expect(json['siriAnswer'], contains('{prayer}'));
    });

    test('schemaVersion 3 yazilir', () {
      expect(snapshot.toJson()['schemaVersion'], 3);
    });

    test('hicri tarih gune yazilir', () {
      final day = (snapshot.toJson()['days'] as List).first;
      expect(day['hijri'], '13 Rebiülevvel 1448');
    });

    test('saatler sifir dolgulu HH:mm bicimindedir', () {
      final times =
          (snapshot.toJson()['days'] as List).first['times']
              as Map<String, dynamic>;
      expect(times, {
        'fajr': '04:12',
        'sunrise': '05:52',
        'dhuhr': '13:15',
        'asr': '16:58',
        'maghrib': '20:26',
        'isha': '21:58',
      });
    });

    test('tarih yyyy-MM-dd bicimindedir', () {
      final day = (snapshot.toJson()['days'] as List).first;
      expect(day['date'], '2026-08-25');
    });

    test('generatedAt offset tasimayan yerel damgadir', () {
      expect(snapshot.toJson()['generatedAt'], '2026-08-25T14:03:00');
    });

    test('locationLabel oldugu gibi tasinir', () {
      expect(snapshot.toJson()['locationLabel'], 'Kadıköy, İstanbul');
    });
  });
}
