import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/utils/app_logger.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/notifications/domain/notification_settings_manager.dart';
import 'package:ezanvakti/features/notifications/domain/skip_manager.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:ezanvakti/presentation/services/data_loader_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// `tomorrow` iki yerin dayanagi: ana ekranin YARIN seridi (spec §6.1/6, gun
/// boyu gorunur) ve paletin gece dilimini ertesi Imsak'ta bitirmesi. Bos
/// kalirsa serit kaybolur ve palet aksam fallback'ine duser.
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
      skipManager: SkipManager(storage: storage),
      logger: AppLogger(),
    );
  }

  test('tomorrow saat kacta olursa olsun dolu gelir', () async {
    final storage = FakeStorage();
    await storage.init();
    final loader = buildLoader(storage, FakeProvider());

    final data = await loader.loadPrayerData(location);

    expect(data.today, isNotNull);
    expect(
      data.tomorrow,
      isNotNull,
      reason: 'YARIN seridi gun boyu gorunur; palet de bunu kullanir',
    );
    expect(
      data.tomorrow!.date.difference(data.today!.date).inDays,
      1,
      reason: 'tomorrow bugunun ertesi gunu olmali',
    );
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
        tomorrow: data.tomorrow,
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

  test('Suresi gecmis atlama kaydi yuklemede elenir', () async {
    final storage = FakeStorage();
    await storage.init();
    await storage.saveSkippedOccurrences([
      SkippedOccurrence(
        kind: SkipKind.alarm,
        reference: 'eski',
        fireAt: DateTime(2020, 1, 1),
      ),
    ]);
    final loader = buildLoader(storage, FakeProvider());

    final data = await loader.loadPrayerData(location);

    expect(data.skips, isEmpty);
  });
}
