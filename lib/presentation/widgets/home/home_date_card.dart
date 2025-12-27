import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/hijri_formatter.dart';
import '../../../core/models/location.dart';

class HomeDateCard extends StatelessWidget {
  final DateTime date;
  final Location location;

  const HomeDateCard({super.key, required this.date, required this.location});

  @override
  Widget build(BuildContext context) {
    final miladi = DateFormat('EEEE, d MMMM yyyy', 'tr_TR').format(date);
    final hijri = HijriFormatter.format(date);

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  location.type == LocationType.gps
                      ? Icons.my_location_rounded
                      : Icons.location_on_rounded,
                  color: AppTheme.gold,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.district,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    location.province,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
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
        ),
      ],
    );
  }
}
