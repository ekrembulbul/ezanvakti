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

  @override
  String get locationsTitle => 'Locations';

  @override
  String get locationsLoading => 'Loading locations…';

  @override
  String locationsLoadFailed(Object error) {
    return 'Could not load locations: $error';
  }

  @override
  String get locationsEmpty => 'No locations added yet';

  @override
  String get locationsEmptyHint =>
      'Detect automatically with GPS or\nsearch for an address';

  @override
  String get locationsSwipeHint =>
      'Swipe a row to delete a location that is not active.';

  @override
  String get locationActive => 'ACTIVE';

  @override
  String get locationAddTitle => 'Add location';

  @override
  String get locationEditTitle => 'Edit location';

  @override
  String get locationSearchHint => 'Search by city, district or place';

  @override
  String get locationSearchPlaceholder => 'Search city, district or place…';

  @override
  String get locationSearchStart => 'Start typing to search.';

  @override
  String get locationSearchNoResult =>
      'No results.\nTry a different search or check your connection.';

  @override
  String get locationGettingPosition => 'Getting location…';

  @override
  String get locationPermissionTitle => 'Location permission';

  @override
  String get locationPermissionBody =>
      'Location access is needed to show prayer times for where you are. Granting it selects your city automatically.';

  @override
  String get locationPermissionAllow => 'Allow';

  @override
  String get locationServicesOff =>
      'Location services are off. Please turn them on.';

  @override
  String get locationPermissionDenied =>
      'Location permission is permanently denied. Grant it from Settings.';

  @override
  String get locationUpdated => 'Location updated';

  @override
  String get locationSelectFirst => 'Please pick a location';

  @override
  String get locationCustomName => 'Custom name (optional)';

  @override
  String get locationCustomNameHint => 'e.g. Home, Work';

  @override
  String get locationUseGlobalCalculation =>
      'Use the global calculation setting';

  @override
  String get locationUseGlobalCalculationHint =>
      'Turn off to pick a method for this location only';

  @override
  String get locationCalculationFromGlobal =>
      'The calculation method comes from the global setting. To change it for this location, edit after saving.';

  @override
  String get locationChange => 'Change';

  @override
  String locationUndoFailed(Object error) {
    return 'Could not undo: $error';
  }

  @override
  String get osmAttribution => '© OpenStreetMap contributors';

  @override
  String get widgetTomorrow => 'Tomorrow';

  @override
  String get widgetStale => 'Out of date';

  @override
  String get widgetOpenApp => 'Open the app for prayer times';

  @override
  String get widgetUpdateApp => 'Please update the app';

  @override
  String siriAnswer(Object prayer, Object time, Object remaining) {
    return '$prayer at $time, $remaining left.';
  }

  @override
  String durationHourMinute(Object hours, Object minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationHour(Object hours) {
    return '$hours h';
  }

  @override
  String durationMinute(Object minutes) {
    return '$minutes min';
  }

  @override
  String get hijriMuharram => 'Muharram';

  @override
  String get hijriSafar => 'Safar';

  @override
  String get hijriRabiAwwal => 'Rabi al-Awwal';

  @override
  String get hijriRabiThani => 'Rabi al-Thani';

  @override
  String get hijriJumadaAwwal => 'Jumada al-Awwal';

  @override
  String get hijriJumadaThani => 'Jumada al-Thani';

  @override
  String get hijriRajab => 'Rajab';

  @override
  String get hijriShaban => 'Sha\'ban';

  @override
  String get hijriRamadan => 'Ramadan';

  @override
  String get hijriShawwal => 'Shawwal';

  @override
  String get hijriDhulQadah => 'Dhu al-Qi\'dah';

  @override
  String get hijriDhulHijjah => 'Dhu al-Hijjah';

  @override
  String get religiousNewYear => 'Islamic New Year';

  @override
  String get religiousAshura => 'Ashura';

  @override
  String get religiousMawlid => 'Mawlid al-Nabi';

  @override
  String get religiousRegaib => 'Laylat al-Raghaib';

  @override
  String get religiousMiraj => 'Laylat al-Miraj';

  @override
  String get religiousBaraat => 'Laylat al-Baraat';

  @override
  String get religiousRamadanStart => 'Start of Ramadan';

  @override
  String get religiousQadr => 'Laylat al-Qadr';

  @override
  String get religiousEidFitr => 'Eid al-Fitr';

  @override
  String get religiousArafah => 'Day of Arafah';

  @override
  String get religiousEidAdha => 'Eid al-Adha';

  @override
  String get asrShafi => 'Shafi (Standard)';

  @override
  String get asrHanafi => 'Hanafi';

  @override
  String get latAuto => 'Automatic';

  @override
  String get latMidnight => 'Middle of the night';

  @override
  String get latOneSeventh => 'One seventh of the night';

  @override
  String get latAngle => 'Angle based';

  @override
  String get calcMethodLabel => 'Calculation method';

  @override
  String get calcAsrLabel => 'Asr (school)';

  @override
  String get calcAdvanced => 'Advanced';

  @override
  String get calcLatitudeLabel => 'High latitude rule';

  @override
  String get calcGlobalNote =>
      'Default for all locations. Used unless a location has its own setting.';

  @override
  String get calcTuneSection => 'Time adjustments';

  @override
  String get calcTuneHint =>
      'Shift times by a few minutes to match your calendar. Notifications, alarms and the widget use the adjusted times.';

  @override
  String minutesShort(Object minutes) {
    return '$minutes min';
  }

  @override
  String get offlineFresh => 'Data is up to date';

  @override
  String get offlineShouldUpdate => 'Data should be refreshed';

  @override
  String get offlineTooOld => 'Data is too old, an update is needed';

  @override
  String get offlineNoData => 'No data';

  @override
  String get offlineNoConnection =>
      'No internet connection. Showing saved data.';

  @override
  String get offlineFetchFailed =>
      'Could not fetch data. Please check your connection.';

  @override
  String get offlineUpdateFailed => 'Update failed. Showing saved data.';

  @override
  String errorDataLoad(Object error) {
    return 'Error loading data: $error';
  }

  @override
  String errorLocationChange(Object error) {
    return 'Could not change location: $error';
  }

  @override
  String errorGpsRefresh(Object error) {
    return 'GPS refresh failed: $error';
  }

  @override
  String gpsUpdated(Object location) {
    return 'GPS location updated: $location';
  }

  @override
  String get errorParseFormat =>
      'The data format may have changed. Please try updating the app.';

  @override
  String get loading => 'Loading…';

  @override
  String get today => 'TODAY';

  @override
  String get nextLabel => 'NEXT';

  @override
  String adhanAt(Object prayer, Object time) {
    return 'Adhan for $prayer at $time';
  }

  @override
  String get upcomingTitle => 'Upcoming';

  @override
  String get upcomingAll => 'All';

  @override
  String get upcomingEmpty => 'No upcoming notification or alarm';

  @override
  String get alarmQrRequired => 'Scan or type a code for the QR task';

  @override
  String get alarmPickSavedCode => 'Pick a saved code';

  @override
  String get alarmAnchorQuestion => 'Anchored to which prayer?';

  @override
  String get alarmBefore => 'Before';

  @override
  String get alarmAfter => 'After';

  @override
  String get alarmBeforePrayer => 'Before the prayer';

  @override
  String get alarmAfterPrayer => 'After the prayer';

  @override
  String get alarmSoundImportFailed => 'Could not import the sound file';

  @override
  String get alarmSnoozeMinutes => 'Snooze duration';

  @override
  String get qrSaveTitle => 'Save code to library';

  @override
  String get qrSaveHint => 'e.g. Bathroom mirror';

  @override
  String get qrLibraryEmpty =>
      'No saved codes yet — save a code after scanning';

  @override
  String get qrRenameTitle => 'Rename code';

  @override
  String get qrInUseTitle => 'Code in use';

  @override
  String qrInUseBody(Object alarms) {
    return 'These alarms use this code as their task: $alarms. Deleting it from the library does not break the alarm, but you cannot pick the code again.';
  }

  @override
  String get qrDeleteAnyway => 'Delete anyway';

  @override
  String get qrDefaultName => 'QR code';

  @override
  String get qrFieldHint => 'Scan or type the code';

  @override
  String get qrScanTooltip => 'Scan code';

  @override
  String get qrFieldNote =>
      'Stick the code away from your bed — bathroom door, kitchen. The alarm only stops when this code is scanned.';

  @override
  String get stopJustNow => 'just now';

  @override
  String stopMinutesAgo(Object minutes) {
    return '$minutes min ago';
  }

  @override
  String stopSnoozeLeft(Object count) {
    return '$count left';
  }

  @override
  String get stopDoMission => 'Do the task';

  @override
  String stopReturnsIn(Object countdown) {
    return 'The alarm returns in $countdown if you do not choose';
  }

  @override
  String stopClosesIn(Object countdown) {
    return 'Closes in $countdown if untouched';
  }

  @override
  String get missionTimeUp => 'Time is up, the alarm is returning';

  @override
  String get missionCountdownNote => 'the alarm returns when time runs out';

  @override
  String get missionCloseCompletely => 'Dismiss the alarm completely';

  @override
  String get missionWrongAnswer => 'Wrong, try again.';

  @override
  String get missionShakeDone => 'done';

  @override
  String get qrMissionNoCode => 'This alarm has no saved QR code.';

  @override
  String get qrMissionNoCodeHint =>
      'Edit the alarm to add a code, or use the emergency exit.';

  @override
  String get qrMissionMismatch => 'A different code was scanned';

  @override
  String get qrMissionScanSaved => 'Scan the code you saved';

  @override
  String get qrMissionFindCode =>
      'Find the code you saved when setting the alarm and scan it.';

  @override
  String get qrMissionAimCamera => 'Point the camera at the code.';

  @override
  String get abortDismissing => 'i am dismissing the alarm';

  @override
  String get abortDismissingHard =>
      'i am dismissing the alarm without the task';

  @override
  String get abortTitle => 'You are dismissing the alarm without the task.';

  @override
  String get abortMaxLevel =>
      'The exit is already at its hardest level; it will not get harder.';

  @override
  String get abortHarderNext => 'Next time the exit will be harder.';

  @override
  String abortTypePhrase(Object phrase) {
    return 'Type this exactly: “$phrase”';
  }

  @override
  String get abortPhraseHint => 'Type the phrase';

  @override
  String get abortHoldToClose => 'Hold for 3 seconds to dismiss';

  @override
  String get remindersUpdate => 'Update';

  @override
  String get remindersUpdateTitle => 'Update notification';

  @override
  String get remindersAddTitle => 'Add notification';

  @override
  String get remindersAddButton => 'Add notification';

  @override
  String get remindersWhichPrayer =>
      'For which prayer do you want a notification?';

  @override
  String get remindersPrayerSection => 'Prayer';

  @override
  String get remindersDerivedSection => 'Derived times';

  @override
  String get remindersDerivedHint =>
      'Disliked and voluntary windows are computed from the chosen prayer.';

  @override
  String get remindersTimeSection => 'Notification time';

  @override
  String get remindersDaysSection => 'Days';

  @override
  String get remindersLabelSection => 'Label (optional)';

  @override
  String get remindersOnTimeOption => 'On time';

  @override
  String get remindersBeforeOption => 'Before';

  @override
  String get remindersPickMinutes => 'Pick minutes';

  @override
  String get remindersMinOffsetError => 'Must be at least 1 min before';

  @override
  String remindersMaxOffsetError(Object max) {
    return 'You can add a notification at most $max min before this prayer.';
  }

  @override
  String get remindersSwipeToDelete => 'Swipe a row to delete it.';

  @override
  String get remindersIntro =>
      'For each prayer you can be reminded on time or X minutes before.';

  @override
  String get alarmsSwipeHint =>
      'Swipe a row to delete; if it was a mistake, use \"Undo\" below. Alarms are rescheduled automatically when times update.';

  @override
  String get alarmsRescheduleNote =>
      'Alarms are rescheduled as prayer data updates.';

  @override
  String get alarmsUnsupported =>
      'Audible alarms are not supported on this device (iOS 26 or later required). Alarms are saved but will not ring.';

  @override
  String get alarmsNeedPermission => 'Permission is needed for alarms to ring.';

  @override
  String get permissionGrant => 'Grant';

  @override
  String get notificationsNeedPermission =>
      'You need to grant permission to receive notifications.';

  @override
  String get exactAlarmOff =>
      'Exact alarms are off. Notifications may be delayed.';

  @override
  String get actionOpen => 'Open';

  @override
  String alarmDeleted(Object label) {
    return 'Alarm $label deleted';
  }

  @override
  String get alarmBlockedSnoozed =>
      'This alarm is snoozed and still owes its task; it cannot be turned off yet.';

  @override
  String get alarmTurnedOff => 'Alarm turned off';

  @override
  String snoozeUntil(Object time) {
    return 'Rings at $time';
  }

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLabel => 'Theme';

  @override
  String get appearanceTimeColor => 'Color follows the time';

  @override
  String get appearanceTimeColorOn => 'The background shifts through the day';

  @override
  String get appearanceTimeColorOff => 'Pick a fixed palette';

  @override
  String get settingsVersionLoading => 'Loading version…';

  @override
  String settingsVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get settingsFooter =>
      'Prayer times are stored on your device and never sent anywhere.';

  @override
  String get privacyBody =>
      'Your location is used only to calculate prayer times and stays on your device. Times are requested from the Aladhan API by coordinates; no personal data is sent.';

  @override
  String dstSummer(Object offset) {
    return 'Daylight saving time in effect ($offset)';
  }

  @override
  String dstWinter(Object offset) {
    return 'Standard time in effect ($offset)';
  }

  @override
  String get weekdayShortMon => 'Mon';

  @override
  String get weekdayShortTue => 'Tue';

  @override
  String get weekdayShortWed => 'Wed';

  @override
  String get weekdayShortThu => 'Thu';

  @override
  String get weekdayShortFri => 'Fri';

  @override
  String get weekdayShortSat => 'Sat';

  @override
  String get weekdayShortSun => 'Sun';

  @override
  String get weekdayLetterMon => 'Mo';

  @override
  String get weekdayLetterTue => 'Tu';

  @override
  String get weekdayLetterWed => 'We';

  @override
  String get weekdayLetterThu => 'Th';

  @override
  String get weekdayLetterFri => 'Fr';

  @override
  String get weekdayLetterSat => 'Sa';

  @override
  String get weekdayLetterSun => 'Su';

  @override
  String offsetMinutes(Object sign, Object minutes) {
    return '$sign$minutes min';
  }

  @override
  String snoozedLabel(Object time) {
    return 'Snoozed · rings at $time';
  }

  @override
  String errorGenericWith(Object error) {
    return 'Error: $error';
  }

  @override
  String locationDeleted(Object location) {
    return '$location deleted';
  }
}
