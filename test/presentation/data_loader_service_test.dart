import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/utils/app_logger.dart';
import 'package:ezanvakti/features/notifications/domain/notification_settings_manager.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:ezanvakti/presentation/services/data_loader_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// [PrayerData]'nin iki farkli "yarin" alani var ve karistirilmasi sessiz bir
/// hataya yol aciyor: `tomorrow` sunum kuralina bagli (yalnizca Yatsi'dan
/// sonra dolu), `nextDay` ise palet icin her zaman dolu olmali.
void main() {
  const location = Location(
    id: 'loc-1',
    province: 'İstanbul',
    district: 'Kadıköy',
    latitude: 40.99,
    longitude: 29.03,
  );

  DataLoaderService buildLoader(FakeStorage storage, FakeProvider provider) {
    return DataLoaderService(
      prayerTimesRepository: PrayerTimesRepository(
        provider: provider,
        storage: storage,
      ),
      notificationService: FakeNotificationService(),
      settingsManager: NotificationSettingsManager(storage: storage),
      logger: AppLogger(),
    );
  }

  test('nextDay saat kacta olursa olsun dolu gelir', () async {
    final storage = FakeStorage();
    await storage.init();
    final loader = buildLoader(storage, FakeProvider());

    final data = await loader.loadPrayerData(location);

    expect(data.today, isNotNull);
    expect(
      data.nextDay,
      isNotNull,
      reason: 'Gece diliminin ertesi İmsak\'ta bittigini palet buradan ogrenir',
    );
    expect(
      data.nextDay!.date.difference(data.today!.date).inDays,
      1,
      reason: 'nextDay bugunun ertesi gunu olmali',
    );
  });

  test('Yatsi gecmediyse tomorrow bos kalir', () async {
    final storage = FakeStorage();
    await storage.init();
    final loader = buildLoader(storage, FakeProvider());

    final data = await loader.loadPrayerData(location);

    // FakeProvider Yatsi'yi 22:01'e koyuyor. Test bu saatten once kosuyorsa
    // "YARIN" seridi gorunmemeli; sonra kosuyorsa gorunmeli.
    final afterIsha = DateTime.now().isAfter(data.today!.isha);
    expect(data.tomorrow != null, afterIsha);
  });

  test('Palet, yuklenen vakitlerle dogru dilimi cozuyor', () async {
    final storage = FakeStorage();
    await storage.init();
    final loader = buildLoader(storage, FakeProvider());

    final data = await loader.loadPrayerData(location);
    final today = data.today!;

    // Ogle ile Ikindi arasi KURSUNI (afternoon) olmali; besleme yapilmazsa
    // resolveDayPhase veri bulamayip aksam fallback'ine duser.
    final betweenDhuhrAndAsr = today.dhuhr.add(const Duration(minutes: 30));
    expect(
      resolveDayPhase(
        today: today,
        tomorrow: data.nextDay,
        now: betweenDhuhrAndAsr,
      ),
      DayPhase.afternoon,
    );

    // Besleme olmadigindaki hal: fallback.
    expect(
      resolveDayPhase(today: null, tomorrow: null, now: betweenDhuhrAndAsr),
      fallbackDayPhase,
    );
  });
}
