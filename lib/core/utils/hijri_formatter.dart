import 'package:hijri/hijri_calendar.dart';

class HijriFormatter {
  const HijriFormatter._();

  static String format(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    const monthTr = {
      'Muharram': 'Muharrem',
      'Safar': 'Safer',
      "Rabi' al-awwal": 'Rebiülevvel',
      "Rabi' al-thani": 'Rebiülahir',
      'Jumada al-awwal': 'Cemaziyülevvel',
      'Jumada al-thani': 'Cemaziyülahir',
      'Rajab': 'Recep',
      "Sha'aban": 'Şaban',
      'Ramadan': 'Ramazan',
      'Shawwal': 'Şevval',
      "Dhu al-Qi'dah": 'Zilkade',
      'Dhu al-Hijjah': 'Zilhicce',
    };
    final monthName = monthTr[hijri.longMonthName] ?? hijri.longMonthName;
    return '${hijri.hDay} $monthName ${hijri.hYear}';
  }
}
