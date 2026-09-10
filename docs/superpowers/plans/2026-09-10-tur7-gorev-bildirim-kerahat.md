# Tur 7 uygulama planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Hedef:** [Tur 7 tasarımını](../specs/2026-09-10-tur7-gorev-bildirim-kerahat-design.md) uygulamak: AlarmKit düzenleme hatası, matematik tuş takımı ve dört zorluk, hatırlatıcı satırı, tam sayfa bildirim düzenleme, kerahat yaklaşıyor uyarısı (ana ekran + iOS widget).

**Mimari:** Dart tarafında saf domain (MathChallenge, KerahatStatus, ReminderPoint) + mevcut `ServiceLocator`/`AppState` düzeni; iOS'ta `AlarmPlanEngine.upsert` ve widget timeline/snapshot. Yeni Swift dosyası yalnız `ios/EzanVaktiWidget/` altında açılır (Xcode'da yalnız o grup dosya sistemiyle eşitli); `WidgetCore` ve `RunnerTests` mevcut dosyalara eklenir.

**Çalışma:** Kullanıcı spec, plan ve implementasyonu birlikte istedi ("kodun hepsini yazana kadar durma"). Inline; alt agent yok. `dev` üzerinde atomik yerel commit'ler, Türkçe Conventional Commit; push/release yok. TDD: her görevde önce kırmızı test.

**Spec:** `docs/superpowers/specs/2026-09-10-tur7-gorev-bildirim-kerahat-design.md`

## Global kısıtlar

- Kullanıcıya görünen metin ARB'de (`app_tr.arb` kaynak; `app_en.arb`, `app_ar.arb` karşılıkları); sonra `flutter gen-l10n`.
- Renk/tipografi yalnız `context.tokens` ve `AppTypography` üzerinden.
- `flutter test | tail -1` exit code'u yutar: `flutter test > out.log; echo $?`.
- Kerahat uyarı eşiği 30 dk; matematik seviyeleri `1..4`; snapshot şeması 4; widget `maxEntries` 24.
- Commit sonunda: `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>` (o anki model neyse).

---

### Görev 1: AlarmKit aynı id'yi güncellemez — `upsert` taze UUID ile kurar

**Dosyalar:**
- Değiştir: `ios/Runner/AlarmPlanEngine.swift:199-212` (`upsert`)
- Test: `ios/RunnerTests/AlarmPlanEngineTests.swift` (`FakeAlarmPlatform.schedule`, yeni test)
- Belge: `docs/adr/0003-platform-alarm-models.md` ("iOS — sistem sahipliğinde" bölümü)

**Arayüzler:**
- Üretir: `upsert(_:)` imzası aynı; davranış: mevcut kayıt farklıysa yeni UUID + eski iptal. Journal işlemi `retire_replaced` (yalnız iptal hatasında, `result: "failed"`).

- [ ] **Adım 1: Fake platform AlarmKit gibi duplicate id'yi reddetsin + kırmızı test**

`FakeAlarmPlatform`:
```swift
enum Failure: Error { case injected, duplicateId }
func schedule(id: UUID, configuration: AlarmMissionConfiguration) async throws {
  operations.append("schedule:" + configuration.scheduleId)
  if failSchedules.contains(configuration.scheduleId) || failSchedules.contains("*") { throw Failure.injected }
  // AlarmKit var olan id'yi güncellemez; cihazda `invalidInput` ("duplicate ID") görüldü.
  if records[id] != nil { throw Failure.duplicateId }
  records[id] = configuration
  states[id] = .scheduled
}
```
Yeni test:
```swift
@MainActor
func testChangedConfigurationIsRegisteredUnderFreshIdAndOldOneRetired() async throws {
  let (engine, backend, clock) = fixture()
  var alarm = record("work", at: clock.now + 60_000)
  _ = try await engine.reconcile(records: [alarm], enabledAlarmIds: ["work"])
  let oldId = engine.mapping[alarm.scheduleId]!
  alarm.label = "changed"
  let failures = try await engine.reconcile(records: [alarm], enabledAlarmIds: ["work"])
  XCTAssertTrue(failures.isEmpty)
  let newId = engine.mapping[alarm.scheduleId]!
  XCTAssertNotEqual(newId, oldId)
  XCTAssertEqual(backend.records[newId]?.label, "changed")
  XCTAssertNil(backend.records[oldId])
  XCTAssertEqual(backend.records.count, 1)
}

@MainActor
func testFailedReplacementOfChangedConfigurationKeepsOldRecord() async throws {
  let (engine, backend, clock) = fixture()
  var alarm = record("work", at: clock.now + 60_000)
  _ = try await engine.reconcile(records: [alarm], enabledAlarmIds: ["work"])
  let oldId = engine.mapping[alarm.scheduleId]!
  alarm.label = "changed"
  backend.failSchedules = [alarm.scheduleId]
  let failures = try await engine.reconcile(records: [alarm], enabledAlarmIds: ["work"])
  XCTAssertNotNil(failures["work"])
  XCTAssertEqual(engine.mapping[alarm.scheduleId], oldId)
  XCTAssertEqual(backend.records[oldId]?.label, "work")
}
```

