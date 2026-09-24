# Ertelenmiş Alarm Geri Sayımı — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ertelenmiş alarm, alarm satırında ve Sıradaki kartında saniyeli "ERTELENDİ m:ss" rozetiyle görünür; dokununca ara ekran "ertelenmiş" kipinde açılır (Görevi yap / Ertele / Alarmı kapat / X); anahtardan görev ekranına düşme kalkar; yeniden erteleme iki platformda uygulanır.

**Architecture:** Karar mantığı Dart'ta kalır (`StopGate`, `MissionCoordinator`); yeni bir `SnoozeCountdown` widget'ı iki listede kullanılır; mevcut `_StopHost` kabuğu oturumdan kip türetir (`snoozedUntil != null`); yeni `openSnoozedAlarm` girişi satır dokunuşunu ekrana bağlar. Native tarafta yalnızca "erteleme sürerken ikinci erteleme" no-op'u kaldırılır; zamanlayıcı değişimi mevcut `rearm` yoluyla olur.

**Tech Stack:** Flutter/Dart (3.44.1), Provider, intl; Swift (AlarmKit, RunnerTests), Kotlin (JUnit 4).

**Spec:** `docs/superpowers/specs/2026-09-22-ertelenmis-alarm-geri-sayim-design.md`

## Global Constraints

- Kullanıcıya görünen metin Dart'a sabit yazılmaz; kaynak `lib/l10n/app_tr.arb`, karşılıkları `app_en.arb` ve `app_ar.arb`. ARB değişikliğinden sonra `flutter gen-l10n`.
- Renk ve tipografi `lib/core/theme/` token'ları ve `AppTypography` üzerinden.
- Kod ve identifier İngilizce; yorumlar Türkçe (mevcut dosyaların dili).
- `dart format` yalnız değiştirilen dosyalara (formatter dokunulmamış 47 dosyayı değiştiriyor).
- Her task sonunda ilgili testler; Task 9 sonunda `flutter analyze` + `flutter test` (tam suite).
- Native değişikliklerden sonra `flutter build apk --debug` ve `FLUTTER_XCODE_ARCHS=arm64 flutter build ios --simulator --debug`.
- Commit'ler `dev` üzerinde, Türkçe Conventional Commit; push yok.
- Kapsam: yalnız ertelenmiş oturum (`snoozedUntil != null`). Durdurma akışı, 30 sn nöbetçi, görev süresi değişmez (spec D1).

---

## Dosya haritası

| Dosya | Sorumluluk | Değişiklik |
|---|---|---|
| `lib/l10n/app_{tr,en,ar}.arb` | metinler | `snoozedLabel` → `snoozeRingsAt`; yeni `snoozeBadgeLabel`, `snoozeBadgeSemantics`, `stopSnoozedHeadline`, `stopRingsAt`, `stopSnoozedCount`, `stopCloseAlarm` |
| `lib/presentation/widgets/reminders/snooze_notice.dart` | erteleme alt metni | `label` yeni anahtarı kullanır |
| `lib/features/alarms/domain/stop_gate.dart` | saf kapı kararları | yeni `canSnoozeAgain` |
| `lib/features/alarms/domain/mission_coordinator.dart` | oturum işlemleri | `snooze` etkin ertelemede limiti atlamaz |
| `test/alarms/fakes/fake_alarm_service.dart` | native sözleşme taklidi | etkin ertelemede yeniden erteleme uygulanır |
| `lib/presentation/widgets/reminders/snooze_countdown.dart` (yeni) | rozet + `formatCountdownSeconds` | — |
| `lib/presentation/screens/alarm_stop_screen.dart` | ara ekran sunumu | `snoozedUntil`, `snoozeUsed`, `onClose`; ertelenmiş kip |
| `lib/presentation/screens/mission_launcher.dart` | ekran açma kabukları | `openSnoozedAlarm`; `_StopHost` kipi; kapı fonksiyonları silinir |
| `lib/presentation/widgets/reminders/alarms_section.dart` | alarm listesi satırı | rozet, kilit, `onSnoozedTap`; `onDisableBlocked` silinir |
| `lib/presentation/widgets/home/upcoming_card.dart` | Sıradaki kartı | rozet, kilit, `onSnoozedTap` |
| `lib/presentation/screens/home_screen.dart`, `lib/presentation/pages/home_page.dart`, `lib/presentation/screens/reminders_screen.dart` | bağlama | `onSnoozedTap` → `openSnoozedAlarm`; kapı çağrıları silinir |
| `ios/Runner/AlarmMissionStore.swift`, `android/.../AlarmMissions.kt` | native oturum deposu | etkin ertelemede yeniden erteleme |
| `docs/adr/0002-stop-gate.md` | karar kaydı | kapatma bölümü |

---

### Task 1: l10n anahtarları ve erteleme alt metni

**Files:**
- Modify: `lib/l10n/app_tr.arb:1933-1941` (`snoozedLabel` bloğu), `:2089-2092` civarı (stop anahtarları)
- Modify: `lib/l10n/app_en.arb:431`, `:456`
- Modify: `lib/l10n/app_ar.arb:431`, `:456`
- Modify: `lib/presentation/widgets/reminders/snooze_notice.dart:19-21`
- Test: `test/alarms/snooze_notice_test.dart:68-72`

**Interfaces:**
- Produces: `l10n.snoozeRingsAt(String time)`, `l10n.snoozeBadgeLabel`, `l10n.snoozeBadgeSemantics(String time)`, `l10n.stopSnoozedHeadline`, `l10n.stopRingsAt(String time)`, `l10n.stopSnoozedCount(Object count)`, `l10n.stopCloseAlarm`. `SnoozeNotice.label(until, l10n)` artık "05:10'te çalacak" döner (önek yok).

- [ ] **Step 1: Testi güncelle (önce kırmızı)**

`test/alarms/snooze_notice_test.dart` içindeki `label` grubunu şununla değiştir:

```dart
  group('label', () {
    test('Saat HH:mm bicimiyle, "Ertelendi" oneki olmadan yazilir', () {
      final text = SnoozeNotice.label(until, l10n);
      expect(text, contains('05:10'));
      // Onek rozete tasindi (spec D4); satir ayni bilgiyi iki kez yazmasin.
      expect(text, isNot(contains('Ertelendi')));
    });
  });
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/alarms/snooze_notice_test.dart`
Expected: FAIL — metin "Ertelendi · 05:10'te çalacak" içeriyor.

- [ ] **Step 3: ARB'leri güncelle**

`lib/l10n/app_tr.arb` — `snoozedLabel` bloğunu (anahtar + `@snoozedLabel` metadata) şununla değiştir:

```json
  "snoozeRingsAt": "{time}'te çalacak",
  "@snoozeRingsAt": {
    "description": "Ertelenmiş alarm satırının alt metni; 'Ertelendi' rozette.",
    "placeholders": {
      "time": {
        "type": "Object"
      }
    }
  },
  "snoozeBadgeLabel": "ERTELENDİ",
  "@snoozeBadgeLabel": {
    "description": "Alarm satırı ve Sıradaki kartındaki geri sayım rozetinin başlığı."
  },
  "snoozeBadgeSemantics": "Ertelendi, {time}'te çalacak, seçenekler için dokun",
  "@snoozeBadgeSemantics": {
    "description": "Rozetin erişilebilirlik etiketi.",
    "placeholders": {
      "time": {
        "type": "Object"
      }
    }
  },
```

Aynı dosyada `stopHeadline` bloğundan hemen sonra ekle:

```json
  "stopSnoozedHeadline": "ALARM ERTELENDİ",
  "@stopSnoozedHeadline": {
    "description": "Ara ekranin ertelenmis kipindeki ust basligi."
  },
  "stopRingsAt": "{time}'te çalar",
  "@stopRingsAt": {
    "description": "Ertelenmis kipte kahraman sayacin altindaki calma saati.",
    "placeholders": {"time": {"type": "String"}}
  },
  "stopSnoozedCount": "{count} kez ertelendi",
  "@stopSnoozedCount": {
    "description": "Ertelenmis kipte kucuk satirdaki erteleme sayisi.",
    "placeholders": {"count": {"type": "Object"}}
  },
  "stopCloseAlarm": "Alarmı kapat",
  "@stopCloseAlarm": {
    "description": "Gorevsiz alarmin ertelenmis kipindeki birincil dugme: erteleme iptal, alarm bugunluk biter."
  },
```

`lib/l10n/app_en.arb` — satır 431 `"snoozedLabel": ...` yerine:

```json
  "snoozeRingsAt": "Rings at {time}",
  "snoozeBadgeLabel": "SNOOZED",
  "snoozeBadgeSemantics": "Snoozed, rings at {time}, tap for options",
```

ve `"stopHeadline": "ALARM STOPPED",` satırından sonra:

```json
  "stopSnoozedHeadline": "ALARM SNOOZED",
  "stopRingsAt": "Rings at {time}",
  "stopSnoozedCount": "Snoozed ×{count}",
  "stopCloseAlarm": "Turn off alarm",
```

`lib/l10n/app_ar.arb` — satır 431 yerine:

```json
  "snoozeRingsAt": "سيرن في {time}",
  "snoozeBadgeLabel": "مؤجل",
  "snoozeBadgeSemantics": "مؤجل، سيرن في {time}، انقر للخيارات",
```

