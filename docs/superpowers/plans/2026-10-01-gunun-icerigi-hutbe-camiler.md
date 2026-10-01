# Günün İçeriği, Hutbe ve Yakındaki Camiler — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ana sayfaya Diyanet'in günlük ayet/hadis/dua kartlarını, Araçlar'a hutbe ve yakındaki camiler araçlarını eklemek; sunucuda günlük içerik ve hutbe işlerini çalıştırmak.

**Architecture:** Sunucu (Go, `server/`) Diyanet'ten günlük içeriği (Awqat tarihsiz uç) ve hutbeleri (Diyanet Haber RSS + Din Hizmetleri PDF bağlantıları) çekip JSON dosyası olarak yayımlar. Uygulama (Flutter) bunları mevcut `vakit-api` HTTP kalıbıyla alır, `settings` tablosunda saklar; camiler için veri tutmaz, harita uygulamasını `url_launcher` ile seçilen koordinat çevresinde açar.

**Tech Stack:** Go 1.26 (`golang.org/x/net/html`, `encoding/xml`), Flutter/Dart (`http`, `share_plus`, `geolocator`, yeni `url_launcher`), SQLite `settings` anahtar–değer tablosu.

**Spec:** `docs/superpowers/specs/2026-10-01-gunun-icerigi-design.md`, `docs/superpowers/specs/2026-10-01-hutbe-design.md`, `docs/superpowers/specs/2026-10-01-yakin-camiler-design.md`

## Global Constraints

- Türkiye günü sabit UTC+3: `time.FixedZone("TRT", 3*3600)`; çalışma imajında tzdata yok, `LoadLocation` kullanılmaz.
- Go: `gofmt -l .` boş, `go vet ./...`, `go test -race ./...` geçmeli (CI aynılarını koşar).
- Dart: yalnız değiştirilen dosyalar `dart format` ile biçimlenir (formatter dokunulmamış 47 dosyayı değiştiriyor).
- Kullanıcıya görünen her metin `lib/l10n/app_tr.arb` + `app_en.arb` + `app_ar.arb`; sonra `flutter gen-l10n`. en metni tr kopyası olamaz (arb tutarlılık testi).
- Yeni `AppTypography` stili eklenmez; gerekirse mevcut stil `copyWith(fontSize:)` ile ve yalnız ölçekteki boyutlarla (11,12,13,14,16,17,20,24).
- `HomeScreen`, `ToolsScreen`, `SettingsScreen` build içinde `ServiceLocator().get` çağırmaz; yeni bağımlılıklar constructor parametresi/callback olarak gelir (mevcut testler servis kaydetmiyor).
- `LocalStorage` arayüzüne metot eklenmez; saklama `getSetting`/`setSetting` ile JSON.
- Diyanet metinleri değiştirilmez, kısaltılmaz; yalnız paragraf/dipnot ayrılır.
- Hatalar `AppLogger` ile loglanır; günlük içerik ve hutbe hataları vakit yüklemesini ve bildirim/alarm planlamasını etkilemez.
- Kartlar (günün içeriği) yalnız `Localizations.localeOf(context).languageCode == 'tr'` iken görünür ve istek atar.

## Review Focus

- **Gece yarısı sınırı (sunucu):** UTC 20:59 ve 21:00 anlarında TR günü farklıdır; iş UTC 21:05'te yeni günün dosyasını yazmalı, 20:59'da dünkünü. → A1'de test.
- **Diyanet henüz yeni güne geçmemiş:** `dayOfYear` dünkü gelirse hiçbir dosya yazılmamalı ve dünkü dosya bugünün yoluna kopyalanmamalı. → A1'de test.
- **Hutbe sayfasında imzadan sonraki çöp metin** (bayram sayfasında "Bayram Namazı nasıl kılınır?" bağlantıları): metne girmemeli. → C1'de fixture testi.
- **Koordinatsız vakit konumu** (eski kayıtlar): cami araması çökmeden "cami <konum adı>" ile açılmalı. → B1/B3'te test.
- **Uygulama dili Türkçe değilken** günün içeriği için ağ isteği atılmamalı ve kart görünmemeli. → A3'te test.

---

## Yürütme düzeni

- A1 inline (sunucu, küçük) → commit.
- A1 commit'inden sonra **C1+C2 tek bir worker'a** (sunucu, `server/` altındaki listelenen dosyalar). Worker `server/` içinde `gofmt`/`go vet`/`go test` koşabilir (Flutter build diziniyle paylaşılan kaynak yok); commit atmaz.
- Worker çalışırken ana oturum sırayla A2 → A3 → B1 → B2 → B3 → C3 → C4 (uygulama).
- Worker raporu gelince diff ve `go test` ana oturumda doğrulanır, commit'lenir.
- F: tam doğrulama, CHANGELOG, commit.

---

## Part A — Günün içeriği

### Task 1 (A1): Sunucu — tarihsiz günlük içerik işi

**Files:**
- Modify: `server/internal/source/source.go:26` (imza), `server/internal/source/awqatsrc/awqatsrc.go:116-124`, `server/internal/source/web/web.go:176-178`, `server/internal/source/web/web_test.go:170`
- Modify: `server/internal/jobs/dailycontent.go` (tamamı), `server/internal/jobs/fake_source_test.go:77`, `server/internal/jobs/other_test.go:78-111`
- Modify: `server/internal/store/store.go` (+`Remove`), `server/internal/store/store_test.go`
- Modify: `server/cmd/vakit/sync.go:38,169-176`, `server/deploy/crontab`, `server/README.md:33,44,76-78`

**Interfaces:**
- Produces: `source.Source.DailyContent(ctx context.Context) (*model.DailyContent, error)`; `jobs.DailyContent(ctx context.Context, d Deps) (Result, error)`; `(*store.Store).Remove(rel string) error` (yoksa nil); `jobs.TurkeyZone *time.Location`.

- [ ] **Step 1: Failing tests** — `other_test.go`'daki iki DailyContent testini şu dört testle değiştir (sahte kaynak `daily` haritası tarihsiz olacağı için `f.today *model.DailyContent` alanı eklenir):

