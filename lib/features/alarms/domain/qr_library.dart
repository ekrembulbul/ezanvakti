import '../../../core/models/alarm.dart';
import '../../../core/models/alarm_mission.dart';

/// Kütüphanedeki bir kodu **görev olarak** kullanan alarmların görünen
/// adları. Silme uyarısı bunları listeler; görevi QR olmayan alarmdaki pasif
/// kopya kullanım sayılmaz.
List<String> alarmsUsingQrPayload(
  List<Alarm> alarms,
  String payload, {
  required String unnamedLabel,
}) {
  final trimmed = payload.trim();
  return [
    for (final alarm in alarms)
      if (alarm.mission == AlarmMission.qr &&
          (alarm.qrPayload ?? '').trim() == trimmed)
        alarm.label.isEmpty ? unnamedLabel : alarm.label,
  ];
}