- [ ] **Adım 2: Kırmızıyı gör**

`xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RunnerTests/AlarmPlanEngineTests 2>&1 | grep -E "error:|failed|passed" | tail`
Beklenen: ilk yeni test `failures.isEmpty` üzerinde kırmızı (fake `duplicateId` fırlatır).

- [ ] **Adım 3: `upsert` düzeltmesi**

```swift
func upsert(_ record: AlarmMissionConfiguration) async throws {
  try validateState()
  var retiring: UUID?
  if let id = mapping[record.scheduleId], let state = try platform.alarms()[id] {
    if state.protectsDelivery { return }
    if let old = missions.configurations[record.scheduleId], old.hasSameSchedule(as: record) { return }
    // AlarmKit var olan id'yi güncellemez (invalidInput / "duplicate ID",
    // cihaz arşivi 2026-09-10). Değişiklik yeni id ile kurulur, eski sonra
    // kaldırılır; yeni kurulum patlarsa çalışan eski kayıt yerinde kalır.
    retiring = id
  }
  guard record.fireAtMillis.isFinite,
    !record.repeatWeekdays.isEmpty || record.fireAtMillis > clock()
  else { throw EngineError.invalidTime }
  journal.record("schedule_requested", at: clock(), configuration: record)
  let id = retiring == nil ? uuid(for: record.scheduleId) : UUID()
  try await platform.schedule(id: id, configuration: record)
  if let retiring {
    var values = mapping
    values[record.scheduleId] = id
    setMapping(values)
    do { try platform.cancel(id: retiring) }
    catch {
      // Eşleme yeni id'de; eski kayıt reconcile sonundaki orphan geçişinde
      // yeniden denenir.
      journal.record("retire_replaced", at: clock(), configuration: record,
        scheduleId: record.scheduleId, result: "failed", error: error)
    }
  }
  try missions.configure(record)
  journal.record("scheduled", at: clock(), configuration: record)
}
```

- [ ] **Adım 4: Tüm RunnerTests yeşil**

Aynı `xcodebuild test … -only-testing:RunnerTests`; beklenen: `** TEST SUCCEEDED **`.

- [ ] **Adım 5: ADR 0003 notu ve commit**

ADR "iOS — sistem sahipliğinde" altına paragraf: AlarmKit `schedule(id:)` var olan id'yi güncellemez; değişen kayıt taze UUID ile kurulup eskisi kaldırılır; kanıt 2026-09-10 cihaz arşivi.

```bash
git add ios/Runner/AlarmPlanEngine.swift ios/RunnerTests/AlarmPlanEngineTests.swift docs/adr/0003-platform-alarm-models.md
git commit -m "fix(alarms): değişen AlarmKit kaydını taze id ile kur"
```

---

### Görev 2: `MathChallenge` dört seviye

**Dosyalar:**
- Değiştir: `lib/features/alarms/domain/math_challenge.dart`
- Test: `test/alarms/math_challenge_test.dart`

**Arayüzler:**
- Üretir: `MathChallenge.maxLevel = 4`, `MathChallenge.questionCount(int level)`, `MathChallenge.generate({level, random})` (imza aynı).

- [ ] **Adım 1: Kırmızı testler**

