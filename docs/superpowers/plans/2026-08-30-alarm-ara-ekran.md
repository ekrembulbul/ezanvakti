# Alarm Ara Ekranı Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alarm durdurulunca açılan büyük düğmeli karar ekranı; görevsiz alarmlarda erteleme sayısını uygulanabilir kılar.

**Architecture:** Mevcut oturum/koordinatör/nöbetçi altyapısı iki alarm tipini de taşır. Kapı kararı saf bir fonksiyona (`StopGate`) alınır, ekran (`AlarmStopScreen`) salt sunumdur, `mission_launcher.dart` ikisini bağlar. Native tarafta görevsiz alarm da `stopIntent` alır; durdurmada nöbetçi kurma kararı saf `MissionStopPolicy`'ye çekilir.

**Tech Stack:** Flutter/Dart, Swift + AlarmKit, XCTest.

**Spec:** `docs/superpowers/specs/2026-08-30-alarm-ara-ekran-design.md`

## Global Constraints

- Süreler (spec D12): `MissionTuning.graceSeconds` = **30**, `MissionTuning.stopScreenSeconds` = **45**.
- Görevsizde durdurma **kesindir**: nöbetçi kurulmaz (D3). Görevlide ara ekranda süre dolarsa alarm döner (D4).
- Ara ekran yalnızca gerçek bir seçim varsa açılır (D6); kapı tablosu spec §4.
- `stopIntent` koşulu: `missionEnabled || snoozeEnabled` (D2). Görevsiz + erteleme açıkta `.countdown` kalkar.
- `MissionSession.stoppedAt` her yeni durdurma olayında güncellenir (D9); JSON anahtarı `stopped_at`, eski kayıtta `firedAt`'e düşer.
- Görsel dil görev ekranıyla aynı: `kMissionButtonHeight` (64), `kMissionButtonRadius` (16), `kMissionButtonFontSize` (19), `AppTypography.counter` (D13).
- Ekran `fullscreenDialog`, `PopScope(canPop: false)` (D15).
- Görev ekranındaki Ertele düğmesi **kalır** (D16).
- Kullanıcıya görünen metinler Türkçe sabit. Commit mesajları ASCII.
- Kod `dev` dalına yazılır (kullanıcı kararı).

**Test komutları:**

```bash
flutter analyze && flutter test
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17'
flutter build ios --no-codesign
```

**pbxproj yardımcısı** (Swift dosyası eklemek için):
`/private/tmp/claude-501/-Users-ekrem-projects-ezanvakti/67e9b7d1-044b-4ef9-86ee-6d0e53c0d3b1/scratchpad/pbxadd.py`
— `--group Runner --path Runner --targets runner` ve `--group RunnerTests --path RunnerTests --targets tests`. Betik yoksa dosya Xcode'dan ilgili target'a eklenir.

---

### Task 1: Süreler

**Files:**
- Modify: `lib/core/config/mission_tuning.dart`
- Test: `test/alarms/mission_tuning_test.dart`

**Interfaces:**
- Produces: `MissionTuning.graceSeconds == 30`, `MissionTuning.stopScreenSeconds == 45`

- [ ] **Step 1: Write the failing test**

`test/alarms/mission_tuning_test.dart`, `MissionTuning` grubuna:

```dart
    test('Ara ekran sureleri', () {
      // Spec 2026-08-30 D12, kullanici karari: 20 sn okuyup basmak icin dar.
      expect(MissionTuning.graceSeconds, 30);
      expect(MissionTuning.stopScreenSeconds, 45);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/alarms/mission_tuning_test.dart`
Expected: FAIL — `The getter 'stopScreenSeconds' isn't defined`

- [ ] **Step 3: Write minimal implementation**

`lib/core/config/mission_tuning.dart`'ta `graceSeconds` bloğunu şununla değiştir:

```dart
  /// Görevli alarmda ara ekranda seçim süresi. Alarm durduruldu, kullanıcı
  /// "Görevi yap"a ya da "Ertele"ye basmadı; bu kadar saniye sonra alarm
  /// döner. 20 sn ekranı okuyup basmak için dar geldi (spec 2026-08-30 D12).
  static const int graceSeconds = 30;

  /// Görevsiz alarmda ara ekranın açık kalma süresi. Dolarsa "Tamam" sayılır:
  /// oturum kapanır, alarmlar yeniden kurulur. Ceza yok — görevsizde durdurma
  /// zaten kesin — ama ekran sonsuza kadar da açık kalmasın.
  static const int stopScreenSeconds = 45;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/alarms/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/mission_tuning.dart test/alarms/mission_tuning_test.dart
git commit -m "feat: ara ekran sureleri (grace 30 sn, stopScreen 45 sn)"
```

---

### Task 2: `MissionSession.stoppedAt`

**Files:**
- Modify: `lib/core/models/mission_session.dart`
- Modify: `lib/features/alarms/domain/mission_coordinator.dart:28-35`
- Test: `test/alarms/mission_session_test.dart`, `test/alarms/mission_coordinator_test.dart`

**Interfaces:**
- Produces: `MissionSession.stoppedAt: DateTime` (kurucuda isteğe bağlı, varsayılan `firedAt`); `copyWith({DateTime? stoppedAt})`

- [ ] **Step 1: Write the failing tests**

`test/alarms/mission_session_test.dart`, `MissionSession` grubuna:

```dart
    test('stoppedAt verilmezse firedAt ile ayni', () {
      final s = MissionSession(alarmId: 'a', firedAt: firedAt);
      expect(s.stoppedAt, firedAt);
    });

    test('stoppedAt JSON ile korunur, eski kayitta firedAt e duser', () {
      final later = firedAt.add(const Duration(minutes: 10));
      final s = MissionSession(alarmId: 'a', firedAt: firedAt, stoppedAt: later);
      expect(MissionSession.fromJson(s.toJson()).stoppedAt, later);

      final legacy = MissionSession.fromJson({
        'alarm_id': 'a',
        'fired_at': firedAt.toIso8601String(),
      });
      expect(legacy.stoppedAt, firedAt);
    });

    test('copyWith stoppedAt i degistirir, firedAt i korur', () {
      final later = firedAt.add(const Duration(minutes: 10));
      final s = MissionSession(alarmId: 'a', firedAt: firedAt)
          .copyWith(stoppedAt: later);
      expect(s.firedAt, firedAt);
      expect(s.stoppedAt, later);
    });
```

`test/alarms/mission_coordinator_test.dart`'a:

