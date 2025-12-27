import 'package:hijri/hijri_calendar.dart';

class HijriFormatter {
  const HijriFormatter._();

  static String format(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    const monthTr = {
      'muharram': 'Muharrem',
      'safar': 'Safer',
      "rabi' al-awwal": 'Rebiülevvel',
      "rabi' al-thani": 'Rebiülahir',
      'jumada al-awwal': 'Cemaziyülevvel',
      'jumada al-thani': 'Cemaziyülahir',
      'rajab': 'Recep',
      "sha'aban": 'Şaban',
      'ramadan': 'Ramazan',
      'shawwal': 'Şevval',
      "dhu al-qi'dah": 'Zilkade',
      'dhu al-hijjah': 'Zilhicce',
    };
    final monthKey = hijri.longMonthName.toLowerCase();
    final monthName = monthTr[monthKey] ?? hijri.longMonthName;
    return '${hijri.hDay} $monthName ${hijri.hYear}';
  }
}
