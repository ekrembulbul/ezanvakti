import '../../../core/constants/notification_sounds.dart';
import 'dart:ui';

import '../../../core/data/religious_days.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/locale_resolver.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../core/models/quiet_window.dart';
import '../../prayer_times/domain/derived_times.dart';
import 'quiet_window_rules.dart';
import '../../../core/interfaces/notification_service.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/models/location.dart';
import '../../../core/models/skipped_occurrence.dart';
import 'skip_rules.dart';
import '../../../core/utils/app_logger.dart';

class NotificationScheduler {
  final NotificationService notificationService;
  final LocalStorage storage;

  /// Bildirim metinleri arka planda, `BuildContext` olmadan üretiliyor.
  /// Çeviri örneği planlama anında bu sağlayıcıdan alınır — kullanıcı dili
  /// değiştirdiğinde bir sonraki planlama yeni dilde kurulur.
  ///
  /// Parametre, kullanıcının uygulama içi dil tercihidir; `null` ise cihaz
  /// dili kullanılır.
  final Future<AppLocalizations> Function(Locale? preferred) localizations;

  static const int scheduleDaysAhead = 7;

  /// iOS uygulama başına en fazla ~64 bekleyen yerel bildirim tutar; bu sayıyı
  /// aşanların en uzaktakilerini sessizce atar. Bu yüzden en yakın olanlardan
  /// bu kadarını planlarız (öngörülemez OS davranışı yerine kontrollü kapama).
  static const int maxScheduledNotifications = 64;

  NotificationScheduler({
    required this.notificationService,
    required this.storage,
    Future<AppLocalizations> Function(Locale? preferred)? localizations,
  }) : localizations = localizations ?? defaultLocalizations;

  /// Varsayılan: cihaz dili; desteklenmiyorsa İngilizce (bkz.
  /// [LocaleResolver]). Kullanıcı uygulama içinde dil seçtiyse çağıran taraf
  /// kendi sağlayıcısını verir.
  static Future<AppLocalizations> defaultLocalizations(
    Locale? preferred,
  ) async {
    return AppLocalizations.delegate.load(
      LocaleResolver.resolve(preferred ?? PlatformDispatcher.instance.locale),
    );
  }