```dart
  /// Erteleme sonrasi ikinci durdurma: ara ekranin geri sayimi ve bayatlik
  /// kontrolu son durdurma anina bagli, ilk calisa degil.
  test('resume: yeni durdurma olayi stoppedAt i gunceller', () async {
    await storage.saveMissionSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    final again = firedAt.add(const Duration(minutes: 5));
    service.pendingEvents = [
      MissionStopEvent(alarmId: 'sahur', stoppedAt: again),
    ];

    final session = await coordinator.resume();

    expect(session!.firedAt, firedAt);
    expect(session.stoppedAt, again);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/alarms/mission_session_test.dart test/alarms/mission_coordinator_test.dart`
Expected: FAIL — `No named parameter with the name 'stoppedAt'`

- [ ] **Step 3: Write minimal implementation**

`lib/core/models/mission_session.dart`:

```dart
class MissionSession {
  final String alarmId;
  final DateTime firedAt;

  /// Son durdurma anı. İlk çalışta [firedAt] ile aynı; erteleme sonrası alarm
  /// yeniden çalıp durdurulunca ilerler. Ara ekranın geri sayımı ve bayatlık
  /// kontrolü buna bağlı — [firedAt] ilk çalışta sabitleniyor.
  final DateTime stoppedAt;

  final int snoozeUsed;
  final int rearmCount;
  final DateTime? deadlineAt;
  final DateTime? snoozedUntil;
  final DateTime? completedAt;

  const MissionSession({
    required this.alarmId,
    required this.firedAt,
    DateTime? stoppedAt,
    this.snoozeUsed = 0,
    this.rearmCount = 0,
    this.deadlineAt,
    this.snoozedUntil,
    this.completedAt,
  }) : stoppedAt = stoppedAt ?? firedAt;
```

`toJson`'a `'stopped_at': stoppedAt.toIso8601String(),` ekle. `fromJson`'a:

```dart
    stoppedAt: switch (json['stopped_at']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
```

`copyWith`'e `DateTime? stoppedAt,` parametresi ve `stoppedAt: stoppedAt ?? this.stoppedAt,` satırı ekle. Mevcut alanların doküman yorumları yerinde kalır.

`mission_coordinator.dart` `resume()`:

```dart
    final session = existing != null && existing.alarmId == latest.alarmId
        ? existing.copyWith(
            rearmCount: existing.rearmCount + 1,
            stoppedAt: latest.stoppedAt,
            clearDeadline: true,
            // Alarm calip kapatildi: erteleme penceresi bitti.
            clearSnoozedUntil: true,
          )
        : MissionSession(alarmId: latest.alarmId, firedAt: latest.stoppedAt);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter analyze && flutter test test/alarms/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/mission_session.dart lib/features/alarms/domain/mission_coordinator.dart test/alarms
git commit -m "feat: oturuma son durdurma ani (stoppedAt) eklendi"
```

---

### Task 3: `StopGate` — kapı kararı

Spec §4 tablosunun saf hali. Widget'a dokunmadan sekiz satır sınanır.

**Files:**
- Create: `lib/features/alarms/domain/stop_gate.dart`
- Test: `test/alarms/stop_gate_test.dart`

**Interfaces:**
- Consumes: `MissionSession.stoppedAt` (Task 2), `MissionTuning.stopScreenSeconds` (Task 1)
- Produces: `enum StopDecision { none, closeAndRearm, showStopScreen, openMission }`; `StopGate.decide({required Alarm? alarm, required MissionSession session, required DateTime now}) -> StopDecision`; `StopGate.snoozeRemaining(Alarm alarm, MissionSession session) -> int?` (`null` = sınırsız)

- [ ] **Step 1: Write the failing test**

`test/alarms/stop_gate_test.dart`:

```dart
import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/features/alarms/domain/stop_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final stoppedAt = DateTime(2026, 8, 30, 8, 45);
  final now = stoppedAt.add(const Duration(seconds: 5));

  const plain = Alarm(id: 'is', kind: AlarmKind.fixed, hour: 8, minute: 45,
      snoozeEnabled: true, snoozeMinutes: 10, maxSnoozes: 1);
  const plainUnlimited = Alarm(id: 'is', kind: AlarmKind.fixed, hour: 8,
      snoozeEnabled: true, maxSnoozes: null);
  const plainNoSnooze = Alarm(id: 'is', kind: AlarmKind.fixed, hour: 8,
      snoozeEnabled: false);
  const gated = Alarm(id: 'sahur', kind: AlarmKind.fixed, hour: 5,
      mission: AlarmMission.qr, snoozeEnabled: true, maxSnoozes: 1);

  MissionSession session({int snoozeUsed = 0, DateTime? snoozedUntil}) =>
      MissionSession(
        alarmId: 'x',
        firedAt: stoppedAt,
        snoozeUsed: snoozeUsed,
        snoozedUntil: snoozedUntil,
      );

  group('StopGate.decide', () {
    test('ertelenmis ve suresi dolmamis oturumda hicbir sey', () {
      expect(
        StopGate.decide(
          alarm: plain,
          session: session(snoozedUntil: now.add(const Duration(minutes: 3))),
          now: now,
        ),
        StopDecision.none,
      );
    });

    test('alarm silinmisse kapat ve yeniden kur', () {
      expect(
        StopGate.decide(alarm: null, session: session(), now: now),
        StopDecision.closeAndRearm,
      );
    });

    test('gorevsiz, erteleme kapali: kapat', () {
      expect(
        StopGate.decide(alarm: plainNoSnooze, session: session(), now: now),
        StopDecision.closeAndRearm,
      );
    });

    test('gorevsiz, bayat: kapat, ekran yok', () {
      final stale = stoppedAt.add(
        const Duration(seconds: MissionTuning.stopScreenSeconds + 1),
      );
      expect(
        StopGate.decide(alarm: plain, session: session(), now: stale),
        StopDecision.closeAndRearm,
      );
    });

    test('gorevsiz, sinirda taze: ekran', () {
      final edge = stoppedAt.add(
        const Duration(seconds: MissionTuning.stopScreenSeconds - 1),
      );
      expect(
        StopGate.decide(alarm: plain, session: session(), now: edge),
        StopDecision.showStopScreen,
      );
    });

    test('gorevsiz, taze, hak var: ekran', () {
      expect(
        StopGate.decide(alarm: plain, session: session(), now: now),
        StopDecision.showStopScreen,
      );
    });

    test('gorevsiz, taze, hak yok: kapat', () {
      expect(
        StopGate.decide(alarm: plain, session: session(snoozeUsed: 1), now: now),
        StopDecision.closeAndRearm,
      );
    });

    test('gorevsiz, sinirsiz erteleme: ekran', () {
      expect(
        StopGate.decide(
          alarm: plainUnlimited, session: session(snoozeUsed: 9), now: now,
        ),
        StopDecision.showStopScreen,
      );
    });

    test('gorevli, hak yok: dogrudan gorev', () {
      expect(
        StopGate.decide(alarm: gated, session: session(snoozeUsed: 1), now: now),
        StopDecision.openMission,
      );
    });

    test('gorevli, hak var: ekran', () {
      expect(
        StopGate.decide(alarm: gated, session: session(), now: now),
        StopDecision.showStopScreen,
      );
    });

    /// Gorevli alarmda bayatlik yok: kapi native zincir tavaniyla sinirli,
    /// oturum bekliyorsa gorev hala borc.
    test('gorevli, eski oturum yine acilir', () {
      final late = stoppedAt.add(const Duration(minutes: 20));
      expect(
        StopGate.decide(alarm: gated, session: session(), now: late),
        StopDecision.showStopScreen,
      );
    });
  });

  group('StopGate.snoozeRemaining', () {
    test('erteleme kapaliysa sifir', () {
      expect(StopGate.snoozeRemaining(plainNoSnooze, session()), 0);
    });
    test('sinirsizsa null', () {
      expect(StopGate.snoozeRemaining(plainUnlimited, session(snoozeUsed: 3)), isNull);
    });
    test('kalan hak, eksiye dusmez', () {
      expect(StopGate.snoozeRemaining(plain, session()), 1);
      expect(StopGate.snoozeRemaining(plain, session(snoozeUsed: 5)), 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/alarms/stop_gate_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../stop_gate.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/features/alarms/domain/stop_gate.dart`:

