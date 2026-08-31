# Tur 3 — Türetilmiş Vakitler ve Takvim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kerahat/işrak/gece yarısı/teheccüd hatırlatmaları, dini gün bildirimleri ve aylık vakit paylaşımı — hepsi mevcut vakit verisinden yerelde.

**Architecture:** Türetilmiş vakitler saf bir hesaplayıcıda (`DerivedTimes`) üretilir; `NotificationSetting` bir `derivedKind` alanıyla genişler ve planlayıcı aday üretirken çıpa vaktin yerine türetilmiş anı kullanır. Bildirim ID şeması nokta indeksini taşıyacak şekilde genişler.

**Tech Stack:** Flutter/Dart, sqflite, hijri, share_plus (yeni), flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-31-tur3-turetilmis-vakitler-design.md`

## Global Constraints

- Kod/dosya/değişken adları İngilizce; kullanıcıya görünen metin Türkçe.
- Doğrulama: `flutter analyze` + `flutter test`; her task sonunda tam paket yeşil.
- Commit'ler `feat/tur3-turetilmis-vakitler` branch'ine, Türkçe mesajla, `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- `PrayerType` enum'u, widget snapshot şeması ve alarm çıpası **değişmez**.

---

### Task 1: Türetilmiş vakit hesabı

**Files:**
- Create: `lib/core/models/derived_time.dart`, `lib/features/prayer_times/domain/derived_times.dart`
- Test: `test/prayer_times/derived_times_test.dart`

**Interfaces:**
- Produces: `enum DerivedTimeKind { ishraq, istiwa, preMaghrib, midnight, lastThird }` + `label`, `description`, `anchor` (PrayerType), `storageValue`.
- Produces: `class DerivedTimeSettings { int ishraqMinutes = 45; int istiwaMinutes = 10; int preMaghribMinutes = 45; }`.
- Produces: `DerivedTimes.resolve({required DerivedTimeKind kind, required PrayerTime day, PrayerTime? nextDay, DerivedTimeSettings settings}) → DateTime?` — gece vakitleri için `nextDay` yoksa `null`.

- [ ] **Step 1: Failing test**

```dart
test('ishraq gunesten 45 dk sonra', () {
  expect(
    DerivedTimes.resolve(kind: DerivedTimeKind.ishraq, day: day),
    day.sunrise.add(const Duration(minutes: 45)),
  );
});

test('istiwa ogleden 10 dk once', () {
  expect(
    DerivedTimes.resolve(kind: DerivedTimeKind.istiwa, day: day),
    day.dhuhr.subtract(const Duration(minutes: 10)),
  );
});

test('gece yarisi aksam ile ertesi imsagin ortasi', () {
  final result = DerivedTimes.resolve(
    kind: DerivedTimeKind.midnight, day: day, nextDay: tomorrow);
  final night = tomorrow.fajr.difference(day.maghrib);
  expect(result, day.maghrib.add(night ~/ 2));
});

test('son ucte bir ertesi imsaktan gecenin ucte biri once', () {
  final result = DerivedTimes.resolve(
    kind: DerivedTimeKind.lastThird, day: day, nextDay: tomorrow);
  final night = tomorrow.fajr.difference(day.maghrib);
  expect(result, tomorrow.fajr.subtract(night ~/ 3));
});

test('ertesi gun yoksa gece vakitleri hesaplanmaz', () {
  expect(DerivedTimes.resolve(kind: DerivedTimeKind.midnight, day: day), isNull);
  expect(DerivedTimes.resolve(kind: DerivedTimeKind.lastThird, day: day), isNull);
});

test('ayarlanabilir sabitler uygulanir', () {
  expect(
    DerivedTimes.resolve(
      kind: DerivedTimeKind.ishraq,
      day: day,
      settings: const DerivedTimeSettings(ishraqMinutes: 30)),
    day.sunrise.add(const Duration(minutes: 30)),
  );
});
```

- [ ] **Step 2: FAIL gör** — `flutter test test/prayer_times/derived_times_test.dart`
- [ ] **Step 3: Implementasyon** (saf sınıflar, ağ/DB yok)
- [ ] **Step 4: PASS + `flutter analyze`**
- [ ] **Step 5: Commit** — `feat: turetilmis vakit hesabi (kerahat, israk, gece yarisi, son ucte bir)`

---

### Task 2: ID şeması genişlemesi

**Files:**
- Modify: `lib/features/notifications/domain/notification_scheduler.dart` (`notificationIdFor`), `lib/features/notifications/data/flutter_local_notification_service.dart` (pending çözümleme)
- Test: `test/notifications/notification_id_test.dart`

