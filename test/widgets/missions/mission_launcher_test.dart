import 'dart:async';

import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/core/models/mission_stop_event.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:ezanvakti/features/alarms/domain/alarms_manager.dart';
import 'package:ezanvakti/features/alarms/domain/mission_coordinator.dart';
import 'package:ezanvakti/presentation/screens/alarm_stop_screen.dart';
import 'package:ezanvakti/presentation/screens/mission_launcher.dart';
import 'package:ezanvakti/presentation/screens/mission_screen.dart';
import 'package:ezanvakti/presentation/widgets/missions/abort_dialog.dart';
import 'package:ezanvakti/presentation/widgets/missions/math_mission.dart';
import 'package:ezanvakti/presentation/widgets/missions/qr_mission.dart';
import 'package:ezanvakti/presentation/widgets/missions/shake_mission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../alarms/fakes/fake_alarm_service.dart';
import '../../support/fakes.dart';
import '../theme_harness.dart';

/// Görev ekranını **açan** katmanın testleri: hangi durumda açılır, hangi
/// durumda açılmaz, tamamlanınca/ertelenince/iptal edilince native tarafa ne
/// gider. Görev gövdelerinin kendi testleri ayrı dosyalarda.
void main() {
  late FakeStorage storage;
  late FakeAlarmService alarmService;
  late AppState appState;
  late MissionCoordinator coordinator;

  const mathAlarm = Alarm(
    id: 'sahur',
    kind: AlarmKind.fixed,
    label: 'Sahur',
    hour: 6,
    minute: 30,
    mission: AlarmMission.math,
    missionLevel: 1,
    snoozeEnabled: true,
    snoozeMinutes: 5,
    maxSnoozes: 2,
  );

  // Sabit gecmis tarih kullanilamaz: StopGate artik 60 dk sonra oturumu
  // bayat sayip ekran acmiyor (Task 1). Testler "az once durdu" varsayar.
  final stoppedAt = DateTime.now();

  setUp(() async {
    storage = FakeStorage();
    await storage.init();
    alarmService = FakeAlarmService();
    appState = AppState();
    coordinator = MissionCoordinator(
      alarmService: alarmService,
      storage: storage,
    );

    final locator = ServiceLocator();
    locator.register<LocalStorage>(storage);
    locator.register<AlarmService>(alarmService);
    locator.register<AlarmsManager>(AlarmsManager(storage: storage));
    locator.register<MissionCoordinator>(coordinator);
    locator.register<AlarmScheduler>(
      AlarmScheduler(alarmService: alarmService, storage: storage),
    );
  });

  /// `_MissionHost` saniyelik bir sayaç çalıştırıyor; `pumpAndSettle` bu
  /// yüzden hiç durulmuyor. Kareler elle ilerletiliyor.
  Future<void> settle(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  late BuildContext hostContext;

  Future<void> pumpLauncher(WidgetTester tester) async {
    // Varsayilan 800x600 test yuzeyi telefon degil; gorev ekrani buyuk
    // olculere gecince govde gorunur alanin disina tasiyordu.
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox.expand();
          },
        ),
        appState: appState,
      ),
    );
    await tester.pump();
  }

  Future<void> open(WidgetTester tester) async {
    await pumpLauncher(tester);
    unawaited(openMissionIfPending(hostContext));
    await settle(tester);
  }

  /// Yeni akista hak varken once ara ekran geliyor; gorev testleri oradan
  /// gecer. Ekran yoksa hicbir sey yapmaz.
  Future<void> enterMission(WidgetTester tester) async {
    if (find.byKey(kStopPrimaryKey).evaluate().isEmpty) return;
    await tester.tap(find.byKey(kStopPrimaryKey));
    await settle(tester);
  }

  /// Ekrandaki soruyu okuyup cevaplar.
  ///
  /// Soru üretimi `_MissionHost` içinde `Random()` ile yapılıyor; testten
  /// tohumlanamadığı için doğru cevap ekrandan çıkarılıyor.
  Future<void> solveMath(WidgetTester tester) async {
    final pattern = RegExp(r'^(\d+) ([+−×]) (\d+)$');
    for (var guard = 0; guard < 6; guard++) {
      if (find.byKey(kMathSubmitKey).evaluate().isEmpty) return;

      int? answer;
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final match = pattern.firstMatch(text.data ?? '');
        if (match == null) continue;
        final a = int.parse(match.group(1)!);
        final b = int.parse(match.group(3)!);
        answer = switch (match.group(2)!) {
          '+' => a + b,
          '−' => a - b,
          _ => a * b,
        };
        break;
      }
      if (answer == null) fail('Soru ekranda bulunamadi');

      await tester.enterText(find.byKey(kMathFieldKey), '$answer');
      await tester.ensureVisible(find.byKey(kMathSubmitKey));
      await tester.tap(find.byKey(kMathSubmitKey));
      await settle(tester);
    }
    fail('Gorev 6 soruda bitmedi');
  }

  group('Ekran ne zaman acilir', () {
    testWidgets('Bekleyen durdurma olayi gorev ekranini acar', (tester) async {
      await storage.saveAlarm(mathAlarm);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: mathAlarm.id, stoppedAt: stoppedAt),
      ];

      await open(tester);
      await enterMission(tester);

      expect(find.byType(MissionScreen), findsOneWidget);
      expect(find.byType(MathMission), findsOneWidget);
      expect(
        alarmService.begun,
        [mathAlarm.id],
        reason: 'nobetci grace suresinden gorev suresine tasinmali',
      );

      await solveMath(tester);
      expect(find.byType(MissionScreen), findsNothing);
    });

    testWidgets('Ertelenmis oturumda ekran acilmaz', (tester) async {
      await storage.saveAlarm(mathAlarm);
      await storage.saveMissionSession(
        MissionSession(
          alarmId: mathAlarm.id,
          firedAt: stoppedAt,
          snoozedUntil: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );

      await open(tester);
      await enterMission(tester);

      expect(
        find.byType(MissionScreen),
        findsNothing,
        reason: 'ortada calan alarm yok; gorev bir sonraki calista sorulur',
      );
      expect(
        appState.missionSession?.snoozedUntil,
        isNotNull,
        reason:
            'Oturum AppStatee yazilmazsa ertelenmis gorevli alarm satirdan '
            'kapatilabilir ve atlanabilir hale geliyor',
      );
    });

    testWidgets('Oturum yoksa ekran acilmaz', (tester) async {
      await storage.saveAlarm(mathAlarm);

      await open(tester);
      await enterMission(tester);

      expect(find.byType(MissionScreen), findsNothing);
      expect(alarmService.begun, isEmpty);
    });

    testWidgets('Alarm silinmisse zincir kapatilir', (tester) async {
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: 'silinmis', stoppedAt: stoppedAt),
      ];

      await open(tester);
      await enterMission(tester);

      expect(find.byType(MissionScreen), findsNothing);
      expect(
        alarmService.completed,
        ['silinmis'],
        reason: 'zincir kapanmazsa telefon olmayan bir gorevi bekler',
      );
    });

    testWidgets('Gorevsiz, erteleme kapali alarmda zincir kapatilir', (
      tester,
    ) async {
      const plain = Alarm(
        id: 'duz',
        kind: AlarmKind.fixed,
        hour: 7,
        snoozeEnabled: false,
      );
      await storage.saveAlarm(plain);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: plain.id, stoppedAt: stoppedAt),
      ];

      await open(tester);
      await enterMission(tester);

      expect(find.byType(MissionScreen), findsNothing);
      expect(alarmService.completed, [plain.id]);
    });

    testWidgets('Ekran acikken ikinci cagri yeni ekran acmaz', (tester) async {
      await storage.saveAlarm(mathAlarm);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: mathAlarm.id, stoppedAt: stoppedAt),
      ];

      await open(tester);
      await enterMission(tester);
      expect(find.byType(MissionScreen), findsOneWidget);

      unawaited(openMissionIfPending(hostContext));
      await settle(tester);

      // Ust uste yigilan ekran `find` ile gorunmez: Overlay, opak bir girdinin
      // altindakileri hic insa etmiyor. Her `_MissionHost` acilista native
      // tarafa `begin` diyor; sayac yigilmayi ele veriyor.
      expect(
        alarmService.begun,
        [mathAlarm.id],
        reason:
            'Ust uste acilan ekranlarin her biri kendi geri sayimini '
            'baslatiyor ve Ertele alttaki eski ekrani ortaya cikariyordu',
      );

      await solveMath(tester);
      expect(
        find.byType(MissionScreen),
        findsNothing,
        reason: 'gorev bitince altta bekleyen ikinci bir ekran kalmamali',
      );
    });
  });

  group('Gorev tipine gore govde', () {
    Future<void> openWith(WidgetTester tester, Alarm alarm) async {
      await storage.saveAlarm(alarm);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: alarm.id, stoppedAt: stoppedAt),
      ];
      await open(tester);
      await enterMission(tester);
    }

    /// Acil çıkışla kapatır: shake ve QR gövdeleri testte tamamlanamıyor
    /// (ivmeölçer ve kamera yok), ekranın açık kalması ise sayacı testin
    /// sonuna taşırdı.
    Future<void> abortOut(WidgetTester tester) async {
      await tester.tap(find.byKey(kMissionAbortKey));
      await settle(tester);
      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(kAbortHoldKey)),
      );
      await tester.pump(const Duration(seconds: 4));
      await hold.up();
      await settle(tester);
    }

    testWidgets('Sallama gorevi sallama govdesini acar', (tester) async {
      await openWith(
        tester,
        mathAlarm.copyWith(id: 'salla', mission: AlarmMission.shake),
      );

      expect(find.byType(ShakeMission), findsOneWidget);
      expect(find.byType(MathMission), findsNothing);

      await abortOut(tester);
    });

    testWidgets('Sayac ilerlerken gorev govdesi yeniden kurulmaz', (
      tester,
    ) async {
      await openWith(
        tester,
        mathAlarm.copyWith(
          id: 'qrsabit',
          mission: AlarmMission.qr,
          qrPayload: 'mutfak-kapisi',
        ),
      );

      final before = tester.widget<QrMission>(find.byType(QrMission));
      await tester.pump(const Duration(seconds: 3));
      final after = tester.widget<QrMission>(find.byType(QrMission));

      expect(
        identical(before, after),
        isTrue,
        reason:
            'Sayac saniyede bir setState cagiriyor; govde her karede yeniden '
            'yaratilinca QR kamera onizlemesi doniyordu',
      );

      await abortOut(tester);
    });

    testWidgets('QR gorevi QR govdesini acar', (tester) async {
      await openWith(
        tester,
        mathAlarm.copyWith(
          id: 'qr',
          mission: AlarmMission.qr,
          qrPayload: 'mutfak-kapisi',
        ),
      );

      expect(find.byType(QrMission), findsOneWidget);

      await abortOut(tester);
    });

    testWidgets('Kodsuz QR gorevinde yol gosterilir', (tester) async {
      await openWith(
        tester,
        mathAlarm.copyWith(id: 'qrbos', mission: AlarmMission.qr),
      );

      expect(find.textContaining('kayıtlı bir QR kod yok'), findsOneWidget);

      await abortOut(tester);
    });
  });

  group('Ekrandan cikis yollari', () {
    /// Cihazda gorulen hata: Gunes alarminin QR gorevi tamamlaninca native
    /// taraf her seyi iptal etti ve ayni gune kurulu 08:45 hic calmadi.
    /// Gorev bitince alarmlar yeniden kurulmali.
    testWidgets('Gorev tamamlaninca alarmlar yeniden planlanir', (
      tester,
    ) async {
      await storage.saveAlarm(mathAlarm);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: mathAlarm.id, stoppedAt: stoppedAt),
      ];

      await open(tester);
      await enterMission(tester);
      expect(alarmService.scheduled, isEmpty);

      await solveMath(tester);

      expect(alarmService.completed, [mathAlarm.id]);
      expect(
        alarmService.scheduled,
        [mathAlarm.id],
        reason: 'zincir kapaninca bir sonraki calis yeniden kurulmali',
      );
    });

    /// Erteleme aktif nobetciyi ileri kuruyor; yeniden planlama once her seyi
    /// iptal ettigi icin ertelemeden sonra cagrilirsa nobetci silinir ve
    /// erteleme sessizce kaybolur.
    testWidgets('Ertelemede alarmlar yeniden planlanmaz', (tester) async {
      await storage.saveAlarm(mathAlarm);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: mathAlarm.id, stoppedAt: stoppedAt),
      ];

      await open(tester);
      await enterMission(tester);
      await tester.tap(find.byKey(kMissionSnoozeKey));
      await settle(tester);

      expect(alarmService.snoozed, isNotEmpty);
      expect(alarmService.scheduled, isEmpty);
      expect(alarmService.cancelAllCount, 0);
    });

    const plainSnooze = Alarm(
      id: 'is',
      kind: AlarmKind.fixed,
      hour: 8,
      minute: 45,
      label: 'İş',
      snoozeEnabled: true,
      snoozeMinutes: 10,
      maxSnoozes: 1,
    );

    testWidgets('Gorevsiz alarmda ara ekran acilir', (tester) async {
      await storage.saveAlarm(plainSnooze);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: plainSnooze.id, stoppedAt: DateTime.now()),
      ];

      await open(tester);

      expect(find.byType(AlarmStopScreen), findsOneWidget);
      expect(find.text('Tamam'), findsOneWidget);
      expect(find.byType(MissionScreen), findsNothing);
      expect(alarmService.begun, isEmpty, reason: 'gorev yok, begin cagrilmaz');
    });

    testWidgets('Gorevsiz: Tamam oturumu kapatir ve alarmlari yeniden kurar', (
      tester,
    ) async {
      await storage.saveAlarm(plainSnooze);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: plainSnooze.id, stoppedAt: DateTime.now()),
      ];

      await open(tester);
      await tester.tap(find.byKey(kStopPrimaryKey));
      await settle(tester);

      expect(find.byType(AlarmStopScreen), findsNothing);
      expect(alarmService.completed, [plainSnooze.id]);
      expect(alarmService.scheduled, [plainSnooze.id]);
      expect(await storage.getMissionSession(), isNull);
    });

    testWidgets('Gorevsiz: Ertele sayar, yeniden kurmaz', (tester) async {
      await storage.saveAlarm(plainSnooze);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: plainSnooze.id, stoppedAt: DateTime.now()),
      ];

      await open(tester);
      await tester.tap(find.byKey(kStopSnoozeKey));
      await settle(tester);

      expect(find.byType(AlarmStopScreen), findsNothing);
      expect(alarmService.snoozed, [(id: plainSnooze.id, minutes: 10)]);
      expect(alarmService.scheduled, isEmpty);
      expect((await storage.getMissionSession())!.snoozeUsed, 1);
    });

    testWidgets('Gorevsiz: hak bitince ekran acilmaz, oturum kapanir', (
      tester,
    ) async {
      await storage.saveAlarm(plainSnooze);
      await storage.saveMissionSession(
        MissionSession(
          alarmId: plainSnooze.id,
          firedAt: DateTime.now(),
          snoozeUsed: 1,
        ),
      );
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: plainSnooze.id, stoppedAt: DateTime.now()),
      ];

      await open(tester);

      expect(find.byType(AlarmStopScreen), findsNothing);
      expect(alarmService.completed, [plainSnooze.id]);
      expect(alarmService.scheduled, [plainSnooze.id]);
    });

    testWidgets('Gorevsiz: bayat durdurma ekran acmaz', (tester) async {
      await storage.saveAlarm(plainSnooze);
      alarmService.pendingEvents = [
        MissionStopEvent(
          alarmId: plainSnooze.id,
          stoppedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      ];

      await open(tester);

      expect(find.byType(AlarmStopScreen), findsNothing);
      expect(alarmService.completed, [plainSnooze.id]);
    });

    /// Sayac gercek saati okuyor (DateTime.now), tester.pump sahte saati
    /// ilerletiyor; bu yuzden durdurma ani pencerenin son saniyesine konuyor:
    /// ekran acilir (bayat degil), ilk tik'te kalan sure sifira duser.
    testWidgets('Gorevsiz: sure dolunca ekran kendini kapatir', (tester) async {
      await storage.saveAlarm(plainSnooze);
      alarmService.pendingEvents = [
        MissionStopEvent(
          alarmId: plainSnooze.id,
          stoppedAt: DateTime.now().subtract(
            const Duration(seconds: MissionTuning.stopScreenSeconds - 1),
          ),
        ),
      ];

      await open(tester);
      expect(find.byType(AlarmStopScreen), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await settle(tester);

      expect(find.byType(AlarmStopScreen), findsNothing);
      expect(alarmService.completed, [plainSnooze.id]);
      expect(alarmService.scheduled, [plainSnooze.id]);
    });

    testWidgets('Gorevli, hak varken once ara ekran; Gorevi yap goreve gecer', (
      tester,
    ) async {
      await storage.saveAlarm(mathAlarm);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: mathAlarm.id, stoppedAt: DateTime.now()),
      ];

      await open(tester);
      expect(find.byType(AlarmStopScreen), findsOneWidget);
      expect(find.text('Görevi yap'), findsOneWidget);
      expect(alarmService.begun, isEmpty, reason: 'begin gorev ekraninda');

      await tester.tap(find.byKey(kStopPrimaryKey));
      await settle(tester);

      expect(find.byType(AlarmStopScreen), findsNothing);
      expect(find.byType(MissionScreen), findsOneWidget);
      expect(alarmService.begun, [mathAlarm.id]);
    });

    testWidgets('Gorevli, hak yokken dogrudan gorev ekrani', (tester) async {
      await storage.saveAlarm(mathAlarm);
      await storage.saveMissionSession(
        MissionSession(
          alarmId: mathAlarm.id,
          firedAt: DateTime.now(),
          snoozeUsed: 2,
        ),
      );
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: mathAlarm.id, stoppedAt: DateTime.now()),
      ];

      await open(tester);

      expect(find.byType(AlarmStopScreen), findsNothing);
      expect(find.byType(MissionScreen), findsOneWidget);
    });

    testWidgets('Gorevli: ara ekranda Ertele sayar ve kapatir', (tester) async {
      await storage.saveAlarm(mathAlarm);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: mathAlarm.id, stoppedAt: DateTime.now()),
      ];

      await open(tester);
      await tester.tap(find.byKey(kStopSnoozeKey));
      await settle(tester);

      expect(find.byType(AlarmStopScreen), findsNothing);
      expect(find.byType(MissionScreen), findsNothing);
      expect(alarmService.snoozed, [(id: mathAlarm.id, minutes: 5)]);
      expect(alarmService.scheduled, isEmpty);
    });

    testWidgets('Gorev tamamlaninca native temizlenir', (tester) async {
      await storage.saveAlarm(mathAlarm);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: mathAlarm.id, stoppedAt: stoppedAt),
      ];

      await open(tester);
      await enterMission(tester);
      await solveMath(tester);

      expect(alarmService.completed, [mathAlarm.id]);
      expect(await storage.getMissionSession(), isNull);
    });

    testWidgets('Ertele alarmi erteler ve ekrani kapatir', (tester) async {
      await storage.saveAlarm(mathAlarm);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: mathAlarm.id, stoppedAt: stoppedAt),
      ];

      await open(tester);
      await enterMission(tester);
      expect(find.byKey(kMissionSnoozeKey), findsOneWidget);

      await tester.tap(find.byKey(kMissionSnoozeKey));
      await settle(tester);

      expect(alarmService.snoozed, [
        (id: mathAlarm.id, minutes: mathAlarm.snoozeMinutes),
      ]);
      expect(find.byType(MissionScreen), findsNothing);
      final session = await storage.getMissionSession();
      expect(session?.snoozeUsed, 1);
    });

    testWidgets('Acil cikis kademeyi yukseltir ve ekrani kapatir', (
      tester,
    ) async {
      await storage.saveAlarm(mathAlarm);
      alarmService.pendingEvents = [
        MissionStopEvent(alarmId: mathAlarm.id, stoppedAt: stoppedAt),
      ];

      await open(tester);
      await enterMission(tester);
      await tester.tap(find.byKey(kMissionAbortKey));
      await settle(tester);

      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(kAbortHoldKey)),
      );
      await tester.pump(const Duration(seconds: 4));
      await hold.up();
      await settle(tester);

      expect(alarmService.aborted, [mathAlarm.id]);
      expect(find.byType(MissionScreen), findsNothing);
      expect(
        (await storage.getAbortState()).level,
        1,
        reason: 'bir dahaki acil cikis daha zor olmali',
      );
    });
  });
}
