# Android Widget Turu Uygulama Planı

> **For agentic workers:** CLAUDE.md orchestrator düzeniyle yürütülür (seri `subagent-driven-development` yok). Alt-agent'lar build/test/codegen/commit koşmaz; "Çalıştır" satırlarını ana oturum Task 9'da koşar. Adımlar `- [ ]`.

**Goal:** Android'de bildirim çubuğunda sabit "sıradaki vakit" satırı ve ana ekran widget'ı (küçük/orta); iOS küçük/orta widget'ı aynı yeni tasarıma.

**Architecture:** Dart, snapshot'a 7 günlük zaman çizelgesini (her değişim anında sıradaki vakit, kerahat durumu, gün dilimi), günlerin epoch'larını, tarih metinlerini ve cetvel parçalarını ekler (şema 4, eklemeli). Kotlin çekirdeği bu JSON'u ayrıştırır, o anki girişi seçer, paleti çözer, cetveli ve zemini bitmap olarak çizer; widget ve sabit satır `RemoteViews` ile çizilir, `Chronometer`/`TextClock` canlı akar. iOS SwiftUI görünümleri yeni tasarıma geçer, mevcut çizelge mantığı kalır.

**Tech Stack:** Flutter/Dart (home_widget 0.9.3), Kotlin (SDK 36, minSdk 24, RemoteViews), SwiftUI/WidgetKit (iOS 17+), JUnit 4, XCTest.

**Spec:** `docs/superpowers/specs/2026-10-08-android-widget-design.md`

## Global Constraints

- Snapshot `schemaVersion` **4** kalır; yeni alanlar eklemeli ve opsiyonel okunur.
- SharedPreferences adı (home_widget): `HomeWidgetPreferences`. Anahtarlar: `ezanvakti_snapshot`, `ezanvakti_appearance`, `ezanvakti_time_format`, `ezanvakti_next_prayer_notification` (`"true"`/`"false"`).
- Android sağlayıcı sınıfı: `com.ekrembulbul.ezanvakti.widget.EzanWidgetProvider`; Kotlin paketi `com.ekrembulbul.ezanvakti.widget`.
- Sabit satır kanalı `ezan_vakti_next_prayer`, bildirim kimliği `9930001`.
- Kerahat kuralı: `KerahatWarning.lead` 30 dk; metinler snapshot `labels.kerahatSoon` ("Kerahate") ve `labels.kerahat` ("Kerahat").
- Boyutlar (dp/pt): küçük widget kenar 14; vakit adı/saat 11/16 (küçük), 11/18 (orta), 13/19 (sabit satır); sayaç 34 (küçük), 28 (orta), 30 (sabit satır).
- Renkler iOS `Palette.swift` ile birebir; kerahat: koyu `#A14158`/`#3C1F2A`, açık `#8D243B`/`#F9E9EC`; yaklaşırken koyu `#E0832E`/`#3B2412`/`#FFB45C`, açık `#C9681C`/`#FDEFE1`/`#A9540E`.
- Yeni Flutter paketi yok; yeni Gradle bağımlılığı yok.
- Kullanıcı metni Dart'ta ARB'den, Android'de `values{,-tr,-ar}/strings.xml`'den.

## Review Focus

1. Gece yarısını aşan an (Yatsı sonrası): sıradaki vakit ertesi günün İmsak'ı, `tomorrow` doğru, gösterilen gün ertesi gün — Task 2 testi.
2. Çizelgenin son girişinden sonra (uygulama 7+ gün açılmadı): widget soluk "Güncel değil", sabit satır kalkar, çökme yok — Task 3 `isStale` testi.
3. Bozuk ya da eksik payload (eski uygulama, boş prefs): widget "uygulamayı aç", sabit satır yok — Task 3 ayrıştırıcı testi.
4. Kerahat aralığı başlangıç−30'u bir vakit anıyla çakışıyor (öğle kerahati 10 dk): anlar tekil, durum doğru — Task 2 testi.
5. 12 saat biçimi ve Arapça arayüz: saatler "12:57 PM" ya da tercih; tarih metinleri uygulamanın dilinde — Task 3 biçim testi, Task 2 metin testi.

## Yürütme düzeni

