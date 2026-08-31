# Tur 1 — Alarm Güvenilirliği Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tekrarlı alarmların uygulama açılmadan da her gün çalması; bayat görev ekranının kapanması; alarm kopyalama, QR kütüphanesi ve "Özel ses" etiketi düzeltmesi.

**Architecture:** Dart planlayıcı (AlarmScheduler) sabit tekrarlı alarmları AlarmKit native haftalık tekrara, çıpalı alarmları 7 günlük `.fixed` ön dizime çevirir. StopGate görevli yolda 60 dk bayatlık uygular; native zincir tavanı `chainStopped` olayıyla Dart'a bildirilir. DB v9: `qr_codes` tablosu + `'adhan'→'default'` düzeltmesi.

**Tech Stack:** Flutter/Dart, sqflite, AlarmKit (iOS 26.1+, Swift), flutter_test, XCTest.

**Spec:** `docs/superpowers/specs/2026-08-31-tur1-alarm-guvenilirligi-design.md`

## Global Constraints

- Kod/dosya/değişken adları İngilizce; yalnızca kullanıcıya görünen metin Türkçe (PRODUCT_SPEC.md).
- iOS deployment target 17.0; AlarmKit kodu `#available(iOS 26.1, *)` arkasında.
- Yeni bağımlılık eklenmez.
- Simülatör/cihaz sürme yok; doğrulama `flutter analyze` + `flutter test` (+ Swift testleri derleme ortamı varsa).
- Commit'ler bu branch'e (`feat/tur1-alarm`), Türkçe mesajla, `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` ile.

---

### Task 1: StopGate görevli bayatlık (F2)

**Files:**
- Modify: `lib/features/alarms/domain/stop_gate.dart:42-53`
- Test: `test/alarms/stop_gate_test.dart`

**Interfaces:**
- Consumes: `MissionTuning.chainDeadlineMinutes` (60), `MissionSession.stoppedAt`.
- Produces: `StopGate.decide` görevli yolda `stoppedAt + 60 dk < now` iken `StopDecision.closeAndRearm` döner. İmza değişmez.

- [ ] **Step 1: Failing testleri yaz** (`stop_gate_test.dart` içine, mevcut grup kalıbıyla)

```dart
test('gated: stale session (stoppedAt 61 dk once) closeAndRearm doner', () {
  final stoppedAt = DateTime(2026, 8, 31, 6, 0);
  final decision = StopGate.decide(
    alarm: gatedAlarm, // dosyada mevcut fixture; yoksa mission: AlarmMission.math ile kur
    session: MissionSession(alarmId: gatedAlarm.id, firedAt: stoppedAt, stoppedAt: stoppedAt),
    now: stoppedAt.add(const Duration(minutes: 61)),
  );
  expect(decision, StopDecision.closeAndRearm);
});

test('gated: 59 dk oncesi bayat degildir', () {
  final stoppedAt = DateTime(2026, 8, 31, 6, 0);
  final decision = StopGate.decide(
    alarm: gatedAlarm,
    session: MissionSession(alarmId: gatedAlarm.id, firedAt: stoppedAt, stoppedAt: stoppedAt),
    now: stoppedAt.add(const Duration(minutes: 59)),
  );
  expect(decision, isNot(StopDecision.closeAndRearm));
});
```

- [ ] **Step 2: Çalıştır, FAIL gör** — `flutter test test/alarms/stop_gate_test.dart`
- [ ] **Step 3: Implementasyon** — `decide` içinde, `requiresGate` dalından ÖNCE (görevsiz 45 sn kuralı kendi dalında kalır):

```dart
if (alarm.mission.requiresGate) {
  final staleAt = session.stoppedAt.add(
    const Duration(minutes: MissionTuning.chainDeadlineMinutes),
  );
  if (!now.isBefore(staleAt)) return StopDecision.closeAndRearm;
  return hasChoice ? StopDecision.showStopScreen : StopDecision.openMission;
}
```

(Mevcut `if (!alarm.mission.requiresGate) {...} return hasChoice ? ...` yapısını bu pozitif dala çevir; görevsiz blok aynen kalır.)

- [ ] **Step 4: Testler PASS** — `flutter test test/alarms/stop_gate_test.dart`
- [ ] **Step 5: Commit** — `fix: gorevli gorev ekranina 60 dk bayatlik siniri (StopGate)`

---

### Task 2: chainStopped olayı (F3)