```dart
test('Dort seviye: soru sayisi 1,2,3,3', () {
  expect([1, 2, 3, 4].map(MathChallenge.questionCount), [1, 2, 3, 3]);
});
test('Aralik disi seviye en yakin uca kirpilir', () {
  expect(MathChallenge.questionCount(0), MathChallenge.questionCount(1));
  expect(MathChallenge.questionCount(9), MathChallenge.questionCount(MathChallenge.maxLevel));
});
test('Kolay: iki haneli +/- tek haneli, carpma yok', () {
  for (var seed = 0; seed < 200; seed++) {
    for (final q in MathChallenge.generate(level: 1, random: Random(seed))) {
      expect(q.op, isNot(MathOp.multiply), reason: q.text);
      expect(q.a, inInclusiveRange(10, 99), reason: q.text);
      expect(q.b, inInclusiveRange(2, 9), reason: q.text);
      expect(q.answer, greaterThanOrEqualTo(1), reason: q.text);
    }
  }
});
test('Orta: iki haneli +/- iki haneli', () { /* a,b 10..99, op != multiply, answer >= 0 */ });
test('Zor: iki haneli x tek haneli', () { /* op == multiply, a 10..99, b 2..9 */ });
test('Ekstrem: iki haneli x iki haneli', () { /* op == multiply, a,b 11..99 */ });
```
Mevcut "Seviye yukseldikce is miktari artar" testi: 2>1, 3>2, 4>=3 olarak güncellenir; "Seviye 1 carpma icermez" ve "en az bir operand > 9" (seviye 3) kalır; seviye listeleri `[1,2,3,4]`.

- [ ] **Adım 2: Kırmızıyı gör** — `flutter test test/alarms/math_challenge_test.dart`

- [ ] **Adım 3: Uygulama**

```dart
static const int maxLevel = 4;
static const Map<int, int> _counts = {1: 1, 2: 2, 3: 3, 4: 3};
static int _clampLevel(int level) => level.clamp(1, maxLevel);

static MathQuestion _one(int level, Random random) {
  switch (level) {
    case 1:
      // Kolay: iki haneli ± tek haneli. a > b olduğu için çıkarma negatif olmaz.
      final op = random.nextBool() ? MathOp.add : MathOp.subtract;
      return MathQuestion(a: 10 + random.nextInt(90), b: 2 + random.nextInt(8), op: op);
    case 2:
      final op = random.nextBool() ? MathOp.add : MathOp.subtract;
      final x = 10 + random.nextInt(90);
      final y = 10 + random.nextInt(90);
      return op == MathOp.subtract
          ? MathQuestion(a: max(x, y), b: min(x, y), op: op)
          : MathQuestion(a: x, b: y, op: op);
    case 3:
      return MathQuestion(a: 10 + random.nextInt(90), b: 2 + random.nextInt(8), op: MathOp.multiply);
    default:
      return MathQuestion(a: 11 + random.nextInt(89), b: 11 + random.nextInt(89), op: MathOp.multiply);
  }
}
```

- [ ] **Adım 4: Yeşil** — aynı komut. **Adım 5: Commit** `feat(missions): matematik görevine dört zorluk seviyesi`

---

### Görev 3: Matematik ekranı tuş takımı

**Dosyalar:**
- Değiştir: `lib/presentation/widgets/missions/math_mission.dart`, `lib/presentation/widgets/missions/mission_metrics.dart`
- Test: `test/widgets/missions/math_mission_test.dart`, `test/widgets/missions/mission_launcher_test.dart` (`solveMath`)

**Arayüzler:**
- Üretir: `Key kMathKey(int digit)`, `const Key kMathBackspaceKey`, `const Key kMathAnswerKey`; `kMathSubmitKey`, `kMathProgressKey` kalır; `kMathFieldKey` silinir. `const double kMissionKeyFontSize = 26`.

- [ ] **Adım 1: Kırmızı testler** — `answerAll` rakamları tuşlayarak girer:

```dart
Future<void> type(WidgetTester tester, int answer) async {
  for (final ch in '$answer'.split('')) {
    await tester.tap(find.byKey(kMathKey(int.parse(ch))));
    await tester.pump();
  }
}
testWidgets('Rakamlar tusla girilir, TextField yok', (tester) async {
  await tester.pumpWidget(wrapWithTheme(MathMission(level: 2, random: Random(7), onCompleted: () {})));
  expect(find.byType(TextField), findsNothing);
  await type(tester, 42);
  expect(find.descendant(of: find.byKey(kMathAnswerKey), matching: find.text('42')), findsOneWidget);
});
testWidgets('Geri tusu son rakami siler, uzun basinca hepsini', ...);
testWidgets('Tum sorular dogru cevaplanirsa tamamlanir', ...);          // type + submit
testWidgets('Yanlis cevap ilerletmez, uyari gosterir ve girdiyi temizler', ...);
testWidgets('Bos cevap gonderilemez', ...);
testWidgets('Dar ekranda tasmaz', (tester) async {
  tester.view.physicalSize = const Size(750, 1000); tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(wrapWithTheme(MathMission(level: 4, random: Random(1), onCompleted: () {})));
  expect(tester.takeException(), isNull);
  expect(find.byType(SingleChildScrollView), findsNothing);
});
```
`mission_launcher_test.solveMath`: `enterText(kMathFieldKey)` yerine rakam tuşları.

- [ ] **Adım 2: Kırmızıyı gör** — `flutter test test/widgets/missions/math_mission_test.dart`

- [ ] **Adım 3: Uygulama** — `_MathMissionState`: `String _input = ''`; `_append(int)` (6 hane), `_backspace()`, `_clear()`, `_submit()` (`int.tryParse(_input)`); `build`: `Column(children: [_progress, 16, _questionCard, 16, _answerDisplay, _wrongHint, 12, Expanded(child: _keypad)])`. `_keypad`: 4 `Expanded(Row)` satırı, her hücre `Expanded(Padding(_key))`; `_key` → `Material` + `InkWell`, `Center(FittedBox(Text(digit, gridValue.copyWith(fontSize: kMissionKeyFontSize))))`; `⌫` `Icons.backspace_outlined` + `onLongPress: _clear`; `✓` accent dolgu, `Icons.check_rounded` + altında küçük "Onayla"/"Bitir". Semantik etiketler: rakam metni, `l10n.actionDelete`, gönder etiketi.

- [ ] **Adım 4: Yeşil** — `flutter test test/widgets/missions/`. **Adım 5: Commit** `feat(missions): matematik görevinde ekran tuş takımı`

---

### Görev 4: Zorluk seçici, seviye etiketi, l10n

**Dosyalar:**
- Değiştir: `lib/presentation/screens/alarm_edit_screen.dart` (`_missionSelector` altına `_levelSelector`, `_save` içinde `missionLevel: _mission == AlarmMission.math ? _missionLevel : 1`), `lib/presentation/utils/alarm_labels.dart` (`missionLevelLabel`, `missionLevelHint`), `lib/presentation/screens/alarm_stop_screen.dart:216-219`, `lib/l10n/app_tr.arb` + en + ar
- Test: `test/widgets/alarm_edit_screen_test.dart` (mevcutsa; yoksa `test/widgets/alarms/alarm_edit_level_test.dart`), `test/presentation/alarm_labels_test.dart`

**Arayüzler:**
- Üretir: `String missionLevelLabel(int level, AppLocalizations l10n)` → Kolay/Orta/Zor/Ekstrem; `String missionLevelHint(int level, AppLocalizations l10n)`.
- ARB: `missionLevel` "Zorluk", `missionLevelEasy` "Kolay", `missionLevelMedium` "Orta", `missionLevelHard` "Zor", `missionLevelExtreme` "Ekstrem", `missionLevelEasyHint` "1 soru · toplama, çıkarma", `missionLevelMediumHint` "2 soru · iki haneli toplama, çıkarma", `missionLevelHardHint` "3 soru · iki haneli × tek haneli", `missionLevelExtremeHint` "3 soru · iki haneli × iki haneli".

- [ ] **Adım 1: Kırmızı** — labels testi (`missionLevelLabel(4, l10n) == 'Ekstrem'`, `missionLevelLabel(9, l10n) == 'Ekstrem'`), edit ekranı testi: görev Matematik seçilince "Zorluk" satırı görünür, Sallama'da görünmez; "Ekstrem" seçip kaydedince `missionLevel == 4`; görev Sallama iken kaydedince `missionLevel == 1`.
- [ ] **Adım 2: Kırmızıyı gör.** **Adım 3: Uygulama** (`OptionRow<int>` items 1..4, `sheetTitle: l10n.missionLevel`). Stop screen: `missionLevelLabel(alarm.missionLevel, l10n)`.
- [ ] **Adım 4: `flutter gen-l10n`, yeşil.** **Adım 5: Commit** `feat(alarms): matematik görevi için zorluk seçimi`

