# Tur 4 — Araçlar ve Sistem Yüzeyleri Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kıble pusulası, namaz takibi + kaza sayacı, zikirmatik ve iOS sistem yüzeyleri (Siri kısayolu, kilit ekranı halkası, widget saat formatı).

**Architecture:** Üç araç yeni bir "Araçlar" sekmesinde toplanır. Kıble açısı saf Dart; cihaz yönü küçük bir `EventChannel` ile native'den akar. Takip ve zikir SQLite'ta (DB v12). Sistem yüzeyleri widget extension'da yaşar.

**Tech Stack:** Flutter/Dart, sqflite, Swift (CoreLocation heading, AppIntents, WidgetKit), flutter_test, XCTest.

**Spec:** `docs/superpowers/specs/2026-08-31-tur4-araclar-design.md`

## Global Constraints

- Kod/dosya/değişken adları İngilizce; kullanıcıya görünen metin Türkçe.
- Yeni Dart bağımlılığı **yok** (heading için EventChannel yazılır).
- Doğrulama: `flutter analyze` + `flutter test`; her task sonunda tam paket yeşil.
- Commit'ler `feat/tur4-araclar` branch'ine, Türkçe mesajla, `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Kıble açısı hesabı

**Files:**
- Create: `lib/features/qibla/domain/qibla_direction.dart`
- Test: `test/qibla/qibla_direction_test.dart`

**Interfaces:**
- Produces: `QiblaDirection.bearing({required double latitude, required double longitude}) → double` — kuzeyden saat yönünde 0–360°.
- Produces: `QiblaDirection.kaabaLatitude = 21.4225`, `kaabaLongitude = 39.8262`.
- Produces: `QiblaDirection.difference(heading, qibla) → double` — −180…180 arası en kısa fark.

- [ ] **Step 1: Failing test**

```dart
test('Istanbul dan kible guneydogu (~151 derece)', () {
  final bearing = QiblaDirection.bearing(latitude: 41.0082, longitude: 28.9784);
  expect(bearing, closeTo(151, 2));
});

test('Kabe nin kuzeyinden bakinca kible guneyi gosterir', () {
  final bearing = QiblaDirection.bearing(
    latitude: QiblaDirection.kaabaLatitude + 10,
    longitude: QiblaDirection.kaabaLongitude);
  expect(bearing, closeTo(180, 0.5));
});