**Files:**
- Modify: `ios/Runner/AppDelegate.swift:95-100` (stopChain dalı), `:120-128` (enqueue)
- Modify: `lib/core/models/mission_stop_event.dart`
- Modify: `lib/features/alarms/domain/mission_coordinator.dart:20-39`
- Modify: `lib/presentation/screens/mission_launcher.dart:46-60`
- Test: `test/alarms/mission_coordinator_test.dart`, `test/alarms/native_alarm_service_mission_test.dart`

**Interfaces:**
- Produces: `MissionStopEvent.chainStopped: bool` (fromMap: `map['chainStopped'] == true`).
- Produces: `MissionCoordinator.resume()` dönüşü `ResumeResult` olur: `class ResumeResult { final MissionSession? session; final String? chainStoppedAlarmId; }`. `chainStoppedAlarmId != null` ise launcher `complete(id)` + `rearmAlarms` yapar, ekran açmaz.

- [ ] **Step 1: Dart failing testler**

```dart
// mission_stop_event icin (native_alarm_service_mission_test.dart):
test('fromMap chainStopped bayragini okur, yoksa false', () {
  final e1 = MissionStopEvent.fromMap({'alarmId': 'a', 'stoppedAt': 1000, 'chainStopped': true});
  final e2 = MissionStopEvent.fromMap({'alarmId': 'a', 'stoppedAt': 1000});
  expect(e1.chainStopped, isTrue);
  expect(e2.chainStopped, isFalse);
});

// coordinator icin (mission_coordinator_test.dart, mevcut sahte AlarmService kalibiyla):
test('resume: chainStopped olayi oturumu acmaz, chainStoppedAlarmId doner', () async {
  fakeService.queuedEvents = [
    MissionStopEvent(alarmId: 'a1', stoppedAt: DateTime(2026, 8, 31, 6), chainStopped: true),
  ];
  final result = await coordinator.resume();
  expect(result.chainStoppedAlarmId, 'a1');
  expect(result.session, isNull);
  expect(await storage.getMissionSession(), isNull);
});
```

- [ ] **Step 2: FAIL gör** — `flutter test test/alarms/`
- [ ] **Step 3: Dart implementasyon**
  - `MissionStopEvent`e `final bool chainStopped;` (constructor default `false`; fromMap `map['chainStopped'] == true`).
  - `ResumeResult` sınıfı `mission_coordinator.dart` içinde.
  - `resume()`: olaylar içinde `chainStopped` olan varsa oturumu sil (`storage.saveMissionSession(null)`) ve `ResumeResult(session: null, chainStoppedAlarmId: o.alarmId)` dön; yoksa mevcut mantık `ResumeResult(session: ..., chainStoppedAlarmId: null)`.
  - `mission_launcher.dart openMissionIfPending`: `final result = await coordinator.resume();` → `if (result.chainStoppedAlarmId != null) { await coordinator.complete(result.chainStoppedAlarmId!); if (context.mounted) await rearmAlarms(context); return; }` — sonrası `result.session` ile mevcut akış. `_StopHostState._refresh` da `result.session` kullanacak şekilde güncellenir.
- [ ] **Step 4: PASS** — `flutter test test/alarms/ test/widgets/missions/`
- [ ] **Step 5: Swift** — `MissionChainStore.handleStop` `.stopChain` dalına, `save(s)` sonrası:

```swift
case .stopChain:
  s["pending"] = false
  save(s)
  enqueueEvent(alarmId: alarmId, chainStopped: true)
  AlarmKitHandler.notifyDart(alarmId: alarmId)
  NSLog("mission|chain|stopped|bounds|id=\(alarmId)")
  return
```

`enqueueStopEvent`i genelle:

```swift
static func enqueueStopEvent(alarmId: String) { enqueueEvent(alarmId: alarmId, chainStopped: false) }

static func enqueueEvent(alarmId: String, chainStopped: Bool) {
  var queue = UserDefaults.standard.array(forKey: eventsKey) as? [[String: Any]] ?? []
  var event: [String: Any] = [
    "alarmId": alarmId,
    "stoppedAt": Date().timeIntervalSince1970 * 1000,
  ]
  if chainStopped { event["chainStopped"] = true }
  queue.append(event)
  UserDefaults.standard.set(queue, forKey: eventsKey)
}
```

- [ ] **Step 6: Analyze + tüm testler** — `flutter analyze && flutter test`
- [ ] **Step 7: Commit** — `fix: zincir tavani Dart'a chainStopped olayiyla bildiriliyor; oturum kapaniyor`

---

