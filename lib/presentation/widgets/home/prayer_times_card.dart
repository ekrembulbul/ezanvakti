import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';

class PrayerTimesCard extends StatelessWidget {
  final PrayerTime prayerTime;
  final PrayerType? currentPrayer;

  const PrayerTimesCard({
    super.key,
    required this.prayerTime,
    this.currentPrayer,
  });

  @override
  Widget build(BuildContext context) {
    final prayers = PrayerType.values;

    final rows = <Widget>[];
    for (var index = 0; index < prayers.length; index++) {
      final type = prayers[index];
      rows.add(
        Expanded(
          child: PrayerTimeRow(
            type: type,
            time: PrayerUtils.getPrayerTime(prayerTime, type),
            isCurrent: type == currentPrayer,
          ),
        ),
      );
      if (index < prayers.length - 1) {
        rows.add(
          Divider(
            color: Colors.white.withValues(alpha: 0.1),
            height: 1,
            indent: 12,
            endIndent: 12,
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: AppTheme.glassDecoration(opacity: 0.1, borderRadius: 22),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          // Kalan alanı doldurur; satırlar mevcut yüksekliğe göre eşit dağılır.
          Expanded(child: Column(children: rows)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.schedule_rounded, color: AppTheme.gold, size: 20),
        const SizedBox(width: 8),
        const Text(
          'Namaz Vakitleri',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class PrayerTimeRow extends StatelessWidget {
  final PrayerType type;
  final DateTime time;
  final bool isCurrent;

  const PrayerTimeRow({
    super.key,
    required this.type,
    required this.time,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final name = PrayerUtils.getPrayerName(type);
    final icon = PrayerUtils.getPrayerIcon(type);
    final timeStr = DateFormat('HH:mm').format(time);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppTheme.gold.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppTheme.gold.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isCurrent
                  ? AppTheme.gold
                  : Colors.white.withValues(alpha: 0.7),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent ? AppTheme.gold : Colors.white,
              ),
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppTheme.gold,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ŞİMDİ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryDark,
                ),
              ),
            ),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isCurrent ? AppTheme.gold : Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
