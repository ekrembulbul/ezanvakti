import '../../core/models/notification_setting.dart';

class PrayerNameHelper {
  static String getName(PrayerType type) {
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

  static List<PrayerType> getAllPrayerTypes() {
    return [
      PrayerType.fajr,
      PrayerType.sunrise,
      PrayerType.dhuhr,
      PrayerType.asr,
      PrayerType.maghrib,
      PrayerType.isha,
    ];
  }

  static int getPrayerOrder(PrayerType type) {
    const order = {
      PrayerType.fajr: 0,
      PrayerType.sunrise: 1,
      PrayerType.dhuhr: 2,
      PrayerType.asr: 3,
      PrayerType.maghrib: 4,
      PrayerType.isha: 5,
    };
    return order[type]!;
  }
}