### Task 3: Sabit tekrarlı alarm → AlarmKit haftalık tekrar (F1a)

**Files:**
- Modify: `lib/core/interfaces/alarm_service.dart` (scheduleAlarm imzası), `lib/features/alarms/data/native_alarm_service.dart:62-90`, `lib/features/alarms/domain/alarm_scheduler.dart:37-96`
- Modify: `ios/Runner/AppDelegate.swift:217-317`
- Test: `test/alarms/alarm_scheduler_error_test.dart` yanına yeni `test/alarms/alarm_scheduler_repeat_test.dart`, RunnerTests'e `WeekdayMappingTests.swift`

**Interfaces:**
- Produces: `scheduleAlarm(..., {List<int> repeatWeekdays = const []})` — dolu ise Swift `.relative(time: hour/minute, repeats: .weekly)` kurar ve `timeMillis`i yalnızca zincir (ladder/chainDeadline) için kullanır.
- Produces: `AlarmScheduler` kuralı: `kind == fixed && weekdays yok/tekrarli && o hafta icin skip yok` → `repeatWeekdays` dolu gönderilir (boş küme = her gün = `[1..7]`). Skip varsa `repeatWeekdays` boş gönderilir (mevcut tek-seferlik yol).

- [ ] **Step 1: Failing test** (`alarm_scheduler_repeat_test.dart`; `alarm_scheduler_error_test.dart`teki sahte `AlarmService` kalıbını kopyala, `scheduleAlarm` çağrılarını kaydetsin)

```dart
test('sabit tekrarli alarm repeatWeekdays ile planlanir', () async {
  final alarm = Alarm(id: 'a1', kind: AlarmKind.fixed, hour: 6, minute: 30, weekdays: {1, 5});
  await storage.saveAlarm(alarm);
  await scheduler.scheduleAlarms(prayerTimes: [/* bos yeterli: fixed vakit istemez */]);
  expect(fakeService.calls.single.repeatWeekdays, [1, 5]);
});

test('skip varsa sabit tekrarli alarm tek seferlik yola duser', () async {
  final alarm = Alarm(id: 'a1', kind: AlarmKind.fixed, hour: 6, minute: 30, weekdays: {});
  await storage.saveAlarm(alarm);
  final fire = AlarmScheduler.computeNextFire(
    alarm: alarm, now: now, prayerTimesByDate: const {});
  await scheduler.scheduleAlarms(
    prayerTimes: const [],
    skips: {SkippedOccurrence(kind: SkipKind.alarm, reference: 'a1', fireAt: fire!)},
  );
  expect(fakeService.calls.single.repeatWeekdays, isEmpty);
});
```

- [ ] **Step 2: FAIL gör**
- [ ] **Step 3: Dart implementasyon** — `AlarmService.scheduleAlarm` ve `NativeAlarmService`e `repeatWeekdays` parametresi (`'repeatWeekdays': repeatWeekdays` channel argümanı). `AlarmScheduler.scheduleAlarms` döngüsünde:

```dart
final repeatWeekdays = _relativeWeekdaysFor(alarm, now: now, skips: skips);
// ...
await alarmService.scheduleAlarm(..., repeatWeekdays: repeatWeekdays);

/// Sabit tekrarli alarm icin native haftalik tekrar gunleri; skip'li hafta
/// veya cipali/tek-seferlik alarmda bos (tek seferlik .fixed yolu).
static List<int> _relativeWeekdaysFor(Alarm alarm, {required DateTime now, required Set<SkippedOccurrence> skips}) {
  if (alarm.kind != AlarmKind.fixed) return const [];
  final days = alarm.weekdays.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : alarm.weekdays;
  final next = computeNextFire(alarm: alarm, now: now, prayerTimesByDate: const {}, skips: skips);
  final nextRaw = computeNextFire(alarm: alarm, now: now, prayerTimesByDate: const {});
  if (next == null || nextRaw == null || next != nextRaw) return const []; // skip devrede
  return (days.toList()..sort());
}
```

- [ ] **Step 4: Dart PASS** — `flutter test test/alarms/`
- [ ] **Step 5: Swift implementasyon** — `scheduleAlarm` içinde:

```swift
let repeatWeekdays = args["repeatWeekdays"] as? [Int] ?? []
let schedule: Alarm.Schedule
if repeatWeekdays.isEmpty {
  schedule = .fixed(date)
} else {
  let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
  schedule = .relative(.init(
    time: .init(hour: comps.hour ?? 0, minute: comps.minute ?? 0),
    repeats: .weekly(Self.localeWeekdays(fromIso: repeatWeekdays))))
}
// config: schedule: schedule (eski .fixed(date) yerine)
```

