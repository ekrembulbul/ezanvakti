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

  @override
  String get locationsTitle => 'المواقع';

  @override
  String get locationsLoading => 'جارٍ تحميل المواقع…';

  @override
  String locationsLoadFailed(Object error) {
    return 'تعذّر تحميل المواقع: $error';
  }

  @override
  String get locationsEmpty => 'لم تتم إضافة مواقع بعد';

  @override
  String get locationsEmptyHint => 'حدّد تلقائيًا عبر GPS أو\nابحث عن عنوان';

  @override
  String get locationsSwipeHint => 'اسحب الصف لحذف موقع غير نشط.';

  @override
  String get locationActive => 'نشط';

  @override
  String get locationAddTitle => 'إضافة موقع';

  @override
  String get locationEditTitle => 'تعديل الموقع';

  @override
  String get locationSearchHint => 'ابحث بالمدينة أو المنطقة أو المكان';

  @override
  String get locationSearchPlaceholder => 'ابحث عن مدينة أو منطقة أو مكان…';

  @override
  String get locationSearchStart => 'ابدأ الكتابة للبحث.';

  @override
  String get locationSearchNoResult =>
      'لا توجد نتائج.\nجرّب بحثًا آخر أو تحقق من اتصالك.';

  @override
  String get locationGettingPosition => 'جارٍ تحديد الموقع…';

  @override
  String get locationPermissionTitle => 'إذن الموقع';

  @override
  String get locationPermissionBody =>
      'نحتاج إذن الموقع لعرض أوقات الصلاة حسب مكانك. بالسماح سيتم اختيار مدينتك تلقائيًا.';

  @override
  String get locationPermissionAllow => 'اسمح';

  @override
  String get locationServicesOff => 'خدمات الموقع مغلقة. يرجى تشغيلها.';

  @override
  String get locationPermissionDenied =>
      'تم رفض إذن الموقع نهائيًا. امنحه من الإعدادات.';

  @override
  String get locationUpdated => 'تم تحديث الموقع';

  @override
  String get locationSelectFirst => 'يرجى اختيار موقع';

  @override
  String get locationCustomName => 'اسم مخصص (اختياري)';

  @override
  String get locationCustomNameHint => 'مثال: المنزل، العمل';

  @override
  String get locationUseGlobalCalculation => 'استخدم إعداد الحساب العام';

  @override
  String get locationUseGlobalCalculationHint =>
      'أوقفه لاختيار طريقة خاصة بهذا الموقع';

  @override
  String get locationCalculationFromGlobal =>
      'تُؤخذ طريقة الحساب من الإعداد العام. لتغييرها لهذا الموقع، عدّل بعد الحفظ.';

  @override
  String get locationChange => 'تغيير';

  @override
  String locationUndoFailed(Object error) {
    return 'تعذّر التراجع: $error';
  }

  @override
  String get osmAttribution => '© مساهمو OpenStreetMap';

  @override
  String get widgetTomorrow => 'غدًا';

  @override
  String get widgetStale => 'غير محدّث';

  @override
  String get widgetOpenApp => 'افتح التطبيق لمعرفة الأوقات';

  @override
  String get widgetUpdateApp => 'يرجى تحديث التطبيق';

  @override
  String siriAnswer(Object prayer, Object time, Object remaining) {
    return '$prayer في $time، بقي $remaining.';
  }

  @override
  String durationHourMinute(Object hours, Object minutes) {
    return '$hours ساعة و$minutes دقيقة';
  }

  @override
  String durationHour(Object hours) {
    return '$hours ساعة';
  }

  @override
  String durationMinute(Object minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get hijriMuharram => 'محرم';

  @override
  String get hijriSafar => 'صفر';

  @override
  String get hijriRabiAwwal => 'ربيع الأول';

  @override
  String get hijriRabiThani => 'ربيع الآخر';

  @override
  String get hijriJumadaAwwal => 'جمادى الأولى';

  @override
  String get hijriJumadaThani => 'جمادى الآخرة';

  @override
  String get hijriRajab => 'رجب';

  @override
  String get hijriShaban => 'شعبان';

  @override
  String get hijriRamadan => 'رمضان';

  @override
  String get hijriShawwal => 'شوال';

  @override
  String get hijriDhulQadah => 'ذو القعدة';

  @override
  String get hijriDhulHijjah => 'ذو الحجة';

  @override
  String get religiousNewYear => 'رأس السنة الهجرية';

  @override
  String get religiousAshura => 'عاشوراء';

  @override
  String get religiousMawlid => 'المولد النبوي';

  @override
  String get religiousRegaib => 'ليلة الرغائب';

  @override
  String get religiousMiraj => 'ليلة الإسراء والمعراج';

  @override
  String get religiousBaraat => 'ليلة البراءة';

  @override
  String get religiousRamadanStart => 'بداية رمضان';

  @override
  String get religiousQadr => 'ليلة القدر';

  @override
  String get religiousEidFitr => 'عيد الفطر';

  @override
  String get religiousArafah => 'يوم عرفة';

  @override
  String get religiousEidAdha => 'عيد الأضحى';

  @override
  String get asrShafi => 'الشافعي (قياسي)';

  @override
  String get asrHanafi => 'الحنفي';

  @override
  String get latAuto => 'تلقائي';

  @override
  String get latMidnight => 'منتصف الليل';

  @override
  String get latOneSeventh => 'سُبع الليل';

  @override
  String get latAngle => 'حسب الزاوية';

  @override
  String get calcMethodLabel => 'طريقة الحساب';

  @override
  String get calcAsrLabel => 'العصر (المذهب)';

  @override
  String get calcAdvanced => 'متقدم';

  @override
  String get calcLatitudeLabel => 'تعديل خطوط العرض العالية';

  @override
  String get calcGlobalNote =>
      'الإعداد الافتراضي لكل المواقع. يُستخدم ما لم يكن للموقع إعداد خاص.';

  @override
  String get calcTuneSection => 'تعديلات الأوقات';

  @override
  String get calcTuneHint =>
      'حرّك الأوقات بضع دقائق لتطابق تقويمك. تستخدم التنبيهات والمنبهات والأداة الأوقات المعدّلة.';

  @override
  String minutesShort(Object minutes) {
    return '$minutes د';
  }

  @override
  String get offlineFresh => 'البيانات محدّثة';

  @override
  String get offlineShouldUpdate => 'ينبغي تحديث البيانات';

  @override
  String get offlineTooOld => 'البيانات قديمة جدًا، يلزم التحديث';

  @override
  String get offlineNoData => 'لا توجد بيانات';

  @override
  String get offlineNoConnection =>
      'لا يوجد اتصال بالإنترنت. يتم عرض البيانات المحفوظة.';

  @override
  String get offlineFetchFailed => 'تعذّر جلب البيانات. يرجى التحقق من اتصالك.';

  @override
  String get offlineUpdateFailed => 'فشل التحديث. يتم عرض البيانات المحفوظة.';

  @override
  String errorDataLoad(Object error) {
    return 'خطأ أثناء تحميل البيانات: $error';
  }

  @override
  String errorLocationChange(Object error) {
    return 'تعذّر تغيير الموقع: $error';
  }

  @override
  String errorGpsRefresh(Object error) {
    return 'فشل تحديث GPS: $error';
  }

  @override
  String gpsUpdated(Object location) {
    return 'تم تحديث موقع GPS: $location';
  }

  @override
  String get errorParseFormat =>
      'قد تكون صيغة البيانات تغيّرت. يرجى تحديث التطبيق.';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get today => 'اليوم';

  @override
  String get nextLabel => 'التالي';

  @override
  String adhanAt(Object prayer, Object time) {
    return 'أذان $prayer في $time';
  }

  @override
  String get upcomingTitle => 'التالي';

  @override
  String get upcomingAll => 'الكل';

  @override
  String get upcomingEmpty => 'لا توجد تنبيهات أو منبهات قادمة';

  @override
  String get alarmQrRequired => 'امسح أو اكتب رمزًا لمهمة QR';

  @override
  String get alarmPickSavedCode => 'اختر من الرموز المحفوظة';

  @override
  String get alarmAnchorQuestion => 'مرتبط بأي صلاة؟';

  @override
  String get alarmBefore => 'قبل';

  @override
  String get alarmAfter => 'بعد';

  @override
  String get alarmBeforePrayer => 'قبل الصلاة';

  @override
  String get alarmAfterPrayer => 'بعد الصلاة';

  @override
  String get alarmSoundImportFailed => 'تعذّر استيراد ملف الصوت';

  @override
  String get alarmSnoozeMinutes => 'مدة التأجيل';

  @override
  String get qrSaveTitle => 'حفظ الرمز في المكتبة';

  @override
  String get qrSaveHint => 'مثال: مرآة الحمام';

  @override
  String get qrLibraryEmpty => 'لا توجد رموز محفوظة — احفظ رمزًا بعد مسحه';

  @override
  String get qrRenameTitle => 'إعادة تسمية الرمز';

  @override
  String get qrInUseTitle => 'الرمز قيد الاستخدام';

  @override
  String qrInUseBody(Object alarms) {
    return 'تستخدم هذه المنبهات الرمز كمهمة: $alarms. حذفه من المكتبة لا يعطّل المنبه لكن لن تتمكن من اختياره مجددًا.';
  }

  @override
  String get qrDeleteAnyway => 'احذف على أي حال';

  @override
  String get qrDefaultName => 'رمز QR';

  @override
  String get qrFieldHint => 'امسح أو اكتب الرمز';

  @override
  String get qrScanTooltip => 'امسح الرمز';

  @override
  String get qrFieldNote =>
      'الصق الرمز بعيدًا عن سريرك: باب الحمام، المطبخ. لا يتوقف المنبه إلا بمسح هذا الرمز.';

  @override
  String get stopJustNow => 'قبل قليل';

  @override
  String stopMinutesAgo(Object minutes) {
    return 'قبل $minutes د';
  }

  @override
  String stopSnoozeLeft(Object count) {
    return 'بقي $count';
  }

  @override
  String get stopDoMission => 'نفّذ المهمة';

  @override
  String stopReturnsIn(Object countdown) {
    return 'سيعود المنبه بعد $countdown إن لم تختر';
  }

  @override
  String stopClosesIn(Object countdown) {
    return 'سيُغلق بعد $countdown إن لم تلمس';
  }

  @override
  String get missionTimeUp => 'انتهى الوقت، سيعود المنبه';

  @override
  String get missionCountdownNote => 'يعود المنبه عند انتهاء الوقت';

  @override
  String get missionCloseCompletely => 'أوقف المنبه تمامًا';

  @override
  String get missionWrongAnswer => 'خطأ، حاول مرة أخرى.';

  @override
  String get missionShakeDone => 'اكتمل';

  @override
  String get qrMissionNoCode => 'لا يوجد رمز QR محفوظ لهذا المنبه.';

  @override
  String get qrMissionNoCodeHint =>
      'عدّل المنبه لإضافة رمز، أو استخدم مخرج الطوارئ.';

  @override
  String get qrMissionMismatch => 'تم مسح رمز مختلف';

  @override
  String get qrMissionScanSaved => 'امسح الرمز الذي حفظته';

  @override
  String get qrMissionFindCode =>
      'اعثر على الرمز الذي حفظته عند ضبط المنبه وامسحه.';

  @override
  String get qrMissionAimCamera => 'وجّه الكاميرا نحو الرمز.';

  @override
  String get abortDismissing => 'أنا أوقف المنبه';

  @override
  String get abortDismissingHard => 'أوقف المنبه دون تنفيذ المهمة';

  @override
  String get abortTitle => 'أنت توقف المنبه دون تنفيذ المهمة.';

  @override
  String get abortMaxLevel => 'المخرج في أصعب مستوى؛ لن يزداد صعوبة.';

  @override
  String get abortHarderNext => 'في المرة القادمة سيكون المخرج أصعب.';

  @override
  String abortTypePhrase(Object phrase) {
    return 'اكتب هذا حرفيًا: ”$phrase“';
  }

  @override
  String get abortPhraseHint => 'اكتب الجملة';

  @override
  String get abortHoldToClose => 'اضغط مطولًا ٣ ثوانٍ للإيقاف';

  @override
  String get remindersUpdate => 'تحديث';

  @override
  String get remindersUpdateTitle => 'تحديث التنبيه';

  @override
  String get remindersAddTitle => 'إضافة تنبيه';

  @override
  String get remindersAddButton => 'أضف تنبيهًا';

  @override
  String get remindersWhichPrayer => 'لأي صلاة تريد تنبيهًا؟';

  @override
  String get remindersPrayerSection => 'الصلاة';

  @override
  String get remindersDerivedSection => 'الأوقات المشتقة';

  @override
  String get remindersDerivedHint =>
      'تُحسب أوقات الكراهة والنوافل من الصلاة المختارة.';

  @override
  String get remindersTimeSection => 'وقت التنبيه';

  @override
  String get remindersDaysSection => 'الأيام';

  @override
  String get remindersLabelSection => 'التسمية (اختياري)';

  @override
  String get remindersOnTimeOption => 'في الوقت';

  @override
  String get remindersBeforeOption => 'قبله';

  @override
  String get remindersPickMinutes => 'اختر الدقائق';

  @override
  String get remindersMinOffsetError => 'يجب أن يكون قبل دقيقة على الأقل';

  @override
  String remindersMaxOffsetError(Object max) {
    return 'يمكنك إضافة تنبيه قبل هذه الصلاة بحد أقصى $max دقيقة.';
  }

  @override
  String get remindersSwipeToDelete => 'اسحب الصف لحذفه.';

  @override
  String get remindersIntro =>
      'لكل صلاة يمكنك التذكير في وقتها أو قبلها بدقائق.';

  @override
  String get alarmsSwipeHint =>
      'اسحب الصف للحذف؛ إن كان بالخطأ استخدم \"تراجع\" بالأسفل. تُعاد جدولة المنبهات تلقائيًا عند تحديث الأوقات.';

  @override
  String get alarmsRescheduleNote =>
      'تُعاد جدولة المنبهات مع تحديث بيانات الأوقات.';

  @override
  String get alarmsUnsupported =>
      'المنبهات الصوتية غير مدعومة على هذا الجهاز (يتطلب iOS 26 أو أحدث). تُحفظ المنبهات لكنها لن ترن.';

  @override
  String get alarmsNeedPermission => 'يلزم الإذن حتى ترن المنبهات.';

  @override
  String get permissionGrant => 'امنح الإذن';

  @override
  String get notificationsNeedPermission => 'يلزم منح الإذن لتلقي التنبيهات.';

  @override
  String get exactAlarmOff => 'المنبهات الدقيقة معطلة. قد تتأخر التنبيهات.';

  @override
  String get actionOpen => 'افتح';

  @override
  String alarmDeleted(Object label) {
    return 'تم حذف المنبه $label';
  }

  @override
  String get alarmBlockedSnoozed =>
      'هذا المنبه مؤجل ولا تزال مهمته معلّقة؛ لا يمكن إيقافه بعد.';

  @override
  String get alarmTurnedOff => 'تم إيقاف المنبه';

  @override
  String snoozeUntil(Object time) {
    return 'سيرن في $time';
  }

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLabel => 'السمة';

  @override
  String get appearanceTimeColor => 'اللون حسب الوقت';

  @override
  String get appearanceTimeColorOn => 'تتغير الخلفية خلال اليوم';

  @override
  String get appearanceTimeColorOff => 'اختر لوحة ثابتة';

  @override
  String get settingsVersionLoading => 'جارٍ تحميل الإصدار…';

  @override
  String settingsVersion(Object version) {
    return 'الإصدار $version';
  }

  @override
  String get settingsFooter => 'تُحفظ الأوقات على جهازك ولا تُرسل لأي جهة.';

  @override
  String get privacyBody =>
      'يُستخدم موقعك فقط لحساب أوقات الصلاة ويبقى على جهازك. تُطلب الأوقات من Aladhan API بالإحداثيات؛ ولا تُرسل بيانات شخصية.';

  @override
  String dstSummer(Object offset) {
    return 'التوقيت الصيفي مفعّل ($offset)';
  }

  @override
  String dstWinter(Object offset) {
    return 'التوقيت الشتوي مفعّل ($offset)';
  }

  @override
  String get weekdayShortMon => 'إث';

  @override
  String get weekdayShortTue => 'ثل';

  @override
  String get weekdayShortWed => 'أر';

  @override
  String get weekdayShortThu => 'خم';

  @override
  String get weekdayShortFri => 'جم';

  @override
  String get weekdayShortSat => 'سب';

  @override
  String get weekdayShortSun => 'أح';

  @override
  String get weekdayLetterMon => 'إث';

  @override
  String get weekdayLetterTue => 'ثل';

  @override
  String get weekdayLetterWed => 'أر';

  @override
  String get weekdayLetterThu => 'خم';

  @override
  String get weekdayLetterFri => 'جم';

  @override
  String get weekdayLetterSat => 'سب';

  @override
  String get weekdayLetterSun => 'أح';

  @override
  String offsetMinutes(Object sign, Object minutes) {
    return '$sign$minutes د';
  }

  @override
  String snoozedLabel(Object time) {
    return 'مؤجل · سيرن في $time';
  }

  @override
  String errorGenericWith(Object error) {
    return 'خطأ: $error';
  }

  @override
  String locationDeleted(Object location) {
    return 'تم حذف $location';
  }
}
