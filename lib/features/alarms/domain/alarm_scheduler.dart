import '../../../core/config/mission_tuning.dart';
import '../../../core/interfaces/alarm_service.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/alarm.dart';
import '../../../core/models/alarm_plan.dart';
import '../../../core/models/alarm_mission.dart';
import '../../../core/models/alarm_theme.dart';
import '../../../core/models/notification_setting.dart' show PrayerType;
import '../../../core/models/prayer_time.dart';
import '../../../core/models/skipped_occurrence.dart';
import '../../../core/theme/day_phase.dart';
import '../../notifications/domain/skip_rules.dart';
import 'mission_chain.dart';
import 'snooze_options.dart';
import '../../../core/utils/app_logger.dart';

/// Alarmların bir sonraki tetiklenme anını hesaplar ve native [AlarmService] ile
/// planlar. Sabit alarmlar native haftalık tekrar, vakte bağlı alarmlar
/// tarihli kayıtlarla kurulur. Yenileme mevcut planla uzlaştırılır.
class AlarmScheduler {
  static const _searchDays = 64;
  final AlarmService alarmService;
  final LocalStorage storage;

  /// Çalar ekranın paleti için kullanıcının güncel görünüm tercihleri.
  /// Planlama anında okunur; tema denetleyicisine doğrudan bağımlılık yok.
  final AlarmAppearance Function() appearance;

  final AppLogger _logger;

  /// Planın "şimdi"si. Testler sabitler: gün-sonu eşiği (isha sonrası) gerçek
  /// saate göre değişince aynı test gündüz geçip gece düşüyordu.
  final DateTime Function() _clock;
  Future<void>? _scheduleQueue;

  AlarmScheduler({
    required this.alarmService,
    required this.storage,
    AlarmAppearance Function()? appearance,
    AppLogger? logger,
    DateTime Function()? clock,
  }) : appearance = appearance ?? (() => AlarmAppearance.fallback),
       _logger = logger ?? AppLogger(),
       _clock = clock ?? DateTime.now;