ve `"stopHeadline": "تم إيقاف المنبه",` satırından sonra:

```json
  "stopSnoozedHeadline": "تم تأجيل المنبه",
  "stopRingsAt": "يرن في {time}",
  "stopSnoozedCount": "أُجّل ×{count}",
  "stopCloseAlarm": "إيقاف المنبه",
```

- [ ] **Step 4: `SnoozeNotice.label`'ı yeni anahtara geçir**

`lib/presentation/widgets/reminders/snooze_notice.dart`:

```dart
  /// Satır alt metnindeki çalma saati. "Ertelendi" öneki artık rozette
  /// (spec 2026-09-22 D4); burada yalnız saat yazılır.
  static String label(DateTime until, AppLocalizations l10n) =>
      l10n.snoozeRingsAt(DateFormat('HH:mm').format(until));
```

- [ ] **Step 5: Üret ve yeşili gör**

Run: `flutter gen-l10n && flutter test test/alarms/snooze_notice_test.dart`
Expected: PASS. `grep -rn snoozedLabel lib test` boş dönmeli.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_tr.arb lib/l10n/app_en.arb lib/l10n/app_ar.arb lib/l10n/app_localizations*.dart lib/presentation/widgets/reminders/snooze_notice.dart test/alarms/snooze_notice_test.dart
git commit -m "feat(l10n): ertelenmiş alarm rozeti ve ara ekran kipi metinleri"
```

---

### Task 2: `StopGate.canSnoozeAgain`

**Files:**
- Modify: `lib/features/alarms/domain/stop_gate.dart:92-100` (`snoozeRemaining` altına)
- Test: `test/alarms/stop_gate_test.dart` (yeni grup)

**Interfaces:**
- Produces: `static bool StopGate.canSnoozeAgain({required Alarm alarm, required MissionSession session, required DateTime now})` — hak kalmış **ve** (görevsiz ya da `now + snoozeMinutes` zincir tavanından önce).

- [ ] **Step 1: Testleri yaz**

`test/alarms/stop_gate_test.dart` dosyasının sonuna, `blocksDismissal` grubundan sonra:

```dart
  group('StopGate.canSnoozeAgain', () {
    final chainDeadline = stoppedAt.add(
      const Duration(minutes: MissionTuning.chainDeadlineMinutes),
    );

    MissionSession gatedSession({int snoozeUsed = 0}) => MissionSession(
      alarmId: 'sahur',
      firedAt: stoppedAt,
      snoozeUsed: snoozeUsed,
      snoozedUntil: now.add(const Duration(minutes: 5)),
      chainDeadlineAt: chainDeadline,
    );

    test('hak yoksa yeniden ertelenemez', () {
      expect(
        StopGate.canSnoozeAgain(
          alarm: plain,
          session: session(snoozeUsed: 1),
          now: now,
        ),
        isFalse,
      );
    });

    test('gorevsizde tavan yok: hak varsa ertelenir', () {
      expect(
        StopGate.canSnoozeAgain(alarm: plain, session: session(), now: now),
        isTrue,
      );
    });

    test('sinirsiz ertelemede her zaman ertelenir', () {
      expect(
        StopGate.canSnoozeAgain(
          alarm: plainUnlimited,
          session: session(snoozeUsed: 40),
          now: now,
        ),
        isTrue,
      );
    });

    test('gorevlide yeni an tavana sigmali', () {
      const gatedTen = Alarm(
        id: 'sahur',
        kind: AlarmKind.fixed,
        hour: 5,
        mission: AlarmMission.qr,
        snoozeEnabled: true,
        snoozeMinutes: 10,
        maxSnoozes: 5,
      );
      expect(
        StopGate.canSnoozeAgain(
          alarm: gatedTen,
          session: gatedSession(),
          now: chainDeadline.subtract(const Duration(minutes: 11)),
        ),
        isTrue,
      );
      // Tam tavan: native `next < chainDeadline` ister; esitlik reddedilir.
      expect(
        StopGate.canSnoozeAgain(
          alarm: gatedTen,
          session: gatedSession(),
          now: chainDeadline.subtract(const Duration(minutes: 10)),
        ),
        isFalse,
      );
    });

    test('gorevlide kayitli tavan yoksa firedAt + 60 dk kullanilir', () {
      final noDeadline = MissionSession(
        alarmId: 'sahur',
        firedAt: stoppedAt,
        snoozedUntil: now.add(const Duration(minutes: 5)),
      );
      expect(
        StopGate.canSnoozeAgain(
          alarm: gated,
          session: noDeadline,
          now: chainDeadline.subtract(const Duration(minutes: 5)),
        ),
        isFalse,
        reason: 'gated snoozeMinutes varsayilani 5; 5 dk kala tam tavana denk gelir',
      );
    });
  });
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/alarms/stop_gate_test.dart`
Expected: FAIL — `canSnoozeAgain` tanımlı değil.

- [ ] **Step 3: Uygula**

`stop_gate.dart` içinde `snoozeRemaining`'in hemen altına:

```dart
  /// Ertelenmiş ekrandan bir kez daha ertelenebilir mi?
  ///
  /// Hak kalmış olmalı; görevlide yeni çalma anı zincirin sert tavanından
  /// **önce** olmalı — native aynı koşulu `next < chainDeadline` ile arar,
  /// reddedeceği isteği kullanıcıya düğme olarak sunmayız (spec D13).
  static bool canSnoozeAgain({
    required Alarm alarm,
    required MissionSession session,
    required DateTime now,
  }) {
    final remaining = snoozeRemaining(alarm, session);
    if (remaining != null && remaining <= 0) return false;
    if (!alarm.mission.requiresGate) return true;
    final next = now.add(Duration(minutes: alarm.snoozeMinutes));
    return next.isBefore(_staleAt(session));
  }
```

- [ ] **Step 4: Yeşili gör**

Run: `flutter test test/alarms/stop_gate_test.dart`
Expected: PASS (tüm gruplar).

- [ ] **Step 5: Commit**

```bash
git add lib/features/alarms/domain/stop_gate.dart test/alarms/stop_gate_test.dart
git commit -m "feat(alarm): StopGate.canSnoozeAgain — hak ve zincir tavanı kontrolü"
```

---

### Task 3: Koordinatör ve fake — erteleme sürerken yeniden erteleme

**Files:**
- Modify: `lib/features/alarms/domain/mission_coordinator.dart:126-145`
- Modify: `test/alarms/fakes/fake_alarm_service.dart:173-190` (`snoozeMission`)
- Test: `test/alarms/mission_coordinator_test.dart`

**Interfaces:**
- Consumes: `effectiveSnoozeLimit(alarm)` (mevcut).
- Produces: `MissionCoordinator.snooze` etkin ertelemede de limiti uygular; fake `snoozeMission` etkin ertelemede yeni anı `now + minutes` yapar ve `snoozeUsed` artırır (native sözleşmesiyle aynı, Task 10–11).

- [ ] **Step 1: Testleri yaz**

`test/alarms/mission_coordinator_test.dart` dosyasının `main` sonuna:

```dart
  group('erteleme sürerken yeniden erteleme', () {
    const alarm = Alarm(
      id: 'is',
      kind: AlarmKind.fixed,
      hour: 8,
      snoozeEnabled: true,
      snoozeMinutes: 10,
      maxSnoozes: 2,
    );

    test('hak varsa native çağrılır, yeni an şimdiden başlar', () async {
      final oldUntil = DateTime.now().add(const Duration(minutes: 3));
      await service.seedSession(
        MissionSession(
          alarmId: 'is',
          firedAt: firedAt,
          snoozeUsed: 1,
          snoozedUntil: oldUntil,
        ),
      );
      final before = DateTime.now();
      expect(await coordinator.snooze(alarm), isTrue);
      expect(service.snoozed, [(id: 'is', minutes: 10)]);
      final session = (await service.getMissionSessions()).single;
      expect(session.snoozeUsed, 2);
      expect(
        session.snoozedUntil!.isAfter(before.add(const Duration(minutes: 9))),
        isTrue,
        reason: 'yeni an eski anin uzerine degil, simdiden 10 dk',
      );
    });

    test('hak bittiyse native çağrılmaz', () async {
      await service.seedSession(
        MissionSession(
          alarmId: 'is',
          firedAt: firedAt,
          snoozeUsed: 2,
          snoozedUntil: DateTime.now().add(const Duration(minutes: 3)),
        ),
      );
      expect(await coordinator.snooze(alarm), isFalse);
      expect(service.snoozed, isEmpty);
      expect((await service.getMissionSessions()).single.snoozeUsed, 2);
    });
  });
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/alarms/mission_coordinator_test.dart`
Expected: FAIL — ilk test: `snoozeUsed` 1 kalır (fake no-op), ikinci test: `snooze` `true` döner (limit atlanıyor).

- [ ] **Step 3: Koordinatörü düzelt**

`mission_coordinator.dart` içindeki `snooze`'u şu hale getir:

```dart
  Future<bool> snooze(Alarm alarm, {DateTime? firedAt}) => _serial(() async {
    await _refresh();
    final session = _find(alarm.id, firedAt);
    if (!alarm.snoozeEnabled || session == null) return false;
    // Erteleme sürerken yeniden erteleme de sayılır (spec 2026-09-22 D12);
    // limit her durumda uygulanır.
    final limit = effectiveSnoozeLimit(alarm);
    if (limit != null && session.snoozeUsed >= limit) return false;
    await _apply(
      () => alarmService.snoozeMission(
        alarm.id,
        alarm.snoozeMinutes,
        firedAt: session.firedAt,
      ),
    );
    return true;
  });
