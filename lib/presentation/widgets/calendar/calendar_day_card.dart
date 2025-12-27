import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';
import '../../../core/utils/hijri_formatter.dart';

class CalendarDayCard extends StatelessWidget {
  final PrayerTime prayerTime;
  final bool isToday;

  const CalendarDayCard({
    super.key,
    required this.prayerTime,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final dayFormat = DateFormat('EEEE', 'tr_TR');
    final hijri = HijriFormatter.format(prayerTime.date);

    return Container(
      key: Key('day_card_${prayerTime.date.toIso8601String()}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isToday
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.gold.withValues(alpha: 0.2),
                  AppTheme.gold.withValues(alpha: 0.05),
                ],
              )
            : null,
        color: isToday ? null : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: isToday
            ? Border.all(color: AppTheme.gold.withValues(alpha: 0.5), width: 1.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isToday,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          leading: _DateBadge(date: prayerTime.date, isToday: isToday),
          title: _DayTitle(
            dayName: dayFormat.format(prayerTime.date),
            isToday: isToday,
          ),
          subtitle: _HijriSubtitle(hijri: hijri, isToday: isToday),
          iconColor: isToday ? AppTheme.gold : Colors.white.withValues(alpha: 0.5),
          collapsedIconColor: isToday
              ? AppTheme.gold
              : Colors.white.withValues(alpha: 0.5),
          children: [
            CalendarPrayerTimesGrid(prayerTime: prayerTime, isToday: isToday),
          ],
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime date;
  final bool isToday;

  const _DateBadge({required this.date, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isToday
            ? AppTheme.gold.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date.day.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isToday ? AppTheme.gold : Colors.white,
            ),
          ),
          Text(
            DateFormat('MMM', 'tr_TR').format(date).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isToday ? AppTheme.gold : Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTitle extends StatelessWidget {
  final String dayName;
  final bool isToday;

  const _DayTitle({required this.dayName, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: AppTheme.gold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'BUGÜN',
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Expanded(
          child: Text(
            dayName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isToday ? AppTheme.gold : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _HijriSubtitle extends StatelessWidget {
  final String hijri;
  final bool isToday;

  const _HijriSubtitle({required this.hijri, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        hijri,
        style: TextStyle(
          fontSize: 12,
          color: isToday
              ? AppTheme.gold.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class CalendarPrayerTimesGrid extends StatelessWidget {
  final PrayerTime prayerTime;
  final bool isToday;

  const CalendarPrayerTimesGrid({
    super.key,
    required this.prayerTime,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final prayers = PrayerType.values;
    final timeFormat = DateFormat('HH:mm');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: prayers.map((type) {
        final time = PrayerUtils.getPrayerTime(prayerTime, type);
        return CalendarPrayerTimeCell(
          type: type,
          time: timeFormat.format(time),
          isToday: isToday,
        );
      }).toList(),
    );
  }
}

class CalendarPrayerTimeCell extends StatelessWidget {
  final PrayerType type;
  final String time;
  final bool isToday;

  const CalendarPrayerTimeCell({
    super.key,
    required this.type,
    required this.time,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = (screenWidth - 80) / 3 - 8;

    return Container(
      width: cellWidth,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isToday
            ? AppTheme.gold.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            PrayerUtils.getPrayerIcon(type),
            size: 20,
            color: isToday ? AppTheme.gold : Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 6),
          Text(
            PrayerUtils.getPrayerName(type),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isToday ? AppTheme.gold : Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isToday ? AppTheme.gold : Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