  Future<void> scheduleNotifications({
    required Location location,
    required List<PrayerTime> prayerTimes,
    Set<SkippedOccurrence> skips = const {},
  }) async {
    final logger = AppLogger();
    logger.debug(
      'Scheduling notifications for ${location.province}/${location.district} (${prayerTimes.length} days)',
    );

    final settings = await storage.getNotificationSettings();
    final general = await storage.getGeneralSettings();
    // Kullanıcı uygulama içinde bir dil seçtiyse bildirimler de o dilde
    // gelmeli; seçmediyse cihaz dili kullanılır.
    final l10n = await localizations(general.language.locale);
    final quietWindows = await storage.getQuietWindows();

    // Mevcut tüm planlanmış bildirimleri önce iptal et — ayar listesi boş olsa
    // bile. Aksi halde kullanıcı tüm bildirimleri silince, daha önce OS'a
    // zamanlanmış bildirimler iptal edilmeden kalır ve tetiklenmeye devam eder.
    await notificationService.cancelAllNotifications();
    logger.debug('Cancelled all existing notifications');

    if (settings.isEmpty) {
      logger.debug(
        'No notification settings; cleared all, nothing to schedule',
      );
      return;
    }

    logger.debug('Found ${settings.length} notification settings');

    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: scheduleDaysAhead));

    // Gece vakitleri (gece yarısı, son üçte bir) ertesi günün imsakını
    // gerektiriyor; günleri tarihe göre indeksliyoruz.
    final byDate = <DateTime, PrayerTime>{
      for (final time in prayerTimes)
        DateTime(time.date.year, time.date.month, time.date.day): time,
    };

    // Pencere içindeki (şimdi .. +scheduleDaysAhead) aktif bildirimleri topla.
    final candidates = <_NotificationCandidate>[];
    final seenIds = <String>{};

    // Spesifik (belirli günlere kısıtlı) satırlar önce denenir: aynı
    // (gün, vakit, sapma) kimliğini paylaşan iki satırda Cuma'ya özel olan
    // genel satırı bastırsın (`seenIds` gerisini hallediyor).
    final orderedSettings = [
      ...settings.where((setting) => setting.isDayScoped),
      ...settings.where((setting) => !setting.isDayScoped),
    ];

    for (final prayerTime in prayerTimes) {
      for (final setting in orderedSettings) {
        if (!setting.isActive) continue;

        final prayerDateTime = _pointTime(setting, prayerTime, byDate);
        // Türetilmiş nokta hesaplanamadıysa (ertesi günün verisi yok) o gün
        // sessizce atlanır; bir sonraki yenilemede veri geldiğinde kurulur.
        if (prayerDateTime == null) continue;

        // Gün filtresi vaktin gününe bakar; sapmalı bildirim bir önceki güne
        // düşse bile satır hangi vakit için kurulduysa o güne aittir.
        if (!setting.firesOnWeekday(prayerDateTime.weekday)) continue;

        // Geçmişi ve pencere dışını ele.
        if (prayerDateTime.isBefore(now) || prayerDateTime.isAfter(cutoff)) {
          continue;
        }

        final notificationTime = prayerDateTime.subtract(
          Duration(minutes: setting.minutesBefore),
        );
        if (notificationTime.isBefore(now)) continue;

        final id = notificationIdFor(
          date: prayerTime.date,
          pointIndex: pointIndexOf(setting),
          minutesBefore: setting.minutesBefore,
        );
        if (!seenIds.add(id)) continue; // ayni (gun,vakit,offset) tekrari

        // "Yalnızca bu sefer" atlanan örnek planlanmaz; aynı bildirimin
        // diğer günleri etkilenmez.
        if (isSkipped(
          skips,
          kind: SkipKind.notification,
          reference: id,
          fireAt: notificationTime,
        )) {
          continue;
        }

        // Sessiz pencere: karar tetiklenme anına göre verilir, vaktin
        // kendisine göre değil — pencere dışına düşen erken hatırlatma
        // sesli kalmalı.
        final quietMode = QuietWindowRules.modeFor(
          windows: quietWindows,
          fireAt: notificationTime,
          prayerType: setting.prayerType,
          prayerAt: prayerDateTime,
        );
        if (quietMode == QuietMode.skip) continue;

        candidates.add(
          _NotificationCandidate(
            id: id,
            notificationTime: notificationTime,
            title: _getNotificationTitle(setting, l10n),
            body: _getNotificationBody(setting, prayerDateTime, l10n),
            soundId: setting.soundId,
            silent:
                quietMode == QuietMode.silent ||
                NotificationSounds.isSilent(setting.soundId),
          ),
        );
      }
    }

    if (general.religiousDayNotifications) {
      _addReligiousDayCandidates(
        candidates: candidates,
        seenIds: seenIds,
        byDate: byDate,
        now: now,
        cutoff: cutoff,
        eve: general.religiousDayEve,
        soundId: general.defaultSound,
        l10n: l10n,
      );
    }

    // En yakın bildirimlerden iOS sınırı kadarını planla.
    candidates.sort((a, b) => a.notificationTime.compareTo(b.notificationTime));
    final toSchedule = candidates.take(maxScheduledNotifications).toList();

    for (final candidate in toSchedule) {
      await notificationService.scheduleNotification(
        id: candidate.id,
        scheduledTime: candidate.notificationTime,
        title: candidate.title,
        body: candidate.body,
        soundId: candidate.soundId,
        silent: candidate.silent,
        timeSensitive: general.showInFocusMode,
      );
      logger.debug(
        '${_formatTime(candidate.notificationTime)} icin bildirim planlandi (${candidate.id})',
      );
    }

    logger.debug(
      'Scheduled ${toSchedule.length}/${candidates.length} notifications '
      '(tavan $maxScheduledNotifications, pencere $scheduleDaysAhead gun)',
    );
  }

  Future<void> rescheduleNotifications({
    required Location location,
    required List<PrayerTime> prayerTimes,
    Set<SkippedOccurrence> skips = const {},
  }) async {
    await scheduleNotifications(
      location: location,
      prayerTimes: prayerTimes,
      skips: skips,
    );
  }

  /// Bir bildirim örneğinin kimliği: gün · nokta · offset.
  ///
  /// Şema 32-bit'e sığar ve id'den geri çözülebilir:
  /// `(gün % 10000) · 200000 + nokta · 10000 + offset`.
  /// Nokta alanı iki hane oldu; 6 vakit + 5 türetilmiş + dini gün tek haneye
  /// sığmıyordu. Gün alanı 10000 ile modlanıyor — 27 yılda bir tekrar eder,
  /// planlama penceresi 7 gün olduğu için çakışma imkânsız.
  ///
  /// Atlama kayıtları da bu kimliği `reference` olarak kullanır; kart ve
  /// planlayıcı aynı değeri üretmek zorunda.
  static String notificationIdFor({
    required DateTime date,
    required int pointIndex,
    required int minutesBefore,
  }) {
    final dayOrdinal =
        DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final id =
        (dayOrdinal % 10000) * 200000 + pointIndex * 10000 + minutesBefore;
    return id.toString();
  }

  /// Vakitler 0–5, türetilmiş noktalar 6–10, dini günler 11.
  static int pointIndexOf(NotificationSetting setting) {
    final derived = setting.derivedKind;
    return derived == null ? setting.prayerType.index : 6 + derived.index;
  }

  /// Dini gün bildirimlerinin ayrılmış nokta indeksi.
  static const int religiousDayPointIndex = 11;

  /// Dini gün adaylarını havuza katar.
  ///
  /// Gün akşam vaktinde hatırlatılır: kandil ve bayram geceleri akşam
  /// namazıyla başlar. İsteğe bağlı olarak bir gün önce öğle vaktinde de
  /// hatırlatılır — hazırlık için (oruç, program).
  void _addReligiousDayCandidates({
    required List<_NotificationCandidate> candidates,
    required Set<String> seenIds,
    required Map<DateTime, PrayerTime> byDate,
    required DateTime now,
    required DateTime cutoff,
    required bool eve,
    required String soundId,
    required AppLocalizations l10n,
  }) {
    if (byDate.isEmpty) return;
    final days = byDate.keys.toList()..sort();
    final religiousDays = ReligiousDays.forRange(days.first, days.last);

    for (final day in religiousDays) {
      final prayerTime = byDate[day.date];
      if (prayerTime == null) continue;

      final name = l10n.religiousDayName(day.id);
      _addReligiousCandidate(
        candidates: candidates,
        seenIds: seenIds,
        date: day.date,
        fireAt: prayerTime.maghrib,
        minutesBefore: 0,
        title: name,
        body: day.isEstimated
            ? l10n.religiousDayTodayEstimated(name)
            : l10n.religiousDayToday(name),
        soundId: soundId,
        now: now,
        cutoff: cutoff,
      );

      if (!eve) continue;
      final eveDate = DateTime(
        day.date.year,
        day.date.month,
        day.date.day - 1,
      );
      final evePrayerTime = byDate[eveDate];
      if (evePrayerTime == null) continue;

      _addReligiousCandidate(
        candidates: candidates,
        seenIds: seenIds,
        date: eveDate,
        fireAt: evePrayerTime.dhuhr,
        // Bir gün önceki hatırlatma da aynı noktaya ait; kimlik çakışmasın
        // diye sapma alanı 1 kullanılıyor.
        minutesBefore: 1,
        title: l10n.religiousDayTomorrowTitle(name),
        body: l10n.religiousDayTomorrowBody(name),
        soundId: soundId,
        now: now,
        cutoff: cutoff,
      );
    }
  }

  void _addReligiousCandidate({
    required List<_NotificationCandidate> candidates,
    required Set<String> seenIds,
    required DateTime date,
    required DateTime fireAt,
    required int minutesBefore,
    required String title,
    required String body,
    required String soundId,
    required DateTime now,
    required DateTime cutoff,
  }) {
    if (fireAt.isBefore(now) || fireAt.isAfter(cutoff)) return;
    final id = notificationIdFor(
      date: date,
      pointIndex: religiousDayPointIndex,
      minutesBefore: minutesBefore,
    );
    if (!seenIds.add(id)) return;
    candidates.add(
      _NotificationCandidate(
        id: id,
        notificationTime: fireAt,
        title: title,
        body: body,
        soundId: soundId,
        silent: NotificationSounds.isSilent(soundId),
      ),
    );
  }

  /// Satırın o gün için tetikleneceği an: vakit bildiriminde vaktin kendisi,
  /// türetilmiş noktada hesaplanan an.
  DateTime? _pointTime(
    NotificationSetting setting,
    PrayerTime day,
    Map<DateTime, PrayerTime> byDate,
  ) {
    final derived = setting.derivedKind;
    if (derived == null) {
      return _getPrayerDateTime(day, setting.prayerType);
    }
    final nextDay = byDate[DateTime(
      day.date.year,
      day.date.month,
      day.date.day + 1,
    )];
    return DerivedTimes.resolve(kind: derived, day: day, nextDay: nextDay);
  }

  DateTime? _getPrayerDateTime(PrayerTime prayerTime, PrayerType prayerType) {
    switch (prayerType) {
      case PrayerType.fajr:
        return prayerTime.fajr;
      case PrayerType.sunrise:
        return prayerTime.sunrise;
      case PrayerType.dhuhr:
        return prayerTime.dhuhr;
      case PrayerType.asr:
        return prayerTime.asr;
      case PrayerType.maghrib:
        return prayerTime.maghrib;
      case PrayerType.isha:
        return prayerTime.isha;
    }
  }

  String _getNotificationTitle(
    NotificationSetting setting,
    AppLocalizations l10n,
  ) {
    final label = setting.label;
    if (label != null && label.trim().isNotEmpty) return label.trim();
    final derived = setting.derivedKind;
    if (derived != null) {
      final name = l10n.derivedName(derived);
      return setting.minutesBefore == 0
          ? name
          : l10n.notificationDerivedSoon(name);
    }
    final prayer = l10n.prayerName(setting.prayerType);
    return setting.minutesBefore == 0
        ? prayer
        : l10n.notificationPrayerSoon(prayer);
  }

  String _getNotificationBody(
    NotificationSetting setting,
    DateTime prayerTime,
    AppLocalizations l10n,
  ) {
    final timeStr =
        '${prayerTime.hour.toString().padLeft(2, '0')}:${prayerTime.minute.toString().padLeft(2, '0')}';

    final derived = setting.derivedKind;
    if (derived != null) {
      final name = l10n.derivedName(derived);
      return setting.minutesBefore == 0
          ? '$timeStr - ${l10n.derivedHint(derived)}'
          : '$timeStr - '
                '${l10n.notificationDerivedMinutesLeft(name, setting.minutesBefore)}';
    }

    final prayer = l10n.prayerName(setting.prayerType);
    return setting.minutesBefore == 0
        ? '$timeStr - ${l10n.notificationPrayerNow(prayer)}'
        : '$timeStr - '
              '${l10n.notificationMinutesLeft(prayer, setting.minutesBefore)}';
  }


  Future<List<ScheduledNotification>> getPendingNotifications() async {
    return await notificationService.getPendingNotifications();
  }

  Future<void> cancelAllNotifications() async {
    await notificationService.cancelAllNotifications();
  }

  Future<bool> hasPermission() async {
    return await notificationService.isPermissionGranted();
  }

  String _formatTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Future<bool> requestPermission() async {
    return await notificationService.requestPermission();
  }
}

class _NotificationCandidate {
  final String id;
  final DateTime notificationTime;
  final String title;
  final String body;
  final String? soundId;
  final bool silent;

  const _NotificationCandidate({
    required this.id,
    required this.notificationTime,
    required this.title,
    required this.body,
    this.soundId,
    this.silent = false,
  });
}
