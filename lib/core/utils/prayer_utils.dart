import 'package:flutter/material.dart';
import '../models/prayer_time.dart';
import '../models/notification_setting.dart';

class PrayerUtils {
  const PrayerUtils._();

  static String getPrayerName(PrayerType type) {
    switch (type) {
      case PrayerType.fajr:
        return 'İmsak';
      case PrayerType.sunrise:
        return 'Güneş';
      case PrayerType.dhuhr:
        return 'Öğle';
      case PrayerType.asr:
        return 'İkindi';
      case PrayerType.maghrib:
        return 'Akşam';
      case PrayerType.isha:
        return 'Yatsı';
    }
  }

  static IconData getPrayerIcon(PrayerType type) {
    switch (type) {
      case PrayerType.fajr:
        return Icons.nights_stay_rounded;
      case PrayerType.sunrise:
        return Icons.wb_sunny_rounded;
      case PrayerType.dhuhr:
        return Icons.light_mode_rounded;
      case PrayerType.asr:
        return Icons.wb_twilight_rounded;
      case PrayerType.maghrib:
        return Icons.nightlight_round;
      case PrayerType.isha:
        return Icons.bedtime_rounded;
    }
  }

  static IconData getPrayerIconByName(String name) {
    switch (name) {
      case 'İmsak':
        return Icons.nights_stay_rounded;
      case 'Güneş':
        return Icons.wb_sunny_rounded;
      case 'Öğle':
        return Icons.light_mode_rounded;
      case 'İkindi':
        return Icons.wb_twilight_rounded;
      case 'Akşam':
        return Icons.nightlight_round;
      case 'Yatsı':
        return Icons.bedtime_rounded;
      default:
        return Icons.access_time_rounded;
    }
  }

  static DateTime getPrayerTime(PrayerTime prayerTime, PrayerType type) {
    switch (type) {
      case PrayerType.fajr:
        return prayerTime.fajr;
      case PrayerType.sunrise:
        return prayerTime.sunrise;
      case PrayerType.dhuhr:
        return prayerTime.dhuhr;
      case PrayerType.asr:
        return prayerTime.asr;
      case PrayerType.maghrib:
        return prayerTime.maghrib;
      case PrayerType.isha:
        return prayerTime.isha;
    }
  }

  static PrayerType? getCurrentPrayer(PrayerTime prayerTime) {
    final now = DateTime.now();
    if (now.isBefore(prayerTime.fajr)) return null;
    if (now.isBefore(prayerTime.sunrise)) return PrayerType.fajr;
    if (now.isBefore(prayerTime.dhuhr)) return PrayerType.sunrise;
    if (now.isBefore(prayerTime.asr)) return PrayerType.dhuhr;
    if (now.isBefore(prayerTime.maghrib)) return PrayerType.asr;
    if (now.isBefore(prayerTime.isha)) return PrayerType.maghrib;
    return PrayerType.isha;
  }

  static DateTime? getNextPrayerTime(
    PrayerTime? todaysPrayerTime,
    PrayerTime? tomorrowsPrayerTime,
  ) {
    if (todaysPrayerTime == null) return null;
    final now = DateTime.now();
    final pt = todaysPrayerTime;

    if (now.isBefore(pt.fajr)) return pt.fajr;
    if (now.isBefore(pt.sunrise)) return pt.sunrise;
    if (now.isBefore(pt.dhuhr)) return pt.dhuhr;
    if (now.isBefore(pt.asr)) return pt.asr;
    if (now.isBefore(pt.maghrib)) return pt.maghrib;
    if (now.isBefore(pt.isha)) return pt.isha;

    return tomorrowsPrayerTime?.fajr;
  }

  static String? getNextPrayerName(PrayerTime? todaysPrayerTime) {
    if (todaysPrayerTime == null) return null;
    final now = DateTime.now();
    final pt = todaysPrayerTime;

    if (now.isBefore(pt.fajr)) return 'İmsak';
    if (now.isBefore(pt.sunrise)) return 'Güneş';
    if (now.isBefore(pt.dhuhr)) return 'Öğle';
    if (now.isBefore(pt.asr)) return 'İkindi';
    if (now.isBefore(pt.maghrib)) return 'Akşam';
    if (now.isBefore(pt.isha)) return 'Yatsı';
    return 'İmsak';
  }
}
