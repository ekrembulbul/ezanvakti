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
      // Tek bir alarm planlanamazsa (ör. kullanıcı alarm iznini reddetti)
      // diğerleri etkilenmemeli. Hata yutulmaz, uyarı olarak loglanır: sessiz
      // başarısızlık hata ayıklamayı imkânsız kılar.
      try {
        await alarmService.scheduleAlarm(
          repeatWeekdays: _relativeWeekdaysFor(alarm, now: now, skips: skips),
          id: alarm.id,
          scheduledTime: fire,
          label: alarm.label,
          soundId: alarm.soundId,
          vibrate: alarm.vibrate,
          snoozeEnabled: alarm.snoozeEnabled,
          snoozeMinutes: alarm.snoozeMinutes,
          theme: themeForFire(fire, byDate, currentAppearance),
          mission: alarm.mission,
          missionLevel: alarm.missionLevel,
          chainConfig: {
            'graceSeconds': MissionTuning.graceSeconds,
            'maxRearms': MissionTuning.maxRearms,
            'chainDeadlineMillis':
                MissionChain.chainDeadline(fire).millisecondsSinceEpoch,
            'missionTimeoutSeconds': MissionTuning.timeoutSecondsFor(
              alarm.mission,
            ),
            'ladderMillis': [
              for (final t in MissionChain.ladder(fire))
                t.millisecondsSinceEpoch,
            ],
          },
        );
      } catch (e) {
        _logger.warning('Alarm planlanamadı (id: ${alarm.id})', e);
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

  /// Çıpalı alarmın önümüzdeki çalışlarını önden dizer (K1/F1b): saat her
  /// gün kaydığı için native tekrar kurulamaz; bunun yerine 7 güne kadar ayrı
  /// kayıt kurulur. Birincil çalış `alarm.id` ile (görev oturumu ve skip
  /// kayıtları bu id ile eşleşiyor), ileri günler `<id>#d<N>` ile ve görevsiz/
  /// ertelemesiz kurulur — degrade: uygulama günlerce açılmazsa alarm yine
  /// çalar ama durdurulduğunda görev ekranı açılmaz; ilk açılış diziyi tazeler.
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
          id: primary ? alarm.id : '${alarm.id}#d$i',
          scheduledTime: fire,
          label: alarm.label,
          soundId: alarm.soundId,
          vibrate: alarm.vibrate,
          snoozeEnabled: primary && alarm.snoozeEnabled,
          snoozeMinutes: alarm.snoozeMinutes,
          theme: themeForFire(fire, byDate, currentAppearance),
          mission: primary ? alarm.mission : AlarmMission.none,
          missionLevel: alarm.missionLevel,
          chainConfig: primary
              ? {
                  'graceSeconds': MissionTuning.graceSeconds,
                  'maxRearms': MissionTuning.maxRearms,
                  'chainDeadlineMillis':
                      MissionChain.chainDeadline(fire).millisecondsSinceEpoch,
                  'missionTimeoutSeconds': MissionTuning.timeoutSecondsFor(
                    alarm.mission,
                  ),
                  'ladderMillis': [
                    for (final t in MissionChain.ladder(fire))
                      t.millisecondsSinceEpoch,
                  ],
                }
              : const <String, dynamic>{},
        );
      } catch (e) {
        _logger.warning('Alarm planlanamadı (id: ${alarm.id}, gün $i)', e);
        failures[alarm.id] = _shortMessage(e);
      }
    }
  }

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
      final day = today.add(Duration(days: i));
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