**Interfaces:**
- Produces: `NotificationScheduler.notificationIdFor({required DateTime date, required int pointIndex, required int minutesBefore})` — formül: `(dayOrdinal % 10000) * 200000 + pointIndex * 10000 + minutesBefore`.
- Produces: `NotificationScheduler.pointIndexOf(NotificationSetting)` — vakit için `prayerType.index` (0–5), türetilmiş için `6 + derivedKind.index` (6–10), dini gün için 11 (`kReligiousDayPointIndex`).

- [ ] **Step 1: Failing test**

```dart
test('id 32-bit sinirinda kalir ve benzersizdir', () {
  final a = NotificationScheduler.notificationIdFor(
    date: DateTime(2026, 9, 4), pointIndex: 10, minutesBefore: 45);
  final b = NotificationScheduler.notificationIdFor(
    date: DateTime(2026, 9, 4), pointIndex: 5, minutesBefore: 45);
  expect(a, isNot(b));
  expect(int.parse(a), lessThan(2147483647));
});

test('ayni gun-nokta-offset ayni id uretir', () {
  final a = NotificationScheduler.notificationIdFor(
    date: DateTime(2026, 9, 4), pointIndex: 3, minutesBefore: 0);
  final b = NotificationScheduler.notificationIdFor(
    date: DateTime(2026, 9, 4, 23, 59), pointIndex: 3, minutesBefore: 0);
  expect(a, b);
});

test('ardisik gunler farkli id uretir', () {
  final a = NotificationScheduler.notificationIdFor(
    date: DateTime(2026, 9, 4), pointIndex: 0, minutesBefore: 0);
  final b = NotificationScheduler.notificationIdFor(
    date: DateTime(2026, 9, 5), pointIndex: 0, minutesBefore: 0);
  expect(a, isNot(b));
});
```

- [ ] **Step 2: FAIL gör → implementasyon**; pending çözümlemede ters formül (`raw % 10000` → minutesBefore, `(raw ~/ 10000) % 20` → pointIndex).
- [ ] **Step 3: Tam test + analyze**
- [ ] **Step 4: Commit** — `feat: bildirim id semasi turetilmis vakitleri de tasiyor`

---

### Task 3: DB v11 + model genişlemesi

**Files:**
- Modify: `lib/core/models/notification_setting.dart`, `lib/features/prayer_times/data/sqlite_storage.dart`, `lib/features/notifications/domain/notification_settings_manager.dart`, `lib/presentation/services/upcoming_resolver.dart`
- Test: `test/notifications/notification_setting_test.dart` (mevcut dosyaya vaka)

**Interfaces:**
- Produces: `NotificationSetting.derivedKind: DerivedTimeKind?`; `isDerived` getter; `notificationKey` `derivedKind`i kapsar (`'dhuhr-istiwa-45-'` biçimi).
- DB v11: `ALTER TABLE notification_settings ADD COLUMN derived_kind TEXT`; UNIQUE `(prayer_type, derived_kind, minutes_before, weekdays)` — tablo yeniden oluşturma (v10 kalıbı).
- Manager eşleşmeleri dörtlü kimliğe geçer; `removeSetting`/`toggleSetting` `derivedKind` parametresi alır.

- [ ] **Step 1: Failing test** — aynı vakit ve sapmada `derivedKind` farklıysa kimlikler ayrışır; JSON round-trip.
- [ ] **Step 2: FAIL gör → implementasyon**
- [ ] **Step 3: Tam test + analyze**
- [ ] **Step 4: Commit** — `feat: DB v11 - bildirim ayarina turetilmis vakit alani`

---

### Task 4: Planlayıcı türetilmiş vakitleri planlar

**Files:**
- Modify: `lib/features/notifications/domain/notification_scheduler.dart`
- Test: `test/notifications/derived_notification_test.dart`

**Interfaces:**
- Consumes: Task 1–3.
- Produces: Planlayıcı `setting.isDerived` ise `DerivedTimes.resolve` ile anı bulur (ertesi günün `PrayerTime`ını listeden alır); bulunamazsa o günü sessizce atlar. Başlık türetilmiş noktanın adı olur (etiket varsa etiket).

- [ ] **Step 1: Failing test**

