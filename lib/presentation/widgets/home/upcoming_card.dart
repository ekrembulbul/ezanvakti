import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/alarm.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/prayer_utils.dart';
import '../../screens/alarms_screen.dart' show alarmTimeLabel;
import '../../services/upcoming_resolver.dart';
import '../common/grouped_list.dart';
import '../common/section_label.dart';

/// Kart satırının yüksekliği (spec §6.1/7). Boş durum kutusuyla aynı olsun
/// diye ayrı sabit: veri gelince kartın boyu zıplamıyor.
const double _kRowHeight = 62;

/// Sıradaki bildirim ve alarmı gösteren grup.
///
/// En fazla iki satır (spec §6.1/7): "sırada ne var" sorusu tek bakışta
/// cevaplanır, tamamı "Tümü" ile açılır.
class UpcomingCard extends StatelessWidget {
  final UpcomingNotification? notification;
  final UpcomingAlarm? alarm;

  /// Kalan sürenin hesaplandığı an. Ana ekran saniyede bir yeniden çizildiği
  /// için dışarıdan verilir; widget kendi saatini tutmaz.
  final DateTime now;

  final VoidCallback onSeeAll;
  final void Function(Alarm alarm, bool isActive)? onAlarmToggled;

  const UpcomingCard({
    super.key,
    required this.now,
    required this.onSeeAll,
    this.notification,
    this.alarm,
    this.onAlarmToggled,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(
          'Sıradaki',
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSeeAll,
            child: Text(
              'Tümü',
              style: AppTypography.hint.copyWith(
                color: tokens.accent,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (notification == null && alarm == null)
          _emptyState(tokens)
        else
          GroupedList(
            children: [
              if (notification != null) _notificationRow(context),
              if (alarm != null) _alarmRow(context),
            ],
          ),
      ],
    );
  }

  Widget _emptyState(AppTokens tokens) {
    return Container(
      height: _kRowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        'Yaklaşan bildirim veya alarm yok',
        style: AppTypography.rowSubtitle.copyWith(color: tokens.textTertiary),
      ),
    );
  }

  Widget _notificationRow(BuildContext context) {
    final tokens = context.tokens;
    final item = notification!;
    final prayerName = PrayerUtils.getPrayerName(item.setting.prayerType);
    final offset = item.setting.minutesBefore == 0
        ? 'Tam vaktinde'
        : '${item.setting.minutesBefore} dk önce';

    return GroupedRow(
      height: _kRowHeight,
      icon: Icons.notifications_rounded,
      title: Text(
        '$prayerName bildirimi',
        style: AppTypography.upcomingRowTitle,
      ),
      subtitle: Text('$offset · ${_clock(item.time)}'),
      trailing: Text(
        formatRemaining(item.time.difference(now)),
        style: AppTypography.upcomingRemaining.copyWith(
          color: tokens.textValue,
        ),
      ),
    );
  }

  Widget _alarmRow(BuildContext context) {
    final tokens = context.tokens;
    final item = alarm!;
    final label = alarmTimeLabel(item.alarm);
    final title = item.alarm.label.isNotEmpty ? item.alarm.label : label;

    return GroupedRow(
      height: _kRowHeight,
      icon: Icons.alarm_rounded,
      iconColor: tokens.accent,
      title: Text(title, style: AppTypography.upcomingRowTitle),
      subtitle: Text(
        '$label · ${_relativeDay(item.time)} ${_clock(item.time)}',
      ),
      trailing: Switch(
        value: item.alarm.isActive,
        onChanged: onAlarmToggled == null
            ? null
            : (value) => onAlarmToggled!(item.alarm, value),
      ),
    );
  }

  String _clock(DateTime time) => DateFormat('HH:mm').format(time);

  /// "bugün" / "yarın" / "Pazartesi".
  String _relativeDay(DateTime time) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(time.year, time.month, time.day);
    final days = target.difference(today).inDays;

    if (days == 0) return 'bugün';
    if (days == 1) return 'yarın';
    return DateFormat('EEEE', 'tr_TR').format(time);
  }
}

/// Kalan süreyi tasarımın kısa biçimiyle yazar: "2s 43dk", "43dk", "<1dk".
String formatRemaining(Duration remaining) {
  if (remaining.inMinutes < 1) return '<1dk';

  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  if (hours == 0) return '${minutes}dk';
  return '${hours}s ${minutes}dk';
}
