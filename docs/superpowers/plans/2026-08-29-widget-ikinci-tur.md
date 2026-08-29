# iOS Widget İkinci Tur Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 0.5.0'daki widget'ın cihaz kullanımında ortaya çıkan iki hatasını düzeltmek, geri sayımı Always-On ekranda okunur hale getirmek, tarih ve hizalama ayarı eklemek.

**Architecture:** Geri sayım hibrit çalışır — ekran açıkken sistemin canlı sayacı, Always-On'da (`isLuminanceReduced`) kendi çizdiğimiz metin. Kendi çizimimizin doğru olması için timeline dakika başına giriş üretir. Hizalama `AppIntentConfiguration` ile widget ayarı olur. Saf mantık (biçimlendirme, timeline, hizalama enum'u) `ios/WidgetCore/` altında kalır ve `RunnerTests`'te sınanır.

**Tech Stack:** Swift + SwiftUI + WidgetKit + AppIntents, Flutter/Dart, XCTest.

**Spec:** `docs/superpowers/specs/2026-08-29-widget-ikinci-tur-design.md`

## Global Constraints

- `schemaVersion` **2**'ye çıkar; widget **1'i de kabul eder** (D35). Bilinmeyen sürüm reddedilir.
- `hijri` alanı **isteğe bağlıdır**; yoksa tarih satırının hicri kısmı çizilmez.
- Hicri tarih **payload'dan** gelir (D30). Swift'te `islamicUmmAlQura` ile **hesaplanmaz**.
- Gün adı ve miladi tarih Swift'te, **`Locale(identifier: "tr_TR")`** zorlanarak biçimlendirilir (D31).
- Kendi çizdiğimiz geri sayım sistemle **aynı biçimde**: sıfır dolgusu yok, saniye yerine tire — `5:34:--` (D20).
- Timeline penceresi **120 dakika**, dakika başına bir giriş (D21/D22).
- Hizalama yalnızca `systemSmall` ve `systemMedium`'da geçerlidir (D24).
- `accessoryInline` **kaldırılır** (D25). Kalan aileler: `systemSmall`, `systemMedium`, `accessoryRectangular`.
- Tarih ve konum **üstte ve küçük**; vakit adı, saati ve geri sayım **altta ve baskın** (D27).
- Kullanıcıya görünen tüm metinler Türkçe sabit.
- Saf Swift tipleri `ios/WidgetCore/` altına konur ve `pbxadd.py` ile hem `widget` hem `tests` target'ına eklenir. `ios/EzanVaktiWidget/` klasörü file-system-synchronized'dır; oraya konan dosya yalnızca widget target'ına üye olur ve XCTest'te görünmez.
- Commit mesajları ASCII.

**Yardımcı betik:** pbxproj'a saf Swift dosyası eklemek için
`/private/tmp/claude-501/-Users-ekrem-projects-ezanvakti/67e9b7d1-044b-4ef9-86ee-6d0e53c0d3b1/scratchpad/pbxadd.py`
kullanılır:

```bash
python3 <betik> --group WidgetCore --path WidgetCore --targets widget,tests ios/WidgetCore/X.swift
python3 <betik> --group RunnerTests --path RunnerTests --targets tests ios/RunnerTests/XTests.swift
```

Betik yoksa yeniden yazılmalı: pbxproj'da `PBXFileReference`, hedef başına `PBXBuildFile` ve ilgili `Sources` fazına giriş ekler.

**Test komutları:**

```bash
flutter analyze && flutter test
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17'
flutter build ios --no-codesign
```

---

### Task 1: Payload'a hicri tarih ve `schemaVersion` 2

**Files:**
- Modify: `lib/features/home_widget/domain/widget_snapshot.dart`
- Modify: `lib/features/home_widget/domain/widget_snapshot_builder.dart`
- Test: `test/home_widget/widget_snapshot_test.dart`, `test/home_widget/widget_snapshot_builder_test.dart`

**Interfaces:**
- Consumes: `HijriFormatter.format(DateTime) → String` (`lib/core/utils/hijri_formatter.dart`)
- Produces: `WidgetSnapshotDay({required DateTime date, required WidgetDayTimes times, required String hijri})`, `WidgetSnapshot.schemaVersion == 2`

- [ ] **Step 1: Mevcut testleri yeni sözleşmeye göre güncelle ve düşmesini izle**

`test/home_widget/widget_snapshot_test.dart` içindeki `WidgetSnapshotDay(...)` çağrısına `hijri: '13 Rebiülevvel 1448'` ekle, `schemaVersion` testini 2'ye çevir ve şu testi ekle:

```dart
    test('hicri tarih gune yazilir', () {
      final day = (snapshot.toJson()['days'] as List).first;
      expect(day['hijri'], '13 Rebiülevvel 1448');
    });
```

- [ ] **Step 2: Testi çalıştır, düştüğünü gör**

Run: `flutter test test/home_widget/widget_snapshot_test.dart`
Expected: FAIL — `The named parameter 'hijri' isn't defined`

- [ ] **Step 3: Modeli güncelle**

`widget_snapshot.dart`'ta `WidgetSnapshotDay`:

```dart
class WidgetSnapshotDay {
  final DateTime date;
  final WidgetDayTimes times;

  /// Uygulamanın gösterdiği hicri tarih (`HijriFormatter.format` çıktısı).
  ///
  /// Swift tarafında hesaplanmıyor: iOS'un `islamicUmmAlQura` takvimi
  /// uygulamanın kullandığı `hijri` paketinden gün kayabiliyor ve widget'ın
  /// uygulamadan farklı tarih göstermesi kabul edilemez.
  final String hijri;

  const WidgetSnapshotDay({
    required this.date,
    required this.times,
    required this.hijri,
  });

  Map<String, dynamic> toJson() => {
    'date': _yyyyMMdd(date),
    'hijri': hijri,
    'times': times.toJson(),
  };
}
```

Aynı dosyada `schemaVersion` sabitini 2 yap:

```dart
  /// 2: günlere `hijri` alanı eklendi. Widget 1'i de kabul eder; o payload'da
  /// hicri satırı çizilmez.
  static const int schemaVersion = 2;
```

- [ ] **Step 4: Testi çalıştır, geçtiğini gör**

Run: `flutter test test/home_widget/widget_snapshot_test.dart`
Expected: PASS

- [ ] **Step 5: Builder testine hicri beklentisi ekle**

`test/home_widget/widget_snapshot_builder_test.dart`'a:

```dart
    test('hicri tarih HijriFormatter ciktisiyla ayni', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: _range(today, 1),
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.days.first.hijri, HijriFormatter.format(today));
    });
```

Dosyanın başına `import 'package:ezanvakti/core/utils/hijri_formatter.dart';` ekle.

- [ ] **Step 6: Testi çalıştır, düştüğünü gör**

Run: `flutter test test/home_widget/widget_snapshot_builder_test.dart`
Expected: FAIL — `hijri` parametresi eksik olduğu için derleme hatası

- [ ] **Step 7: Builder'ı güncelle**

`widget_snapshot_builder.dart`'ta `_toDay`:

```dart
  static WidgetSnapshotDay _toDay(PrayerTime time) {
    final day = _dayOf(time.date);
    return WidgetSnapshotDay(
      date: day,
      hijri: HijriFormatter.format(day),
      times: WidgetDayTimes(
        fajr: time.fajr,
        sunrise: time.sunrise,
        dhuhr: time.dhuhr,
        asr: time.asr,
        maghrib: time.maghrib,
        isha: time.isha,
      ),
    );
  }
```

Dosyanın başına `import '../../../core/utils/hijri_formatter.dart';` ekle.

- [ ] **Step 8: Tüm Dart testlerini çalıştır**

Run: `flutter analyze && flutter test`
Expected: analiz temiz, tüm testler PASS

- [ ] **Step 9: Commit**

```bash
git add lib/features/home_widget test/home_widget
git commit -m "feat: widget payload'ina hicri tarih eklendi

Hicri tarih Swift'te hesaplanmiyor: iOS'un islamicUmmAlQura takvimi
uygulamanin kullandigi hijri paketinden gun kayabiliyor. schemaVersion 2."
```

---

### Task 2: Swift tarafında isteğe bağlı hicri ve v1/v2 kabulü

**Files:**
- Modify: `ios/WidgetCore/WidgetSnapshot.swift`
- Modify: `ios/RunnerTests/WidgetSnapshotTests.swift`

**Interfaces:**
- Consumes: Task 1'in JSON şeması
- Produces: `SnapshotDay.hijri: String?`, `WidgetSnapshot.supportedSchemaVersions: Set<Int>` (`[1, 2]`)

- [ ] **Step 1: Write the failing tests**

