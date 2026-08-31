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

  /// Düğme
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
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
  /// **'Dil'**
  String get settingsLanguage;

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

  /// Dil seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Sistem'**
  String get languageSystem;

  /// Dil seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Türkçe'**
  String get languageTurkish;

  /// Dil seçeneği
  ///
  /// In tr, this message translates to:
  /// **'İngilizce'**
  String get languageEnglish;

  /// Dil seçeneği
  ///
  /// In tr, this message translates to:
  /// **'Arapça'**
  String get languageArabic;

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

  /// Kopya etiketi
  ///
  /// In tr, this message translates to:
  /// **'(kopya)'**
  String get alarmCopySuffix;

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