```dart
import '../../../core/config/mission_tuning.dart';
import '../../../core/models/alarm.dart';
import '../../../core/models/alarm_mission.dart';
import '../../../core/models/mission_session.dart';

/// Alarm durdurulduktan sonra ne olacağı.
enum StopDecision {
  /// Ortada çalan alarm yok (ertelenmiş); hiçbir şey yapma.
  none,

  /// Oturumu kapat, alarmları yeniden kur; ekran açma.
  closeAndRearm,

  /// Ara ekran: görevlide "Görevi yap / Ertele", görevsizde "Tamam / Ertele".
  showStopScreen,

  /// Görevli alarm, erteleme hakkı yok: doğrudan görev ekranı.
  openMission,
}

/// Ara ekranın kapısı. Spec 2026-08-30 §4 tablosu; saf, zamanı dışarıdan alır.
///
/// Kural: ekran **yalnızca gerçek bir seçim varsa** açılır (D6). Tek düğmelik
/// ekran uykulu kullanıcıya fazladan bir dokunuş.
class StopGate {
  const StopGate._();

  static StopDecision decide({
    required Alarm? alarm,
    required MissionSession session,
    required DateTime now,
  }) {
    final snoozedUntil = session.snoozedUntil;
    if (snoozedUntil != null && snoozedUntil.isAfter(now)) {
      return StopDecision.none;
    }
    if (alarm == null) return StopDecision.closeAndRearm;

    final remaining = snoozeRemaining(alarm, session);
    final hasChoice = remaining == null || remaining > 0;

    if (!alarm.mission.requiresGate) {
      if (!hasChoice) return StopDecision.closeAndRearm;
      // Görevsizde durdurma kesin (D3); saatler sonra eski bir Ertele
      // ekranıyla karşılaşılmasın (D7).
      final expiresAt = session.stoppedAt.add(
        const Duration(seconds: MissionTuning.stopScreenSeconds),
      );
      if (!now.isBefore(expiresAt)) return StopDecision.closeAndRearm;
      return StopDecision.showStopScreen;
    }

    return hasChoice ? StopDecision.showStopScreen : StopDecision.openMission;
  }

  /// Kalan erteleme hakkı. `null` = sınırsız; erteleme kapalıysa 0.
  static int? snoozeRemaining(Alarm alarm, MissionSession session) {
    if (!alarm.snoozeEnabled) return 0;
    final limit = alarm.maxSnoozes;
    if (limit == null) return null;
    final left = limit - session.snoozeUsed;
    return left < 0 ? 0 : left;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/alarms/stop_gate_test.dart`
Expected: PASS (14 test)

- [ ] **Step 5: Commit**

```bash
git add lib/features/alarms/domain/stop_gate.dart test/alarms/stop_gate_test.dart
git commit -m "feat: ara ekran kapisi (StopGate) -- saf karar fonksiyonu"
```

---

### Task 4: `AlarmStopScreen` — sunum

**Files:**
- Create: `lib/presentation/screens/alarm_stop_screen.dart`
- Modify: `lib/presentation/utils/alarm_labels.dart` (`missionLabel`)
- Test: `test/widgets/missions/alarm_stop_screen_test.dart`

**Interfaces:**
- Consumes: `alarmTimeLabel`, `weekdaysLabel` (`alarm_labels.dart`); `kMissionButton*` (`mission_metrics.dart`)
- Produces: `AlarmStopScreen({required Alarm alarm, required bool gated, required int remainingSeconds, required int? snoozeRemaining, required DateTime firedAt, required DateTime stoppedAt, required DateTime now, required VoidCallback onPrimary, VoidCallback? onSnooze})`; keys `kStopPrimaryKey`, `kStopSnoozeKey`, `kStopCountdownKey`; `missionLabel(AlarmMission) -> String`

- [ ] **Step 1: Write the failing test**

`test/widgets/missions/alarm_stop_screen_test.dart`:

