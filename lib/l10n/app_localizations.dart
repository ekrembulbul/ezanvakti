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