```go
func TestDailyContent_WritesTurkeyDayWhenDayMatches(t *testing.T) {
	f := newFake()
	d := testDeps(t, f)
	d.Now = func() time.Time { return time.Date(2026, 10, 1, 21, 5, 0, 0, time.UTC) } // TR 2 Ekim 00:05
	f.today = &model.DailyContent{DayOfYear: 275, Verse: "v", VerseSource: "vs", Hadith: "h", HadithSource: "hs", Prayer: "p"}
	res, err := DailyContent(context.Background(), d)
	if err != nil || res.Written != 1 {
		t.Fatalf("res=%v err=%v", res, err)
	}
	var got model.DailyContent
	trDay := time.Date(2026, 10, 2, 0, 0, 0, 0, TurkeyZone)
	if err := d.Store.ReadJSON(store.DailyContentPath(trDay), &got); err != nil || got.Date != "2026-10-02" {
		t.Fatalf("got=%+v err=%v", got, err)
	}
}

func TestDailyContent_DayMismatchWritesNothing(t *testing.T) {
	f := newFake()
	d := testDeps(t, f)
	d.Now = func() time.Time { return time.Date(2026, 10, 1, 21, 5, 0, 0, time.UTC) }
	f.today = &model.DailyContent{DayOfYear: 274, Verse: "v", VerseSource: "vs", Hadith: "h", HadithSource: "hs", Prayer: "p"}
	res, _ := DailyContent(context.Background(), d)
	if res.Written != 0 || res.Skipped != 1 {
		t.Fatalf("res=%v", res)
	}
}

func TestDailyContent_ExistingTodaySkipsFetch(t *testing.T) { /* dosyayı önce WriteJSON ile yaz; f.calls["daily"]==0 ve Skipped==1 bekle */ }

func TestDailyContent_EmptyFieldRejected(t *testing.T) { /* Hadith=="" → Rejected==1, dosya yok */ }

func TestDailyContent_PrunesOlderThanSevenDays(t *testing.T) {
	// 2026-09-23 (9 gün önce) ve 2026-09-26 (6 gün önce) dosyaları + yıl sınırı için 2025-12-31 yaz;
	// Now = 2026-10-02 00:05 TR. Çalışmadan sonra 09-26 kalmalı, 09-23 ve 2025-12-31 silinmeli.
	// State.DailyContent.Days kalan dosya sayısına eşit olmalı.
}
```

Ayrıca `TestDailyContent_UnsupportedSkips` → `f.unsupported = true` iken `Skipped == 1`. `web_test.go:170` çağrısı `s.DailyContent(ctx)` olur. `store_test.go`'ya `TestRemove_MissingIsNil` ve `TestRemove_DeletesFile`.

- [ ] **Step 2: Run** `cd server && go test ./internal/jobs/ ./internal/store/ ./internal/source/...` → derleme hatası/FAIL.
- [ ] **Step 3: Implement.**
  - `source.go`: `DailyContent(ctx context.Context) (*model.DailyContent, error)` ve yorum "bugünün içeriği (Diyanet tarihsiz uç)".
  - `awqatsrc.go`: `rec, err := s.c.DailyContent(ctx)`; `Date` boş bırakılır (iş doldurur).
  - `web.go`: imza değişir, yine `ErrUnsupported`.
  - `store.go`: `func (s *Store) Remove(rel string) error { err := os.Remove(filepath.Join(s.Root, filepath.FromSlash(rel))); if errors.Is(err, fs.ErrNotExist) { return nil }; return err }`.
  - `jobs/dailycontent.go`:

```go
// TurkeyZone, Diyanet içeriğinin gün sınırı: Türkiye 2016'dan beri sabit UTC+3.
// Çalışma imajında tzdata yok; LoadLocation kullanılmaz.
var TurkeyZone = time.FixedZone("TRT", 3*3600)

// dailyContentKeepDays, sunucuda tutulan en eski günün bugünden uzaklığı.
const dailyContentKeepDays = 7

// DailyContent, Türkiye günü için Diyanet'in tarihsiz günlük içeriğini yazar. Gelen
// dayOfYear bugünle eşleşmezse (Diyanet henüz yeni güne geçmediyse) yazmaz; cron
// saat başı yeniden dener. Her çalışmada 7 günden eski dosyaları siler.
func DailyContent(ctx context.Context, d Deps) (Result, error) {
	var res Result
	today := d.Now().In(TurkeyZone)
	defer func() { d.State.DailyContent.Days = pruneDailyContent(d, today) }()
	path := store.DailyContentPath(today)
	if d.Store.Exists(path) {
		res.Skipped++
		return res, nil
	}
	content, err := d.Source.DailyContent(ctx)
	switch {
	case errors.Is(err, source.ErrUnsupported):
		res.Skipped++
		return res, nil
	case err != nil:
		if stopOnQuota(err, &res) {
			return res, fmt.Errorf("daily-content: %w", err)
		}
		res.Errors++
		d.Logger.Warn("daily-content fetch failed", "err", err.Error())
		return res, nil
	}
	res.Fetched++
	if content == nil || content.Verse == "" || content.Hadith == "" || content.Prayer == "" {
		res.Rejected++
		d.Logger.Warn("daily-content incomplete; not written")
		return res, nil
	}
	if content.DayOfYear != today.YearDay() {
		res.Skipped++
		d.Logger.Warn("daily-content day mismatch; retry later", "got", content.DayOfYear, "want", today.YearDay())
		return res, nil
	}
	content.Date = today.Format(model.DateLayout)
	if err := d.Store.WriteJSON(path, content); err != nil {
		return res, err
	}
	res.Written++
	d.State.DailyContent.UpdatedAt = d.Now()
	d.Logger.Info("sync daily-content done", "result", res.String())
	return res, nil
}
```

  `pruneDailyContent(d Deps, today time.Time) int`: `today.Year()` ve `today.Year()-1` için `os.ReadDir(filepath.Join(d.Store.Root, "daily-content", year))`; `N.json` → `time.Date(year,1,1,0,0,0,0,TurkeyZone).AddDate(0,0,N-1)`; `today` gün başından 7 günden eskiyse `d.Store.Remove(...)`; kalanları sayar. Okuma hatası (dizin yok) sessizce 0.
  - `sync.go`: `daily-content` dalında bayrak yok → `res, jobErr = jobs.DailyContent(ctx, deps)`; usage satırı `daily-content  günün ayet/hadis/duası (Türkiye günü; saat başı denenir)`.
  - `crontab`: 4. satırdaki 403 yorumunu kaldır; ekle:
    ```
    # daily-content: TR 00:05–06:05 saat başı (UTC 21:05–03:05); o gün yazıldıysa istek atmaz.
    5 21-23 * * * cd "$HOME/vakit-api" && docker compose run --rm -T vakit sync daily-content >> logs/sync.log 2>&1
    5 0-3 * * *   cd "$HOME/vakit-api" && docker compose run --rm -T vakit sync daily-content >> logs/sync.log 2>&1
    ```
  - README: uç satırı "(API onayı sonrası)" → "(Türkiye günü, son 7 gün)", komut `vakit sync daily-content`, cron anlatımına daily-content, 403 notu yerine "tarihsiz uç kullanılır; tarihli uç rolümüze kapalı".