```dart
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/presentation/screens/alarm_stop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  final firedAt = DateTime(2026, 8, 30, 8, 45);
  final stoppedAt = firedAt.add(const Duration(seconds: 30));
  final now = stoppedAt.add(const Duration(seconds: 7));

  const plain = Alarm(
    id: 'is', kind: AlarmKind.fixed, hour: 8, minute: 45, label: 'İş',
    snoozeEnabled: true, snoozeMinutes: 10, maxSnoozes: 1,
  );
  const gated = Alarm(
    id: 'sabah', kind: AlarmKind.anchored, anchor: PrayerType.sunrise,
    offsetMinutes: -60, label: 'Sabah Namazı',
    mission: AlarmMission.qr, missionLevel: 2,
    snoozeEnabled: true, snoozeMinutes: 10, maxSnoozes: 2,
  );

  Future<void> pump(
    WidgetTester tester, {
    required Alarm alarm,
    required bool gated,
    int remainingSeconds = 38,
    int? snoozeRemaining = 1,
    VoidCallback? onPrimary,
    VoidCallback? onSnooze,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        AlarmStopScreen(
          alarm: alarm,
          gated: gated,
          remainingSeconds: remainingSeconds,
          snoozeRemaining: snoozeRemaining,
          firedAt: firedAt,
          stoppedAt: stoppedAt,
          now: now,
          onPrimary: onPrimary ?? () {},
          onSnooze: onSnooze,
        ),
      ),
    );
  }

  testWidgets('gorevsiz: Tamam birincil, Ertele sure ve hak ile', (tester) async {
    await pump(tester, alarm: plain, gated: false, onSnooze: () {});

    expect(find.text('Tamam'), findsOneWidget);
    expect(find.text('Ertele · 10 dk'), findsOneWidget);
    expect(find.text('1 hak kaldı'), findsOneWidget);
    expect(find.textContaining('Dokunmazsan'), findsOneWidget);
    expect(find.text('İş'), findsOneWidget);
    expect(find.text('08:45'), findsOneWidget);
    expect(find.textContaining('Her gün'), findsOneWidget);
  });

  testWidgets('gorevli: Gorevi yap birincil, gorev karti ve uyari', (tester) async {
    await pump(tester, alarm: gated, gated: true, onSnooze: () {});

    expect(find.text('Görevi yap'), findsOneWidget);
    expect(find.text('Ertele · 10 dk'), findsOneWidget);
    expect(find.textContaining('QR okutma'), findsOneWidget);
    expect(find.textContaining('90 sn'), findsOneWidget);
    expect(find.textContaining('alarm'), findsWidgets);
    expect(find.textContaining('Güneş −60 dk'), findsOneWidget);
    expect(find.text('Sabah Namazı'), findsOneWidget);
  });

  testWidgets('sinirsiz ertelemede hak satiri yok', (tester) async {
    await pump(tester, alarm: plain, gated: false, snoozeRemaining: null, onSnooze: () {});
    expect(find.textContaining('hak'), findsNothing);
    expect(find.byKey(kStopSnoozeKey), findsOneWidget);
  });

  testWidgets('onSnooze yoksa Ertele cizilmez', (tester) async {
    await pump(tester, alarm: plain, gated: false, onSnooze: null);
    expect(find.byKey(kStopSnoozeKey), findsNothing);
  });

  testWidgets('geri sayim m:ss biciminde ve saniyeyi tasir', (tester) async {
    await pump(tester, alarm: plain, gated: false, remainingSeconds: 38);
    expect(find.byKey(kStopCountdownKey), findsOneWidget);
    expect(find.textContaining('0:38'), findsOneWidget);
  });

  testWidgets('dugmeler geri cagrilari tetikler', (tester) async {
    var primary = 0;
    var snooze = 0;
    await pump(tester, alarm: plain, gated: false,
        onPrimary: () => primary++, onSnooze: () => snooze++);

    await tester.tap(find.byKey(kStopPrimaryKey));
    await tester.tap(find.byKey(kStopSnoozeKey));
    expect(primary, 1);
    expect(snooze, 1);
  });

  testWidgets('kac dakika once durduruldugu yazar', (tester) async {
    await pump(tester, alarm: plain, gated: false);
    expect(find.textContaining('az önce'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/missions/alarm_stop_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../alarm_stop_screen.dart'`

- [ ] **Step 3: `missionLabel` yardımcısı**

`lib/presentation/utils/alarm_labels.dart`'a:

```dart
import '../../core/models/alarm_mission.dart';

/// Görev adının kullanıcıya görünen hali.
String missionLabel(AlarmMission mission) => switch (mission) {
  AlarmMission.none => 'Görev yok',
  AlarmMission.math => 'Matematik',
  AlarmMission.shake => 'Sallama',
  AlarmMission.qr => 'QR okutma',
};
```

`alarm_edit_screen.dart`'ta aynı dizeler ayrıca yazılıysa **bu turda dokunulmaz**; ayrı bir temizlik.

- [ ] **Step 4: Ekranı yaz**

