// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get prayerFajr => 'الفجر';

  @override
  String get prayerSunrise => 'الشروق';

  @override
  String get prayerDhuhr => 'الظهر';

  @override
  String get prayerAsr => 'العصر';

  @override
  String get prayerMaghrib => 'المغرب';

  @override
  String get prayerIsha => 'العشاء';

  @override
  String get navPrayerTimes => 'الأوقات';

  @override
  String get navCalendar => 'التقويم';

  @override
  String get navReminders => 'التنبيهات';

  @override
  String get navTools => 'الأدوات';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionOk => 'حسنًا';

  @override
  String get actionUndo => 'تراجع';

  @override
  String get actionShare => 'مشاركة';

  @override
  String get actionCopy => 'نسخ';

  @override
  String get actionReset => 'إعادة تعيين';

  @override
  String get actionRetry => 'أعد المحاولة';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsGeneral => 'عام';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsInfo => 'معلومات';

  @override
  String get settingsNotificationsAndSound => 'التنبيهات والصوت';

  @override
  String get settingsLocation => 'الموقع';

  @override
  String get settingsCalculation => 'طريقة الحساب';

  @override
  String get settingsDataSource => 'مصدر البيانات';

  @override
  String get settingsPrivacy => 'الخصوصية';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsTimeFormat => 'صيغة الوقت';

  @override
  String get settingsQuietWindows => 'فترات الصمت';

  @override
  String get languageSystem => 'النظام';

  @override
  String get languageTurkish => 'التركية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageArabic => 'العربية';

  @override
  String get timeFormatSystem => 'النظام';

  @override
  String get timeFormat24 => '٢٤ ساعة';

  @override
  String get timeFormat12 => '١٢ ساعة';

  @override
  String get settingsAutoLocation => 'تتبع الموقع تلقائيًا';

  @override
  String get settingsAutoLocationHint =>
      'تُحدَّث الأوقات تلقائيًا عند تغيّر مدينتك.';

  @override
  String get toolsTitle => 'الأدوات';

  @override
  String get toolsDirection => 'الاتجاه';

  @override
  String get toolsTracking => 'المتابعة';

  @override
  String get toolsQibla => 'القبلة';

  @override
  String get toolsQiblaHint => 'اعثر على اتجاه الكعبة بالبوصلة';

  @override
  String get toolsPrayerTracking => 'متابعة الصلاة';

  @override
  String get toolsPrayerTrackingHint => 'سجّل ما صلّيت واحسب ما فاتك';

  @override
  String get toolsDhikr => 'المسبحة';

  @override
  String get toolsDhikrHint => 'عدّاد مع هدف';

  @override
  String get toolsPrivacyNote =>
      'تعمل الأدوات على جهازك؛ ولا تُرسَل أي بيانات للخارج.';

  @override
  String get qiblaTitle => 'القبلة';

  @override
  String get qiblaFromNorth => 'باتجاه عقارب الساعة من الشمال';

  @override
  String get qiblaNeedsLocation => 'الموقع مطلوب';

  @override
  String get qiblaNeedsLocationHint =>
      'اختر موقعًا أو استخدم GPS لتحديد القبلة.';

  @override
  String get qiblaWaiting => 'في انتظار البوصلة…';

  @override
  String get qiblaCalibrate =>
      'تحتاج البوصلة إلى معايرة. حرّك هاتفك على شكل رقم ثمانية لبضع ثوانٍ.';

  @override
  String get qiblaAligned => 'أنت متجه إلى القبلة';

  @override
  String qiblaTurnRight(Object degrees) {
    return 'استدر $degrees° يمينًا';
  }

  @override
  String qiblaTurnLeft(Object degrees) {
    return 'استدر $degrees° يسارًا';
  }

  @override
  String get trackingTitle => 'متابعة الصلاة';

  @override
  String get trackingLastDays => 'آخر ٧ أيام';

  @override
  String get trackingQadaCounter => 'عدّاد القضاء';

  @override
  String get trackingDone => 'صلّيت';

  @override
  String get trackingQada => 'قضاء';

  @override
  String get trackingEmpty => 'فارغ';

  @override
  String get dhikrTitle => 'المسبحة';

  @override
  String get dhikrTarget => 'الهدف';

  @override
  String get dhikrTapToCount => 'انقر في أي مكان للعد';

  @override
  String dhikrProgress(Object remaining, Object laps) {
    return 'بقي $remaining · الجولة $laps';
  }

  @override
  String dhikrTodayTotal(Object count) {
    return 'اليوم: $count';
  }

  @override
  String get dhikrResetTitle => 'إعادة تعيين العدّاد';

  @override
  String get dhikrResetBody => 'سيُمسح عدد اليوم.';

  @override
  String notificationPrayerNow(Object prayer) {
    return 'دخل وقت $prayer';
  }

  @override
  String notificationPrayerSoon(Object prayer) {
    return 'يقترب وقت $prayer';
  }

  @override
  String notificationMinutesLeft(Object prayer, Object minutes) {
    return 'بقي $minutes دقيقة على $prayer';
  }

  @override
  String notificationDerivedSoon(Object name) {
    return 'يقترب $name';
  }

  @override
  String notificationDerivedMinutesLeft(Object name, Object minutes) {
    return 'بقي $minutes دقيقة على $name';
  }

  @override
  String religiousDayTodayEstimated(Object name) {
    return '$name اليوم. التاريخ محسوب وقد يختلف بيوم عن التقويم الرسمي.';
  }

  @override
  String religiousDayToday(Object name) {
    return '$name اليوم.';
  }

  @override
  String religiousDayTomorrowTitle(Object name) {
    return '$name غدًا';
  }

  @override
  String religiousDayTomorrowBody(Object name) {
    return 'سيُحتفل بـ$name غدًا.';
  }

  @override
  String get derivedIshraq => 'الإشراق';

  @override
  String get derivedIstiwa => 'الزوال (وقت الكراهة)';

  @override
  String get derivedPreMaghrib => 'قبل المغرب (وقت الكراهة)';

  @override
  String get derivedMidnight => 'منتصف الليل الشرعي';

  @override
  String get derivedLastThird => 'الثلث الأخير من الليل';

  @override
  String get derivedIshraqHint => 'ينتهي وقت الكراهة بعد الشروق';

  @override
  String get derivedIstiwaHint => 'يبدأ وقت الكراهة قبل الظهر';

  @override
  String get derivedPreMaghribHint => 'يبدأ وقت الكراهة قبل المغرب';

  @override
  String get derivedMidnightHint => 'منتصف الليل الشرعي';

  @override
  String get derivedLastThirdHint => 'يبدأ وقت التهجد';
}
