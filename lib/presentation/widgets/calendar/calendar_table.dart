import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../l10n/l10n_extensions.dart';
import 'package:intl/intl.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/prayer_utils.dart';

/// İmsakiyeyle aynı kompakt satır yüksekliği; büyük metinde ölçeklenir.
const double kCalendarRowHeight = 56;

/// İmsakiyedeki 1.5:1 tarih/vakit sütunu oranı.
const int _kDayColumnFlex = 3;
const int _kPrayerColumnFlex = 2;
const double _kMinimumTableWidth = 280;

/// Dar sütunlarda saatler küçültülse de komşu değerler arasında boşluk kalır.
const double _kColumnGap = 3;

/// Takvimin sabit başlık satırı: vakit adları.
class CalendarHeaderRow extends StatelessWidget {
  const CalendarHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      constraints: const BoxConstraints(minHeight: kCalendarRowHeight),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.divider)),
      ),
      child: Row(
        children: [
          const Expanded(flex: _kDayColumnFlex, child: SizedBox()),
          for (final type in PrayerType.values)
            Expanded(
              flex: _kPrayerColumnFlex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kColumnGap),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    context.l10n.prayerName(type),
                    style: AppTypography.rowSubtitle.copyWith(
                      color: tokens.textValue,
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
    final fontSize = AppTypography.rowSubtitle.fontSize!;
    final textScale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(fontSize) / fontSize,
    );
    final rowHeight = kCalendarRowHeight * textScale;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(
            _kMinimumTableWidth * textScale,
            constraints.maxWidth,
          ),
          height: constraints.maxHeight,
          child: Column(
            children: [
              SizedBox(height: rowHeight, child: const CalendarHeaderRow()),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: days.length,
                  itemExtent: rowHeight,
                  itemBuilder: (context, index) =>
                      _CalendarRow(day: days[index], now: now),
                ),
              ),
            ],
          ),
        ),
      ),
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
          Expanded(
            flex: _kDayColumnFlex,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kColumnGap),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _dayLabel(context),
              ),
            ),
          ),
          for (final type in PrayerType.values)
            Expanded(
              flex: _kPrayerColumnFlex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kColumnGap),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    DateFormat(
                      'HH:mm',
                    ).format(PrayerUtils.getPrayerTime(day, type)),
                    style:
                        (_isToday
                                ? AppTypography.upcomingRemaining
                                : AppTypography.rowSubtitle)
                            .copyWith(
                              color: _isToday
                                  ? tokens.accent
                                  : tokens.textValue,
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
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dayNumber = DateFormat('d MMM', locale).format(day.date);
    final weekday = DateFormat('EEEE', locale).format(day.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
              context.l10n.today,
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
