import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/notification_setting.dart'
    show PrayerType;
import 'package:ezanvakti/presentation/utils/alarm_labels.dart';
import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/l10n_helper.dart';

/// Etiket fonksiyonlari ekranin disina bagimli degil; karakterizasyon testi
/// olarak kilitleniyorlar ki yeniden duzenleme sirasinda davranis kaymasin.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async => l10n = await loadTestL10n());

  group('alarmTimeLabel', () {
    test('Sabit alarm saati sifir dolgulu yazar', () {
      const alarm = Alarm(id: '1', kind: AlarmKind.fixed, hour: 6, minute: 5);

      expect(alarmTimeLabel(alarm, l10n: l10n), '06:05');
    });

    test('Cipali alarm vakit adi ve sapmayi yazar', () {
      const alarm = Alarm(
        id: '1',
        kind: AlarmKind.anchored,
        anchor: PrayerType.fajr,
        offsetMinutes: -30,
      );

      expect(alarmTimeLabel(alarm, l10n: l10n), 'İmsak −30 dk');
    });

    test('Pozitif sapma arti isaretiyle yazilir', () {
      const alarm = Alarm(
        id: '1',
        kind: AlarmKind.anchored,
        anchor: PrayerType.isha,
        offsetMinutes: 15,
      );

      expect(alarmTimeLabel(alarm, l10n: l10n), 'Yatsı +15 dk');
    });

    test('Sapma sifirsa yalnizca vakit adi', () {
      const alarm = Alarm(
        id: '1',
        kind: AlarmKind.anchored,
        anchor: PrayerType.isha,
      );

      expect(alarmTimeLabel(alarm, l10n: l10n), 'Yatsı');
    });
  });

  group('weekdaysLabel', () {
    test('Bos kume ve yedi gun "Her gün"', () {
      expect(weekdaysLabel(const {}, l10n), 'Her gün');
      expect(weekdaysLabel(const {1, 2, 3, 4, 5, 6, 7}, l10n), 'Her gün');
    });

    test('Hafta ici ve hafta sonu ozel etiketler', () {
      expect(weekdaysLabel(const {1, 2, 3, 4, 5}, l10n), 'Hafta içi');
      expect(weekdaysLabel(const {6, 7}, l10n), 'Hafta sonu');
    });

    test('Diger kombinasyonlar kisa gun adlariyla siralanir', () {
      expect(weekdaysLabel(const {3, 1}, l10n), 'Pzt, Çar');
    });
  });

  group('alarmSubtitle', () {
    test('Etiket varsa tekrar bilgisiyle birlestirilir', () {
      const alarm = Alarm(
        id: '1',
        kind: AlarmKind.fixed,
        label: 'Sahur',
        weekdays: {1, 2, 3, 4, 5},
      );

      expect(alarmSubtitle(alarm, l10n), 'Sahur · Hafta içi');
    });

    test('Etiket yoksa yalnizca tekrar bilgisi', () {
      const alarm = Alarm(id: '1', kind: AlarmKind.fixed);

      expect(alarmSubtitle(alarm, l10n), 'Her gün');
    });
  });
}