```

- [ ] **Step 4: Fake'i native sözleşmesine uydur**

`fake_alarm_service.dart` `snoozeMission` içindeki
`if (session.snoozedUntil?.isAfter(DateTime.now()) == true) return;` satırını sil. Kalan gövde:

```dart
    if (snoozeError != null) throw snoozeError!;
    await _syncEvents();
    final session = _matching(alarmId, firedAt);
    if (session == null) return;
    // Etkin erteleme engel degil: yeni an simdiden, sayac +1 (native ile ayni).
    snoozed.add((id: alarmId, minutes: minutes));
    _sessions[alarmId] = session.copyWith(
      snoozeUsed: session.snoozeUsed + 1,
      clearDeadline: true,
      snoozedUntil: DateTime.now().add(Duration(minutes: minutes)),
    );
```

- [ ] **Step 5: Yeşili gör**

Run: `flutter test test/alarms/mission_coordinator_test.dart test/alarms/native_alarm_service_mission_test.dart test/widgets/missions/mission_launcher_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/alarms/domain/mission_coordinator.dart test/alarms/fakes/fake_alarm_service.dart test/alarms/mission_coordinator_test.dart
git commit -m "fix(alarm): erteleme sürerken yeniden erteleme limitle sayılır"
```

---

### Task 4: `SnoozeCountdown` rozeti

**Files:**
- Create: `lib/presentation/widgets/reminders/snooze_countdown.dart`
- Test: `test/widgets/reminders/snooze_countdown_test.dart`

**Interfaces:**
- Produces:
  - `String formatCountdownSeconds(int seconds)` → `"7:42"`, negatif → `"0:00"`.
  - `class SnoozeCountdown extends StatefulWidget { final DateTime until; final DateTime Function() clock; const SnoozeCountdown({super.key, required this.until, this.clock = DateTime.now}); }` — `Key`: `kSnoozeCountdownKey`.

- [ ] **Step 1: Testleri yaz**

```dart
import 'package:ezanvakti/presentation/widgets/reminders/snooze_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  group('formatCountdownSeconds', () {
    test('m:ss, saniye iki haneli', () {
      expect(formatCountdownSeconds(462), '7:42');
      expect(formatCountdownSeconds(65), '1:05');
      expect(formatCountdownSeconds(0), '0:00');
    });

    test('negatif sifira kirpilir', () {
      expect(formatCountdownSeconds(-3), '0:00');
    });
  });

  group('SnoozeCountdown', () {
    testWidgets('baslik ve kalan sure yazilir, saniyede bir ilerler', (
      tester,
    ) async {
      var now = DateTime(2026, 9, 22, 5, 41, 18);
      final until = DateTime(2026, 9, 22, 5, 49);
      await tester.pumpWidget(
        wrapWithTheme(SnoozeCountdown(until: until, clock: () => now)),
      );

      expect(find.byKey(kSnoozeCountdownKey), findsOneWidget);
      expect(find.text('ERTELENDİ'), findsOneWidget);
      expect(find.text('7:42'), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('7:41'), findsOneWidget);
    });

    testWidgets('sure dolunca 0:00 kalir', (tester) async {
      final until = DateTime(2026, 9, 22, 5, 49);
      await tester.pumpWidget(
        wrapWithTheme(
          SnoozeCountdown(
            until: until,
            clock: () => until.add(const Duration(seconds: 30)),
          ),
        ),
      );
      expect(find.text('0:00'), findsOneWidget);
    });

    testWidgets('erisilebilirlik etiketi saati soyler', (tester) async {
      final until = DateTime(2026, 9, 22, 5, 49);
      await tester.pumpWidget(
        wrapWithTheme(
          SnoozeCountdown(
            until: until,
            clock: () => until.subtract(const Duration(minutes: 2)),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'05:49')),
        findsOneWidget,
      );
    });
  });
}
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/reminders/snooze_countdown_test.dart`
Expected: FAIL — dosya yok.

- [ ] **Step 3: Uygula**

`lib/presentation/widgets/reminders/snooze_countdown.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../l10n/l10n_extensions.dart';

const Key kSnoozeCountdownKey = Key('snooze_countdown');

