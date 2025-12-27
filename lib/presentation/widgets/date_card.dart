import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/hijri_formatter.dart';

class DateCard extends StatelessWidget {
  final DateTime date;

  const DateCard({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final miladi = DateFormat('d MMMM yyyy EEEE', 'tr_TR').format(date);
    final hijri = HijriFormatter.format(date);

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
}