```dart
test('istiwa bildirimi ogleden 10 dk once planlanir', () async {
  storage.settings = [
    const NotificationSetting(
      prayerType: PrayerType.dhuhr,
      derivedKind: DerivedTimeKind.istiwa,
      isActive: true),
  ];
  await schedule();
  final call = service.calls.first;
  expect(call.scheduledTime.hour, 12);
  expect(call.scheduledTime.minute, 50);
  expect(call.title, contains('Kerahat'));
});

test('ertesi gun verisi olmayan son gun icin gece vakti planlanmaz', () async {
  storage.settings = [
    const NotificationSetting(
      prayerType: PrayerType.maghrib,
      derivedKind: DerivedTimeKind.lastThird,
      isActive: true),
  ];
  await schedule();
  // Son gunun gecesi hesaplanamaz: gun sayisindan bir eksik planlanir.
  expect(service.calls.length, lessThan(daysProvided));
});
```

- [ ] **Step 2: FAIL gör → implementasyon**
- [ ] **Step 3: Tam test + analyze**
- [ ] **Step 4: Commit** — `feat: turetilmis vakitler icin bildirim planlamasi`

---

### Task 5: Türetilmiş vakit arayüzü

**Files:**
- Modify: `lib/presentation/widgets/notifications/add_notification_bottom_sheet.dart`, `lib/presentation/widgets/notifications/notification_tile.dart`, `lib/presentation/screens/reminders_screen.dart`
- Test: `test/widgets/notifications/add_notification_sheet_test.dart` (mevcut dosyaya vaka)

**Interfaces:**
- Produces: Bottom sheet'te iki grup — "Namaz vakitleri" (6 çip) ve "Türetilmiş" (5 çip); seçim `(PrayerType, DerivedTimeKind?)` çifti üretir. `onAdd` imzası `derivedKind` alır.
- Produces: Satır başlığı türetilmiş noktanın adı; alt metinde açıklaması.

- [ ] **Step 1: Failing test** — türetilmiş çip seçilip kaydedilince `onAdd`a doğru `derivedKind` gider.
- [ ] **Step 2: FAIL gör → implementasyon**
- [ ] **Step 3: Tam test + analyze**
- [ ] **Step 4: Commit** — `feat: hatirlatici eklerken turetilmis vakit secimi`

---

### Task 6: Dini günler

**Files:**
- Create: `lib/core/models/religious_day.dart`, `lib/core/data/religious_days.dart`, `lib/features/prayer_times/domain/religious_day_resolver.dart`
- Modify: `lib/features/notifications/domain/notification_scheduler.dart`, `lib/core/models/general_settings.dart` (anahtarlar), `lib/presentation/widgets/settings/notification_prefs_section.dart`
- Test: `test/prayer_times/religious_days_test.dart`

**Interfaces:**
- Produces: `class ReligiousDay { DateTime date; String name; ReligiousDayKind kind; bool isEstimated; }`, `enum ReligiousDayKind { kandil, bayram, ramadanStart, other }`.
- Produces: `ReligiousDays.forRange(DateTime start, DateTime end) → List<ReligiousDay>` — 2026–2028 gömülü tablodan; kapsam dışında `hijri` ile hesap + `isEstimated: true`.
- Produces: `GeneralSettings.religiousDayNotifications: bool` (varsayılan `false`) ve `religiousDayEve: bool` (bir gün önce, varsayılan `true`).
- Planlayıcı: açıksa o günün sabahı (imsak + 60 dk) ve isteğe bağlı bir önceki gün öğle vaktinde bildirim; `pointIndex = 11`.

- [ ] **Step 1: Failing test** — bilinen tarih (2027 Ramazan başlangıcı) tabloda; aralık filtresi; kapsam dışı yılda `isEstimated` işareti.
- [ ] **Step 2: FAIL gör → implementasyon**
- [ ] **Step 3: Tam test + analyze**
- [ ] **Step 4: Commit** — `feat: dini gunler ve kandil bildirimleri`

---

### Task 7: Aylık vakit paylaşımı + kapanış

**Files:**
- Modify: `pubspec.yaml` (`share_plus`), `lib/presentation/screens/` takvim ekranı, `CHANGELOG.md`
- Test: paylaşım saf yardımcısı için birim test (görsel üretimi test edilmez)

- [ ] **Step 1: `share_plus` ekle** — `flutter pub add share_plus`
- [ ] **Step 2: Takvim ekranına "Paylaş"** — `RepaintBoundary` + `toImage` → geçici dosya → `SharePlus.instance.share`
- [ ] **Step 3: Sürüm `0.8.0+34`, CHANGELOG 0.8.0** (türetilmiş vakitler, dini günler, paylaşım; not: atlama kayıtları sıfırlandı)
- [ ] **Step 4: Tam doğrulama** — `flutter analyze && flutter test && flutter build ios --no-codesign`
- [ ] **Step 5: Commit** — `docs: 0.8.0 surum notlari`
- [ ] **Step 6: Ekrem'e cihaz test listesi + TestFlight sorusu**