/// Kalan saniyeyi `m:ss` yazar; negatif "0:00". Ara ekranın sayacı ve rozet
/// aynı biçimi kullanır.
String formatCountdownSeconds(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Ertelenmiş alarmın satır ve karttaki rozeti: "ERTELENDİ" + geri sayım.
///
/// Anahtarın yerinde durur (spec 2026-09-22 D2). Kendi saniyelik
/// zamanlayıcısıyla işler; sayfanın 10 sn'lik saati değişmez (D3). Sıfıra
/// inince "0:00" kalır — alarm çalıp durdurulunca oturum tazelenir ve rozet
/// kalkar. [clock] testler içindir.
class SnoozeCountdown extends StatefulWidget {
  final DateTime until;
  final DateTime Function() clock;

  const SnoozeCountdown({
    super.key,
    required this.until,
    this.clock = DateTime.now,
  });

  @override
  State<SnoozeCountdown> createState() => _SnoozeCountdownState();
}

class _SnoozeCountdownState extends State<SnoozeCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final remaining = widget.until.difference(widget.clock()).inSeconds;
    final time = DateFormat('HH:mm').format(widget.until);
    // Buyuk metin olceginde rozet satiri yutmasin: kompakt rozet en fazla
    // 1.3x buyur; metin sutunu ellipsis ile zaten korunuyor.
    return Semantics(
      label: l10n.snoozeBadgeSemantics(time),
      excludeSemantics: true,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Container(
        key: kSnoozeCountdownKey,
        constraints: const BoxConstraints(minWidth: 78),
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
        decoration: BoxDecoration(
          color: tokens.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.snoozeBadgeLabel,
              maxLines: 1,
              style: AppTypography.sectionLabel.copyWith(
                fontSize: 10,
                letterSpacing: 1.4,
                color: tokens.accent,
              ),
            ),
            Text(
              formatCountdownSeconds(remaining),
              maxLines: 1,
              style: AppTypography.counter.copyWith(
                fontSize: 22,
                letterSpacing: -0.6,
                height: 1.2,
                color: tokens.accent,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Yeşili gör**

Run: `flutter test test/widgets/reminders/snooze_countdown_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/reminders/snooze_countdown.dart test/widgets/reminders/snooze_countdown_test.dart
git commit -m "feat(ui): SnoozeCountdown rozeti — ERTELENDİ + saniyeli geri sayım"
```

---

### Task 5: Ara ekranın "ertelenmiş" kipi

**Files:**
- Modify: `lib/presentation/screens/alarm_stop_screen.dart`
- Test: `test/widgets/missions/alarm_stop_screen_test.dart`

**Interfaces:**
- Consumes: `formatCountdownSeconds` (Task 4), l10n anahtarları (Task 1).
- Produces: `AlarmStopScreen` yeni alanlar — `DateTime? snoozedUntil` (null = durduruldu kipi), `int snoozeUsed = 0`, `VoidCallback? onClose`; yeni `const Key kStopCloseKey = Key('stop_close')`. Ertelenmiş kipte: başlık `stopSnoozedHeadline`, kahraman `remainingSeconds` sayacı (accent), altında `stopRingsAt`, küçük satırda `<gün/çıpa> · <alarm saati> · stopSnoozedCount`; alt bilgi satırı yok; görevsiz birincil `stopCloseAlarm`; X yalnız `onClose != null` iken.

- [ ] **Step 1: Testleri yaz**

`test/widgets/missions/alarm_stop_screen_test.dart` — `pump` yardımcısına üç parametre ekle ve widget'a geçir:

```dart
    DateTime? snoozedUntil,
    int snoozeUsed = 0,
    VoidCallback? onClose,
```
```dart
          snoozedUntil: snoozedUntil,
          snoozeUsed: snoozeUsed,
          onClose: onClose,
```

Dosyanın sonuna yeni grup:

```dart
  group('ertelenmis kip', () {
    final snoozedUntil = DateTime(2026, 8, 30, 8, 55);

    testWidgets('baslik, kahraman sayac ve calma saati', (tester) async {
      await pump(
        tester,
        alarm: gated,
        gated: true,
        remainingSeconds: 462,
        snoozedUntil: snoozedUntil,
        snoozeUsed: 1,
        onClose: () {},
      );
      expect(find.text('ALARM ERTELENDİ'), findsOneWidget);
      expect(find.text('ALARM DURDURULDU'), findsNothing);
      expect(find.text('7:42'), findsOneWidget);
      expect(find.text("08:55'te çalar"), findsOneWidget);
      expect(find.textContaining('1 kez ertelendi'), findsOneWidget);
      // Alt bilgi satiri (donme/kapanma sayaci) ertelenmis kipte yok (D11).
      expect(find.byKey(kStopCountdownKey), findsNothing);
      expect(find.byKey(kStopCloseKey), findsOneWidget);
    });

    testWidgets('gorevlide Gorevi yap, gorevsizde Alarmi kapat', (
      tester,
    ) async {
      await pump(
        tester,
        alarm: gated,
        gated: true,
        snoozedUntil: snoozedUntil,
        onClose: () {},
      );
      expect(find.text('Görevi yap'), findsOneWidget);

      await pump(
        tester,
        alarm: plain,
        gated: false,
        snoozedUntil: snoozedUntil,
        onClose: () {},
      );
      expect(find.text('Alarmı kapat'), findsOneWidget);
      expect(find.text('Tamam'), findsNothing);
    });

    testWidgets('X onClose cagirir; kendiliginden kipte X yok', (
      tester,
    ) async {
      var closed = false;
      await pump(
        tester,
        alarm: plain,
        gated: false,
        snoozedUntil: snoozedUntil,
        onClose: () => closed = true,
      );
      await tester.tap(find.byKey(kStopCloseKey));
      expect(closed, isTrue);

      await pump(tester, alarm: plain, gated: false);
      expect(find.byKey(kStopCloseKey), findsNothing);
      expect(find.text('ALARM DURDURULDU'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/missions/alarm_stop_screen_test.dart`
Expected: FAIL — `snoozedUntil` parametresi yok.

- [ ] **Step 3: Uygula**

`alarm_stop_screen.dart` değişiklikleri:

Import ekle: `import '../widgets/reminders/snooze_countdown.dart';`

Anahtarlara ekle: `const Key kStopCloseKey = Key('stop_close');`

Alanlar (mevcut `nextPrayerTime`'dan sonra):

```dart
  /// Ertelenmiş kip (spec 2026-09-22 D8): alarm bu anda çalacak. `null` ise
  /// durduruldu kipi. Ertelenmişte [remainingSeconds] bu ana kadar kalan.
  final DateTime? snoozedUntil;

  /// Küçük satırdaki "n kez ertelendi"; yalnız ertelenmiş kipte yazılır.
  final int snoozeUsed;

  /// Sağ üstteki X: hiçbir şeyi değiştirmeden çıkar. Yalnız kullanıcı
  /// ekranı kendisi açtıysa verilir (D10).
  final VoidCallback? onClose;
```

Constructor'a `this.snoozedUntil, this.snoozeUsed = 0, this.onClose,` ekle.

`_countdown` getter'ını değiştir:

```dart
  bool get _snoozed => snoozedUntil != null;

  String get _countdown => formatCountdownSeconds(remainingSeconds);
```

`build` içindeki `const SizedBox(height: 8)` + başlık `Text` çiftini şu sabit yükseklikli Stack ile değiştir (başlık ortada, X sağda; negatif offset yok, kırpılmaz):

```dart
              SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      _snoozed ? l10n.stopSnoozedHeadline : l10n.stopHeadline,
                      textAlign: TextAlign.center,
                      style: AppTypography.sectionLabel.copyWith(
                        color: tokens.textTertiary,
                      ),
                    ),
                    if (onClose != null)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: IconButton(
                          key: kStopCloseKey,
                          tooltip: l10n.actionCancel,
                          icon: const Icon(Icons.close_rounded),
                          color: tokens.textSecondary,
                          onPressed: onClose,
                        ),
                      ),
                  ],
                ),
              ),
```

Alt bilgi satırını koşullu yap:

```dart
              if (!_snoozed) ...[
                const SizedBox(height: 20),
                _footer(tokens, l10n),
              ],
```

(`const SizedBox(height: 20)` ile `_footer` çağrısını bu bloğa taşı.)

`_header`'ı ertelenmiş kip için genişlet — mevcut metodu şununla değiştir:

```dart
  Widget _header(BuildContext context, AppTokens tokens, AppLocalizations l10n) {
    final title = alarm.label.isEmpty ? l10n.alarmDefaultLabel : alarm.label;
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
            _snoozed ? _countdown : _timeText(l10n),
            style: AppTypography.counter.copyWith(
              color: _snoozed ? tokens.accent : tokens.textPrimary,
            ),
          ),
        ),
        if (_snoozed) ...[
          const SizedBox(height: 6),
          Text(
            l10n.stopRingsAt(context.formatTime(snoozedUntil!)),
            textAlign: TextAlign.center,
            style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          _snoozed ? _snoozedDetailText(l10n) : _detailText(l10n),
          textAlign: TextAlign.center,
          style: AppTypography.hint.copyWith(
            fontSize: 15,
            color: tokens.textTertiary,
          ),
        ),
      ],
    );
  }

  /// Ertelenmiş kipte küçük satır: gün/çıpa · alarm saati · n kez ertelendi.
  String _snoozedDetailText(AppLocalizations l10n) {
    final first = alarm.kind == AlarmKind.fixed
        ? weekdaysLabel(alarm.weekdays, l10n)
        : alarmTimeLabel(alarm, l10n: l10n);
    return '$first · ${_timeText(l10n)} · ${l10n.stopSnoozedCount(snoozeUsed)}';
  }
```

`build` içindeki `_header(tokens, l10n)` çağrısını `_header(context, tokens, l10n)` yap.

`_primaryButton` etiketi:

```dart
          gated
              ? l10n.stopDoMission
              : _snoozed
              ? l10n.stopCloseAlarm
              : l10n.actionOk,
```

- [ ] **Step 4: Yeşili gör**

Run: `flutter test test/widgets/missions/alarm_stop_screen_test.dart`
Expected: PASS (eski testler dahil).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/alarm_stop_screen.dart test/widgets/missions/alarm_stop_screen_test.dart
git commit -m "feat(ui): ara ekrana ertelenmiş kip — kahraman geri sayım, X, Alarmı kapat"
```

---

### Task 6: Launcher — `openSnoozedAlarm`, `_StopHost` kipi, kapı fonksiyonlarının kaldırılması

**Files:**
- Modify: `lib/presentation/screens/mission_launcher.dart`
- Test: `test/widgets/missions/mission_launcher_test.dart`

**Interfaces:**
- Consumes: `StopGate.canSnoozeAgain` (Task 2), `AlarmStopScreen.snoozedUntil/snoozeUsed/onClose` (Task 5).
- Produces: `Future<void> openSnoozedAlarm(BuildContext context, Alarm alarm)`. Silinir: `resolveMissionBeforeDismiss`, `resolveSkipBeforeDismiss`.

- [ ] **Step 1: Eski kapı testlerini sil, yeni grubu yaz**

`mission_launcher_test.dart` içinde `resolveMissionBeforeDismiss` ve `resolveSkipBeforeDismiss` kullanan iki grubu (satır ~800–965: "gorevsiz alarmda ekran acilmaz, eylem uygulanir" … "Tanimi bulunmayan alarm atlamayi engellemez") tamamen sil. `SkippedOccurrence` import'u artık kullanılmıyorsa kaldır.

Yerine, dosya sonuna:

```dart
  group('openSnoozedAlarm', () {
    const plainSnooze = Alarm(
      id: 'is',
      kind: AlarmKind.fixed,
      hour: 8,
      minute: 45,
      snoozeEnabled: true,
      snoozeMinutes: 10,
      maxSnoozes: 2,
    );

    Future<void> openSnoozed(WidgetTester tester, Alarm alarm) async {
      await pumpLauncher(tester);
      unawaited(openSnoozedAlarm(hostContext, alarm));
      await settle(tester);
    }

    Future<void> seedSnoozed(
      Alarm alarm, {
      int snoozeUsed = 1,
      Duration left = const Duration(minutes: 7),
    }) => alarmService.seedSession(
      MissionSession(
        alarmId: alarm.id,
        firedAt: stoppedAt,
        snoozeUsed: snoozeUsed,
        snoozedUntil: DateTime.now().add(left),
        chainDeadlineAt: alarm.mission.requiresGate
            ? stoppedAt.add(
                const Duration(minutes: MissionTuning.chainDeadlineMinutes),
              )
            : null,
      ),
    );

    testWidgets('ertelenmis oturum yoksa ekran acilmaz', (tester) async {
      await storage.saveAlarm(mathAlarm);
      await openSnoozed(tester, mathAlarm);
      expect(find.byType(AlarmStopScreen), findsNothing);
    });

    testWidgets('ertelenmis gorevli: ekran ertelenmis kipte, X ile cikilir', (
      tester,
    ) async {
      await storage.saveAlarm(mathAlarm);
      await seedSnoozed(mathAlarm);
      await openSnoozed(tester, mathAlarm);

      expect(find.byType(AlarmStopScreen), findsOneWidget);
      expect(find.text('ALARM ERTELENDİ'), findsOneWidget);
      expect(find.byKey(kStopCloseKey), findsOneWidget);

      await tester.tap(find.byKey(kStopCloseKey));
      await settle(tester);

      expect(find.byType(AlarmStopScreen), findsNothing);
      expect(alarmService.snoozed, isEmpty);
      expect(alarmService.completed, isEmpty);
      expect(alarmService.begun, isEmpty);
      expect(
        appState.missionSession?.snoozedUntil,
        isNotNull,
        reason: 'X hicbir seyi degistirmez; erteleme kurulu kalir',
      );
    });

    testWidgets('Gorevi yap ertelemeyi bitirip gorev ekranini acar', (
      tester,
    ) async {
      await storage.saveAlarm(mathAlarm);
      await seedSnoozed(mathAlarm);
      await openSnoozed(tester, mathAlarm);

      await tester.tap(find.byKey(kStopPrimaryKey));
      await settle(tester);

      expect(find.byType(MissionScreen), findsOneWidget);
      expect(alarmService.begun, [mathAlarm.id]);
      expect(
        (await alarmService.getMissionSessions()).single.snoozedUntil,
        isNull,
        reason: 'begin ertelemeyi bitirir (M9)',
      );
    });

    testWidgets('Ertele yeniden erteler, hak bir eksilir, ekran kapanir', (
      tester,
    ) async {
      await storage.saveAlarm(mathAlarm);
      await seedSnoozed(mathAlarm);
      await openSnoozed(tester, mathAlarm);

      await tester.tap(find.byKey(kStopSnoozeKey));
      await settle(tester);

      expect(find.byType(AlarmStopScreen), findsNothing);
      expect(alarmService.snoozed, [(id: mathAlarm.id, minutes: 5)]);
      expect((await alarmService.getMissionSessions()).single.snoozeUsed, 2);
      expect(alarmService.scheduled, isEmpty);
    });

    testWidgets('hak bitince Ertele yok', (tester) async {
      await storage.saveAlarm(mathAlarm);
      await seedSnoozed(mathAlarm, snoozeUsed: 2);
      await openSnoozed(tester, mathAlarm);

      expect(find.byType(AlarmStopScreen), findsOneWidget);
      expect(find.byKey(kStopSnoozeKey), findsNothing);
    });

    testWidgets('gorevsiz: Alarmi kapat oturumu bitirir ve yeniden kurar', (
      tester,
    ) async {
      await storage.saveAlarm(plainSnooze);
      await seedSnoozed(plainSnooze);
      await openSnoozed(tester, plainSnooze);

      expect(find.text('Alarmı kapat'), findsOneWidget);
      await tester.tap(find.byKey(kStopPrimaryKey));
      await settle(tester);

      expect(find.byType(AlarmStopScreen), findsNothing);
      expect(alarmService.completed, [plainSnooze.id]);
      expect(alarmService.scheduled, [plainSnooze.id]);
    });

    testWidgets('ekran acikken durdurma olayi gelince durduruldu kipine gecer', (
      tester,
    ) async {
      await storage.saveAlarm(mathAlarm);
      await seedSnoozed(mathAlarm);
      await openSnoozed(tester, mathAlarm);
      expect(find.byKey(kStopCloseKey), findsOneWidget);

      // Erteleme doldu, alarm caldi, kullanici durdurdu: fake, olaydan
      // snoozedUntil'siz ve yeni stoppedAt'li oturum uretir (native gibi).
      alarmService.emitStop(
        MissionStopEvent(alarmId: mathAlarm.id, stoppedAt: DateTime.now()),
      );
      await settle(tester);

      expect(find.byType(AlarmStopScreen), findsOneWidget);
      expect(find.text('ALARM DURDURULDU'), findsOneWidget);
      expect(find.byKey(kStopCloseKey), findsNothing);
      expect(find.byKey(kStopCountdownKey), findsOneWidget);
    });
  });
```

`FakeAlarmService`'e olay yayma yardımcısı ekle (`test/alarms/fakes/fake_alarm_service.dart`, `seedSession` altına):

```dart
  /// Uygulama ön plandayken gelen durdurma olayını taklit eder.
  void emitStop(MissionStopEvent event) {
    pendingEvents = [...pendingEvents, event];
    _stops.add(event);
  }
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/missions/mission_launcher_test.dart`
Expected: derleme hatası — `openSnoozedAlarm` yok.

- [ ] **Step 3: Kapı fonksiyonlarını sil, `openSnoozedAlarm`'ı ekle**

`mission_launcher.dart`:

1. `resolveMissionBeforeDismiss` ve `resolveSkipBeforeDismiss` fonksiyonlarını (doc yorumlarıyla) sil. `import '../../core/models/skipped_occurrence.dart';` satırını kaldır.

2. `openMissionIfPending`'in altına ekle:

```dart
/// Ertelenmiş alarmın satırına ya da rozetine dokunuldu (spec 2026-09-22 D5).
///
/// Ara ekranı "ertelenmiş" kipinde açar: kullanıcı görevi yapar, yeniden
/// erteler, görevsizde alarmı kapatır ya da X ile hiçbir şeyi değiştirmeden
/// çıkar. Erteleme yoksa (dolmuş, bitmiş, silinmiş) hiçbir şey açılmaz; bu
/// durumlar [openMissionIfPending]'in işi.
Future<void> openSnoozedAlarm(BuildContext context, Alarm alarm) async {
  if (!context.mounted || !_canPresentMission || _missionScreenOpen) return;
  final navigator = Navigator.of(context);
  _openScreenNavigator = navigator;
  final coordinator = ServiceLocator().get<MissionCoordinator>();
  try {
    final sessions = await coordinator.currentSessions();
    if (!context.mounted) return;
    context.read<AppState>().setMissionSessions(sessions);
    final session = MissionSession.pendingForAlarm(sessions, alarm.id);
    if (session == null ||
        session.snoozedUntil?.isAfter(DateTime.now()) != true) {
      return;
    }
    final result = await navigator.push<StopScreenResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _StopHost(alarm: alarm, session: session),
      ),
    );
    if (result != StopScreenResult.mission ||
        !context.mounted ||
        !_canPresentMission) {
      return;
    }
    // Gorevi yap: taze oturumla gorev ekrani; begin ertelemeyi bitirir.
    final fresh = MissionSession.pendingForAlarm(
      await coordinator.currentSessions(),
      alarm.id,
    );
    if (!context.mounted || !_canPresentMission) return;
    await navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MissionHost(
          alarm: alarm,
          session: fresh?.firedAt.isAtSameMomentAs(session.firedAt) == true
              ? fresh!
              : session,
        ),
      ),
    );
  } catch (error, stack) {
    if (context.mounted) {
      _showMissionFailure(
        context,
        error,
        stack,
        () => openSnoozedAlarm(context, alarm),
      );
    }
  } finally {
    if (identical(_openScreenNavigator, navigator)) _openScreenNavigator = null;
    if (context.mounted) {
      try {
        final sessions = await coordinator.currentSessions();
        if (context.mounted) {
          context.read<AppState>().setMissionSessions(sessions);
        }
      } catch (error, stack) {
        if (context.mounted) {
          _showMissionFailure(
            context,
            error,
            stack,
            () => openSnoozedAlarm(context, alarm),
          );
        }
      }
      // Ekran acikken baska bir alarm durdurulduysa sirasi simdi.
      if (_needsMissionCheck && context.mounted) {
        unawaited(openMissionIfPending(context));
      }
    }
  }
}
```

3. `_StopHostState`'i ertelenmiş kipe göre düzenle:

```dart
  bool get _gated => widget.alarm.mission.requiresGate;

  /// Ertelenmiş kip: oturum snapshot'ında erteleme var. Süre dolup alarm
  /// çalsa bile native durdurmayı kaydedene kadar kip değişmez; kip ancak
  /// dinlenen durdurma olayıyla tazelenen oturumla döner (spec D14).
  bool get _snoozed => _session.snoozedUntil != null;

  int get _windowSeconds =>
      _gated ? MissionTuning.graceSeconds : MissionTuning.stopScreenSeconds;

  int get _remaining {
    final end =
        _session.snoozedUntil ??
        _session.stoppedAt.add(Duration(seconds: _windowSeconds));
    final left = end.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }
```

`_tick`:

```dart
  void _tick() {
    if (!mounted) return;
    setState(() {});
    // Ertelenmis kipte otomatik kapanma yok (D11): sayac 0:00'da bekler.
    if (!_snoozed && !_gated && _remaining <= 0) _primary();
  }
```

`_snooze`'un altına:

```dart
  /// X: hiçbir şeyi değiştirmeden çık; erteleme kurulu kalır (D10).
  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(StopScreenResult.done);
  }
```

`build`:

```dart
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = StopGate.snoozeRemaining(widget.alarm, _session);
    final canSnooze = StopGate.canSnoozeAgain(
      alarm: widget.alarm,
      session: _session,
      now: now,
    );
    // Karşılama satırı ana ekranla aynı hesabı kullanır (ADR 0004).
    final appState = context.read<AppState>();
    final today = appState.todaysPrayerTime;
    return PopScope(
      // Ertelenmis kipte geri jesti X ile ayni: degisiklik yok.
      canPop: _snoozed,
      child: AlarmStopScreen(
        nextPrayerType: PrayerUtils.getNextPrayerType(today),
        nextPrayerTime: PrayerUtils.getNextPrayerTime(
          today,
          appState.tomorrowsPrayerTime,
        ),
        alarm: widget.alarm,
        gated: _gated,
        remainingSeconds: _remaining,
        snoozeRemaining: remaining,
        firedAt: _session.firedAt,
        stoppedAt: _session.stoppedAt,
        now: now,
        snoozedUntil: _session.snoozedUntil,
        snoozeUsed: _session.snoozeUsed,
        onClose: _snoozed ? _close : null,
        onPrimary: _primary,
        onSnooze: canSnooze ? _snooze : null,
      ),
    );
  }