`ios/RunnerTests/WidgetSnapshotTests.swift`'i tamamen şununla değiştir:

```swift
import XCTest

final class WidgetSnapshotTests: XCTestCase {
    private func jsonV2(schemaVersion: Int = 2) -> Data {
        """
        {
          "schemaVersion": \(schemaVersion),
          "locationLabel": "Ankara",
          "generatedAt": "2026-08-29T23:03:00",
          "days": [
            { "date": "2026-08-29",
              "hijri": "13 Rebiülevvel 1448",
              "times": { "fajr": "04:37", "sunrise": "06:06", "dhuhr": "12:55",
                         "asr": "16:36", "maghrib": "19:32", "isha": "20:55" } }
          ]
        }
        """.data(using: .utf8)!
    }

    private var jsonV1: Data {
        """
        {
          "schemaVersion": 1,
          "locationLabel": "Ankara",
          "generatedAt": "2026-08-29T23:03:00",
          "days": [
            { "date": "2026-08-29",
              "times": { "fajr": "04:37", "sunrise": "06:06", "dhuhr": "12:55",
                         "asr": "16:36", "maghrib": "19:32", "isha": "20:55" } }
          ]
        }
        """.data(using: .utf8)!
    }

    func testDecodesV2WithHijri() throws {
        let snapshot = try WidgetSnapshot.decode(jsonV2())
        XCTAssertEqual(snapshot.locationLabel, "Ankara")
        XCTAssertEqual(snapshot.days[0].hijri, "13 Rebiülevvel 1448")
        XCTAssertEqual(snapshot.days[0].times.asr, "16:36")
    }

    /// Guncelleme aninda App Group'ta hala v1 payload duruyor olabilir.
    /// Reddetseydik kullaniciya uygulama zaten guncelken "uygulamayi
    /// guncelleyin" gosterirdik.
    func testAcceptsV1WithoutHijri() throws {
        let snapshot = try WidgetSnapshot.decode(jsonV1)
        XCTAssertNil(snapshot.days[0].hijri)
        XCTAssertEqual(snapshot.days[0].times.fajr, "04:37")
    }

    func testRejectsUnknownSchemaVersion() {
        XCTAssertThrowsError(try WidgetSnapshot.decode(jsonV2(schemaVersion: 99))) { error in
            XCTAssertEqual(error as? SnapshotLoadError, .unsupportedSchema)
        }
    }

    func testRejectsMalformedPayload() {
        let broken = "{ not json".data(using: .utf8)!
        XCTAssertThrowsError(try WidgetSnapshot.decode(broken)) { error in
            XCTAssertEqual(error as? SnapshotLoadError, .malformed)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RunnerTests/WidgetSnapshotTests 2>&1 | grep -E "error:|TEST " | head -5
```
Expected: FAIL — `value of type 'SnapshotDay' has no member 'hijri'`

- [ ] **Step 3: Write minimal implementation**

`ios/WidgetCore/WidgetSnapshot.swift` içinde `SnapshotDay` ve `WidgetSnapshot`:

```swift
struct SnapshotDay: Decodable, Equatable {
    /// `"yyyy-MM-dd"`. Offset taşımaz; cihaz-yerel wall-clock olarak yorumlanır.
    let date: String

    /// Uygulamanın hesapladığı hicri tarih. v1 payload'da yoktur.
    let hijri: String?

    let times: SnapshotTimes
}

struct WidgetSnapshot: Decodable, Equatable {
    /// v1 hâlâ kabul edilir: güncelleme anında App Group'ta eski payload
    /// duruyor olabilir ve onu reddetmek, uygulama zaten güncelken
    /// "uygulamayı güncelleyin" göstermek olurdu.
    static let supportedSchemaVersions: Set<Int> = [1, 2]

    let schemaVersion: Int
    let locationLabel: String
    let days: [SnapshotDay]

    static func decode(_ json: Data) throws -> WidgetSnapshot {
        let snapshot: WidgetSnapshot
        do {
            snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: json)
        } catch {
            throw SnapshotLoadError.malformed
        }

        guard supportedSchemaVersions.contains(snapshot.schemaVersion) else {
            throw SnapshotLoadError.unsupportedSchema
        }
        return snapshot
    }
}
```

- [ ] **Step 4: Diğer testlerdeki `SnapshotDay` çağrılarını düzelt**

`NextPrayerTests.swift`, `DayPhaseTests.swift` ve `PrayerTimelineTests.swift` içindeki `SnapshotDay(date:times:)` çağrılarına `hijri: "13 Rebiülevvel 1448"` ekle.

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|TEST " | head -5
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add ios/WidgetCore ios/RunnerTests
git commit -m "feat: widget v1 ve v2 payload'i birlikte kabul ediyor

hijri istege bagli. v1'i reddetseydik guncelleme aninda App Group'ta duran
eski payload yuzunden kullaniciya uygulama zaten guncelken 'uygulamayi
guncelleyin' gosterirdik."
```

---

### Task 3: Geri sayım biçimlendiricisi

Always-On'da kendi çizdiğimiz metin. Sistemin biçimini taklit eder: sıfır dolgusu yok, saniye tire.

**Files:**
- Create: `ios/WidgetCore/CountdownText.swift`
- Create: `ios/RunnerTests/CountdownTextTests.swift`

**Interfaces:**
- Consumes: (yok)
- Produces: `enum CountdownText { static func format(from: Date, to: Date) -> String }`

- [ ] **Step 1: Write the failing test**

`ios/RunnerTests/CountdownTextTests.swift`:

```swift
import XCTest

final class CountdownTextTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func text(after seconds: TimeInterval) -> String {
        CountdownText.format(from: base, to: base.addingTimeInterval(seconds))
    }

    /// Sistem "5:34:42" yaziyor; biz saniyeyi tire yapip geri kalanini birebir
    /// taklit ediyoruz. Sifir dolgusu yok.
    func testHoursMinutesWithDashedSeconds() {
        XCTAssertEqual(text(after: 5 * 3600 + 34 * 60 + 42), "5:34:--")
    }

    func testMinutesArePaddedOnlyWhenHoursPresent() {
        XCTAssertEqual(text(after: 5 * 3600 + 4 * 60), "5:04:--")
    }

    /// Bir saatin altinda sistem "34:42" yaziyor, saat hanesi hic cikmiyor.
    func testUnderAnHourDropsTheHour() {
        XCTAssertEqual(text(after: 34 * 60 + 42), "34:--")
    }

    func testUnderTenMinutesIsNotPadded() {
        XCTAssertEqual(text(after: 9 * 60 + 5), "9:--")
    }

    func testPastDeadlineClampsToZero() {
        XCTAssertEqual(text(after: -120), "0:--")
    }

    /// Saniye kalintisi asagi yuvarlanir; 59 saniye kala hala "0:--".
    func testPartialMinuteRoundsDown() {
        XCTAssertEqual(text(after: 59), "0:--")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RunnerTests/CountdownTextTests 2>&1 | grep -E "error:|TEST " | head -5
```
Expected: FAIL — `cannot find 'CountdownText' in scope`

- [ ] **Step 3: Write minimal implementation**

`ios/WidgetCore/CountdownText.swift`:

```swift
import Foundation

/// Always-On ekranda kendi çizdiğimiz geri sayım.
///
/// Sistemin `Text(date, style: .timer)` biçimini taklit eder — sıfır dolgusu
/// yok, saat hanesi yalnızca gerekince çıkar — ama saniye yerine tire koyar.
/// Sebep: widget saniyede bir güncellenemiyor, timeline dakika başına giriş
/// üretiyor. Donmuş bir saniye rakamı, tireden daha yanıltıcı olurdu.
enum CountdownText {
    static func format(from: Date, to: Date) -> String {
        let remaining = max(0, Int(to.timeIntervalSince(from)))
        let totalMinutes = remaining / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):--"
        }
        return "\(minutes):--"
    }
}
```

- [ ] **Step 4: Kaydet ve testi çalıştır**

```bash
python3 /private/tmp/claude-501/-Users-ekrem-projects-ezanvakti/67e9b7d1-044b-4ef9-86ee-6d0e53c0d3b1/scratchpad/pbxadd.py \
  --group WidgetCore --path WidgetCore --targets widget,tests ios/WidgetCore/CountdownText.swift
python3 /private/tmp/claude-501/-Users-ekrem-projects-ezanvakti/67e9b7d1-044b-4ef9-86ee-6d0e53c0d3b1/scratchpad/pbxadd.py \
  --group RunnerTests --path RunnerTests --targets tests ios/RunnerTests/CountdownTextTests.swift
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RunnerTests/CountdownTextTests 2>&1 | grep -E "error:|TEST " | head -5
```
Expected: `** TEST SUCCEEDED **`, 6 test

- [ ] **Step 5: Commit**

```bash
git add ios/WidgetCore/CountdownText.swift ios/RunnerTests/CountdownTextTests.swift ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: Always-On icin geri sayim bicimlendiricisi