- [ ] **Step 4: Run** `cd server && gofmt -l . && go vet ./... && go test -race ./...` → temiz, PASS.
- [ ] **Step 5: Commit** `feat(server): günlük içeriği Diyanet'in tarihsiz ucundan çek`.

### Task 2 (A2): Uygulama — günlük içerik veri katmanı

**Files:**
- Create: `lib/features/daily_content/domain/daily_content.dart`, `lib/features/daily_content/data/daily_content_api.dart`, `lib/features/daily_content/domain/daily_content_repository.dart`
- Modify: `lib/core/di/service_locator.dart` (kayıt)
- Test: `test/daily_content/daily_content_api_test.dart`, `test/daily_content/daily_content_repository_test.dart`

**Interfaces:**
- Produces:
  - `class DailyContent { final String date; final String verse, verseSource, hadith, hadithSource, prayer; final String? prayerSource; factory DailyContent.fromJson(Map<String, dynamic>); Map<String, dynamic> toJson(); DateTime get day; }` (`fromJson` sunucu anahtarları: `date, verse, verseSource, hadith, hadithSource, prayer, prayerSource`; zorunlu alan eksikse `ParseException`).
  - `class DailyContentApi { DailyContentApi({required http.Client client, String baseUrl = VakitApiConfig.baseUrl}); Future<DailyContent?> fetch(DateTime day); }` — 200 → içerik, 404 → `null`, diğer → `ApiException`, JSON bozuk → `ParseException`; zaman aşımı 15 sn.
  - `class DailyContentRepository { DailyContentRepository({required DailyContentApi api, required LocalStorage storage, DateTime Function()? now}); Future<DailyContent?> load(); static DailyContent? visible(DailyContent? c, DateTime now); }`; ayar anahtarları `daily_content` (JSON) ve `daily_content_attempt` (ISO).

