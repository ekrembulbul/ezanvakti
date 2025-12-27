import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/hijri_formatter.dart';

class DateWidget extends StatelessWidget {
  final DateTime date;

  const DateWidget({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final miladi = DateFormat('EEEE, d MMMM yyyy', 'tr_TR').format(date);
    final hijri = HijriFormatter.format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          miladi,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 1),
        Text(
          hijri,
          style: TextStyle(
            fontSize: 11.5,
            color: AppTheme.gold.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}
