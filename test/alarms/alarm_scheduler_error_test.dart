import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/fasting_log.dart';
import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/core/models/prayer_log.dart';
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/core/models/mission_stop_event.dart';
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_theme.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Belirli bir id'de patlayan, digerlerinde basarili olan servis.
class _FlakyAlarmService implements AlarmService {
  final List<String> scheduled = [];
  int cancelAllCount = 0;
  String? failingId = 'patlayan';

  @override
  Future<void> cancelAllAlarms() async => cancelAllCount++;

  @override
  Future<void> scheduleAlarm({
    required String id,
    required DateTime scheduledTime,
    required String label,
    required String soundId,
    required bool vibrate,
    required bool snoozeEnabled,
    required int snoozeMinutes,
    required AlarmTheme theme,
    required AlarmMission mission,
    required int missionLevel,
    required Map<String, dynamic> chainConfig,
    List<int> repeatWeekdays = const [],
  }) async {
    if (id == failingId) {
      throw PlatformException(code: 'schedule_failed', message: 'izin yok');
    }
    scheduled.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<MissionStopEvent> get missionStops => const Stream.empty();

  @override
  Future<List<MissionStopEvent>> consumeMissionEvents() async => const [];

  @override
  Future<void> beginMission(String alarmId) async {}

  @override
  Future<void> snoozeMission(String alarmId, int minutes) async {}

  @override
  Future<void> completeMission(String alarmId) async {}

  @override
  Future<void> abortMission(String alarmId) async {}
}

class _StorageWithAlarms implements LocalStorage {

  final Map<String, String> _rawSettings = {};

  @override
  Future<String?> getSetting(String key) async => _rawSettings[key];

  @override
  Future<void> setSetting(String key, String value) async =>
      _rawSettings[key] = value;

  final Map<String, FastingStatus> _fastingLog = {};
  int _fastingQada = 0;

  @override
  Future<Map<String, FastingStatus>> getFastingLog(
    DateTime from,
    DateTime to,
  ) async => Map.of(_fastingLog);

  @override
  Future<void> setFastingLog(DateTime date, FastingStatus? status) async {
    final key = fastingLogKey(date);
    if (status == null) {
      _fastingLog.remove(key);
    } else {
      _fastingLog[key] = status;
    }
  }

  @override
  Future<int> getFastingQadaCount() async => _fastingQada;

  @override
  Future<void> setFastingQadaCount(int count) async => _fastingQada = count;

  final Map<String, PrayerStatus> _prayerLog = {};
  final Map<PrayerType, int> _qadaCounts = {};
  final Map<String, int> _dhikrLog = {};

  @override
  Future<Map<String, PrayerStatus>> getPrayerLog(
    DateTime from,
    DateTime to,
  ) async => Map.of(_prayerLog);

  @override
  Future<void> setPrayerLog(
    DateTime date,
    PrayerType prayerType,
    PrayerStatus? status,
  ) async {
    final key = prayerLogKey(date, prayerType);
    if (status == null) {
      _prayerLog.remove(key);
    } else {
      _prayerLog[key] = status;
    }
  }

  @override
  Future<Map<PrayerType, int>> getQadaCounts() async => Map.of(_qadaCounts);

  @override
  Future<void> setQadaCount(PrayerType prayerType, int count) async =>
      _qadaCounts[prayerType] = clampQadaCount(count);

  @override
  Future<int> getDhikrCount(DateTime date) async =>
      _dhikrLog['${date.year}-${date.month}-${date.day}'] ?? 0;

  @override
  Future<void> setDhikrCount(DateTime date, int count) async =>
      _dhikrLog['${date.year}-${date.month}-${date.day}'] = count;

  List<QuietWindow> _quietWindows = [];

  @override
  Future<List<QuietWindow>> getQuietWindows() async => _quietWindows;

  @override
  Future<void> saveQuietWindows(List<QuietWindow> windows) async =>
      _quietWindows = windows;
  final List<Alarm> alarms;

  _StorageWithAlarms(this.alarms);

  Map<String, String> failures = {};

  @override
  Future<List<Alarm>> getAlarms() async => alarms;

  @override
  Future<Map<String, String>> getAlarmScheduleFailures() async => failures;

  @override
  Future<void> saveAlarmScheduleFailures(Map<String, String> value) async =>
      failures = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Alarm fixed(String id, int hour) =>
      Alarm(id: id, kind: AlarmKind.fixed, hour: hour, minute: 0);

  test('Bir alarm planlanamazsa digerleri planlanmaya devam eder', () async {
    final service = _FlakyAlarmService();
    final scheduler = AlarmScheduler(
      alarmService: service,
      storage: _StorageWithAlarms([fixed('patlayan', 6), fixed('saglam', 7)]),
    );

    // Yakalanmamis istisna firlatmamali.
    await scheduler.scheduleAlarms(prayerTimes: const []);

    expect(service.scheduled, ['saglam']);
  });

  test('Planlanamayan alarm kalici kayda dusuyor, duzelince temizleniyor', () async {
    final service = _FlakyAlarmService();
    final storage = _StorageWithAlarms([fixed('patlayan', 6), fixed('saglam', 7)]);
    final scheduler = AlarmScheduler(alarmService: service, storage: storage);

    await scheduler.scheduleAlarms(prayerTimes: const []);
    expect(storage.failures.keys.toList(), ['patlayan']);

    // Sonraki planlamada hata kalmadiysa kayit da kalmamali.
    service.failingId = null;
    await scheduler.scheduleAlarms(prayerTimes: const []);
    expect(storage.failures, isEmpty);
  });

  test('Alarm listesi bos olsa da mevcut planlar temizlenir', () async {
    final service = _FlakyAlarmService();
    final scheduler = AlarmScheduler(
      alarmService: service,
      storage: _StorageWithAlarms([]),
    );

    await scheduler.scheduleAlarms(prayerTimes: const []);

    expect(service.cancelAllCount, 1);
  });

  test('Pasif alarmlar planlanmaz', () async {
    final service = _FlakyAlarmService();
    final scheduler = AlarmScheduler(
      alarmService: service,
      storage: _StorageWithAlarms([
        const Alarm(
          id: 'pasif',
          kind: AlarmKind.fixed,
          hour: 6,
          isActive: false,
        ),
        fixed('aktif', 7),
      ]),
    );

    await scheduler.scheduleAlarms(prayerTimes: const []);

    expect(service.scheduled, ['aktif']);
  });
}
