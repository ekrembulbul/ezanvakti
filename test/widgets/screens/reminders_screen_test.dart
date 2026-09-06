import 'package:ezanvakti/core/models/mission_stop_event.dart';
import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/interfaces/notification_service.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/alarm_theme.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/core/services/exact_alarm_service.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:ezanvakti/features/alarms/domain/alarms_manager.dart';
import 'package:ezanvakti/features/notifications/domain/skip_manager.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/features/notifications/domain/notification_settings_manager.dart';
import 'package:ezanvakti/presentation/screens/reminders_screen.dart';
import 'package:ezanvakti/presentation/screens/alarm_edit_screen.dart';
import 'package:ezanvakti/presentation/services/reminder_rescheduler.dart';
import 'package:ezanvakti/presentation/services/reminder_list_preferences.dart';
import 'package:ezanvakti/presentation/services/upcoming_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import '../../support/fakes.dart';
import '../../alarms/fakes/fake_alarm_service.dart';
import '../theme_harness.dart';

class _StubAlarmService implements AlarmService {
  @override
  Future<bool> isSupported() async => true;

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> cancelAllAlarms() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<MissionStopEvent> get missionStops => const Stream.empty();

  @override
  Future<List<MissionStopEvent>> consumeMissionEvents() async => const [];

  @override
  Future<void> beginMission(String alarmId) async {}

  @override
  Future<void> snoozeMission(String alarmId, int minutes) async {}

  @override
  Future<void> completeMission(String alarmId) async {}

  @override
  Future<void> abortMission(String alarmId) async {}
}

/// Planlamayı askıda tutan bildirim servisi.
///
/// Silme geri bildiriminin planlamayı beklemediğini doğrulamak için gerekli:
/// gerçek cihazda yavaş olan adım tam olarak budur.
class _BlockingNotificationService extends FakeNotificationService {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> cancelAllNotifications() async {
    await gate.future;
    await super.cancelAllNotifications();
  }
}

class _FailingNotificationService extends FakeNotificationService {
  @override
  Future<void> cancelAllNotifications() async =>
      throw StateError('Notification service unavailable');
}

class _FailingAlarmService extends FakeAlarmService {
  @override
  Future<void> scheduleAlarm({
    required String id,
    required DateTime scheduledTime,
    required String label,
    required String soundId,
    required bool vibrate,
    required bool snoozeEnabled,
    required int snoozeMinutes,
    required AlarmTheme theme,
    required AlarmMission mission,
    required int missionLevel,
    required Map<String, dynamic> chainConfig,
    List<int> repeatWeekdays = const [],
  }) async => throw StateError('Alarm service unavailable');
}

