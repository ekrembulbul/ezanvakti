import 'package:flutter/material.dart';

import '../../core/models/alarm.dart';
import '../../core/models/alarm_mission.dart';
import '../../core/utils/duration_formatter.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extensions.dart';

/// "07:30" (sabit) veya "İmsak · 30 dk önce" (çıpalı).
///
/// [formatHourMinute] verilmezse saat 24 saatlik biçimde basılır. [l10n]
/// zorunlu: eskiden opsiyoneldi ve null dalı sabit Türkçe üretiyordu.
String alarmTimeLabel(
  Alarm alarm, {
  required AppLocalizations l10n,
  String Function(int hour, int minute)? formatHourMinute,
}) {
  if (alarm.kind == AlarmKind.fixed) {
    if (formatHourMinute != null) {
      return formatHourMinute(alarm.hour, alarm.minute);
    }
    final h = alarm.hour.toString().padLeft(2, '0');
    final m = alarm.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  final name = l10n.prayerName(alarm.anchor);
  if (alarm.offsetMinutes == 0) return name;
  final duration = formatCompactMinutes(alarm.offsetMinutes.abs(), l10n);
  final relative = alarm.offsetMinutes < 0
      ? l10n.reminderBeforeDuration(duration)
      : l10n.reminderAfterDuration(duration);
  return '$name · $relative';
}

String alarmSubtitle(Alarm alarm, AppLocalizations l10n) {
  final parts = <String>[];
  if (alarm.label.isNotEmpty) parts.add(alarm.label);
  parts.add(weekdaysLabel(alarm.weekdays, l10n));
  return parts.join(' · ');
}

/// "Her gün" / "Hafta içi" / "Pzt, Cum" gibi.
String weekdaysLabel(Set<int> weekdays, AppLocalizations l10n) {
  if (weekdays.isEmpty || weekdays.length == 7) return l10n.alarmEveryDay;
  if (weekdays.length == 5 && weekdays.containsAll(const {1, 2, 3, 4, 5})) {
    return l10n.alarmWeekdays;
  }
  if (weekdays.length == 2 && weekdays.containsAll(const {6, 7})) {
    return l10n.alarmWeekend;
  }
  final sorted = weekdays.toList()..sort();
  return sorted.map((day) => l10n.weekdayShort(day)).join(', ');
}

/// Ses seçiminin kullanıcıya görünen hali.
///
/// Yalnızca `custom:` önekli değerler özel sestir; geri kalan her şey
/// (0.5.1 öncesinden kalan 'adhan'/'alarm' dahil) sistem varsayılanıyla
/// çalıyor ve öyle etiketlenir.
String soundLabelFor(
  String soundId,
  String? customName,
  AppLocalizations l10n,
) {
  if (soundId.startsWith('custom:')) {
    return customName ?? l10n.alarmSoundCustom;
  }
  return l10n.alarmSoundDefault;
}

/// Görev adının kullanıcıya görünen hali.
String missionLabel(AlarmMission mission, AppLocalizations l10n) =>
    switch (mission) {
      AlarmMission.none => l10n.missionNone,
      AlarmMission.math => l10n.missionMath,
      AlarmMission.shake => l10n.missionShake,
      AlarmMission.qr => l10n.missionQr,
    };

/// Matematik zorluğunun adı. Seviye `1..4`'e kırpılır (bkz. `MathChallenge`).
String missionLevelLabel(int level, AppLocalizations l10n) =>
    switch (level.clamp(1, 4)) {
      1 => l10n.missionLevelEasy,
      2 => l10n.missionLevelMedium,
      3 => l10n.missionLevelHard,
      _ => l10n.missionLevelExtreme,
    };

/// Seçici satırındaki açıklama: soru sayısı ve işlem türü.
String missionLevelHint(int level, AppLocalizations l10n) =>
    switch (level.clamp(1, 4)) {
      1 => l10n.missionLevelEasyHint,
      2 => l10n.missionLevelMediumHint,
      3 => l10n.missionLevelHardHint,
      _ => l10n.missionLevelExtremeHint,
    };

IconData? missionIcon(AlarmMission mission) => switch (mission) {
  AlarmMission.none => null,
  AlarmMission.math => Icons.calculate_rounded,
  AlarmMission.shake => Icons.vibration_rounded,
  AlarmMission.qr => Icons.qr_code_scanner_rounded,
};
