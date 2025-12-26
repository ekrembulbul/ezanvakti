import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';

class DateCard extends StatelessWidget {
  final DateTime date;

  const DateCard({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final miladi = DateFormat('d MMMM yyyy EEEE', 'tr_TR').format(date);
    final hijri = _formatHijriDate(date);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              miladi,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey.shade900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hijri,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatHijriDate(DateTime date) {
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
