import 'package:ezanvakti/core/errors/prayer_times_errors.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/features/location/domain/location_service.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:ezanvakti/presentation/widgets/notifications/permission_warning_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../widgets/theme_harness.dart';

/// `docs/PLAN_CHECKLIST.md`'deki MVP kabul kriterlerinin uctan uca karsiligi.
///
/// Diger test dosyalari katmanlari tek tek dogruluyor; buradaki dort senaryo
/// katmanlari **birlestirip** kullanicinin gordugu davranisi kaniti sayiyor:
/// online ilk yukleme, ag kesildiginde onbellege dusme, konum degisimi ve
/// bildirim izni verilmemis hali.
void main() {
  const istanbul = Location(
    id: 'loc-istanbul',
    province: 'İstanbul',
    district: 'Kadıköy',
    latitude: 40.99,
    longitude: 29.03,
  );
  const ankara = Location(
    id: 'loc-ankara',
    province: 'Ankara',
    district: 'Çankaya',
    latitude: 39.92,
    longitude: 32.85,
  );

  /// Senaryolarin ortak kurulumu: bos depo, 30 gunluk veri uretebilen saglayici
  /// ve cagrilari sayan bildirim servisi.
  ({
    FakeStorage storage,
    FakeProvider provider,
    FakeNotificationService notifications,
    PrayerTimesRepository prayerTimes,
  })
  buildStack() {
    final storage = FakeStorage();
    final provider = FakeProvider();
    return (
      storage: storage,
      provider: provider,
      notifications: FakeNotificationService(),
      prayerTimes: PrayerTimesRepository(provider: provider, storage: storage),
    );
  }

  group('MVP kabul — online', () {
    test('Konum secilince bugunun vakitleri gorulebiliyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      await stack.storage.saveActiveLocation(istanbul);

      final today = atMidnight(DateTime.now());
      final times = await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
      );

      expect(times, hasLength(7));
      expect(
        stack.provider.fetchCount,
        1,
        reason: 'Onbellek bostu, ag denendi',
      );

      // Bugunun vakti tutarli sirada ve artik onbellekte.
      final first = times.first;
      expect(first.fajr.isBefore(first.dhuhr), isTrue);
      expect(first.dhuhr.isBefore(first.isha), isTrue);
      expect(
        await stack.storage.getDailyPrayerTime(
          locationId: istanbul.id,
          date: today,
        ),
        isNotNull,
      );
    });

    test('Aktif bildirim ayarlari icin bildirim planlaniyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      await stack.storage.saveNotificationSettings(const [
        NotificationSetting(prayerType: PrayerType.dhuhr, isActive: true),
        NotificationSetting(prayerType: PrayerType.asr, isActive: false),
      ]);

      final today = atMidnight(DateTime.now());
      final times = await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: today.add(const Duration(days: 6)),
      );

      final scheduler = NotificationScheduler(
        notificationService: stack.notifications,
        storage: stack.storage,
      );
      await scheduler.scheduleNotifications(
        location: istanbul,
        prayerTimes: times,
      );

      // Bildirim id'si sayisal; hangi vakit icin planlandigi ancak zamandan
      // okunur. Ogle 13:15, kapali olan Ikindi 17:09.
      expect(stack.notifications.scheduled, isNotEmpty);
      expect(
        stack.notifications.scheduled.every(
          (n) => n.scheduledTime.hour == 13 && n.scheduledTime.minute == 15,
        ),
        isTrue,
        reason: 'Yalnizca aktif ayar planlanmali, kapali olan degil',
      );
    });
  });

  group('MVP kabul — offline', () {
    test('Ag kesilince onbellekteki vakitler gosteriliyor', () async {
      final stack = buildStack();
      await stack.storage.init();

      final today = atMidnight(DateTime.now());
      final end = today.add(const Duration(days: 6));

      // Once online: onbellek dolar.
      await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: end,
      );
      expect(stack.provider.fetchCount, 1);

      // Sonra ag kesilir. forceRefresh ile ag zorlanir ki fallback yolu
      // gercekten calissin; onbellek dolu oldugu icin istisna kullaniciya
      // yansimamali.
      stack.provider.failWith = NetworkException('Baglanti yok');
      final offline = await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: end,
        forceRefresh: true,
      );

      expect(offline, hasLength(7));
      expect(stack.provider.fetchCount, 2, reason: 'Once ag denenmeli');
    });

    test('Onbellek de bossa hata kullaniciya iletiliyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      stack.provider.failWith = NetworkException('Baglanti yok');

      final today = atMidnight(DateTime.now());

      expect(
        () => stack.prayerTimes.getPrayerTimes(
          location: istanbul,
          startDate: today,
          endDate: today,
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('MVP kabul — konum degisimi', () {
    test('Konum degisince aktif konum ve bildirimler guncelleniyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      await stack.storage.saveActiveLocation(istanbul);
      await stack.storage.saveNotificationSettings(const [
        NotificationSetting(prayerType: PrayerType.dhuhr, isActive: true),
      ]);

      final today = atMidnight(DateTime.now());
      final end = today.add(const Duration(days: 6));

      final istanbulTimes = await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: end,
      );
      final scheduler = NotificationScheduler(
        notificationService: stack.notifications,
        storage: stack.storage,
      );
      await scheduler.scheduleNotifications(
        location: istanbul,
        prayerTimes: istanbulTimes,
      );
      expect(stack.notifications.scheduled, isNotEmpty);

      final locationService = LocationService(
        locationRepository: LocationRepository(storage: stack.storage),
        prayerTimesRepository: stack.prayerTimes,
        notificationService: stack.notifications,
      );
      await locationService.changeLocation(ankara);

      expect((await stack.storage.getActiveLocation())?.id, ankara.id);
      expect(
        stack.notifications.scheduled,
        isEmpty,
        reason: 'Eski konumun bekleyen bildirimleri iptal edilmeli',
      );

      // Yeni konumun vakitleriyle yeniden planlanabiliyor.
      final ankaraTimes = await stack.prayerTimes.getPrayerTimes(
        location: ankara,
        startDate: today,
        endDate: end,
      );
      await scheduler.scheduleNotifications(
        location: ankara,
        prayerTimes: ankaraTimes,
      );
      expect(stack.notifications.scheduled, isNotEmpty);
    });

    test('Ayni konuma gecis gereksiz iptal tetiklemiyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      await stack.storage.saveActiveLocation(istanbul);

      final locationService = LocationService(
        locationRepository: LocationRepository(storage: stack.storage),
        prayerTimesRepository: stack.prayerTimes,
        notificationService: stack.notifications,
      );
      await locationService.changeLocation(istanbul);

      expect(stack.notifications.cancelAllCount, 0);
    });

    test('Ag yokken konum degisimi eldeki vakitleri silmiyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      await stack.storage.saveActiveLocation(istanbul);

      final today = atMidnight(DateTime.now());
      final end = today.add(const Duration(days: 6));

      await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: end,
      );

      // Konum degisti ama ag yok. LocationMonitorService artik onbellegi
      // onden silmiyor; yukleme forceRefresh ile yapilir ve yeni veri
      // gelmezse eskisi yerinde kalir.
      stack.provider.failWith = NetworkException('Baglanti yok');
      final afterChange = await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: end,
        forceRefresh: true,
      );

      expect(
        afterChange,
        hasLength(7),
        reason: 'Onbellek yeni veri gelmeden silinmemeli',
      );
    });
  });

  group('MVP kabul — bildirim izni yok', () {
    testWidgets(
      'Izin yoksa kullanici uyarilir ve izin istemeye yonlendirilir',
      (tester) async {
        final notifications = FakeNotificationService()
          ..permissionGranted = false;
        bool? reportedResult;

        await tester.pumpWidget(
          wrapWithTheme(
            PermissionWarningCard(
              onRequestPermission: notifications.requestPermission,
              onPermissionGranted: (granted) => reportedResult = granted,
            ),
          ),
        );

        expect(find.byKey(const Key('permission_warning')), findsOneWidget);
        expect(
          find.text('Bildirim almak için izin vermeniz gerekiyor.'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('request_permission_button')));
        await tester.pumpAndSettle();

        expect(notifications.permissionRequestCount, 1);
        expect(
          reportedResult,
          isFalse,
          reason: 'Izin reddedilince ekran bunu ogrenmeli, sessiz kalmamali',
        );
      },
    );

    test('Izin reddedilmis olsa da eski bildirimler temizleniyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      stack.notifications.permissionGranted = false;

      // Ayar listesi bos: planlanacak bildirim yok ama eskiler iptal edilmeli.
      final scheduler = NotificationScheduler(
        notificationService: stack.notifications,
        storage: stack.storage,
      );
      await scheduler.scheduleNotifications(
        location: istanbul,
        prayerTimes: const [],
      );

      expect(stack.notifications.scheduled, isEmpty);
      expect(stack.notifications.cancelAllCount, 1);
    });
  });
}