---

### Görev 5: Hatırlatıcı satırı düzeni

**Dosyalar:**
- Değiştir: `lib/presentation/widgets/reminders/reminder_row.dart`
- Test: `test/widgets/reminders/reminder_row_layout_test.dart`

- [ ] **Adım 1: Kırmızı** — `find.text(label)` stil `fontSize == 16 && fontWeight == FontWeight.w600`; etiket ve detail farklı `Text`lerde ve etiket detail'in üstünde (`tester.getTopLeft(label).dy < tester.getTopLeft(detail).dy`).
- [ ] **Adım 2: Kırmızıyı gör.** **Adım 3: Uygulama** — `Wrap` yerine: `if (label != null) Text(label, rowTitle.copyWith(fontWeight: w600, color: textPrimary))`; sonra `if (detail != null || remaining != null) Text([detail, remaining].whereType<String>().join(' · '), rowSubtitle, tabular)`.
- [ ] **Adım 4: Yeşil (tr/ar 1.8 ölçek testi dahil).** **Adım 5: Commit** `feat(reminders): satırda etiket büyük, zaman bilgisi altta`

---

### Görev 6: `ReminderPoint`, `NotificationDraft`, gruplu `OptionPicker`

**Dosyalar:**
- Oluştur: `lib/core/models/reminder_point.dart`, `lib/core/models/notification_draft.dart`
- Değiştir: `lib/presentation/widgets/common/option_picker.dart` (`OptionItem.group`, `_OptionSheet` grup başlığı)
- Test: `test/models/reminder_point_test.dart`, `test/widgets/common/option_picker_test.dart`

**Arayüzler:**
```dart
class ReminderPoint {
  final PrayerType anchor; final DerivedTimeKind? derived;
  const ReminderPoint.prayer(this.anchor) : derived = null;
  const ReminderPoint.derivedPoint(DerivedTimeKind kind) : anchor = kind.anchor, derived = kind;  // anchor için switch
  bool get isDerived => derived != null;
  static List<ReminderPoint> get all => [...PrayerType.values.map(ReminderPoint.prayer), ...DerivedTimeKind.values.map(ReminderPoint.derivedPoint)];
  static ReminderPoint of(PrayerType type, DerivedTimeKind? kind);
  ==, hashCode değer bazlı
}
class NotificationDraft { prayerType, derivedKind, minutesBefore, weekdays, label; const; }
class OptionItem<T> { ..., final String? group; }
```

- [ ] **Adım 1: Kırmızı** — `ReminderPoint.derivedPoint(istiwa).anchor == dhuhr`; `all.length == 11`; eşitlik; option picker: iki farklı `group` verilince sheet'te iki `SectionLabel` çizilir, `group == null` iken hiç çizilmez.
- [ ] **Adım 2: Kırmızıyı gör.** **Adım 3: Uygulama.** **Adım 4: Yeşil.** **Adım 5: Commit** `feat(reminders): bildirim noktası modeli ve gruplu seçici`

---

### Görev 7: `NotificationEditScreen` tam sayfa

**Dosyalar:**
- Oluştur: `lib/presentation/screens/notification_edit_screen.dart`, `test/widgets/notifications/notification_edit_screen_test.dart`
- Değiştir: `lib/presentation/screens/reminders_screen.dart:790-830` (`_showNotificationSheet` → `_openNotificationEditor`), `lib/l10n/app_*.arb`
- Sil: `lib/presentation/widgets/notifications/add_notification_bottom_sheet.dart`, `test/widgets/notifications/add_notification_sheet_test.dart`

**Arayüzler:**
- `NotificationEditScreen({NotificationSetting? initial, required List<PrayerTime> prayerTimes, DateTime Function()? clock})` → `Navigator.pop<NotificationDraft>`.
- `RemindersScreen._openNotificationEditor({NotificationSetting? initial})`.
- ARB: `remindersNew` "Yeni bildirim", `remindersEdit` "Bildirimi düzenle", `remindersWhen` "Ne zaman?", `remindersPrayerGroup` "Namaz vakitleri", `remindersDerivedGroup` "Hesaplanan vakitler", `remindersDerivedExplain`, `remindersFormulaIshraq` "Güneş vaktinden 45 dk sonra", `remindersFormulaIstiwa` "Öğle vaktinden 10 dk önce", `remindersFormulaPreMaghrib` "Akşam vaktinden 45 dk önce", `remindersFormulaMidnight` "Akşam ile ertesi imsak arasının ortası", `remindersFormulaLastThird` "Gecenin son üçte birinin başı", `remindersTodayAt` "Bugün {time}", `remindersNextPreview` "Sıradaki: {day} {time}". Kaldır: `remindersAddTitle`, `remindersAddButton`, `remindersUpdateTitle`, `remindersWhichPrayer`, `remindersPrayerSection`, `remindersDerivedSection`, `remindersDerivedHint` (başka kullanımı yoksa; `grep` ile doğrula).