Saf eşleme (test edilebilir, `AlarmKitHandler` içinde `static`):

```swift
static func localeWeekdays(fromIso days: [Int]) -> [Locale.Weekday] {
  let map: [Int: Locale.Weekday] = [
    1: .monday, 2: .tuesday, 3: .wednesday, 4: .thursday,
    5: .friday, 6: .saturday, 7: .sunday,
  ]
  return days.compactMap { map[$0] }
}
```

- [ ] **Step 6: Swift test** — `ios/RunnerTests/WeekdayMappingTests.swift`:

```swift
import XCTest
@testable import Runner

final class WeekdayMappingTests: XCTestCase {
  func testIsoWeekdayMapping() {
    if #available(iOS 26.1, *) {
      XCTAssertEqual(AlarmKitHandler.localeWeekdays(fromIso: [1, 5, 7]), [.monday, .friday, .sunday])
      XCTAssertEqual(AlarmKitHandler.localeWeekdays(fromIso: [9]), [])
    }
  }
}
```

- [ ] **Step 7: Analyze + testler; Swift derlemesi için** `xcodebuild -project ios/Runner.xcodeproj -scheme Runner -destination 'generic/platform=iOS' build ANALYZE=NO` yerine mevcut alışkanlık neyse onu kullan (yoksa Swift derleme doğrulaması tur sonu CI/TestFlight build'ine kalır — planda not düş).
- [ ] **Step 8: Commit** — `feat: sabit tekrarli alarmlar AlarmKit haftalik tekrariyla kuruluyor`

---

### Task 4: Çıpalı alarm 7 günlük ön dizim (F1b)

**Files:**
- Modify: `lib/features/alarms/domain/alarm_scheduler.dart` (yeni `computeNextFires` + scheduleAlarms döngüsü)
- Modify: `ios/Runner/MissionChainKeys.swift` (+ testi `ios/RunnerTests/MissionChainKeysTests.swift`)
- Test: `test/alarms/alarm_scheduler_repeat_test.dart`

**Interfaces:**
- Produces: `static List<DateTime> computeNextFires({required Alarm alarm, required DateTime now, required Map<DateTime, PrayerTime> prayerTimesByDate, int searchDays = 8, int limit = 7, Set<SkippedOccurrence> skips = const {}})` — `computeNextFire` ile aynı kurallar, ilk `limit` çalışı döner.
- Produces: çıpalı tekrarlı alarm `id#d0..#d6` kimlikleriyle kurulur; `#d0` `missionEnabled/chainConfig` taşır, `#d1..` `missionEnabled: false, snoozeEnabled: false` ile kurulur (session/ladder yazılmaz; stopIntent konmaz — durdurma kesin, uygulama açılışı genel yeniden planlamayı koşturur).
- Produces: `MissionChainKeys.select` `<id>#d<N>` anahtarlarını da alarmın zinciri sayar (cancel kapsar).

- [ ] **Step 1: Failing testler**

```dart
test('cipali alarm 7 gunluk dizi olarak planlanir', () async {
  final alarm = Alarm(id: 'a1', kind: AlarmKind.anchored, anchor: PrayerType.fajr, offsetMinutes: -30);
  await storage.saveAlarm(alarm);
  await scheduler.scheduleAlarms(prayerTimes: sevenDaysOfPrayerTimes);
  expect(fakeService.calls.map((c) => c.id).toList(),
      ['a1#d0', 'a1#d1', 'a1#d2', 'a1#d3', 'a1#d4', 'a1#d5', 'a1#d6']);
  expect(fakeService.calls.first.missionEnabled, isTrue); // alarm.mission'a gore
  expect(fakeService.calls.skip(1).every((c) => !c.missionEnabled), isTrue);
});

test('computeNextFires skip edilen gunu atlar', () { /* 2. gunu skip'le, listede olmamali */ });
```

- [ ] **Step 2: FAIL gör**
- [ ] **Step 3: Implementasyon** — `computeNextFires` = mevcut döngünün `return` yerine listeye ekleyip devam eden hali (`computeNextFire` onu `firstOrNull` ile çağırır — tek kaynağa indir). `scheduleAlarms`ta `alarm.kind == AlarmKind.anchored` ise dizi kur; `MissionChainKeys.swift`te `select`in alarm anahtarı eşleşmesine `#d` öneki ekle (mevcut `#w`/`#ladder` kalıbının yanına) + `MissionChainKeysTests.swift`e vaka.
- [ ] **Step 4: PASS** — `flutter test test/alarms/`
- [ ] **Step 5: Commit** — `feat: cipali alarmlar 7 gun onden diziliyor (#d0..#d6)`

---

### Task 5: Kurulamayan alarm görünür (F4)

**Files:**
- Modify: `lib/features/alarms/domain/alarm_scheduler.dart:92-94` (catch), `lib/core/interfaces/local_storage.dart` + `lib/features/prayer_times/data/sqlite_storage.dart` (`getAlarmScheduleFailures`/`saveAlarmScheduleFailures`), `lib/presentation/widgets/reminders/alarms_section.dart:88-93` (+ `reminders_screen.dart` kablolama)
- Test: `test/alarms/alarm_scheduler_error_test.dart`

**Interfaces:**
- Produces: `LocalStorage.getAlarmScheduleFailures() → Future<Map<String, String>>` (alarmId → kısa mesaj) ve `saveAlarmScheduleFailures(Map<String, String>)`; `settings` anahtarı `alarm_schedule_failures`.
- Produces: `AlarmsSection`e `Map<String, String> scheduleFailures` parametresi; başarısız satır alt metni: `"Kurulamadı — düzenleyip kaydederek yeniden dene"`.

- [ ] **Step 1: Failing test** — sahte servis `scheduleAlarm`da `PlatformException` fırlatınca `storage.getAlarmScheduleFailures()` o alarmı içermeli; bir sonraki başarılı planlamada temizlenmeli.
- [ ] **Step 2: FAIL gör**
- [ ] **Step 3: Implementasyon** — `scheduleAlarms` başında boş map; her hata `failures[alarm.id] = e.toString()` (kısalt: ilk 120 karakter); döngü sonunda `saveAlarmScheduleFailures(failures)`. UI: `reminders_screen` storage'dan okuyup `AlarmsSection`e geçirir; `_subtitle` önceliği: kurulamadı > ertelendi > atlandı > kapalı.
- [ ] **Step 4: PASS + analyze**
- [ ] **Step 5: Commit** — `feat: kurulamayan alarm satirda gorunur uyari veriyor`

---

### Task 6: DB v9 — qr_codes + 'adhan'→'default' (ALM.3 altyapı + ALM.4)

**Files:**
- Modify: `lib/features/prayer_times/data/sqlite_storage.dart` (version 9, `_onCreate`, `_onUpgrade`, `_createAlarmsTable` DEFAULT, QR CRUD), `lib/core/interfaces/local_storage.dart`, `lib/core/models/alarm.dart` (varsayılan `soundId: 'default'`), `lib/presentation/screens/alarm_edit_screen.dart:69` (`?? 'default'`) ve `:544-545` (bilinmeyen değer → 'Varsayılan')
- Create: `lib/core/models/qr_code_entry.dart`
- Test: `test/` altında storage testlerinin bulunduğu kalıba uyan yeni `test/features/prayer_times/sqlite_storage_v9_test.dart` (sqflite testleri mevcutta nasıl koşuyorsa — ffi kalıbı yoksa model + CRUD testini `sqflite_common_ffi` OLMADAN yazamayız; o durumda migration SQL'i inceleme + mevcut test kalıbı neyse ona uy; kalıp yoksa bu task'ın testi `QrCodeEntry` serileştirmesi + `Alarm` varsayılanıyla sınırlı kalır ve migration tur sonu cihaz testinde doğrulanır — planda kabul edilen boşluk)

**Interfaces:**
- Produces: `class QrCodeEntry { final String id; final String label; final String payload; final DateTime createdAt; }` (+ `toMap/fromMap`).
- Produces: `LocalStorage.getQrCodes() → Future<List<QrCodeEntry>>`, `saveQrCode(QrCodeEntry)`, `deleteQrCode(String id)`.
- Produces: DB version 9: `CREATE TABLE qr_codes(id TEXT PRIMARY KEY, label TEXT NOT NULL, payload TEXT NOT NULL, created_at TEXT NOT NULL)`; `UPDATE alarms SET sound_id='default' WHERE sound_id='adhan'`; `_createAlarmsTable` içinde `sound_id ... DEFAULT 'default'`.

- [ ] **Step 1: Test(ler)i yaz** (kalıba göre; en az `Alarm` varsayılanı `'default'` ve `QrCodeEntry` round-trip)
- [ ] **Step 2: FAIL gör**
- [ ] **Step 3: Implementasyon** (yukarıdaki üretimler + `_onUpgrade`e `if (oldVersion < 9) {...}`)
- [ ] **Step 4: PASS + analyze**
- [ ] **Step 5: Commit** — `feat: DB v9 - qr_codes tablosu; alarm ses varsayilani 'default' (Ozel ses etiketi duzeltmesi)`

---

### Task 7: QR kütüphanesi UI (ALM.3)

**Files:**
- Modify: `lib/presentation/screens/alarm_edit_screen.dart` (QR bölümü: kayıtlı kod seçici + okut-adlandır-kaydet), gerekirse yeni `lib/presentation/widgets/alarms/qr_library_sheet.dart`
- Test: `test/` altında mevcut alarm edit widget test kalıbı varsa ona vaka; yoksa `QrCodeEntry` seçim mantığını saf yardımcıya çekip birim test

**Interfaces:**
- Consumes: Task 6'nın `LocalStorage` QR API'si.
- Produces: QR bölümünde: seçili kodun etiketi görünür; "Kayıtlı kodlardan seç" alt sayfası (liste + sil/yeniden adlandır); "Yeni kod okut" mevcut tarama akışının sonuna ad sorup `saveQrCode` çağırır ve `_qrPayload`ı doldurur. Silmede, payload'ı kullanan alarm varsa (`getAlarms` üzerinden kontrol) uyarı dialog'u.

- [ ] **Step 1: Saf mantık testi** (ör. `qrLibraryUsage(alarms, payload)` → kullanan alarm etiketleri)
- [ ] **Step 2: FAIL → implementasyon → PASS**
- [ ] **Step 3: UI kablolama + `flutter analyze`**
- [ ] **Step 4: Commit** — `feat: QR kod kutuphanesi - kayitli kodlardan secim ve adlandirarak kaydetme`

---

### Task 8: Alarm kopyalama (ALM.2)

**Files:**
- Modify: `lib/features/alarms/domain/alarms_manager.dart` (+ `duplicate`), `lib/presentation/widgets/reminders/alarms_section.dart` (`GroupedRow onLongPress` → alt sayfa: Kopyala/Sil), `lib/presentation/screens/reminders_screen.dart` (kablolama: kopyayı edit ekranında aç)
- Test: `test/alarms/alarms_manager_test.dart` (yoksa oluştur)

**Interfaces:**
- Produces: `Alarm duplicateOf(Alarm source, {required String newId})` (saf; `alarms_manager.dart` içinde top-level ya da static): `isActive: true`, `label: source.label.isEmpty ? '' : '${source.label} (kopya)'`, diğer alanlar aynı. **Kaydetmez** — edit ekranı kaydeder.

- [ ] **Step 1: Failing test**

```dart
test('duplicateOf yeni id ve "(kopya)" etiketiyle kopyalar, kaydetmez', () {
  final copy = duplicateOf(source, newId: 'n1');
  expect(copy.id, 'n1');
  expect(copy.label, 'Sahur (kopya)');
  expect(copy.hour, source.hour);
});
```

- [ ] **Step 2: FAIL → implementasyon → PASS**
- [ ] **Step 3: UI: uzun basma alt sayfası + edit ekranına `isNew` kopya akışı; `flutter analyze`**
- [ ] **Step 4: Commit** — `feat: alarma uzun basarak kopyalama`

---

### Task 9: ALM.5 bilgilendirme + kapanış

**Files:**
- Modify: `lib/presentation/screens/alarm_edit_screen.dart` (ses satırı altına tek satır: `"Alarm, Zil Sesi ve Uyarılar seviyesiyle çalar."`)
- Modify: `pubspec.yaml` (`version: 0.6.0+32`), `CHANGELOG.md` (0.6.0 bölümü: K1/K2/K3 düzeltmeleri, kopyalama, QR kütüphanesi, Özel ses düzeltmesi), `docs/ROADMAP.md` (tamamlananlar)

- [ ] **Step 1: Metin + sürüm + changelog değişiklikleri**
- [ ] **Step 2: Tam doğrulama** — `flutter analyze && flutter test` (tamamı yeşil; çıktı rapora)
- [ ] **Step 3: Commit** — `docs: 0.6.0 surum notlari ve ALM.5 ses bilgilendirmesi`
- [ ] **Step 4: Ekrem'e cihaz test listesi + TestFlight sorusu** (merge/tag onaysız yapılmaz)