test('fark -180 ile 180 arasinda ve en kisa yol', () {
  expect(QiblaDirection.difference(350, 10), closeTo(20, 0.001));
  expect(QiblaDirection.difference(10, 350), closeTo(-20, 0.001));
});
```

- [ ] **Step 2: FAIL gör** — `flutter test test/qibla/qibla_direction_test.dart`
- [ ] **Step 3: Implementasyon** — büyük daire formülü:
  `θ = atan2(sin Δλ · cos φ₂, cos φ₁ · sin φ₂ − sin φ₁ · cos φ₂ · cos Δλ)`, dereceye çevir, `(θ + 360) % 360`.
- [ ] **Step 4: PASS + analyze**
- [ ] **Step 5: Commit** — `feat: kible acisi hesabi (buyuk daire formulu)`

---

### Task 2: Cihaz yönü köprüsü

**Files:**
- Create: `lib/features/qibla/data/heading_service.dart`, `ios/Runner/HeadingStreamHandler.swift`
- Modify: `ios/Runner/AppDelegate.swift` (kanal kaydı), `ios/Runner.xcodeproj/project.pbxproj`
- Test: `test/qibla/heading_service_test.dart`

**Interfaces:**
- Produces: `class HeadingReading { double degrees; double accuracy; }` — `accuracy < 0` kalibrasyon gerekli demek.
- Produces: `HeadingService.headings → Stream<HeadingReading>`; desteklenmeyen platformda boş akış.
- Native: `EventChannel('com.ekrembulbul.ezanvakti/heading')`, olay `{'degrees': double, 'accuracy': double}`.

- [ ] **Step 1: Failing test** — sahte `EventChannel` akışından gelen map'in `HeadingReading`e çevrildiğini, bozuk olayın atlandığını doğrula.
- [ ] **Step 2: FAIL gör → Dart implementasyonu → PASS**
- [ ] **Step 3: Swift** — `HeadingStreamHandler`: `CLLocationManager` sahibi, `startUpdatingHeading`, `didUpdateHeading` → `trueHeading` (geçersizse `magneticHeading`), `headingAccuracy`. `Info.plist`'te konum açıklaması zaten var (geolocator).
- [ ] **Step 4: pbxproj'e dosya ekle + `flutter build ios --no-codesign`**
- [ ] **Step 5: Commit** — `feat: cihaz yonu icin heading kanali (CoreLocation)`

---

### Task 3: Araçlar sekmesi ve kıble ekranı

**Files:**
- Create: `lib/presentation/screens/tools_screen.dart`, `lib/presentation/screens/qibla_screen.dart`
- Modify: `lib/presentation/pages/home_page.dart` (4. sekme)
- Test: `test/widgets/screens/tools_screen_test.dart`

**Interfaces:**
- Produces: `ToolsScreen` — kıble, takip, zikirmatik satırları (sonraki task'larda dolar).
- Produces: `QiblaScreen` — açı, ok, kalibrasyon uyarısı, hizalanınca haptik.

- [ ] **Step 1: Failing test** — Araçlar sekmesinde üç aracın satırı çizilir; konum yokken kıble ekranı açıklayıcı boş durum gösterir.
- [ ] **Step 2: FAIL gör → implementasyon → PASS**
- [ ] **Step 3: analyze**
- [ ] **Step 4: Commit** — `feat: Araclar sekmesi ve kible pusulasi ekrani`

---

### Task 4: Namaz takibi ve kaza sayacı (DB v12)

**Files:**
- Create: `lib/core/models/prayer_log.dart`, `lib/features/tracking/domain/prayer_tracker.dart`, `lib/presentation/screens/prayer_tracking_screen.dart`
- Modify: `lib/core/interfaces/local_storage.dart`, `lib/features/prayer_times/data/sqlite_storage.dart`
- Test: `test/tracking/prayer_tracker_test.dart`

**Interfaces:**
- Produces: `enum PrayerStatus { done, qada, missed }` + `storageValue`/`fromStorage`.
- Produces: `PrayerStatus? nextStatus(PrayerStatus? current)` — döngü `null → done → qada → null`.
- Produces: `LocalStorage.getPrayerLog(DateTime from, DateTime to) → Future<Map<String, PrayerStatus>>` (anahtar `'yyyy-MM-dd|prayerType'`), `setPrayerLog(date, prayerType, status?)`, `getQadaCounts()`, `setQadaCount(prayerType, count)`.
- DB v12: iki yeni tablo (spec'teki şema).

- [ ] **Step 1: Failing test** — durum döngüsü; anahtar biçimi; kaza sayacı negatife düşmez.
- [ ] **Step 2: FAIL gör → implementasyon → PASS**
- [ ] **Step 3: UI** — 5×7 ızgara + kaza sayaçları; sahte depoyla widget testi.
- [ ] **Step 4: Tam test + analyze**
- [ ] **Step 5: Commit** — `feat: namaz takibi ve kaza sayaci (DB v12)`

---

### Task 5: Zikirmatik

**Files:**
- Create: `lib/features/tracking/domain/dhikr_counter.dart`, `lib/presentation/screens/dhikr_screen.dart`
- Modify: `lib/core/interfaces/local_storage.dart`, `lib/features/prayer_times/data/sqlite_storage.dart`
- Test: `test/tracking/dhikr_counter_test.dart`

**Interfaces:**
- Produces: `DhikrState { int count; int target; }` + `laps` (tamamlanan tur), `remaining`.
- Produces: `LocalStorage.getDhikrCount(DateTime date)`, `setDhikrCount(DateTime date, int count)` (`dhikr_log`).
- Hedefler: `const [33, 99, 100, 500, 1000]` + özel.

- [ ] **Step 1: Failing test** — tur ve kalan hesabı; hedef aşılınca tur artar; sıfırlama.
- [ ] **Step 2: FAIL gör → implementasyon → PASS**
- [ ] **Step 3: UI** — tam ekran dokunma, haptik, hedef seçimi, sıfırlama onayı.
- [ ] **Step 4: Tam test + analyze**
- [ ] **Step 5: Commit** — `feat: zikirmatik`

---

### Task 6: Sistem yüzeyleri (Siri, halka widget, saat formatı)

**Files:**
- Create: `ios/EzanVaktiWidget/NextPrayerIntent.swift`, `ios/EzanVaktiWidget/Views/CircularView.swift`
- Modify: `ios/EzanVaktiWidget/EzanVaktiWidget.swift`, `ios/WidgetCore/*` (saat biçimi), `lib/features/home_widget/data/home_widget_publisher.dart`
- Test: `ios/RunnerTests/` saf biçimlendirme testi

**Interfaces:**
- Produces: App Group anahtarı `ezanvakti_time_format` (`system|h24|h12`) — snapshot şeması değişmez.
- Produces: `WidgetCore` içinde `TimeFormatting.clock(_ date: Date, preference: String, locale: Locale) → String`.
- Produces: `accessoryCircular` ailesi + `NextPrayerIntent` (`AppIntent`, `AppShortcutsProvider`).

- [ ] **Step 1: Swift saf biçimlendirme testi (RunnerTests)** — h24/h12/system.
- [ ] **Step 2: Implementasyon** — Dart yayıncı formatı App Group'a yazar; widget okur.
- [ ] **Step 3: `flutter build ios --no-codesign`**
- [ ] **Step 4: Commit** — `feat: Siri kisayolu, kilit ekrani halkasi ve widget saat bicimi`

---

### Task 7: Kapanış

- [ ] **Step 1: Sürüm `0.9.0+35`, CHANGELOG 0.9.0**
- [ ] **Step 2: Tam doğrulama** — `flutter analyze && flutter test && flutter build ios --no-codesign`
- [ ] **Step 3: Commit** — `docs: 0.9.0 surum notlari`
- [ ] **Step 4: Ekrem'e cihaz test listesi + TestFlight sorusu**
