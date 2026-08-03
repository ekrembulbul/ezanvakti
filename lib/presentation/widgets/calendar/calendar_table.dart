import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/prayer_utils.dart';
import '../common/section_label.dart';

/// Bir takvim satırının yüksekliği. `itemExtent` olarak verilir; sabit olması
/// uzun listede kaydırmayı ucuzlatır.
const double kCalendarRowHeight = 76;

/// Tarih kolonunun genişliği; başlık ve satırlarda aynı olmak zorunda.
const double _kDayColumnWidth = 64;

/// Saat kolonlarının iki yanındaki boşluk. Değerler `FittedBox` ile kolonu
/// doldurduğu için boşluk verilmezse saatler bitişik görünüyor.
const double _kColumnGap = 4;

/// Takvimin sabit başlık satırı: vakit adları.
class CalendarHeaderRow extends StatelessWidget {
  const CalendarHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.divider)),
      ),
      child: Row(
        children: [
          const SizedBox(width: _kDayColumnWidth),
          for (final type in PrayerType.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kColumnGap),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    SectionLabel.toTurkishUpperCase(
                      PrayerUtils.getPrayerName(type),
                    ),
                    style: AppTypography.gridPrayerName.copyWith(
                      color: tokens.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Günleri satır, vakitleri kolon olarak gösteren takvim tablosu.
///
/// Genişleyen kart listesinin yerini alır: bütün günlerin bütün vakitleri
/// tek bakışta karşılaştırılabilir.
class CalendarTable extends StatelessWidget {
  final List<PrayerTime> days;
  final DateTime now;

  const CalendarTable({super.key, required this.days, required this.now});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CalendarHeaderRow(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: days.length,
            itemExtent: kCalendarRowHeight,
            itemBuilder: (context, index) =>
                _CalendarRow(day: days[index], now: now),
          ),
        ),
      ],
    );
  }
}

class _CalendarRow extends StatelessWidget {
  final PrayerTime day;
  final DateTime now;

  const _CalendarRow({required this.day, required this.now});

  bool get _isToday =>
      day.date.year == now.year &&
      day.date.month == now.month &&
      day.date.day == now.day;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      key: const Key('calendar_row'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _isToday ? tokens.secondarySurface : null,
        border: Border(bottom: BorderSide(color: tokens.divider)),
      ),
      child: Row(
        children: [
          SizedBox(width: _kDayColumnWidth, child: _dayLabel(context)),
          for (final type in PrayerType.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kColumnGap),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    DateFormat(
                      'HH:mm',
                    ).format(PrayerUtils.getPrayerTime(day, type)),
                    style: AppTypography.gridValue.copyWith(
                      color: _isToday ? tokens.textPrimary : tokens.textValue,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayLabel(BuildContext context) {
    final tokens = context.tokens;
    final dayNumber = DateFormat('d MMM', 'tr_TR').format(day.date);
    final weekday = DateFormat('EEEE', 'tr_TR').format(day.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dayNumber,
          style: AppTypography.hint.copyWith(
            color: _isToday ? tokens.accent : tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        if (_isToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'BUGÜN',
              style: AppTypography.sectionLabel.copyWith(
                color: tokens.backgroundStops.last,
                letterSpacing: 0.5,
              ),
            ),
          )
        else
          Text(
            weekday,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.hint.copyWith(color: tokens.textTertiary),
          ),
      ],
    );
  }
}
