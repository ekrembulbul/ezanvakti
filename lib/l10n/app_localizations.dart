import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('tr'),
  ];

  /// Namaz vakti adı
  ///
  /// In tr, this message translates to:
  /// **'İmsak'**
  String get prayerFajr;

  /// Namaz vakti adı
  ///
  /// In tr, this message translates to:
  /// **'Güneş'**
  String get prayerSunrise;

  /// Namaz vakti adı
  ///
  /// In tr, this message translates to:
  /// **'Öğle'**
  String get prayerDhuhr;

  /// Namaz vakti adı
  ///
  /// In tr, this message translates to:
  /// **'İkindi'**
  String get prayerAsr;

  /// Namaz vakti adı
  ///
  /// In tr, this message translates to:
  /// **'Akşam'**
  String get prayerMaghrib;

  /// Namaz vakti adı
  ///
  /// In tr, this message translates to:
  /// **'Yatsı'**
  String get prayerIsha;

  /// Alt gezinme
  ///
  /// In tr, this message translates to:
  /// **'Vakitler'**
  String get navPrayerTimes;

  /// Alt gezinme
  ///
  /// In tr, this message translates to:
  /// **'Takvim'**
  String get navCalendar;

  /// Alt gezinme
  ///
  /// In tr, this message translates to:
  /// **'Hatırlatıcılar'**
  String get navReminders;

  /// Alt gezinme
  ///
  /// In tr, this message translates to:
  /// **'Araçlar'**
  String get navTools;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get actionCancel;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get actionSave;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get actionDelete;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get actionOk;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Geri al'**
  String get actionUndo;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Paylaş'**
  String get actionShare;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Kopyala'**
  String get actionCopy;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Sıfırla'**
  String get actionReset;

  /// Hata ekranindaki tekrar dene dugmesi.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden Dene'**
  String get actionRetry;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settingsTitle;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Genel'**
  String get settingsGeneral;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Görünüm'**
  String get settingsAppearance;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Bilgi'**
  String get settingsInfo;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Bildirim ve ses'**
  String get settingsNotificationsAndSound;

  /// Ayar satırı
  ///
  /// In tr, this message translates to:
  /// **'Konum'**
  String get settingsLocation;

  /// Ayar satırı
  ///
  /// In tr, this message translates to:
  /// **'Hesaplama'**
  String get settingsCalculation;

  /// Ayar satırı
  ///
  /// In tr, this message translates to:
  /// **'Veri kaynağı'**
  String get settingsDataSource;

  /// Ayar satırı
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik'**
  String get settingsPrivacy;

  /// Ayar satırı
  ///
  /// In tr, this message translates to:
  /// **'Saat biçimi'**
  String get settingsTimeFormat;

  /// Ayar satırı
  ///
  /// In tr, this message translates to:
  /// **'Sessiz pencereler'**
  String get settingsQuietWindows;

  /// Saat biçimi seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get timeFormatSystem;

  /// Saat biçimi seçeneği
  ///
  /// In tr, this message translates to:
  /// **'24 saat'**
  String get timeFormat24;

  /// Saat biçimi seçeneği
  ///
  /// In tr, this message translates to:
  /// **'12 saat'**
  String get timeFormat12;

  /// Ayar satırı
  ///
  /// In tr, this message translates to:
  /// **'Konumu otomatik izle'**
  String get settingsAutoLocation;

  /// Ayar açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Şehir değişince vakitler kendiliğinden güncellenir.'**
  String get settingsAutoLocationHint;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Araçlar'**
  String get toolsTitle;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Yön'**
  String get toolsDirection;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Takip'**
  String get toolsTracking;

  /// Araç adı
  ///
  /// In tr, this message translates to:
  /// **'Kıble'**
  String get toolsQibla;

  /// Araç açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Kâbe yönünü pusulayla bul'**
  String get toolsQiblaHint;

  /// Araç adı
  ///
  /// In tr, this message translates to:
  /// **'Namaz takibi'**
  String get toolsPrayerTracking;

  /// Araç açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Kıldıklarını işaretle, kazanı say'**
  String get toolsPrayerTrackingHint;

  /// Araç adı
  ///
  /// In tr, this message translates to:
  /// **'Zikirmatik'**
  String get toolsDhikr;

  /// Araç açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Hedefli sayaç'**
  String get toolsDhikrHint;

  /// Alt bilgi
  ///
  /// In tr, this message translates to:
  /// **'Araçlar cihazında çalışır; hiçbir veri dışarı gönderilmez.'**
  String get toolsPrivacyNote;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Kıble'**
  String get qiblaTitle;

  /// Açı açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Kuzeyden sağa doğru'**
  String get qiblaFromNorth;

  /// Boş durum başlığı
  ///
  /// In tr, this message translates to:
  /// **'Konum gerekiyor'**
  String get qiblaNeedsLocation;

  /// Boş durum açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Kıble yönü için önce bir konum seç ya da GPS ile bul.'**
  String get qiblaNeedsLocationHint;

  /// Durum metni
  ///
  /// In tr, this message translates to:
  /// **'Pusula bekleniyor…'**
  String get qiblaWaiting;

  /// Kalibrasyon uyarısı
  ///
  /// In tr, this message translates to:
  /// **'Pusula kalibrasyon istiyor. Telefonu havada sekiz çizerek birkaç saniye hareket ettir.'**
  String get qiblaCalibrate;

  /// Hizalandı bildirimi
  ///
  /// In tr, this message translates to:
  /// **'Kıbleye dönüksün'**
  String get qiblaAligned;

  /// Yön talimatı
  ///
  /// In tr, this message translates to:
  /// **'{degrees}° sağa dön'**
  String qiblaTurnRight(Object degrees);

  /// Yön talimatı
  ///
  /// In tr, this message translates to:
  /// **'{degrees}° sola dön'**
  String qiblaTurnLeft(Object degrees);

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Namaz takibi'**
  String get trackingTitle;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Son 7 gün'**
  String get trackingLastDays;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Kaza sayacı'**
  String get trackingQadaCounter;

  /// Durum etiketi
  ///
  /// In tr, this message translates to:
  /// **'Kıldım'**
  String get trackingDone;

  /// Durum etiketi
  ///
  /// In tr, this message translates to:
  /// **'Kaza'**
  String get trackingQada;

  /// Durum etiketi
  ///
  /// In tr, this message translates to:
  /// **'Boş'**
  String get trackingEmpty;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Zikirmatik'**
  String get dhikrTitle;

  /// Ayar satırı
  ///
  /// In tr, this message translates to:
  /// **'Hedef'**
  String get dhikrTarget;

  /// Yönerge
  ///
  /// In tr, this message translates to:
  /// **'Saymak için ekrana dokun'**
  String get dhikrTapToCount;

  /// İlerleme metni
  ///
  /// In tr, this message translates to:
  /// **'Hedefe {remaining} · Tur {laps}'**
  String dhikrProgress(Object remaining, Object laps);

  /// Günlük toplam
  ///
  /// In tr, this message translates to:
  /// **'Bugün toplam {count}'**
  String dhikrTodayTotal(Object count);

  /// Diyalog başlığı
  ///
  /// In tr, this message translates to:
  /// **'Sayacı sıfırla'**
  String get dhikrResetTitle;

  /// Diyalog gövdesi
  ///
  /// In tr, this message translates to:
  /// **'Bugünkü zikir sayısı silinecek.'**
  String get dhikrResetBody;

  /// Bildirim gövdesi
  ///
  /// In tr, this message translates to:
  /// **'{prayer} vakti girdi'**
  String notificationPrayerNow(Object prayer);

  /// Bildirim başlığı
  ///
  /// In tr, this message translates to:
  /// **'{prayer} vakti yaklaşıyor'**
  String notificationPrayerSoon(Object prayer);

  /// Bildirim gövdesi
  ///
  /// In tr, this message translates to:
  /// **'{prayer} vaktine {minutes} dakika kaldı'**
  String notificationMinutesLeft(Object prayer, Object minutes);

  /// Türetilmiş vakit bildirimi
  ///
  /// In tr, this message translates to:
  /// **'{name} yaklaşıyor'**
  String notificationDerivedSoon(Object name);

  /// Türetilmiş vakit bildirimi
  ///
  /// In tr, this message translates to:
  /// **'{name} vaktine {minutes} dakika kaldı'**
  String notificationDerivedMinutesLeft(Object name, Object minutes);

  /// Dini gün bildirimi
  ///
  /// In tr, this message translates to:
  /// **'{name} bugün. Tarih hesaplanmıştır; Diyanet takvimiyle bir gün farklı olabilir.'**
  String religiousDayTodayEstimated(Object name);

  /// Dini gün bildirimi
  ///
  /// In tr, this message translates to:
  /// **'{name} bugün.'**
  String religiousDayToday(Object name);

  /// Dini gün bildirimi
  ///
  /// In tr, this message translates to:
  /// **'{name} yarın'**
  String religiousDayTomorrowTitle(Object name);

  /// Dini gün bildirimi
  ///
  /// In tr, this message translates to:
  /// **'{name} yarın idrak edilecek.'**
  String religiousDayTomorrowBody(Object name);

  /// Türetilmiş vakit
  ///
  /// In tr, this message translates to:
  /// **'İşrak'**
  String get derivedIshraq;

  /// Türetilmiş vakit
  ///
  /// In tr, this message translates to:
  /// **'Kerahat (zeval)'**
  String get derivedIstiwa;

  /// Türetilmiş vakit
  ///
  /// In tr, this message translates to:
  /// **'Kerahat (akşam öncesi)'**
  String get derivedPreMaghrib;

  /// Türetilmiş vakit
  ///
  /// In tr, this message translates to:
  /// **'Gece yarısı'**
  String get derivedMidnight;

  /// Türetilmiş vakit
  ///
  /// In tr, this message translates to:
  /// **'Gecenin son üçte biri'**
  String get derivedLastThird;

  /// Türetilmiş vakit açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Güneşten sonra kerahat biter'**
  String get derivedIshraqHint;

  /// Türetilmiş vakit açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Öğleden önceki kerahat başlar'**
  String get derivedIstiwaHint;

  /// Türetilmiş vakit açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Akşamdan önceki kerahat başlar'**
  String get derivedPreMaghribHint;

  /// Türetilmiş vakit açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Şer\'i gecenin ortası'**
  String get derivedMidnightHint;

  /// Türetilmiş vakit açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Teheccüd vakti başlar'**
  String get derivedLastThirdHint;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Hatırlatıcılar'**
  String get remindersTitle;

  /// Segment
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get remindersNotifications;

  /// Segment
  ///
  /// In tr, this message translates to:
  /// **'Alarmlar'**
  String get remindersAlarms;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Henüz bildirim yok'**
  String get remindersNoNotifications;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Namaz vakitlerinde hatırlatma almak için\nbildirim ekleyin.'**
  String get remindersNoNotificationsHint;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Henüz alarm yok'**
  String get remindersNoAlarms;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Sabit saatli veya vakte göre alarm ekle'**
  String get remindersNoAlarmsHint;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'{count} hatırlatma'**
  String remindersCount(Object count);

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'{count} alarm'**
  String remindersAlarmCount(Object count);

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Cuma namazı hatırlatıcısı ekle'**
  String get remindersAddFriday;

  /// Hazır şablon etiketi
  ///
  /// In tr, this message translates to:
  /// **'Cuma namazı'**
  String get reminderFridayLabel;

  /// Bildirim satırı
  ///
  /// In tr, this message translates to:
  /// **'Tam vaktinde'**
  String get reminderOnTime;

  /// Bildirim satırı
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dk önce'**
  String reminderMinutesBefore(Object minutes);

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca bu sefer atlanacak'**
  String get reminderSkippedOnce;

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'Kapalı'**
  String get reminderOff;

  /// Hata durumu
  ///
  /// In tr, this message translates to:
  /// **'Kurulamadı — düzenleyip kaydederek yeniden dene'**
  String get reminderScheduleFailed;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Sessiz pencereler'**
  String get quietTitle;

  /// Açıklama
  ///
  /// In tr, this message translates to:
  /// **'Bu aralıklarda Ezan Vakti bildirimleri sessiz gösterilir ya da hiç gösterilmez. iPhone\'da bir uygulama telefonu sessize alamaz; bu ayar yalnızca uygulamanın kendi bildirimlerini etkiler, alarmlara dokunmaz.'**
  String get quietIntro;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Cuma namazı'**
  String get quietFridaySection;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Cuma vaktinde sessiz'**
  String get quietFridayTitle;

  /// Ayar açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Cuma öğle vaktinin çevresinde bildirimler susar. Süreleri değiştirebilir ya da tamamen kapatabilirsin.'**
  String get quietFridayHint;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Özel pencereler'**
  String get quietCustomSection;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Henüz özel pencere yok.'**
  String get quietNoCustom;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Pencere ekle'**
  String get quietAddWindow;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Kaç dakika önce'**
  String get quietMinutesBefore;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Kaç dakika sonra'**
  String get quietMinutesAfter;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Bu aralıkta'**
  String get quietModeLabel;

  /// Seçenek
  ///
  /// In tr, this message translates to:
  /// **'Sessiz göster'**
  String get quietModeSilent;

  /// Seçenek açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Bildirim görünür, ses çalmaz'**
  String get quietModeSilentHint;

  /// Seçenek
  ///
  /// In tr, this message translates to:
  /// **'Hiç gösterme'**
  String get quietModeSkip;

  /// Seçenek açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Bildirim hiç planlanmaz'**
  String get quietModeSkipHint;

  /// Özet
  ///
  /// In tr, this message translates to:
  /// **'{before} dk önce – {after} dk sonra'**
  String quietWindowSummary(Object before, Object after);

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Vakit'**
  String get quietPrayerLabel;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Yeni bildirim sesi'**
  String get prefsNewSound;

  /// Ses seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Sistem sesi'**
  String get soundSystem;

  /// Ses açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Cihazın varsayılan bildirim sesi'**
  String get soundSystemHint;

  /// Ses seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Kısa uyarı'**
  String get soundBeep;

  /// Ses açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Uygulamanın kendi kısa tonu'**
  String get soundBeepHint;

  /// Ses seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Sessiz'**
  String get soundSilent;

  /// Ses açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Bildirim görünür, ses çalmaz'**
  String get soundSilentHint;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Odak modunda göster'**
  String get prefsShowInFocus;

  /// Ayar açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler Odak açıkken özete düşmez. Telefonun sessiz anahtarını delmez.'**
  String get prefsShowInFocusHint;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Dini günler'**
  String get prefsReligiousDays;

  /// Ayar açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Kandil, bayram ve mübarek günlerde akşam vakti hatırlatır. Tarihler hicri takvimden hesaplanır; Diyanet takvimiyle bir gün farklı olabilir.'**
  String get prefsReligiousDaysHint;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Bir gün önce de hatırlat'**
  String get prefsReligiousDayEve;

  /// Ayar açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Öğle vaktinde \"yarın\" bildirimi gönderir.'**
  String get prefsReligiousDayEveHint;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Alarm ekle'**
  String get alarmAdd;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Alarmı düzenle'**
  String get alarmEdit;

  /// Alarm türü
  ///
  /// In tr, this message translates to:
  /// **'Sabit saat'**
  String get alarmFixedTime;

  /// Alarm türü
  ///
  /// In tr, this message translates to:
  /// **'Vakte göre'**
  String get alarmAnchored;

  /// Bölüm
  ///
  /// In tr, this message translates to:
  /// **'Tekrar'**
  String get alarmRepeat;

  /// Bölüm
  ///
  /// In tr, this message translates to:
  /// **'Etiket'**
  String get alarmLabel;

  /// Alan ipucu
  ///
  /// In tr, this message translates to:
  /// **'Örn. Sahur'**
  String get alarmLabelHint;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Ses'**
  String get alarmSound;

  /// Ses seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Varsayılan'**
  String get alarmSoundDefault;

  /// Ses seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Özel ses'**
  String get alarmSoundCustom;

  /// Ses seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Cihazdan ses seç…'**
  String get alarmSoundPick;

  /// Bilgi notu
  ///
  /// In tr, this message translates to:
  /// **'Alarm, Zil Sesi ve Uyarılar ses seviyesiyle çalar.'**
  String get alarmSoundVolumeNote;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Titreşim'**
  String get alarmVibrate;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Ertele (snooze)'**
  String get alarmSnooze;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Erteleme sayısı'**
  String get alarmSnoozeCount;

  /// Seçenek
  ///
  /// In tr, this message translates to:
  /// **'Sınırsız'**
  String get alarmSnoozeUnlimited;

  /// Seçenek
  ///
  /// In tr, this message translates to:
  /// **'{count} kez'**
  String alarmSnoozeTimes(Object count);

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Kapatma görevi'**
  String get alarmMission;

  /// Alt sayfa başlığı
  ///
  /// In tr, this message translates to:
  /// **'Alarmı nasıl kapatacaksın?'**
  String get alarmMissionQuestion;

  /// Görev
  ///
  /// In tr, this message translates to:
  /// **'Görev yok'**
  String get missionNone;

  /// Görev açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Kaydırarak doğrudan kapanır'**
  String get missionNoneHint;

  /// Görev
  ///
  /// In tr, this message translates to:
  /// **'Matematik'**
  String get missionMath;

  /// Görev açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Soruları çözmeden kapanmaz'**
  String get missionMathHint;

  /// Görev
  ///
  /// In tr, this message translates to:
  /// **'Sallama'**
  String get missionShake;

  /// Görev açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Telefonu sallayarak kapatılır'**
  String get missionShakeHint;

  /// Görev
  ///
  /// In tr, this message translates to:
  /// **'QR okutma'**
  String get missionQr;

  /// Görev açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı kodu okutmadan kapanmaz'**
  String get missionQrHint;

  /// Tekrar
  ///
  /// In tr, this message translates to:
  /// **'Her gün'**
  String get alarmEveryDay;

  /// Tekrar
  ///
  /// In tr, this message translates to:
  /// **'Hafta içi'**
  String get alarmWeekdays;

  /// Tekrar
  ///
  /// In tr, this message translates to:
  /// **'Hafta sonu'**
  String get alarmWeekend;

  /// Kopyalanan alarmin etiketi.
  ///
  /// In tr, this message translates to:
  /// **'{label} (kopya)'**
  String alarmCopySuffix(String label);

  /// Menü
  ///
  /// In tr, this message translates to:
  /// **'Kopyala'**
  String get alarmDuplicate;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Bir şeyler ters gitti'**
  String get errorGeneric;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Vakit Takvimi'**
  String get calendarTitle;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Takvimi paylaş'**
  String get calendarShare;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Takvim verisi bulunamadı'**
  String get calendarEmpty;

  /// Yükleme
  ///
  /// In tr, this message translates to:
  /// **'Takvim yükleniyor...'**
  String get calendarLoading;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Takvim görüntüsü oluşturulamadı'**
  String get calendarShareFailed;

  /// Alt başlık
  ///
  /// In tr, this message translates to:
  /// **'{count} gün'**
  String calendarDayCount(Object count);

  /// Kart başlığı
  ///
  /// In tr, this message translates to:
  /// **'SIRADAKİ'**
  String get upcomingNext;

  /// Satır başlığı
  ///
  /// In tr, this message translates to:
  /// **'{prayer} bildirimi'**
  String upcomingNotification(Object prayer);

  /// Gün etiketi; cümle içinde geçtiği için küçük harf
  ///
  /// In tr, this message translates to:
  /// **'yarın'**
  String get upcomingTomorrow;

  /// Gün etiketi; cümle içinde geçtiği için küçük harf
  ///
  /// In tr, this message translates to:
  /// **'bugün'**
  String get upcomingToday;

  /// Bildirim mesajı
  ///
  /// In tr, this message translates to:
  /// **'Bildirim eklendi'**
  String get snackNotificationAdded;

  /// Bildirim mesajı
  ///
  /// In tr, this message translates to:
  /// **'Bildirim güncellendi'**
  String get snackNotificationUpdated;

  /// Bildirim mesajı
  ///
  /// In tr, this message translates to:
  /// **'Bildirim silindi'**
  String get snackNotificationDeleted;

  /// Hata mesajı
  ///
  /// In tr, this message translates to:
  /// **'Bu bildirim zaten mevcut'**
  String get snackNotificationExists;

  /// Bildirim mesajı
  ///
  /// In tr, this message translates to:
  /// **'Alarm silindi'**
  String get snackAlarmDeleted;

  /// Eylem
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca bu sefer'**
  String get snackSkipOnce;

  /// Eylem
  ///
  /// In tr, this message translates to:
  /// **'Geri al'**
  String get snackUndo;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Konumlar'**
  String get locationTitle;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Konum ekle'**
  String get locationAdd;

  /// Alan ipucu
  ///
  /// In tr, this message translates to:
  /// **'Şehir ara'**
  String get locationSearch;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Konumumu kullan'**
  String get locationUseGps;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı konum yok'**
  String get locationEmpty;

  /// Paylaşım metni
  ///
  /// In tr, this message translates to:
  /// **'{location} · {period} namaz vakitleri'**
  String shareCaption(Object location, Object period);

  /// Sayaç etiketi
  ///
  /// In tr, this message translates to:
  /// **'İftara'**
  String get ramadanIftarCountdown;

  /// Sayaç etiketi
  ///
  /// In tr, this message translates to:
  /// **'Sahurun bitişine'**
  String get ramadanSuhoorCountdown;

  /// Gün etiketi
  ///
  /// In tr, this message translates to:
  /// **'Ramazan {day}. gün'**
  String ramadanDay(Object day);

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Ramazan İmsakiyesi'**
  String get ramadanCalendarTitle;

  /// Bölüm başlığı
  ///
  /// In tr, this message translates to:
  /// **'Oruç takibi'**
  String get ramadanFastingSection;

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'Tuttum'**
  String get ramadanFasted;

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'Kaza'**
  String get ramadanFastMissed;

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'Muaf'**
  String get ramadanFastExempt;

  /// Sayaç
  ///
  /// In tr, this message translates to:
  /// **'Kaza orucu'**
  String get ramadanFastingQada;

  /// Diyalog başlığı
  ///
  /// In tr, this message translates to:
  /// **'Ramazan hatırlatmaları'**
  String get ramadanSetupTitle;

  /// Diyalog gövdesi
  ///
  /// In tr, this message translates to:
  /// **'Sahur (imsaktan 45 dk önce) ve iftar bildirimi eklensin mi? Hatırlatıcılar listesinde görünür, dilediğinde silebilirsin.'**
  String get ramadanSetupBody;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get ramadanSetupAccept;

  /// Bildirim etiketi
  ///
  /// In tr, this message translates to:
  /// **'Sahur'**
  String get ramadanSuhoorLabel;

  /// Bildirim etiketi
  ///
  /// In tr, this message translates to:
  /// **'İftar'**
  String get ramadanIftarLabel;

  /// Bildirim mesajı
  ///
  /// In tr, this message translates to:
  /// **'Sahur ve iftar hatırlatmaları eklendi'**
  String get ramadanRemindersAdded;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Konumlar'**
  String get locationsTitle;

  /// Yükleme
  ///
  /// In tr, this message translates to:
  /// **'Konumlar yükleniyor...'**
  String get locationsLoading;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Konumlar yüklenemedi: {error}'**
  String locationsLoadFailed(Object error);

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Henüz konum eklenmedi'**
  String get locationsEmpty;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'GPS ile otomatik tespit edin veya\nadres arayarak konum seçin'**
  String get locationsEmptyHint;

  /// İpucu
  ///
  /// In tr, this message translates to:
  /// **'Aktif olmayan konumu silmek için satırı sola kaydırın.'**
  String get locationsSwipeHint;

  /// Rozet
  ///
  /// In tr, this message translates to:
  /// **'AKTİF'**
  String get locationActive;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Konum ekle'**
  String get locationAddTitle;

  /// Ekran başlığı
  ///
  /// In tr, this message translates to:
  /// **'Konumu Düzenle'**
  String get locationEditTitle;

  /// Alan ipucu
  ///
  /// In tr, this message translates to:
  /// **'Şehir, ilçe veya yer adıyla ara'**
  String get locationSearchHint;

  /// Alan ipucu
  ///
  /// In tr, this message translates to:
  /// **'Şehir, ilçe veya yer ara...'**
  String get locationSearchPlaceholder;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Aramak için yazmaya başlayın.'**
  String get locationSearchStart;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Sonuç bulunamadı.\nFarklı bir arama deneyin veya bağlantınızı kontrol edin.'**
  String get locationSearchNoResult;

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'Konum Alınıyor...'**
  String get locationGettingPosition;

  /// Diyalog başlığı
  ///
  /// In tr, this message translates to:
  /// **'Konum İzni'**
  String get locationPermissionTitle;

  /// Diyalog gövdesi
  ///
  /// In tr, this message translates to:
  /// **'Namaz vakitlerini bulunduğunuz konuma göre gösterebilmek için konum iznine ihtiyaç var. İzni vererek bulunduğunuz il/ilçe otomatik seçilecektir.'**
  String get locationPermissionBody;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'İzin Ver'**
  String get locationPermissionAllow;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Konum servisleri kapalı. Lütfen açın.'**
  String get locationServicesOff;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Konum izni kalıcı olarak reddedildi. Ayarlardan izin verin.'**
  String get locationPermissionDenied;

  /// Bildirim mesajı
  ///
  /// In tr, this message translates to:
  /// **'Konum güncellendi'**
  String get locationUpdated;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Lütfen bir konum seçin'**
  String get locationSelectFirst;

  /// Alan başlığı
  ///
  /// In tr, this message translates to:
  /// **'Özel İsim (Opsiyonel)'**
  String get locationCustomName;

  /// Alan ipucu
  ///
  /// In tr, this message translates to:
  /// **'Örn: Ev, İş, Anne Evi'**
  String get locationCustomNameHint;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Genel hesaplama ayarını kullan'**
  String get locationUseGlobalCalculation;

  /// Ayar açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Kapatırsan bu konuma özel yöntem/mezhep seçebilirsin'**
  String get locationUseGlobalCalculationHint;

  /// Bilgi notu
  ///
  /// In tr, this message translates to:
  /// **'Hesaplama yöntemi genel ayardan alınır. Bu konuma özel değiştirmek için kaydettikten sonra düzenleyin.'**
  String get locationCalculationFromGlobal;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Değiştir'**
  String get locationChange;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Geri alınamadı: {error}'**
  String locationUndoFailed(Object error);

  /// Atıf
  ///
  /// In tr, this message translates to:
  /// **'© OpenStreetMap katkıcıları'**
  String get osmAttribution;

  /// Widget etiketi
  ///
  /// In tr, this message translates to:
  /// **'Yarın'**
  String get widgetTomorrow;

  /// Widget etiketi
  ///
  /// In tr, this message translates to:
  /// **'Güncel değil'**
  String get widgetStale;

  /// Widget etiketi
  ///
  /// In tr, this message translates to:
  /// **'Vakitler için uygulamayı aç'**
  String get widgetOpenApp;

  /// Widget etiketi
  ///
  /// In tr, this message translates to:
  /// **'Uygulamayı güncelleyin'**
  String get widgetUpdateApp;

  /// Siri cevabı
  ///
  /// In tr, this message translates to:
  /// **'{prayer} {time}, {remaining} kaldı.'**
  String siriAnswer(Object prayer, Object time, Object remaining);

  /// Süre biçimi
  ///
  /// In tr, this message translates to:
  /// **'{hours} saat {minutes} dakika'**
  String durationHourMinute(Object hours, Object minutes);

  /// Süre biçimi
  ///
  /// In tr, this message translates to:
  /// **'{hours} saat'**
  String durationHour(Object hours);

  /// Süre biçimi
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dakika'**
  String durationMinute(Object minutes);

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Muharrem'**
  String get hijriMuharram;

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Safer'**
  String get hijriSafar;

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Rebiülevvel'**
  String get hijriRabiAwwal;

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Rebiülahir'**
  String get hijriRabiThani;

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Cemaziyülevvel'**
  String get hijriJumadaAwwal;

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Cemaziyülahir'**
  String get hijriJumadaThani;

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Recep'**
  String get hijriRajab;

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Şaban'**
  String get hijriShaban;

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Ramazan'**
  String get hijriRamadan;

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Şevval'**
  String get hijriShawwal;

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Zilkade'**
  String get hijriDhulQadah;

  /// Hicri ay
  ///
  /// In tr, this message translates to:
  /// **'Zilhicce'**
  String get hijriDhulHijjah;

  /// Dini gün
  ///
  /// In tr, this message translates to:
  /// **'Hicri Yılbaşı'**
  String get religiousNewYear;

  /// Dini gün
  ///
  /// In tr, this message translates to:
  /// **'Aşure Günü'**
  String get religiousAshura;

  /// Dini gün
  ///
  /// In tr, this message translates to:
  /// **'Mevlid Kandili'**
  String get religiousMawlid;

  /// Dini gün
  ///
  /// In tr, this message translates to:
  /// **'Regaib Kandili'**
  String get religiousRegaib;

  /// Dini gün
  ///
  /// In tr, this message translates to:
  /// **'Miraç Kandili'**
  String get religiousMiraj;

  /// Dini gün
  ///
  /// In tr, this message translates to:
  /// **'Berat Kandili'**
  String get religiousBaraat;

  /// Dini gün
  ///
  /// In tr, this message translates to:
  /// **'Ramazan Başlangıcı'**
  String get religiousRamadanStart;

  /// Dini gün
  ///
  /// In tr, this message translates to:
  /// **'Kadir Gecesi'**
  String get religiousQadr;

  /// Dini gün
  ///
  /// In tr, this message translates to:
  /// **'Ramazan Bayramı'**
  String get religiousEidFitr;

  /// Dini gün
  ///
  /// In tr, this message translates to:
  /// **'Arefe Günü'**
  String get religiousArafah;

  /// Dini gün
  ///
  /// In tr, this message translates to:
  /// **'Kurban Bayramı'**
  String get religiousEidAdha;

  /// İkindi mezhebi
  ///
  /// In tr, this message translates to:
  /// **'Şafi (Standart)'**
  String get asrShafi;

  /// İkindi mezhebi
  ///
  /// In tr, this message translates to:
  /// **'Hanefi'**
  String get asrHanafi;

  /// Enlem düzeltmesi
  ///
  /// In tr, this message translates to:
  /// **'Otomatik'**
  String get latAuto;

  /// Enlem düzeltmesi
  ///
  /// In tr, this message translates to:
  /// **'Gece ortası'**
  String get latMidnight;

  /// Enlem düzeltmesi
  ///
  /// In tr, this message translates to:
  /// **'Gecenin yedide biri'**
  String get latOneSeventh;

  /// Enlem düzeltmesi
  ///
  /// In tr, this message translates to:
  /// **'Açı tabanlı'**
  String get latAngle;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Hesaplama Yöntemi'**
  String get calcMethodLabel;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'İkindi (Mezhep)'**
  String get calcAsrLabel;

  /// Bölüm
  ///
  /// In tr, this message translates to:
  /// **'Gelişmiş'**
  String get calcAdvanced;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Yüksek Enlem Düzeltmesi'**
  String get calcLatitudeLabel;

  /// Bilgi notu
  ///
  /// In tr, this message translates to:
  /// **'Tüm konumlar için varsayılan ayar. Bir konum kendi ayarını seçmediği sürece bu kullanılır.'**
  String get calcGlobalNote;

  /// Bölüm
  ///
  /// In tr, this message translates to:
  /// **'Vakit düzeltmeleri'**
  String get calcTuneSection;

  /// Bilgi notu
  ///
  /// In tr, this message translates to:
  /// **'Vakitleri elindeki takvime göre birkaç dakika kaydırabilirsin. Bildirimler, alarmlar ve widget da kaydırılmış vakti kullanır.'**
  String get calcTuneHint;

  /// Kısa dakika
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dk'**
  String minutesShort(Object minutes);

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'Veriler güncel'**
  String get offlineFresh;

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'Veriler güncellenmeli'**
  String get offlineShouldUpdate;

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'Veriler çok eski, güncelleme gerekli'**
  String get offlineTooOld;

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'Veri bulunamadı'**
  String get offlineNoData;

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'İnternet bağlantısı yok. Kaydedilmiş veriler gösteriliyor.'**
  String get offlineNoConnection;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Veri alınamadı. Lütfen internet bağlantınızı kontrol edin.'**
  String get offlineFetchFailed;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Güncelleme başarısız. Kaydedilmiş veriler gösteriliyor.'**
  String get offlineUpdateFailed;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Veri yüklenirken hata oluştu: {error}'**
  String errorDataLoad(Object error);

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Konum değiştirilemedi: {error}'**
  String errorLocationChange(Object error);

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'GPS yenileme hatası: {error}'**
  String errorGpsRefresh(Object error);

  /// Bildirim mesajı
  ///
  /// In tr, this message translates to:
  /// **'GPS konumu güncellendi: {location}'**
  String gpsUpdated(Object location);

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Veri formatı değişmiş olabilir. Lütfen uygulamayı güncellemeyi deneyin.'**
  String get errorParseFormat;

  /// Yükleme
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor...'**
  String get loading;

  /// Takvim rozeti
  ///
  /// In tr, this message translates to:
  /// **'BUGÜN'**
  String get today;

  /// Sayaç etiketi
  ///
  /// In tr, this message translates to:
  /// **'SONRAKİ'**
  String get nextLabel;

  /// Sayaç alt bilgisi
  ///
  /// In tr, this message translates to:
  /// **'{prayer} ezanı {time}\'de'**
  String adhanAt(Object prayer, Object time);

  /// Kart başlığı
  ///
  /// In tr, this message translates to:
  /// **'Sıradaki'**
  String get upcomingTitle;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Tümü'**
  String get upcomingAll;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Yaklaşan bildirim veya alarm yok'**
  String get upcomingEmpty;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'QR görevi için bir kod okut ya da yaz'**
  String get alarmQrRequired;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı kodlardan seç'**
  String get alarmPickSavedCode;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Hangi vakte göre?'**
  String get alarmAnchorQuestion;

  /// Yön
  ///
  /// In tr, this message translates to:
  /// **'Önce'**
  String get alarmBefore;

  /// Yön
  ///
  /// In tr, this message translates to:
  /// **'Sonra'**
  String get alarmAfter;

  /// Yön
  ///
  /// In tr, this message translates to:
  /// **'Vakitten önce'**
  String get alarmBeforePrayer;

  /// Yön
  ///
  /// In tr, this message translates to:
  /// **'Vakitten sonra'**
  String get alarmAfterPrayer;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Ses dosyası alınamadı'**
  String get alarmSoundImportFailed;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Erteleme süresi'**
  String get alarmSnoozeMinutes;

  /// Diyalog
  ///
  /// In tr, this message translates to:
  /// **'Kodu kütüphaneye kaydet'**
  String get qrSaveTitle;

  /// Alan ipucu
  ///
  /// In tr, this message translates to:
  /// **'Örn. Banyo aynası'**
  String get qrSaveHint;

  /// Boş durum
  ///
  /// In tr, this message translates to:
  /// **'Henüz kayıtlı kod yok — okuttuğun kodu kaydederek başla'**
  String get qrLibraryEmpty;

  /// Diyalog
  ///
  /// In tr, this message translates to:
  /// **'Kodu yeniden adlandır'**
  String get qrRenameTitle;

  /// Diyalog
  ///
  /// In tr, this message translates to:
  /// **'Kod kullanımda'**
  String get qrInUseTitle;

  /// Diyalog gövdesi
  ///
  /// In tr, this message translates to:
  /// **'Bu kodu şu alarmlar görev olarak kullanıyor: {alarms}. Kütüphaneden silmek alarmı bozmaz ama kodu yeniden seçemezsin.'**
  String qrInUseBody(Object alarms);

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Yine de sil'**
  String get qrDeleteAnyway;

  /// Varsayılan ad
  ///
  /// In tr, this message translates to:
  /// **'QR kod'**
  String get qrDefaultName;

  /// Alan ipucu
  ///
  /// In tr, this message translates to:
  /// **'Kodu okut ya da yaz'**
  String get qrFieldHint;

  /// İpucu
  ///
  /// In tr, this message translates to:
  /// **'Kodu okut'**
  String get qrScanTooltip;

  /// Bilgi notu
  ///
  /// In tr, this message translates to:
  /// **'Kodu yatağından uzak bir yere yapıştır: banyo kapısı, mutfak. Alarm ancak bu kod okutulunca kapanır.'**
  String get qrFieldNote;

  /// Zaman
  ///
  /// In tr, this message translates to:
  /// **'az önce'**
  String get stopJustNow;

  /// Zaman
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dk önce'**
  String stopMinutesAgo(Object minutes);

  /// Kalan hak
  ///
  /// In tr, this message translates to:
  /// **'{count} hak kaldı'**
  String stopSnoozeLeft(Object count);

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Görevi yap'**
  String get stopDoMission;

  /// Bilgi
  ///
  /// In tr, this message translates to:
  /// **'Seçim yapmazsan alarm {countdown} sonra döner'**
  String stopReturnsIn(Object countdown);

  /// Bilgi
  ///
  /// In tr, this message translates to:
  /// **'Dokunmazsan {countdown} sonra kapanır'**
  String stopClosesIn(Object countdown);

  /// Bilgi
  ///
  /// In tr, this message translates to:
  /// **'Süre doldu, alarm geri dönüyor'**
  String get missionTimeUp;

  /// Bilgi
  ///
  /// In tr, this message translates to:
  /// **'süre bitince alarm geri döner'**
  String get missionCountdownNote;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Alarmı tamamen kapat'**
  String get missionCloseCompletely;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Yanlış, tekrar dene.'**
  String get missionWrongAnswer;

  /// Durum
  ///
  /// In tr, this message translates to:
  /// **'tamamlandı'**
  String get missionShakeDone;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Bu alarma kayıtlı bir QR kod yok.'**
  String get qrMissionNoCode;

  /// Bilgi
  ///
  /// In tr, this message translates to:
  /// **'Alarmı düzenleyip kod ekleyebilir ya da acil çıkışı kullanabilirsin.'**
  String get qrMissionNoCodeHint;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Farklı bir kod okundu'**
  String get qrMissionMismatch;

  /// Yönerge
  ///
  /// In tr, this message translates to:
  /// **'Kaydettiğin kodu okut'**
  String get qrMissionScanSaved;

  /// Yönerge
  ///
  /// In tr, this message translates to:
  /// **'Alarmı kurarken kaydettiğin kodu bul ve onu okut.'**
  String get qrMissionFindCode;

  /// Yönerge
  ///
  /// In tr, this message translates to:
  /// **'Kamerayı koda doğru tut.'**
  String get qrMissionAimCamera;

  /// Acil çıkış cümlesi
  ///
  /// In tr, this message translates to:
  /// **'alarmı kapatıyorum'**
  String get abortDismissing;

  /// Acil çıkış cümlesi
  ///
  /// In tr, this message translates to:
  /// **'görevi yapmadan alarmı kapatıyorum'**
  String get abortDismissingHard;

  /// Diyalog
  ///
  /// In tr, this message translates to:
  /// **'Alarmı görevi yapmadan kapatıyorsun.'**
  String get abortTitle;

  /// Bilgi
  ///
  /// In tr, this message translates to:
  /// **'Çıkış artık en zor kademede; daha da zorlaşmayacak.'**
  String get abortMaxLevel;

  /// Bilgi
  ///
  /// In tr, this message translates to:
  /// **'Bir dahaki sefere çıkış daha zor olacak.'**
  String get abortHarderNext;

  /// Yönerge
  ///
  /// In tr, this message translates to:
  /// **'Şunu birebir yaz: “{phrase}”'**
  String abortTypePhrase(Object phrase);

  /// Alan ipucu
  ///
  /// In tr, this message translates to:
  /// **'Cümleyi yaz'**
  String get abortPhraseHint;

  /// Yönerge
  ///
  /// In tr, this message translates to:
  /// **'Kapatmak için 3 saniye basılı tut'**
  String get abortHoldToClose;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Güncelle'**
  String get remindersUpdate;

  /// Sheet başlığı
  ///
  /// In tr, this message translates to:
  /// **'Bildirimi Güncelle'**
  String get remindersUpdateTitle;

  /// Sheet başlığı
  ///
  /// In tr, this message translates to:
  /// **'Yeni Bildirim Ekle'**
  String get remindersAddTitle;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Bildirim Ekle'**
  String get remindersAddButton;

  /// Yönerge
  ///
  /// In tr, this message translates to:
  /// **'Hangi vakitte bildirim almak istiyorsunuz?'**
  String get remindersWhichPrayer;

  /// Bölüm
  ///
  /// In tr, this message translates to:
  /// **'Namaz Vakti'**
  String get remindersPrayerSection;

  /// Bölüm
  ///
  /// In tr, this message translates to:
  /// **'Türetilmiş Vakitler'**
  String get remindersDerivedSection;

  /// Bilgi
  ///
  /// In tr, this message translates to:
  /// **'Kerahat ve nafile pencereleri, seçtiğin vakitten hesaplanır.'**
  String get remindersDerivedHint;

  /// Bölüm
  ///
  /// In tr, this message translates to:
  /// **'Bildirim Zamanı'**
  String get remindersTimeSection;

  /// Bölüm
  ///
  /// In tr, this message translates to:
  /// **'Günler'**
  String get remindersDaysSection;

  /// Bölüm
  ///
  /// In tr, this message translates to:
  /// **'Etiket (isteğe bağlı)'**
  String get remindersLabelSection;

  /// Seçenek
  ///
  /// In tr, this message translates to:
  /// **'Tam vaktinde'**
  String get remindersOnTimeOption;

  /// Seçenek
  ///
  /// In tr, this message translates to:
  /// **'Öncesinde'**
  String get remindersBeforeOption;

  /// Yönerge
  ///
  /// In tr, this message translates to:
  /// **'Dakika seçin'**
  String get remindersPickMinutes;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'En az 1 dk önce olabilir'**
  String get remindersMinOffsetError;

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Bu vakitten en fazla {max} dk önce bildirim ekleyebilirsin.'**
  String remindersMaxOffsetError(Object max);

  /// İpucu
  ///
  /// In tr, this message translates to:
  /// **'Silmek için satırı sola kaydırın.'**
  String get remindersSwipeToDelete;

  /// Bilgi
  ///
  /// In tr, this message translates to:
  /// **'Her vakit için tam vaktinde veya X dakika önce hatırlatma alabilirsiniz.'**
  String get remindersIntro;

  /// İpucu
  ///
  /// In tr, this message translates to:
  /// **'Silmek için satırı sola kaydırın; yanlışlıkla silersen alttaki \"Geri al\" ile dönersin. Alarmlar vakit güncellendiğinde otomatik yeniden planlanır.'**
  String get alarmsSwipeHint;

  /// Bilgi
  ///
  /// In tr, this message translates to:
  /// **'Alarmlar vakit verisi güncellendikçe yeniden planlanır.'**
  String get alarmsRescheduleNote;

  /// Uyarı
  ///
  /// In tr, this message translates to:
  /// **'Sesli alarm bu cihazda desteklenmiyor (iOS 26 ve üzeri gerekir). Alarmlar kaydedilir ancak çalmaz.'**
  String get alarmsUnsupported;

  /// Uyarı
  ///
  /// In tr, this message translates to:
  /// **'Alarmların çalması için izin gerekiyor.'**
  String get alarmsNeedPermission;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'İzin ver'**
  String get permissionGrant;

  /// Uyarı
  ///
  /// In tr, this message translates to:
  /// **'Bildirim almak için izin vermeniz gerekiyor.'**
  String get notificationsNeedPermission;

  /// Uyarı
  ///
  /// In tr, this message translates to:
  /// **'Tam zamanlı alarm kapalı. Bildirimler gecikebilir.'**
  String get exactAlarmOff;

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Aç'**
  String get actionOpen;

  /// Bildirim mesajı
  ///
  /// In tr, this message translates to:
  /// **'{label} alarmı silindi'**
  String alarmDeleted(Object label);

  /// Uyarı
  ///
  /// In tr, this message translates to:
  /// **'Bu alarm ertelendi ve görevi bekliyor; görevi yapmadan kapatılamaz.'**
  String get alarmBlockedSnoozed;

  /// Bildirim mesajı
  ///
  /// In tr, this message translates to:
  /// **'Alarm kapatıldı'**
  String get alarmTurnedOff;

  /// Erteleme bilgisi
  ///
  /// In tr, this message translates to:
  /// **'{time}\'te çalacak'**
  String snoozeUntil(Object time);

  /// Tema
  ///
  /// In tr, this message translates to:
  /// **'Koyu'**
  String get themeDark;

  /// Tema
  ///
  /// In tr, this message translates to:
  /// **'Açık'**
  String get themeLight;

  /// Tema
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get themeSystem;

  /// Bölüm
  ///
  /// In tr, this message translates to:
  /// **'Tema'**
  String get themeLabel;

  /// Ayar
  ///
  /// In tr, this message translates to:
  /// **'Vakte göre renk'**
  String get appearanceTimeColor;

  /// Ayar açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Zemin gün içinde ilerler'**
  String get appearanceTimeColorOn;

  /// Ayar açıklaması
  ///
  /// In tr, this message translates to:
  /// **'Sabit bir palet seçin'**
  String get appearanceTimeColorOff;

  /// Alt bilgi
  ///
  /// In tr, this message translates to:
  /// **'Sürüm yükleniyor...'**
  String get settingsVersionLoading;

  /// Alt bilgi
  ///
  /// In tr, this message translates to:
  /// **'Sürüm {version}'**
  String settingsVersion(Object version);

  /// Alt bilgi
  ///
  /// In tr, this message translates to:
  /// **'Vakitler cihazınızda saklanır, dışarı gönderilmez.'**
  String get settingsFooter;

  /// Gizlilik metni
  ///
  /// In tr, this message translates to:
  /// **'Konumunuz yalnızca namaz vakitlerini hesaplamak için kullanılır ve cihazınızda saklanır. Vakit verisi Aladhan API üzerinden koordinatla sorgulanır; kişisel bilgi gönderilmez.'**
  String get privacyBody;

  /// Saat dilimi
  ///
  /// In tr, this message translates to:
  /// **'Yaz saati uygulanıyor ({offset})'**
  String dstSummer(Object offset);

  /// Saat dilimi
  ///
  /// In tr, this message translates to:
  /// **'Kış saati uygulanıyor ({offset})'**
  String dstWinter(Object offset);

  /// Gün kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Pzt'**
  String get weekdayShortMon;

  /// Gün kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Sal'**
  String get weekdayShortTue;

  /// Gün kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Çar'**
  String get weekdayShortWed;

  /// Gün kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Per'**
  String get weekdayShortThu;

  /// Gün kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Cum'**
  String get weekdayShortFri;

  /// Gün kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Cmt'**
  String get weekdayShortSat;

  /// Gün kısaltması
  ///
  /// In tr, this message translates to:
  /// **'Paz'**
  String get weekdayShortSun;

  /// Gün harfi
  ///
  /// In tr, this message translates to:
  /// **'Pt'**
  String get weekdayLetterMon;

  /// Gün harfi
  ///
  /// In tr, this message translates to:
  /// **'Sa'**
  String get weekdayLetterTue;

  /// Gün harfi
  ///
  /// In tr, this message translates to:
  /// **'Ça'**
  String get weekdayLetterWed;

  /// Gün harfi
  ///
  /// In tr, this message translates to:
  /// **'Pe'**
  String get weekdayLetterThu;

  /// Gün harfi
  ///
  /// In tr, this message translates to:
  /// **'Cu'**
  String get weekdayLetterFri;

  /// Gün harfi
  ///
  /// In tr, this message translates to:
  /// **'Ct'**
  String get weekdayLetterSat;

  /// Gün harfi
  ///
  /// In tr, this message translates to:
  /// **'Pa'**
  String get weekdayLetterSun;

  /// Sapma etiketi
  ///
  /// In tr, this message translates to:
  /// **'{sign}{minutes} dk'**
  String offsetMinutes(Object sign, Object minutes);

  /// Erteleme bilgisi
  ///
  /// In tr, this message translates to:
  /// **'Ertelendi · {time}\'te çalacak'**
  String snoozedLabel(Object time);

  /// Hata
  ///
  /// In tr, this message translates to:
  /// **'Hata: {error}'**
  String errorGenericWith(Object error);

  /// Bildirim mesajı
  ///
  /// In tr, this message translates to:
  /// **'{location} silindi'**
  String locationDeleted(Object location);

  /// Android bildirim kanalinin sistem ayarlarindaki adi.
  ///
  /// In tr, this message translates to:
  /// **'Ezan Vakti Bildirimleri'**
  String get androidChannelName;

  /// Android bildirim kanalinin sistem ayarlarindaki aciklamasi.
  ///
  /// In tr, this message translates to:
  /// **'Namaz vakitlerini bildiren bildirimler'**
  String get androidChannelDescription;

  /// Gorev ekranindaki erteleme dugmesi; sure ve kalan hak.
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dk ertele · {count} hak'**
  String missionSnoozeAction(int minutes, int count);

  /// Uygulama adi; Android gorev listesi ve ayarlar basligi.
  ///
  /// In tr, this message translates to:
  /// **'Ezan Vakti & Alarm'**
  String get appName;

  /// Alarmin bagli oldugu namaz vaktini secen satirin etiketi.
  ///
  /// In tr, this message translates to:
  /// **'Vakit'**
  String get alarmAnchorLabel;

  /// Kaydirma araligi ipucu.
  ///
  /// In tr, this message translates to:
  /// **'1 - {max} dk'**
  String offsetRangeHint(int max);

  /// Ara ekrandaki erteleme dugmesi.
  ///
  /// In tr, this message translates to:
  /// **'Ertele · {minutes} dk'**
  String stopSnoozeAction(int minutes);

  /// Bir adim geri donen dugme.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get actionBack;

  /// GPS secenegi alt metni.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik konum tespiti'**
  String get locationAutoDetect;

  /// GPS ile konum bulma dugmesi.
  ///
  /// In tr, this message translates to:
  /// **'GPS ile Bul'**
  String get locationFindWithGps;

  /// Kayitli konum sayisi basligi.
  ///
  /// In tr, this message translates to:
  /// **'{count} konum'**
  String locationsCount(int count);

  /// Bir dakikadan az kalan geri sayim.
  ///
  /// In tr, this message translates to:
  /// **'<1dk'**
  String get countdownLessThanMinute;

  /// Kisa geri sayim; yalnizca dakika.
  ///
  /// In tr, this message translates to:
  /// **'{minutes}dk'**
  String countdownMinutesShort(int minutes);

  /// Kisa geri sayim; saat ve dakika.
  ///
  /// In tr, this message translates to:
  /// **'{hours}s {minutes}dk'**
  String countdownHourMinuteShort(int hours, int minutes);

  /// Sallama gorevinde kalan sallama sayisinin alt metni.
  ///
  /// In tr, this message translates to:
  /// **'kez daha salla'**
  String get missionShakeRemaining;

  /// Adres cozulemedigindeki GPS konum etiketi.
  ///
  /// In tr, this message translates to:
  /// **'GPS Konumu'**
  String get gpsFallbackLabel;

  /// Sabit saatli alarm bolumunun basligi.
  ///
  /// In tr, this message translates to:
  /// **'Saat'**
  String get alarmFixedSection;

  /// Cipali alarmin zamanlama bolumu basligi.
  ///
  /// In tr, this message translates to:
  /// **'Zamanlama'**
  String get alarmTimingSection;

  /// Kaydirma yok; tam vakitte calan secenek.
  ///
  /// In tr, this message translates to:
  /// **'Tam vaktinde'**
  String get alarmExactTime;

  /// Erteleme suresi secenegi.
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dakika'**
  String alarmSnoozeMinutesOption(int minutes);

  /// Etiketi olmayan alarmin gorunen adi.
  ///
  /// In tr, this message translates to:
  /// **'Alarm'**
  String get alarmDefaultLabel;

  /// Dosya seciciye verilen ses dosyasi turu adi.
  ///
  /// In tr, this message translates to:
  /// **'Ses'**
  String get soundFileTypeLabel;

  /// Ara ekranin ust basligi.
  ///
  /// In tr, this message translates to:
  /// **'ALARM DURDURULDU'**
  String get stopHeadline;

  /// Ara ekranda gorev ozeti.
  ///
  /// In tr, this message translates to:
  /// **'{mission} · {level} · {seconds} sn'**
  String stopMissionSummary(String mission, String level, int seconds);

  /// Matematik goreviniin cevap alani ipucu.
  ///
  /// In tr, this message translates to:
  /// **'Cevap'**
  String get missionAnswerHint;

  /// Son soruda gorunen dugme.
  ///
  /// In tr, this message translates to:
  /// **'Bitir'**
  String get missionFinish;

  /// Ara sorularda gorunen dugme.
  ///
  /// In tr, this message translates to:
  /// **'Onayla'**
  String get missionConfirm;

  /// Acil cikis penceresindeki geri sayim.
  ///
  /// In tr, this message translates to:
  /// **'Bekle: {seconds} sn'**
  String missionAbortWait(int seconds);

  /// Tam ekran QR tarayicinin basligi.
  ///
  /// In tr, this message translates to:
  /// **'Kodu okut'**
  String get qrScannerTitle;

  /// QR kod alaninin bolum etiketi.
  ///
  /// In tr, this message translates to:
  /// **'QR KOD'**
  String get qrSectionLabel;

  /// GPS ile eklenen konumun tur etiketi.
  ///
  /// In tr, this message translates to:
  /// **'GPS Konumu'**
  String get locationTypeGps;

  /// Elle eklenen konumun tur etiketi.
  ///
  /// In tr, this message translates to:
  /// **'Manuel'**
  String get locationTypeManual;

  /// Adres arama secenegi basligi.
  ///
  /// In tr, this message translates to:
  /// **'Adres Ara'**
  String get locationSearchAddress;

  /// Konum kaydedilemedigindeki uyari.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilemedi: {error}'**
  String locationSaveFailed(String error);

  /// Konumun genel hesaplama ayarini gosteren satir.
  ///
  /// In tr, this message translates to:
  /// **'Genel ayar: {method} · {school}'**
  String locationGlobalCalculation(String method, String school);

  /// Surum numarasi okunamadiginda gosterilir.
  ///
  /// In tr, this message translates to:
  /// **'Bilinmiyor'**
  String get versionUnknown;

  /// GPS izni yokken gosterilen hata.
  ///
  /// In tr, this message translates to:
  /// **'Konum izni gerekli'**
  String get errorLocationPermission;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