`lib/presentation/screens/alarm_stop_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/mission_tuning.dart';
import '../../core/models/alarm.dart';
import '../../core/models/alarm_mission.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../utils/alarm_labels.dart';
import '../widgets/missions/mission_metrics.dart';

const Key kStopPrimaryKey = Key('stop_primary');
const Key kStopSnoozeKey = Key('stop_snooze');
const Key kStopCountdownKey = Key('stop_countdown');

/// Alarm durdurulunca açılan karar ekranı. Salt sunum: sayaç ve eylemler
/// dışarıdan gelir.
///
/// Görevli alarmda "Görevi yap / Ertele", görevsizde "Tamam / Ertele". Görev
/// ekranıyla aynı dil (spec 2026-08-30 D13): uyku sersemi okunacak.
class AlarmStopScreen extends StatelessWidget {
  final Alarm alarm;
  final bool gated;

  /// Kalan saniye: görevlide alarmın dönmesine, görevsizde ekranın
  /// kapanmasına.
  final int remainingSeconds;

  /// Kalan erteleme hakkı; `null` sınırsız.
  final int? snoozeRemaining;

  final DateTime firedAt;
  final DateTime stoppedAt;
  final DateTime now;

  /// Görevlide görev ekranına geçer, görevsizde kapatır.
  final VoidCallback onPrimary;
  final VoidCallback? onSnooze;

  const AlarmStopScreen({
    super.key,
    required this.alarm,
    required this.gated,
    required this.remainingSeconds,
    required this.snoozeRemaining,
    required this.firedAt,
    required this.stoppedAt,
    required this.now,
    required this.onPrimary,
    this.onSnooze,
  });

  String get _countdown {
    final s = remainingSeconds < 0 ? 0 : remainingSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// Sabit alarmda kurulu saat; çıpalıda gerçek çalış anı (vakit her gün
  /// kayar, kullanıcı bugünkü saati görmeli).
  String get _timeText => alarm.kind == AlarmKind.fixed
      ? alarmTimeLabel(alarm)
      : DateFormat('HH:mm').format(firedAt);

  String get _detailText {
    final ago = now.difference(stoppedAt).inMinutes;
    final agoText = ago < 1 ? 'az önce' : '$ago dk önce';
    final first = alarm.kind == AlarmKind.fixed
        ? weekdaysLabel(alarm.weekdays)
        : alarmTimeLabel(alarm);
    return '$first · $agoText';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.backgroundStops.last,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'ALARM DURDURULDU',
                textAlign: TextAlign.center,
                style: AppTypography.sectionLabel.copyWith(
                  color: tokens.textTertiary,
                ),
              ),
              const Spacer(),
              _header(tokens),
              if (gated) ...[const SizedBox(height: 24), _missionCard(tokens)],
              const Spacer(),
              _primaryButton(tokens),
              if (onSnooze != null) ...[
                const SizedBox(height: 12),
                _snoozeButton(tokens),
                if (snoozeRemaining != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$snoozeRemaining hak kaldı',
                    textAlign: TextAlign.center,
                    style: AppTypography.hint.copyWith(
                      fontSize: 14,
                      color: tokens.textTertiary,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
              _footer(tokens),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppTokens tokens) {
    final title = alarm.label.isEmpty ? 'Alarm' : alarm.label;
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.screenTitle.copyWith(
            fontSize: 22,
            color: tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            _timeText,
            style: AppTypography.counter.copyWith(color: tokens.textPrimary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _detailText,
          textAlign: TextAlign.center,
          style: AppTypography.hint.copyWith(
            fontSize: 15,
            color: tokens.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _missionCard(AppTokens tokens) {
    final seconds = MissionTuning.timeoutSecondsFor(alarm.mission);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(kMissionButtonRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, color: tokens.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${missionLabel(alarm.mission)} · seviye ${alarm.missionLevel} · $seconds sn',
              style: AppTypography.rowTitle.copyWith(
                fontSize: kMissionSupportFontSize,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(AppTokens tokens) {
    return SizedBox(
      height: kMissionButtonHeight,
      child: FilledButton(
        key: kStopPrimaryKey,
        onPressed: onPrimary,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.backgroundStops.last,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kMissionButtonRadius),
          ),
        ),
        child: Text(
          gated ? 'Görevi yap' : 'Tamam',
          style: AppTypography.rowTitle.copyWith(
            fontSize: kMissionButtonFontSize,
          ),
        ),
      ),
    );
  }

  Widget _snoozeButton(AppTokens tokens) {
    return SizedBox(
      height: kMissionButtonHeight,
      child: OutlinedButton(
        key: kStopSnoozeKey,
        onPressed: onSnooze,
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.accent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kMissionButtonRadius),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Ertele · ${alarm.snoozeMinutes} dk',
            style: AppTypography.rowTitle.copyWith(
              fontSize: kMissionButtonFontSize,
            ),
          ),
        ),
      ),
    );
  }

  /// Görevlide uyarı (alarm döner), görevsizde bilgi (kapanır).
  Widget _footer(AppTokens tokens) {
    final text = gated
        ? 'Seçim yapmazsan alarm $_countdown sonra döner'
        : 'Dokunmazsan $_countdown sonra kapanır';
    return Text(
      text,
      key: kStopCountdownKey,
      textAlign: TextAlign.center,
      style: AppTypography.hint.copyWith(
        fontSize: 14,
        color: gated ? tokens.accent : tokens.textTertiary,
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter analyze && flutter test test/widgets/missions/alarm_stop_screen_test.dart`
Expected: PASS (7 test). `tokens.surface` / `tokens.border` `AppTokens`'ta yoksa (`grep -n "surface\|border" lib/core/theme/app_tokens.dart` ile bak) `tokens.secondarySurface` / `tokens.divider` kullan.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/alarm_stop_screen.dart lib/presentation/utils/alarm_labels.dart test/widgets/missions/alarm_stop_screen_test.dart
git commit -m "feat: alarm ara ekrani (AlarmStopScreen)"
```

---

### Task 5: Launcher — kapı ve `_StopHost`

**Files:**
- Modify: `lib/presentation/screens/mission_launcher.dart`
- Test: `test/widgets/missions/mission_launcher_test.dart`

**Interfaces:**
- Consumes: `StopGate`, `StopDecision` (Task 3); `AlarmStopScreen`, `kStop*` (Task 4); `MissionSession.stoppedAt` (Task 2); `MissionTuning.graceSeconds/stopScreenSeconds` (Task 1); `rearmAlarms` (mevcut)
- Produces: `openMissionIfPending` yeni davranış; `enum StopScreenResult { done, mission }`

- [ ] **Step 1: Mevcut testi yeni sözleşmeye çek**

`mission_launcher_test.dart`'ta `'Gorevsiz alarmda zincir kapatilir'` testindeki `plain` alarmı erteleme kapalı yap — artık "seçim yok" yolu bu:

```dart
      const plain = Alarm(
        id: 'duz', kind: AlarmKind.fixed, hour: 7, snoozeEnabled: false,
      );
