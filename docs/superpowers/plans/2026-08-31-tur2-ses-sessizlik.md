# Tur 2 — Ses ve Sessizlik Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sessiz pencereler (Cuma dahil), bildirim başına ses, odak modunda göster, gün filtresi, vakit ince ayarı ve saat formatı; Ayarlar ekranının yeniden yapılandırılması.

**Architecture:** Yeni davranışların tamamı Dart tarafında ve saf yardımcılarda toplanır (`QuietWindowRules`, `PrayerTimeTuner`, `TimeFormatter`); planlayıcı bunları aday üretim noktasında uygular. Şema değişikliği tek migration'da (DB v10). Native tarafta yalnızca ses dosyası ve entitlement var.

**Tech Stack:** Flutter/Dart, sqflite, flutter_local_notifications 17, flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-31-tur2-ses-sessizlik-design.md`

## Global Constraints

- Kod/dosya/değişken adları İngilizce; kullanıcıya görünen metin Türkçe (PRODUCT_SPEC.md).
- Yeni bağımlılık eklenmez.
- Doğrulama: `flutter analyze` + `flutter test` (simülatör sürülmez).
- Commit'ler `feat/tur2-ses-sessizlik` branch'ine, Türkçe mesajla, `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Her tamamlanan task'tan sonra tam test paketi yeşil olmalı.

---

### Task 1: Vakit ince ayarı (SES.5)

**Files:**
- Create: `lib/features/prayer_times/domain/prayer_time_tuner.dart`
- Modify: `lib/core/models/calculation_settings.dart`, `lib/features/prayer_times/domain/prayer_times_repository.dart`, `lib/presentation/screens/calculation_settings_screen.dart`
- Test: `test/prayer_times/prayer_time_tuner_test.dart`