```

- [ ] **Step 4: Yeşili gör**

Run: `flutter test test/widgets/missions/mission_launcher_test.dart`
Expected: PASS. Not: "Gorevli: ara ekranda Ertele sayar ve kapatir" ve diğer eski testler `canSnoozeAgain` ile de geçer (tavana uzak).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/mission_launcher.dart test/widgets/missions/mission_launcher_test.dart test/alarms/fakes/fake_alarm_service.dart
git commit -m "feat(alarm): ertelenmiş alarma dokununca ara ekran; anahtar kapısı kaldırıldı"
```

(Bu commit'ten sonra `reminders_screen.dart` ve `home_page.dart` derlenmez; Task 9'a kadar `flutter analyze` çalıştırılmaz, yalnız hedef test dosyaları koşulur.)

---

### Task 7: Alarm listesi satırı — rozet, kilit, dokunma

**Files:**
- Modify: `lib/presentation/widgets/reminders/alarms_section.dart`
- Test: `test/widgets/reminders/alarms_section_skip_test.dart`

**Interfaces:**
- Consumes: `SnoozeCountdown`, `kSnoozeCountdownKey` (Task 4), `StopGate.blocksDismissal` (mevcut).
- Produces: `AlarmsSection.onSnoozedTap: ValueChanged<Alarm>?` (yeni); `onDisableBlocked` silinir.