- [ ] **Step 1: Failing tests** (MockClient kalıbı `test/location/places_api_test.dart:26`; depolama için `test/presentation/reminder_list_preferences_test.dart:21-43`'teki asgari `_SettingsStorage`):
  - api: `fetch(DateTime(2026,10,1))` isteği `/v1/daily-content/2026-10-01`; 200 ayrıştırılır; 404 → null; 500 → `ApiException`; bozuk JSON → `ParseException`.
  - repository:
    - saklanan içerik bugünkü ise istek atılmaz (MockClient çağrı sayacı 0);
    - saklanan dünkü, son deneme 10 dk önce → istek atılmaz, dünkü döner;
    - son deneme 31 dk önce, sunucu 200 → yeni içerik saklanır ve döner;
    - sunucu 404 → saklanan döner, deneme zamanı yazılır;
    - ağ hatası → saklanan döner, hata yutulmaz ama fırlatılmaz (logger);
    - `visible`: 7 gün önceki görünür, 8 gün önceki `null`.
- [ ] **Step 2: Run** `flutter test test/daily_content/` → FAIL.
- [ ] **Step 3: Implement.** `load()`:

```dart
Future<DailyContent?> load() async {
  final stored = await _readStored();
  final now = _now();
  final today = DateTime(now.year, now.month, now.day);
  if (stored != null && stored.day == today) return stored;
  final lastAttempt = DateTime.tryParse(await storage.getSetting(_attemptKey) ?? '');
  if (lastAttempt != null && now.difference(lastAttempt) < retryAfter) return stored;
  await storage.setSetting(_attemptKey, now.toIso8601String());
  try {
    final fresh = await api.fetch(today);
    if (fresh == null) return stored;
    await storage.setSetting(_contentKey, jsonEncode(fresh.toJson()));
    return fresh;
  } catch (e, s) {
    AppLogger().warning('Daily content fetch failed', e, s);
    return stored;
  }
}
```

  `retryAfter = Duration(minutes: 30)`. `_readStored` bozuk JSON'da `null` döner ve loglar. ServiceLocator'a `DailyContentApi(client: get<http.Client>())` ve `DailyContentRepository(api:, storage: get<LocalStorage>())` kaydı (PlacesApi kaydının yanına).
- [ ] **Step 4: Run** testler PASS; `dart format` (yalnız yeni/değişen dosyalar); `flutter analyze`.
- [ ] **Step 5: Commit** `feat(app): günlük içerik veri katmanı`.

### Task 3 (A3): Uygulama — ana sayfa kartları

**Files:**
- Create: `lib/presentation/widgets/home/daily_content_section.dart`
- Modify: `lib/presentation/screens/home_screen.dart` (yeni `dailyContent` parametresi, `_buildBody` Column'da `PrayerGrid` sonrası), `lib/presentation/pages/home_page.dart` (yükleme: postFrame, resume, gece yarısı; yalnız tr)
- Modify: `lib/l10n/app_tr.arb`, `app_en.arb`, `app_ar.arb`; `docs/PRIVACY.md`, `docs/privacy.html`
- Test: `test/widgets/home/daily_content_section_test.dart`, `test/widgets/home/home_screen_test.dart` (tr/en)

**Interfaces:**
- Consumes: `DailyContent`, `DailyContentRepository.visible`.
- Produces: `DailyContentSection({required DailyContent content})`; `HomeScreen(..., DailyContent? dailyContent)`.

- [ ] **Step 1: Failing tests.**
  - Section: üç başlık ("Günün Ayeti", "Günün Hadisi", "Günün Duası"), metinler ve kaynaklar görünür; `prayerSource == null` iken dua kaynağı satırı yok; karta uzun basınca `SystemChannels.platform` `Clipboard.setData` çağrısı `metin + "\n" + kaynak` ile yapılır ve SnackBar "Kopyalandı" görünür (`tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, ...)`).
  - HomeScreen: `dailyContent` verildiğinde tr'de bölüm var; `locale: Locale('en')` ile yok; `null` iken yok. Mevcut `home_scroll_test`/`overflow_test` geçmeye devam eder.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.**
  - Kart kapsayıcı `general_section.dart:35-41` kalıbı (surface, radius 16, border, padding 16); başlık `AppTypography.sectionLabel`, metin `AppTypography.rowTitle` (`textPrimary`, satır yüksekliği 1.45), kaynak `AppTypography.hint` + `textTertiary`, sağa yaslı (RTL'de `TextAlign.end`). Sağ üstte `AppBarActionButton(icon: Icons.ios_share_rounded, tooltip: l10n.actionShare)`.
  - Paylaş: `SharePlus.instance.share(ShareParams(text: '$title\n\n$text\n$source', sharePositionOrigin: rect))`; hata loglanır.
  - Kopyala: `GestureDetector(onLongPress:)` → `Clipboard.setData(ClipboardData(text: '$text\n$source'))` + `ScaffoldMessenger..clearSnackBars()..showSnackBar(SnackBar(content: Text(l10n.dailyContentCopied)))`.
  - `HomeScreen`: `if (dailyContent != null && Localizations.localeOf(context).languageCode == 'tr') ...[DailyContentSection(content: dailyContent!), SizedBox(20)]` `PrayerGrid`'den sonra.
  - `HomePage`: `DailyContent? _dailyContent`; `Future<void> _loadDailyContent()` → `if (Localizations.localeOf(context).languageCode != 'tr') return;` → repository `load()` → `setState(() => _dailyContent = DailyContentRepository.visible(c, DateTime.now()))`. postFrame'de `_loadPrayerData` sonrası, `didChangeAppLifecycleState(resumed)` içinde ve gece yarısı timer'ında çağrılır; `unawaited`.
  - ARB (tr/en/ar): `dailyVerseTitle` Günün Ayeti / Verse of the Day / آية اليوم; `dailyHadithTitle` Günün Hadisi / Hadith of the Day / حديث اليوم; `dailyPrayerTitle` Günün Duası / Prayer of the Day / دعاء اليوم; `dailyContentCopied` Kopyalandı / Copied / تم النسخ. `flutter gen-l10n`.
  - PRIVACY.md + privacy.html "Sunucuya giden veriler" listesine: "Günlük ayet/hadis/dua için yalnız tarih".
- [ ] **Step 4: Run** `flutter test test/widgets/home/ test/l10n/` PASS; `flutter analyze`; `dart format` değişenler.
- [ ] **Step 5: Commit** `feat(app): ana sayfada günün ayeti, hadisi ve duası`.

---

## Part B — Yakındaki camiler

### Task 4 (B1): `url_launcher`, platform ayarları ve bağlantı üretimi

**Files:**
- Modify: `pubspec.yaml` (`url_launcher`), `ios/Runner/Info.plist` (`LSApplicationQueriesSchemes`: `comgooglemaps`, `yandexmaps`), `android/app/src/main/AndroidManifest.xml` (`<queries>`: `VIEW` + `geo`, `VIEW` + `https`)
- Create: `lib/features/mosques/domain/map_links.dart`
- Test: `test/mosques/map_links_test.dart`

**Interfaces:**
- Produces: `enum MapApp { apple, google, yandex }`; `typedef LatLon = ({double lat, double lon});`; `Uri mosqueSearchUri({required MapApp app, required String query, LatLon? center, required bool android, required bool appleUnified})`; `bool appleUnifiedMapsSupported(String operatingSystemVersion)` (≥ 18.4).

- [ ] **Step 1: Failing tests** — her biri tam dizgiyle:
  - android + merkez → `geo:41.0,29.0?z=14&q=cami`; android merkezsiz → `geo:0,0?q=cami%20Kad%C4%B1k%C3%B6y`
  - apple unified → `https://maps.apple.com/search?query=cami&center=41.0,29.0&span=0.03,0.03`
  - apple legacy → `https://maps.apple.com/?q=cami&sll=41.0,29.0&z=14`
  - google → `comgooglemaps://?q=cami&center=41.0,29.0&zoom=14`
  - yandex → `yandexmaps://maps.yandex.com/?text=cami&ll=29.0,41.0&z=14` (boylam önce)
  - Arapça sorgu (`مسجد`) yüzde kodlanır.
  - `appleUnifiedMapsSupported`: "18.4" true, "Version 18.3.1 (Build …)" false, "26.0" true, "" false.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** (dizgiler `Uri.encodeQueryComponent` yerine `Uri.encodeComponent` ile — boşluk `%20`; Yandex biçimi resmî belgeyle doğrulanmadı, cihaz testine kalır — dosyada yorum). Platform dosyaları:

```xml
<!-- Info.plist -->
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>comgooglemaps</string>
  <string>yandexmaps</string>
</array>
```

```xml
<!-- AndroidManifest <queries> içine -->
<intent>
  <action android:name="android.intent.action.VIEW"/>
  <data android:scheme="geo"/>
</intent>
<intent>
  <action android:name="android.intent.action.VIEW"/>
  <data android:scheme="https"/>
</intent>
```

  `flutter pub add url_launcher`.
- [ ] **Step 4: Run** testler PASS, `flutter analyze`.
- [ ] **Step 5: Commit** `feat(app): harita arama bağlantıları ve url_launcher`.

### Task 5 (B2): GPS — tek seferlik koordinat

**Files:**
- Modify: `lib/features/location/data/gps_location_service.dart:42-67`
- Test: mevcut GPS testleri (davranış aynı kalmalı)

**Interfaces:**
- Produces: `Future<LatLon> currentPosition({Future<bool> Function()? requestPermission, Duration timeout = const Duration(seconds: 10)})` — `locate` bunu çağırıp `resolve` eder. Hata anahtarları aynı; zaman aşımı `GpsLocationException('location_timeout')`.

- [ ] **Step 1:** `locate` gövdesindeki izin + konum kısmını `currentPosition`'a taşı (`LocationAccuracy.medium`, `timeLimit: timeout` cami için; `locate` yüksek doğrulukla çağırır — parametre `accuracy`). `TimeoutException` → `GpsLocationException(timeoutKey)`.
- [ ] **Step 2: Run** `flutter test test/location/` → PASS (davranış değişmedi); `flutter analyze`.
- [ ] **Step 3: Commit** `refactor(location): koordinatı ilçe çözümlemesinden ayır`.

### Task 6 (B3): Yakındaki camiler akışı, Araçlar ve Ayarlar satırları

**Files:**
- Create: `lib/presentation/services/nearby_mosques_launcher.dart`, `lib/presentation/widgets/tools/nearby_mosques_sheet.dart`
- Modify: `lib/presentation/screens/tools_screen.dart` (yeni `onFindMosques` callback'li satır; gizlilik notu metni), `lib/presentation/pages/home_page.dart` (callback'i bağlar), `lib/presentation/screens/settings_screen.dart` + çağıranı (iOS'ta "Harita uygulaması" satırı; `bool showMapAppRow` ve `onMapApp` parametreleri)
- Modify: ARB'ler, `docs/PRIVACY.md`, `docs/privacy.html`
- Test: `test/mosques/nearby_mosques_launcher_test.dart`, `test/widgets/screens/tools_screen_test.dart`

**Interfaces:**
- Consumes: `mosqueSearchUri`, `appleUnifiedMapsSupported`, `GpsLocationService.currentPosition`, `Location.latitude/longitude/displayName`.
- Produces:
  - `class NearbyMosquesLauncher { NearbyMosquesLauncher({required LocalStorage storage, required bool isIOS, required String osVersion, required Future<bool> Function(Uri) canOpen, required Future<bool> Function(Uri) open}); Future<List<MapApp>> installedApps(); Future<MapApp?> savedApp(); Future<void> saveApp(MapApp app); Future<bool> launch({required MapApp app, required String query, LatLon? center}); }` — ayar anahtarı `maps_app` (`apple|google|yandex`). Android'de `installedApps` → `[MapApp.google]` gibi değil; Android yolu uygulama seçmez, `launch(app: MapApp.google, ...)` `geo:` üretir (`android: !isIOS`).
  - `Future<void> showNearbyMosquesFlow(BuildContext context, {required Location location, required NearbyMosquesLauncher launcher, required GpsLocationService gps})`.

- [ ] **Step 1: Failing tests (launcher):** iOS'ta yalnız Apple yüklü → `installedApps == [apple]`; Google da yüklü (canOpen `comgooglemaps://` true) → `[apple, google]`; kayıtlı `google` ama artık yüklü değil → `savedApp` null; `launch` doğru Uri ile `open` çağırır; `open` false → `launch` false.
- [ ] **Step 2: Failing tests (Tools):** tr'de "Yakındaki camiler" satırı görünür, dokununca callback çağrılır; gizlilik notu yeni metin.
- [ ] **Step 3: Run** → FAIL.
- [ ] **Step 4: Implement akış** (`showNearbyMosquesFlow`):
  1. `showOptionPicker<_Origin>` ile iki seçenek: "Vakit konumuna göre (`location.displayName`)" ve "Bulunduğum yere göre".
  2. Vakit: `center = (lat, lon)` iki değer de doluysa; değilse `null` ve sorgu `'${l10n.mosqueSearchQuery} ${location.displayName}'`.
  3. Bulunduğum yer: `gps.currentPosition(requestPermission: rationale)`; `GpsLocationException` → `AlertDialog` "Konumun alınamadı. Vakit konumuna göre aransın mı?" (Evet → 2. adım, Vazgeç → çık). Rationale metni `mosquesPermissionBody`.
  4. iOS: `installed = await launcher.installedApps()`; tek ise o; `savedApp` varsa o; yoksa `showOptionPicker<MapApp>` → `saveApp`. Android: `MapApp.google` (yalnız `geo:` üretimi için).
  5. `launch` false → SnackBar `mosquesOpenFailed`; `AppLogger().warning`.
  - Tools: `_row(icon: Icons.mosque_outlined, title: l10n.toolsMosques, subtitle: l10n.toolsMosquesHint, onTap: onFindMosques)`; HomePage `onFindMosques: () => showNearbyMosquesFlow(context, location: appState.activeLocation!, launcher: ServiceLocator().get(), gps: ServiceLocator().get())`. ServiceLocator'a `NearbyMosquesLauncher(storage:, isIOS: Platform.isIOS, osVersion: Platform.operatingSystemVersion, canOpen: canLaunchUrl, open: (u) => launchUrl(u, mode: LaunchMode.externalApplication))`.
  - Settings: `if (showMapAppRow) _row(icon: Icons.map_outlined, title: l10n.settingsMapApp, value: label, onTap: onMapApp)`; HomePage/çağıran `showMapAppRow: Platform.isIOS`.
  - ARB: `toolsMosques` Yakındaki camiler / Nearby mosques / المساجد القريبة; `toolsMosquesHint` Harita uygulamasında ara / Search in your maps app / ابحث في تطبيق الخرائط; `mosqueSearchQuery` cami / mosque / مسجد; `mosquesByPrayerLocation` Vakit konumuna göre ({place}) / By prayer-time location ({place}) / حسب موقع المواقيت ({place}); `mosquesByCurrentLocation` Bulunduğum yere göre / Where I am now / حسب موقعي الحالي; `mosquesLocationFailed` Konumun alınamadı. Vakit konumuna göre aransın mı? / Couldn't get your location. Search around your prayer-time location instead? / تعذّر تحديد موقعك. هل تريد البحث حول موقع المواقيت؟; `mosquesPermissionBody` Yakındaki camileri bulunduğun yere göre aramak için konumun bir kez okunur; konum yalnız harita uygulamasına iletilir. / To search near you, your location is read once and passed only to your maps app. / للبحث بالقرب منك، يُقرأ موقعك مرة واحدة ويُرسل إلى تطبيق الخرائط فقط.; `mosquesOpenFailed` Harita uygulaması açılamadı / Couldn't open the maps app / تعذّر فتح تطبيق الخرائط; `mapAppPickerTitle` Harita uygulaması / Maps app / تطبيق الخرائط; `settingsMapApp` Harita uygulaması / Maps app / تطبيق الخرائط; `mapAppApple` Apple Haritalar / Apple Maps / خرائط Apple; `mapAppGoogle` Google Haritalar / Google Maps / خرائط Google; `mapAppYandex` Yandex Haritalar / Yandex Maps / خرائط Yandex; `mapAppAsk` Her seferinde sor / Ask each time / اسأل في كل مرة; `toolsPrivacyNote` güncellenir: "Kıble, takvim, takip ve zikir cihazında çalışır. Hutbeler sunucumuzdan gelir; cami araması harita uygulamanda açılır." (+en/ar).
  - PRIVACY: "Yakındaki camiler: seçtiğin konumun koordinatı yalnız açtığın harita uygulamasına iletilir; sunucumuza gitmez."
- [ ] **Step 5: Run** testler + `flutter test test/l10n/ test/widgets/screens/` PASS; analyze; format.
- [ ] **Step 6: Commit** `feat(app): yakındaki camileri harita uygulamasında ara`.

---

## Part C — Hutbe

### JSON sözleşmesi (sunucu ↔ uygulama)

`GET /v1/sermons` (`Cache-Control: public, max-age=900`):

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-10-01T19:00:04Z",
  "sermons": [
    {
      "id": "2026-09-25-cuma",
      "date": "2026-09-25",
      "kind": "cuma",
      "title": "Tebliğ Sorumluluğumuz",
      "sourceUrl": "https://www.diyanethaber.com.tr/25-eylul-2026-cuma-hutbesi",
      "modifiedAt": "2026-09-25T11:28:09+03:00",
      "pdfs": {
        "en": {"title": "Our Responsibility to Convey Islam", "url": "https://dinhizmetleri.diyanet.gov.tr/Documents/Our%20Responsibility%20to%20Convey%20Islam.pdf"},
        "ar": {"title": "مَسْؤُولِيَّتُنَا فِي التَّبْلِيغِ", "url": "https://dinhizmetleri.diyanet.gov.tr/Documents/…pdf"}
      }
    }
  ]
}
```

`GET /v1/sermons/{id}` (`Cache-Control: public, max-age=3600`; bilinmeyen/biçimsiz id 404):

```json
{
  "id": "2026-09-25-cuma", "date": "2026-09-25", "kind": "cuma",
  "title": "Tebliğ Sorumluluğumuz", "heading": "TEBLİĞ SORUMLULUĞUMUZ",
  "paragraphs": ["Muhterem Müslümanlar!", "Medineliler …"],
  "footnotes": [{"n": 1, "text": "İbn Sa’d, Tabakât, I, 219, 220."}],
  "signature": "Din Hizmetleri Genel Müdürlüğü",
  "sourceUrl": "https://www.diyanethaber.com.tr/25-eylul-2026-cuma-hutbesi",
  "modifiedAt": "2026-09-25T11:28:09+03:00"
}
```

`kind`: `cuma` | `bayram`. `pdfs` boş nesne olabilir. Sıralama tarih azalan, en çok 20.

### Task 7 (C1): Sunucu — hutbe ayrıştırıcıları (worker)

**Files:**
- Create: `server/internal/sermon/model.go`, `rss.go`, `article.go`, `dinhizmetleri.go`, `client.go`, `*_test.go`, `testdata/` (fixture'lar: `diyanethaber_rss.xml`, `diyanethaber_2026-09-25.html`, `diyanethaber_bayram_2026-05-27.html`, `dinhizmetleri_home.html`, `dinhizmetleri_detay_1318.html`, `dinhizmetleri_detay_1251.html` — kaynak: scratchpad `hutbe_fx/trimmed/`)

**Interfaces:**
- Produces:
  - `type Kind string` (`KindCuma = "cuma"`, `KindBayram = "bayram"`); `type PDF struct{ Title, URL string }`; `type Summary struct{ ID, Date string; Kind Kind; Title, SourceURL, ModifiedAt string; PDFs map[string]PDF }` (JSON etiketleri sözleşmedeki gibi); `type Footnote struct{ N int; Text string }`; `type Text struct{ ID, Date string; Kind Kind; Title, Heading string; Paragraphs []string; Footnotes []Footnote; Signature, SourceURL, ModifiedAt string }`; `type Index struct{ SchemaVersion int; UpdatedAt time.Time; Sermons []Summary }`.
  - `type FeedItem struct{ Date time.Time; Kind Kind; Title, Link string }`; `func ParseFeed(r io.Reader) ([]FeedItem, error)` — başlık "25 Eylül 2026 - Cuma Hutbesi" / "05 Haziran 2026 - …" / "Kurban Bayramı Hutbesi - 27 Mayıs 2026"; konu açıklamadaki çift tırnak içinden ("…tarihli ve \"Tebliğ Sorumluluğumuz\" konulu…"), yoksa başlıktaki tarih çıkarılmış kısım ("Kurban Bayramı Hutbesi"). Tarihi çözülemeyen kayıt atlanır.
  - `func ParseArticle(r io.Reader) (heading string, paragraphs []string, footnotes []Footnote, signature, modifiedAt string, err error)` — JSON-LD `NewsArticle.articleBody` (`\r\n` → `\n`, boş satırla bloklara ayır, kırp, boşları at); ilk blok heading; `^\[(\d+)\]\s*(.*)$` dipnot; dipnotlardan sonra "Din Hizmetleri Genel Müdürlüğü" bloğu imza; imzadan (yoksa son dipnottan) sonraki her şey atılır; dipnot yoksa imzaya kadar paragraf. `dateModified` → modifiedAt.
  - `func FindDetailURL(home io.Reader, date time.Time, kind Kind) (string, error)` — `/Detay/{id}/{ddmmyyyy}-{cuma|bayram}-hutbesi` önekiyle eşleşen ilk bağlantı (HTML entity çözülür); yoksa `"", nil`.
  - `func ParsePDFs(detail io.Reader, base string, trTitle string) (map[string]PDF, error)` — `<title>` içindeki parantezden dil sırası ("Sesli Hutbe" atlanır; Türkçe adlar: Türkçe→tr, İngilizce→en, Arapça→ar, Almanca, Fransızca, İspanyolca, İtalyanca, Rusça); `/Documents/*.pdf` bağlantıları belge sırasıyla dillere eşlenir; sayı tutmazsa geri düşüş: Arap harfli ad → ar, TR başlığa eşit ad → tr, kalan tek Latin ad → en (birden fazlaysa en yok). Yalnız `en` ve `ar` döner; URL `base` + yol, yol `url.PathEscape` parçalarıyla kodlanır.
  - `type Client struct{...}`; `func NewClient(opts ...Option) *Client`; `WithHTTPClient(*http.Client)`, `WithInterval(time.Duration)`, `WithBaseURLs(diyanetHaber, dinHizmetleri string)`; `func (c *Client) Get(ctx context.Context, url string) ([]byte, error)` — `User-Agent: vakit-api/1.0 (+https://ezanvakti.ekrembulbul.me)`, zaman aşımı 30 sn, istekler arası en az `interval` (varsayılan 1 sn), gövde sınırı 4 MB, 200 dışı hata; `/kategoriler/` içeren URL'yi reddeder.

- [ ] **Step 1:** Fixture'ları `server/internal/sermon/testdata/` altına kopyala.
- [ ] **Step 2: Failing tests:**
  - `ParseFeed`: 20 kayıt; ilki `2026-09-25` cuma "Tebliğ Sorumluluğumuz"; "05 Haziran 2026" → `2026-06-05`; bayram kaydı `2026-05-27` bayram "Kurban Bayramı Hutbesi".
  - `ParseArticle` (25.09): heading "TEBLİĞ SORUMLULUĞUMUZ", ilk paragraf "Muhterem Müslümanlar!", 6 dipnot, `Footnotes[2] == {3, "Nahl, 16/125."}`, imza "Din Hizmetleri Genel Müdürlüğü", modifiedAt "2026-09-25T11:28:09+03:00"; hiçbir paragraf "[" ile başlamaz.
  - `ParseArticle` (bayram): son paragraf "Bayram Namazı nasıl kılınır?" DEĞİL; 4 dipnot.
  - `FindDetailURL(home, 2026-09-25, cuma)` → `…/Detay/1318/…`; `(2026-03-20, bayram)` → `…/Detay/1251/…`; olmayan tarih → `""`.
  - `ParsePDFs(1318, …, "Tebliğ Sorumluluğumuz")` → en "Our Responsibility to Convey Islam", ar Arapça başlık; `ParsePDFs(1251, …, "Ramazan Bayramı")` → en "Eid al_fitr" (title sırasında İngilizce 8. dil), ar "عِيدِ الْفِطْرِ".
  - Client: httptest sunucusu UA'yı görür; 404 → hata; `/kategoriler/x` → hata ve istek atılmaz.
- [ ] **Step 3:** `cd server && go test ./internal/sermon/` → FAIL.
- [ ] **Step 4:** Uygula (`golang.org/x/net/html` ile; `encoding/xml` RSS için).
- [ ] **Step 5:** `gofmt -l . && go vet ./... && go test -race ./internal/sermon/` → PASS.

### Task 8 (C2): Sunucu — hutbe işi, uçlar, CLI, cron (worker)

**Files:**
- Create: `server/internal/jobs/sermons.go`, `server/internal/jobs/sermons_test.go`, `server/internal/httpapi/sermons_test.go` (ya da `handler_test.go`'ya ekleme)
- Modify: `server/internal/store/paths.go` (+`SermonIndexPath() string` = `sermons/index.json`, `SermonTextPath(id string) string` = `sermons/{id}.json`), `server/internal/httpapi/handler.go` (iki uç), `server/internal/httpapi/health.go` (sermons özeti index dosyasından: `{"updatedAt", "count"}`; migration yok), `server/cmd/vakit/sync.go` + `main.go` (iş `sermons`), `server/deploy/crontab`, `server/README.md`

**Interfaces:**
- Consumes: C1 paketi; `jobs.TurkeyZone` (A1).
- Produces: `func Sermons(ctx context.Context, d Deps, c *sermon.Client) (Result, error)`; uçlar sözleşmedeki gibi.

- [ ] **Step 1: Failing tests** (httptest ile Diyanet Haber + Din Hizmetleri sahte sunucusu, C1 fixture'larıyla):
  - ilk çalışma: RSS'teki 20 kaydın metni yazılır, index 20 kayıt, tarih azalan; 25.09 kaydında `pdfs.en` dolu.
  - ikinci çalışma (Now = 2026-10-01): metni olan ve tarihi bugünden önce olan kayıtlar için sayfa İSTENMEZ (istek sayacı).
  - Now = 2026-09-25 09:00 TR: 25.09 kaydının sayfası yeniden istenir; `dateModified` değişmişse metin güncellenir.
  - kısa metin (<500 karakter toplam paragraf) → eski metin korunur, `Rejected++`.
  - RSS 500 → iş hata döner, mevcut dosyalara dokunulmaz.
  - 21. kayıt düşünce eski metin dosyası silinir.
  - PDF bulunamazsa `pdfs` boş; hutbe tarihi bugünden ≥ 7 gün geride değilse sonraki çalışmada yeniden aranır, eskiyse aranmaz.
  - httpapi: `/v1/sermons` 200 + `max-age=900`; `/v1/sermons/2026-09-25-cuma` 200 + `max-age=3600`; `/v1/sermons/../x` ve bilinmeyen id 404; health'te `sermons.count`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implement.** id doğrulaması `^\d{4}-\d{2}-\d{2}-(cuma|bayram)$`. Index yazımı `WriteJSON` (atomik). Din Hizmetleri ana sayfası çalışma başına en çok bir kez çekilir (yalnız PDF aranacak kayıt varsa). Cron (TR → UTC):
  ```
  # sermons: her gün TR 22:00, ek olarak perşembe 17:00 ve cuma 11:30
  0 19 * * *  cd "$HOME/vakit-api" && docker compose run --rm -T vakit sync sermons >> logs/sync.log 2>&1
  0 14 * * 4  cd "$HOME/vakit-api" && docker compose run --rm -T vakit sync sermons >> logs/sync.log 2>&1
  30 8 * * 5  cd "$HOME/vakit-api" && docker compose run --rm -T vakit sync sermons >> logs/sync.log 2>&1
  ```
  README: uçlar, komut, cron, kaynak ve izin notu (Diyanet Haber künyesi), robots notu.
- [ ] **Step 4:** `gofmt -l . && go vet ./... && go test -race ./...` → PASS.
- [ ] **Step 5 (ana oturum):** diff'i dosya listesine karşı doğrula, testleri koş, commit `feat(server): Diyanet hutbelerini çek ve yayımla`.

### Task 9 (C3): Uygulama — hutbe veri katmanı

**Files:**
- Create: `lib/features/sermons/domain/sermon.dart`, `lib/features/sermons/data/sermons_api.dart`, `lib/features/sermons/domain/sermon_repository.dart`
- Modify: `lib/core/di/service_locator.dart`
- Test: `test/sermons/sermons_api_test.dart`, `test/sermons/sermon_repository_test.dart`

**Interfaces:**
- Produces:
  - `enum SermonKind { cuma, bayram }`; `class SermonPdf { final String title; final Uri url; }`; `class SermonSummary { final String id; final DateTime date; final SermonKind kind; final String title; final Uri sourceUrl; final Map<String, SermonPdf> pdfs; fromJson/toJson }`; `class SermonFootnote { final int n; final String text; }`; `class SermonText { id, date, kind, title, heading, List<String> paragraphs, List<SermonFootnote> footnotes, String signature, Uri sourceUrl; fromJson/toJson }`.
  - `class SermonsApi { SermonsApi({required http.Client client, String baseUrl}); Future<List<SermonSummary>> fetchIndex(); Future<SermonText> fetchText(String id); }`.
  - `class SermonRepository { SermonRepository({required SermonsApi api, required LocalStorage storage, DateTime Function()? now}); Future<List<SermonSummary>> index({bool force = false}); Future<SermonText> text(String id); Future<int> fontStep(); Future<void> setFontStep(int step); static SermonSummary? featured(List<SermonSummary> index, DateTime now); }`. Ayar anahtarları: `sermons_index` (JSON), `sermons_index_at` (ISO), `sermon_texts` (JSON `{id: text}`), `sermon_font_step` (0–4, varsayılan 2).

- [ ] **Step 1: Failing tests:**
  - index: saklanan 30 dk önce → istek yok; 61 dk önce → istek, saklanır; ağ hatası + saklanan var → saklanan döner; ağ hatası + saklanan yok → hata fırlar.
  - index yenilenince `sermon_texts` içinden index'te olmayan id'ler silinir.
  - text: saklıysa istek yok; değilse indirilir ve saklanır; ağ yok + saklı değil → hata.
  - `featured`: en yeni hutbe tarihi bugün ya da yarınsa döner (perşembe ve cuma), cumartesi `null`; bayram hutbesi bayram günü ve bir gün öncesi.
  - fontStep sınırları 0–4'e kıstırılır.
- [ ] **Step 2–4:** FAIL → uygula (A2 kalıbı; `index` 1 saat throttle) → PASS, analyze, format.
- [ ] **Step 5: Commit** `feat(app): hutbe veri katmanı`.

### Task 10 (C4): Uygulama — hutbe ekranları ve ana sayfa kartı

**Files:**
- Create: `lib/presentation/screens/sermon_list_screen.dart`, `lib/presentation/screens/sermon_reader_screen.dart`, `lib/presentation/widgets/home/sermon_card.dart`
- Modify: `lib/presentation/screens/tools_screen.dart` (`onOpenSermons`), `lib/presentation/screens/home_screen.dart` (`featuredSermon`, `onOpenSermon`), `lib/presentation/pages/home_page.dart`, ARB'ler, `docs/PRIVACY.md`, `docs/privacy.html`
- Test: `test/widgets/screens/sermon_list_screen_test.dart`, `test/widgets/screens/sermon_reader_screen_test.dart`, `test/widgets/home/sermon_card_test.dart`

**Interfaces:**
- Consumes: C3; `url_launcher` (B1).
- Produces: `SermonListScreen({required SermonRepository repository, required Future<bool> Function(Uri) openUrl})`, `SermonReaderScreen({required SermonRepository repository, required SermonSummary summary, required Future<bool> Function(Uri) openUrl})`, `SermonCard({required SermonSummary sermon, required String title, required VoidCallback onOpen})`.

- [ ] **Step 1: Failing tests:**
  - Liste tr: Türkçe başlık + tarih ("25 Eylül 2026 · Cuma"); dokununca okuma ekranı.
  - Liste en: yalnız `pdfs.en` olanlar, İngilizce başlıkla; dokununca `openUrl(pdf.url)`.
  - Liste: index hatası + boş → `ErrorState` ve yeniden dene.
  - Okuma: heading, paragraflar, dipnotlar ("1. İbn Sa’d…"), imza, "Kaynak: Diyanet Haber" (dokununca `openUrl(sourceUrl)`); yazı büyüt düğmesi metin boyutunu 17→20 yapar ve `setFontStep(3)` çağrılır; en küçükte küçült düğmesi pasif.
  - Kart: tr'de "Bu haftanın hutbesi" + başlık; bayramda "Bayram hutbesi"; en'de pdf yoksa HomeScreen kartı göstermez.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implement.**
  - Yazı boyutları `[14, 16, 17, 20, 24]`, satır yüksekliği 1.5, `AppTypography.rowTitle.copyWith(fontSize:)`.
  - Paylaş: `ShareParams(text: '$title\n$sourceUrl')`.
  - PDF ve kaynak: `openUrl` = `launchUrl(u, mode: LaunchMode.inAppBrowserView)` (HomePage'de bağlanır); false → SnackBar `sermonOpenFailed`.
  - HomeScreen: `featuredSermon` kartı `PrayerGrid`'den sonra, günün içeriğinden önce; dile göre başlık (tr: `summary.title`, en/ar: `pdfs[lang]?.title`, yoksa kart yok).
  - HomePage: `_loadSermons()` postFrame/resume'da `repository.index()` → `featured(...)`; Tools `onOpenSermons` → `SermonListScreen`.
  - ARB (tr/en/ar): `toolsSermons` Hutbe / Sermons / الخطب; `toolsSermonsHint` Diyanet'in haftalık hutbesi / Weekly sermon by Diyanet / الخطبة الأسبوعية من رئاسة الشؤون الدينية; `sermonsTitle` Hutbeler / Sermons / الخطب; `sermonKindFriday` Cuma / Friday / الجمعة; `sermonKindEid` Bayram / Eid / العيد; `sermonThisWeek` Bu haftanın hutbesi / This week's sermon / خطبة هذا الأسبوع; `sermonEid` Bayram hutbesi / Eid sermon / خطبة العيد; `sermonRead` Oku / Read / اقرأ; `sermonSource` Kaynak: Diyanet Haber / Source: Diyanet Haber / المصدر: Diyanet Haber; `sermonFootnotes` Dipnotlar / Notes / الحواشي; `sermonTextSmaller` Yazıyı küçült / Smaller text / تصغير النص; `sermonTextLarger` Yazıyı büyüt / Larger text / تكبير النص; `sermonOpenFailed` Sayfa açılamadı / Couldn't open the page / تعذّر فتح الصفحة; `sermonsEmpty` Henüz hutbe yok / No sermons yet / لا توجد خطب بعد. `flutter gen-l10n`.
  - PRIVACY: veri kaynaklarına "Hutbeler Diyanet İşleri Başkanlığı'nın yayınlarından (Diyanet Haber, Din Hizmetleri) alınır."
- [ ] **Step 4:** `flutter test` (ilgili + `test/l10n/`), analyze, format → PASS.
- [ ] **Step 5: Commit** `feat(app): hutbe listesi, okuma ekranı ve ana sayfa kartı`.

---

## Task F: Bütünleştirme ve doğrulama

- [ ] `cd server && gofmt -l . && go vet ./... && go test -race ./...`
- [ ] `flutter analyze`, `flutter test` (tüm suite)
- [ ] `flutter build apk --debug`, `FLUTTER_XCODE_ARCHS=arm64 flutter build ios --simulator --debug`
- [ ] CHANGELOG `## [Unreleased]` girişleri (Eklendi: günün içeriği, hutbe, yakındaki camiler; sunucu notları) — `docs: …` commit'i
- [ ] Teslim notu: cihazda denenmesi gerekenler (Yandex bağlantısı, Apple eski biçim iOS 17–18.3, PDF açılışı, kartların görünümü), sunucunun deploy'u `main` merge'üyle olur, ilk gece logu kontrol edilecek; Android release manifestinde INTERNET izni olmadığı (önceden var olan durum) ayrıca bildirilecek.
