import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/core/constants/notification_sounds.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/recording_notification_service.dart';
import 'fakes/notification_storage.dart';

void main() {
  final today = DateTime(2026, 9, 4); // Cuma
  PrayerTime dayAt(DateTime date) => PrayerTime(
    date: date,
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
    );
  });

  Future<void> schedule({Set<SkippedOccurrence> skips = const {}}) =>
      scheduler.scheduleNotifications(
        location: location,
        prayerTimes: [for (var i = 0; i < 3; i++) dayAt(today.add(Duration(days: i)))],
        skips: skips,
      );

  test('ayardaki ses kimligi servise gecirilir', () async {
    storage.settings = [
      const NotificationSetting(
        prayerType: PrayerType.isha,
        isActive: true,
        soundId: NotificationSounds.beep,
      ),
    ];
    await schedule();
    expect(service.calls, isNotEmpty);
    expect(service.calls.first.soundId, NotificationSounds.beep);
    expect(service.calls.first.silent, isFalse);
  });

  test('sessiz ses kimligi silent bayragina cevrilir', () async {
    storage.settings = [
      const NotificationSetting(
        prayerType: PrayerType.isha,
        isActive: true,
        soundId: NotificationSounds.silent,
      ),
    ];
    await schedule();
    expect(service.calls.first.silent, isTrue);
  });

  test('odak modu kapaliyken time sensitive gonderilmez', () async {
    storage.general = const GeneralSettings(showInFocusMode: false);
    storage.settings = [
      const NotificationSetting(prayerType: PrayerType.isha, isActive: true),
    ];
    await schedule();
    expect(service.calls.first.timeSensitive, isFalse);
  });

  test('odak modu acikken time sensitive gonderilir', () async {
    storage.settings = [
      const NotificationSetting(prayerType: PrayerType.isha, isActive: true),
    ];
    await schedule();
    expect(service.calls.first.timeSensitive, isTrue);
  });

  test('ses secilmemisse sistem varsayilani gider', () async {
    storage.settings = [
      const NotificationSetting(prayerType: PrayerType.isha, isActive: true),
    ];
    await schedule();
    expect(service.calls.first.soundId, isNull);
    expect(service.calls.first.silent, isFalse);
  });
}
