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
  String get actionRetry => 'Yeniden Dene';

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
  String get settingsTimeFormat => 'Saat biçimi';

  @override
  String get settingsQuietWindows => 'Sessiz pencereler';

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
      'Bu aralıklarda Ezan Vakti bildirimleri sessiz gösterilir ya da hiç gösterilmez. Ayar yalnızca uygulamanın kendi bildirimlerini etkiler; telefonun zil profiline ve alarmlara dokunmaz.';

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
  String alarmCopySuffix(String label) {
    return '$label (kopya)';
  }

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

  @override
  String get hijriMuharram => 'Muharrem';

  @override
  String get hijriSafar => 'Safer';

  @override
  String get hijriRabiAwwal => 'Rebiülevvel';

  @override
  String get hijriRabiThani => 'Rebiülahir';

  @override
  String get hijriJumadaAwwal => 'Cemaziyülevvel';

  @override
  String get hijriJumadaThani => 'Cemaziyülahir';

  @override
  String get hijriRajab => 'Recep';

  @override
  String get hijriShaban => 'Şaban';

  @override
  String get hijriRamadan => 'Ramazan';

  @override
  String get hijriShawwal => 'Şevval';

  @override
  String get hijriDhulQadah => 'Zilkade';

  @override
  String get hijriDhulHijjah => 'Zilhicce';

  @override
  String get religiousNewYear => 'Hicri Yılbaşı';

  @override
  String get religiousAshura => 'Aşure Günü';

  @override
  String get religiousMawlid => 'Mevlid Kandili';

  @override
  String get religiousRegaib => 'Regaib Kandili';

  @override
  String get religiousMiraj => 'Miraç Kandili';

  @override
  String get religiousBaraat => 'Berat Kandili';

  @override
  String get religiousRamadanStart => 'Ramazan Başlangıcı';

  @override
  String get religiousQadr => 'Kadir Gecesi';

  @override
  String get religiousEidFitr => 'Ramazan Bayramı';

  @override
  String get religiousArafah => 'Arefe Günü';

  @override
  String get religiousEidAdha => 'Kurban Bayramı';

  @override
  String get asrShafi => 'Şafi (Standart)';

  @override
  String get asrHanafi => 'Hanefi';

  @override
  String get latAuto => 'Otomatik';

  @override
  String get latMidnight => 'Gece ortası';

  @override
  String get latOneSeventh => 'Gecenin yedide biri';

  @override
  String get latAngle => 'Açı tabanlı';

  @override
  String get calcMethodLabel => 'Hesaplama Yöntemi';

  @override
  String get calcAsrLabel => 'İkindi (Mezhep)';

  @override
  String get calcAdvanced => 'Gelişmiş';

  @override
  String get calcLatitudeLabel => 'Yüksek Enlem Düzeltmesi';

  @override
  String get calcGlobalNote =>
      'Tüm konumlar için varsayılan ayar. Bir konum kendi ayarını seçmediği sürece bu kullanılır.';

  @override
  String get calcTuneSection => 'Vakit düzeltmeleri';

  @override
  String get calcTuneHint =>
      'Vakitleri elindeki takvime göre birkaç dakika kaydırabilirsin. Bildirimler, alarmlar ve widget da kaydırılmış vakti kullanır.';

  @override
  String minutesShort(Object minutes) {
    return '$minutes dk';
  }

  @override
  String get offlineFresh => 'Veriler güncel';

  @override
  String get offlineShouldUpdate => 'Veriler güncellenmeli';

  @override
  String get offlineTooOld => 'Veriler çok eski, güncelleme gerekli';

  @override
  String get offlineNoData => 'Veri bulunamadı';

  @override
  String get offlineNoConnection =>
      'İnternet bağlantısı yok. Kaydedilmiş veriler gösteriliyor.';

  @override
  String get offlineFetchFailed =>
      'Veri alınamadı. Lütfen internet bağlantınızı kontrol edin.';

  @override
  String get offlineUpdateFailed =>
      'Güncelleme başarısız. Kaydedilmiş veriler gösteriliyor.';

  @override
  String errorDataLoad(Object error) {
    return 'Veri yüklenirken hata oluştu: $error';
  }

  @override
  String errorLocationChange(Object error) {
    return 'Konum değiştirilemedi: $error';
  }

  @override
  String errorGpsRefresh(Object error) {
    return 'GPS yenileme hatası: $error';
  }

  @override
  String gpsUpdated(Object location) {
    return 'GPS konumu güncellendi: $location';
  }

  @override
  String get errorParseFormat =>
      'Veri formatı değişmiş olabilir. Lütfen uygulamayı güncellemeyi deneyin.';

  @override
  String get loading => 'Yükleniyor...';

  @override
  String get today => 'BUGÜN';

  @override
  String get nextLabel => 'SONRAKİ';

  @override
  String adhanAt(Object prayer, Object time) {
    return '$prayer ezanı $time\'de';
  }

  @override
  String get upcomingTitle => 'Sıradaki';

  @override
  String get upcomingAll => 'Tümü';

  @override
  String get upcomingEmpty => 'Yaklaşan bildirim veya alarm yok';

  @override
  String get alarmQrRequired => 'QR görevi için bir kod okut ya da yaz';

  @override
  String get alarmPickSavedCode => 'Kayıtlı kodlardan seç';

  @override
  String get alarmAnchorQuestion => 'Hangi vakte göre?';

  @override
  String get alarmBefore => 'Önce';

  @override
  String get alarmAfter => 'Sonra';

  @override
  String get alarmBeforePrayer => 'Vakitten önce';

  @override
  String get alarmAfterPrayer => 'Vakitten sonra';

  @override
  String get alarmSoundImportFailed => 'Ses dosyası alınamadı';

  @override
  String get alarmSnoozeMinutes => 'Erteleme süresi';

  @override
  String get qrSaveTitle => 'Kodu kütüphaneye kaydet';

  @override
  String get qrSaveHint => 'Örn. Banyo aynası';

  @override
  String get qrLibraryEmpty =>
      'Henüz kayıtlı kod yok — okuttuğun kodu kaydederek başla';

  @override
  String get qrRenameTitle => 'Kodu yeniden adlandır';

  @override
  String get qrInUseTitle => 'Kod kullanımda';

  @override
  String qrInUseBody(Object alarms) {
    return 'Bu kodu şu alarmlar görev olarak kullanıyor: $alarms. Kütüphaneden silmek alarmı bozmaz ama kodu yeniden seçemezsin.';
  }

  @override
  String get qrDeleteAnyway => 'Yine de sil';

  @override
  String get qrDefaultName => 'QR kod';

  @override
  String get qrFieldHint => 'Kodu okut ya da yaz';

  @override
  String get qrScanTooltip => 'Kodu okut';

  @override
  String get qrFieldNote =>
      'Kodu yatağından uzak bir yere yapıştır: banyo kapısı, mutfak. Alarm ancak bu kod okutulunca kapanır.';

  @override
  String get stopJustNow => 'az önce';

  @override
  String stopMinutesAgo(Object minutes) {
    return '$minutes dk önce';
  }

  @override
  String stopSnoozeLeft(Object count) {
    return '$count hak kaldı';
  }

  @override
  String get stopDoMission => 'Görevi yap';

  @override
  String stopReturnsIn(Object countdown) {
    return 'Seçim yapmazsan alarm $countdown sonra döner';
  }

  @override
  String stopClosesIn(Object countdown) {
    return 'Dokunmazsan $countdown sonra kapanır';
  }

  @override
  String get missionTimeUp => 'Süre doldu, alarm geri dönüyor';

  @override
  String get missionCountdownNote => 'süre bitince alarm geri döner';

  @override
  String get missionCloseCompletely => 'Alarmı tamamen kapat';

  @override
  String get missionWrongAnswer => 'Yanlış, tekrar dene.';

  @override
  String get missionShakeDone => 'tamamlandı';

  @override
  String get qrMissionNoCode => 'Bu alarma kayıtlı bir QR kod yok.';

  @override
  String get qrMissionNoCodeHint =>
      'Alarmı düzenleyip kod ekleyebilir ya da acil çıkışı kullanabilirsin.';

  @override
  String get qrMissionMismatch => 'Farklı bir kod okundu';

  @override
  String get qrMissionScanSaved => 'Kaydettiğin kodu okut';

  @override
  String get qrMissionFindCode =>
      'Alarmı kurarken kaydettiğin kodu bul ve onu okut.';

  @override
  String get qrMissionAimCamera => 'Kamerayı koda doğru tut.';

  @override
  String get abortDismissing => 'alarmı kapatıyorum';

  @override
  String get abortDismissingHard => 'görevi yapmadan alarmı kapatıyorum';

  @override
  String get abortTitle => 'Alarmı görevi yapmadan kapatıyorsun.';

  @override
  String get abortMaxLevel =>
      'Çıkış artık en zor kademede; daha da zorlaşmayacak.';

  @override
  String get abortHarderNext => 'Bir dahaki sefere çıkış daha zor olacak.';

  @override
  String abortTypePhrase(Object phrase) {
    return 'Şunu birebir yaz: “$phrase”';
  }

  @override
  String get abortPhraseHint => 'Cümleyi yaz';

  @override
  String get abortHoldToClose => 'Kapatmak için 3 saniye basılı tut';

  @override
  String get remindersUpdate => 'Güncelle';

  @override
  String get remindersUpdateTitle => 'Bildirimi Güncelle';

  @override
  String get remindersAddTitle => 'Yeni Bildirim Ekle';

  @override
  String get remindersAddButton => 'Bildirim Ekle';

  @override
  String get remindersWhichPrayer =>
      'Hangi vakitte bildirim almak istiyorsunuz?';

  @override
  String get remindersPrayerSection => 'Namaz Vakti';

  @override
  String get remindersDerivedSection => 'Türetilmiş Vakitler';

  @override
  String get remindersDerivedHint =>
      'Kerahat ve nafile pencereleri, seçtiğin vakitten hesaplanır.';

  @override
  String get remindersTimeSection => 'Bildirim Zamanı';

  @override
  String get remindersDaysSection => 'Günler';

  @override
  String get remindersLabelSection => 'Etiket (isteğe bağlı)';

  @override
  String get remindersOnTimeOption => 'Tam vaktinde';

  @override
  String get remindersBeforeOption => 'Öncesinde';

  @override
  String get remindersPickMinutes => 'Dakika seçin';

  @override
  String get remindersMinOffsetError => 'En az 1 dk önce olabilir';

  @override
  String remindersMaxOffsetError(Object max) {
    return 'Bu vakitten en fazla $max dk önce bildirim ekleyebilirsin.';
  }

  @override
  String get remindersSwipeToDelete => 'Silmek için satırı sola kaydırın.';

  @override
  String get remindersIntro =>
      'Her vakit için tam vaktinde veya X dakika önce hatırlatma alabilirsiniz.';

  @override
  String get alarmsSwipeHint =>
      'Silmek için satırı sola kaydırın; yanlışlıkla silersen alttaki \"Geri al\" ile dönersin. Alarmlar vakit güncellendiğinde otomatik yeniden planlanır.';

  @override
  String get alarmsRescheduleNote =>
      'Alarmlar vakit verisi güncellendikçe yeniden planlanır.';

  @override
  String get alarmsUnsupported =>
      'Sesli alarm bu cihazda desteklenmiyor (iOS 26 ve üzeri gerekir). Alarmlar kaydedilir ancak çalmaz.';

  @override
  String get alarmsNeedPermission => 'Alarmların çalması için izin gerekiyor.';

  @override
  String get permissionGrant => 'İzin ver';

  @override
  String get notificationsNeedPermission =>
      'Bildirim almak için izin vermeniz gerekiyor.';

  @override
  String get exactAlarmOff =>
      'Tam zamanlı alarm kapalı. Bildirimler gecikebilir.';

  @override
  String get actionOpen => 'Aç';

  @override
  String alarmDeleted(Object label) {
    return '$label alarmı silindi';
  }

  @override
  String get alarmBlockedSnoozed =>
      'Bu alarm ertelendi ve görevi bekliyor; görevi yapmadan kapatılamaz.';

  @override
  String get alarmTurnedOff => 'Alarm kapatıldı';

  @override
  String snoozeUntil(Object time) {
    return '$time\'te çalacak';
  }

  @override
  String get themeDark => 'Koyu';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLabel => 'Tema';

  @override
  String get appearanceTimeColor => 'Vakte göre renk';

  @override
  String get appearanceTimeColorOn => 'Zemin gün içinde ilerler';

  @override
  String get appearanceTimeColorOff => 'Sabit bir palet seçin';

  @override
  String get settingsVersionLoading => 'Sürüm yükleniyor...';

  @override
  String settingsVersion(Object version) {
    return 'Sürüm $version';
  }

  @override
  String get settingsFooter =>
      'Vakitler cihazınızda saklanır, dışarı gönderilmez.';

  @override
  String get privacyBody =>
      'Konumunuz yalnızca namaz vakitlerini hesaplamak için kullanılır ve cihazınızda saklanır. Vakit verisi Aladhan API üzerinden koordinatla sorgulanır; kişisel bilgi gönderilmez.';

  @override
  String dstSummer(Object offset) {
    return 'Yaz saati uygulanıyor ($offset)';
  }

  @override
  String dstWinter(Object offset) {
    return 'Kış saati uygulanıyor ($offset)';
  }

  @override
  String get weekdayShortMon => 'Pzt';

  @override
  String get weekdayShortTue => 'Sal';

  @override
  String get weekdayShortWed => 'Çar';

  @override
  String get weekdayShortThu => 'Per';

  @override
  String get weekdayShortFri => 'Cum';

  @override
  String get weekdayShortSat => 'Cmt';

  @override
  String get weekdayShortSun => 'Paz';

  @override
  String get weekdayLetterMon => 'Pt';

  @override
  String get weekdayLetterTue => 'Sa';

  @override
  String get weekdayLetterWed => 'Ça';

  @override
  String get weekdayLetterThu => 'Pe';

  @override
  String get weekdayLetterFri => 'Cu';

  @override
  String get weekdayLetterSat => 'Ct';

  @override
  String get weekdayLetterSun => 'Pa';

  @override
  String offsetMinutes(Object sign, Object minutes) {
    return '$sign$minutes dk';
  }

  @override
  String snoozedLabel(Object time) {
    return 'Ertelendi · $time\'te çalacak';
  }

  @override
  String errorGenericWith(Object error) {
    return 'Hata: $error';
  }

  @override
  String locationDeleted(Object location) {
    return '$location silindi';
  }

  @override
  String get androidChannelName => 'Ezan Vakti Bildirimleri';

  @override
  String get androidChannelDescription =>
      'Namaz vakitlerini bildiren bildirimler';

  @override
  String missionSnoozeAction(int minutes, int count) {
    return '$minutes dk ertele · $count hak';
  }

  @override
  String get appName => 'Ezan Vakti & Alarm';

  @override
  String get alarmAnchorLabel => 'Vakit';

  @override
  String offsetRangeHint(int max) {
    return '1 - $max dk';
  }

  @override
  String stopSnoozeAction(int minutes) {
    return 'Ertele · $minutes dk';
  }

  @override
  String get actionBack => 'Geri';

  @override
  String get locationAutoDetect => 'Otomatik konum tespiti';

  @override
  String get locationFindWithGps => 'GPS ile Bul';

  @override
  String locationsCount(int count) {
    return '$count konum';
  }

  @override
  String get countdownLessThanMinute => '<1dk';

  @override
  String countdownMinutesShort(int minutes) {
    return '${minutes}dk';
  }

  @override
  String countdownHourMinuteShort(int hours, int minutes) {
    return '${hours}s ${minutes}dk';
  }

  @override
  String get missionShakeRemaining => 'kez daha salla';

  @override
  String get gpsFallbackLabel => 'GPS Konumu';

  @override
  String get alarmFixedSection => 'Saat';

  @override
  String get alarmTimingSection => 'Zamanlama';

  @override
  String get alarmExactTime => 'Tam vaktinde';

  @override
  String alarmSnoozeMinutesOption(int minutes) {
    return '$minutes dakika';
  }

  @override
  String get alarmDefaultLabel => 'Alarm';

  @override
  String get soundFileTypeLabel => 'Ses';

  @override
  String get stopHeadline => 'ALARM DURDURULDU';

  @override
  String stopMissionSummary(String mission, String level, int seconds) {
    return '$mission · $level · $seconds sn';
  }

  @override
  String get missionAnswerHint => 'Cevap';

  @override
  String get missionFinish => 'Bitir';

  @override
  String get missionConfirm => 'Onayla';

  @override
  String missionAbortWait(int seconds) {
    return 'Bekle: $seconds sn';
  }

  @override
  String get qrScannerTitle => 'Kodu okut';

  @override
  String get qrSectionLabel => 'QR KOD';

  @override
  String get locationTypeGps => 'GPS Konumu';

  @override
  String get locationTypeManual => 'Manuel';

  @override
  String get locationSearchAddress => 'Adres Ara';

  @override
  String locationSaveFailed(String error) {
    return 'Kaydedilemedi: $error';
  }

  @override
  String locationGlobalCalculation(String method, String school) {
    return 'Genel ayar: $method · $school';
  }

  @override
  String get versionUnknown => 'Bilinmiyor';

  @override
  String get errorLocationPermission => 'Konum izni gerekli';
}