- [ ] **Step 1: Testleri güncelle**

`alarms_section_skip_test.dart`:
- `build` yardımcısında `void Function(Alarm)? onDisableBlocked` parametresini ve `onDisableBlocked: onDisableBlocked,` satırını sil; `ValueChanged<Alarm>? onSnoozedTap` parametresi ve `onSnoozedTap: onSnoozedTap,` ekle.
- Import ekle: `import 'package:ezanvakti/presentation/widgets/reminders/snooze_countdown.dart';`
- Şu dört testi sil: "Ertelenmis alarmda atlama yerine erteleme bilgisi cikar", "Ertelenmis gorevli alarm kapatilamaz", "Gorevsiz alarm ertelenmis olsa da kapatilabilir", "Ertelenmemis ama gorev borcu duran alarm da kapidan gecer", "Zincir tavani dolmus borc kapatmayi engellemez".
- Yerine:

```dart
  testWidgets('Ertelenmis alarmda anahtar yerine rozet, dokunma ekrana gider', (
    tester,
  ) async {
    Alarm? tapped;
    await tester.pumpWidget(
      build(
        alarms: const [gated],
        session: MissionSession(
          alarmId: 'sahur',
          firedAt: DateTime.now(),
          snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
        ),
        onSnoozedTap: (a) => tapped = a,
      ),
    );
    expect(find.byKey(kSnoozeCountdownKey), findsOneWidget);
    expect(find.text('ERTELENDİ'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('Ertelendi ·'), findsNothing);

    await tester.tap(find.byKey(kSnoozeCountdownKey));
    await tester.pump();
    expect(tapped?.id, 'sahur');
  });

  testWidgets('Gorevsiz ertelenmis alarmda da rozet var, anahtar yok', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(
        session: MissionSession(
          alarmId: 'ogle',
          firedAt: DateTime.now(),
          snoozedUntil: DateTime.now().add(const Duration(minutes: 10)),
        ),
      ),
    );
    expect(find.byKey(kSnoozeCountdownKey), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('Ertelenmemis ama gorev borcu duran alarmda anahtar kilitli', (
    tester,
  ) async {
    var toggled = false;
    await tester.pumpWidget(
      build(
        alarms: const [gated],
        // Erteleme yok: alarm durdurulmus, gorev henuz yapilmamis.
        session: MissionSession(alarmId: 'sahur', firedAt: DateTime.now()),
        onToggle: (a, b) => toggled = true,
      ),
    );
    expect(find.byKey(kSnoozeCountdownKey), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(toggled, isFalse);
  });

  testWidgets('Zincir tavani dolmus borc anahtari kilitlemez', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      build(
        alarms: const [gated],
        session: MissionSession(
          alarmId: 'sahur',
          firedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        onToggle: (a, b) => toggled = true,
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(toggled, isTrue, reason: 'tavan dolunca gorev borcu da duser');
  });
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/reminders/alarms_section_skip_test.dart`
Expected: derleme hatası — `onSnoozedTap` yok.

- [ ] **Step 3: Uygula**

`alarms_section.dart`:

Import ekle: `import 'snooze_countdown.dart';`

`onDisableBlocked` alanını ve constructor parametresini sil; yerine:

```dart
  /// Ertelenmiş alarmın satırına/rozetine dokunuldu: ara ekran açılır
  /// (spec 2026-09-22 D5). Verilmezse satır ertelemede dokunulmaz.
  final ValueChanged<Alarm>? onSnoozedTap;
```
ve constructor'a `this.onSnoozedTap,`.

`_status` içinde `snoozedUntil` satırı aynen kalır (`SnoozeNotice.label` artık öneksiz).

`_alarmRow` içinde:

```dart
    final snoozedUntil = SnoozeNotice.snoozedUntilFor(missionSession, alarm);
    final snoozed = snoozedUntil != null;
    // Gorev borcu olup ertelenmemis alarmda anahtar kilitli (D6): ara/gorev
    // ekrani zaten kendiliginden aciliyor, cikissiz kalinmaz.
    final locked =
        !snoozed &&
        StopGate.blocksDismissal(
          alarm: alarm,
          sessions: missionSessions,
          now: DateTime.now(),
        );
```

(`canDisable` değişkenini kaldır.)

`ReminderRow` çağrısında:

```dart
      remaining: displayTime != null && status == null
          ? reminderRemaining(
              displayTime.difference(referenceTime),
              context.l10n,
            )
          : null,
```

```dart
      onTap: isReordering
          ? null
          : snoozed && onSnoozedTap != null
          ? () => onSnoozedTap!(alarm)
          : () => onEdit(alarm),
```

```dart
      trailing: isReordering
          ? const SizedBox.shrink()
          : snoozed
          ? SnoozeCountdown(until: snoozedUntil)
          : Switch(
              value: isOn,
              onChanged: locked
                  ? null
                  : (value) {
                      if (!value) {
                        onToggle(alarm, false);
                        return;
                      }
                      // Aciliyor: bekleyen tek seferlik atlama varsa once o
                      // kalkar, yoksa alarm kalici olarak acilir.
                      if (skipped && onSkipChanged != null) {
                        onSkipChanged!(
                          SkippedOccurrence(
                            kind: SkipKind.alarm,
                            reference: alarm.id,
                            fireAt: fireAt,
                          ),
                          false,
                        );
                        return;
                      }
                      onToggle(alarm, true);
                    },
            ),
```

- [ ] **Step 4: Yeşili gör**

