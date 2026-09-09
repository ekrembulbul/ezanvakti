import 'alarm.dart';
import 'alarm_mission.dart';
import 'alarm_theme.dart';
import 'skipped_occurrence.dart';

/// Delivery interval belonging to an unavailable prayer source day.
class AlarmPreservedPeriod {
  final String alarmId;
  final DateTime from;
  final DateTime until;
  const AlarmPreservedPeriod({
    required this.alarmId,
    required this.from,
    required this.until,
  });
  Map<String, dynamic> toMap() => {
    'alarmId': alarmId,
    'fromMillis': from.millisecondsSinceEpoch,
    'untilMillis': until.millisecondsSinceEpoch,
  };
}

/// A primary native schedule. Its optional fallbacks belong to this occurrence.
class AlarmPlanEntry {
  final String id;
  final Alarm alarm;
  final DateTime scheduledTime;
  final AlarmTheme theme;
  final List<int> repeatWeekdays;
  final Map<String, dynamic> chainConfig;
  final bool isFirstOccurrence;

  AlarmPlanEntry({
    required this.id,
    required this.alarm,
    required this.scheduledTime,
    required this.theme,
    required Map<String, dynamic> chainConfig,
    List<int> repeatWeekdays = const [],
    this.isFirstOccurrence = true,
  }) : repeatWeekdays = List.unmodifiable(repeatWeekdays),
       chainConfig = Map.unmodifiable(chainConfig);

  Map<String, dynamic> toMap() => {
    'id': id,
    'timeMillis': scheduledTime.millisecondsSinceEpoch,
    'label': alarm.label,
    'soundId': alarm.soundId,
    'vibrate': alarm.vibrate,
    // Yalnızca Android okur; iOS'ta alarm AlarmKit'in elinde ve ses
    // seviyesine erişim yok (bkz. docs/adr/0003).
    'fadeIn': alarm.fadeIn,
    'snoozeEnabled': alarm.snoozeEnabled,
    'snoozeMinutes': alarm.snoozeMinutes,
    'theme': theme.toMap(),
    'mission': alarm.mission.name,
    'missionLevel': alarm.missionLevel,
    'missionEnabled': alarm.mission.requiresGate,
    'repeatWeekdays': repeatWeekdays,
    'chainConfig': {
      ...chainConfig,
      'alarmId': alarm.id,
      'fireAtMillis': scheduledTime.millisecondsSinceEpoch,
    },
  };
}

/// Complete desired plan; missing prayer data preserves only named active roots.
class AlarmPlan {
  final List<AlarmPlanEntry> records;
  final Set<String> enabledAlarmIds;
  final Set<String> preserveAlarmIds;
  final Set<SkippedOccurrence> skippedOccurrences;
  final List<AlarmPreservedPeriod> preservedPeriods;

  AlarmPlan({
    required List<AlarmPlanEntry> records,
    required Set<String> enabledAlarmIds,
    Set<String> preserveAlarmIds = const {},
    Set<SkippedOccurrence> skippedOccurrences = const {},
    List<AlarmPreservedPeriod> preservedPeriods = const [],
  }) : records = List.unmodifiable(records),
       enabledAlarmIds = Set.unmodifiable(enabledAlarmIds),
       preserveAlarmIds = Set.unmodifiable(preserveAlarmIds),
       skippedOccurrences = Set.unmodifiable(skippedOccurrences),
       preservedPeriods = List.unmodifiable(preservedPeriods);

  Map<String, dynamic> toMap() => {
    'protocolVersion': 2,
    'records': [for (final record in records) record.toMap()],
    'enabledAlarmIds': enabledAlarmIds.toList()..sort(),
    'preserveAlarmIds': preserveAlarmIds.toList()..sort(),
    'preservedPeriods': [for (final period in preservedPeriods) period.toMap()],
    'skippedOccurrences': [
      for (final skip in skippedOccurrences)
        {
          'alarmId': skip.reference,
          'fireAtMillis': skip.fireAt.millisecondsSinceEpoch,
        },
    ],
  };
}
