import 'dart:async';

import '../../../core/config/mission_tuning.dart';
import '../../../core/interfaces/alarm_service.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/alarm.dart';
import '../../../core/models/alarm_plan.dart';
import '../../../core/models/general_settings.dart';
import '../../../core/models/alarm_mission.dart';
import '../../../core/models/alarm_theme.dart';
import '../../../core/models/mission_session.dart';
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
///
/// Tek seferlik alarm yalnız hedef gününde tek tarihli kayıtla kurulur; çalıp
/// zincir süresi geçince burada kapatılır (docs/adr/0007).
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

  final _onceAlarmsChanged = StreamController<Set<String>>.broadcast();

  /// Planlama sırasında planlayıcının kendisi değiştirdiği tek seferlik
  /// alarmların kimlikleri: çalışı biten kapatıldı ya da boş hedef günü
  /// onarıldı. Liste depodan yeniden okunmazsa satır eski hâlini gösterirdi;
  /// arayüz bu olayla alarmları tazeler.
  Stream<Set<String>> get onceAlarmsChanged => _onceAlarmsChanged.stream;

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

  /// Tek seferlik alarmın hedef gününü planın "şimdi"sine göre yeniden
  /// hesaplar: kapalı alarm yeniden açılırken ve (koşullu) kaydederken
  /// çağrılır. Yedi günün tamamı kabul edilir, atlanan örnek geçilir;
  /// ekrandaki cümle de aynı hesabı ([nextOnceOccurrence]) kullanır.
  /// Hesaplanamazsa (vakit verisi yok) mevcut tarih korunur. Tekrarlı alarm
  /// aynen döner.
  Alarm withOnceDate(
    Alarm alarm, {
    required List<PrayerTime> prayerTimes,
    required Set<SkippedOccurrence> skips,
  }) {
    if (!alarm.isOnce) return alarm;
    final next = nextOnceOccurrence(
      alarm: alarm,
      now: _clock(),
      prayerTimesByDate: {for (final pt in prayerTimes) _dateKey(pt.date): pt},
      skips: skips,
    );
    return next == null ? alarm : alarm.copyWith(onceDate: next.day);
  }

  /// Kaydedilen tek seferlik alarmın hedef günü.
  ///
  /// Kayıtlı tek seferlik alarmın saati, türü, vakti ve ofseti değişmediyse
  /// ve o çalış hâlâ sürüyorsa (bekleyen oturum var ya da çalış geçmiş ama
  /// zincir süresi dolmamış) hedef gün korunur: çalan ya da yeni çalmış
  /// alarmın etiketini düzeltmek onu ertesi güne yeniden kurmamalı. Diğer
  /// her durumda [withOnceDate] ile yeniden hesaplanır.
  Future<Alarm> onceDateForSave(
    Alarm alarm, {
    required List<PrayerTime> prayerTimes,
    required Set<SkippedOccurrence> skips,
  }) async {
    if (!alarm.isOnce) return alarm;
    final recomputed = withOnceDate(
      alarm,
      prayerTimes: prayerTimes,
      skips: skips,
    );
    final stored = (await storage.getAlarms())
        .where((candidate) => candidate.id == alarm.id)
        .firstOrNull;
    final storedDay = stored?.onceDate;
    if (stored == null ||
        !stored.isOnce ||
        storedDay == null ||
        stored.kind != alarm.kind ||
        stored.hour != alarm.hour ||
        stored.minute != alarm.minute ||
        stored.anchor != alarm.anchor ||
        stored.offsetMinutes != alarm.offsetMinutes) {
      return recomputed;
    }
    final now = _clock();
    final fire = _fireOn(stored, _dateKey(storedDay), {
      for (final pt in prayerTimes) _dateKey(pt.date): pt,
    });
    final ringing =
        fire != null &&
        !fire.isAfter(now) &&
        now.isBefore(MissionChain.chainDeadline(fire));
    if (ringing || await _hasPendingSession(alarm.id)) {
      return alarm.copyWith(onceDate: storedDay);
    }
    return recomputed;
  }

  /// Oturumlar okunamazsa "yok" sayılır: hedef gün yeniden hesaplanır.
  Future<bool> _hasPendingSession(String alarmId) async {
    try {
      return MissionSession.pendingForAlarm(
            await alarmService.getMissionSessions(),
            alarmId,
          ) !=
          null;
    } catch (error) {
      _logger.warning(
        'Mission sessions unavailable while saving a one-shot alarm',
        error.runtimeType,
      );
      return false;
    }
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
    var alarms = await storage.getAlarms();
    // Ayar okunamazsa alarmlar varsayılan çalma süresiyle yine kurulur:
    // bir tercih hatası alarm planlamasını durdurmamalı.
    var general = const GeneralSettings();
    try {
      general = await storage.getGeneralSettings();
    } catch (error) {
      _logger.warning(
        'General settings unavailable for alarms',
        error.runtimeType,
      );
    }
    // 0 = sınırsız; native'e "yok" olarak gider.
    final ringLimit = general.alarmRingLimitMinutes > 0
        ? general.alarmRingLimitMinutes
        : null;
    final byDate = {for (final pt in prayerTimes) _dateKey(pt.date): pt};
    final now = _clock();
    alarms = await _settleOnceAlarms(alarms, byDate, now, skips);
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
        // Tek seferlikte yalnız hedef günün çalışı vardır.
        limit: alarm.isOnce
            ? 1
            : alarm.kind == AlarmKind.anchored || repeatDays.isEmpty
            ? 7
            : 1,
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
            ringLimitMinutes: ringLimit,
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

  /// Planlamadan önce açık tek seferlik alarmları düzene sokar; değişenleri
  /// [onceAlarmsChanged] ile bildirir.
  Future<List<Alarm>> _settleOnceAlarms(
    List<Alarm> alarms,
    Map<DateTime, PrayerTime> byDate,
    DateTime now,
    Set<SkippedOccurrence> skips,
  ) async {
    final changed = <String>{};
    final repaired = await _repairOnceDates(
      alarms,
      byDate,
      now,
      skips,
      changed,
    );
    final settled = await _closeSpentOnceAlarms(repaired, byDate, now, changed);
    if (changed.isNotEmpty) _onceAlarmsChanged.add(Set.unmodifiable(changed));
    return settled;
  }

  /// Hedef günü boş (hiç hesaplanamamış ya da bozuk okunmuş) açık tek
  /// seferlik alarmın gününü, vakit verisi varsa şimdi hesaplayıp kaydeder.
  /// Kaydedilemezse alarm onarılmamış hâliyle planlanır (kurulmaz): her
  /// planlamada yeniden hesaplanan bir gün alarmı her gün çaldırırdı.
  Future<List<Alarm>> _repairOnceDates(
    List<Alarm> alarms,
    Map<DateTime, PrayerTime> byDate,
    DateTime now,
    Set<SkippedOccurrence> skips,
    Set<String> changed,
  ) async {
    final result = <Alarm>[];
    for (final alarm in alarms) {
      final next = alarm.isActive && alarm.isOnce && alarm.onceDate == null
          ? nextOnceOccurrence(
              alarm: alarm,
              now: now,
              prayerTimesByDate: byDate,
              skips: skips,
            )
          : null;
      if (next == null) {
        result.add(alarm);
        continue;
      }
      final fixed = alarm.copyWith(onceDate: next.day);
      try {
        await storage.saveAlarm(fixed);
        changed.add(alarm.id);
        result.add(fixed);
      } catch (error) {
        _logger.warning(
          'One-shot alarm date could not be repaired',
          error.runtimeType,
        );
        result.add(alarm);
      }
    }
    return result;
  }

  /// Çalışı ve zincir süresi geçmiş tek seferlik alarmları kapatır.
  ///
  /// Zincir süresi dolmadan kapatılmaz: alarm kökü planda kalmazsa native
  /// taraf iOS'ta çalan alerti keser, görev zincirini düşürür. Bekleyen
  /// oturum (erteleme ya da görev) varken de kapatılmaz; oturum StopGate ile
  /// kapanınca sıradaki planlama kapatır. Oturumlar okunamazsa güvenli taraf
  /// seçilir: alarm açık kalır, native kayıt zaten geçmişte olduğu için
  /// yeniden çalmaz.
  Future<List<Alarm>> _closeSpentOnceAlarms(
    List<Alarm> alarms,
    Map<DateTime, PrayerTime> byDate,
    DateTime now,
    Set<String> changed,
  ) async {
    final spent = {
      for (final alarm in alarms)
        if (alarm.isActive &&
            alarm.isOnce &&
            _onceChainEnded(alarm, byDate, now))
          alarm.id,
    };
    if (spent.isEmpty) return alarms;
    final List<MissionSession> sessions;
    try {
      sessions = await alarmService.getMissionSessions();
    } catch (error) {
      _logger.warning(
        'Mission sessions unavailable; one-shot alarms stay on',
        error.runtimeType,
      );
      return alarms;
    }
    final result = <Alarm>[];
    for (final alarm in alarms) {
      if (spent.contains(alarm.id) &&
          MissionSession.pendingForAlarm(sessions, alarm.id) == null) {
        final off = alarm.copyWith(isActive: false);
        try {
          await storage.saveAlarm(off);
          changed.add(alarm.id);
          result.add(off);
          continue;
        } catch (error) {
          _logger.warning(
            'One-shot alarm could not be turned off',
            error.runtimeType,
          );
        }
      }
      result.add(alarm);
    }
    return result;
  }

  /// Hedef gündeki çalış + zincir süresi geçti mi?
  ///
  /// Hedef gün bugünden en az iki gün önceyse vakit verisine bakılmaz: en
  /// büyük ofset (240 dk) ve zincir süresi (60 dk) en geç ertesi gün gece
  /// yarısından önce biter. Uygulama günler sonra açılınca hedef gün vakit
  /// penceresinin dışında kalır; bu kural olmadan çıpalı alarm hiç
  /// kapanmazdı. Daha yakın günde çalış anı hesaplanır; çıpalıda vakit
  /// yoksa kapatılmaz (eksik vakit davranışı).
  static bool _onceChainEnded(
    Alarm alarm,
    Map<DateTime, PrayerTime> byDate,
    DateTime now,
  ) {
    final day = alarm.onceDate;
    if (day == null) return false;
    if (_calendarDaysBetween(day, now) >= 2) return true;
    final fire = _fireOn(alarm, _dateKey(day), byDate);
    return fire != null && !now.isBefore(MissionChain.chainDeadline(fire));
  }

  /// [from] gününden [to] gününe takvim günü farkı; yaz saati günündeki
  /// 23/25 saatlik gün farkı bozmasın diye UTC üzerinden.
  static int _calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

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
      if (!alarm.firesOnDay(day) || available.containsKey(day)) {
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
    // Saat dilimi değişince Android sabit kaydı aynı duvar saatine taşır;
    // tek seferlikte de gider.
    if (alarm.kind == AlarmKind.fixed) 'repeatHour': alarm.hour,
    if (alarm.kind == AlarmKind.fixed) 'repeatMinute': alarm.minute,
    // Şablon giderse Android uzlaştırması ve iOS durdurma akışı tarihli
    // kaydı haftalık tekrara çevirir; tek seferlik alarm haftalık olurdu.
    if (alarm.kind == AlarmKind.fixed && !alarm.isOnce)
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
        alarm.isOnce ||
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
  /// tetiklenme anı. Çıpalı ön dizim (F1b) bunun üzerine kurulu. Tek
  /// seferlik alarmda yalnız hedef günün çalışı aranır.
  static List<DateTime> computeNextFires({
    required Alarm alarm,
    required DateTime now,
    required Map<DateTime, PrayerTime> prayerTimesByDate,
    int searchDays = _searchDays,
    int limit = 7,
    Set<SkippedOccurrence> skips = const {},
  }) => [
    for (final occurrence in _nextOccurrences(
      alarm: alarm,
      now: now,
      prayerTimesByDate: prayerTimesByDate,
      searchDays: searchDays,
      limit: limit,
      skips: skips,
    ))
      occurrence.fire,
  ];

  /// Tek seferlik alarmın kurulacağı örnek: gün kümesi ve eski hedef gün yok
  /// sayılıp yedi günün tamamı kabul edilerek sıradaki ilk geçerli çalış.
  /// [day] kaynak vakit günüdür (çıpalıda ofset gece yarısını geçirse de
  /// vaktin okunduğu gün). Atlanan örnek geçilir. Vakit verisi yoksa `null`.
  ///
  /// Hedef gün kaydederken ([withOnceDate]) ve düzenleme ekranındaki cümlede
  /// aynı fonksiyondan gelir: ekranda görünen an planlanan andır (ADR 0004).
  static ({DateTime day, DateTime fire})? nextOnceOccurrence({
    required Alarm alarm,
    required DateTime now,
    required Map<DateTime, PrayerTime> prayerTimesByDate,
    Set<SkippedOccurrence> skips = const {},
  }) => _nextOccurrences(
    alarm: alarm.copyWith(isOnce: false, weekdays: const {}),
    now: now,
    prayerTimesByDate: prayerTimesByDate,
    searchDays: _searchDays,
    limit: 1,
    skips: skips,
  ).firstOrNull;

  static List<({DateTime day, DateTime fire})> _nextOccurrences({
    required Alarm alarm,
    required DateTime now,
    required Map<DateTime, PrayerTime> prayerTimesByDate,
    required int searchDays,
    required int limit,
    required Set<SkippedOccurrence> skips,
  }) {
    final occurrences = <({DateTime day, DateTime fire})>[];
    final today = _dateKey(now);
    for (var i = 0; i < searchDays && occurrences.length < limit; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      if (!alarm.firesOnDay(day)) continue;

      final candidate = _fireOn(alarm, day, prayerTimesByDate);
      if (candidate == null) continue;

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

      occurrences.add((day: day, fire: candidate));
    }
    return occurrences;
  }

  /// Kaynak gün [day] için çalış anı; çıpalıda o günün vakti yoksa `null`.
  static DateTime? _fireOn(
    Alarm alarm,
    DateTime day,
    Map<DateTime, PrayerTime> prayerTimesByDate,
  ) {
    if (alarm.kind == AlarmKind.fixed) {
      return DateTime(day.year, day.month, day.day, alarm.hour, alarm.minute);
    }
    final pt = prayerTimesByDate[day];
    if (pt == null) return null;
    return _anchorTime(
      pt,
      alarm.anchor,
    ).add(Duration(minutes: alarm.offsetMinutes));
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
