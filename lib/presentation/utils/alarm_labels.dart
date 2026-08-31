import '../../core/models/alarm.dart';
import '../../core/models/alarm_mission.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extensions.dart';

/// "07:30" (sabit) veya "İmsak −30 dk" (çıpalı).
///
/// [l10n] verilmezse saat 24 saatlik biçimde basılır ve çıpalı alarmda vakit
/// adı yerine tipin kendi adı kullanılır — yalnızca saf çağrılar ve testler
/// için; arayüz her zaman çeviriyi geçer.
String alarmTimeLabel(
  Alarm alarm, {
  AppLocalizations? l10n,
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
  final name = l10n?.prayerName(alarm.anchor) ?? alarm.anchor.name;
  if (alarm.offsetMinutes == 0) return name;
  final sign = alarm.offsetMinutes < 0 ? '−' : '+';
  final minutes = l10n == null
      ? '${alarm.offsetMinutes.abs()} dk'
      : l10n.minutesShort(alarm.offsetMinutes.abs());
  return '$name $sign$minutes';
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
