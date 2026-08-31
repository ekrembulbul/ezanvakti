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

  @override
  String get remindersTitle => 'Hatırlatıcılar';

  @override
  String get remindersNotifications => 'Bildirimler';

  @override
  String get remindersAlarms => 'Alarmlar';

  @override
  String get remindersNoNotifications => 'Henüz bildirim yok';

  @override
  String get remindersNoNotificationsHint =>
      'Namaz vakitlerinde hatırlatma almak için\nbildirim ekleyin.';

  @override
  String get remindersNoAlarms => 'Henüz alarm yok';

  @override
  String get remindersNoAlarmsHint => 'Sabit saatli veya vakte göre alarm ekle';

  @override
  String remindersCount(Object count) {
    return '$count hatırlatma';
  }

  @override
  String remindersAlarmCount(Object count) {
    return '$count alarm';
  }

  @override
  String get remindersAddFriday => 'Cuma namazı hatırlatıcısı ekle';

  @override
  String get reminderFridayLabel => 'Cuma namazı';

  @override
  String get reminderOnTime => 'Tam vaktinde';

  @override
  String reminderMinutesBefore(Object minutes) {
    return '$minutes dk önce';
  }

  @override
  String get reminderSkippedOnce => 'Yalnızca bu sefer atlanacak';

  @override
  String get reminderOff => 'Kapalı';

  @override
  String get reminderScheduleFailed =>
      'Kurulamadı — düzenleyip kaydederek yeniden dene';

  @override
  String get quietTitle => 'Sessiz pencereler';

  @override
  String get quietIntro =>
      'Bu aralıklarda Ezan Vakti bildirimleri sessiz gösterilir ya da hiç gösterilmez. iPhone\'da bir uygulama telefonu sessize alamaz; bu ayar yalnızca uygulamanın kendi bildirimlerini etkiler, alarmlara dokunmaz.';

  @override
  String get quietFridaySection => 'Cuma namazı';

  @override
  String get quietFridayTitle => 'Cuma vaktinde sessiz';

  @override
  String get quietFridayHint =>
      'Cuma öğle vaktinin çevresinde bildirimler susar. Süreleri değiştirebilir ya da tamamen kapatabilirsin.';

  @override
  String get quietCustomSection => 'Özel pencereler';

  @override
  String get quietNoCustom => 'Henüz özel pencere yok.';

  @override
  String get quietAddWindow => 'Pencere ekle';

  @override
  String get quietMinutesBefore => 'Kaç dakika önce';

  @override
  String get quietMinutesAfter => 'Kaç dakika sonra';

  @override
  String get quietModeLabel => 'Bu aralıkta';

  @override
  String get quietModeSilent => 'Sessiz göster';

  @override
  String get quietModeSilentHint => 'Bildirim görünür, ses çalmaz';

  @override
  String get quietModeSkip => 'Hiç gösterme';

  @override
  String get quietModeSkipHint => 'Bildirim hiç planlanmaz';

  @override
  String quietWindowSummary(Object before, Object after) {
    return '$before dk önce – $after dk sonra';
  }

  @override
  String get quietPrayerLabel => 'Vakit';

  @override
  String get prefsNewSound => 'Yeni bildirim sesi';

  @override
  String get soundSystem => 'Sistem sesi';

  @override
  String get soundSystemHint => 'Cihazın varsayılan bildirim sesi';

  @override
  String get soundBeep => 'Kısa uyarı';

  @override
  String get soundBeepHint => 'Uygulamanın kendi kısa tonu';

  @override
  String get soundSilent => 'Sessiz';

  @override
  String get soundSilentHint => 'Bildirim görünür, ses çalmaz';

  @override
  String get prefsShowInFocus => 'Odak modunda göster';

  @override
  String get prefsShowInFocusHint =>
      'Bildirimler Odak açıkken özete düşmez. Telefonun sessiz anahtarını delmez.';

  @override
  String get prefsReligiousDays => 'Dini günler';

  @override
  String get prefsReligiousDaysHint =>
      'Kandil, bayram ve mübarek günlerde akşam vakti hatırlatır. Tarihler hicri takvimden hesaplanır; Diyanet takvimiyle bir gün farklı olabilir.';

  @override
  String get prefsReligiousDayEve => 'Bir gün önce de hatırlat';

  @override
  String get prefsReligiousDayEveHint =>
      'Öğle vaktinde \"yarın\" bildirimi gönderir.';

  @override
  String get alarmAdd => 'Alarm ekle';

  @override
  String get alarmEdit => 'Alarmı düzenle';

  @override
  String get alarmFixedTime => 'Sabit saat';

  @override
  String get alarmAnchored => 'Vakte göre';

  @override
  String get alarmRepeat => 'Tekrar';

  @override
  String get alarmLabel => 'Etiket';

  @override
  String get alarmLabelHint => 'Örn. Sahur';

  @override
  String get alarmSound => 'Ses';

  @override
  String get alarmSoundDefault => 'Varsayılan';

  @override
  String get alarmSoundCustom => 'Özel ses';

  @override
  String get alarmSoundPick => 'Cihazdan ses seç…';

  @override
  String get alarmSoundVolumeNote =>
      'Alarm, Zil Sesi ve Uyarılar ses seviyesiyle çalar.';

  @override
  String get alarmVibrate => 'Titreşim';

  @override
  String get alarmSnooze => 'Ertele (snooze)';

  @override
  String get alarmSnoozeCount => 'Erteleme sayısı';

  @override
  String get alarmSnoozeUnlimited => 'Sınırsız';

  @override
  String alarmSnoozeTimes(Object count) {
    return '$count kez';
  }

  @override
  String get alarmMission => 'Kapatma görevi';

  @override
  String get alarmMissionQuestion => 'Alarmı nasıl kapatacaksın?';

  @override
  String get missionNone => 'Görev yok';

  @override
  String get missionNoneHint => 'Kaydırarak doğrudan kapanır';

  @override
  String get missionMath => 'Matematik';

  @override
  String get missionMathHint => 'Soruları çözmeden kapanmaz';

  @override
  String get missionShake => 'Sallama';

  @override
  String get missionShakeHint => 'Telefonu sallayarak kapatılır';

  @override
  String get missionQr => 'QR okutma';

  @override
  String get missionQrHint => 'Kayıtlı kodu okutmadan kapanmaz';

  @override
  String get alarmEveryDay => 'Her gün';

  @override
  String get alarmWeekdays => 'Hafta içi';

  @override
  String get alarmWeekend => 'Hafta sonu';

  @override
  String get alarmCopySuffix => '(kopya)';

  @override
  String get alarmDuplicate => 'Kopyala';

  @override
  String get errorGeneric => 'Bir şeyler ters gitti';

  @override
  String get calendarTitle => 'Vakit Takvimi';

  @override
  String get calendarShare => 'Takvimi paylaş';

  @override
  String get calendarEmpty => 'Takvim verisi bulunamadı';

  @override
  String get calendarLoading => 'Takvim yükleniyor...';

  @override
  String get calendarShareFailed => 'Takvim görüntüsü oluşturulamadı';

  @override
  String calendarDayCount(Object count) {
    return '$count gün';
  }

  @override
  String get upcomingNext => 'SIRADAKİ';

  @override
  String upcomingNotification(Object prayer) {
    return '$prayer bildirimi';
  }

  @override
  String get upcomingTomorrow => 'yarın';

  @override
  String get upcomingToday => 'bugün';

  @override
  String get snackNotificationAdded => 'Bildirim eklendi';

  @override
  String get snackNotificationUpdated => 'Bildirim güncellendi';

  @override
  String get snackNotificationDeleted => 'Bildirim silindi';

  @override
  String get snackNotificationExists => 'Bu bildirim zaten mevcut';

  @override
  String get snackAlarmDeleted => 'Alarm silindi';

  @override
  String get snackSkipOnce => 'Yalnızca bu sefer';

  @override
  String get snackUndo => 'Geri al';

  @override
  String get locationTitle => 'Konumlar';

  @override
  String get locationAdd => 'Konum ekle';

  @override
  String get locationSearch => 'Şehir ara';

  @override
  String get locationUseGps => 'Konumumu kullan';

  @override
  String get locationEmpty => 'Kayıtlı konum yok';

  @override
  String shareCaption(Object location, Object period) {
    return '$location · $period namaz vakitleri';
  }

  @override
  String get ramadanIftarCountdown => 'İftara';

  @override
  String get ramadanSuhoorCountdown => 'Sahurun bitişine';

  @override
  String ramadanDay(Object day) {
    return 'Ramazan $day. gün';
  }

  @override
  String get ramadanCalendarTitle => 'Ramazan İmsakiyesi';

  @override
  String get ramadanFastingSection => 'Oruç takibi';

  @override
  String get ramadanFasted => 'Tuttum';

  @override
  String get ramadanFastMissed => 'Kaza';

  @override
  String get ramadanFastExempt => 'Muaf';

  @override
  String get ramadanFastingQada => 'Kaza orucu';

  @override
  String get ramadanSetupTitle => 'Ramazan hatırlatmaları';

  @override
  String get ramadanSetupBody =>
      'Sahur (imsaktan 45 dk önce) ve iftar bildirimi eklensin mi? Hatırlatıcılar listesinde görünür, dilediğinde silebilirsin.';

  @override
  String get ramadanSetupAccept => 'Ekle';

  @override
  String get ramadanSuhoorLabel => 'Sahur';

  @override
  String get ramadanIftarLabel => 'İftar';

  @override
  String get ramadanRemindersAdded => 'Sahur ve iftar hatırlatmaları eklendi';

  @override
  String get locationsTitle => 'Konumlar';

  @override
  String get locationsLoading => 'Konumlar yükleniyor...';

  @override
  String locationsLoadFailed(Object error) {
    return 'Konumlar yüklenemedi: $error';
  }

  @override
  String get locationsEmpty => 'Henüz konum eklenmedi';

  @override
  String get locationsEmptyHint =>
      'GPS ile otomatik tespit edin veya\nadres arayarak konum seçin';

  @override
  String get locationsSwipeHint =>
      'Aktif olmayan konumu silmek için satırı sola kaydırın.';

  @override
  String get locationActive => 'AKTİF';

  @override
  String get locationAddTitle => 'Konum ekle';

  @override
  String get locationEditTitle => 'Konumu Düzenle';

  @override
  String get locationSearchHint => 'Şehir, ilçe veya yer adıyla ara';

  @override
  String get locationSearchPlaceholder => 'Şehir, ilçe veya yer ara...';

  @override
  String get locationSearchStart => 'Aramak için yazmaya başlayın.';

  @override
  String get locationSearchNoResult =>
      'Sonuç bulunamadı.\nFarklı bir arama deneyin veya bağlantınızı kontrol edin.';

  @override
  String get locationGettingPosition => 'Konum Alınıyor...';

  @override
  String get locationPermissionTitle => 'Konum İzni';

  @override
  String get locationPermissionBody =>
      'Namaz vakitlerini bulunduğunuz konuma göre gösterebilmek için konum iznine ihtiyaç var. İzni vererek bulunduğunuz il/ilçe otomatik seçilecektir.';

  @override
  String get locationPermissionAllow => 'İzin Ver';

  @override
  String get locationServicesOff => 'Konum servisleri kapalı. Lütfen açın.';

  @override
  String get locationPermissionDenied =>
      'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.';

  @override
  String get locationUpdated => 'Konum güncellendi';

  @override
  String get locationSelectFirst => 'Lütfen bir konum seçin';

  @override
  String get locationCustomName => 'Özel İsim (Opsiyonel)';

  @override
  String get locationCustomNameHint => 'Örn: Ev, İş, Anne Evi';

  @override
  String get locationUseGlobalCalculation => 'Genel hesaplama ayarını kullan';

  @override
  String get locationUseGlobalCalculationHint =>
      'Kapatırsan bu konuma özel yöntem/mezhep seçebilirsin';

  @override
  String get locationCalculationFromGlobal =>
      'Hesaplama yöntemi genel ayardan alınır. Bu konuma özel değiştirmek için kaydettikten sonra düzenleyin.';

  @override
  String get locationChange => 'Değiştir';

  @override
  String locationUndoFailed(Object error) {
    return 'Geri alınamadı: $error';
  }

  @override
  String get osmAttribution => '© OpenStreetMap katkıcıları';

  @override
  String get widgetTomorrow => 'Yarın';

  @override
  String get widgetStale => 'Güncel değil';

  @override
  String get widgetOpenApp => 'Vakitler için uygulamayı aç';

  @override
  String get widgetUpdateApp => 'Uygulamayı güncelleyin';

  @override
  String siriAnswer(Object prayer, Object time, Object remaining) {
    return '$prayer $time, $remaining kaldı.';
  }

  @override
  String durationHourMinute(Object hours, Object minutes) {
    return '$hours saat $minutes dakika';
  }

  @override
  String durationHour(Object hours) {
    return '$hours saat';
  }

  @override
  String durationMinute(Object minutes) {
    return '$minutes dakika';
  }
}