void main() {
  const sahur = Alarm(
    id: 'sahur',
    kind: AlarmKind.fixed,
    label: 'Sahur',
    hour: 6,
    minute: 30,
  );

  late FakeStorage storage;
  late AppState appState;

  void register({
    FakeNotificationService? notifications,
    AlarmService? alarms,
  }) {
    final notificationService = notifications ?? FakeNotificationService();
    final locator = ServiceLocator();
    final alarmService = alarms ?? _StubAlarmService();

    locator.register<LocalStorage>(storage);
    locator.register<NotificationService>(notificationService);
    locator.register<ExactAlarmService>(ExactAlarmService());
    locator.register<AlarmService>(alarmService);
    locator.register<AlarmsManager>(AlarmsManager(storage: storage));
    locator.register<SkipManager>(SkipManager(storage: storage));
    locator.register<NotificationSettingsManager>(
      NotificationSettingsManager(storage: storage),
    );
    locator.register<ReminderRescheduler>(
      ReminderRescheduler(
        notificationScheduler: NotificationScheduler(
          notificationService: notificationService,
          storage: storage,
        ),
        alarmScheduler: AlarmScheduler(
          alarmService: alarmService,
          storage: storage,
        ),
      ),
    );
  }

  setUp(() async {
    storage = FakeStorage();
    await storage.init();
    appState = AppState();
    register();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithTheme(const RemindersScreen(), appState: appState),
    );
    await tester.pumpAndSettle();
  }

  for (final alarmFails in [true, false]) {
    testWidgets(
      'Bildirim hatasında alarm durum uyarısı yenilenir (alarmFails=$alarmFails)',
      (tester) async {
        register(
          notifications: _FailingNotificationService(),
          alarms: alarmFails ? _FailingAlarmService() : FakeAlarmService(),
        );
        await storage.saveAlarm(sahur);
        if (!alarmFails) {
          await storage.saveAlarmScheduleFailures({
            'sahur': 'Previous failure',
          });
        }
        appState.setAlarms(const [sahur]);
        appState.setActiveLocation(
          const Location(
            id: 'test',
            province: 'Test',
            district: 'Test',
            latitude: 0,
            longitude: 0,
          ),
        );
        final date = DateTime.now().add(const Duration(days: 1));
        DateTime at(int hour) =>
            DateTime(date.year, date.month, date.day, hour);
        appState.setPrayerTimes([
          PrayerTime(
            date: at(0),
            fajr: at(5),
            sunrise: at(6),
            dhuhr: at(13),
            asr: at(16),
            maghrib: at(19),
            isha: at(21),
          ),
        ]);
        await pump(tester);
        await tester.tap(find.text('Alarmlar'));
        await tester.pumpAndSettle();
        final warning = find.textContaining('Kurulamadı');
        expect(warning, alarmFails ? findsNothing : findsOneWidget);
        // İki toggle tek planlamada birleşir; alarm yeniden açık ve kurulmuş olmalı.
        await tester.tap(find.byType(Switch));
        await tester.pump();
        await tester.tap(find.byType(Switch));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(warning, alarmFails ? findsOneWidget : findsNothing);
      },
    );
  }

  testWidgets('Segment Alarmlar a gecince alarm bolumu gorunur', (
    tester,
  ) async {
    appState.setAlarms(const [sahur]);
    await pump(tester);

    expect(find.textContaining('06:30'), findsNothing);

    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('06:30'), findsOneWidget);
  });

  testWidgets(
    'Alarm sırası sürüklenir, yeniden açılınca korunur ve planlamayı değiştirmez',
    (tester) async {
      const later = Alarm(
        id: 'later',
        kind: AlarmKind.fixed,
        label: 'İkinci',
        hour: 8,
        minute: 15,
      );
      final notifications = FakeNotificationService();
      register(notifications: notifications);
      appState.setAlarms(const [sahur, later]);
      await pump(tester);
      await tester.tap(find.text('Alarmlar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder_sort_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sırayı düzenle'));
      await tester.pumpAndSettle();
      final handle = find.byKey(const ValueKey('reminder-drag-0'));
      expect(handle, findsOneWidget);
      await tester.timedDrag(
        handle,
        const Offset(0, 220),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.textContaining('08:15')).dy,
        lessThan(tester.getTopLeft(find.textContaining('06:30')).dy),
      );
      final preferences = await ReminderListPreferencesStore(
        storage: storage,
      ).load(ReminderListKind.alarms);
      expect(preferences.customOrder, ['later', 'sahur']);
      expect(notifications.cancelAllCount, 0);

      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      await tester.tap(find.text('Alarmlar'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.textContaining('08:15')).dy,
        lessThan(tester.getTopLeft(find.textContaining('06:30')).dy),
      );
    },
  );

  testWidgets(
    'Bildirim özel sırası otomatik ad sıralaması sonrasında korunur',
    (tester) async {
      const morning = NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        label: 'A hazırlık',
      );
      const noon = NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        label: 'Z hazırlık',
      );
      appState.setNotificationSettings(const [morning, noon]);
      await pump(tester);
      await tester.tap(find.byKey(const Key('reminder_sort_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sırayı düzenle'));
      await tester.pumpAndSettle();
      await tester.timedDrag(
        find.byKey(const ValueKey('reminder-drag-0')),
        const Offset(0, 160),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      final preferences = await ReminderListPreferencesStore(
        storage: storage,
      ).load(ReminderListKind.notifications);
      expect(preferences.customOrder, [
        notificationKey(noon),
        notificationKey(morning),
      ]);

      await tester.tap(find.byKey(const Key('reminder_reorder_done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reminder_sort_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reminder-sort-name')));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('A hazırlık')).dy,
        lessThan(tester.getTopLeft(find.text('Z hazırlık')).dy),
      );
      await tester.tap(find.byKey(const Key('reminder_sort_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reminder-sort-custom')));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Z hazırlık')).dy,
        lessThan(tester.getTopLeft(find.text('A hazırlık')).dy),
      );
    },
  );

  testWidgets('Alarm silinince AppState tazelenir', (tester) async {
    // LocalStorage tek tek kaydeder; toplu saveAlarms yok.
    await storage.saveAlarm(sahur);
    appState.setAlarms(const [sahur]);
    await pump(tester);

    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();

    // Alarm satirinda onay sorulmuyor; kaydirmak dogrudan siliyor.
    await tester.drag(find.textContaining('06:30'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(
      appState.alarms,
      isEmpty,
      reason:
          'Mutasyon sonrasi AppState tazelenmezse ana ekrandaki SIRADAKI '
          'karti bayat alarm gosterir',
    );
  });

  testWidgets(
    'Uzun basma kopyayı düzenlemeye açar, kaydetmeden kayıt oluşmaz',
    (tester) async {
      await storage.saveAlarm(sahur);
      appState.setAlarms(const [sahur]);
      await pump(tester);
      await tester.tap(find.text('Alarmlar'));
      await tester.pumpAndSettle();

      await tester.longPress(find.textContaining('06:30'));
      await tester.pumpAndSettle();
      expect(find.text('Kopyala'), findsOneWidget);
      await tester.tap(find.text('Kopyala'));
      await tester.pumpAndSettle();

      final draft = tester
          .widget<AlarmEditScreen>(find.byType(AlarmEditScreen))
          .alarm!;
      expect(draft.id, isNot(sahur.id));
      expect(draft.label, 'Sahur (kopya)');
      expect(draft.hour, 6);
      expect(draft.minute, 30);
      expect(await storage.getAlarms(), [sahur]);

      Navigator.of(tester.element(find.byType(AlarmEditScreen))).pop();
      await tester.pumpAndSettle();
      expect(appState.alarms, [sahur]);
      expect(await storage.getAlarms(), [sahur]);
    },
  );

  testWidgets('Kopyayı kaydetmek özgün alarmı koruyarak ikinci alarm ekler', (
    tester,
  ) async {
    await storage.saveAlarm(sahur);
    appState.setAlarms(const [sahur]);
    await pump(tester);
    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();
    await tester.longPress(find.textContaining('06:30'));
    await tester.pumpAndSettle();
    expect(find.text('Kopyala'), findsOneWidget);
    await tester.tap(find.text('Kopyala'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(appState.alarms, hasLength(2));
    expect(appState.alarms, contains(sahur));
    final copy = appState.alarms.singleWhere((alarm) => alarm.id != sahur.id);
    expect(copy.label, 'Sahur (kopya)');
    expect(copy.hour, 6);
    expect(copy.minute, 30);
    expect(await storage.getAlarms(), hasLength(2));
  });

  testWidgets('Silinen alarm "Geri al" ile geri gelir', (tester) async {
    await storage.saveAlarm(sahur);
    appState.setAlarms(const [sahur]);
    await pump(tester);

    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();

    await tester.drag(find.textContaining('06:30'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(appState.alarms, isEmpty);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();

    expect(appState.alarms.map((a) => a.id), [sahur.id]);
  });

  testWidgets('Bildirim silinince AppState tazelenir', (tester) async {
    const dhuhr = NotificationSetting(
      prayerType: PrayerType.dhuhr,
      isActive: true,
      minutesBefore: 0,
    );
    await storage.saveNotificationSettings(const [dhuhr]);
    appState.setNotificationSettings(const [dhuhr]);
    await pump(tester);

    // Onay sorulmuyor; kaydirmak dogrudan siliyor.
    await tester.drag(find.text('Öğle'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(
      appState.notificationSettings,
      isEmpty,
      reason:
          'NotificationSettingsScreen hic pop(true) yapmadigi icin bu tazeleme '
          'eskiden hic calismiyordu',
    );

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();

    expect(
      appState.notificationSettings.map((s) => s.prayerType),
      [PrayerType.dhuhr],
      reason: 'Silme onaysiz oldugu icin geri alma calismak zorunda',
    );
  });

  testWidgets(
    'Ana sayfada atlanan Cuma bildirimi listede aynı örnekten geri açılır',
    (tester) async {
      final now = DateTime.now();
      final daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;
      final date = now.add(
        Duration(days: daysUntilFriday == 0 ? 7 : daysUntilFriday),
      );
      DateTime at(int hour, int minute) =>
          DateTime(date.year, date.month, date.day, hour, minute);
      final day = PrayerTime(
        date: at(0, 0),
        fajr: at(5, 0),
        sunrise: at(6, 30),
        dhuhr: at(13, 0),
        asr: at(16, 30),
        maghrib: at(20, 0),
        isha: at(21, 30),
      );
      final setting = NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 45,
        weekdays: const {DateTime.friday},
        label: 'Cuma namazı',
      );
      final skip = notificationOccurrence((
        setting: setting,
        prayerDate: day.date,
        time: at(12, 15),
      ));
      await storage.saveNotificationSettings([setting]);
      await storage.saveSkippedOccurrences([skip]);
      appState.setNotificationSettings([setting]);
      appState.setPrayerTimes([day]);
      appState.setSkips({skip});
      await pump(tester);
      expect(find.text('Cuma namazı'), findsOneWidget);
      expect(find.textContaining('12:15'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(appState.skips, isEmpty);
      expect(await storage.getSkippedOccurrences(), isEmpty);
    },
  );

  testWidgets('"Geri al" planlamayi beklemeden hemen gorunur', (tester) async {
    final blocking = _BlockingNotificationService();
    register(notifications: blocking);

    await storage.saveAlarm(sahur);
    appState.setAlarms(const [sahur]);
    await pump(tester);

    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();

    await tester.drag(find.textContaining('06:30'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(
      find.text('Geri al'),
      findsOneWidget,
      reason:
          'Planlama saniyeler surebiliyor; geri bildirim onun arkasinda '
          'beklerse kullanici satir kayboldugundan cok sonra gorur',
    );

    // Planlama beklemesi dolsun; askidaki timer test sonunda kalmasin.
    await tester.pump(const Duration(milliseconds: 600));
    blocking.gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Alarm kapatilinca "Yalnizca bu sefer" teklif edilir', (
    tester,
  ) async {
    await storage.saveAlarm(sahur);
    appState.setAlarms(const [sahur]);
    await pump(tester);

    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(appState.alarms.single.isActive, isFalse, reason: 'once kapanir');
    expect(find.text('Yalnızca bu sefer'), findsOneWidget);

    await tester.tap(find.text('Yalnızca bu sefer'));
    await tester.pumpAndSettle();

    expect(
      appState.alarms.single.isActive,
      isTrue,
      reason: 'tek seferlik atlama kalici kapatma degil; alarm geri acilir',
    );
    expect(
      appState.skips,
      hasLength(1),
      reason: 'yalnizca siradaki calis atlanir',
    );
    expect(appState.skips.single.kind, SkipKind.alarm);
    expect(appState.skips.single.reference, sahur.id);
  });

  testWidgets('Kapatma cubugu dokunulmazsa kendiliginden kalkar', (
    tester,
  ) async {
    await storage.saveAlarm(sahur);
    appState.setAlarms(const [sahur]);
    await pump(tester);

    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Yalnızca bu sefer'), findsOneWidget);

    // Sure + cikis animasyonu.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 750));

    expect(
      find.text('Yalnızca bu sefer'),
      findsNothing,
      reason:
          "Eylemli snackbar Flutter'da varsayilan olarak kalici; kullanici "
          'dokunmazsa cubuk hic kapanmiyordu',
    );
  });
}
