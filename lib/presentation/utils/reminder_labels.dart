import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/notification_setting.dart';
import '../../core/utils/duration_formatter.dart';
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
  final derived = setting.derivedKind;
  final point = derived == null
      ? l10n.prayerName(setting.prayerType)
      : l10n.derivedName(derived);
  final offset = setting.minutesBefore == 0
      ? l10n.reminderOnTime
      : l10n.reminderBeforeDuration(
          formatCompactMinutes(setting.minutesBefore, l10n),
        );
  return '$point · $offset';
}

String? notificationCustomLabel(NotificationSetting setting) {
  final label = setting.label?.trim();
  return label == null || label.isEmpty ? null : label;
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
  return formatCompactDuration(remaining, l10n);
}
