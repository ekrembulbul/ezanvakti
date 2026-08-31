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

  @override
  String get remindersTitle => 'التنبيهات';

  @override
  String get remindersNotifications => 'التنبيهات';

  @override
  String get remindersAlarms => 'المنبهات';

  @override
  String get remindersNoNotifications => 'لا توجد تنبيهات بعد';

  @override
  String get remindersNoNotificationsHint =>
      'أضف تنبيهًا ليصلك تذكير\nفي أوقات الصلاة.';

  @override
  String get remindersNoAlarms => 'لا توجد منبهات بعد';

  @override
  String get remindersNoAlarmsHint => 'أضف منبهًا بوقت ثابت أو مرتبطًا بالصلاة';

  @override
  String remindersCount(Object count) {
    return '$count تنبيهات';
  }

  @override
  String remindersAlarmCount(Object count) {
    return '$count منبهات';
  }

  @override
  String get remindersAddFriday => 'أضف تنبيه صلاة الجمعة';

  @override
  String get reminderFridayLabel => 'صلاة الجمعة';

  @override
  String get reminderOnTime => 'في الوقت';

  @override
  String reminderMinutesBefore(Object minutes) {
    return 'قبل $minutes دقيقة';
  }

  @override
  String get reminderSkippedOnce => 'سيُتخطى هذه المرة فقط';

  @override
  String get reminderOff => 'مغلق';

  @override
  String get reminderScheduleFailed =>
      'تعذّر الجدولة — عدّل واحفظ لإعادة المحاولة';

  @override
  String get quietTitle => 'فترات الصمت';

  @override
  String get quietIntro =>
      'خلال هذه الفترات تظهر تنبيهات التطبيق بصمت أو لا تظهر. لا يستطيع أي تطبيق كتم الآيفون؛ هذا الإعداد يؤثر على تنبيهات التطبيق فقط ولا يمس المنبهات.';

  @override
  String get quietFridaySection => 'صلاة الجمعة';

  @override
  String get quietFridayTitle => 'صامت في وقت الجمعة';

  @override
  String get quietFridayHint =>
      'تصمت التنبيهات حول ظهر الجمعة. يمكنك تغيير المدد أو إيقافها.';

  @override
  String get quietCustomSection => 'فترات مخصصة';

  @override
  String get quietNoCustom => 'لا توجد فترات مخصصة بعد.';

  @override
  String get quietAddWindow => 'أضف فترة';

  @override
  String get quietMinutesBefore => 'كم دقيقة قبل';

  @override
  String get quietMinutesAfter => 'كم دقيقة بعد';

  @override
  String get quietModeLabel => 'خلال هذه الفترة';

  @override
  String get quietModeSilent => 'إظهار صامت';

  @override
  String get quietModeSilentHint => 'يظهر التنبيه دون صوت';

  @override
  String get quietModeSkip => 'عدم الإظهار';

  @override
  String get quietModeSkipHint => 'لا تتم جدولة التنبيه إطلاقًا';

  @override
  String quietWindowSummary(Object before, Object after) {
    return 'قبل $before دقيقة – بعد $after دقيقة';
  }

  @override
  String get quietPrayerLabel => 'الصلاة';

  @override
  String get prefsNewSound => 'صوت التنبيه الجديد';

  @override
  String get soundSystem => 'صوت النظام';

  @override
  String get soundSystemHint => 'صوت التنبيه الافتراضي لجهازك';

  @override
  String get soundBeep => 'تنبيه قصير';

  @override
  String get soundBeepHint => 'نغمة التطبيق القصيرة';

  @override
  String get soundSilent => 'صامت';

  @override
  String get soundSilentHint => 'يظهر التنبيه دون صوت';

  @override
  String get prefsShowInFocus => 'الإظهار في وضع التركيز';

  @override
  String get prefsShowInFocusHint =>
      'لا يؤجل وضع التركيز التنبيهات. هذا لا يتجاوز مفتاح الصامت.';

  @override
  String get prefsReligiousDays => 'الأيام الدينية';

  @override
  String get prefsReligiousDaysHint =>
      'يذكّرك عند المغرب في الليالي المباركة والأعياد. تُحسب التواريخ من التقويم الهجري وقد تختلف بيوم عن الرسمي.';

  @override
  String get prefsReligiousDayEve => 'ذكّرني قبل يوم أيضًا';

  @override
  String get prefsReligiousDayEveHint => 'يرسل تنبيه \"غدًا\" وقت الظهر.';

  @override
  String get alarmAdd => 'إضافة منبه';

  @override
  String get alarmEdit => 'تعديل المنبه';

  @override
  String get alarmFixedTime => 'وقت ثابت';

  @override
  String get alarmAnchored => 'حسب الصلاة';

  @override
  String get alarmRepeat => 'التكرار';

  @override
  String get alarmLabel => 'التسمية';

  @override
  String get alarmLabelHint => 'مثال: السحور';

  @override
  String get alarmSound => 'الصوت';

  @override
  String get alarmSoundDefault => 'افتراضي';

  @override
  String get alarmSoundCustom => 'صوت مخصص';

  @override
  String get alarmSoundPick => 'اختر صوتًا من الجهاز…';

  @override
  String get alarmSoundVolumeNote =>
      'يعمل المنبه بمستوى صوت الرنين والتنبيهات.';

  @override
  String get alarmVibrate => 'الاهتزاز';

  @override
  String get alarmSnooze => 'التأجيل';

  @override
  String get alarmSnoozeCount => 'عدد مرات التأجيل';

  @override
  String get alarmSnoozeUnlimited => 'غير محدود';

  @override
  String alarmSnoozeTimes(Object count) {
    return '$count مرات';
  }

  @override
  String get alarmMission => 'مهمة الإيقاف';

  @override
  String get alarmMissionQuestion => 'كيف ستوقف المنبه؟';

  @override
  String get missionNone => 'بدون مهمة';

  @override
  String get missionNoneHint => 'يُوقف بالسحب مباشرة';

  @override
  String get missionMath => 'الرياضيات';

  @override
  String get missionMathHint => 'لا يتوقف قبل حل المسائل';

  @override
  String get missionShake => 'الهز';

  @override
  String get missionShakeHint => 'يُوقف بهز الهاتف';

  @override
  String get missionQr => 'مسح رمز QR';

  @override
  String get missionQrHint => 'لا يتوقف قبل مسح الرمز المحفوظ';

  @override
  String get alarmEveryDay => 'كل يوم';

  @override
  String get alarmWeekdays => 'أيام الأسبوع';

  @override
  String get alarmWeekend => 'عطلة نهاية الأسبوع';

  @override
  String get alarmCopySuffix => '(نسخة)';

  @override
  String get alarmDuplicate => 'نسخ';

  @override
  String get errorGeneric => 'حدث خطأ ما';

  @override
  String get calendarTitle => 'تقويم الأوقات';

  @override
  String get calendarShare => 'مشاركة التقويم';

  @override
  String get calendarEmpty => 'لا توجد بيانات التقويم';

  @override
  String get calendarLoading => 'جارٍ تحميل التقويم…';

  @override
  String get calendarShareFailed => 'تعذّر إنشاء صورة التقويم';

  @override
  String calendarDayCount(Object count) {
    return '$count أيام';
  }

  @override
  String get upcomingNext => 'التالي';

  @override
  String upcomingNotification(Object prayer) {
    return 'تنبيه $prayer';
  }

  @override
  String get upcomingTomorrow => 'غدًا';

  @override
  String get upcomingToday => 'اليوم';

  @override
  String get snackNotificationAdded => 'تمت إضافة التنبيه';

  @override
  String get snackNotificationUpdated => 'تم تحديث التنبيه';

  @override
  String get snackNotificationDeleted => 'تم حذف التنبيه';

  @override
  String get snackNotificationExists => 'هذا التنبيه موجود بالفعل';

  @override
  String get snackAlarmDeleted => 'تم حذف المنبه';

  @override
  String get snackSkipOnce => 'هذه المرة فقط';

  @override
  String get snackUndo => 'تراجع';

  @override
  String get locationTitle => 'المواقع';

  @override
  String get locationAdd => 'إضافة موقع';

  @override
  String get locationSearch => 'ابحث عن مدينة';

  @override
  String get locationUseGps => 'استخدم موقعي';

  @override
  String get locationEmpty => 'لا توجد مواقع محفوظة';

  @override
  String shareCaption(Object location, Object period) {
    return '$location · أوقات الصلاة لـ$period';
  }

  @override
  String get ramadanIftarCountdown => 'حتى الإفطار';

  @override
  String get ramadanSuhoorCountdown => 'حتى نهاية السحور';

  @override
  String ramadanDay(Object day) {
    return 'رمضان اليوم $day';
  }

  @override
  String get ramadanCalendarTitle => 'إمساكية رمضان';

  @override
  String get ramadanFastingSection => 'متابعة الصيام';

  @override
  String get ramadanFasted => 'صمت';

  @override
  String get ramadanFastMissed => 'قضاء';

  @override
  String get ramadanFastExempt => 'معذور';

  @override
  String get ramadanFastingQada => 'صيام القضاء';

  @override
  String get ramadanSetupTitle => 'تنبيهات رمضان';

  @override
  String get ramadanSetupBody =>
      'هل تريد إضافة تنبيهي السحور (قبل الفجر بـ٤٥ دقيقة) والإفطار؟ ستظهر في قائمة التنبيهات ويمكنك حذفها متى شئت.';

  @override
  String get ramadanSetupAccept => 'أضف';

  @override
  String get ramadanSuhoorLabel => 'السحور';

  @override
  String get ramadanIftarLabel => 'الإفطار';

  @override
  String get ramadanRemindersAdded => 'تمت إضافة تنبيهي السحور والإفطار';
}
