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

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersNotifications => 'Notifications';

  @override
  String get remindersAlarms => 'Alarms';

  @override
  String get remindersNoNotifications => 'No notifications yet';

  @override
  String get remindersNoNotificationsHint =>
      'Add a notification to be reminded\nat prayer times.';

  @override
  String get remindersNoAlarms => 'No alarms yet';

  @override
  String get remindersNoAlarmsHint =>
      'Add a fixed-time or prayer-anchored alarm';

  @override
  String remindersCount(Object count) {
    return '$count reminders';
  }

  @override
  String remindersAlarmCount(Object count) {
    return '$count alarms';
  }

  @override
  String get remindersAddFriday => 'Add Friday prayer reminder';

  @override
  String get reminderFridayLabel => 'Friday prayer';

  @override
  String get reminderOnTime => 'On time';

  @override
  String reminderMinutesBefore(Object minutes) {
    return '$minutes min before';
  }

  @override
  String get reminderSkippedOnce => 'Skipped just this once';

  @override
  String get reminderOff => 'Off';

  @override
  String get reminderScheduleFailed =>
      'Could not be scheduled — edit and save to retry';

  @override
  String get quietTitle => 'Quiet windows';

  @override
  String get quietIntro =>
      'During these windows Ezan Vakti notifications are shown silently or not at all. An app cannot silence your iPhone; this setting affects only this app\'s notifications and leaves alarms untouched.';

  @override
  String get quietFridaySection => 'Friday prayer';

  @override
  String get quietFridayTitle => 'Silent at Friday prayer';

  @override
  String get quietFridayHint =>
      'Notifications go quiet around Friday noon. You can change the durations or turn it off.';

  @override
  String get quietCustomSection => 'Custom windows';

  @override
  String get quietNoCustom => 'No custom windows yet.';

  @override
  String get quietAddWindow => 'Add window';

  @override
  String get quietMinutesBefore => 'Minutes before';

  @override
  String get quietMinutesAfter => 'Minutes after';

  @override
  String get quietModeLabel => 'During this window';

  @override
  String get quietModeSilent => 'Show silently';

  @override
  String get quietModeSilentHint => 'Notification appears without sound';

  @override
  String get quietModeSkip => 'Do not show';

  @override
  String get quietModeSkipHint => 'The notification is not scheduled at all';

  @override
  String quietWindowSummary(Object before, Object after) {
    return '$before min before – $after min after';
  }

  @override
  String get quietPrayerLabel => 'Prayer';

  @override
  String get prefsNewSound => 'New notification sound';

  @override
  String get soundSystem => 'System sound';

  @override
  String get soundSystemHint => 'Your device\'s default notification sound';

  @override
  String get soundBeep => 'Short chime';

  @override
  String get soundBeepHint => 'The app\'s own short tone';

  @override
  String get soundSilent => 'Silent';

  @override
  String get soundSilentHint => 'Notification appears without sound';

  @override
  String get prefsShowInFocus => 'Show during Focus';

  @override
  String get prefsShowInFocusHint =>
      'Notifications are not held back by Focus. This does not bypass the silent switch.';

  @override
  String get prefsReligiousDays => 'Religious days';

  @override
  String get prefsReligiousDaysHint =>
      'Reminds you at sunset on holy nights and festivals. Dates are computed from the Hijri calendar and may differ by a day from the official one.';

  @override
  String get prefsReligiousDayEve => 'Also remind the day before';

  @override
  String get prefsReligiousDayEveHint =>
      'Sends a \"tomorrow\" notification at noon.';

  @override
  String get alarmAdd => 'Add alarm';

  @override
  String get alarmEdit => 'Edit alarm';

  @override
  String get alarmFixedTime => 'Fixed time';

  @override
  String get alarmAnchored => 'By prayer';

  @override
  String get alarmRepeat => 'Repeat';

  @override
  String get alarmLabel => 'Label';

  @override
  String get alarmLabelHint => 'e.g. Suhoor';

  @override
  String get alarmSound => 'Sound';

  @override
  String get alarmSoundDefault => 'Default';

  @override
  String get alarmSoundCustom => 'Custom sound';

  @override
  String get alarmSoundPick => 'Pick a sound from device…';

  @override
  String get alarmSoundVolumeNote =>
      'Alarms play at the Ringer & Alerts volume.';

  @override
  String get alarmVibrate => 'Vibration';

  @override
  String get alarmSnooze => 'Snooze';

  @override
  String get alarmSnoozeCount => 'Snooze limit';

  @override
  String get alarmSnoozeUnlimited => 'Unlimited';

  @override
  String alarmSnoozeTimes(Object count) {
    return '$count times';
  }

  @override
  String get alarmMission => 'Dismiss task';

  @override
  String get alarmMissionQuestion => 'How will you dismiss the alarm?';

  @override
  String get missionNone => 'No task';

  @override
  String get missionNoneHint => 'Dismissed by swiping';

  @override
  String get missionMath => 'Math';

  @override
  String get missionMathHint => 'Solve problems to dismiss';

  @override
  String get missionShake => 'Shake';

  @override
  String get missionShakeHint => 'Dismissed by shaking the phone';

  @override
  String get missionQr => 'Scan QR';

  @override
  String get missionQrHint => 'Scan the saved code to dismiss';

  @override
  String get alarmEveryDay => 'Every day';

  @override
  String get alarmWeekdays => 'Weekdays';

  @override
  String get alarmWeekend => 'Weekend';

  @override
  String get alarmCopySuffix => '(copy)';

  @override
  String get alarmDuplicate => 'Duplicate';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get calendarTitle => 'Prayer Calendar';

  @override
  String get calendarShare => 'Share calendar';

  @override
  String get calendarEmpty => 'No calendar data';

  @override
  String get calendarLoading => 'Loading calendar…';

  @override
  String get calendarShareFailed => 'Could not create the calendar image';

  @override
  String calendarDayCount(Object count) {
    return '$count days';
  }

  @override
  String get upcomingNext => 'NEXT';

  @override
  String upcomingNotification(Object prayer) {
    return '$prayer notification';
  }

  @override
  String get upcomingTomorrow => 'tomorrow';

  @override
  String get upcomingToday => 'today';

  @override
  String get snackNotificationAdded => 'Notification added';

  @override
  String get snackNotificationUpdated => 'Notification updated';

  @override
  String get snackNotificationDeleted => 'Notification deleted';

  @override
  String get snackNotificationExists => 'This notification already exists';

  @override
  String get snackAlarmDeleted => 'Alarm deleted';

  @override
  String get snackSkipOnce => 'Just this once';

  @override
  String get snackUndo => 'Undo';

  @override
  String get locationTitle => 'Locations';

  @override
  String get locationAdd => 'Add location';

  @override
  String get locationSearch => 'Search a city';

  @override
  String get locationUseGps => 'Use my location';

  @override
  String get locationEmpty => 'No saved locations';

  @override
  String shareCaption(Object location, Object period) {
    return '$location · prayer times for $period';
  }

  @override
  String get ramadanIftarCountdown => 'To iftar';

  @override
  String get ramadanSuhoorCountdown => 'To end of suhoor';

  @override
  String ramadanDay(Object day) {
    return 'Ramadan day $day';
  }

  @override
  String get ramadanCalendarTitle => 'Ramadan Timetable';

  @override
  String get ramadanFastingSection => 'Fasting';

  @override
  String get ramadanFasted => 'Fasted';

  @override
  String get ramadanFastMissed => 'To make up';

  @override
  String get ramadanFastExempt => 'Exempt';

  @override
  String get ramadanFastingQada => 'Fasts to make up';

  @override
  String get ramadanSetupTitle => 'Ramadan reminders';

  @override
  String get ramadanSetupBody =>
      'Add suhoor (45 min before Fajr) and iftar notifications? They appear in your reminders list and can be removed anytime.';

  @override
  String get ramadanSetupAccept => 'Add';

  @override
  String get ramadanSuhoorLabel => 'Suhoor';

  @override
  String get ramadanIftarLabel => 'Iftar';

  @override
  String get ramadanRemindersAdded => 'Suhoor and iftar reminders added';
}