Sistemin bicimini taklit ediyor: sifir dolgusu yok, saat hanesi yalnizca
gerekince cikiyor. Saniye tire, cunku widget saniyede bir guncellenemiyor ve
donmus bir saniye rakami tireden yaniltici olurdu."
```

---

### Task 4: Gün etiketi biçimlendiricisi

**Files:**
- Create: `ios/WidgetCore/DayLabel.swift`
- Create: `ios/RunnerTests/DayLabelTests.swift`

**Interfaces:**
- Consumes: `SnapshotDay` (Task 2)
- Produces: `enum DayLabel { static func gregorian(_ day: SnapshotDay) -> String? }`

- [ ] **Step 1: Write the failing test**

`ios/RunnerTests/DayLabelTests.swift`:

```swift
import XCTest

final class DayLabelTests: XCTestCase {
    private func day(_ date: String) -> SnapshotDay {
        SnapshotDay(
            date: date,
            hijri: "13 Rebiülevvel 1448",
            times: SnapshotTimes(
                fajr: "04:37", sunrise: "06:06", dhuhr: "12:55",
                asr: "16:36", maghrib: "19:32", isha: "20:55"
            )
        )
    }

    /// Cihaz dili ne olursa olsun Turkce: uygulama tamamen Turkce.
    func testFormatsInTurkishRegardlessOfDeviceLocale() {
        XCTAssertEqual(DayLabel.gregorian(day("2026-08-29")), "Cumartesi, 29 Ağustos")
    }

    func testAnotherMonth() {
        XCTAssertEqual(DayLabel.gregorian(day("2026-01-02")), "Cuma, 2 Ocak")
    }

    func testMalformedDateReturnsNil() {
        XCTAssertNil(DayLabel.gregorian(day("bozuk")))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RunnerTests/DayLabelTests 2>&1 | grep -E "error:|TEST " | head -5
```
Expected: FAIL — `cannot find 'DayLabel' in scope`

- [ ] **Step 3: Write minimal implementation**

`ios/WidgetCore/DayLabel.swift`:

```swift
import Foundation

/// Gösterilen günün miladi etiketi: `"Cumartesi, 29 Ağustos"`.
///
/// Hicri tarih burada üretilmez — o payload'dan gelir. Locale `tr_TR` ile
/// zorlanır çünkü uygulama tamamen Türkçe; cihaz diline bırakmak widget'ı
/// uygulamadan farklı bir dilde konuşturur.
enum DayLabel {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter
    }()

    private static let parser: DateFormatter = {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return parser
    }()

    static func gregorian(_ day: SnapshotDay) -> String? {
        guard let date = parser.date(from: day.date) else { return nil }
        return formatter.string(from: date)
    }
}
```

⚠️ `setLocalizedDateFormatFromTemplate` tr_TR için beklenen sıralamayı vermezse (test çıktısı `"29 Ağustos Cumartesi"` gibi çıkarsa) `formatter.dateFormat = "EEEE, d MMMM"` ile sabitle ve testi tekrar çalıştır.

- [ ] **Step 4: Kaydet ve testi çalıştır**

```bash
python3 /private/tmp/claude-501/-Users-ekrem-projects-ezanvakti/67e9b7d1-044b-4ef9-86ee-6d0e53c0d3b1/scratchpad/pbxadd.py \
  --group WidgetCore --path WidgetCore --targets widget,tests ios/WidgetCore/DayLabel.swift
python3 /private/tmp/claude-501/-Users-ekrem-projects-ezanvakti/67e9b7d1-044b-4ef9-86ee-6d0e53c0d3b1/scratchpad/pbxadd.py \
  --group RunnerTests --path RunnerTests --targets tests ios/RunnerTests/DayLabelTests.swift
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RunnerTests/DayLabelTests 2>&1 | grep -E "error:|TEST " | head -5
```
Expected: `** TEST SUCCEEDED **`, 3 test

- [ ] **Step 5: Commit**

```bash
git add ios/WidgetCore/DayLabel.swift ios/RunnerTests/DayLabelTests.swift ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: widget icin Turkce gun etiketi bicimlendiricisi

Locale tr_TR ile zorlaniyor: cihaz diline birakmak widget'i uygulamadan
farkli bir dilde konusturur."
```

---

### Task 5: Dakikalık timeline, sıradaki vaktin günü ve YARIN

Bu turun çekirdeği. İki hatayı (M3, M4) düzeltir ve Always-On çizimini mümkün kılar.

**Files:**
- Modify: `ios/WidgetCore/PrayerTimeline.swift`
- Modify: `ios/RunnerTests/PrayerTimelineTests.swift`

**Interfaces:**
- Consumes: `WidgetSnapshot`, `SnapshotDay` (Task 2); `NextPrayer`, `PrayerSlot`, `DayPhase`
- Produces: `WidgetContent.ready(next: PrayerSlot, day: SnapshotDay, phase: DayPhase, locationLabel: String, isStale: Bool, isTomorrow: Bool)`, `PrayerTimeline.windowMinutes` (`Int`, 120), `PrayerTimeline.entries(for:now:calendar:) -> [PrayerEntry]`

- [ ] **Step 1: Write the failing tests**

`ios/RunnerTests/PrayerTimelineTests.swift`'e mevcut testlere ek olarak şunları koy; `testEntriesLandOnPrayerBoundaries` ve `testHorizonIsCapped` testlerini **sil** (artık girişler vakit sınırlarında değil, dakika başında):

```swift
    func testEntriesAreOneMinuteApart() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-25", "2026-08-26"])),
            now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertEqual(entries[0].date, at(25, 14, 0))
        XCTAssertEqual(entries[1].date, at(25, 14, 1))
        XCTAssertEqual(entries[2].date, at(25, 14, 2))
    }

    func testWindowCoversTwoHours() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-25", "2026-08-26"])),
            now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertEqual(entries.count, PrayerTimeline.windowMinutes + 1)
        XCTAssertEqual(entries.last?.date, at(25, 16, 0))
    }

    /// M3/M4: 23:00'te siradaki vakit yarinin Imsak'i; liste de yarini
    /// gostermeli, yoksa iki sutun farkli gune bakar ve vurgu listede
    /// karsilik bulmaz.
    func testListFollowsTheDayOfTheNextPrayer() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-25", "2026-08-26"])),
            now: at(25, 23, 0), calendar: calendar
        )
        guard case let .ready(next, day, _, _, _, isTomorrow) = entries[0].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(next.name, "İmsak")
        XCTAssertEqual(day.date, "2026-08-26")
        XCTAssertTrue(isTomorrow)
    }

    func testIsTomorrowIsFalseWithinTheSameDay() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-25", "2026-08-26"])),
            now: at(25, 14, 0), calendar: calendar
        )
        guard case let .ready(_, day, _, _, _, isTomorrow) = entries[0].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(day.date, "2026-08-25")
        XCTAssertFalse(isTomorrow)
    }

    /// Pencere icinde vakit gecince o girisin siradakisi degismeli.
    func testEntryAfterBoundaryAdvancesToTheNextPrayer() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-25", "2026-08-26"])),
            now: at(25, 16, 57), calendar: calendar
        )
        guard case let .ready(before, _, _, _, _, _) = entries[0].content,
              case let .ready(after, _, _, _, _, _) = entries[2].content else {
            return XCTFail("ready bekleniyordu")
        }
        XCTAssertEqual(before.name, "İkindi")   // 16:58
        XCTAssertEqual(after.name, "Akşam")     // 16:59'da İkindi gecmis
    }
```

Mevcut `testStaleSnapshotIsMarked` içindeki desen eşleşmesini altı bileşene çıkar:

```swift
        guard case let .ready(_, _, _, _, isStale, _) = entries[0].content else {
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RunnerTests/PrayerTimelineTests 2>&1 | grep -E "error:|TEST " | head -5
```
Expected: FAIL — `pattern with 6 elements cannot match 'ready' with 5 associated values`

- [ ] **Step 3: Write minimal implementation**

`ios/WidgetCore/PrayerTimeline.swift`'i şununla değiştir:

```swift
import WidgetKit

enum WidgetContent: Equatable {
    case ready(
        next: PrayerSlot,
        day: SnapshotDay,
        phase: DayPhase,
        locationLabel: String,
        isStale: Bool,
        isTomorrow: Bool
    )
    /// Widget kurulmuş ama uygulama hiç açılmamış.
    case noData
    /// Payload'ın şeması widget'ın bildiğinden yeni.
    case needsUpdate
}

struct PrayerEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent
}