- [ ] **Adım 1: Kırmızı testler** — eski sheet testleri sayfaya taşınır: `pumpPage` bir `Navigator` altında açar, "Kaydet"e basınca `NotificationDraft` yakalanır. Yeni: "Ne zaman?" satırına basınca sheet'te "NAMAZ VAKİTLERİ" ve "HESAPLANAN VAKİTLER" başlıkları; "Kerahat (zeval)" seçilince açıklama kartında formül + "Bugün 12:45"; önizleme satırı "Sıradaki: bugün …"; dakika sınırı aşımı mesajı; günler/etiket kaydı; her gün → boş küme; hesaplanan nokta kaydında `prayerType` çıpa.
- [ ] **Adım 2: Kırmızıyı gör.** **Adım 3: Uygulama** — sayfa `AlarmEditScreen` kalıbı; bölüm yardımcıları (`_whenRow`, `_explanationCard`, `_offsetSection`, `_previewLine`, `_weekdaySelector`, `_labelField`); `_nextPreview()` 8 gün döngüsü `NotificationTimeRules.pointTime`. `reminders_screen`: `Navigator.push<NotificationDraft>(MaterialPageRoute(...))`; sonuç null değilse add/update. Sheet ve testi silinir.
- [ ] **Adım 4: `flutter gen-l10n`, `flutter analyze`, yeşil.** **Adım 5: Commit** `feat(reminders): bildirim ekleme tam sayfa ve anlaşılır zaman seçimi`

---

### Görev 8: `KerahatStatus` + ana ekran uyarı satırı

**Dosyalar:**
- Oluştur: `lib/features/prayer_times/domain/kerahat_status.dart`, `test/prayer_times/kerahat_status_test.dart`
- Değiştir: `lib/presentation/widgets/home/countdown_hero.dart`, `lib/l10n/app_*.arb`
- Test: `test/widgets/home/countdown_hero_test.dart` (mevcut dosyaya ekle)

**Arayüzler:**
```dart
sealed class KerahatStatus { final KerahatInterval interval; }
class KerahatApproaching extends KerahatStatus {}
class KerahatActive extends KerahatStatus {}
abstract final class KerahatWarning { static const Duration lead = Duration(minutes: 30);
  static KerahatStatus? resolve(List<KerahatInterval> intervals, DateTime now); }
```
ARB: `kerahatSoonLine` "Kerahat {time} · {remaining}".

- [ ] **Adım 1: Kırmızı** — resolve: içinde → Active; start−20dk → Approaching; start−31dk → null; end sonrası → null. Hero: start−20dk'da `Key('kerahat_soon_line')` var ve metin "Kerahat 18:47 · 20 dk"; start−31dk'da yok; aktifken yok (kart var).
- [ ] **Adım 2: Kırmızıyı gör.** **Adım 3: Uygulama** — `_countdown` altına `?_soonLine(tokens, now)`.
- [ ] **Adım 4: Yeşil.** **Adım 5: Commit** `feat(home): kerahat yaklaşırken sayaç altında uyarı`

---

### Görev 9: Widget snapshot v4 (Dart)

**Dosyalar:**
- Değiştir: `lib/features/home_widget/domain/widget_snapshot.dart` (`WidgetKerahatInterval`, `WidgetSnapshotDay.kerahat`, `WidgetLabels.kerahat/kerahatActive/kerahatUntil`, `schemaVersion = 4`), `widget_snapshot_builder.dart` (`KerahatTimes.forDay`), `widget_labels_factory.dart`, `lib/l10n/app_*.arb` (`widgetKerahat` "Kerahat", `widgetKerahatActive` "Kerahat vakti", `widgetKerahatUntil` "bitiş {time}")
- Test: `test/home_widget/widget_snapshot_builder_test.dart`, `test/home_widget/widget_snapshot_test.dart`

