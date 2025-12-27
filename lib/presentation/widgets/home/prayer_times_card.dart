import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';

class PrayerTimesCard extends StatelessWidget {
  final PrayerTime prayerTime;
  final PrayerType? currentPrayer;
  final VoidCallback? onCalendarTap;

  const PrayerTimesCard({
    super.key,
    required this.prayerTime,
    this.currentPrayer,
    this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    final prayers = PrayerType.values;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      decoration: AppTheme.glassDecoration(opacity: 0.1, borderRadius: 18),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          ...prayers.asMap().entries.map((entry) {
            final index = entry.key;
            final type = entry.value;
            final isCurrent = type == currentPrayer;
            return Column(
              children: [
                PrayerTimeRow(
                  type: type,
                  time: PrayerUtils.getPrayerTime(prayerTime, type),
                  isCurrent: isCurrent,
                ),
                if (index < prayers.length - 1)
                  Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                    height: 1,
                    indent: 12,
                    endIndent: 12,
                  ),
              ],
            );
          }),
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
        const Spacer(),
        if (onCalendarTap != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCalendarTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: AppTheme.gold,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Takvim',
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppTheme.gold.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
              size: 20,
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