enum PrayerTimeline {
    /// Timeline'ın ileriyi görme mesafesi, dakika cinsinden.
    ///
    /// Always-On ekranda geri sayımı biz çiziyoruz (`CountdownText`) ve widget
    /// görünümleri önceden hazırlandığı için sayının dakikada bir değişmesinin
    /// tek yolu dakika başına giriş üretmek. Girişler yenileme bütçesi
    /// harcamaz; harcayan, timeline tükendiğinde istenen yenilemedir. İki
    /// saatlik pencere günde ~12 yenileme demek.
    static let windowMinutes = 120

    static func entries(
        for result: Result<WidgetSnapshot, SnapshotLoadError>?,
        now: Date,
        calendar: Calendar
    ) -> [PrayerEntry] {
        guard let result else {
            return [PrayerEntry(date: now, content: .noData)]
        }

        switch result {
        case .failure(.unsupportedSchema):
            return [PrayerEntry(date: now, content: .needsUpdate)]
        case .failure(.malformed):
            return [PrayerEntry(date: now, content: .noData)]
        case .success(let snapshot):
            return entries(for: snapshot, now: now, calendar: calendar)
        }
    }

    private static func entries(
        for snapshot: WidgetSnapshot,
        now: Date,
        calendar: Calendar
    ) -> [PrayerEntry] {
        let slots = NextPrayer.slots(days: snapshot.days, calendar: calendar)
        guard !slots.isEmpty else {
            return [PrayerEntry(date: now, content: .noData)]
        }

        return (0...windowMinutes).map { minute in
            let moment = now.addingTimeInterval(TimeInterval(minute * 60))
            return PrayerEntry(
                date: moment,
                content: content(
                    for: snapshot, slots: slots, at: moment, calendar: calendar
                )
            )
        }
    }

    private static func content(
        for snapshot: WidgetSnapshot,
        slots: [PrayerSlot],
        at moment: Date,
        calendar: Calendar
    ) -> WidgetContent {
        guard let next = slots.first(where: { $0.date > moment }) else {
            // Pencere tükendi: son bilinen günü bayat olarak göster. Boş kutu
            // bırakmaktansa eski veriyi "güncel değil" damgasıyla göstermek
            // kullanıcıya daha çok şey anlatır.
            return .ready(
                next: slots[slots.count - 1],
                day: snapshot.days[snapshot.days.count - 1],
                phase: DayPhase.fallback,
                locationLabel: snapshot.locationLabel,
                isStale: true,
                isTomorrow: false
            )
        }

        // Liste, sıradaki vaktin gününü gösterir. `moment`'in gününü
        // gösterseydi Yatsı'dan sonra sol sütun yarını, sağ sütun bugünü
        // gösterirdi ve vurgulanacak satır listede hiç bulunmazdı.
        let nextDayKey = dateKey(next.date, calendar: calendar)
        let day = snapshot.days.first { $0.date == nextDayKey }

        return .ready(
            next: next,
            day: day ?? snapshot.days[snapshot.days.count - 1],
            phase: DayPhase.resolve(slots: slots, now: moment, calendar: calendar),
            locationLabel: snapshot.locationLabel,
            isStale: day == nil,
            isTomorrow: nextDayKey != dateKey(moment, calendar: calendar)
        )
    }

    /// `SnapshotDay.date` ile karşılaştırmak için `"yyyy-MM-dd"` anahtarı.
    /// `DateFormatter` yerine bileşen kullanılıyor: locale ve takvim
    /// sürprizlerine kapalı.
    private static func dateKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RunnerTests/PrayerTimelineTests 2>&1 | grep -E "error:|TEST " | head -5
```
Expected: `** TEST SUCCEEDED **`

⚠️ Bu adımda görünümler henüz altı bileşenli `.ready`'yi bilmiyor; `flutter build ios` bu noktada derlenmeyebilir. Task 8–10'da düzeliyor. Testler geçtiği için commit'lemek doğru; derleme doğrulaması Task 10'un sonunda yapılır.

- [ ] **Step 5: Commit**

```bash
git add ios/WidgetCore/PrayerTimeline.swift ios/RunnerTests/PrayerTimelineTests.swift
git commit -m "fix: widget listesi artik siradaki vaktin gunune bakiyor

Yatsi'dan sonra sol sutun yarinin Imsak'ini, sag sutun bugunu gosteriyordu;
vurgulanacak satir listede hic bulunmadigi icin alti vakit de soluk
ciziliyordu. Gun artik moment'e degil siradaki vakte gore seciliyor.

Timeline dakika basina giris uretiyor (2 saatlik pencere): Always-On ekranda
geri sayimi biz cizecegiz ve gorunumler onceden hazirlandigi icin sayinin
dakikada bir degismesinin tek yolu bu. Girisler yenileme butcesi harcamiyor.

isTomorrow eklendi: siradaki vakit ertesi gune aitse gorunum YARIN yazacak."
```

---

### Task 6: Hizalama ayarı ve `AppIntentConfiguration`

**Files:**
- Create: `ios/WidgetCore/WidgetAlignment.swift`
- Create: `ios/EzanVaktiWidget/Configuration/EzanVaktiWidgetIntent.swift`
- Create: `ios/RunnerTests/WidgetAlignmentTests.swift`

**Interfaces:**
- Consumes: (yok)
- Produces: `enum WidgetAlignment: String, CaseIterable { case leading, center, trailing }`, `WidgetAlignment.horizontal: HorizontalAlignment`, `WidgetAlignment.frame: Alignment`, `WidgetAlignment.textAlignment: TextAlignment`, `struct EzanVaktiWidgetIntent: WidgetConfigurationIntent { var alignment: WidgetAlignment }`

- [ ] **Step 1: Write the failing test**

`ios/RunnerTests/WidgetAlignmentTests.swift`:

```swift
import SwiftUI
import XCTest

final class WidgetAlignmentTests: XCTestCase {
    func testDefaultIsLeading() {
        XCTAssertEqual(WidgetAlignment.default, .leading)
    }

    func testMapsToSwiftUIHorizontalAlignment() {
        XCTAssertEqual(WidgetAlignment.leading.horizontal, .leading)
        XCTAssertEqual(WidgetAlignment.center.horizontal, .center)
        XCTAssertEqual(WidgetAlignment.trailing.horizontal, .trailing)
    }

    func testMapsToTextAlignment() {
        XCTAssertEqual(WidgetAlignment.leading.textAlignment, .leading)
        XCTAssertEqual(WidgetAlignment.center.textAlignment, .center)
        XCTAssertEqual(WidgetAlignment.trailing.textAlignment, .trailing)
    }