Run: `flutter test test/widgets/reminders/ test/widgets/notifications/alarms_section_test.dart`
Expected: PASS (`alarm_sessions_test` "08:05" içerme beklentisi yeni metinle de doğru).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/reminders/alarms_section.dart test/widgets/reminders/alarms_section_skip_test.dart
git commit -m "feat(ui): alarm satırında ertelenmiş rozeti, kilitli anahtar ve dokunma"
```

---

### Task 8: Sıradaki kartı — rozet, kilit, dokunma

**Files:**
- Modify: `lib/presentation/widgets/home/upcoming_card.dart`
- Test: `test/widgets/home/upcoming_card_test.dart`

**Interfaces:**
- Consumes: `SnoozeCountdown` (Task 4), `StopGate.blocksDismissal`.
- Produces: `UpcomingCard.onSnoozedTap: ValueChanged<Alarm>?` (yeni).

- [ ] **Step 1: Testleri güncelle**

`upcoming_card_test.dart`: `pumpCard`'a `ValueChanged<Alarm>? onSnoozedTap` parametresi ekle ve `onSnoozedTap: onSnoozedTap,` geçir. Import ekle: `import 'package:ezanvakti/presentation/widgets/reminders/snooze_countdown.dart';`

"Ertelenmis gorevli alarmin atlama anahtari kilitli degil" testini şununla değiştir:

```dart
    testWidgets('Ertelenmis alarmda anahtar yerine rozet; satir ekrana gider', (
      tester,
    ) async {
      Alarm? tapped;
      await pumpCard(
        tester,
        alarm: (alarm: sahur.copyWith(mission: AlarmMission.qr), time: alarmAt),
        missionSessions: [
          MissionSession(
            alarmId: sahur.id,
            firedAt: now,
            snoozedUntil: now.add(const Duration(minutes: 8)),
          ),
        ],
        onSnoozedTap: (alarm) => tapped = alarm,
      );

      expect(find.byKey(kSnoozeCountdownKey), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('Ertelendi ·'), findsNothing);
      await tester.tap(find.text('Sahur'));
      await tester.pump();
      expect(tapped?.id, sahur.id);
    });

    testWidgets('Gorev borcu olup ertelenmemis alarmda atlama anahtari kilitli', (
      tester,
    ) async {
      await pumpCard(
        tester,
        alarm: (alarm: sahur.copyWith(mission: AlarmMission.qr), time: alarmAt),
        missionSessions: [
          MissionSession(alarmId: sahur.id, firedAt: DateTime.now()),
        ],
        onSkipChanged: (_, _) {},
      );
      expect(find.byKey(kSnoozeCountdownKey), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/home/upcoming_card_test.dart`
Expected: derleme hatası — `onSnoozedTap` yok.

- [ ] **Step 3: Uygula**

`upcoming_card.dart`:

Import ekle: `import '../../../features/alarms/domain/stop_gate.dart';` ve `import '../reminders/snooze_countdown.dart';`

Alan + constructor:

```dart
  /// Ertelenmiş alarm satırına dokunuldu: ara ekran (spec 2026-09-22 D5).
  final ValueChanged<Alarm>? onSnoozedTap;
```
`this.onSnoozedTap,`

`_skipSwitch`'e `enabled` parametresi:

```dart
  Widget _skipSwitch(
    SkippedOccurrence occurrence,
    bool isSkippedNow, {
    bool enabled = true,
  }) {
    return Switch(
      value: !isSkippedNow,
      onChanged: onSkipChanged == null || !enabled
          ? null
          : (value) => onSkipChanged!(occurrence, !value),
    );
  }
```

`_alarmRow` içinde `snoozedUntil` hesabından sonra:

```dart
    final snoozed = snoozedUntil != null;
    // Gorev borcu olup ertelenmemis alarmda anahtar kilitli (D6).
    final locked =
        !snoozed &&
        StopGate.blocksDismissal(
          alarm: item.alarm,
          sessions: missionSessions,
          now: now,
        );
```

`subtitle` switch'inin ilk dalı:

```dart
          (final DateTime until, _) => SnoozeNotice.label(until, context.l10n),
```

`GroupedRow`'a:

```dart
      onTap: snoozed && onSnoozedTap != null
          ? () => onSnoozedTap!(item.alarm)
          : null,
      trailing: snoozed
          ? SnoozeCountdown(until: snoozedUntil)
          : _skipSwitch(occurrence, skipped, enabled: !locked),
```

(`resolveSkipBeforeDismiss` yorumunu sil.)

- [ ] **Step 4: Yeşili gör**

Run: `flutter test test/widgets/home/upcoming_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/home/upcoming_card.dart test/widgets/home/upcoming_card_test.dart
git commit -m "feat(ui): Sıradaki kartında ertelenmiş rozeti ve dokunma"
```

---

### Task 9: Bağlama — ekranlar, analiz, tam suite

**Files:**
- Modify: `lib/presentation/screens/home_screen.dart:59-61, 91, 243`
- Modify: `lib/presentation/pages/home_page.dart:459-470, 675`
- Modify: `lib/presentation/screens/reminders_screen.dart:693-702, 974`

**Interfaces:**
- Consumes: `openSnoozedAlarm` (Task 6), `AlarmsSection.onSnoozedTap` (Task 7), `UpcomingCard.onSnoozedTap` (Task 8).

- [ ] **Step 1: `HomeScreen`'e `onSnoozedTap` ekle**

`home_screen.dart` — `onSkipChanged` alanının altına:

```dart
  /// Ertelenmiş alarm satırına dokunuldu; ara ekran açılır.
  final ValueChanged<Alarm>? onSnoozedTap;
```
Constructor: `this.onSnoozedTap,`. `UpcomingCard(...)` çağrısına `onSnoozedTap: widget.onSnoozedTap,`.

- [ ] **Step 2: `HomePage`'i bağla**

`home_page.dart` — `_toggleSkip` başındaki kapı bloğunu sil:

```dart
  /// "SIRADAKİ" kartındaki tek seferlik kapatma.
  ///
  /// Kalıcı kapatma Bildirimler/Alarmlar ekranlarında kalır; buradaki anahtar
  /// yalnızca gösterilen örneği atlar. Görev borcu olan alarmda anahtar
  /// kilitli, ertelenmişte yerini rozet alır (spec 2026-09-22 D6).
  Future<void> _toggleSkip(SkippedOccurrence occurrence, bool skipped) async {
    final appState = context.read<AppState>();
    final manager = ServiceLocator().get<SkipManager>();
```

`HomeScreen(...)` çağrısına `onSkipChanged: _toggleSkip,` altına:

```dart
              onSnoozedTap: (alarm) => openSnoozedAlarm(context, alarm),
```

Kullanılmayan import kalırsa (`AlarmsManager` hâlâ başka yerde kullanılıyor; kontrol et) kaldır.

- [ ] **Step 3: `RemindersScreen`'i bağla**

`reminders_screen.dart` — `_onDisableBlocked` metodunu (doc yorumuyla) sil. `AlarmsSection(...)` çağrısında `onDisableBlocked: _onDisableBlocked,` yerine:

```dart
              onSnoozedTap: (alarm) => openSnoozedAlarm(context, alarm),
```

- [ ] **Step 4: Analiz, biçim, tam suite**

Run:
```bash
dart format lib/presentation/widgets/reminders/snooze_countdown.dart lib/presentation/widgets/reminders/snooze_notice.dart lib/presentation/widgets/reminders/alarms_section.dart lib/presentation/widgets/home/upcoming_card.dart lib/presentation/screens/alarm_stop_screen.dart lib/presentation/screens/mission_launcher.dart lib/presentation/screens/home_screen.dart lib/presentation/pages/home_page.dart lib/presentation/screens/reminders_screen.dart lib/features/alarms/domain/stop_gate.dart lib/features/alarms/domain/mission_coordinator.dart test/alarms/stop_gate_test.dart test/alarms/mission_coordinator_test.dart test/alarms/fakes/fake_alarm_service.dart test/alarms/snooze_notice_test.dart test/widgets/reminders/snooze_countdown_test.dart test/widgets/reminders/alarms_section_skip_test.dart test/widgets/home/upcoming_card_test.dart test/widgets/missions/alarm_stop_screen_test.dart test/widgets/missions/mission_launcher_test.dart
flutter analyze
flutter test > /tmp/ft.log; echo "exit=$?"; tail -3 /tmp/ft.log
```
Expected: analyze temiz; `flutter test` exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/home_screen.dart lib/presentation/pages/home_page.dart lib/presentation/screens/reminders_screen.dart
git commit -m "feat(ui): ertelenmiş alarm dokunuşu ana ekran ve alarm listesine bağlandı"
```

---

### Task 10: iOS — erteleme sürerken yeniden erteleme

**Files:**
- Modify: `ios/Runner/AlarmMissionStore.swift:370-384`
- Test: `ios/RunnerTests/AlarmMissionStoreTests.swift`, `ios/RunnerTests/AlarmPlanEngineTests.swift`

**Interfaces:**
- Produces: `AlarmMissionStore.snooze` etkin ertelemede oturumu değiştirmeden dönmez; `snoozedUntilMillis = now + minutes`, `snoozeUsed += 1`; limit ve tavan kontrolü aynen.

- [ ] **Step 1: Testleri yaz**

`AlarmMissionStoreTests.swift` sonuna (sınıf içine):

```swift
  func testSnoozeDuringActiveSnoozeRestartsFromNowAndCounts() throws {
    let config = configuration("is")
    try store.configure(config)
    _ = try store.stop(scheduleId: config.scheduleId, nowMillis: fire + 1000)
    _ = try store.snooze(alarmId: "is", minutes: 5, nowMillis: fire + 2000)
    let again = try XCTUnwrap(store.snooze(alarmId: "is", minutes: 5, nowMillis: fire + 122_000))
    XCTAssertEqual(again.snoozedUntilMillis, fire + 122_000 + 300_000)
    XCTAssertEqual(again.snoozeUsed, 2)
    XCTAssertFalse(again.begun)
    XCTAssertNil(again.deadlineMillis)
  }

  func testSnoozeDuringActiveSnoozeStillHonorsLimit() throws {
    let config = configuration("is")  // maxSnoozes 2
    try store.configure(config)
    _ = try store.stop(scheduleId: config.scheduleId, nowMillis: fire + 1000)
    _ = try store.snooze(alarmId: "is", minutes: 5, nowMillis: fire + 2000)
    _ = try store.snooze(alarmId: "is", minutes: 5, nowMillis: fire + 62_000)
    XCTAssertNil(try store.snooze(alarmId: "is", minutes: 5, nowMillis: fire + 122_000))
    XCTAssertEqual(store.session(alarmId: "is")?.snoozeUsed, 2)
    XCTAssertEqual(store.session(alarmId: "is")?.snoozedUntilMillis, fire + 62_000 + 300_000)
  }
```

`AlarmPlanEngineTests.swift` — `testBeginDuringSnoozeReplacesSnoozeTimerWithMissionTimer`'ın altına:

```swift
  @MainActor
  func testSnoozeDuringSnoozeReplacesTimerWithLaterOne() async throws {
    let (engine, backend, clock) = fixture()
    var primary = record("work", at: clock.now + 1000)
    primary.maxSnoozes = 3
    _ = try await engine.reconcile(records: [primary], enabledAlarmIds: ["work"])
    clock.now += 1001
    _ = try await engine.stop(scheduleId: primary.scheduleId)
    try await engine.snooze("work", minutes: 5, expectedFireMillis: primary.fireAtMillis)
    let firstTimer = engine.missions.session(alarmId: "work")!.timerScheduleId!
    clock.now += 120_000
    backend.operations = []
    try await engine.snooze("work", minutes: 5, expectedFireMillis: primary.fireAtMillis)
    let session = engine.missions.session(alarmId: "work")!
    XCTAssertEqual(session.snoozeUsed, 2)
    XCTAssertEqual(session.snoozedUntilMillis, clock.now + 300_000)
    let secondTimer = try XCTUnwrap(session.timerScheduleId)
    XCTAssertNotEqual(secondTimer, firstTimer)
    XCTAssertEqual(engine.missions.configurations[secondTimer]?.fireAtMillis, clock.now + 300_000)
    XCTAssertNil(engine.mapping[firstTimer])
    XCTAssertTrue(backend.operations.contains("schedule:" + secondTimer))
    XCTAssertTrue(backend.operations.contains("cancel:" + firstTimer))
  }
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `cd ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RunnerTests/AlarmMissionStoreTests -only-testing:RunnerTests/AlarmPlanEngineTests 2>&1 | grep -E "Test Case .* (passed|failed)|error:|\*\* TEST" | tail -30`
Expected: üç yeni test FAIL (`snoozeUsed` 1 kalır / `snoozedUntilMillis` değişmez).

- [ ] **Step 3: Uygula**

`AlarmMissionStore.swift` `snooze` içinden şu satırı sil:

```swift
    if (session.snoozedUntilMillis ?? 0) > nowMillis { return session }
```

ve fonksiyon başındaki guard'ın üstüne yorum ekle:

```swift
  /// Erteleme sürerken ikinci erteleme de uygulanır: yeni an şimdiden,
  /// sayaç +1 (spec 2026-09-22 D12). Limit ve zincir tavanı aynen.
```

- [ ] **Step 4: Yeşili gör**

Run: aynı `xcodebuild test` komutu.
Expected: `** TEST SUCCEEDED **`, yeni testler passed.

- [ ] **Step 5: Commit**

```bash
git add ios/Runner/AlarmMissionStore.swift ios/RunnerTests/AlarmMissionStoreTests.swift ios/RunnerTests/AlarmPlanEngineTests.swift
git commit -m "fix(ios): erteleme sürerken yeniden erteleme uygulanır, sayaç artar"
```

---

### Task 11: Android — erteleme sürerken yeniden erteleme

**Files:**
- Modify: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmMissions.kt:257-269`
- Test: `android/app/src/test/kotlin/com/ekrembulbul/ezanvakti/AlarmMissionsTest.kt`

**Interfaces:**
- Produces: `AlarmMissions.snooze` etkin ertelemede `current`'ı değiştirmeden dönmez; `snoozedUntilMillis = now + minutes*60_000`, `snoozeUsed + 1`.

- [ ] **Step 1: Testleri yaz**

`AlarmMissionsTest.kt` sınıfına:

```kotlin
    @Test fun snoozeDuringActiveSnoozeRestartsFromNowAndCounts() {
        val a = args("is")
        missions.fired(a, fire)
        missions.stop(a, fire + 1000)
        missions.snooze("is", 5, fire + 2000)
        val again = missions.snooze("is", 5, fire + 122_000)!!
        assertEquals(fire + 122_000 + 300_000, again.snoozedUntilMillis)
        assertEquals(2, again.snoozeUsed)
        assertFalse(again.begun)
        assertNull(again.deadlineMillis)
    }

    @Test fun snoozeDuringActiveSnoozeStillHonorsLimit() {
        val a = args("is") // maxSnoozes 2
        missions.fired(a, fire)
        missions.stop(a, fire + 1000)
        missions.snooze("is", 5, fire + 2000)
        missions.snooze("is", 5, fire + 62_000)
        assertNull(missions.snooze("is", 5, fire + 122_000))
        assertEquals(2, missions.session("is")!!.snoozeUsed)
        assertEquals(fire + 62_000 + 300_000, missions.session("is")!!.snoozedUntilMillis)
    }
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "com.ekrembulbul.ezanvakti.AlarmMissionsTest" -q 2>&1 | tail -20`
Expected: iki yeni test FAIL.

- [ ] **Step 3: Uygula**

`AlarmMissions.kt` `snooze` içinden şu satırı sil:

```kotlin
        if ((current.snoozedUntilMillis ?: 0) > now) return@mutate current
```

Fonksiyonun üstüne yorum:

```kotlin
    /** Erteleme sürerken ikinci erteleme de uygulanır: yeni an şimdiden, sayaç +1
     *  (spec 2026-09-22 D12). Limit ve zincir tavanı aynen. */
```

- [ ] **Step 4: Yeşili gör**

Run: aynı gradle komutu.
Expected: BUILD SUCCESSFUL, tüm `AlarmMissionsTest` passed.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmMissions.kt android/app/src/test/kotlin/com/ekrembulbul/ezanvakti/AlarmMissionsTest.kt
git commit -m "fix(android): erteleme sürerken yeniden erteleme uygulanır, sayaç artar"
```

---

### Task 12: ADR 0002 güncellemesi ve platform build'leri

**Files:**
- Modify: `docs/adr/0002-stop-gate.md` ("Kapatma girişimleri de aynı kapıdan geçer" bölümü ve Referanslar)

- [ ] **Step 1: ADR bölümünü yeniden yaz**

"### Kapatma girişimleri de aynı kapıdan geçer" başlığından "Erteleme hakkı ayrı bir kural taşır..." paragrafına kadar olan bölümü şununla değiştir:

```markdown
### Kapatma girişimleri: kilit ve satırdan giriş (22 Eylül 2026)

`decide()` "ortada çalan alarm var mı" sorusunu cevaplar. Ödenmemiş görev borcu ise alarm ertelenmişken de durur, ve o sırada alarmı listeden pasife almak ya da sıradaki çalışını atlamak borçtan kaçmanın arka kapısıydı.

`StopGate.blocksDismissal()` bu ikinci soruyu sorar: *bu alarmın ödenmemiş görev borcu var mı?* Cevap evetse anahtar ve tek seferlik atlama anahtarı **devre dışıdır**; ertelenmiş alarmda anahtarın yerini geri sayım rozeti alır (spec 2026-09-22 D2/D6). Çıkış iki yoldan biridir:

- **Ertelenmişken** satıra ya da rozete dokunmak ara ekranı "ertelenmiş" kipinde açar (`openSnoozedAlarm`): kullanıcı görevi yapar (erteleme biter, görev ekranı; oradaki kademeli acil çıkış da borcu kapatır), yeniden erteler ya da görevsizde alarmı kapatır. X hiçbir şeyi değiştirmeden çıkar.
- **Ertelenmemişken** (nöbetçi ya da görev süresi penceresi) ara/görev ekranı zaten `openMissionIfPending` ile kendiliğinden açılır; kilit kısa sürer.

9 Eylül–22 Eylül arasındaki çözüm, kapatma girişimini doğrudan görev ekranına yönlendiriyordu (`resolveMissionBeforeDismiss`): koruma ile çıkış aynı yerdeydi ama seçim sunmuyordu — kullanıcı "kapat" deyip kendini QR okuturken buluyordu. Kullanıcı kararıyla kaldırıldı; seçim ara ekranda, giriş satırda.

Ondan önceki çözüm (kilitli anahtar + "görevi yapmadan kapatılamaz" uyarısı) kullanıcıyı çıkışsız bırakıyordu; bugünkü kilit satırdan girişle birlikte geldiği için o soruna dönmez.

Silme kapıya tabi değildir — kalıcı ve niyetli bir eylemdir, ve silinmiş bir alarmın görevini yaptırmak anlamsız olurdu.
```

"Değerlendirilen alternatifler" altına ekle:

```markdown
**Kapatma girişimini doğrudan görev ekranına yönlendirmek (9–22 Eylül).** Terk edildi: seçim sunmadan göreve düşürüyordu; ayrıca erteleme sürerken yeniden ertelemek için giriş yoktu.
```

Referanslar listesinde `lib/presentation/screens/mission_launcher.dart — resolveMissionBeforeDismiss() ve resolveSkipBeforeDismiss()` satırını şununla değiştir:

```markdown
- `lib/presentation/screens/mission_launcher.dart` — `openSnoozedAlarm()` ve `_StopHost` ertelenmiş kipi
- `lib/presentation/widgets/reminders/snooze_countdown.dart` — rozet
- `docs/superpowers/specs/2026-09-22-ertelenmis-alarm-geri-sayim-design.md` — D2/D5/D6/D12 kararları
```

- [ ] **Step 2: Doğrula**

Run: `git diff --check`
Expected: temiz.

- [ ] **Step 3: Platform build'leri**

Run:
```bash
flutter build apk --debug 2>&1 | tail -3
FLUTTER_XCODE_ARCHS=arm64 flutter build ios --simulator --debug 2>&1 | tail -3
```
Expected: ikisi de "Built ...".

- [ ] **Step 4: Commit**

```bash
git add docs/adr/0002-stop-gate.md
git commit -m "docs(adr): 0002 kapatma girişimleri — kilit ve satırdan giriş"
```

---

## Teslim

- Rapor: ne değişti, doğrulama çıktıları (analyze, flutter test, RunnerTests, gradle, iki build), test edilmeyen davranış: native alarmın gerçek cihazda zamanında çalması ve rozetin gerçek cihazdaki görünümü.
- Cihaz test listesi (Ekrem): ertele → Alarmlar satırı ve Sıradaki kartında rozet sayıyor → dokun → "ALARM ERTELENDİ" ekranı → X (değişmez) → tekrar dokun → Ertele (sayaç şimdi+n, hak −1) → tekrar dokun → Görevi yap → görev → alarm biter; görevsiz alarmda Alarmı kapat → yarın kurulu; süre dolunca alarm çalar, durdurma akışı aynen; ertelenmişken anahtar yok, görev penceresinde anahtar gri.
