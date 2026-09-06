import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/notification_setting.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extensions.dart';

String notificationTitle(NotificationSetting setting, AppLocalizations l10n) {
  final label = setting.label?.trim();
  if (label != null && label.isNotEmpty) return label;
  final derived = setting.derivedKind;
  return derived == null
      ? l10n.prayerName(setting.prayerType)
      : l10n.derivedName(derived);
}

String notificationRuleLabel(
  NotificationSetting setting,
  AppLocalizations l10n,
) {
  final offset = setting.minutesBefore == 0
      ? l10n.reminderOnTime
      : l10n.reminderMinutesBefore(setting.minutesBefore);
  if (setting.label?.trim().isNotEmpty != true) return offset;
  final derived = setting.derivedKind;
  final point = derived == null
      ? l10n.prayerName(setting.prayerType)
      : l10n.derivedName(derived);
  return '$point · $offset';
}

String reminderDayLabel(BuildContext context, DateTime time, DateTime now) {
  // Takvim günleri arasındaki fark DST gününde 23/25 saatten etkilenmez.
  final today = DateTime.utc(now.year, now.month, now.day);
  final target = DateTime.utc(time.year, time.month, time.day);
  final days = target.difference(today).inDays;
  if (days == 0) return context.l10n.upcomingToday;
  if (days == 1) return context.l10n.upcomingTomorrow;
  return DateFormat(
    days >= 7 || days < 0 ? 'd MMM' : 'EEEE',
    Localizations.localeOf(context).toLanguageTag(),
  ).format(time);
}

String reminderRemaining(Duration remaining, AppLocalizations l10n) {
  if (remaining.inMinutes < 1) return l10n.countdownLessThanMinute;
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  return hours == 0
      ? l10n.countdownMinutesShort(minutes)
      : l10n.countdownHourMinuteShort(hours, minutes);
}
