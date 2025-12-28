import '../../../core/models/notification_setting.dart';

const List<NotificationSetting> defaultNotificationSettings = [
  NotificationSetting(
    prayerType: PrayerType.fajr,
    isActive: true,
    minutesBefore: 0,
  ),
  NotificationSetting(
    prayerType: PrayerType.sunrise,
    isActive: true,
    minutesBefore: 30,
  ),
  NotificationSetting(
    prayerType: PrayerType.dhuhr,
    isActive: true,
    minutesBefore: 0,
  ),
  NotificationSetting(
    prayerType: PrayerType.asr,
    isActive: true,
    minutesBefore: 0,
  ),
  NotificationSetting(
    prayerType: PrayerType.asr,
    isActive: true,
    minutesBefore: 15,
  ),
  NotificationSetting(
    prayerType: PrayerType.maghrib,
    isActive: true,
    minutesBefore: 0,
  ),
  NotificationSetting(
    prayerType: PrayerType.maghrib,
    isActive: true,
    minutesBefore: 60,
  ),
  NotificationSetting(
    prayerType: PrayerType.isha,
    isActive: true,
    minutesBefore: 0,
  ),
  NotificationSetting(
    prayerType: PrayerType.isha,
    isActive: true,
    minutesBefore: 15,
  ),
];