    func testHasThreeCases() {
        XCTAssertEqual(WidgetAlignment.allCases.count, 3)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RunnerTests/WidgetAlignmentTests 2>&1 | grep -E "error:|TEST " | head -5
```
Expected: FAIL — `cannot find 'WidgetAlignment' in scope`

- [ ] **Step 3: Saf enum'u yaz**

`ios/WidgetCore/WidgetAlignment.swift`:

```swift
import SwiftUI

/// Ana ekran widget'larında blokların yatay hizası.
///
/// `AppEnum` uyumu widget target'ındaki `EzanVaktiWidgetIntent.swift`'te
/// extension olarak veriliyor; bu dosya AppIntents'e bağımlı değil ki
/// XCTest'te sınanabilsin.
enum WidgetAlignment: String, CaseIterable {
    case leading
    case center
    case trailing

    static let `default`: WidgetAlignment = .leading

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frame: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
```

- [ ] **Step 4: Intent'i yaz**

`ios/EzanVaktiWidget/Configuration/EzanVaktiWidgetIntent.swift`:

```swift
import AppIntents

extension WidgetAlignment: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Hizalama" }

    static var caseDisplayRepresentations: [WidgetAlignment: DisplayRepresentation] {
        [
            .leading: "Sola yaslı",
            .center: "Ortalı",
            .trailing: "Sağa yaslı",
        ]
    }
}

/// Widget'a uzun basıp "Widget'ı Düzenle" dendiğinde çıkan ayar.
struct EzanVaktiWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Ezan Vakti" }
    static var description: IntentDescription { "Sıradaki vakit ve geri sayım." }

    @Parameter(title: "Hizalama", default: .leading)
    var alignment: WidgetAlignment

    init() {}
}
```

- [ ] **Step 5: Kaydet ve testi çalıştır**

```bash
python3 /private/tmp/claude-501/-Users-ekrem-projects-ezanvakti/67e9b7d1-044b-4ef9-86ee-6d0e53c0d3b1/scratchpad/pbxadd.py \
  --group WidgetCore --path WidgetCore --targets widget,tests ios/WidgetCore/WidgetAlignment.swift
python3 /private/tmp/claude-501/-Users-ekrem-projects-ezanvakti/67e9b7d1-044b-4ef9-86ee-6d0e53c0d3b1/scratchpad/pbxadd.py \
  --group RunnerTests --path RunnerTests --targets tests ios/RunnerTests/WidgetAlignmentTests.swift
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:RunnerTests/WidgetAlignmentTests 2>&1 | grep -E "error:|TEST " | head -5
```
Expected: `** TEST SUCCEEDED **`, 4 test

`Configuration/` klasörü `ios/EzanVaktiWidget/` altında olduğu için pbxproj'a eklenmesi gerekmez — synchronized grup otomatik alır.

- [ ] **Step 6: Commit**

```bash
git add ios/WidgetCore/WidgetAlignment.swift ios/EzanVaktiWidget/Configuration ios/RunnerTests/WidgetAlignmentTests.swift ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: widget hizalama ayari

Galeriye uc kopya koymak yerine iOS'un standart 'Widget'i Duzenle' akisi.
Saf enum WidgetCore'da kaliyor ki XCTest'te sinanabilsin; AppEnum uyumu
widget target'inda extension olarak veriliyor."
```

---

### Task 7: Widget'a özel açık tema durakları

**Files:**
- Modify: `ios/EzanVaktiWidget/Theme/Palette.swift`

**Interfaces:**
- Consumes: `DayPhase`
- Produces: (değişmez — `Palette.forPhase(_:colorScheme:)` aynı imzayla döner)

- [ ] **Step 1: Açık palet duraklarını widget için koyulaştır**

`Palette.swift`'teki `light(_:)` fonksiyonunun tamamını şununla değiştir. Yalnızca `backgroundStops` değişiyor: ilk durak belirgin şekilde koyulaşıyor, son durak neredeyse aynı kalıyor. `accent` ve metin renklerine dokunulmuyor — ilk durak koyulaştığı için metin kontrastı azalmıyor, artıyor.

```swift
    /// Açık temada duraklar uygulamanınkinden **koyudur**.
    ///
    /// Uygulamada gradyan koca bir ekrana yayılıyor ve yumuşak bir geçiş
    /// okunuyor; 2x2'lik bir kutuda aynı değerler düz beyaz karta dönüşüyordu.
    /// Renk ailesi (ton) korunur, yalnızca duraklar arası kontrast açılır.
    private static func light(_ phase: DayPhase) -> Palette {
        switch phase {
        case .morning: // NİLÜFER
            return Palette(
                accent: Color(hex: 0x265F8E),
                textPrimary: Color(hex: 0x0E1D2C),
                textSecondary: Color(hex: 0x43596D),
                backgroundStops: [Color(hex: 0xB8D2ED), Color(hex: 0xDCE9F7), Color(hex: 0xF3F8FC)]
            )
        case .afternoon: // SEDEF
            return Palette(
                accent: Color(hex: 0x2A5B68),
                textPrimary: Color(hex: 0x0F1C21),
                textSecondary: Color(hex: 0x435A62),
                backgroundStops: [Color(hex: 0xC2D8DE), Color(hex: 0xE2ECF0), Color(hex: 0xF4F9FA)]
            )
        case .evening: // GÜLKURUSU
            return Palette(
                accent: Color(hex: 0x983F62),
                textPrimary: Color(hex: 0x201A1E),
                textSecondary: Color(hex: 0x5A4A50),
                backgroundStops: [Color(hex: 0xEFCBD6), Color(hex: 0xF7E7EB), Color(hex: 0xFCF5F6)]
            )
        case .night: // LEYLAK
            return Palette(
                accent: Color(hex: 0x5E3A80),
                textPrimary: Color(hex: 0x1A1424),
                textSecondary: Color(hex: 0x4F4260),
                backgroundStops: [Color(hex: 0xD6C8E4), Color(hex: 0xEBE4F1), Color(hex: 0xF8F5FA)]
            )
        }
    }
```

- [ ] **Step 2: Metin kontrastını doğrula**

Açık paletlerde `textSecondary` değerleri değişmedi; ilk durak koyulaştığı için kontrast **arttı**, azalmadı. Gözle doğrulama Task 11'deki cihaz testinde.

- [ ] **Step 3: Derlemeyi kontrol et**

Run: `xcodebuild build -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **` ya da yalnızca Task 5'ten gelen görünüm hataları

- [ ] **Step 4: Commit**

```bash
git add ios/EzanVaktiWidget/Theme/Palette.swift
git commit -m "fix: acik temada widget zemini duz beyaz kart gibi duruyordu

Uygulamada gradyan koca ekrana yayilip yumusak bir gecis okunuyor; 2x2'lik
kutuda ayni degerler duz beyaza donusuyordu. Duraklar widget icin
koyulastirildi, palet ailesi korundu."
```

---

### Task 8: SmallView yeniden düzeni

**Files:**
- Modify: `ios/EzanVaktiWidget/Views/SmallView.swift`

**Interfaces:**
- Consumes: `PrayerEntry`, `WidgetContent` (Task 5); `CountdownText` (Task 3); `DayLabel` (Task 4); `WidgetAlignment` (Task 6); `Palette` (Task 7)
- Produces: `struct SmallView: View { init(entry: PrayerEntry, alignment: WidgetAlignment) }`

- [ ] **Step 1: Görünümü yeniden yaz**

`ios/EzanVaktiWidget/Views/SmallView.swift`:

```swift
import SwiftUI

struct SmallView: View {
    @Environment(\.colorScheme) private var colorScheme
    /// Always-On ekranda `true`. Sistemin canlı sayacı orada okunmaz bir
    /// biçime düşüyor; o durumda geri sayımı kendimiz çiziyoruz.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let entry: PrayerEntry
    let alignment: WidgetAlignment

    var body: some View {
        switch entry.content {
        case .noData:
            MessageView(text: "Vakitler için uygulamayı aç", phase: .fallback)
        case .needsUpdate:
            MessageView(text: "Uygulamayı güncelleyin", phase: .fallback)
        case let .ready(next, day, phase, locationLabel, isStale, isTomorrow):
            ready(
                next: next, day: day, phase: phase,
                locationLabel: locationLabel, isStale: isStale, isTomorrow: isTomorrow
            )
        }
    }

