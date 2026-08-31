import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/notification_storage.dart';
import 'fakes/recording_notification_service.dart';

void main() {
  // 4 Eylul 2026 Cuma'dan basliyoruz; 7 gunluk pencere tum haftayi kapsar.
  final start = DateTime(2026, 9, 4);

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
    );
  });

  Future<void> schedule() => scheduler.scheduleNotifications(
    location: location,
    prayerTimes: [for (var i = 0; i < 8; i++) dayAt(start.add(Duration(days: i)))],
  );

  test('yalnizca Cuma satiri sadece cuma gunu planlanir', () async {
    storage.settings = [
      const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 45,
        weekdays: {5},
        label: 'Cuma namazı',
      ),
    ];
    await schedule();

    expect(service.calls, isNotEmpty);
    expect(
      service.calls.every(
        (call) => call.scheduledTime.weekday == DateTime.friday,
      ),
      isTrue,
      reason: 'yalnizca cuma gunleri planlanmali',
    );
  });

  test('etiket bildirim basliginda kullanilir', () async {
    storage.settings = [
      const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 45,
        weekdays: {5},
        label: 'Cuma namazı',
      ),
    ];
    await schedule();
    expect(service.calls.first.title, 'Cuma namazı');
  });

  test('gunsuz satir her gun planlanir', () async {
    storage.settings = [
      const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 45,
      ),
    ];
    await schedule();
    final weekdays = service.calls
        .map((call) => call.scheduledTime.weekday)
        .toSet();
    expect(weekdays.length, greaterThan(1));
  });

  /// Ayni (gun, vakit, sapma) iki satirdan gelebilir: "her gun" ve "yalnizca
  /// Cuma". Kimlik ayni oldugu icin cuma gunu spesifik satir kazanmali.
  test('cakismada cuma gunu spesifik satir kazanir', () async {
    storage.settings = [
      const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 45,
      ),
      const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 45,
        weekdays: {5},
        label: 'Cuma namazı',
      ),
    ];
    await schedule();

    final friday = service.calls.firstWhere(
      (call) => call.scheduledTime.weekday == DateTime.friday,
    );
    expect(friday.title, 'Cuma namazı');

    // Planlama penceresi 7 gun oldugu icin hangi gunlerin dustugu bugune
    // bagli; cuma disi herhangi bir gun genel satiri tasimali.
    final others = service.calls.where(
      (call) => call.scheduledTime.weekday != DateTime.friday,
    );
    expect(others, isNotEmpty);
    expect(others.every((call) => call.title != 'Cuma namazı'), isTrue);
  });
}