**Interfaces:**
- Produces: `PrayerTimeTuner.apply(List<PrayerTime>, Map<PrayerType,int> tune) → List<PrayerTime>` ve `applyOne(PrayerTime, tune) → PrayerTime`.
- Produces: `CalculationSettings.tune: Map<PrayerType,int>` (varsayılan boş; JSON'da `{"fajr": -2}` biçiminde, sıfır değerler yazılmaz).

- [ ] **Step 1: Failing test**

```dart
test('tune dakikalari her vakte ayri uygulanir, tarih degismez', () {
  final tuned = PrayerTimeTuner.applyOne(base, const {PrayerType.fajr: -2, PrayerType.isha: 3});
  expect(tuned.fajr, base.fajr.subtract(const Duration(minutes: 2)));
  expect(tuned.isha, base.isha.add(const Duration(minutes: 3)));
  expect(tuned.dhuhr, base.dhuhr);
  expect(tuned.date, base.date);
});

test('bos tune ayni nesneyi dondurur', () {
  expect(PrayerTimeTuner.applyOne(base, const {}), same(base));
});
```

- [ ] **Step 2: Çalıştır, FAIL gör** — `flutter test test/prayer_times/prayer_time_tuner_test.dart`
- [ ] **Step 3: Implementasyon** — `PrayerTimeTuner` saf sınıf; `CalculationSettings`e `tune` alanı (toJson/fromJson/copyWith/== / hashCode); repository'nin `getPrayerTimes`/`getDailyPrayerTime` dönüşlerinde global ayarı okuyup uygula (tek kapı).
- [ ] **Step 4: PASS + `flutter analyze`**
- [ ] **Step 5: UI** — `calculation_settings_screen.dart`'a "Vakit düzeltmeleri" bölümü: 6 vakit, her biri −15…+15 stepper; değişimde kaydet ve `ReminderRescheduler` tetikle (ekranın mevcut kaydetme akışıyla aynı).
- [ ] **Step 6: Commit** — `feat: vakit ince ayari (vakit basina +-15 dk, yerelde uygulanir)`

---

### Task 2: Saat formatı ve otomatik konum anahtarı (SES.6)

**Files:**
- Create: `lib/core/utils/time_formatter.dart`, `lib/core/models/general_settings.dart`
- Modify: `lib/core/interfaces/local_storage.dart`, `lib/features/prayer_times/data/sqlite_storage.dart`, saat basan görünümler
- Test: `test/core/time_formatter_test.dart`

**Interfaces:**
- Produces: `enum TimeFormatPreference { system, h24, h12 }`; `TimeFormatter.format(DateTime, TimeFormatPreference, {required bool systemUses24h}) → String`.
- Produces: `GeneralSettings { timeFormat, autoLocation }`, `settings` anahtarları `general_time_format` / `general_auto_location`; `LocalStorage.getGeneralSettings()` / `saveGeneralSettings(...)`.

- [ ] **Step 1: Failing test**

```dart
test('h24 her zaman 24 saat, h12 ogleden sonra PM yazar', () {
  final t = DateTime(2026, 8, 31, 19, 5);
  expect(TimeFormatter.format(t, TimeFormatPreference.h24, systemUses24h: false), '19:05');
  expect(TimeFormatter.format(t, TimeFormatPreference.h12, systemUses24h: true), '7:05 PM');
});

test('system tercihi cihaz ayarina uyar', () {
  final t = DateTime(2026, 8, 31, 19, 5);
  expect(TimeFormatter.format(t, TimeFormatPreference.system, systemUses24h: true), '19:05');
  expect(TimeFormatter.format(t, TimeFormatPreference.system, systemUses24h: false), '7:05 PM');
});
```

- [ ] **Step 2: FAIL gör → implementasyon** (`intl` zaten bağımlı; `DateFormat.Hm()` / `DateFormat.jm()`), `GeneralSettings` + storage.
- [ ] **Step 3: PASS + analyze**
- [ ] **Step 4: Commit** — `feat: saat formati tercihi (sistem/24/12) ve genel ayar modeli`

---

### Task 3: DB v10 — bildirim ayarı genişlemesi

**Files:**
- Modify: `lib/core/models/notification_setting.dart`, `lib/features/prayer_times/data/sqlite_storage.dart`, `lib/features/notifications/domain/notification_settings_manager.dart`, `lib/presentation/services/upcoming_resolver.dart`
- Test: `test/notifications/notification_setting_test.dart` (yoksa oluştur)

**Interfaces:**
- Produces: `NotificationSetting { prayerType, isActive, minutesBefore, soundId: String?, weekdays: Set<int>, label: String? }` + `firesOnWeekday(int)`.
- Produces: `notificationKey(setting)` → `'${type.name}-${minutes}-${weekdaysCsv}'` (boş küme → boş segment).
- Produces: manager'ın `updateSetting`/`toggleSetting`/`removeSetting` eşleşmesi üçlü kimliğe geçer.
- DB v10: `ALTER TABLE notification_settings ADD COLUMN sound_id TEXT`, `... ADD COLUMN weekdays TEXT NOT NULL DEFAULT ''`, `... ADD COLUMN label TEXT`; UNIQUE'i değiştirmek için tablo yeniden oluşturma (v5 kalıbı) — mevcut satırlar korunur.

- [ ] **Step 1: Failing test**

```dart
test('notificationKey gunleri de kapsar', () {
  const daily = NotificationSetting(prayerType: PrayerType.dhuhr, isActive: true, minutesBefore: 45);
  const friday = NotificationSetting(
    prayerType: PrayerType.dhuhr, isActive: true, minutesBefore: 45, weekdays: {5});
  expect(notificationKey(daily), isNot(notificationKey(friday)));
});

test('firesOnWeekday: bos kume her gun demek', () {
  const daily = NotificationSetting(prayerType: PrayerType.dhuhr, isActive: true, minutesBefore: 0);
  const friday = NotificationSetting(
    prayerType: PrayerType.dhuhr, isActive: true, minutesBefore: 0, weekdays: {5});
  expect(daily.firesOnWeekday(3), isTrue);
  expect(friday.firesOnWeekday(3), isFalse);
  expect(friday.firesOnWeekday(5), isTrue);
});
```

- [ ] **Step 2: FAIL gör → implementasyon** (model, storage okuma/yazma, migration, manager eşleşmeleri, `notificationKey`).
- [ ] **Step 3: Tam test + analyze** — sahte `LocalStorage`lar etkilenirse imzaları güncelle.
- [ ] **Step 4: Commit** — `feat: DB v10 - bildirim ayarina ses, gun filtresi ve etiket alanlari`

---

### Task 4: Bildirim sesi (SES.2) ve odak modu (SES.3)

**Files:**
- Create: `ios/Runner/Sounds/beep.caf` (özgün üretim), `test/notifications/notification_sound_test.dart`
- Modify: `lib/core/interfaces/notification_service.dart`, `lib/features/notifications/data/flutter_local_notification_service.dart`, `lib/features/notifications/domain/notification_scheduler.dart`, `ios/Runner.xcodeproj` (kaynak dosya), `ios/Runner/Runner.entitlements`

**Interfaces:**
- Produces: `NotificationService.scheduleNotification(..., {String? soundId, bool silent = false, bool timeSensitive = true})`.
- Produces: `NotificationSoundOption` sabitleri: `'system'` (null), `'beep'`, `'silent'`.
- iOS: `DarwinNotificationDetails(presentSound: !silent, sound: soundFileFor(soundId), interruptionLevel: timeSensitive ? InterruptionLevel.timeSensitive : InterruptionLevel.active)`.

- [ ] **Step 1: Failing test** — planlayıcının ayardaki `soundId`'yi servise geçirdiğini ve `silent` bayrağını doğru verdiğini doğrulayan sahte servis testi.
- [ ] **Step 2: FAIL gör → implementasyon**; `beep.caf` üretimi (`python3` ile 0.4 sn 880 Hz sinüs WAV → `afconvert -f caff -d LEI16`), Xcode kaynak kaydı, entitlement.
- [ ] **Step 3: PASS + analyze + `flutter build ios --no-codesign`**
- [ ] **Step 4: Commit** — `feat: bildirim basina ses secimi ve odak modunda gosterme`

---

### Task 5: Sessiz pencereler (SES.1)

**Files:**
- Create: `lib/core/models/quiet_window.dart`, `lib/features/notifications/domain/quiet_window_rules.dart`, `lib/presentation/screens/quiet_windows_screen.dart`
- Modify: `lib/core/interfaces/local_storage.dart`, `lib/features/prayer_times/data/sqlite_storage.dart`, `lib/features/notifications/domain/notification_scheduler.dart`
- Test: `test/notifications/quiet_window_rules_test.dart`

**Interfaces:**
- Produces: `QuietWindow` modeli (spec'teki alanlar) + `QuietWindow.fridayDefault()` (öğle, 15 önce, 60 sonra, `silent`).
- Produces: `QuietWindowRules.modeFor({required List<QuietWindow> windows, required DateTime fireAt, required PrayerType prayerType, required DateTime prayerAt}) → QuietMode?` — pencereye düşmüyorsa `null`.
- Produces: `LocalStorage.getQuietWindows()` / `saveQuietWindows(List<QuietWindow>)` (`settings` anahtarı `quiet_windows`).

- [ ] **Step 1: Failing test**

```dart
test('cuma ogle penceresi yalnizca cuma gunu ve pencere icinde uygular', () {
  final windows = [QuietWindow.fridayDefault()];
  final fridayDhuhr = DateTime(2026, 9, 4, 13, 0); // Cuma
  expect(
    QuietWindowRules.modeFor(
      windows: windows, fireAt: fridayDhuhr, prayerType: PrayerType.dhuhr, prayerAt: fridayDhuhr),
    QuietMode.silent,
  );
  // Pencere disi: 20 dk once (pencere 15 dk once basliyor)
  expect(
    QuietWindowRules.modeFor(
      windows: windows,
      fireAt: fridayDhuhr.subtract(const Duration(minutes: 20)),
      prayerType: PrayerType.dhuhr,
      prayerAt: fridayDhuhr),
    isNull,
  );
  // Persembe ogle: cuma penceresi degil
  final thursdayDhuhr = DateTime(2026, 9, 3, 13, 0);
  expect(
    QuietWindowRules.modeFor(
      windows: windows, fireAt: thursdayDhuhr, prayerType: PrayerType.dhuhr, prayerAt: thursdayDhuhr),
    isNull,
  );
});
```

- [ ] **Step 2: FAIL gör → implementasyon**; planlayıcıda aday üretiminde `modeFor` çağrısı: `skip` → adayı atla, `silent` → adayı `silent: true` ile planla.
- [ ] **Step 3: UI** — Ayarlar > Sessiz pencereler: üstte Cuma kartı (anahtar + önce/sonra), altında özel pencere listesi (vakit + önce/sonra + mod), altında açıklama: "iPhone'da uygulama telefonu sessize alamaz; bu ayar yalnızca Ezan Vakti bildirimlerini susturur."
- [ ] **Step 4: Tam test + analyze**
- [ ] **Step 5: Commit** — `feat: sessiz pencereler - cuma sablonu ve vakit bazli ozel pencereler`

---

### Task 6: Gün filtresi UI + Cuma hatırlatıcısı (SES.4)

**Files:**
- Modify: `lib/presentation/widgets/notifications/add_notification_bottom_sheet.dart`, `lib/presentation/screens/reminders_screen.dart`, `lib/presentation/widgets/reminders/notifications_section.dart`, `lib/features/notifications/domain/notification_scheduler.dart`
- Test: `test/notifications/notifications_test.dart` (mevcut dosyaya vaka)

**Interfaces:**
- Consumes: Task 3'ün `weekdays`/`label` alanları.
- Produces: Bottom sheet gün çipleri (alarm ekranındaki kalıp) + etiket alanı; `onAdd(type, minutes, weekdays, label)`.
- Produces: Planlayıcıda gün eşleşmesi (`setting.firesOnWeekday(prayerDateTime.weekday)`) ve **spesifik satır önce** sıralaması.
- Produces: Bildirim listesinde "Cuma namazı" hızlı ekleme düğmesi (öğle · 45 dk önce · yalnızca Cuma · etiket).

- [ ] **Step 1: Failing test** — "yalnızca Cuma" satırı Perşembe planlanmaz, Cuma planlanır; aynı (vakit, offset) çakışmasında Cuma günü spesifik satırın başlığı kullanılır.
- [ ] **Step 2: FAIL gör → implementasyon**
- [ ] **Step 3: Tam test + analyze**
- [ ] **Step 4: Commit** — `feat: bildirimlere gun filtresi ve Cuma namazi hatirlaticisi`

---

### Task 7: Ayarlar ekranı ve kapanış

**Files:**
- Modify: `lib/presentation/screens/settings_screen.dart`, `lib/presentation/pages/home_page.dart` (yeni ekran yönlendirmeleri), `pubspec.yaml`, `CHANGELOG.md`
- Test: `test/widgets/screens/settings_screen_test.dart` (mevcut dosyaya vaka)

- [ ] **Step 1: Ayarlar yeniden yapılandırma** — bölümler: **Genel** (Konum, Hesaplama, Saat formatı, Otomatik konum) · **Bildirim ve ses** (Varsayılan ses, Odak modunda göster) · **Sessiz pencereler** (→ ekran) · **Görünüm** · **Bilgi**.
- [ ] **Step 2: Sürüm `0.7.0+33`, CHANGELOG 0.7.0 bölümü** (sessiz pencereler, ses seçimi, odak modu, gün filtresi, vakit düzeltmeleri, saat formatı; not: atlama kayıtları sıfırlandı).
- [ ] **Step 3: Tam doğrulama** — `flutter analyze && flutter test && flutter build ios --no-codesign`
- [ ] **Step 4: Commit** — `docs: 0.7.0 surum notlari; ayarlar ekrani yeniden yapilandirildi`
- [ ] **Step 5: Ekrem'e cihaz test listesi + TestFlight sorusu** (merge/tag onaysız yapılmaz)
