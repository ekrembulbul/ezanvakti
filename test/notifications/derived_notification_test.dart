import 'package:ezanvakti/core/models/derived_time.dart';
import 'dart:ui';

import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:ezanvakti/core/data/religious_days.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/models/religious_day.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/notification_storage.dart';
import 'fakes/recording_notification_service.dart';

void main() {
  PrayerTime dayAt(DateTime date) => PrayerTime(
    date: DateTime(date.year, date.month, date.day),
    fajr: DateTime(date.year, date.month, date.day, 5, 0),
    sunrise: DateTime(date.year, date.month, date.day, 6, 30),
    dhuhr: DateTime(date.year, date.month, date.day, 13, 0),
    asr: DateTime(date.year, date.month, date.day, 16, 30),
    maghrib: DateTime(date.year, date.month, date.day, 19, 45),
    isha: DateTime(date.year, date.month, date.day, 21, 15),
  );

  final location = Location(
    id: 'l1',
    province: 'İstanbul',
    district: 'Fatih',
    type: LocationType.manual,
  );

  late RecordingNotificationService service;
  late NotificationTestStorage storage;
  late NotificationScheduler scheduler;

  setUp(() {
    service = RecordingNotificationService();
    storage = NotificationTestStorage();
    scheduler = NotificationScheduler(
      notificationService: service,
      storage: storage,
      // Testler kaynak dilde (Turkce) kosuyor; cihaz diline bagli olmasin.
      localizations: (_) =>
          AppLocalizations.delegate.load(const Locale('tr')),
    );
  });

  /// Bugunden basliyoruz: planlayici gecmisi ve 7 gunluk pencere disini eler.
  const dayCount = 5;
  List<PrayerTime> days() {
    final today = DateTime.now();
    return [
      for (var i = 0; i < dayCount; i++)
        dayAt(DateTime(today.year, today.month, today.day + i)),
    ];
  }

  Future<void> schedule() => scheduler.scheduleNotifications(
    location: location,
    prayerTimes: days(),
  );

  test('istiva bildirimi ogleden 10 dk once planlanir', () async {
    storage.settings = [
      const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        derivedKind: DerivedTimeKind.istiwa,
        isActive: true,
      ),
    ];
    await schedule();

    expect(service.calls, isNotEmpty);
    final call = service.calls.first;
    expect(call.scheduledTime.hour, 12);
    expect(call.scheduledTime.minute, 50);
    expect(call.title, DerivedTimeKind.istiwa.label);
  });

  test('israk bildirimi gunesten 45 dk sonra planlanir', () async {
    storage.settings = [
      const NotificationSetting(
        prayerType: PrayerType.sunrise,
        derivedKind: DerivedTimeKind.ishraq,
        isActive: true,
      ),
    ];
    await schedule();

    final call = service.calls.first;
    expect(call.scheduledTime.hour, 7);
    expect(call.scheduledTime.minute, 15);
  });

  test('son gunun gece vakti planlanmaz (ertesi gun verisi yok)', () async {
    storage.settings = [
      const NotificationSetting(
        prayerType: PrayerType.maghrib,
        derivedKind: DerivedTimeKind.lastThird,
        isActive: true,
      ),
    ];
    await schedule();

    // Gece vakitleri ertesi gunun imsagini gerektirir; son gun icin
    // hesaplanamaz.
    final scheduledDays = service.calls
        .map((call) => DateTime(
              call.scheduledTime.year,
              call.scheduledTime.month,
              call.scheduledTime.day,
            ))
        .toSet();
    expect(scheduledDays.length, lessThan(dayCount));
    expect(service.calls, isNotEmpty);
  });

  test('turetilmis nokta cipa vaktiyle ayni anda planlanabilir', () async {
    storage.settings = [
      const NotificationSetting(prayerType: PrayerType.dhuhr, isActive: true),
      const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        derivedKind: DerivedTimeKind.istiwa,
        isActive: true,
      ),
    ];
    await schedule();

    final ids = service.calls.map((call) => call.id).toSet();
    expect(ids.length, service.calls.length, reason: 'kimlikler cakismamali');
    expect(
      service.calls.any((call) => call.title == DerivedTimeKind.istiwa.label),
      isTrue,
    );
    expect(service.calls.any((call) => call.title == 'Öğle'), isTrue);
  });

  group('dini gunler', () {
    /// Planlama penceresi 7 gun oldugu icin sabit bir tarih kullanilamaz:
    /// bugunden sonraki ilk dini gunu bulup onu iceren pencereyi kuruyoruz.
    late ReligiousDay target;

    setUp(() {
      final today = DateTime.now();
      final upcoming = ReligiousDays.forRange(
        DateTime(today.year, today.month, today.day + 1),
        DateTime(today.year, today.month, today.day + 300),
      );
      target = upcoming.first;
    });

    /// Hedef gunu ve bir oncesini kapsayan, **bugunden baslayan** pencere.
    List<PrayerTime> window() {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      final dayCount = target.date.difference(start).inDays + 2;
      return [
        for (var i = 0; i < dayCount; i++)
          dayAt(DateTime(start.year, start.month, start.day + i)),
      ];
    }

    Future<void> scheduleWindow() => scheduler.scheduleNotifications(
      location: location,
      prayerTimes: window(),
    );

    test('ayar kapaliyken dini gun bildirimi planlanmaz', () async {
      await scheduleWindow();
      expect(service.calls, isEmpty);
    });

    test('ayar acikken gun aksam vaktinde planlanir', () async {
      storage.general = const GeneralSettings(
        religiousDayNotifications: true,
        religiousDayEve: false,
      );
      await scheduleWindow();

      // Hedef gun 7 gunluk planlama penceresine giriyorsa bildirim olmali.
      final withinWindow = target.date.difference(DateTime.now()).inDays <
          NotificationScheduler.scheduleDaysAhead;
      if (!withinWindow) return;

      final matches = service.calls.where(
        (call) => call.title == target.name,
      );
      expect(matches, isNotEmpty, reason: target.name);
      expect(matches.first.scheduledTime.hour, 19, reason: 'aksam vakti');
      expect(matches.first.body, contains('hesaplanmıştır'));
    });

    test('bir gun once hatirlatma ayri kimlik kullanir', () async {
      storage.general = const GeneralSettings(
        religiousDayNotifications: true,
        religiousDayEve: true,
      );
      await scheduleWindow();

      final ids = service.calls.map((call) => call.id).toSet();
      expect(ids.length, service.calls.length, reason: 'kimlikler cakismamali');
    });
  });

  test('etiket verilirse turetilmis noktanin adinin yerine gecer', () async {
    storage.settings = [
      const NotificationSetting(
        prayerType: PrayerType.maghrib,
        derivedKind: DerivedTimeKind.midnight,
        isActive: true,
        label: 'Gece namazı',
      ),
    ];
    await schedule();
    expect(service.calls.first.title, 'Gece namazı');
  });
}
