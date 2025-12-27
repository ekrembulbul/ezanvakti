import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/hijri_formatter.dart';

class DateCard extends StatelessWidget {
  final DateTime date;

  const DateCard({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final miladi = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(date);
    final hijri = HijriFormatter.format(date);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: AppTheme.glassDecoration(opacity: 0.1, borderRadius: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.gold.withValues(alpha: 0.3),
                  AppTheme.gold.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: AppTheme.gold,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  miladi,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hijri,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.gold.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
