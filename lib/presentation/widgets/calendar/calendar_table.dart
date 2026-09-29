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

/// Listenin altındaki boşluk. Başlangıç konumu içerik sonuna göre
/// kısıtlanırken de aynı değer hesaba katılır.
const double _kListBottomPadding = 24;

/// Bugünden önceki günler, hangi ay açık olursa olsun, soluk çizilir.
const double _kPastDayOpacity = 0.5;

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
/// tek bakışta karşılaştırılabilir. Bugünü içeren ayda liste, bugünün bir
/// üst satırı en üstte olacak konumda açılır; başka ayda en üstten başlar.
/// Ekran tabloyu gösterdiği ayla anahtarlar: ay değişince yeni durum kurulur
/// ve başlangıç konumu yeniden hesaplanır.
class CalendarTable extends StatefulWidget {
  final List<PrayerTime> days;
  final DateTime now;

  const CalendarTable({super.key, required this.days, required this.now});

  /// Listenin ilk kaydırma konumu. Bugün listede değilse ya da ilk günse
  /// sıfır. İçerik sonuna göre kısıtlanır: ayın son günlerinde istenen konum
  /// kaydırılabilir alanı aşar; aşan konum açılışta geri yaylanan bir kayma
  /// olarak görünürdü (iOS'ta belirgin).
  static double initialScrollOffset({
    required List<PrayerTime> days,
    required DateTime now,
    required double rowHeight,
    required double viewportHeight,
  }) {
    final todayIndex = days.indexWhere(
      (day) => DateUtils.isSameDay(day.date, now),
    );
    if (todayIndex <= 0) return 0;
    final contentHeight = days.length * rowHeight + _kListBottomPadding;
    final maxOffset = math.max(0.0, contentHeight - viewportHeight);
    return math.min((todayIndex - 1) * rowHeight, maxOffset);
  }

  @override
  State<CalendarTable> createState() => _CalendarTableState();
}

class _CalendarTableState extends State<CalendarTable> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = AppTypography.rowSubtitle.fontSize!;
    final textScale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(fontSize) / fontSize,
    );
    final rowHeight = kCalendarRowHeight * textScale;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Konum yalnız ilk yerleşimde hesaplanır ve animasyonsuz verilir;
        // sonraki yerleşimler kullanıcının kaydırdığı yere dokunmaz.
        // keepScrollOffset kapalı: rotanın PageStorage'ı eski bir konumla
        // başlangıç konumunu ezmesin.
        _scroll ??= ScrollController(
          initialScrollOffset: CalendarTable.initialScrollOffset(
            days: widget.days,
            now: widget.now,
            rowHeight: rowHeight,
            viewportHeight: constraints.maxHeight - rowHeight,
          ),
          keepScrollOffset: false,
        );
        return SingleChildScrollView(
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
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: _kListBottomPadding),
                    itemCount: widget.days.length,
                    itemExtent: rowHeight,
                    itemBuilder: (context, index) => CalendarDayRow(
                      day: widget.days[index],
                      now: widget.now,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Takvimin bir gün satırı. Ekrandaki tablo ve ay paylaşım görüntüsü aynı
/// satırı kullanır; paylaşılan tablo ekrandakiyle aynı görünür.
class CalendarDayRow extends StatelessWidget {
  final PrayerTime day;

  /// Bugün vurgusu ve geçmiş günlerin soluklaştırılması bu ana göre yapılır.
  /// Paylaşım görüntüsünde `null`: satırlar vurgusuz ve tam opak çizilir.
  final DateTime? now;

  const CalendarDayRow({super.key, required this.day, this.now});

  bool get _isToday {
    final now = this.now;
    return now != null && DateUtils.isSameDay(day.date, now);
  }

  bool get _isPast {
    final now = this.now;
    return now != null &&
        DateUtils.dateOnly(day.date).isBefore(DateUtils.dateOnly(now));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Opacity(
      key: const Key('calendar_row'),
      opacity: _isPast ? _kPastDayOpacity : 1,
      child: Container(
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
