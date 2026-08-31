// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get prayerFajr => 'İmsak';

  @override
  String get prayerSunrise => 'Güneş';

  @override
  String get prayerDhuhr => 'Öğle';

  @override
  String get prayerAsr => 'İkindi';

  @override
  String get prayerMaghrib => 'Akşam';

  @override
  String get prayerIsha => 'Yatsı';

  @override
  String get navPrayerTimes => 'Vakitler';

  @override
  String get navCalendar => 'Takvim';

  @override
  String get navReminders => 'Hatırlatıcılar';

  @override
  String get navTools => 'Araçlar';

  @override
  String get actionCancel => 'Vazgeç';

  @override
  String get actionSave => 'Kaydet';

  @override
  String get actionDelete => 'Sil';

  @override
  String get actionOk => 'Tamam';

  @override
  String get actionUndo => 'Geri al';

  @override
  String get actionShare => 'Paylaş';

  @override
  String get actionCopy => 'Kopyala';

  @override
  String get actionReset => 'Sıfırla';

  @override
  String get actionRetry => 'Tekrar dene';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsGeneral => 'Genel';

  @override
  String get settingsAppearance => 'Görünüm';

  @override
  String get settingsInfo => 'Bilgi';

  @override
  String get settingsNotificationsAndSound => 'Bildirim ve ses';

  @override
  String get settingsLocation => 'Konum';

  @override
  String get settingsCalculation => 'Hesaplama';

  @override
  String get settingsDataSource => 'Veri kaynağı';

  @override
  String get settingsPrivacy => 'Gizlilik';

  @override
  String get settingsLanguage => 'Dil';

  @override
  String get settingsTimeFormat => 'Saat biçimi';

  @override
  String get settingsQuietWindows => 'Sessiz pencereler';

  @override
  String get languageSystem => 'Sistem';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'İngilizce';

  @override
  String get languageArabic => 'Arapça';

  @override
  String get timeFormatSystem => 'Sistem';

  @override
  String get timeFormat24 => '24 saat';

  @override
  String get timeFormat12 => '12 saat';

  @override
  String get settingsAutoLocation => 'Konumu otomatik izle';

  @override
  String get settingsAutoLocationHint =>
      'Şehir değişince vakitler kendiliğinden güncellenir.';

  @override
  String get toolsTitle => 'Araçlar';

  @override
  String get toolsDirection => 'Yön';

  @override
  String get toolsTracking => 'Takip';

  @override
  String get toolsQibla => 'Kıble';

  @override
  String get toolsQiblaHint => 'Kâbe yönünü pusulayla bul';

  @override
  String get toolsPrayerTracking => 'Namaz takibi';

  @override
  String get toolsPrayerTrackingHint => 'Kıldıklarını işaretle, kazanı say';

  @override
  String get toolsDhikr => 'Zikirmatik';

  @override
  String get toolsDhikrHint => 'Hedefli sayaç';

  @override
  String get toolsPrivacyNote =>
      'Araçlar cihazında çalışır; hiçbir veri dışarı gönderilmez.';

  @override
  String get qiblaTitle => 'Kıble';

  @override
  String get qiblaFromNorth => 'Kuzeyden sağa doğru';

  @override
  String get qiblaNeedsLocation => 'Konum gerekiyor';

  @override
  String get qiblaNeedsLocationHint =>
      'Kıble yönü için önce bir konum seç ya da GPS ile bul.';

  @override
  String get qiblaWaiting => 'Pusula bekleniyor…';

  @override
  String get qiblaCalibrate =>
      'Pusula kalibrasyon istiyor. Telefonu havada sekiz çizerek birkaç saniye hareket ettir.';

  @override
  String get qiblaAligned => 'Kıbleye dönüksün';

  @override
  String qiblaTurnRight(Object degrees) {
    return '$degrees° sağa dön';
  }

  @override
  String qiblaTurnLeft(Object degrees) {
    return '$degrees° sola dön';
  }

  @override
  String get trackingTitle => 'Namaz takibi';

  @override
  String get trackingLastDays => 'Son 7 gün';

  @override
  String get trackingQadaCounter => 'Kaza sayacı';

  @override
  String get trackingDone => 'Kıldım';

  @override
  String get trackingQada => 'Kaza';

  @override
  String get trackingEmpty => 'Boş';

  @override
  String get dhikrTitle => 'Zikirmatik';

  @override
  String get dhikrTarget => 'Hedef';

  @override
  String get dhikrTapToCount => 'Saymak için ekrana dokun';

  @override
  String dhikrProgress(Object remaining, Object laps) {
    return 'Hedefe $remaining · Tur $laps';
  }

  @override
  String dhikrTodayTotal(Object count) {
    return 'Bugün toplam $count';
  }

  @override
  String get dhikrResetTitle => 'Sayacı sıfırla';

  @override
  String get dhikrResetBody => 'Bugünkü zikir sayısı silinecek.';

  @override
  String notificationPrayerNow(Object prayer) {
    return '$prayer vakti girdi';
  }

  @override
  String notificationPrayerSoon(Object prayer) {
    return '$prayer vakti yaklaşıyor';
  }

  @override
  String notificationMinutesLeft(Object prayer, Object minutes) {
    return '$prayer vaktine $minutes dakika kaldı';
  }

  @override
  String notificationDerivedSoon(Object name) {
    return '$name yaklaşıyor';
  }

  @override
  String notificationDerivedMinutesLeft(Object name, Object minutes) {
    return '$name vaktine $minutes dakika kaldı';
  }

  @override
  String religiousDayTodayEstimated(Object name) {
    return '$name bugün. Tarih hesaplanmıştır; Diyanet takvimiyle bir gün farklı olabilir.';
  }

  @override
  String religiousDayToday(Object name) {
    return '$name bugün.';
  }

  @override
  String religiousDayTomorrowTitle(Object name) {
    return '$name yarın';
  }

  @override
  String religiousDayTomorrowBody(Object name) {
    return '$name yarın idrak edilecek.';
  }

  @override
  String get derivedIshraq => 'İşrak';

  @override
  String get derivedIstiwa => 'Kerahat (zeval)';

  @override
  String get derivedPreMaghrib => 'Kerahat (akşam öncesi)';

  @override
  String get derivedMidnight => 'Gece yarısı';

  @override
  String get derivedLastThird => 'Gecenin son üçte biri';

  @override
  String get derivedIshraqHint => 'Güneşten sonra kerahat biter';

  @override
  String get derivedIstiwaHint => 'Öğleden önceki kerahat başlar';

  @override
  String get derivedPreMaghribHint => 'Akşamdan önceki kerahat başlar';

  @override
  String get derivedMidnightHint => 'Şer\'i gecenin ortası';

  @override
  String get derivedLastThirdHint => 'Teheccüd vakti başlar';
}
