import '../../../core/config/mission_tuning.dart';
import '../../../core/interfaces/alarm_service.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/alarm.dart';
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
/// planlar. Tekrarlı alarmlarda yalnızca "bir sonraki" çalış planlanır; alarm
/// çalıp kapatılınca (veya uygulama açılış/yenilemesinde) yeniden planlanır.
class AlarmScheduler {
  final AlarmService alarmService;
  final LocalStorage storage;

  /// Çalar ekranın paleti için kullanıcının güncel görünüm tercihleri.
  /// Planlama anında okunur; tema denetleyicisine doğrudan bağımlılık yok.
  final AlarmAppearance Function() appearance;

  final AppLogger _logger;
  Future<void>? _scheduleQueue;

  AlarmScheduler({
    required this.alarmService,
    required this.storage,
    AlarmAppearance Function()? appearance,
    AppLogger? logger,
  }) : appearance = appearance ?? (() => AlarmAppearance.fallback),
       _logger = logger ?? AppLogger();

  /// Kayıtlı tüm alarmlar için önce mevcut planları temizler, sonra aktif
  /// alarmların bir sonraki tetiklenmesini planlar.
  Future<void> scheduleAlarms({
    required List<PrayerTime> prayerTimes,
    Set<SkippedOccurrence> skips = const {},
  }) {
    final times = List<PrayerTime>.unmodifiable(prayerTimes);
    final skipped = Set<SkippedOccurrence>.unmodifiable(skips);
    final previous = _scheduleQueue;
    final operation = previous == null
        ? Future<void>.sync(
            () => _scheduleAlarms(prayerTimes: times, skips: skipped),
          )
        : previous.then(
            (_) => _scheduleAlarms(prayerTimes: times, skips: skipped),
          );
    _scheduleQueue = operation.then<void>(
      (_) {},
      // Only recover the sequencing tail. The caller receives the original
      // failing operation below, so its error and stack remain intact.
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<void> _scheduleAlarms({
    required List<PrayerTime> prayerTimes,
    required Set<SkippedOccurrence> skips,
  }) async {
    final alarms = await storage.getAlarms();

    // Boş olsa bile önce temizle (silinen alarmlar ortada kalmasın).
    await alarmService.cancelAllAlarms();
    if (alarms.isEmpty) return;

    final byDate = <DateTime, PrayerTime>{};
    for (final pt in prayerTimes) {
      byDate[_dateKey(pt.date)] = pt;
    }

    final now = DateTime.now();
    final currentAppearance = appearance();
    final failures = <String, String>{};
    for (final alarm in alarms) {
      if (!alarm.isActive) continue;
      if (alarm.kind == AlarmKind.anchored) {
        await _scheduleAnchoredSeries(
          alarm: alarm,
          now: now,
          byDate: byDate,
          skips: skips,
          currentAppearance: currentAppearance,
          failures: failures,
        );
        continue;
      }
      final fire = computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: byDate,
        skips: skips,
      );
      if (fire == null) continue;
      final repeatWeekdays = _relativeWeekdaysFor(
        alarm,
        now: now,
        skips: skips,
      );
      // Tek bir alarm planlanamazsa (ör. kullanıcı alarm iznini reddetti)
      // diğerleri etkilenmemeli. Hata yutulmaz, uyarı olarak loglanır: sessiz
      // başarısızlık hata ayıklamayı imkânsız kılar.
      try {
        await alarmService.scheduleAlarm(
          repeatWeekdays: repeatWeekdays,
          id: repeatWeekdays.isEmpty
              ? '${alarm.id}#at${fire.millisecondsSinceEpoch}'
              : alarm.id,
          scheduledTime: fire,
          label: alarm.label,
          soundId: alarm.soundId,
          vibrate: alarm.vibrate,
          snoozeEnabled: alarm.snoozeEnabled,
          snoozeMinutes: alarm.snoozeMinutes,
          theme: themeForFire(fire, byDate, currentAppearance),
          mission: alarm.mission,
          missionLevel: alarm.missionLevel,
          chainConfig: _chainConfig(alarm, fire),
        );
      } catch (e) {
        // Log; kullanıcıya gösterilmiyor, çevrilmiyor.
        _logger.warning('Alarm scheduling failed (id: ${alarm.id})', e);
        failures[alarm.id] = _shortMessage(e);
      }
    }

    // Kalıcı kayıt arayüz içindir; yazılamaması planlamayı düşürmemeli
    // (testlerdeki kısmi sahte depolar da desteklemeyebilir).
    try {
      await storage.saveAlarmScheduleFailures(failures);
    } catch (e) {
      _logger.warning('Alarm hata kaydi yazilamadi', e);
    }
  }

  /// Satırda gösterilecek kadar kısa hata özeti.
  static String _shortMessage(Object error) {
    final text = error.toString();
    return text.length <= 120 ? text : text.substring(0, 120);
  }

  /// Çıpalı çalışlar kararlı tarih kimlikleriyle kurulur. Her kayıt ana alarm
  /// kimliğini ve görevi taşır; günler ilerleyince başka çalışın kimliğini almaz.
  Future<void> _scheduleAnchoredSeries({
    required Alarm alarm,
    required DateTime now,
    required Map<DateTime, PrayerTime> byDate,
    required Set<SkippedOccurrence> skips,
    required AlarmAppearance currentAppearance,
    required Map<String, String> failures,
  }) async {
    final fires = computeNextFires(
      alarm: alarm,
      now: now,
      prayerTimesByDate: byDate,
      skips: skips,
    );
    for (var i = 0; i < fires.length; i++) {
      final fire = fires[i];
      final primary = i == 0;
      try {
        await alarmService.scheduleAlarm(
          id: '${alarm.id}#at${fire.millisecondsSinceEpoch}',
          scheduledTime: fire,
          label: alarm.label,
          soundId: alarm.soundId,
          vibrate: alarm.vibrate,
          snoozeEnabled: alarm.snoozeEnabled,
          snoozeMinutes: alarm.snoozeMinutes,
          theme: themeForFire(fire, byDate, currentAppearance),
          mission: alarm.mission,
          missionLevel: alarm.missionLevel,
          chainConfig: _chainConfig(alarm, fire, includeLadder: primary),
        );
      } catch (e) {
        _logger.warning('Alarm scheduling failed (id: ${alarm.id}, day $i)', e);
        failures[alarm.id] = _shortMessage(e);
      }
    }
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

  /// Sabit saatli tekrarlı alarm için native haftalık tekrar günleri
  /// (1=Pazartesi..7=Pazar, sıralı). Çıpalı alarm relative olamaz (saat her
  /// gün kayar) ve "yalnızca bu sefer atla" devredeyken native tekrar o
  /// örneği atlayamayacağı için tek seferlik yola düşülür — atlanan gün
  /// geçince bir sonraki planlamada tekrar native tekrara döner.
  static List<int> _relativeWeekdaysFor(
    Alarm alarm, {
    required DateTime now,
    required Set<SkippedOccurrence> skips,
  }) {
    if (alarm.kind != AlarmKind.fixed) return const [];
    final withSkips = computeNextFire(
      alarm: alarm,
      now: now,
      prayerTimesByDate: const {},
      skips: skips,
    );
    final withoutSkips = computeNextFire(
      alarm: alarm,
      now: now,
      prayerTimesByDate: const {},
    );
    if (withSkips == null || withSkips != withoutSkips) return const [];
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
    int searchDays = 8,
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
    int searchDays = 8,
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