- [ ] **Adım 1: Kırmızı** — builder: günün `kerahat` listesi 3 aralık, `toJson()['days'][0]['kerahat'] == [{'start':'05:52','end':'06:37'}, {'start':'13:05','end':'13:15'}, {'start':'19:41','end':'20:26'}]`; `schemaVersion == 4`; labels JSON'da üç yeni anahtar.
- [ ] **Adım 2: Kırmızıyı gör.** **Adım 3: Uygulama.** **Adım 4: Yeşil.** **Adım 5: Commit** `feat(widget): snapshot v4 kerahat aralıkları ve etiketleri`

---

### Görev 10: Widget Swift — decode, timeline, palet, görünüm

**Dosyalar:**
- Değiştir: `ios/WidgetCore/WidgetSnapshot.swift` (`SnapshotInterval`, `SnapshotDay.kerahat: [SnapshotInterval]?`, labels, `supportedSchemaVersions` 4), `ios/WidgetCore/PrayerTimeline.swift` (`KerahatStatus`, `PrayerEntry.kerahat`, kerahat anları, `maxEntries = 24`), `ios/EzanVaktiWidget/Theme/Palette.swift` (`kerahat`), `ios/EzanVaktiWidget/Views/SmallView.swift`, `MediumView.swift`
- Oluştur: `ios/EzanVaktiWidget/Views/KerahatLine.swift`
- Test: `ios/RunnerTests/WidgetSnapshotTests.swift`, `ios/RunnerTests/PrayerTimelineTests.swift`

**Arayüzler:**
```swift
struct SnapshotInterval: Decodable, Equatable { let start: String; let end: String }
enum KerahatStatus: Equatable { case approaching(start: Date, end: Date), active(end: Date)
  static let lead: TimeInterval = 30 * 60
  static func resolve(days: [SnapshotDay], now: Date, calendar: Calendar) -> KerahatStatus? }
struct PrayerEntry { ... var kerahat: KerahatStatus? = nil }
struct KerahatLine: View { let entry: PrayerEntry; let status: KerahatStatus; let color: Color; let showsStartTime: Bool }
```

- [ ] **Adım 1: Kırmızı** — Snapshot: v4 JSON `kerahat` decode; v3 → `nil`. Timeline: `days` fixture'ına kerahat `[("05:52","06:37"),("13:05","13:15"),("19:41","20:26")]`; `now = 25 Ağustos 14:00` → kareler 16:58 (İkindi), 19:11 (start−30), 19:41 (start), 20:26 (Akşam=end) … ; `entries(now: 19:20).first.kerahat == .approaching(start: 19:41, end: 20:26)`; `now: 19:50` → `.active(end: 20:26)`; `now: 14:00` → nil.
- [ ] **Adım 2: Kırmızıyı gör.** **Adım 3: Uygulama** — timeline `moments`: `boundaries + kerahatMoments` sıralı, tekrarsız, `prefix(maxEntries)`; her kare `kerahat: KerahatStatus.resolve(days:, now: moment, calendar:)`. Görünüm: `CountdownLabel` altına `if let status = entry.kerahat { KerahatLine(...) }`.
- [ ] **Adım 4: RunnerTests yeşil + `flutter build ios --simulator --debug`.** **Adım 5: Commit** `feat(widget): kerahat yaklaşıyor ve kerahat vakti satırı`

---

### Görev 11: Bütünlük ve teslim

- [ ] `dart format` (dokunulan dosyalar), `flutter gen-l10n`, `flutter analyze`.
- [ ] `flutter test > /tmp/…/test.log; echo $?` — tam suite.
- [ ] `xcodebuild test … -only-testing:RunnerTests` tam; `flutter build ios --simulator --debug`.
- [ ] CHANGELOG `## [Unreleased]` girişleri (Eklendi / Değişti / Düzeltildi); spec ve plan commit'i; `git status` temiz.
- [ ] Cihaz kabul listesi Ekrem'e (alarm düzenle → çalma, matematik tuş takımı, bildirim sayfası, widget kerahat satırı).

## Fiziksel cihaz kabulü

- [ ] Ekrem: yeni build ile yukarıdaki dört senaryo. Birim/simülatör sonuçları bunu tamamlanmış saymaz.