| Faz | Task | Kim |
|---|---|---|
| 0 | 1 Ortak kaynaklar (ARB, Android string, manifest, widget info, ayar alanı, yayıncı/DI) · 3 Kotlin çekirdeği | Ana oturum |
| 1 (paralel) | 2 Dart veri sözleşmesi + ayar satırı | Ana oturum |
| | 4 Android widget (renderer, sağlayıcı, ayar ekranı, layout'lar) | Agent A — `opus-high-worker` |
| | 5 Sabit satır (bildirim, kaydırma alıcısı, layout'lar) | Agent B — `opus-high-worker` |
| | 6 iOS widget yenilemesi | Agent C — `opus-high-worker` |
| 2 | 7 Entegrasyon testleri · 8 Emülatör/simülatör · 9 Doğrulama, ADR, commit'ler | Ana oturum |

## Veri sözleşmesi (Task 2 üretir; Task 3 ve 6 tüketir)

```json
{
  "schemaVersion": 4,
  "locationLabel": "İstanbul (Merkez)",
  "generatedAt": "2026-10-08T12:42:00",
  "labels": { "fajr": "İmsak", "...": "...", "tomorrow": "Yarın", "stale": "Güncel değil",
              "openApp": "Vakitler için uygulamayı aç", "updateApp": "...", "kerahat": "Kerahat", "kerahatSoon": "Kerahate" },
  "days": [{
    "date": "2026-10-08",
    "hijri": "27 Rebiülahir 1448",
    "times": { "fajr": "05:36", "sunrise": "07:01", "dhuhr": "12:57", "asr": "16:08", "maghrib": "18:43", "isha": "20:02" },
    "kerahat": [{ "start": "07:01", "end": "07:46" }, { "start": "12:47", "end": "12:57" }, { "start": "17:58", "end": "18:43" }],
    "weekday": "Perşembe",
    "dateLabel": "8 Ekim",
    "hijriShort": "27 Rebiülahir",
    "epochs": { "fajr": 1791427000000, "sunrise": 1791432060000, "dhuhr": 1791453420000, "asr": 1791464880000, "maghrib": 1791473980000, "isha": 1791478920000 },
    "ruler": {
      "segments": [{ "start": 0.0, "end": 0.2333, "kind": "night", "gapBefore": false, "gapAfter": true }],
      "marks": [0.2333, 0.2924, 0.5396, 0.6722, 0.7799, 0.8347]
    }
  }],
  "timeline": [
    { "at": 1791452520000, "day": 0, "slot": 2, "tomorrow": false, "phase": "morning",
      "kerahat": { "state": "approaching", "start": 1791452820000, "end": 1791453420000 } }
  ]
}
```
- `slot`: 0 İmsak, 1 Güneş, 2 Öğle, 3 İkindi, 4 Akşam, 5 Yatsı. `day`: `days` indeksi. Bir giriş, bir sonraki girişin `at`'ına kadar geçerlidir; son giriş, gösterdiği vaktin epoch'una kadar.
- `phase`: `morning|afternoon|evening|night`. `kind`: `day|night|kerahat`. `kerahat` yoksa `null`.

---

### Task 1: Ortak kaynaklar (ana oturum, faz 0)

**Files:** `lib/l10n/app_{tr,en,ar}.arb` (+gen-l10n), `android/app/src/main/res/values{,-tr,-ar}/strings.xml`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/ezan_widget_info.xml`, `lib/core/models/general_settings.dart`, `lib/features/prayer_times/data/sqlite_storage.dart`, `lib/core/interfaces/widget_publisher.dart`, `lib/features/home_widget/data/home_widget_publisher.dart`, `lib/core/di/service_locator.dart`, `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmBootReceiver.kt`, testler `test/models/general_settings_next_prayer_test.dart`, `test/home_widget/home_widget_publisher_test.dart`.

**Produces:** ARB `prefsNextPrayerNotification` ("Bildirim çubuğunda sıradaki vakit"/"Next prayer in the notification bar"/"الصلاة القادمة في شريط الإشعارات"), `prefsNextPrayerNotificationHint` ("Kilit ekranında da görünür."/"Also shown on the lock screen."/"يظهر أيضًا على شاشة القفل."). Android string'ler: `next_prayer_channel_name` (Sıradaki vakit / Next prayer / الصلاة القادمة), `widget_config_title` (Hizalama / Alignment / المحاذاة), `widget_align_start` (Sola yaslı / Left / يسار), `widget_align_center` (Ortalı / Centered / وسط), `widget_align_end` (Sağa yaslı / Right / يمين), `widget_config_save` (Kaydet / Save / حفظ), `widget_description` (Sıradaki vakit ve geri sayım / Next prayer and countdown / الصلاة القادمة والعد التنازلي), `widget_open_app` (Vakitler için uygulamayı aç / Open the app for prayer times / افتح التطبيق لعرض المواقيت). `GeneralSettings.nextPrayerNotification` (bool, varsayılan `true`, anahtar `general_next_prayer_notification`). `WidgetPublisher.publishNextPrayerNotification(bool enabled)`. `HomeWidgetPublisher.androidProvider = 'com.ekrembulbul.ezanvakti.widget.EzanWidgetProvider'`.

- [ ] ARB + `flutter gen-l10n`; Android string'ler üç dilde.
- [ ] Manifest: `<receiver android:name=".widget.EzanWidgetProvider" android:exported="false" android:label="@string/app_name"><intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE"/></intent-filter><meta-data android:name="android.appwidget.provider" android:resource="@xml/ezan_widget_info"/></receiver>`, `<activity android:name=".widget.WidgetConfigActivity" android:exported="true" android:theme="@android:style/Theme.DeviceDefault.Dialog.NoActionBar"><intent-filter><action android:name="android.appwidget.action.APPWIDGET_CONFIGURE"/></intent-filter></activity>`, `<receiver android:name=".widget.SurfaceRefreshReceiver" android:exported="false"/>`, `<receiver android:name=".widget.NextPrayerDismissReceiver" android:exported="false"/>`.
- [ ] `ezan_widget_info.xml`:
```xml
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="110dp" android:minHeight="110dp"
    android:targetCellWidth="2" android:targetCellHeight="2"
    android:minResizeWidth="110dp" android:minResizeHeight="110dp"
    android:maxResizeWidth="420dp" android:maxResizeHeight="220dp"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="0"
    android:initialLayout="@layout/widget_small"
    android:previewLayout="@layout/widget_small"
    android:description="@string/widget_description"
    android:configure="com.ekrembulbul.ezanvakti.widget.WidgetConfigActivity"
    android:widgetFeatures="reconfigurable|configuration_optional"
    android:widgetCategory="home_screen" />
```
- [ ] `GeneralSettings` alanı (copyWith/toMap/fromMap/==/hashCode; `'true'`/`'false'`, bozuk → varsayılan) + `sqlite_storage.dart` `getGeneralSettings` anahtar listesine ekle. Test: varsayılan true, `'false'` okunur, bozuk → true.
- [ ] `WidgetPublisher.publishNextPrayerNotification`; `HomeWidgetPublisher`: her `updateWidget` çağrısı `HomeWidget.updateWidget(iOSName: widgetKind, qualifiedAndroidName: androidProvider)`; yeni yöntem anahtarı `"true"/"false"` yazar ve günceller; `NoopWidgetPublisher` boş. DI: `Platform.isIOS || Platform.isAndroid ? HomeWidgetPublisher(...) : const NoopWidgetPublisher()`. Mevcut yayıncı testi sahte kanalla yeni argümanı doğrular.
- [ ] `AlarmBootReceiver.onReceive` sonuna `com.ekrembulbul.ezanvakti.widget.SurfaceRefresher.refreshAll(context)` (try/catch, log).

### Task 2: Dart veri sözleşmesi ve ayar satırı (ana oturum, faz 1)

**Files:** Create `lib/features/prayer_times/domain/day_ruler_math.dart`, `lib/features/home_widget/domain/widget_timeline_builder.dart`; Modify `lib/presentation/widgets/home/day_ruler.dart`, `lib/features/home_widget/domain/widget_snapshot.dart`, `widget_snapshot_builder.dart`, `lib/core/utils/hijri_formatter.dart`, `lib/presentation/widgets/settings/notification_prefs_section.dart`, `lib/presentation/pages/home_page.dart` (gerekirse `now`/l10n), Tests `test/home_widget/widget_timeline_builder_test.dart`, `test/home_widget/widget_snapshot_builder_test.dart`, `test/home_widget/widget_snapshot_test.dart`, `test/core/hijri_formatter_test.dart`, `test/widgets/settings/notification_prefs_next_prayer_test.dart`.

**Produces:** Veri sözleşmesindeki JSON.

- [ ] `day_ruler_math.dart`'a `RulerSegmentKind`, `RulerRange`, `RulerSegment`, `buildRulerSegments`, `dayProgress` taşı (kod aynen); `day_ruler.dart` import eder; mevcut cetvel testleri yeni yerden import eder.
- [ ] Failing test (`widget_timeline_builder_test.dart`, `prayerTimeFor` yardımcısıyla):
```dart
test('her an sıradaki vakti, günü ve kerahat durumunu taşır', () {
  final days = [prayerTimeFor(DateTime(2026, 10, 8)), prayerTimeFor(DateTime(2026, 10, 9))];
  final entries = WidgetTimelineBuilder.build(days: days, now: DateTime(2026, 10, 8, 12, 42));
  final first = entries.first;
  expect(first.at, DateTime(2026, 10, 8, 12, 42));
  expect((first.day, first.slot, first.tomorrow), (0, 2, false));
  final afterIsha = entries.firstWhere((e) => e.at == days[0].isha);
  expect((afterIsha.day, afterIsha.slot, afterIsha.tomorrow), (1, 0, true));
  final noonStart = KerahatTimes.forDay(days[0]).firstWhere((i) => i.end == days[0].dhuhr).start;
  final approaching = entries.firstWhere((e) => e.at == noonStart.subtract(const Duration(minutes: 30)));
  expect(approaching.kerahat?.state, WidgetKerahatState.approaching);
  expect(entries.firstWhere((e) => e.at == noonStart).kerahat?.state, WidgetKerahatState.active);
});
test('anlar sıralı ve tekil; ilk an şimdi, son giriş son vakitten önce', () {
  final days = [prayerTimeFor(DateTime(2026, 10, 8))];
  final entries = WidgetTimelineBuilder.build(days: days, now: DateTime(2026, 10, 8, 3));
  final ats = entries.map((e) => e.at).toList();
  expect(ats, [...ats]..sort());
  expect(ats.toSet().length, ats.length);
  expect(entries.last.at.isBefore(days[0].isha), isTrue);
});
test('gece yarısı anı çizelgede yer alır; gece dilimi sürer', () {
  final days = [prayerTimeFor(DateTime(2026, 10, 8)), prayerTimeFor(DateTime(2026, 10, 9))];
  final entries = WidgetTimelineBuilder.build(days: days, now: DateTime(2026, 10, 8, 23, 30));
  final midnight = entries.firstWhere((e) => e.at == DateTime(2026, 10, 9));
  expect(midnight.phase, DayPhase.night);
  expect((midnight.day, midnight.slot, midnight.tomorrow), (1, 0, false));
  expect(entries.first.tomorrow, isTrue);
});
```
- [ ] `WidgetTimelineBuilder.build({required List<PrayerTime> days, required DateTime now}) → List<WidgetTimelineEntry>`: günler tarihe göre sıralı (snapshot'taki gibi en fazla 7, bugünden). Slotlar = günler × 6 vakit (sıralı). Anlar = `{now}` ∪ slot zamanları ∪ her gün `KerahatTimes.forDay` aralıkları için (start−`KerahatWarning.lead`, start, end) ∪ ikinci günden itibaren gün başları; `now`'dan önce olanlar atılır; son slot zamanına eşit/sonraki anlar atılır. Her an `t`: `next` = zamanı `t`'den büyük ilk slot (yoksa giriş üretilmez); `day` = next'in gün indeksi; `tomorrow` = next'in günü `t`'nin takvim gününden farklı; `kerahat` = `KerahatWarning.resolve(tüm aralıklar, t)` → `WidgetTimelineKerahat(state, start, end)`; `phase` = `resolveDayPhase(today: t'nin günü, tomorrow: ertesi gün, now: t)`.
- [ ] `widget_snapshot.dart`: `WidgetTimelineEntry {DateTime at; int day; int slot; bool tomorrow; DayPhase phase; WidgetTimelineKerahat? kerahat; toJson()}`, `enum WidgetKerahatState { approaching, active }`, `WidgetTimelineKerahat {state, start, end; toJson()}`, `WidgetRuler {List<RulerSegment> segments; List<double> marks; toJson()}` (sayılar 4 ondalık), `WidgetSnapshotDay`'e `weekday`, `dateLabel`, `hijriShort`, `epochs`, `ruler`; `WidgetSnapshot`'a `timeline`. `at`/`start`/`end`/`epochs` `millisecondsSinceEpoch`.
- [ ] `WidgetSnapshotBuilder.build`: günlere `weekday = DateFormat.EEEE(locale)`, `dateLabel = DateFormat.MMMMd(locale)` (TR: "8 Ekim"), `hijriShort = HijriFormatter.formatHijriShort`, cetvel = `buildRulerSegments(prayerFractions: 6 vakit dayProgress, dayStart: fajr, dayEnd: maghrib, kerahatRanges: KerahatTimes)`; `marks` = 6 oran. Locale `l10n.localeName`, yoksa `tr`. Kök `timeline = WidgetTimelineBuilder.build(days: alınan günler, now: now)`.
- [ ] `HijriFormatter.formatHijriShort(HijriDate, [AppLocalizations?])` → "27 Rebiülahir" (ay adı mevcut özel yardımcıdan). Test.
- [ ] `NotificationPrefsSection`: `showNextPrayerNotification ?? Platform.isAndroid` iken Divider + anahtar satırı (`_switchRow` kalıbı) `prefsNextPrayerNotification`/`Hint`; `onChanged` → `_update(..copyWith(nextPrayerNotification: v))` ve `ServiceLocator().get<WidgetPublisher>().publishNextPrayerNotification(v)`. Açılışta değer yayınlansın: `home_page` widget yayınından hemen sonra `publishNextPrayerNotification(appState.generalSettings.nextPrayerNotification)`.
- [ ] Testler: snapshot JSON alanları, timeline JSON biçimi (`"state": "approaching"`), hicri kısa, ayar satırı görünür/gizli ve yayın çağrısı.

### Task 3: Kotlin çekirdeği (ana oturum, faz 0)

**Files:** Create `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/widget/{WidgetSnapshotModel.kt, WidgetTimeline.kt, WidgetPalette.kt, WidgetTimeFormat.kt, RulerBitmap.kt, BackgroundBitmap.kt, WidgetStore.kt, SurfaceRefresher.kt, SurfaceRefreshReceiver.kt}`; tests `android/app/src/test/kotlin/com/ekrembulbul/ezanvakti/widget/{WidgetSnapshotModelTest.kt, WidgetTimelineTest.kt, WidgetPaletteTest.kt, WidgetTimeFormatTest.kt}`.

**Produces (Task 4 ve 5 tüketir):**
```kotlin
enum class SlotKey { FAJR, SUNRISE, DHUHR, ASR, MAGHRIB, ISHA }
data class WidgetSlot(val key: SlotKey, val name: String, val epochMillis: Long)
data class RulerPart(val start: Float, val end: Float, val kind: Kind, val gapBefore: Boolean, val gapAfter: Boolean) { enum class Kind { DAY, NIGHT, KERAHAT } }
data class WidgetDay(val date: String, val weekday: String?, val dateLabel: String?, val hijri: String?, val hijriShort: String?, val slots: List<WidgetSlot>, val ruler: List<RulerPart>, val marks: List<Float>)
data class KerahatWindow(val active: Boolean, val startMillis: Long, val endMillis: Long) { val targetMillis: Long get() = if (active) endMillis else startMillis }
enum class Phase { MORNING, AFTERNOON, EVENING, NIGHT }
data class TimelineEntry(val atMillis: Long, val dayIndex: Int, val slotIndex: Int, val tomorrow: Boolean, val phase: Phase, val kerahat: KerahatWindow?)
data class WidgetLabels(val tomorrow: String, val stale: String, val openApp: String, val kerahat: String, val kerahatSoon: String)
data class WidgetSnapshot(val locationLabel: String, val days: List<WidgetDay>, val timeline: List<TimelineEntry>, val labels: WidgetLabels)
sealed interface SnapshotResult { data class Ok(val snapshot: WidgetSnapshot) : SnapshotResult; data object NoData : SnapshotResult }
object WidgetSnapshotParser { fun parse(json: String?): SnapshotResult }
data class WidgetState(val entry: TimelineEntry, val day: WidgetDay, val next: WidgetSlot, val stale: Boolean)
object WidgetTimeline { fun state(snapshot: WidgetSnapshot, now: Long): WidgetState?; fun nextBoundary(snapshot: WidgetSnapshot, now: Long): Long? }
data class WidgetAppearance(val themeMode: String, val timeBasedColor: Boolean, val fixedPalette: Phase) { companion object { val FALLBACK: WidgetAppearance; fun parse(json: String?): WidgetAppearance } }
data class Palette(val accent: Int, val textPrimary: Int, val textSecondary: Int, val stops: IntArray, val isDark: Boolean) { val kerahatLine: Int; val kerahatSurface: Int; val soonLine: Int; val soonSurface: Int; val soonText: Int; val kerahatText: Int; val divider: Int; val night: Int; val tick: Int }
object WidgetPalette { fun resolve(appearance: WidgetAppearance, phase: Phase, systemDark: Boolean): Palette }
object WidgetTimeFormat { fun pattern(preference: String?, system24: Boolean): String; fun format(epochMillis: Long, preference: String?, system24: Boolean, locale: java.util.Locale): String }
object RulerBitmap { fun draw(widthPx: Int, density: Float, parts: List<RulerPart>, marks: List<Float>, nowFraction: Float?, palette: Palette): android.graphics.Bitmap; const val HEIGHT_DP = 22f; fun dotCenterPx(widthPx: Int, nowFraction: Float): Float }
object BackgroundBitmap { fun draw(widthPx: Int, heightPx: Int, radiusPx: Float, stops: IntArray): android.graphics.Bitmap }
object WidgetStore { fun snapshotJson(c: Context): String?; fun appearanceJson(c: Context): String?; fun timeFormat(c: Context): String?; fun notificationEnabled(c: Context): Boolean; fun alignment(c: Context, widgetId: Int): Int; fun setAlignment(c: Context, widgetId: Int, value: Int); fun removeAlignment(c: Context, widgetId: Int) }  // 0 sola, 1 orta (varsayılan), 2 sağa
object SurfaceRefresher { fun refreshAll(context: Context) }
```
`SurfaceRefresher.refreshAll`: `EzanWidgetProvider.updateAll(context)` (Task 4) ve `NextPrayerNotification.update(context)` (Task 5) çağırır (her biri ayrı try/catch); `WidgetTimeline.nextBoundary`'ye `RTC_WAKEUP` kesin alarm (`canScheduleExactAlarms` yoksa `setAndAllowWhileIdle`), istek kodu 7401; 15 dk'lık `RTC` `setInexactRepeating`, istek kodu 7402 (snapshot yoksa ikisi iptal). Alıcı: `SurfaceRefreshReceiver` → `refreshAll`.

- [ ] Failing Kotlin testleri: ayrıştırıcı (sözleşme JSON'u → alanlar; `null`/bozuk → `NoData`; eksik `timeline` → `NoData`; tek bozuk gün atlanır); zaman çizelgesi (giriş seçimi, son girişten sonra slot epoch'una kadar geçerli, sonra `stale=true` ve son giriş; boş çizelge → null; `nextBoundary` = sonraki `at` ya da son slot epoch'u); palet (koyu/açık, `system`, sabit palet, iOS değerleri örnek: koyu sabah accent `0xFF93C4E8`, açık gece stops[0] `0xFFD6C8E4`); saat biçimi (`h24` → `HH:mm`, `h12` → `h:mm a`, `system` → system24'e göre).
- [ ] Uygulama: `org.json` ile; palet değerleri `Palette.swift`'ten birebir; `divider` = textSecondary α .4 (koyu)/.3 (açık), `night` = textSecondary α .4, `tick` = textSecondary α .7. Bitmap'ler: cetvel yüksekliği 22 dp (üstte 0 — saat etiketi layout'ta), yatak 5 dp, çentik 2×7 dp yatağın 2 dp altında, boşluk 3 px, nokta 14 dp accent halka/iç; zemin radyal gradyan merkez (0.70w, −0.04h), yarıçap kısa kenar×1.25, duraklar 0/0.44/1, köşe yarıçapı verilen.
- [ ] Çalıştır (Task 9): `./gradlew :app:testDebugUnitTest`.

### Task 4: Android widget (Agent A)

**Files:** Create `widget/WidgetRenderer.kt`, `widget/EzanWidgetProvider.kt`, `widget/WidgetConfigActivity.kt`, `res/layout/widget_small.xml`, `res/layout/widget_medium.xml`, `res/layout/widget_message.xml`, `res/layout/widget_config.xml`; test `widget/WidgetRendererModelTest.kt`.

**Consumes:** Task 3 API'leri. **Produces:** `object EzanWidgetProvider.Companion.updateAll(context: Context)` (kurulu bütün widget'ları çizer).

- [ ] Saf sunum modeli (`WidgetViewModel` — `WidgetRenderer.kt` içinde): `from(state, snapshot, palette, timePref, system24, locale, now) → { topText ("İstanbul · 8 Ekim"), nameText (büyük harf; tomorrow ise "YARIN · İMSAK"), timeText, countdownTargetMillis, bottomLines (gün adı, hicri) | kerahat (word, rangeText "12:47 – 12:57", target, active), mediumTopRight ("Perşembe, 8 Ekim · 27 Rebiülahir" ya da kerahat çipi), columns (6 × ad/saat/durum past|next|future), nameColor/countdownColor (kerahatte palette.kerahatText) }`; testler bu model üzerinde (tomorrow öneki, kerahat yaklaşırken/aktif metin ve hedef, geçmiş/sıradaki sütun, stale).
- [ ] `widget_small.xml`: kök `FrameLayout` (arka `ImageView` zemin bitmap'i, `fitXY`) + 14 dp iç boşluklu dikey `LinearLayout`: üst `TextView` 12sp tek satır `ellipsize=end`; orta ağırlıklı blok (ad 11sp bold harf aralığı .07 + saat 16sp medium, aynı satır taban hizalı; altında `Chronometer` 34sp ince `countDown`); alt 34 dp yuva: iki satırlı `TextView` 11sp (gün, hicri) ya da kerahat kartı (`LinearLayout` 34 dp, 12 dp köşe: solda kelime 12sp + aralık 10sp, sağda `Chronometer` 16sp). Hizalamalar `gravity` ile (sola/orta/sağa üç varyant ya da `setInt(id, "setGravity", …)`).
- [ ] `widget_medium.xml`: üst satır (konum sol, sağda tarih `TextView` ya da kerahat çipi 22 dp), vakit satırı (ad 11 + saat 18, sağda `Chronometer` 28), cetvel bloğu (`FrameLayout`: üstte `TextClock` 11sp accent, sol boşluğu nokta merkezine göre `setViewPadding`, altında cetvel `ImageView`), altı sütun (`LinearLayout` ağırlık 1, ad 10sp + saat 12sp; sıradaki için yuvarlak zemin `ImageView`/`setInt setBackgroundColor`).
- [ ] `WidgetRenderer.render(context, widgetId, sizeDp, now): RemoteViews`: snapshot/görünüm/saat tercihini okur, `WidgetTimeline.state`, palet (`Configuration.uiMode` gece), bitmap'ler, `setChronometer(id, SystemClock.elapsedRealtime() + (target - now), null, true)` + `setChronometerCountDown(id, true)`; stale → kök `setFloat("setAlpha", 0.55f)` ve üst metin `labels.stale`; `NoData` → `widget_message` ("Vakitler için uygulamayı aç"). Dokunma: `PendingIntent` → `MainActivity`.
- [ ] `EzanWidgetProvider`: `onUpdate` → her id için çiz; `onAppWidgetOptionsChanged` → yeniden çiz; `onDeleted` → `WidgetStore.removeAlignment`; `onReceive`: `ACTION_APPWIDGET_UPDATE` geldiğinde (id listesi boş olsa da) `SurfaceRefresher.refreshAll(context)` ve `super.onReceive`. API 31+: `RemoteViews(mapOf(SizeF(110f,110f) to small, SizeF(250f,110f) to medium))`; altında `OPTION_APPWIDGET_MIN_WIDTH >= 250` → orta. `updateAll` = `AppWidgetManager.getAppWidgetIds` hepsi.
- [ ] `WidgetConfigActivity`: `RadioGroup` (üç seçenek, mevcut değer işaretli, varsayılan orta), "Kaydet" → `WidgetStore.setAlignment`, `updateAll`, `setResult(RESULT_OK, Intent().putExtra(EXTRA_APPWIDGET_ID, id))`, `finish()`; iptal → `RESULT_CANCELED`.

### Task 5: Sabit satır (Agent B)

**Files:** Create `widget/NextPrayerNotification.kt`, `widget/NextPrayerDismissReceiver.kt`, `res/layout/notification_next_prayer.xml`, `res/layout/notification_next_prayer_expanded.xml`; test `widget/NextPrayerContentTest.kt`.

**Consumes:** Task 3. **Produces:** `object NextPrayerNotification { fun update(context: Context); fun cancel(context: Context) }`.

- [ ] Saf içerik modeli `NextPrayerContent.from(state, snapshot, palette, timePref, system24, locale)`: `subText` (konum ya da kerahat kelimesi), `headerChronometerTarget` (yalnız kerahat penceresinde), `accentColor` (normal palette.accent; yaklaşırken soonLine; kerahatte kerahatLine), sol ad/saat, sağ sayaç hedefi, kart (kelime, aralık, hedef, aktif) ya da yok, sütunlar, cetvel girdileri. Testler: üç durum (normal/yaklaşırken/kerahatte) için başlık, renk ve kart; tomorrow öneki.
- [ ] Layout'lar: kapalı tek satır (sol ad 13sp + saat 19sp, sağ `Chronometer` 30sp, yükseklik ≤ 48 dp); açık: aynı satır + kart (`visibility` kerahatte) + cetvel bloğu (`TextClock` + `ImageView`) + altı sütun; dikey ritim 8/12 (spec taslağı `sabit-satir-son-v2.html`). Metin renkleri sistem bildirim stillerinden (`@android:style/TextAppearance.Material.Notification.*`), vurgu palette'ten.
- [ ] `update`: ayar kapalı, izin yok, `NoData` ya da `stale` → `cancel`. Aksi halde kanal (IMPORTANCE_LOW, ses/titreşim yok, `lockscreenVisibility = PUBLIC`), `NotificationCompat.Builder`: `setSmallIcon(R.drawable.ic_stat_notification)`, `setStyle(DecoratedCustomViewStyle())`, `setCustomContentView`, `setCustomBigContentView`, `setSubText`, kerahatte `setUsesChronometer(true)` + `setChronometerCountDown(true)` + `setWhen(target)` (aksi `setShowWhen(false)`), `setColor`, `setOngoing(true)`, `setOnlyAlertOnce(true)`, `setSilent(true)`, `setCategory(CATEGORY_STATUS)`, içerik `PendingIntent` → `MainActivity`, `setDeleteIntent` → `NextPrayerDismissReceiver`. Kimlik `9930001`.
- [ ] `NextPrayerDismissReceiver`: ayar açıksa `NextPrayerNotification.update(context)` (hemen yeniden).

### Task 6: iOS widget yenilemesi (Agent C)

**Files:** Modify `ios/WidgetCore/WidgetSnapshot.swift` (opsiyonel `weekday`, `dateLabel`, `hijriShort`, `ruler`), `ios/WidgetCore/DayLabel.swift` (payload metnini tercih et), `ios/EzanVaktiWidget/Views/SmallView.swift`, `MediumView.swift`, `WidgetBlocks.swift`; Create `Views/KerahatCard.swift`, `Views/KerahatChip.swift`, `Views/RulerView.swift`; Delete `Views/KerahatRibbon.swift`; Tests `ios/RunnerTests/WidgetSnapshotTests.swift`, `DayLabelTests.swift`, yeni `RulerGeometryTests.swift` (saf geometri `WidgetCore/RulerGeometry.swift`).

- [ ] Payload alanları opsiyonel (`ruler: SnapshotRuler?` → `segments: [SnapshotRulerSegment]`, `marks: [Double]`); eski payload çözülür (test).
- [ ] `DayLabel.gregorian(day)` → `day.weekday + ", " + day.dateLabel` varsa, yoksa mevcut biçim; `short(day)` → `dateLabel` varsa.
- [ ] Küçük (K6): kenar 14; üst "konum · kısa tarih" 12pt `textSecondary`; orta vakit satırı (ad 11 semibold accent büyük harf + saat 16 semibold, taban hizalı) ve `CountdownLabel` 34 light; alt 34pt yuva: kerahat yoksa iki satır 11pt (gün adı, hicri), varsa `KerahatCard` (12pt köşe; kelime 12 semibold + aralık 10, sağda sayaç 16; yaklaşırken `kerahatSoonSurface/Text`, kerahatte `kerahatSurface` + bordo metin). Hizalama ayarı küçükte geçerli (varsayılan `.center`). Kerahatte ad ve sayaç `palette.kerahat` tonuna; zemin değişmez (`isKerahatActive` zemin kayması kaldırılır).
- [ ] Orta (K8): üst satır konum (sol) · sağda `"\(weekday), \(dateLabel) · \(hijriShort)"` ya da kerahat penceresinde `KerahatChip` (22pt kapsül: kelime + sayaç); vakit satırı (11/18) + sağda sayaç 28 light; `RulerView` (payload `ruler`, nokta ve üstte saat; segment renkleri accent / textSecondary α.4 / kerahatLine; çentikler textSecondary α.7); altı sütun (ad 10 + saat 12; sıradaki accent zeminli, geçenler soluk). `ruler` yoksa cetvel çizilmez.
- [ ] Always-On sayaç kuralı (D19–D20) ve dakikalık çizelge aynen; kilit ekranı dosyalarına dokunulmaz.
- [ ] Çalıştır (Task 9): `flutter build ios --simulator --debug`; RunnerTests `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 17'` (mevcut değilse uygun simülatör).

### Task 7: Entegrasyon (ana oturum)

- [ ] Raporları oku, `git status`'u dosya kümeleriyle karşılaştır; Opus high dosyalarını tam oku.
- [ ] `flutter gen-l10n && dart format` (yalnız değişen dosyalar) `&& flutter analyze && flutter test`.
- [ ] `cd android && ./gradlew :app:testDebugUnitTest :app:lintDebug` (yeni `NewApi`/`GestureBackNavigation` dışı hata yok).
- [ ] `flutter build apk --debug --dart-define=VAKIT_API_BASE_URL=https://ezanvakti.ekrembulbul.me`; `flutter build ios --simulator --debug`.

### Task 8: Emülatör ve simülatör (ana oturum)

- [ ] Android 16 emülatörü: uygulamayı aç (konum seç), widget'ı ana ekrana ekle (uzun bas → Widgets), küçük ve orta, hizalama ayarı, Arapça uygulama dili; sabit satır kapalı/açık, kaydırınca geri gelme, ayardan kapatma; kerahat penceresi (emülatör saatini kerahat öncesine alarak).
- [ ] iOS simülatöründe derleme ve mümkünse widget görünümü.

### Task 9: Doğrulama, ADR, commit'ler (ana oturum)

- [ ] ADR 0004'e Android zaman çizelgesi notu; `git diff --check`.
- [ ] Mantıksal commit'ler (`dev`): ortak kaynaklar · Dart veri sözleşmesi · Kotlin çekirdeği · Android widget · sabit satır · iOS widget · dokümanlar. Türkçe Conventional Commit + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
