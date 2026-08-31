import 'package:flutter/material.dart';
import '../models/prayer_time.dart';
import '../models/notification_setting.dart';

class PrayerUtils {
  const PrayerUtils._();

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

  /// Sıradaki vaktin **tipi**; adı çağıran taraf çeviriden alır.
  ///
  /// Eskiden Türkçe ad dönüyordu ve çağıranlar o ada göre ikon seçiyordu;
  /// çeviri gelince bu kalıp sessizce bozulurdu.
  static PrayerType? getNextPrayerType(PrayerTime? todaysPrayerTime) {
    if (todaysPrayerTime == null) return null;
    final now = DateTime.now();
    final pt = todaysPrayerTime;

    if (now.isBefore(pt.fajr)) return PrayerType.fajr;
    if (now.isBefore(pt.sunrise)) return PrayerType.sunrise;
    if (now.isBefore(pt.dhuhr)) return PrayerType.dhuhr;
    if (now.isBefore(pt.asr)) return PrayerType.asr;
    if (now.isBefore(pt.maghrib)) return PrayerType.maghrib;
    if (now.isBefore(pt.isha)) return PrayerType.isha;
    return PrayerType.fajr;
  }
}
