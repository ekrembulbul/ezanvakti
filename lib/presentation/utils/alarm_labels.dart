import '../../core/models/alarm.dart';
import '../../core/models/alarm_mission.dart';
import 'prayer_name_helper.dart';

/// "07:30" (sabit) veya "İmsak −30 dk" (çıpalı).
///
/// [formatHourMinute] verilirse sabit saat kullanıcının 12/24 tercihine göre
/// basılır; verilmezse 24 saat (saf çağrılar ve testler için).
String alarmTimeLabel(
  Alarm alarm, {
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
  final name = PrayerNameHelper.getName(alarm.anchor);
  if (alarm.offsetMinutes == 0) return name;
  final sign = alarm.offsetMinutes < 0 ? '−' : '+';
  return '$name $sign${alarm.offsetMinutes.abs()} dk';
}

String alarmSubtitle(Alarm alarm) {
  final parts = <String>[];
  if (alarm.label.isNotEmpty) parts.add(alarm.label);
  parts.add(weekdaysLabel(alarm.weekdays));
  return parts.join(' · ');
}

String weekdaysLabel(Set<int> weekdays) {
  if (weekdays.isEmpty || weekdays.length == 7) return 'Her gün';
  if (weekdays.length == 5 && weekdays.containsAll(const {1, 2, 3, 4, 5})) {
    return 'Hafta içi';
  }
  if (weekdays.length == 2 && weekdays.containsAll(const {6, 7})) {
    return 'Hafta sonu';
  }
  const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  final sorted = weekdays.toList()..sort();
  return sorted.map((d) => names[d - 1]).join(', ');
}

/// Ses seçiminin kullanıcıya görünen hali.
///
/// Yalnızca `custom:` önekli değerler özel sestir; geri kalan her şey
/// (0.5.1 öncesinden kalan 'adhan'/'alarm' dahil) sistem varsayılanıyla
/// çalıyor ve öyle etiketlenir — "Özel ses" diye görünen hayalet seçenek
/// bir etiket hatasıydı.
String soundLabelFor(String soundId, String? customName) {
  if (soundId.startsWith('custom:')) return customName ?? 'Özel ses';
  return 'Varsayılan';
}

/// Görev adının kullanıcıya görünen hali.
String missionLabel(AlarmMission mission) => switch (mission) {
  AlarmMission.none => 'Görev yok',
  AlarmMission.math => 'Matematik',
  AlarmMission.shake => 'Sallama',
  AlarmMission.qr => 'QR okutma',
};
