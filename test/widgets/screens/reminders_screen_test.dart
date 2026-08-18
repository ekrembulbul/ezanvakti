import 'package:ezanvakti/core/models/mission_stop_event.dart';
import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/interfaces/notification_service.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/core/services/exact_alarm_service.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:ezanvakti/features/alarms/domain/alarms_manager.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/features/notifications/domain/notification_settings_manager.dart';
import 'package:ezanvakti/presentation/screens/reminders_screen.dart';
import 'package:ezanvakti/presentation/services/reminder_rescheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/fakes.dart';
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

  setUp(() async {
    storage = FakeStorage();
    await storage.init();
    appState = AppState();

    final locator = ServiceLocator();
    final notificationService = FakeNotificationService();
    final alarmService = _StubAlarmService();

    locator.register<LocalStorage>(storage);
    locator.register<NotificationService>(notificationService);
    locator.register<ExactAlarmService>(ExactAlarmService());
    locator.register<AlarmService>(alarmService);
    locator.register<AlarmsManager>(AlarmsManager(storage: storage));
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
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: wrapWithTheme(const RemindersScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Segment Alarmlar a gecince alarm bolumu gorunur', (
    tester,
  ) async {
    appState.setAlarms(const [sahur]);
    await pump(tester);

    expect(find.text('06:30'), findsNothing);

    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();

    expect(find.text('06:30'), findsOneWidget);
  });

  testWidgets('Alarm silinince AppState tazelenir', (tester) async {
    // LocalStorage tek tek kaydeder; toplu saveAlarms yok.
    await storage.saveAlarm(sahur);
    appState.setAlarms(const [sahur]);
    await pump(tester);

    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();

    // Alarm satirinda onay sorulmuyor; kaydirmak dogrudan siliyor.
    await tester.drag(find.text('06:30'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(
      appState.alarms,
      isEmpty,
      reason:
          'Mutasyon sonrasi AppState tazelenmezse ana ekrandaki SIRADAKI '
          'karti bayat alarm gosterir',
    );
  });

  testWidgets('Silinen alarm "Geri al" ile geri gelir', (tester) async {
    await storage.saveAlarm(sahur);
    appState.setAlarms(const [sahur]);
    await pump(tester);

    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('06:30'), const Offset(-400, 0));
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
}