  /// Serializes plan updates and definition changes against the same storage.
  Future<T> _serial<T>(Future<T> Function() operation) {
    final previous = _scheduleQueue;
    final result = previous == null
        ? Future<T>.sync(operation)
        : previous.then((_) => operation());
    _scheduleQueue = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  Future<void> saveDefinition(Alarm alarm) => _serial(() async {
    await storage.saveAlarm(alarm);
    if (!alarm.isActive) await _cancelRoot(alarm.id);
  });

  Future<void> deleteDefinition(String id) => _serial(() async {
    await storage.deleteAlarm(id);
    await _cancelRoot(id);
  });

  Future<void> _cancelRoot(String id) async {
    try {
      await alarmService.cancelAlarm(id);
    } catch (error) {
      final failures = <String, String>{id: 'cancel_failed'};
      try {
        failures.addAll(await storage.getAlarmScheduleFailures());
      } catch (storageError) {
        _logger.warning(
          'Alarm status could not be read',
          storageError.runtimeType,
        );
      }
      failures[id] = 'cancel_failed';
      await _saveFailures(failures);
      rethrow;
    }
    try {
      final failures = Map<String, String>.of(
        await storage.getAlarmScheduleFailures(),
      );
      failures.remove(id);
      await _saveFailures(failures);
    } catch (error) {
      _logger.warning(
        'Alarm status could not be read after cancellation',
        error.runtimeType,
      );
    }
  }

  /// Native reconciliation preserves unchanged records and active missions.
  Future<void> scheduleAlarms({
    required List<PrayerTime> prayerTimes,
    Set<SkippedOccurrence> skips = const {},
  }) {
    final times = List<PrayerTime>.unmodifiable(prayerTimes);
    final skipped = Set<SkippedOccurrence>.unmodifiable(skips);
    return _serial(() => _scheduleAlarms(prayerTimes: times, skips: skipped));
  }

  Future<void> _scheduleAlarms({
    required List<PrayerTime> prayerTimes,
    required Set<SkippedOccurrence> skips,
  }) async {
    // AlarmKit olmayan cihazda (iOS < 26.1) köprü çağrılmaz: her açılışta
    // hata üretip alarmları "planlanamadı" diye damgalıyordu. Eski damgalar
    // da temizlenir; tanımlar dokunulmadan kalır, cihaz güncellenince kurulur.
    if (!await alarmService.isSupported()) {
      await _saveFailures(const {});
      return;
    }
    final alarms = await storage.getAlarms();
    final byDate = {for (final pt in prayerTimes) _dateKey(pt.date): pt};
    final now = _clock();
    final currentAppearance = appearance();
    final records = <AlarmPlanEntry>[];
    final enabled = <String>{};
    final preserved = <String>{};
    final preservedPeriods = <AlarmPreservedPeriod>[];
    for (final alarm in alarms.where((alarm) => alarm.isActive)) {
      enabled.add(alarm.id);
      if (alarm.kind == AlarmKind.anchored) {
        preservedPeriods.addAll(_missingPrayerPeriods(alarm, byDate, now));
      }
      final repeatDays = alarm.kind == AlarmKind.fixed
          ? _relativeWeekdaysFor(alarm, skips: skips)
          : const <int>[];
      final fires = computeNextFires(
        alarm: alarm,
        now: now,
        prayerTimesByDate: byDate,
        skips: skips,
        limit: alarm.kind == AlarmKind.anchored || repeatDays.isEmpty ? 7 : 1,
      );
      if (fires.isEmpty) {
        if (alarm.kind == AlarmKind.anchored) preserved.add(alarm.id);
        continue;
      }
      for (final (index, fire) in fires.indexed) {
        records.add(
          AlarmPlanEntry(
            id: repeatDays.isEmpty
                ? '${alarm.id}#at${fire.millisecondsSinceEpoch}'
                : alarm.id,
            alarm: alarm,
            scheduledTime: fire,
            theme: themeForFire(fire, byDate, currentAppearance),
            repeatWeekdays: repeatDays,
            isFirstOccurrence: index == 0,
            chainConfig: _chainConfig(alarm, fire, includeLadder: index == 0),
          ),
        );
      }
    }
    records.sort((left, right) {
      if (left.isFirstOccurrence != right.isFirstOccurrence) {
        return left.isFirstOccurrence ? -1 : 1;
      }
      final time = left.scheduledTime.compareTo(right.scheduledTime);
      return time != 0 ? time : left.id.compareTo(right.id);
    });
    try {
      final failures = await alarmService.reconcileAlarms(
        AlarmPlan(
          records: records,
          enabledAlarmIds: enabled,
          preserveAlarmIds: preserved,
          preservedPeriods: preservedPeriods,
          skippedOccurrences: skips
              .where(
                (skip) =>
                    skip.kind == SkipKind.alarm &&
                    enabled.contains(skip.reference),
              )
              .toSet(),
        ),
      );
      await _saveFailures(failures);
    } catch (error) {
      await _saveFailures({
        for (final alarm in alarms) alarm.id: 'reconcile_failed',
        if (alarms.isEmpty) '_plan': 'reconcile_failed',
      });
      rethrow;
    }
  }

  Future<void> _saveFailures(Map<String, String> failures) async {
    try {
      await storage.saveAlarmScheduleFailures(failures);
    } catch (error) {
      _logger.warning('Alarm status could not be saved', error.runtimeType);
    }
  }

  List<AlarmPreservedPeriod> _missingPrayerPeriods(
    Alarm alarm,
    Map<DateTime, PrayerTime> available,
    DateTime now,
  ) {
    final periods = <AlarmPreservedPeriod>[];
    final offset = Duration(minutes: alarm.offsetMinutes);
    for (var i = 0; i < _searchDays; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      if (!alarm.firesOnWeekday(day.weekday) || available.containsKey(day)) {
        continue;
      }
      final from = day.add(offset);
      final until = DateTime(day.year, day.month, day.day + 1).add(offset);
      if (!until.isAfter(now)) continue;
      final previous = periods.lastOrNull;
      if (previous?.until == from) {
        periods[periods.length - 1] = AlarmPreservedPeriod(
          alarmId: alarm.id,
          from: previous!.from,
          until: until,
        );
      } else {
        periods.add(
          AlarmPreservedPeriod(alarmId: alarm.id, from: from, until: until),
        );
      }
    }
    return periods;
  }

  Map<String, dynamic> _chainConfig(
    Alarm alarm,
    DateTime fire, {
    bool includeLadder = true,
  }) => {
    'alarmId': alarm.id,
    'fireAtMillis': fire.millisecondsSinceEpoch,
    if (alarm.kind == AlarmKind.fixed) 'repeatHour': alarm.hour,
    if (alarm.kind == AlarmKind.fixed) 'repeatMinute': alarm.minute,
    if (alarm.kind == AlarmKind.fixed)
      'templateWeekdays':
          (alarm.weekdays.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : alarm.weekdays)
              .toList()
            ..sort(),
    'graceSeconds': MissionTuning.graceSeconds,
    'maxRearms': MissionTuning.maxRearms,
    'maxSnoozes': effectiveSnoozeLimit(alarm),
    'chainDurationMillis': const Duration(
      minutes: MissionTuning.chainDeadlineMinutes,
    ).inMilliseconds,
    'chainDeadlineMillis': MissionChain.chainDeadline(
      fire,
    ).millisecondsSinceEpoch,
    'missionTimeoutSeconds': MissionTuning.timeoutSecondsFor(alarm.mission),
    'ladderMillis': includeLadder && alarm.mission.requiresGate
        ? [for (final t in MissionChain.ladder(fire)) t.millisecondsSinceEpoch]
        : <int>[],
  };

  /// Çalar ekranın paleti.
  ///
  /// Kullanıcının tema seçimi (koyu/açık/sistem) ve sabit palet tercihi
  /// [appearance] ile gelir. "Vakte göre renk" açıksa dilimi alarmın
  /// **çalacağı** an belirler, planlama anı değil: sabah 05:00'te çalan alarm
  /// ÇİVİT, yatsıdan sonra çalan SÜMBÜL ile açılır. O günün vakitleri elde
  /// yoksa fallback dilime düşer.
  static AlarmTheme themeForFire(
    DateTime fire,
    Map<DateTime, PrayerTime> prayerTimesByDate,
    AlarmAppearance appearance,
  ) {
    final day = _dateKey(fire);
    return AlarmTheme.resolve(
      appearance: appearance,
      phaseAtFire: resolveDayPhase(
        today: prayerTimesByDate[day],
        tomorrow: prayerTimesByDate[DateTime(day.year, day.month, day.day + 1)],
        now: fire,
      ),
    );
  }

  /// iOS cannot suppress a single delivery of a weekly OS record. While a
  /// skip is pending it uses dated records and restores the weekly template
  /// after the next stop. Android keeps the template and filters its receiver.
  static List<int> _relativeWeekdaysFor(
    Alarm alarm, {
    required Set<SkippedOccurrence> skips,
  }) {
    if (alarm.kind != AlarmKind.fixed ||
        skips.any(
          (skip) => skip.kind == SkipKind.alarm && skip.reference == alarm.id,
        )) {
      return const [];
    }
    final days = alarm.weekdays.isEmpty
        ? const {1, 2, 3, 4, 5, 6, 7}
        : alarm.weekdays;
    return days.toList()..sort();
  }

  /// [now]'dan sonraki ilk geçerli tetiklenme anını döner; [searchDays] gün
  /// içinde uygun gün/vakit bulunamazsa null. Çıpalı alarmlar için ilgili günün
  /// vakti [prayerTimesByDate]'te yoksa o gün atlanır.
  static DateTime? computeNextFire({
    required Alarm alarm,
    required DateTime now,
    required Map<DateTime, PrayerTime> prayerTimesByDate,
    int searchDays = _searchDays,
    Set<SkippedOccurrence> skips = const {},
  }) {
    final fires = computeNextFires(
      alarm: alarm,
      now: now,
      prayerTimesByDate: prayerTimesByDate,
      searchDays: searchDays,
      limit: 1,
      skips: skips,
    );
    return fires.isEmpty ? null : fires.first;
  }

  /// [computeNextFire]'ın dizi hali: sıradaki en fazla [limit] geçerli
  /// tetiklenme anı. Çıpalı ön dizim (F1b) bunun üzerine kurulu.
  static List<DateTime> computeNextFires({
    required Alarm alarm,
    required DateTime now,
    required Map<DateTime, PrayerTime> prayerTimesByDate,
    int searchDays = _searchDays,
    int limit = 7,
    Set<SkippedOccurrence> skips = const {},
  }) {
    final fires = <DateTime>[];
    final today = _dateKey(now);
    for (var i = 0; i < searchDays && fires.length < limit; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      if (!alarm.firesOnWeekday(day.weekday)) continue;

      DateTime? candidate;
      if (alarm.kind == AlarmKind.fixed) {
        candidate = DateTime(
          day.year,
          day.month,
          day.day,
          alarm.hour,
          alarm.minute,
        );
      } else {
        final pt = prayerTimesByDate[day];
        if (pt == null) continue;
        candidate = _anchorTime(
          pt,
          alarm.anchor,
        ).add(Duration(minutes: alarm.offsetMinutes));
      }

      if (!candidate.isAfter(now)) continue;

      // "Yalnızca bu sefer" atlanan çalma anı geçilir; alarm bir sonraki
      // uygun günde normal çalar.
      final skipped = isSkipped(
        skips,
        kind: SkipKind.alarm,
        reference: alarm.id,
        fireAt: candidate,
      );
      if (skipped) continue;

      fires.add(candidate);
    }
    return fires;
  }

  static DateTime _anchorTime(PrayerTime pt, PrayerType anchor) {
    switch (anchor) {
      case PrayerType.fajr:
        return pt.fajr;
      case PrayerType.sunrise:
        return pt.sunrise;
      case PrayerType.dhuhr:
        return pt.dhuhr;
      case PrayerType.asr:
        return pt.asr;
      case PrayerType.maghrib:
        return pt.maghrib;
      case PrayerType.isha:
        return pt.isha;
    }
  }

  static DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
