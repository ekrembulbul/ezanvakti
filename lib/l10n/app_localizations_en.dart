// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get prayerFajr => 'Fajr';

  @override
  String get prayerSunrise => 'Sunrise';

  @override
  String get prayerDhuhr => 'Dhuhr';

  @override
  String get prayerAsr => 'Asr';

  @override
  String get prayerMaghrib => 'Maghrib';

  @override
  String get prayerIsha => 'Isha';

  @override
  String get navPrayerTimes => 'Times';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navReminders => 'Reminders';

  @override
  String get navTools => 'Tools';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionOk => 'OK';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionShare => 'Share';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionReset => 'Reset';

  @override
  String get actionRetry => 'Try again';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsInfo => 'Info';

  @override
  String get settingsNotificationsAndSound => 'Notifications & sound';

  @override
  String get settingsLocation => 'Location';

  @override
  String get settingsCalculation => 'Calculation';

  @override
  String get settingsDataSource => 'Data source';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTimeFormat => 'Time format';

  @override
  String get settingsQuietWindows => 'Quiet windows';

  @override
  String get languageSystem => 'System';

  @override
  String get languageTurkish => 'Turkish';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get timeFormatSystem => 'System';

  @override
  String get timeFormat24 => '24-hour';

  @override
  String get timeFormat12 => '12-hour';

  @override
  String get settingsAutoLocation => 'Track location automatically';

  @override
  String get settingsAutoLocationHint =>
      'Times update automatically when your city changes.';

  @override
  String get toolsTitle => 'Tools';

  @override
  String get toolsDirection => 'Direction';

  @override
  String get toolsTracking => 'Tracking';

  @override
  String get toolsQibla => 'Qibla';

  @override
  String get toolsQiblaHint => 'Find the direction of the Kaaba';

  @override
  String get toolsPrayerTracking => 'Prayer tracking';

  @override
  String get toolsPrayerTrackingHint =>
      'Mark what you prayed, count what you owe';

  @override
  String get toolsDhikr => 'Dhikr counter';

  @override
  String get toolsDhikrHint => 'Counter with a target';

  @override
  String get toolsPrivacyNote => 'Tools run on your device; no data leaves it.';

  @override
  String get qiblaTitle => 'Qibla';

  @override
  String get qiblaFromNorth => 'Clockwise from north';

  @override
  String get qiblaNeedsLocation => 'Location required';

  @override
  String get qiblaNeedsLocationHint =>
      'Pick a location or use GPS to find the qibla.';

  @override
  String get qiblaWaiting => 'Waiting for compass…';

  @override
  String get qiblaCalibrate =>
      'The compass needs calibration. Move your phone in a figure eight for a few seconds.';

  @override
  String get qiblaAligned => 'You are facing the qibla';

  @override
  String qiblaTurnRight(Object degrees) {
    return 'Turn $degrees° right';
  }

  @override
  String qiblaTurnLeft(Object degrees) {
    return 'Turn $degrees° left';
  }

  @override
  String get trackingTitle => 'Prayer tracking';

  @override
  String get trackingLastDays => 'Last 7 days';

  @override
  String get trackingQadaCounter => 'Missed prayers';

  @override
  String get trackingDone => 'Prayed';

  @override
  String get trackingQada => 'Missed';

  @override
  String get trackingEmpty => 'Empty';

  @override
  String get dhikrTitle => 'Dhikr counter';

  @override
  String get dhikrTarget => 'Target';

  @override
  String get dhikrTapToCount => 'Tap anywhere to count';

  @override
  String dhikrProgress(Object remaining, Object laps) {
    return '$remaining to go · Round $laps';
  }

  @override
  String dhikrTodayTotal(Object count) {
    return 'Today: $count';
  }

  @override
  String get dhikrResetTitle => 'Reset counter';

  @override
  String get dhikrResetBody => 'Today\'s count will be cleared.';

  @override
  String notificationPrayerNow(Object prayer) {
    return '$prayer time has begun';
  }

  @override
  String notificationPrayerSoon(Object prayer) {
    return '$prayer is approaching';
  }

  @override
  String notificationMinutesLeft(Object prayer, Object minutes) {
    return '$minutes minutes to $prayer';
  }

  @override
  String notificationDerivedSoon(Object name) {
    return '$name is approaching';
  }

  @override
  String notificationDerivedMinutesLeft(Object name, Object minutes) {
    return '$minutes minutes to $name';
  }

  @override
  String religiousDayTodayEstimated(Object name) {
    return '$name is today. The date is calculated and may differ by a day from the official calendar.';
  }

  @override
  String religiousDayToday(Object name) {
    return '$name is today.';
  }

  @override
  String religiousDayTomorrowTitle(Object name) {
    return '$name is tomorrow';
  }

  @override
  String religiousDayTomorrowBody(Object name) {
    return '$name will be observed tomorrow.';
  }

  @override
  String get derivedIshraq => 'Ishraq';

  @override
  String get derivedIstiwa => 'Zawal (disliked time)';

  @override
  String get derivedPreMaghrib => 'Before Maghrib (disliked time)';

  @override
  String get derivedMidnight => 'Islamic midnight';

  @override
  String get derivedLastThird => 'Last third of the night';

  @override
  String get derivedIshraqHint => 'Disliked time ends after sunrise';

  @override
  String get derivedIstiwaHint => 'Disliked time before noon begins';

  @override
  String get derivedPreMaghribHint => 'Disliked time before sunset begins';

  @override
  String get derivedMidnightHint => 'Midpoint of the Islamic night';

  @override
  String get derivedLastThirdHint => 'Tahajjud time begins';
}