    private func ready(
        next: PrayerSlot, day: SnapshotDay, phase: DayPhase,
        locationLabel: String, isStale: Bool, isTomorrow: Bool
    ) -> some View {
        let palette = Palette.forPhase(phase, colorScheme: colorScheme)

        return VStack(alignment: alignment.horizontal, spacing: 0) {
            // Üst blok: ikincil bilgi, küçük punto.
            VStack(alignment: alignment.horizontal, spacing: 1) {
                if let gregorian = DayLabel.gregorian(day) {
                    Text(gregorian)
                }
                if let hijri = day.hijri {
                    Text(hijri)
                }
                Text(isStale ? "Güncel değil" : locationLabel)
            }
            .font(.system(size: 10))
            .foregroundStyle(palette.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            // Alt blok: widget'ın asıl işi.
            VStack(alignment: alignment.horizontal, spacing: 0) {
                Text(
                    (isTomorrow ? "YARIN · " : "")
                        + next.name.uppercased(with: Locale(identifier: "tr_TR"))
                )
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Text(next.date, format: .dateTime.hour().minute())
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                CountdownLabel(
                    entry: entry,
                    target: next.date,
                    isLuminanceReduced: isLuminanceReduced,
                    size: 32,
                    color: palette.textPrimary
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frame)
        .multilineTextAlignment(alignment.textAlignment)
        .opacity(isStale ? 0.55 : 1)
    }
}
```

- [ ] **Step 2: Ortak geri sayım etiketini yaz**

`ios/EzanVaktiWidget/Views/CountdownLabel.swift`:

```swift
import SwiftUI

/// Hibrit geri sayım.
///
/// Ekran açıkken sistemin canlı sayacını kullanırız — saniye akar, biçimine
/// karışamayız. Always-On ekranda aynı metin `"5 hours 51 minutes"` gibi
/// okunmaz bir biçime düşüyor; orada `CountdownText` ile kendimiz çizeriz.
/// Kendi çizimimiz sistemin biçimini taklit eder, yalnızca saniye tire olur.
struct CountdownLabel: View {
    let entry: PrayerEntry
    let target: Date
    let isLuminanceReduced: Bool
    let size: CGFloat
    let color: Color

    var body: some View {
        Group {
            if isLuminanceReduced {
                Text(CountdownText.format(from: entry.date, to: target))
            } else {
                Text(target, style: .timer)
            }
        }
        .font(.system(size: size, weight: .semibold).monospacedDigit())
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add ios/EzanVaktiWidget/Views/SmallView.swift ios/EzanVaktiWidget/Views/CountdownLabel.swift
git commit -m "feat: small widget yeniden duzenlendi

Tarih ve konum uste ve kucuk, vakit ile geri sayim alta ve baskin. Alt bosluk
kapandi, geri sayim 26'dan 32'ye cikip yariagirliktan kalina gecti.

Geri sayim hibrit: ekran acikken sistemin canli sayaci, Always-On'da kendi
cizimimiz. Sistem yalnizca sonuk ekranda okunmaz bicime dusuyor."
```

---

### Task 9: MediumView yeniden düzeni

**Files:**
- Modify: `ios/EzanVaktiWidget/Views/MediumView.swift`

**Interfaces:**
- Consumes: Task 8'in tamamı (`CountdownLabel` dahil)
- Produces: `struct MediumView: View { init(entry: PrayerEntry, alignment: WidgetAlignment) }`

- [ ] **Step 1: Görünümü yeniden yaz**

`ios/EzanVaktiWidget/Views/MediumView.swift`:

```swift
import SwiftUI

struct MediumView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let entry: PrayerEntry
    let alignment: WidgetAlignment

    var body: some View {
        switch entry.content {
        case .noData:
            MessageView(text: "Vakitler için uygulamayı aç", phase: .fallback)
        case .needsUpdate:
            MessageView(text: "Uygulamayı güncelleyin", phase: .fallback)
        case let .ready(next, day, phase, locationLabel, isStale, isTomorrow):
            ready(
                next: next, day: day, phase: phase,
                locationLabel: locationLabel, isStale: isStale, isTomorrow: isTomorrow
            )
        }
    }

    private func ready(
        next: PrayerSlot, day: SnapshotDay, phase: DayPhase,
        locationLabel: String, isStale: Bool, isTomorrow: Bool
    ) -> some View {
        let palette = Palette.forPhase(phase, colorScheme: colorScheme)
        // Liste sıradaki vaktin gününü gösterir; `day` bu yüzden timeline'da
        // sıradaki vakte göre seçiliyor.
        let slots = NextPrayer.slots(days: [day], calendar: .current)

        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: alignment.horizontal, spacing: 0) {
                VStack(alignment: alignment.horizontal, spacing: 1) {
                    if let gregorian = DayLabel.gregorian(day) {
                        Text(gregorian)
                    }
                    Text(
                        [day.hijri, isStale ? "Güncel değil" : locationLabel]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                    )
                }
                .font(.system(size: 10))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Text(
                    (isTomorrow ? "YARIN · " : "")
                        + next.name.uppercased(with: Locale(identifier: "tr_TR"))
                )
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Text(next.date, format: .dateTime.hour().minute())
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                CountdownLabel(
                    entry: entry,
                    target: next.date,
                    isLuminanceReduced: isLuminanceReduced,
                    size: 26,
                    color: palette.textPrimary
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.frame)
            .multilineTextAlignment(alignment.textAlignment)

            // Altı satır dikeyde yayılıp yüksekliğin tamamını kaplar; 0.5.0'da
            // listenin altında ölü alan kalıyordu.
            VStack(spacing: 0) {
                ForEach(Array(slots.enumerated()), id: \.element.name) { index, slot in
                    if index > 0 { Spacer(minLength: 0) }
                    row(slot: slot, next: next, palette: palette)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(isStale ? 0.55 : 1)
    }

    /// Geçmiş vakitler soluk, sıradaki accent ile vurgulu.
    private func row(slot: PrayerSlot, next: PrayerSlot, palette: Palette) -> some View {
        let isNext = slot == next
        let isPast = slot.date < entry.date
        let weight: Font.Weight = isNext ? .semibold : .regular

        return HStack(spacing: 6) {
            Text(slot.name)
                .font(.system(size: 12, weight: weight))
            Spacer(minLength: 4)
            Text(slot.date, format: .dateTime.hour().minute())
                .font(.system(size: 12, weight: weight).monospacedDigit())
        }
        .lineLimit(1)
        .foregroundStyle(
            isNext
                ? palette.accent
                : (isPast ? palette.textSecondary.opacity(0.5) : palette.textPrimary)
        )
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add ios/EzanVaktiWidget/Views/MediumView.swift
git commit -m "fix: medium widget iki farkli gune bakmiyor artik

Sol sutun yarinin Imsak'ini, sag sutun bugunu gosteriyordu; vurgulanacak satir
listede bulunmadigi icin alti vakit de soluk ciziliyordu. Liste artik siradaki
vaktin gunune ait ve vurgu her zaman karsilik buluyor.

Alti satir dikeyde yayilip yuksekligin tamamini kapliyor, alt bosluk kapandi.
Siradaki vakit yarina aitse YARIN yaziyor."
```

---

### Task 10: RectangularView, inline'ın kaldırılması ve widget kaydı

**Files:**
- Modify: `ios/EzanVaktiWidget/Views/RectangularView.swift`
- Delete: `ios/EzanVaktiWidget/Views/InlineView.swift`
- Modify: `ios/EzanVaktiWidget/EzanVaktiWidget.swift`

**Interfaces:**
- Consumes: Task 5, 6, 8, 9
- Produces: `EzanVaktiWidget` — `AppIntentConfiguration`, aileler `systemSmall`, `systemMedium`, `accessoryRectangular`

- [ ] **Step 1: Rectangular'ı yeniden yaz**

`ios/EzanVaktiWidget/Views/RectangularView.swift`:

```swift
import SwiftUI
import WidgetKit

/// Kilit ekranı ailelerinde sistem tek renge indirger; gradyan denenmez.
struct RectangularView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    let entry: PrayerEntry

    var body: some View {
        switch entry.content {
        case .noData:
            Text("Vakitler için uygulamayı aç").font(.system(size: 12))
        case .needsUpdate:
            Text("Uygulamayı güncelleyin").font(.system(size: 12))
        case let .ready(next, _, _, _, isStale, isTomorrow):
            VStack(alignment: .leading, spacing: 1) {
                if isStale {
                    Text("GÜNCEL DEĞİL")
                        .font(.system(size: 10, weight: .semibold))
                        .widgetAccentable()
                }

                HStack(spacing: 4) {
                    Text(isTomorrow ? "Yarın \(next.name)" : next.name)
                    Text(next.date, format: .dateTime.hour().minute())
                        .monospacedDigit()
                }
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                // "SIRADAKİ" etiketi kalktı; yerini widget'ın asıl işi aldı.
                Group {
                    if isLuminanceReduced {
                        Text(CountdownText.format(from: entry.date, to: next.date))
                    } else {
                        Text(next.date, style: .timer)
                    }
                }
                .font(.system(size: 20, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 2: Inline'ı sil**

```bash
rm ios/EzanVaktiWidget/Views/InlineView.swift
```

- [ ] **Step 3: Widget kaydını `AppIntentConfiguration`'a çevir**

`ios/EzanVaktiWidget/EzanVaktiWidget.swift`:

```swift
import SwiftUI
import WidgetKit

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), content: .noData)
    }

    func snapshot(
        for configuration: EzanVaktiWidgetIntent, in context: Context
    ) async -> PrayerEntry {
        PrayerTimeline.entries(
            for: SnapshotStore.load(), now: Date(), calendar: .current
        ).first ?? placeholder(in: context)
    }

    func timeline(
        for configuration: EzanVaktiWidgetIntent, in context: Context
    ) async -> Timeline<PrayerEntry> {
        let now = Date()
        let entries = PrayerTimeline.entries(
            for: SnapshotStore.load(), now: now, calendar: .current
        )

        // Timeline tükendiğinde WidgetKit yeniden sorar. Veri yokken bir saat
        // sonra tekrar bakılır: uygulama bu arada açılmış olabilir.
        let refreshAt = entries.last.map {
            $0.date > now ? $0.date : now.addingTimeInterval(3600)
        } ?? now.addingTimeInterval(3600)

        return Timeline(entries: entries, policy: .after(refreshAt))
    }
}

struct EzanVaktiWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry
    let alignment: WidgetAlignment

    private var phase: DayPhase {
        if case let .ready(_, _, phase, _, _, _) = entry.content { return phase }
        return .fallback
    }

    var body: some View {
        content
            .widgetURL(URL(string: "ezanvakti://home"))
            .containerBackground(for: .widget) {
                switch family {
                case .systemSmall, .systemMedium:
                    PhaseBackground(phase: phase)
                default:
                    AccessoryWidgetBackground()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall: SmallView(entry: entry, alignment: alignment)
        case .systemMedium: MediumView(entry: entry, alignment: alignment)
        case .accessoryRectangular: RectangularView(entry: entry)
        default: SmallView(entry: entry, alignment: alignment)
        }
    }
}

struct EzanVaktiWidget: Widget {
    /// Dart tarafındaki `HomeWidgetPublisher.widgetKind` ile birebir aynı
    /// olmalı; aksi halde reload hiçbir widget'a ulaşmaz.
    let kind = "EzanVaktiWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: EzanVaktiWidgetIntent.self,
            provider: Provider()
        ) { entry in
            EzanVaktiWidgetEntryView(entry: entry, alignment: WidgetAlignment.default)
        }
        .configurationDisplayName("Ezan Vakti")
        .description("Sıradaki vakit ve geri sayım.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
```

⚠️ Yukarıdaki `EzanVaktiWidgetEntryView(entry:alignment:)` çağrısı hizalamayı **sabit** `.default` geçiyor; kullanıcının seçimi Step 4'te bağlanıyor.

- [ ] **Step 4: Hizalamayı entry üzerinden taşı**

`PrayerEntry`'nin `alignment` taşıması gerekiyor ki görünüm kullanıcının seçimini görsün. `ios/WidgetCore/PrayerTimeline.swift`'te:

```swift
struct PrayerEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent
    var alignment: WidgetAlignment = .default
}
```

`EzanVaktiWidget.swift`'te provider'ın iki fonksiyonunda konfigürasyonu uygula:

```swift
    func snapshot(
        for configuration: EzanVaktiWidgetIntent, in context: Context
    ) async -> PrayerEntry {
        var entry = PrayerTimeline.entries(
            for: SnapshotStore.load(), now: Date(), calendar: .current
        ).first ?? placeholder(in: context)
        entry.alignment = configuration.alignment
        return entry
    }

    func timeline(
        for configuration: EzanVaktiWidgetIntent, in context: Context
    ) async -> Timeline<PrayerEntry> {
        let now = Date()
        let entries = PrayerTimeline.entries(
            for: SnapshotStore.load(), now: now, calendar: .current
        ).map { entry -> PrayerEntry in
            var copy = entry
            copy.alignment = configuration.alignment
            return copy
        }

        let refreshAt = entries.last.map {
            $0.date > now ? $0.date : now.addingTimeInterval(3600)
        } ?? now.addingTimeInterval(3600)

        return Timeline(entries: entries, policy: .after(refreshAt))
    }
```

Ve görünüm çağrısını değiştir:

```swift
        } { entry in
            EzanVaktiWidgetEntryView(entry: entry, alignment: entry.alignment)
        }
```

- [ ] **Step 5: Tüm testleri ve derlemeyi çalıştır**

```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|TEST " | head -10
flutter build ios --no-codesign 2>&1 | tail -3
```
Expected: `** TEST SUCCEEDED **` ve `✓ Built build/ios/iphoneos/Runner.app`

- [ ] **Step 6: Commit**

```bash
git add ios/EzanVaktiWidget ios/WidgetCore/PrayerTimeline.swift
git commit -m "feat: kilit ekrani dikdortgeni buyudu, inline kaldirildi

SIRADAKI etiketi kalkti, geri sayim 13'ten 20'ye cikti. Always-On'da orada da
kendi cizimimiz devrede.

Inline widget kaldirildi (kullanici karari): tek satir ve tek renk oldugu icin
bu turdaki iyilestirmelerin hicbiri oraya uygulanamiyordu.

Widget StaticConfiguration'dan AppIntentConfiguration'a gecti; hizalama artik
'Widget'i Duzenle' ekranindan seciliyor."
```

---

### Task 11: URL şeması ve derin bağlantı teşhisi

**Files:**
- Modify: `ios/Runner/Info.plist`

**Interfaces:**
- Consumes: (yok)
- Produces: (yok — platform yapılandırması)

- [ ] **Step 1: Şemayı tanımla**

`ios/Runner/Info.plist` içinde `<dict>`'in altına ekle:

```xml
	<!-- Widget'a dokununca acilan adres (EzanVaktiWidget.swift, widgetURL).
	     Sema tanimli olmadan iOS adresi uygulamaya teslim etmiyor. -->
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string>com.ekrembulbul.ezanvakti</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>ezanvakti</string>
			</array>
		</dict>
	</array>
```

- [ ] **Step 2: Plist'in geçerliliğini doğrula**

Run: `plutil -lint ios/Runner/Info.plist`
Expected: `ios/Runner/Info.plist: OK`

- [ ] **Step 3: Derlemeyi doğrula**

Run: `flutter build ios --no-codesign 2>&1 | tail -3`
Expected: `✓ Built build/ios/iphoneos/Runner.app`

- [ ] **Step 4: Commit**

```bash
git add ios/Runner/Info.plist
git commit -m "fix: widget'in actigi ezanvakti:// semasi tanimli degildi

widgetURL bu adresi veriyordu ama Info.plist'te hicbir yerde kayitli
olmadigi icin iOS adresi uygulamaya teslim etmiyordu."
```

- [ ] **Step 5: Belirtinin geçip geçmediğini cihazda ölç**

Kullanıcı bildirimi: widget'a dokununca uygulama açılıyor ama "sağdan bir ekran geliyormuş gibi" bir geçiş oluyor.

**Sebebi doğrulanmadı.** Elenen iki ihtimal:
- `AppRoot` route push etmiyor, widget'ları yerinde değiştiriyor (`app_root.dart:60-69`) — Flutter route animasyonu değil.
- `MaterialApp` `home:` kullanıyor, başlangıçta geçiş yok (`main.dart:72`).

Şema tanımı belirtiyi çözerse iş biter. **Çözmezse burada tahmin yürütme:** `superpowers:systematic-debugging` ile ayrı bir oturumda ele al. Kayda değer ilk ölçüm: uygulama tamamen kapalıyken mi, arka plandayken mi, yoksa her ikisinde de mi oluyor.

---

### Task 12: Varsayılan alarm sesi

Widget'tan bağımsız. Spec kapsamı dışında; kullanıcı onayıyla ayrıca uygulanır.

**Files:**
- Modify: `lib/core/models/alarm.dart:62,121`
- Modify: `lib/presentation/screens/alarm_edit_screen.dart:532-578`
- Test: `test/alarms/alarm_sound_test.dart`

**Interfaces:**
- Consumes: (yok)
- Produces: `Alarm.soundId` varsayılanı `'default'`

- [ ] **Step 1: Write the failing test**

`test/alarms/alarm_sound_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/models/alarm.dart';

void main() {
  group('Alarm ses varsayilani', () {
    test('yeni alarm sistem varsayilan sesini kullanir', () {
      final alarm = Alarm(id: 'a1', hour: 5, minute: 0);
      expect(alarm.soundId, 'default');
    });

    /// Projede hic ses dosyasi yok; 'adhan' ve 'alarm' zaten sessizce sistem
    /// varsayilanina dusuyordu (AppDelegate.swift:415-418). Secenekler
    /// kaldirildigi icin kayitli degerler de esleniyor, yoksa secicide
    /// "Ozel ses" diye gorunurlerdi.
    test('kayitli adhan degeri varsayilana eslenir', () {
      final alarm = Alarm.fromMap({
        'id': 'a1',
        'hour': 5,
        'minute': 0,
        'sound_id': 'adhan',
      });
      expect(alarm.soundId, 'default');
    });

    test('kayitli alarm degeri varsayilana eslenir', () {
      final alarm = Alarm.fromMap({
        'id': 'a1',
        'hour': 5,
        'minute': 0,
        'sound_id': 'alarm',
      });
      expect(alarm.soundId, 'default');
    });

    test('kullanicinin sectigi ozel ses korunur', () {
      final alarm = Alarm.fromMap({
        'id': 'a1',
        'hour': 5,
        'minute': 0,
        'sound_id': 'custom:ezan.caf',
      });
      expect(alarm.soundId, 'custom:ezan.caf');
    });
  });
}
```

⚠️ `Alarm` kurucusunun zorunlu alanları bu testtekinden farklıysa (`lib/core/models/alarm.dart:40-75`), testi gerçek imzaya uyarla — varsayılan `soundId` beklentisi değişmez.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/alarms/alarm_sound_test.dart`
Expected: FAIL — `Expected: 'default'  Actual: 'adhan'`

- [ ] **Step 3: Modeli güncelle**

`lib/core/models/alarm.dart`'ta varsayılanı değiştir (satır 62 civarı):

```dart
    this.soundId = 'default',
```

Ve `fromMap`'te eski değerleri eşle (satır 121 civarı):

```dart
      soundId: _migrateSoundId(map['sound_id'] as String?),
```

Sınıfın altına ekle:

```dart
/// Projede hiçbir ses dosyası yok; `adhan` ve `alarm` zaten sessizce sistem
/// varsayılanına düşüyordu (`AppDelegate.swift:415-418`). Seçenekler
/// seçiciden kaldırıldığı için kayıtlı değerler de eşleniyor — yoksa eski
/// alarmlar seçicide "Özel ses" diye görünürdü.
String _migrateSoundId(String? stored) {
  if (stored == null || stored.isEmpty) return 'default';
  if (stored == 'adhan' || stored == 'alarm') return 'default';
  return stored;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/alarms/alarm_sound_test.dart`
Expected: PASS (4 test)

- [ ] **Step 5: Seçiciden çalışmayan seçenekleri kaldır**

`lib/presentation/screens/alarm_edit_screen.dart`'ta `_soundSelector`'ı şununla değiştir:

```dart
  /// Seçicide yalnızca gerçekten farklı ses üreten seçenekler durur.
  /// `Ezan` ve `Alarm sesi` kaldırıldı: projede ses dosyası olmadığı için
  /// ikisi de sistem varsayılanına düşüyordu. Çalışmayan bir seçenek,
  /// olmayan seçenekten kötüdür. Gerçek bir ezan kaydı bundle'a girdiğinde
  /// seçenek geri gelir.
  Widget _soundSelector() {
    final isCustom = _soundId.startsWith('custom:');
    return OptionRow<String>(
      label: 'Ses',
      selected: _soundId,
      valueLabel: (v) => switch (v) {
        'default' => 'Varsayılan',
        _ => _customSoundName ?? 'Özel ses',
      },
      items: [
        const OptionItem(
          value: 'default',
          label: 'Varsayılan',
          icon: Icons.volume_up_rounded,
        ),
        if (isCustom)
          OptionItem(
            value: _soundId,
            label: _customSoundName ?? 'Özel ses',
            icon: Icons.audiotrack_rounded,
          ),
        const OptionItem(
          value: _pickSoundValue,
          label: 'Cihazdan ses seç…',
          icon: Icons.library_music_outlined,
        ),
      ],
      onChanged: (v) {
        if (v == _pickSoundValue) {
          _pickCustomSound();
          return;
        }
        setState(() => _soundId = v);
      },
    );
  }
```

- [ ] **Step 6: Tüm Dart testlerini çalıştır**

Run: `flutter analyze && flutter test`
Expected: analiz temiz, tüm testler PASS

- [ ] **Step 7: Commit**

```bash
git add lib/core/models/alarm.dart lib/presentation/screens/alarm_edit_screen.dart test/alarms/alarm_sound_test.dart
git commit -m "fix: alarm ses seciciondeki uc secenek ayni sesi caliyordu

Projede hicbir ses dosyasi yok; Ezan, Alarm sesi ve Varsayilan ucu de sistem
varsayilanina dusuyordu (AppDelegate.swift:415-418). Etiketler yalan
soyluyordu.

Calismayan iki secenek kaldirildi, varsayilan 'default' oldu ve kayitli
degerler eslendi. Ezan secenegi gercek bir kayit bundle'a girdiginde geri
gelir."
```

---

### Task 13: Cihaz doğrulaması, dokümantasyon ve sürüm

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `CHANGELOG.md`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Cihazda doğrula**

⚠️ `StaticConfiguration` → `AppIntentConfiguration` geçişi, kurulu widget'ların sıfırlanmasına yol açabilir. Widget ekranda kaybolursa yeniden eklenmeli — hata değil.

1. Ana ekrana small ve medium ekle; tarih, hicri tarih ve konumun üstte küçük, geri sayımın altta baskın olduğunu gör
2. Widget'a uzun bas → **Widget'ı Düzenle** → hizalamayı ortaya ve sağa al, ikisinin de uygulandığını gör
3. Kilit ekranına dikdörtgen ekle; "SIRADAKİ"nin gitmiş, geri sayımın büyümüş olduğunu gör
4. **Always-On'da geri sayımın `5:34:--` biçiminde olduğunu doğrula** — R5'in ölçümü
5. Yatsı'dan sonra medium'da sol ve sağ sütunun aynı günü gösterdiğini ve "YARIN" yazdığını gör
6. Açık temada zeminin düz beyaz değil, paletin tonunda olduğunu gör
7. Widget'a dokun; uygulamanın açılışında "sağdan ekran gelmesi" belirtisinin geçip geçmediğini not et (Task 11 Step 5)
8. Alarm ekranında ses seçicisinde yalnızca "Varsayılan" ve "Cihazdan ses seç…" olduğunu gör

4. madde olumsuzsa `CountdownLabel`'daki `isLuminanceReduced` dallanması çalışmıyordur; spec R5'e göre her yerde kendi çizimimize geçilir.

- [ ] **Step 2: ARCHITECTURE.md'yi güncelle**

"Veri akışı — iOS widget" bölümündeki madde listesine ekle:

```markdown
- Payload'da her gün kendi **hicri tarihini** taşır. Swift'te hesaplanmaz:
  iOS'un `islamicUmmAlQura` takvimi uygulamanın kullandığı `hijri` paketinden
  gün kayabilir.
- Timeline **dakika başına** giriş üretir (2 saatlik pencere). Always-On
  ekranda geri sayımı `CountdownText` ile kendimiz çizeriz; sistemin canlı
  sayacı orada okunmaz bir biçime düşüyor.
- Hizalama `AppIntentConfiguration` ile widget ayarıdır.
```

- [ ] **Step 3: CHANGELOG ve sürüm**

`pubspec.yaml`: `version: 0.5.0+26` → `version: 0.5.1+27`

`CHANGELOG.md` başına:

```markdown
## [0.5.1] - 2026-08-29

### Eklendi
- Widget'lara **tarih**: gün adı, miladi tarih ve hicri tarih. Hicri tarih uygulamanın hesabıyla birebir aynı.
- Widget'a **hizalama ayarı**: sola yaslı, ortalı veya sağa yaslı. Widget'a uzun basıp "Widget'ı Düzenle" ile seçiliyor.
- Sıradaki vakit ertesi güne aitse widget artık **"YARIN"** yazıyor.

### Düzeltildi
- **Orta boy widget iki farklı günü gösteriyordu:** Yatsı'dan sonra soldaki vakit yarına, sağdaki liste bugüne aitti ve listede hiçbir satır vurgulanmıyordu.
- **Kilit ekranı kapalıyken (Always-On) geri sayım** "5 hours 51 minutes" gibi okunmaz bir biçime düşüyordu; artık `5:34:--` yazıyor.
- Açık temada widget zemini düz beyaz kart gibi görünüyordu.
- Widget'a dokununca açılan adres uygulamada tanımlı değildi.
- **Alarm ses seçicisindeki üç seçenek aynı sesi çalıyordu.** Projede ses dosyası olmadığı için "Ezan" ve "Alarm sesi" de sistem varsayılanına düşüyordu; çalışmayan iki seçenek kaldırıldı.

### Değişti
- Widget'lar dikeyde yeniden düzenlendi: tarih ve konum üstte küçük, vakit ve geri sayım altta baskın. Alt boşluklar kapandı.
- Kilit ekranı widget'ından "SIRADAKİ" etiketi kalktı, geri sayım büyüdü.
- Saatin üstündeki tek satırlık (inline) kilit ekranı widget'ı kaldırıldı.
```

- [ ] **Step 4: Son doğrulama**

```bash
flutter analyze && flutter test
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "TEST " | tail -2
flutter build ios --no-codesign 2>&1 | tail -2
```
Expected: üçü de temiz

- [ ] **Step 5: Commit**

```bash
git add docs/ CHANGELOG.md pubspec.yaml
git commit -m "docs: widget ikinci turu icin dokumantasyon ve 0.5.1 surumu"
```

---

## Notlar

**Sıra bağımlılıkları:** Task 1–2 payload sözleşmesini kurar, 3–4 saf biçimlendiricileri, 5 timeline'ı, 6 hizalamayı. Görünümler (8–10) bunların hepsine dayanır; Task 5'ten sonra Task 10 bitene kadar `flutter build ios` geçici olarak kırık kalır — testler bu aralıkta da geçer. Task 11 ve 12 bağımsız, herhangi bir sırada yapılabilir.

**Elle yapılacak işler:** Task 13 Step 1 (cihaz testi). Portal ya da secret işi yok; imzalama altyapısı 0.5.0'da kuruldu.

**Bilinen belirsizlikler:** Task 4 Step 3 (`setLocalizedDateFormatFromTemplate` çıktısı), Task 11 Step 5 (derin bağlantı belirtisinin sebebi), Task 13 Step 1 madde 4 (`isLuminanceReduced` davranışı). Üçünde de alternatif adımda yazılı.