```

Testin adını `'Gorevsiz, erteleme kapali alarmda zincir kapatilir'` yap.

- [ ] **Step 2: Write the failing tests**

Aynı dosyaya, `'Gorev tamamlaninca native temizlenir'` testinin hemen üstüne. Dosya başına `import 'package:ezanvakti/presentation/screens/alarm_stop_screen.dart';` ekle.

```dart
    const plainSnooze = Alarm(
      id: 'is', kind: AlarmKind.fixed, hour: 8, minute: 45, label: 'İş',
      snoozeEnabled: true, snoozeMinutes: 10, maxSnoozes: 1,
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
        MissionSession(alarmId: plainSnooze.id, firedAt: DateTime.now(), snoozeUsed: 1),
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

    testWidgets('Gorevsiz: sure dolunca ekran kendini kapatir', (tester) async {
      await storage.saveAlarm(plainSnooze);
      alarmService.pendingEvents = [
        MissionStopEvent(
          alarmId: plainSnooze.id,
          stoppedAt: DateTime.now().subtract(
            const Duration(seconds: MissionTuning.stopScreenSeconds - 2),
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
        MissionSession(alarmId: mathAlarm.id, firedAt: DateTime.now(), snoozeUsed: 2),
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
```

Dosya başına `import 'package:ezanvakti/core/config/mission_tuning.dart';` ekle.

⚠️ `mathAlarm` `maxSnoozes: 2` — mevcut testler görev ekranını `open` sonrası doğrudan bekliyor (`'Bekleyen durdurma olayi gorev ekranini acar'`, `'Gorev tamamlaninca native temizlenir'`, `'Ertele alarmi erteler ve ekrani kapatir'`, `'Acil cikis...'`, `'Ekran acikken ikinci cagri...'`, `'Sallama...'`, `'QR...'`, `'Sayac ilerlerken...'`, `'Gorev tamamlaninca alarmlar yeniden planlanir'`, `'Ertelemede alarmlar yeniden planlanmaz'`). Yeni kapıda önce ara ekran gelir. Bu testlerde `open(tester)` sonrasına şu yardımcıyı ekle ve çağır:

```dart
  /// Yeni akista hak varken once ara ekran geliyor; gorev testleri oradan
  /// gecer.
  Future<void> enterMission(WidgetTester tester) async {
    if (find.byKey(kStopPrimaryKey).evaluate().isEmpty) return;
    await tester.tap(find.byKey(kStopPrimaryKey));
    await settle(tester);
  }
```

Her `await open(tester);` satırından sonra (yalnızca görev ekranı bekleyen testlerde) `await enterMission(tester);` ekle. `'Ertele alarmi erteler...'` testi görev ekranındaki `kMissionSnoozeKey`'e basıyor; D16 gereği düğme orada da duruyor, test `enterMission` ile aynen geçer.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/widgets/missions/mission_launcher_test.dart`
Expected: FAIL — yeni testler `AlarmStopScreen` bulamaz; eski görev testleri `enterMission` eklenmemişse zaten geçer (ara ekran henüz yok).

- [ ] **Step 4: Launcher'ı yeniden yaz — kapı**

`mission_launcher.dart` içinde `openMissionIfPending`'i şununla değiştir (dosya başına importlar: `../../features/alarms/domain/stop_gate.dart`, `alarm_stop_screen.dart`, `../../core/models/mission_session.dart`):

```dart
/// Ara ekranın nasıl kapandığı.
enum StopScreenResult { done, mission }

/// Bekleyen bir oturum varsa uygun ekranı açar.
///
/// Uygulama, alarm durdurulunca `stopIntent` tarafından öne getiriliyor;
/// buraya hem soğuk açılışta hem de ön plana dönüşte uğranır. Karar
/// [StopGate]'te; burada yalnızca sonuç uygulanır.
Future<void> openMissionIfPending(BuildContext context) async {
  if (_missionScreenOpen) return;
  final coordinator = ServiceLocator().get<MissionCoordinator>();
  final session = await coordinator.resume();
  if (context.mounted) context.read<AppState>().setMissionSession(session);
  if (session == null || !session.isPending) return;

  final alarms = await ServiceLocator().get<AlarmsManager>().getAlarms();
  final alarm = alarms.where((a) => a.id == session.alarmId).firstOrNull;
  final decision = StopGate.decide(
    alarm: alarm,
    session: session,
    now: DateTime.now(),
  );

  switch (decision) {
    case StopDecision.none:
      return;
    case StopDecision.closeAndRearm:
      // Alarm silinmis, secim yok ya da bayat: zinciri kapat ki telefon
      // olmayan bir gorevi beklemesin; ertesi gunu kur.
      await coordinator.complete(session.alarmId);
      if (context.mounted) await rearmAlarms(context);
      return;
    case StopDecision.openMission:
    case StopDecision.showStopScreen:
      break;
  }

  if (!context.mounted) return;
  _missionScreenOpen = true;
  try {
    var openMission = decision == StopDecision.openMission;
    if (!openMission) {
      final result = await Navigator.of(context).push<StopScreenResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _StopHost(alarm: alarm!, session: session),
        ),
      );
      openMission = result == StopScreenResult.mission;
    }
    if (openMission && context.mounted) {
      final current = await coordinator.currentSession();
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _MissionHost(
            alarm: alarm!,
            snoozeUsed: current?.snoozeUsed ?? session.snoozeUsed,
          ),
        ),
      );
    }
  } finally {
    _missionScreenOpen = false;
    if (context.mounted) {
      context.read<AppState>().setMissionSession(
        await coordinator.currentSession(),
      );
    }
  }
}
```

`_missionScreenOpen` bayrağı ara ekran ve görev ekranı boyunca `true` kalır: `pushReplacement` yerine sıralı iki `push` kullanılmasının sebebi bu — `pushReplacement` ilk rotanın `Future`'ını erken tamamlayıp bayrağı düşürürdü.

- [ ] **Step 5: `_StopHost`**

Aynı dosyaya, `_MissionHost`'un üstüne:

```dart
/// Ara ekranı sayaçla çalıştıran kabuk.
///
/// Görevlide sayaç `graceSeconds`: dolunca native nöbetçi alarmı döndürür,
/// burada yalnızca gösterilir. Görevsizde `stopScreenSeconds`: dolunca
/// "Tamam" sayılır ve ekran kendini kapatır (spec D3/D8).
class _StopHost extends StatefulWidget {
  final Alarm alarm;
  final MissionSession session;

  const _StopHost({required this.alarm, required this.session});

  @override
  State<_StopHost> createState() => _StopHostState();
}

class _StopHostState extends State<_StopHost> {
  late MissionSession _session = widget.session;
  Timer? _ticker;
  StreamSubscription<dynamic>? _stops;
  bool _closing = false;

  MissionCoordinator get _coordinator =>
      ServiceLocator().get<MissionCoordinator>();

  bool get _gated => widget.alarm.mission.requiresGate;

  int get _windowSeconds =>
      _gated ? MissionTuning.graceSeconds : MissionTuning.stopScreenSeconds;

  int get _remaining {
    final end = _session.stoppedAt.add(Duration(seconds: _windowSeconds));
    final left = end.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // Gorevlide sure dolup alarm donerse ve yine durdurulursa geri sayim
    // yeni stoppedAt ile tazelenir; ikinci ekran acilmaz.
    _stops = ServiceLocator().get<AlarmService>().missionStops.listen((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final session = await _coordinator.resume();
    if (!mounted || session == null) return;
    setState(() => _session = session);
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (!_gated && _remaining <= 0) _primary();
  }

  Future<void> _primary() async {
    if (_closing) return;
    _closing = true;
    if (_gated) {
      Navigator.of(context).pop(StopScreenResult.mission);
      return;
    }
    await _coordinator.complete(widget.alarm.id);
    if (!mounted) return;
    await rearmAlarms(context);
    if (mounted) Navigator.of(context).pop(StopScreenResult.done);
  }

  Future<void> _snooze() async {
    if (_closing) return;
    final ok = await _coordinator.snooze(widget.alarm);
    if (!ok || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(StopScreenResult.done);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stops?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = StopGate.snoozeRemaining(widget.alarm, _session);
    final canSnooze = remaining == null || remaining > 0;
    return PopScope(
      canPop: false,
      child: AlarmStopScreen(
        alarm: widget.alarm,
        gated: _gated,
        remainingSeconds: _remaining,
        snoozeRemaining: remaining,
        firedAt: _session.firedAt,
        stoppedAt: _session.stoppedAt,
        now: DateTime.now(),
        onPrimary: _primary,
        onSnooze: canSnooze ? _snooze : null,
      ),
    );
  }
}
```

`_MissionHost`'taki `_snoozeRemaining` getter'ı `StopGate.snoozeRemaining(widget.alarm, ...)` ile **değiştirilmez** — o görev ekranı için `snoozeUsed`'ı widget parametresinden alıyor ve sınırsızı 0 sayıyor (görevli alarmda sınırsız zaten seçilemez); bu turda dokunulmaz.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter analyze && flutter test test/widgets/missions/`
Expected: PASS. `'Gorevsiz: sure dolunca ekran kendini kapatir'` kırmızı kalırsa `_tick` içindeki `setState` ile `pop` sırasını kontrol et: `pop` `setState`'ten sonra çağrılmalı ve `_closing` bir kez tetiklenmeli.

- [ ] **Step 7: Tüm Dart paketini çalıştır**

Run: `flutter test`
Expected: PASS. Kırmızı bir şey varsa büyük ihtimalle `ServiceLocator`'a `AlarmScheduler` kaydı olmayan bir test kurulumudur; oraya `AlarmScheduler(alarmService: fake, storage: fake)` ekle.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/mission_launcher.dart test/widgets/missions/mission_launcher_test.dart
git commit -m "feat: alarm durunca ara ekran; gorevsizde erteleme artik sayiliyor

Kapi karari StopGate'te. Gorevlide hak varken once ara ekran, Gorevi yap
goreve gecer; gorevsizde Tamam oturumu kapatip alarmlari yeniden kurar,
sure dolunca ekran kendini kapatir."
```

---

### Task 6: Native — görevsiz alarm da uygulamayı açar

**Files:**
- Create: `ios/Runner/MissionStopPolicy.swift`
- Modify: `ios/Runner/AppDelegate.swift:72-106` (`handleStop`), `:236-254` (uyarı kurulumu), `:268-304` (oturum + merdiven)
- Create: `ios/RunnerTests/MissionStopPolicyTests.swift`

**Interfaces:**
- Produces: `enum StopAction { ignore, rearm, stopChain }`; `MissionStopPolicy.action(gated:rearmCount:maxRearms:nowMillis:chainDeadlineMillis:) -> StopAction`

- [ ] **Step 1: Write the failing test**

`ios/RunnerTests/MissionStopPolicyTests.swift`:

```swift
import XCTest

@testable import Runner

final class MissionStopPolicyTests: XCTestCase {
    /// Gorevsizde durdurma kesin (spec 2026-08-30 D3): nobetci kurulmaz.
    func testUngatedNeverRearms() {
        XCTAssertEqual(
            MissionStopPolicy.action(
                gated: false, rearmCount: 0, maxRearms: 40,
                nowMillis: 0, chainDeadlineMillis: 1_000
            ),
            .ignore
        )
    }

    func testGatedWithinBoundsRearms() {
        XCTAssertEqual(
            MissionStopPolicy.action(
                gated: true, rearmCount: 3, maxRearms: 40,
                nowMillis: 0, chainDeadlineMillis: 1_000
            ),
            .rearm
        )
    }

    func testGatedStopsAtRearmCap() {
        XCTAssertEqual(
            MissionStopPolicy.action(
                gated: true, rearmCount: 40, maxRearms: 40,
                nowMillis: 0, chainDeadlineMillis: 1_000
            ),
            .stopChain
        )
    }

    func testGatedStopsPastDeadline() {
        XCTAssertEqual(
            MissionStopPolicy.action(
                gated: true, rearmCount: 0, maxRearms: 40,
                nowMillis: 2_000, chainDeadlineMillis: 1_000
            ),
            .stopChain
        )
    }
}
```

- [ ] **Step 2: Kaydet ve düştüğünü gör**

```bash
python3 /private/tmp/claude-501/-Users-ekrem-projects-ezanvakti/67e9b7d1-044b-4ef9-86ee-6d0e53c0d3b1/scratchpad/pbxadd.py \
  --group RunnerTests --path RunnerTests --targets tests ios/RunnerTests/MissionStopPolicyTests.swift
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RunnerTests/MissionStopPolicyTests 2>&1 | grep -E "error:|TEST " | head -3
```
Expected: `cannot find 'MissionStopPolicy' in scope`

- [ ] **Step 3: Politikayı yaz**

`ios/Runner/MissionStopPolicy.swift`:

```swift
import Foundation

enum StopAction: Equatable {
    /// Görevsiz alarm: durdurma kesin, nöbetçi yok. Olay yine kuyruğa yazılır
    /// ki uygulama açılınca ara ekran erteleme sunabilsin.
    case ignore
    case rearm
    case stopChain
}

/// Alarm durdurulunca nöbetçi kurulsun mu? Saf; `handleStop` bunu uygular.
enum MissionStopPolicy {
    static func action(
        gated: Bool, rearmCount: Int, maxRearms: Int,
        nowMillis: Double, chainDeadlineMillis: Double
    ) -> StopAction {
        guard gated else { return .ignore }
        guard rearmCount < maxRearms, nowMillis < chainDeadlineMillis else {
            return .stopChain
        }
        return .rearm
    }
}
```

```bash
python3 /private/tmp/claude-501/-Users-ekrem-projects-ezanvakti/67e9b7d1-044b-4ef9-86ee-6d0e53c0d3b1/scratchpad/pbxadd.py \
  --group Runner --path Runner --targets runner ios/Runner/MissionStopPolicy.swift
```

- [ ] **Step 4: `handleStop`'u politikaya bağla**

`AppDelegate.swift` `handleStop` gövdesini şununla değiştir:

```swift
  static func handleStop() {
    guard var s = session(), s["pending"] as? Bool == true,
      let alarmId = s["alarmId"] as? String
    else { return }

    enqueueStopEvent(alarmId: alarmId)

    // Eski oturumlarda bayrak yok: hepsi gorevliydi.
    let gated = s["gated"] as? Bool ?? true
    let rearmCount = s["rearmCount"] as? Int ?? 0
    let maxRearms = s["maxRearms"] as? Int ?? 40
    let chainDeadline = s["chainDeadlineMillis"] as? Double ?? 0
    let nowMillis = Date().timeIntervalSince1970 * 1000

    switch MissionStopPolicy.action(
      gated: gated, rearmCount: rearmCount, maxRearms: maxRearms,
      nowMillis: nowMillis, chainDeadlineMillis: chainDeadline)
    {
    case .ignore:
      // Gorevsiz: durdurma kesin. Uygulama acilinca ara ekran erteleme sunar.
      AlarmKitHandler.notifyDart(alarmId: alarmId)
      return
    case .stopChain:
      s["pending"] = false
      save(s)
      NSLog("mission|chain|stopped|bounds|id=\(alarmId)")
      return
    case .rearm:
      break
    }

    let grace = s["graceSeconds"] as? Int ?? 30
    s["rearmCount"] = rearmCount + 1
    s["deadlineMillis"] = nowMillis + Double(grace * 1000)
    save(s)

    AlarmKitHandler.rearmWatchdog(
      alarmId: alarmId,
      fireDate: Date().addingTimeInterval(TimeInterval(grace)),
      session: s)

    // Uygulama ayaktaysa dogrudan haber ver: yalnizca kuyruga yazmak yetmiyor,
    // on plandaki uygulamada hicbir yasam dongusu olayi tetiklenmiyor.
    AlarmKitHandler.notifyDart(alarmId: alarmId)
  }
```

- [ ] **Step 5: Uyarı kurulumu ve oturum**

`scheduleAlarm` içindeki `if missionEnabled { ... } else if snoozeEnabled { ... } else { ... }` bloğunu şununla değiştir:

```swift
    // Uygulamayi acan alarm: gorevli, ya da gorevsiz ama erteleme acik.
    // Erteleme kapali gorevsiz alarm bugunku gibi: sadece durdur, uygulama
    // acilmaz (spec 2026-08-30 D2).
    let opensApp = missionEnabled || snoozeEnabled
    alert = AlarmPresentation.Alert(title: title)
    if opensApp {
      // Sistemin Ertele dugmesi (.countdown) sayilamiyordu; erteleme
      // uygulama icindeki ara ekrana tasindi (D5).
      stopIntent = MissionStopIntent()
    }
```

`countdownPresentation` ve `countdownDuration` artık hiç atanmıyor; `var` tanımları `nil` kalır (derleyici uyarısı verirse `let countdownPresentation: AlarmPresentation.Countdown? = nil` yap).

Oturum bloğundaki `if missionEnabled {` koşulunu `if opensApp {` yap ve `session["label"] = label` satırının altına ekle:

```swift
          // Gorevsizde durdurma kesin: handleStop nobetci kurmaz (D3/D10).
          session["gated"] = missionEnabled
```

Merdiven kurulumu görevsizde gereksiz (D11): `if let ladder = chainConfig["ladderMillis"]` satırını `if missionEnabled, let ladder = chainConfig["ladderMillis"]` yap.

- [ ] **Step 6: Test ve derleme**

```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|TEST " | head -4
flutter build ios --no-codesign 2>&1 | tail -1
```
Expected: `** TEST SUCCEEDED **`, `✓ Built`

- [ ] **Step 7: Commit**

```bash
git add ios/Runner ios/RunnerTests ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: gorevsiz alarm da durdurulunca uygulamayi aciyor

Sistemin Ertele dugmesi (.countdown) sayilamiyordu; erteleme uygulama
icindeki ara ekrana tasindi. Gorevsizde durdurma kesin: handleStop nobetci
kurmuyor (MissionStopPolicy, XCTest ile sinandi). Erteleme kapali gorevsiz
alarm bugunku gibi kaliyor."
```

---

### Task 7: Dokümantasyon, sürüm, cihaz testi

**Files:**
- Modify: `CHANGELOG.md`, `pubspec.yaml`
- Modify: `docs/superpowers/specs/2026-08-17-gorev-tabanli-kapatma-design.md` (D3/D6/D15 notu)

- [ ] **Step 1: Görev spec'ine düzeltme notu**

`2026-08-17` spec'inde D6 satırının sonuna ekle: ` **Düzeltme (0.5.4):** kalktı — görevsiz alarm da erteleme açıksa `stopIntent` alır, bkz. [ara ekran spec'i](2026-08-30-alarm-ara-ekran-design.md).` D3 ve D15 satırlarına: ` **0.5.4:** tüm alarmlara genişledi.`

- [ ] **Step 2: CHANGELOG ve sürüm**

`pubspec.yaml`: `version: 0.5.3+29` → `version: 0.5.4+30`.

`CHANGELOG.md` başına:

```markdown
## [0.5.4] - 2026-08-30

### Eklendi
- **Alarm durunca karar ekranı.** Alarmı durdurunca uygulama açılıyor ve büyük iki düğme çıkıyor: görevli alarmda "Görevi yap / Ertele", görevsizde "Tamam / Ertele". Erteleme süresi düğmenin üstünde, kalan hak altında.

### Düzeltildi
- **Görevsiz alarmlarda "Erteleme sayısı" ayarı hiçbir şey yapmıyordu** — sistem uyarısındaki Ertele düğmesi sayılamıyordu, sınırsız ertelenebiliyordu. Erteleme artık uygulama içinde sayılıyor; sistem düğmesi kaldırıldı.
- Görevsiz alarm çalıp kapatıldıktan sonra ertesi günkü alarm, uygulama açılana kadar kurulmuyordu; "Tamam" artık ertesi günü kuruyor.

### Değişti
- Görevli alarmda ara ekranda seçim süresi 30 sn (dolarsa alarm döner). Görevsizde ekran 45 sn sonra kendini kapatıyor.
- Erteleme kapalı görevsiz alarmlar eskisi gibi: durdurunca uygulama açılmaz.
```

- [ ] **Step 3: Son doğrulama**

```bash
flutter analyze && flutter test
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "TEST " | tail -1
flutter build ios --no-codesign 2>&1 | tail -1
```
Expected: üçü de temiz.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md pubspec.yaml docs/superpowers/specs/2026-08-17-gorev-tabanli-kapatma-design.md
git commit -m "docs: alarm ara ekrani icin surum notlari ve 0.5.4"
```

- [ ] **Step 5: Cihaz testi (kullanıcı)**

1. Görevsiz, erteleme açık, 1 hak: alarm çal → durdur → ara ekran "Tamam / Ertele · 10 dk / 1 hak kaldı". Ertele → 10 dk sonra çalar → durdur → ekran açılmaz (hak yok), uygulama açılır ve kapanır.
2. Görevsiz: durdur → dokunma → 45 sn sonra ekran kapanır; ertesi gün alarm çalar.
3. Görevli, hak var: durdur → "Görevi yap / Ertele"; 30 sn bekle → alarm döner.
4. Görevli: Görevi yap → görev ekranı, sayaç görev süresinden başlar.
5. Erteleme kapalı görevsiz alarm: durdur → uygulama açılmaz.

---

## Notlar

**Sıra:** 1 → 2 → 3 (saf katman) → 4 (sunum) → 5 (bağlama) → 6 (native) → 7. Task 6 Dart'tan bağımsız; 5'ten önce de yapılabilir ama cihazda tam akış ancak ikisi birlikte çalışır.

**Bilinen belirsizlikler:** Task 4 Step 5 (`tokens.surface`/`border` adları), Task 5 Step 6 (otomatik kapanma testinde `setState`/`pop` sırası). İkisinin de alternatifi adımda yazılı.
