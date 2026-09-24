# Diyanet il/ilçe modeli — ekranlar, GPS, migrasyon ve temizlik (Plan B2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uygulama tümüyle `vakit-api`/Diyanet yoluna geçer: konum ekleme (arama + GPS) sunucudan, GPS izleme `resolve` ile, eski kayıtlar migrasyon ekranıyla eşlenir, Aladhan/Photon/ters-geocode/hesap yöntemi katmanları silinir, gizlilik ve belgeler güncellenir.

**Architecture:** Plan B1'in veri katmanı (`DiyanetProvider`, `PlacesApi`, `LocationMigrationService`, şema 15) üzerine sunum katmanı bağlanır. Ortak bir `PlaceSearchPanel` widget'ı arama davranışını üç ekranda (ekle, düzenle, migrasyon) paylaşır; GPS çözümleme tek serviste (`GpsLocationService`) toplanır ve izleyici (`LocationMonitorService`) aynı `resolve` yolunu kullanır. Hesap parametreleri modelden kalkar; yalnız ± dakika düzeltmesi (`PrayerTuneSettings`) kalır (ADR 0004 korunur).

**Tech Stack:** Flutter/Dart, `http` (`MockClient` testleri), `geolocator` (kalır), sqflite (şema 15, sürüm artmaz), `provider`, l10n ARB (tr/en/ar).

**Spec:** `docs/superpowers/specs/2026-09-17-diyanet-uygulama-design.md` (UYG.2, UYG.3, UYG.6, UYG.7 ekran, UYG.8, UYG.9) — Plan B1: `docs/superpowers/plans/2026-09-17-diyanet-uygulama-veri-katmani.md`.

## Global Constraints

- Branch `feature/vakit-api`; her task sonunda Türkçe Conventional Commit + `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. `push`/`merge` yok.
- Kullanıcıya görünen metin Dart'a yazılmaz: `lib/l10n/app_tr.arb` (kaynak) + `app_en.arb` + `app_ar.arb`; ARB değişince `flutter gen-l10n`. `test/l10n/no_hardcoded_turkish_test.dart` "Konum", "Vakit" gibi ASCII kelimeleri de yakalar — `'Diyanet İşleri Başkanlığı'` dahil her metin l10n'dan gelir.
- `dart format` yalnız dokunulan dosyalara (`dart format <dosyalar>`); `flutter analyze` temiz; ilgili testler + task sonunda ilgili paket.
- Koordinat ve arama metni log'lanmaz (mevcut kural). Sunucuya giden koordinat `PlacesApi.resolve` içinde zaten olduğu gibi; sunucu ~100 m'ye yuvarlayıp log'lamıyor (Spec A).
- Tema token'ları `context.tokens`, tipografi `AppTypography`; ortak widget'lar `GroupedList/GroupedRow`, `SimpleAppBar`, `AppSurface`, `LocationChoiceButton`, `LocationErrorCard`, `LocationSelectionConfirm`.
- Widget testleri `test/widgets/theme_harness.dart` → `wrapWithTheme(child, appState:)` ile; l10n Türkçe koşar.
- `test/support/fakes.dart` (`FakeStorage`, `FakeProvider`, `FakeNotificationService`) ve `test/support/l10n_helper.dart` (`loadTestL10n()`) kullanılır.
- Sunucu sözleşmesi (`/v1`) değişmez. Boş arama (`q=`) sunucuda il merkezlerini (popüler önce) döner — ekran açılışta bunu gösterir.

## Spec'ten sapmalar (bilinçli)

1. **`PrayerTimeProvider` arayüzü sadeleşmez.** Spec UYG.4 "fetchYear(cityId, year)" der; Plan B1 `DiyanetProvider`'ı mevcut `fetchPrayerTimes(location, start, end)` arayüzüne yazdı ve depo sözleşmesi değişmedi. Arayüz değişikliği 6 sahte sağlayıcı ve depo testlerini tarar, kazancı yok. `location.cityId` üzerinden çalışır; spec'e not düşülür (Task 9).
2. **Düzeltme ayarının depo anahtarı `calculation_settings` kalır.** Mevcut kullanıcıların `tune` değeri kaybolmasın; `PrayerTuneSettings.fromJson` yalnız `tune`'u okur, `method/school` yok sayılır.
3. **Migrasyon ekranında aktif konum silinemez** (liste ekranındaki kuralla aynı); "Seç" ya da "Başka ilçe ara" ile çözülür. Böylece depoya "aktif konumu temizle" API'si eklenmez.
4. **Konum düzenleme ekranı** yalnız özel ad + ilçe değiştir (spec UYG.8 ile aynı); ilçe değiştirme `PlaceSearchPanel` ile ekranın içinde.

## Dosya haritası

| Dosya | Sorumluluk |
|---|---|
| `lib/presentation/screens/prayer_tune_screen.dart` (yeni) | Yalnız ± dakika düzeltmesi; `CalculationSettingsScreen`'in yerine |
| `lib/core/models/prayer_tune_settings.dart` (yeni) | `CalculationSettings` → yalnız `tune` |
| `lib/presentation/widgets/location/place_search_panel.dart` (yeni) | Arama kutusu + debounce + sonuç listesi + hata/yeniden dene; ekle/düzenle/migrasyon paylaşır |
| `lib/features/location/data/gps_location_service.dart` (yeni; `presentation/services/location_service.dart` silinir) | İzin akışı + cihaz koordinatı + `PlacesApi.resolve` → `GpsResolution`; kararlı hata anahtarları |
| `lib/presentation/utils/location_error_text.dart` (yeni) | Hata nesnesi → l10n metni (GPS anahtarları, kapsama dışı, ağ) |
| `lib/features/location/domain/location_monitor_service.dart` | Ters-geocode yerine `resolve`; yalnız `cityId` değişince olay |
| `lib/presentation/screens/location_add_screen.dart` (yeniden yazılır) | Tek ekran: arama paneli + "Konumumu kullan" + GPS onay bandı + özel ad |
| `lib/presentation/screens/location_edit_screen.dart` | Özel ad + ilçe değiştir |
| `lib/presentation/screens/location_migration_screen.dart` (yeni) | Belirsiz/desteklenmeyen kayıtlar için tek seferlik doğrulama |
| `lib/presentation/pages/app_root.dart`, `home_page.dart` | Açılışta migrasyon; eşlenmemiş aktif konumda "doğrula" durumu; GPS yenileme `GpsLocationService` |
| `lib/core/di/service_locator.dart` | `PlacesApi`, `DiyanetProvider`, `GpsLocationService`, `LocationMigrationService` kaydı |
| Silinir | `awqat_salah_provider.dart`, `photon_geocoding_service.dart`, `place_suggestion.dart`, `gps_label.dart`, `calculation_params.dart`, `calculation_settings.dart`, `regional_defaults.dart`, `calculation_settings_screen.dart`, `calculation_params_selector.dart`, `presentation/services/location_service.dart` + testleri; `geocoding` bağımlılığı |
| Belgeler | `docs/PRIVACY.md`, `docs/privacy.html`, `docs/PLAY_DATA_SAFETY.md`, `docs/adr/0006-diyanet-single-source.md` (+ README index), `README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `CHANGELOG.md`, `docs/DEVELOPMENT.md`, `.github/workflows/{android-play,ios-testflight}.yml` |

---

### Task 1: Hesap ayarı ekranı → Vakit düzeltme ekranı; düzenleme ekranı yalnız özel ad

**Files:**
- Create: `lib/presentation/screens/prayer_tune_screen.dart`, `test/widgets/screens/prayer_tune_screen_test.dart`
- Delete: `lib/presentation/screens/calculation_settings_screen.dart`, `lib/presentation/widgets/location/calculation_params_selector.dart`
- Modify: `lib/presentation/pages/home_page.dart` (`_navigateToCalculationSettings` → `_navigateToPrayerTune`; `_applyGlobalCalculationChange` silinir), `lib/presentation/screens/settings_screen.dart` (`onCalculationSettings` → `onPrayerTune`, satır başlığı), `lib/presentation/screens/location_edit_screen.dart` (override bölümü kalkar; `_save` tüm alanları korur — bugünkü kod `cityId`'yi düşürüyor), `lib/presentation/screens/location_add_screen.dart` (`RegionalDefaults` bloğu ve `locationCalculationFromGlobal` satırı kalkar), `lib/presentation/screens/location_list_screen.dart` (düzenle ikonu `Icons.edit_outlined`, yorum), `test/widgets/screens/settings_screen_test.dart`, ARB'ler (`settingsPrayerTune`)

**Interfaces:**
- Consumes: `PrayerTuneSelector(tune:, onChanged:)`, `CalculationSettings.tune` (bu task'ta model henüz değişmez).
- Produces: `class PrayerTuneScreen extends StatefulWidget { const PrayerTuneScreen({required Map<PrayerType,int> initial}); }` — kaydedince `Navigator.pop<Map<PrayerType,int>>(tune)`. `SettingsScreen.onPrayerTune: VoidCallback?`.

- [ ] **Step 1: ARB anahtarı** — `app_tr.arb` sonuna (kapanış `}` öncesi):
```json
  "settingsPrayerTune": "Vakit düzeltme",
  "@settingsPrayerTune": {"description": "Ayarlar satırı: vakit başına ± dakika düzeltmesi ekranı"}
```
`app_en.arb`: `"settingsPrayerTune": "Time adjustment"`, `app_ar.arb`: `"settingsPrayerTune": "تعديل الأوقات"`. `flutter gen-l10n`.

- [ ] **Step 2: Failing widget test** — `test/widgets/screens/prayer_tune_screen_test.dart`:
```dart
import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/presentation/screens/prayer_tune_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  testWidgets('Duzeltme ekrani baslik, ipucu ve alti vakit satirini gosterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(const PrayerTuneScreen(initial: {PrayerType.fajr: 2})),
    );

    expect(find.text('Vakit düzeltme'), findsOneWidget);
    expect(find.text('İmsak'), findsOneWidget);
    expect(find.text('Yatsı'), findsOneWidget);
    expect(find.text('+2 dk'), findsOneWidget);
  });

  testWidgets('Kaydet secilen haritayi geri doner', (tester) async {
    Map<PrayerType, int>? result;
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Map<PrayerType, int>>(
                MaterialPageRoute(
                  builder: (_) => const PrayerTuneScreen(initial: {}),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // İmsak satırındaki "+" düğmesi (ilk satır, ikinci step düğmesi).
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(result, {PrayerType.fajr: 1});
  });
}
```
`'+2 dk'` biçimi `PrayerTuneSelector`'ın değer etiketinden gelir; ekranı yazmadan önce `lib/presentation/widgets/settings/prayer_tune_selector.dart` içindeki etiket biçimini (`DurationFormatter`/`signedMinutes`) oku ve testteki beklentiyi ona göre düzelt.

- [ ] **Step 3: Run, fail** — `flutter test test/widgets/screens/prayer_tune_screen_test.dart` → derleme hatası (dosya yok).

- [ ] **Step 4: `PrayerTuneScreen`**
```dart
import 'package:flutter/material.dart';

import '../../core/models/notification_setting.dart' show PrayerType;
import '../../l10n/l10n_extensions.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/settings/prayer_tune_selector.dart';

/// Vakit başına ± dakika düzeltmesini düzenler. Kaydedilince yeni harita geri
/// döndürülür; kaydetme ve yeniden yükleme çağırana aittir. Düzeltme okurken
/// uygulandığı için (ADR 0004) önbellek geçerli kalır, yeniden çekim olmaz.
class PrayerTuneScreen extends StatefulWidget {
  final Map<PrayerType, int> initial;

  const PrayerTuneScreen({super.key, required this.initial});

  @override
  State<PrayerTuneScreen> createState() => _PrayerTuneScreenState();
}

class _PrayerTuneScreenState extends State<PrayerTuneScreen> {
  late Map<PrayerType, int> _tune;

  @override
  void initState() {
    super.initState();
    _tune = Map<PrayerType, int>.from(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(title: context.l10n.settingsPrayerTune),
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    PrayerTuneSelector(
                      tune: _tune,
                      onChanged: (value) => setState(() => _tune = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_tune),
                child: Text(context.l10n.actionSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: HomePage** — `_navigateToCalculationSettings` ve `_applyGlobalCalculationChange` silinir; yerine:
```dart
  void _navigateToPrayerTune() async {
    final storage = ServiceLocator().get<LocalStorage>();
    final current = await storage.getCalculationSettings();
    if (!mounted) return;

    final tune = await Navigator.of(context).push<Map<PrayerType, int>>(
      MaterialPageRoute(
        builder: (_) => PrayerTuneScreen(initial: current.tune),
      ),
    );
    if (tune == null || mapEquals(tune, current.tune)) return;

    await storage.saveCalculationSettings(current.copyWith(tune: tune));
    // Veri aynı, yalnızca okunuşu değişti (ADR 0004): önbellek geçerli.
    await _reloadAfterTuneChange();
  }
```
`_navigateToSettings` içindeki `onCalculationSettings: _navigateToCalculationSettings` → `onPrayerTune: _navigateToPrayerTune`. Import: `calculation_settings_screen.dart` → `prayer_tune_screen.dart`; `calculation_settings.dart` importu bu task'ta kalır (Task 3'te kalkar). `PrayerTimesRepository`/`NotificationService` importları hâlâ kullanılıyorsa kalır; analiz "unused import" derse kaldır.

- [ ] **Step 6: SettingsScreen** — alan `onCalculationSettings` → `onPrayerTune`; satır:
```dart
                _row(
                  icon: Icons.tune_rounded,
                  title: context.l10n.settingsPrayerTune,
                  onTap: widget.onPrayerTune,
                ),
```
`settings_screen_test.dart`: `onCalc` parametresi `onPrayerTune` olur; `'Hesaplama'` beklentileri `'Vakit düzeltme'`.

- [ ] **Step 7: LocationEditScreen** — `_useGlobal/_method/_school/_latitudeAdjustment/_globalSettings/_loadGlobalSettings/_buildUseGlobalSwitch/_buildGlobalSummary` ve `CalculationParamsSelector` kullanımı silinir; importlar `calculation_params/calculation_settings/grouped_list/calculation_params_selector` kalkar. `_save`:
```dart
  Future<void> _save() async {
    final customName = _customNameController.text.trim();
    final updated = widget.location.copyWith(
      customName: customName.isEmpty ? null : customName,
    );
    // copyWith `??` ile null'ı koruyamaz: özel ad silindiyse açık kurulum.
    final cleared = customName.isEmpty && widget.location.customName != null;
    final toSave = cleared ? _withoutCustomName(widget.location) : updated;
    try {
      await widget.locationRepository.updateLocation(toSave);
      if (mounted) Navigator.of(context).pop(toSave);
    } catch (e) { /* mevcut snackbar bloğu aynen */ }
  }

  static Location _withoutCustomName(Location location) => Location(
    id: location.id,
    province: location.province,
    district: location.district,
    latitude: location.latitude,
    longitude: location.longitude,
    type: location.type,
    method: location.method,
    school: location.school,
    latitudeAdjustmentMethod: location.latitudeAdjustmentMethod,
    cityId: location.cityId,
    stateId: location.stateId,
    countryId: location.countryId,
    displayLabel: location.displayLabel,
  );
```
(`method/school/latitudeAdjustmentMethod` satırları Task 3'te silinir.) `build` içinde `ListView` çocukları: `_buildLocationHeader()`, `SizedBox(24)`, `_buildCustomNameField()`. Sınıf doc yorumu: "Kayıtlı bir konumun özel adını düzenler; ilçe değiştirme Task 6'da eklenir."

- [ ] **Step 8: LocationAddScreen (asgari)** — `regional_defaults.dart` importu, `_selectedCountryCode`, `_saveAndReturn`'deki `countryCode` parametresi ve `isFirstLocation/RegionalDefaults` bloğu, `_buildConfigSection` içindeki `locationCalculationFromGlobal` `Row`'u silinir. `LocationListScreen._editButton`: `Icons.tune_rounded` → `Icons.edit_outlined`; "Aktif konum da duzenlenebilmeli (hesaplama parametreleri)" yorumu "…(özel ad)" olur.

- [ ] **Step 9: Doğrula** — `dart format <dokunulan>`, `flutter analyze`, `flutter test test/widgets/screens/ test/location/`. Beklenen: PASS.

- [ ] **Step 10: Commit**
```bash
git add -A lib test
git commit -m "refactor(ayarlar): hesap yöntemi ekranı yerine vakit düzeltme ekranı; konum düzenleme yalnız özel ad

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: DI geçişi — `DiyanetProvider` etkin, Aladhan sağlayıcısı silinir

**Files:**
- Modify: `lib/core/di/service_locator.dart`, `lib/presentation/screens/settings_screen.dart` (`dataSource` varsayılanı l10n), `lib/presentation/pages/home_page.dart` (`dataSource` geçiriliyorsa kaldır), `test/error_handling/parse_error_test.dart` (yalnız "Storage" grubu kalır), `test/widgets/screens/settings_screen_test.dart` (`'Aladhan API'` → `'Diyanet İşleri Başkanlığı'`), `test/setup/setup_test.dart` (Aladhan referansı varsa), `test/l10n/no_hardcoded_turkish_test.dart` (`allowed` haritasından silinen dosyalar), ARB (`dataSourceDiyanet`)
- Delete: `lib/features/prayer_times/data/awqat_salah_provider.dart`, `test/prayer_times/rate_limit_test.dart`, `test/prayer_times/calculation_params_url_test.dart`

**Interfaces:**
- Consumes: `DiyanetProvider({required http.Client client, required LocalStorage storage, String baseUrl = VakitApiConfig.baseUrl})`, `PlacesApi({required http.Client client, String baseUrl})`.
- Produces: `ServiceLocator` kayıtları: `PlacesApi`, `PrayerTimeProvider` = `DiyanetProvider`.

- [ ] **Step 1: ARB** — `dataSourceDiyanet`: tr `"Diyanet İşleri Başkanlığı"`, en `"Presidency of Religious Affairs (Diyanet)"`, ar `"رئاسة الشؤون الدينية (ديانت)"`; description "Ayarlar > Bilgi > Veri kaynağı değeri". `flutter gen-l10n`.

- [ ] **Step 2: Test güncelle (önce kırmızı)** — `settings_screen_test.dart` "Veri kaynagi ve gizlilik satirlari BILGI altinda": `expect(find.text('Diyanet İşleri Başkanlığı'), findsOneWidget);`. Çalıştır → FAIL (`Aladhan API` yazıyor).

- [ ] **Step 3: ServiceLocator** — `awqat_salah_provider.dart` importu yerine `diyanet_provider.dart` ve `places_api.dart`; sıra: `LocalStorage` **önce** kurulur (sağlayıcı ETag için depoya bağlı):
```dart
    logger.debug('Initializing Local Storage (SQLite)');
    final localStorage = SqliteStorage();
    register<LocalStorage>(localStorage);

    register<PlacesApi>(PlacesApi(client: httpClient));

    logger.debug('Initializing Prayer Time Provider (Diyanet / vakit-api)');
    final PrayerTimeProvider prayerTimeProvider = DiyanetProvider(
      client: httpClient,
      storage: localStorage,
    );
    register<PrayerTimeProvider>(prayerTimeProvider);
```
(`PrayerTimesRepository` kurulumu bunların altında kalır.)

- [ ] **Step 4: SettingsScreen** — `dataSource` parametresi kalkar; satır değeri `context.l10n.dataSourceDiyanet`. `home_page.dart` `SettingsScreen(` çağrısında `dataSource:` geçiliyorsa sil.

- [ ] **Step 5: Aladhan'ı sil** — `git rm lib/features/prayer_times/data/awqat_salah_provider.dart test/prayer_times/rate_limit_test.dart test/prayer_times/calculation_params_url_test.dart`. `parse_error_test.dart`: "API Provider" ve "Integration" grupları ve `AwqatSalahProvider`/`MockClient` importları silinir; "Storage" grubu (ParseException davranışı) kalır. `setup_test.dart`'ta `AwqatSalahProvider` geçiyorsa (`grep -n AwqatSalah test/setup/setup_test.dart`) o test silinir. `no_hardcoded_turkish_test.dart` `allowed` haritasından `lib/features/location/data/photon_geocoding_service.dart` **Task 6'da**, `calculation_params.dart` **Task 3'te** kalkar (dosyalar o zaman siliniyor).

- [ ] **Step 6: Doğrula** — `grep -rn "AwqatSalah\|awqat_salah" lib test` boş; `flutter analyze`; `flutter test test/widgets/screens/settings_screen_test.dart test/error_handling test/setup test/prayer_times`.

- [ ] **Step 7: Commit** — `feat(vakit): uygulama Diyanet sağlayıcısına geçti; Aladhan sağlayıcısı kaldırıldı`.

---

### Task 3: `PrayerTuneSettings` — hesap parametreleri modelden, depodan ve kataloglardan silinir

**Files:**
- Create: `lib/core/models/prayer_tune_settings.dart`
- Delete: `lib/core/models/calculation_settings.dart`, `lib/core/models/calculation_params.dart`, `lib/core/models/regional_defaults.dart`, `test/models/regional_defaults_test.dart`
- Modify: `lib/core/interfaces/local_storage.dart`, `lib/features/prayer_times/data/sqlite_storage.dart`, `lib/core/models/location.dart`, `lib/features/prayer_times/domain/prayer_times_repository.dart`, `lib/features/prayer_times/domain/prayer_time_tuner.dart` (**hijri korunur — mevcut hata**), `lib/features/location/domain/location_repository.dart`, `lib/features/location/domain/location_service.dart`, `lib/presentation/pages/home_page.dart`, `lib/presentation/screens/location_edit_screen.dart`, `lib/l10n/l10n_extensions.dart` (`asrSchoolLabel`, `latitudeAdjustmentLabel` silinir), sahte depolar: `test/support/fakes.dart`, `test/location/location_feature_test.dart`, `test/setup/setup_test.dart`, `test/prayer_times/prayer_times_data_layer_test.dart`, `test/notifications/notifications_test.dart`, `test/offline/offline_behavior_test.dart`; testler: `test/models/models_test.dart`, `test/prayer_times/prayer_time_tuner_test.dart`, `test/ramadan/imsakiye_test.dart`, `test/location/location_feature_test.dart`, `test/ramadan/gps_imsakiye_cache_test.dart`

**Interfaces:**
- Produces:
```dart
class PrayerTuneSettings {
  final Map<PrayerType, int> tune;
  const PrayerTuneSettings({this.tune = const {}});
  static const PrayerTuneSettings none = PrayerTuneSettings();
  Map<String, dynamic> toJson();            // {'tune': {...}} — sıfırlar yazılmaz
  factory PrayerTuneSettings.fromJson(Map<String, dynamic> json); // yalnız 'tune' okur
  PrayerTuneSettings copyWith({Map<PrayerType, int>? tune});
  ==, hashCode (tune sırasız)
}
// LocalStorage
Future<PrayerTuneSettings> getPrayerTuneSettings();
Future<void> savePrayerTuneSettings(PrayerTuneSettings settings);
```
- `Location`: `method/school/latitudeAdjustmentMethod`, `withResolvedParams`, `hasCalculationOverride` kalkar; `fromJson` eski anahtarları yok sayar.
- `LocationService.changeLocation`: aynı `id` ve aynı `cityId` → yalnız aktif kayıt tazelenir (koordinat/ad; kıble), önbellek/bildirim dokunulmaz; `cityId` değiştiyse önbellek temizlenir + bildirimler iptal.
- `LocationRepository.saveOrUpdateGpsLocation`: önbellek yalnız `cityId` değişince temizlenir.

- [ ] **Step 1: Failing tests**

`test/prayer_times/prayer_time_tuner_test.dart` — `CalculationSettings` testini şu ikisiyle değiştir:
```dart
  test('PrayerTuneSettings JSON round-trip: sifirlar yazilmaz', () {
    const settings = PrayerTuneSettings(
      tune: {PrayerType.fajr: 2, PrayerType.isha: 0, PrayerType.asr: -1},
    );
    final json = settings.toJson();
    expect(json['tune'], {'fajr': 2, 'asr': -1});
    expect(PrayerTuneSettings.fromJson(json), settings.copyWith(tune: {PrayerType.fajr: 2, PrayerType.asr: -1}));
  });

  test('Eski calculation_settings JSON okunur; method/school yok sayilir', () {
    final settings = PrayerTuneSettings.fromJson({
      'method': 13,
      'school': 0,
      'tune': {'fajr': 3},
    });
    expect(settings.tune, {PrayerType.fajr: 3});
    expect(settings.toJson().containsKey('method'), isFalse);
  });

  test('Duzeltme uygulanan gun Hicri tarihini korur', () {
    final day = PrayerTime(
      date: DateTime(2026, 8, 1),
      fajr: DateTime(2026, 8, 1, 4),
      sunrise: DateTime(2026, 8, 1, 6),
      dhuhr: DateTime(2026, 8, 1, 13),
      asr: DateTime(2026, 8, 1, 17),
      maghrib: DateTime(2026, 8, 1, 20),
      isha: DateTime(2026, 8, 1, 22),
      hijri: const HijriDate(day: 18, month: 2, year: 1448),
    );
    final tuned = PrayerTimeTuner.applyOne(day, {PrayerType.fajr: 2});
    expect(tuned.fajr, DateTime(2026, 8, 1, 4, 2));
    expect(tuned.hijri, day.hijri);
  });
```
`test/models/models_test.dart` — "Location calculation params", "CalculationSettings", "CalculationMethods catalog" grupları silinir; yerine:
```dart
  group('Location legacy JSON', () {
    test('method/school anahtarlari yok sayilir, Diyanet alanlari okunur', () {
      final location = Location.fromJson({
        'id': 'p1', 'province': 'İstanbul', 'district': 'Şile',
        'method': 13, 'school': 0, 'latitudeAdjustmentMethod': 3,
        'cityId': 9547, 'stateId': 539, 'countryId': 2,
      });
      expect(location.cityId, 9547);
      expect(location.isMapped, isTrue);
      expect(location.toJson().containsKey('method'), isFalse);
    });
  });
```
`test/location/location_feature_test.dart` — "Same location with changed calc params clears cache and reschedules" testi şu hâle gelir (aynı yerde):
```dart
    test('Same id with changed district clears cache and cancels notifications', () async {
      const base = Location(id: 'gps', province: 'İstanbul', district: 'Şile', type: LocationType.gps, cityId: 9547, latitude: 41.17, longitude: 29.61);
      await locationService.changeLocation(base);
      await storage.savePrayerTimes([/* mevcut PrayerTime örneği */], base.id);
      provider.fetchCallCount = 0;
      notificationService.cancelAllCallCount = 0;

      final moved = base.copyWith(province: 'Ankara', district: 'Ankara', cityId: 9206, latitude: 39.9, longitude: 32.8);
      await locationService.changeLocation(moved);

      expect(storage.cacheForTesting.containsKey(base.id), isFalse);
      expect(notificationService.cancelAllCallCount, equals(1));
      expect(provider.fetchCallCount, equals(0));
      expect((await locationService.getActiveLocation())!.cityId, 9206);
    });

    test('Same id and district with new coordinates only refreshes the active record', () async {
      const base = Location(id: 'gps', province: 'İstanbul', district: 'Şile', type: LocationType.gps, cityId: 9547, latitude: 41.17, longitude: 29.61);
      await locationService.changeLocation(base);
      await storage.savePrayerTimes([/* aynı örnek */], base.id);
      notificationService.cancelAllCallCount = 0;

      final nudged = base.copyWith(latitude: 41.18);
      await locationService.changeLocation(nudged);

      expect(storage.cacheForTesting.containsKey(base.id), isTrue);
      expect(notificationService.cancelAllCallCount, equals(0));
      expect((await locationService.getActiveLocation())!.latitude, 41.18);
    });
```
`test/ramadan/gps_imsakiye_cache_test.dart` — `gps` sabitine `cityId: 9547` ekle; "GPS update invalidates…" testinde `gps.copyWith(id: 'another-incoming', latitude: 39, longitude: 32)` → `gps.copyWith(id: 'another-incoming', latitude: 39, longitude: 32, cityId: 9206)`; yeni koordinat ama aynı `cityId` için temizlenmediğini de doğrula (`saveOrUpdateGpsLocation(gps.copyWith(latitude: 41.2))` → `cleared` değişmez). `CoordinateProvider.requested.latitude` beklentileri kalır (sağlayıcı `Location` alıyor).

`test/prayer_times/prayer_times_data_layer_test.dart` — `withResolvedParams`/override ile ilgili iki test ("global ayar uygulanmalı", "override…") silinir. `test/ramadan/imsakiye_test.dart:92` → `storage.savePrayerTuneSettings(const PrayerTuneSettings(tune: {PrayerType.fajr: 3}))`.

- [ ] **Step 2: Run, fail** — `flutter test test/prayer_times/prayer_time_tuner_test.dart test/models/models_test.dart` → derleme hatası.

- [ ] **Step 3: `PrayerTuneSettings`**
```dart
import 'notification_setting.dart' show PrayerType;

/// Vakit başına ± dakika düzeltmesi (kullanıcı ayarı).
///
/// Diyanet tablosu hesap değil veridir; kullanıcının değiştirebildiği tek şey
/// bu kaydırmadır. Yerelde, okuma anında uygulanır (bkz. `PrayerTimeTuner`,
/// ADR 0004); sıfır değerler saklanmaz.
///
/// Depo anahtarı geçmişten `calculation_settings` olarak kalır: eski JSON'daki
/// `method`/`school` alanları yok sayılır, `tune` korunur.
class PrayerTuneSettings {
  final Map<PrayerType, int> tune;

  const PrayerTuneSettings({this.tune = const {}});

  static const PrayerTuneSettings none = PrayerTuneSettings();

  Map<String, dynamic> toJson() => {
    if (tune.isNotEmpty)
      'tune': {
        for (final entry in tune.entries)
          if (entry.value != 0) entry.key.name: entry.value,
      },
  };

  factory PrayerTuneSettings.fromJson(Map<String, dynamic> json) =>
      PrayerTuneSettings(tune: _tuneFromJson(json['tune']));

  static Map<PrayerType, int> _tuneFromJson(Object? raw) {
    if (raw is! Map) return const {};
    final result = <PrayerType, int>{};
    for (final entry in raw.entries) {
      final minutes = entry.value;
      if (minutes is! int || minutes == 0) continue;
      for (final type in PrayerType.values) {
        if (type.name == entry.key) result[type] = minutes;
      }
    }
    return result;
  }

  PrayerTuneSettings copyWith({Map<PrayerType, int>? tune}) =>
      PrayerTuneSettings(tune: tune ?? this.tune);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerTuneSettings &&
          runtimeType == other.runtimeType &&
          _sameTune(tune, other.tune);

  static bool _sameTune(Map<PrayerType, int> a, Map<PrayerType, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered([
    for (final entry in tune.entries) Object.hash(entry.key, entry.value),
  ]);
}
```

- [ ] **Step 4: Depo arayüzü ve SQLite** — `local_storage.dart`: import ve iki metot `getPrayerTuneSettings/savePrayerTuneSettings`. `sqlite_storage.dart`: `_tuneSettingsKey = 'calculation_settings'` sabiti (yorum: geçmiş anahtar, tune korunur); `getPrayerTuneSettings` `PrayerTuneSettings.fromJson`, hata durumunda `PrayerTuneSettings.none`; `saveLocation/updateLocation` `'method'/'school'/'latitude_adjustment'` satırlarını yazmaz; `getSavedLocations` (ve varsa `getActiveLocation` satır eşlemesi) bu sütunları okumaz. Şema sürümü **değişmez**; sütunlar kalır.

- [ ] **Step 5: `Location`** — üç alan, `withResolvedParams`, `hasCalculationOverride`, `calculation_settings.dart` importu kalkar; `fromJson`'daki `method/school/latitudeAdjustmentMethod` satırları silinir (anahtarlar yok sayılır); `toJson/copyWith/==/hashCode` güncellenir. `displayName` yorumundaki Photon cümlesi: "İl merkezinde sunucu `displayLabel` verir; yedek olarak iki alan aynıysa tek ad yazılır."

- [ ] **Step 6: Depo/servisler** — `PrayerTimesRepository`: `_resolveLocation` silinir, `provider.fetchPrayerTimes(location: location, …)` / `fetchDailyPrayerTime(location: location, …)`; `_tuned/_tunedOne` `storage.getPrayerTuneSettings()`; `clearAllCache` kullanılmıyorsa (`grep -rn clearAllCache lib`) silinir, testteki (`cache_invalidation_test`) çağrı `clearCacheForLocation` ile yeniden yazılır ya da metot kalır — kullanan test varsa **kalır**. `PrayerTimeTuner.applyOne`:
```dart
  static PrayerTime applyOne(PrayerTime time, Map<PrayerType, int> tune) {
    if (_isEmpty(tune)) return time;
    // copyWith: Hicri gibi vakit dışı alanlar korunur.
    return time.copyWith(
      fajr: _shift(time.fajr, tune[PrayerType.fajr]),
      sunrise: _shift(time.sunrise, tune[PrayerType.sunrise]),
      dhuhr: _shift(time.dhuhr, tune[PrayerType.dhuhr]),
      asr: _shift(time.asr, tune[PrayerType.asr]),
      maghrib: _shift(time.maghrib, tune[PrayerType.maghrib]),
      isha: _shift(time.isha, tune[PrayerType.isha]),
    );
  }
```
Sınıf yorumundaki "Aladhan'ın `tune` parametresiyle değil" cümlesi "sunucudan düzeltilmiş veri istenmez" olur. `LocationRepository`: `getCalculationSettings/saveCalculationSettings` ve importu silinir; `saveOrUpdateGpsLocation` koşulu `existingGps.cityId != updatedLocation.cityId`. `LocationService.changeLocation`:
```dart
  Future<void> changeLocation(Location newLocation) async {
    final oldLocation = await locationRepository.getActiveLocation();
    final sameLocation = oldLocation?.id == newLocation.id;
    final districtChanged =
        oldLocation != null && oldLocation.cityId != newLocation.cityId;

    if (sameLocation && !districtChanged) {
      // Aynı ilçe: koordinat/ad tazelenir (kıble), önbellek ve bildirimler geçerli.
      if (oldLocation != newLocation) {
        await locationRepository.setActiveLocation(newLocation);
      }
      return;
    }

    if (sameLocation && districtChanged) {
      await prayerTimesRepository.clearCacheForLocation(newLocation.id);
    }

    await locationRepository.setActiveLocation(newLocation);
    await notificationService?.cancelAllNotifications();
  }
```
`_calcParamsChanged` silinir. `home_page.dart`: `_navigateToPrayerTune` → `getPrayerTuneSettings()` / `savePrayerTuneSettings(current.copyWith(tune: tune))`; `calculation_settings.dart` importu → `prayer_tune_settings.dart`. `location_edit_screen.dart` `_withoutCustomName`: üç satır silinir. `l10n_extensions.dart`: `calculation_params.dart` importu ve iki etiket fonksiyonu silinir (ARB anahtarları Task 8'de).

- [ ] **Step 7: Sahte depolar** — altı dosyada `CalculationSettings _calculationSettings = CalculationSettings.defaults;` → `PrayerTuneSettings _tuneSettings = PrayerTuneSettings.none;`, metotlar `getPrayerTuneSettings/savePrayerTuneSettings`, importlar `prayer_tune_settings.dart`. `test/support/fakes.dart` içinde `FakeProvider.lastLocation` kalır.

- [ ] **Step 8: Katalogları sil** — `git rm lib/core/models/calculation_params.dart lib/core/models/calculation_settings.dart lib/core/models/regional_defaults.dart test/models/regional_defaults_test.dart`; `no_hardcoded_turkish_test.dart` `allowed` haritasından `calculation_params.dart` satırı silinir. `grep -rn "CalculationSettings\|CalculationDefaults\|CalculationMethods\|AsrSchool\|LatitudeAdjustment\|RegionalDefaults\|withResolvedParams\|hasCalculationOverride\|latitudeAdjustmentMethod" lib test` boş olmalı.

- [ ] **Step 9: Doğrula** — `flutter analyze`; `flutter test` (tam suite: depo arayüzü değişti). Beklenen: PASS.

- [ ] **Step 10: Commit** — `refactor(model): hesap yöntemi/mezhep/enlem ayarı kalktı; yalnız vakit düzeltmesi (PrayerTuneSettings) kaldı`.

---

### Task 4: `PlaceSearchPanel` — paylaşılan arama paneli

**Files:**
- Create: `lib/presentation/widgets/location/place_search_panel.dart`, `test/widgets/location/place_search_panel_test.dart`
- Modify: ARB'ler

**Interfaces:**
- Consumes: `PlacesApi.search(query, {limit})`, `PlaceMatch{displayName, matchedAlias}`, `NoCoverageException`, `PlacesNotReadyException`, `ApiException`.
- Produces:
```dart
class PlaceSearchPanel extends StatefulWidget {
  const PlaceSearchPanel({super.key, required PlacesApi api, required ValueChanged<PlaceMatch> onSelected, bool autofocus = true});
  static const Duration debounce = Duration(milliseconds: 300);
  static const int minQueryLength = 2;
  static const int resultLimit = 10;
}
```
Davranış: açılışta `search('')` (il merkezleri); yazınca 300 ms debounce, `< 2` karakterde istek yok (mevcut liste kalır); satır `displayName`, `matchedAlias` doluysa alt satır `placeAliasIncluded(alias)`; boş sonuç → `locationSearchNoResult`; hata (`SocketException`, `TimeoutException`, `ApiException`, `PlacesNotReadyException`, `ParseException`) → `locationNeedsInternet` + `actionRetry` (aynı sorguyu yineler); istek sonuçları yarış korumalı (son sorgu kazanır).

- [ ] **Step 1: ARB** (tr / en / ar):
```json
  "placeAliasIncluded": "{alias} buna dahil",
  "@placeAliasIncluded": {"description": "Arama sonucunda eşanlam: seçilen ilçe bu adı kapsar", "placeholders": {"alias": {"type": "String"}}},
  "locationNeedsInternet": "Konum eklemek için internet gerekli.",
  "@locationNeedsInternet": {"description": "Arama/GPS çözümleme sunucuya ulaşamadı"},
  "locationSearchPlaceholder": "İl veya ilçe ara...",
  "locationSearchNoResult": "Sonuç bulunamadı.\nİl ya da ilçe adını kontrol et."
```
en: `"{alias} is included"`, `"Adding a location needs an internet connection."`, `"Search province or district..."`, `"No results.\nCheck the province or district name."`; ar: `"يشمل {alias}"`, `"إضافة موقع تتطلب اتصالاً بالإنترنت."`, `"ابحث عن محافظة أو قضاء..."`, `"لا توجد نتائج.\nتحقق من اسم المحافظة أو القضاء."`. (`locationSearchPlaceholder`/`locationSearchNoResult` mevcut anahtarlar; değerleri güncellenir.) `flutter gen-l10n`.

- [ ] **Step 2: Failing widget test** — `test/widgets/location/place_search_panel_test.dart`:
```dart
import 'dart:convert';

import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/presentation/widgets/location/place_search_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../theme_harness.dart';

const _headers = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _match(int id, String name, String state, {bool centre = false, String? alias}) => {
  'id': id, 'name': name, 'stateName': state,
  'displayName': centre ? '$name (Merkez)' : '$name, $state',
  'stateId': 539, 'countryId': 2, 'isCentre': centre,
  'latitude': 41.0, 'longitude': 29.0, 'matchedAlias': ?alias,
};

http.Response _ok(List<Map<String, dynamic>> results) =>
    http.Response(jsonEncode({'query': '', 'results': results}), 200, headers: _headers);

void main() {
  late List<String> queries;
  setUp(() => queries = []);

  Widget panel(Future<http.Response> Function(http.Request) handler, {ValueChanged<PlaceMatch>? onSelected}) =>
      wrapWithTheme(PlaceSearchPanel(
        api: PlacesApi(client: MockClient((req) { queries.add(req.url.queryParameters['q'] ?? ''); return handler(req); }), baseUrl: 'https://api.test'),
        onSelected: onSelected ?? (_) {},
      ));

  testWidgets('Acilista bos sorguyla il merkezleri listelenir', (tester) async {
    await tester.pumpWidget(panel((_) async => _ok([_match(9541, 'İstanbul', 'İstanbul', centre: true), _match(9206, 'Ankara', 'Ankara', centre: true)])));
    await tester.pump();

    expect(queries, ['']);
    expect(find.text('İstanbul (Merkez)'), findsOneWidget);
    expect(find.text('Ankara (Merkez)'), findsOneWidget);
  });

  testWidgets('Yazinca 300 ms sonra tek istek atilir; alias alt satirda', (tester) async {
    await tester.pumpWidget(panel((req) async {
      final q = req.url.queryParameters['q'];
      if (q == 'kadik') return _ok([_match(9541, 'İstanbul', 'İstanbul', centre: true, alias: 'Kadıköy')]);
      return _ok([]);
    }));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'k');
    await tester.pump(const Duration(milliseconds: 350));
    expect(queries, [''], reason: '2 karakterden kisa sorgu istek atmaz');

    await tester.enterText(find.byType(TextField), 'kadi');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'kadik');
    await tester.pump(const Duration(milliseconds: 350));

    expect(queries, ['', 'kadik'], reason: 'debounce ara sorguyu yutar');
    expect(find.text('İstanbul (Merkez)'), findsOneWidget);
    expect(find.text('Kadıköy buna dahil'), findsOneWidget);
  });

  testWidgets('Satira dokunmak secimi bildirir', (tester) async {
    PlaceMatch? selected;
    await tester.pumpWidget(panel((_) async => _ok([_match(9547, 'Şile', 'İstanbul')]), onSelected: (m) => selected = m));
    await tester.pump();

    await tester.tap(find.text('Şile, İstanbul'));
    expect(selected?.id, 9547);
  });

  testWidgets('Sonuc yoksa mesaj, sunucu hatasinda internet uyarisi ve yeniden dene', (tester) async {
    var fail = true;
    await tester.pumpWidget(panel((_) async => fail ? http.Response('', 503) : _ok([])));
    await tester.pump();

    expect(find.text('Konum eklemek için internet gerekli.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Yeniden Dene'));
    await tester.pump();

    expect(find.textContaining('Sonuç bulunamadı'), findsOneWidget);
    expect(queries, ['', '']);
  });
}
```

- [ ] **Step 3: Run, fail** — derleme hatası.

- [ ] **Step 4: `PlaceSearchPanel`**
```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/app_logger.dart';
import '../../../features/location/data/places_api.dart';
import '../../../l10n/l10n_extensions.dart';

/// Sunucuda il/ilçe arar: kutu + debounce + sonuç listesi.
///
/// Açılışta boş sorgu gönderilir; sunucu il merkezlerini (popüler önce) döner,
/// kullanıcı hiç yazmadan büyük şehirleri görür. Yazarken 300 ms bekler; 2
/// karakterden kısa sorguda istek atılmaz. Ağ/sunucu hatası "internet gerekli"
/// + yeniden dene olur; arama metni log'lanmaz.
class PlaceSearchPanel extends StatefulWidget {
  final PlacesApi api;
  final ValueChanged<PlaceMatch> onSelected;
  final bool autofocus;

  static const Duration debounce = Duration(milliseconds: 300);
  static const int minQueryLength = 2;
  static const int resultLimit = 10;

  const PlaceSearchPanel({
    super.key,
    required this.api,
    required this.onSelected,
    this.autofocus = true,
  });

  @override
  State<PlaceSearchPanel> createState() => _PlaceSearchPanelState();
}

class _PlaceSearchPanelState extends State<PlaceSearchPanel> {
  final _controller = TextEditingController();
  Timer? _timer;
  int _requestSeq = 0;

  List<PlaceMatch> _results = const [];
  bool _searching = false;
  bool _failed = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _search('');
      return;
    }
    if (query.length < PlaceSearchPanel.minQueryLength) return;
    _timer = Timer(PlaceSearchPanel.debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final seq = ++_requestSeq;
    setState(() {
      _searching = true;
      _failed = false;
      _lastQuery = query;
    });
    try {
      final results = await widget.api.search(
        query,
        limit: PlaceSearchPanel.resultLimit,
      );
      if (!mounted || seq != _requestSeq) return; // geç gelen eski cevap
      setState(() {
        _results = results;
        _searching = false;
      });
    } on Exception catch (e) {
      // SocketException, TimeoutException, ApiException, PlacesNotReadyException,
      // ParseException: hepsi kullanıcı için "sunucuya ulaşılamadı".
      if (!mounted || seq != _requestSeq) return;
      AppLogger().warning('Place search failed', e);
      setState(() {
        _results = const [];
        _searching = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildField(),
        const SizedBox(height: 12),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildField() {
    final tokens = context.tokens;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        style: TextStyle(color: tokens.textPrimary),
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: context.l10n.locationSearchPlaceholder,
          hintStyle: TextStyle(color: tokens.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          prefixIcon: Icon(Icons.search_rounded, color: tokens.textTertiary),
          suffixIcon: _buildSuffix(),
        ),
      ),
    );
  }

  Widget? _buildSuffix() {
    final tokens = context.tokens;
    if (_searching) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent),
        ),
      );
    }
    if (_controller.text.isNotEmpty) {
      return IconButton(
        icon: Icon(Icons.close_rounded, color: tokens.textTertiary),
        onPressed: () {
          _controller.clear();
          _onChanged('');
        },
      );
    }
    return null;
  }

  Widget _buildBody() {
    final tokens = context.tokens;
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.locationNeedsInternet,
              textAlign: TextAlign.center,
              style: AppTypography.rowSubtitle.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _search(_lastQuery),
              child: Text(context.l10n.actionRetry),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      if (_searching) return const SizedBox.shrink();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.locationSearchNoResult,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textTertiary, fontSize: 14, height: 1.5),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: _results.length,
      itemBuilder: (context, index) => _tile(_results[index]),
    );
  }

  Widget _tile(PlaceMatch match) {
    final tokens = context.tokens;
    final alias = match.matchedAlias;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        widget.onSelected(match);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.surface),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, color: tokens.textTertiary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.displayName, style: TextStyle(color: tokens.textPrimary, fontSize: 15)),
                  if (alias != null)
                    Text(
                      context.l10n.placeAliasIncluded(alias),
                      style: AppTypography.hint.copyWith(color: tokens.textTertiary),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```
Not: `dart:io` yalnız `SocketException` yakalamak için gerekmez — `on Exception` hepsini kapsıyor; importu ekleme. Test "Yeniden Dene" `actionRetry` değeriyle ("Yeniden Dene") eşleşir.

- [ ] **Step 5: Run, pass** — `flutter test test/widgets/location/`.

- [ ] **Step 6: Commit** — `feat(konum): sunucu tabanlı il/ilçe arama paneli (PlaceSearchPanel)`.

---

### Task 5: GPS çözümleme tek yoldan — `GpsLocationService` ve izleyici `resolve` kullanır

**Files:**
- Create: `lib/features/location/data/gps_location_service.dart`, `lib/presentation/utils/location_error_text.dart`, `test/location/location_monitor_service_test.dart` (genişler), `test/presentation/location_error_text_test.dart`
- Delete: `lib/presentation/services/location_service.dart` (`GpsLocationService` eski)
- Modify: `lib/features/location/domain/location_monitor_service.dart`, `lib/core/di/service_locator.dart`, `lib/presentation/pages/home_page.dart` (`_manualGpsRefresh`, `_gpsErrorText`), ARB (`locationNoCoverage`)

**Interfaces:**
- Produces:
```dart
class GpsLocationException implements Exception { final String key; const GpsLocationException(this.key); }
class GpsResolution { final Location location; final double distanceKm; }
class GpsLocationService {
  GpsLocationService({required PlacesApi api});
  static const String gpsLocationId = 'gps';
  static const String servicesOffKey = 'location_services_off';
  static const String permissionRequiredKey = 'location_permission_required';
  static const String permissionDeniedForeverKey = 'location_permission_denied_forever';
  /// İzin `denied` ise [requestPermission] çağrılır; `true` dönerse sistem izni
  /// istenir. Verilmezse izin yokken [permissionRequiredKey] fırlatılır.
  Future<GpsResolution> locate({Future<bool> Function()? requestPermission});
  /// Koordinatı sunucuda ilçeye çözer (izleyici ve locate bunu kullanır).
  Future<GpsResolution> resolve(double latitude, double longitude, {String? customName});
}
// presentation/utils/location_error_text.dart
String locationErrorText(AppLocalizations l10n, Object error);
```
- `LocationMonitorService({required LocationRepository locationRepository, required GpsLocationService gps})`; `@visibleForTesting Future<void> handleFix(Coordinates current, {DateTime? now})`.

- [ ] **Step 1: ARB** — `locationNoCoverage`: tr `"Bu bölge henüz desteklenmiyor; ilçeni ara ve seç."`, en `"This area isn't supported yet; search and pick your district."`, ar `"هذه المنطقة غير مدعومة بعد؛ ابحث عن قضائك واختره."`; `locationPermissionDenied` (mevcut) kalır; `locationServicesOff` kalır. `flutter gen-l10n`.

- [ ] **Step 2: Failing tests**

`test/presentation/location_error_text_test.dart`:
```dart
import 'dart:io';

import 'package:ezanvakti/core/exceptions/api_exception.dart';
import 'package:ezanvakti/features/location/data/gps_location_service.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/presentation/utils/location_error_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/l10n_helper.dart';

void main() {
  test('hata nesnesi kullaniciya uygun metne cevrilir', () async {
    final l10n = await loadTestL10n();
    expect(locationErrorText(l10n, const GpsLocationException(GpsLocationService.permissionRequiredKey)), l10n.errorLocationPermission);
    expect(locationErrorText(l10n, const GpsLocationException(GpsLocationService.servicesOffKey)), l10n.locationServicesOff);
    expect(locationErrorText(l10n, const GpsLocationException(GpsLocationService.permissionDeniedForeverKey)), l10n.locationPermissionDenied);
    expect(locationErrorText(l10n, NoCoverageException()), l10n.locationNoCoverage);
    expect(locationErrorText(l10n, PlacesNotReadyException()), l10n.locationNeedsInternet);
    expect(locationErrorText(l10n, const SocketException('x')), l10n.locationNeedsInternet);
    expect(locationErrorText(l10n, ApiException(500, context: 'x')), l10n.locationNeedsInternet);
    expect(locationErrorText(l10n, Exception('boom')), l10n.errorGenericWith('Exception: boom'));
  });
}
```
(`ApiException` kurucusunu `lib/core/exceptions/api_exception.dart`'tan doğrula; `NoCoverageException`/`PlacesNotReadyException` `const` değilse `()` ile kur.)

`test/location/location_monitor_service_test.dart` — mevcut `isSignificantLocationChange` testleri kalır; ekle:
```dart
  group('handleFix', () {
    const _h = {'content-type': 'application/json; charset=utf-8'};
    Map<String, dynamic> city(int id, String name, String state) => {
      'id': id, 'name': name, 'stateName': state, 'displayName': '$name, $state',
      'stateId': 539, 'countryId': 2, 'isCentre': false, 'latitude': 41.17, 'longitude': 29.61,
    };
    http.Response resolved(Map<String, dynamic> c) =>
        http.Response(jsonEncode({'city': c, 'distanceKm': 1.2}), 200, headers: _h);
    const sile = Location(id: 'gps', province: 'İstanbul', district: 'Şile', type: LocationType.gps, cityId: 9547, latitude: 41.17, longitude: 29.61);

    late FakeStorage storage;
    late List<String> cleared;
    late List<Location> events;

    LocationMonitorService service(Future<http.Response> Function(http.Request) handler) {
      final repo = LocationRepository(storage: storage, clearPrayerCache: (id) async => cleared.add(id));
      final s = LocationMonitorService(
        locationRepository: repo,
        gps: GpsLocationService(api: PlacesApi(client: MockClient(handler), baseUrl: 'https://api.test')),
      );
      s.onLocationChanged.listen(events.add);
      return s;
    }

    setUp(() async {
      storage = FakeStorage();
      cleared = [];
      events = [];
      await storage.saveLocation(sile);
      await storage.saveActiveLocation(sile);
    });

    test('ilce degisince konum guncellenir, onbellek temizlenir, olay yayilir', () async {
      final s = service((_) async => resolved(city(9206, 'Ankara', 'Ankara')));
      await s.handleFix((latitude: 39.9, longitude: 32.8), now: DateTime(2026, 9, 17, 12));
      await Future<void>.delayed(Duration.zero);

      final gps = (await storage.getSavedLocations()).single;
      expect(gps.cityId, 9206);
      expect(gps.latitude, 39.9);
      expect(cleared, ['gps']);
      expect(events.single.cityId, 9206);
    });

    test('ayni ilcede yalniz koordinat yazilir; olay ve temizlik yok', () async {
      final s = service((_) async => resolved(city(9547, 'Şile', 'İstanbul')));
      await s.handleFix((latitude: 41.2, longitude: 29.7), now: DateTime(2026, 9, 17, 12));
      await Future<void>.delayed(Duration.zero);

      final gps = (await storage.getSavedLocations()).single;
      expect(gps.cityId, 9547);
      expect(gps.latitude, 41.2);
      expect((await storage.getActiveLocation())!.latitude, 41.2);
      expect(cleared, isEmpty);
      expect(events, isEmpty);
    });

    test('kapsama disi fix eski ilceyi korur', () async {
      final s = service((_) async => http.Response('{"error":{"code":"NO_COVERAGE","message":"x"}}', 404, headers: _h));
      await s.handleFix((latitude: 48.85, longitude: 2.35), now: DateTime(2026, 9, 17, 12));

      expect((await storage.getSavedLocations()).single.cityId, 9547);
      expect(events, isEmpty);
    });

    test('ag hatasinda deneme atlanir, referans guncellenmez (sonraki fix yeniden dener)', () async {
      var calls = 0;
      final s = service((_) async { calls++; return http.Response('', 503); });
      await s.handleFix((latitude: 39.9, longitude: 32.8), now: DateTime(2026, 9, 17, 12));
      await s.handleFix((latitude: 39.9, longitude: 32.8), now: DateTime(2026, 9, 17, 12, 1));

      expect(calls, 2, reason: 'referans kaydedilmedigi icin ikinci fix de denenir');
      expect((await storage.getSavedLocations()).single.cityId, 9547);
    });
  });
```
Importlar: `dart:convert`, `http`, `http/testing`, `FakeStorage`, `LocationRepository`, `GpsLocationService`, `PlacesApi`, `Location`.

- [ ] **Step 3: Run, fail.**

- [ ] **Step 4: `GpsLocationService`**
```dart
import 'package:geolocator/geolocator.dart';

import '../../../core/models/location.dart';
import 'places_api.dart';

/// GPS akışındaki kararlı hata anahtarı; metni sunum katmanı seçer.
class GpsLocationException implements Exception {
  final String key;
  const GpsLocationException(this.key);
  @override
  String toString() => 'GpsLocationException($key)';
}

class GpsResolution {
  final Location location;
  final double distanceKm;
  const GpsResolution({required this.location, required this.distanceKm});
}

/// Cihaz konumunu alır ve sunucuda Diyanet ilçesine çözer.
///
/// Konum tek satır olarak saklanır (`gps` kimliği); koordinat cihazınki
/// (kıble için), il/ilçe ve `cityId` sunucudan. Ters-geocode yok: cihaz
/// koordinatı platform servislerine değil yalnız `vakit-api`'ye gider.
class GpsLocationService {
  final PlacesApi api;

  static const String gpsLocationId = 'gps';
  static const String servicesOffKey = 'location_services_off';
  static const String permissionRequiredKey = 'location_permission_required';
  static const String permissionDeniedForeverKey =
      'location_permission_denied_forever';

  GpsLocationService({required this.api});

  Future<GpsResolution> locate({
    Future<bool> Function()? requestPermission,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const GpsLocationException(servicesOffKey);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (requestPermission == null || !await requestPermission()) {
        throw const GpsLocationException(permissionRequiredKey);
      }
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const GpsLocationException(permissionRequiredKey);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const GpsLocationException(permissionDeniedForeverKey);
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return resolve(position.latitude, position.longitude);
  }

  /// [NoCoverageException] ve ağ hataları olduğu gibi çıkar; çağıran karar verir.
  Future<GpsResolution> resolve(
    double latitude,
    double longitude, {
    String? customName,
  }) async {
    final result = await api.resolve(latitude: latitude, longitude: longitude);
    final location = result.city
        .toLocation(
          type: LocationType.gps,
          id: gpsLocationId,
          latitude: latitude,
          longitude: longitude,
        )
        .copyWith(customName: customName);
    return GpsResolution(location: location, distanceKm: result.distanceKm);
  }
}
```

- [ ] **Step 5: `locationErrorText`** — `lib/presentation/utils/location_error_text.dart`:
```dart
import 'dart:async';
import 'dart:io';

import '../../core/exceptions/api_exception.dart';
import '../../core/exceptions/parse_exception.dart';
import '../../features/location/data/gps_location_service.dart';
import '../../features/location/data/places_api.dart';
import '../../l10n/app_localizations.dart';

/// Konum ekleme/GPS akışındaki hata nesnesini kullanıcı metnine çevirir.
/// Servisler metin değil kararlı anahtar/tip üretir; çeviri burada seçilir.
String locationErrorText(AppLocalizations l10n, Object error) {
  if (error is GpsLocationException) {
    return switch (error.key) {
      GpsLocationService.servicesOffKey => l10n.locationServicesOff,
      GpsLocationService.permissionDeniedForeverKey => l10n.locationPermissionDenied,
      _ => l10n.errorLocationPermission,
    };
  }
  if (error is NoCoverageException) return l10n.locationNoCoverage;
  if (error is PlacesNotReadyException ||
      error is ApiException ||
      error is ParseException ||
      error is SocketException ||
      error is TimeoutException ||
      error is HttpException) {
    return l10n.locationNeedsInternet;
  }
  return l10n.errorGenericWith(error.toString());
}
```
(`parse_exception.dart` yolunu `grep -rn "class ParseException" lib` ile doğrula.)

- [ ] **Step 6: `LocationMonitorService`** — `geocoding`, `device_localizations`, `gps_label` importları silinir; alan `final GpsLocationService gps;` kurucuya eklenir; `_getLocationFromCoordinates` silinir; `_onPositionChanged(Position p) => handleFix((latitude: p.latitude, longitude: p.longitude))`:
```dart
  @visibleForTesting
  Future<void> handleFix(Coordinates current, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    if (!isSignificantLocationChange(
      previous: _lastCoordinates,
      current: current,
      lastUpdate: _lastUpdateTime,
      now: at,
    )) {
      return;
    }
    // Koordinat log'lanmaz (gizlilik).
    logger.debug('Significant location change detected');

    final existing = await locationRepository.getGpsLocation();
    final GpsResolution resolution;
    try {
      resolution = await gps.resolve(
        current.latitude,
        current.longitude,
        customName: existing?.customName,
      );
    } on NoCoverageException {
      // Türkiye dışı: eski ilçe kalır, bu fix referans olur (tekrar sorulmaz).
      logger.info('GPS fix outside coverage; keeping previous district');
      _lastCoordinates = current;
      _lastUpdateTime = at;
      return;
    } on Exception catch (e) {
      // Ağ yok: referans güncellenmez, bir sonraki fix yeniden dener.
      logger.debug('GPS resolve skipped', e);
      return;
    }

    _lastCoordinates = current;
    _lastUpdateTime = at;

    final saved = await locationRepository.saveOrUpdateGpsLocation(
      resolution.location,
    );
    if (existing != null && existing.cityId == saved.cityId) {
      // Aynı ilçe: koordinat kıble için yazıldı; önbellek ve planlama geçerli.
      final active = await locationRepository.getActiveLocation();
      if (active?.id == saved.id) {
        await locationRepository.setActiveLocation(saved);
      }
      logger.debug('GPS district unchanged, coordinates refreshed');
      return;
    }
    _locationChangeController.add(saved);
    logger.debug('GPS location updated: ${saved.displayName}');
  }
```
`import 'package:flutter/foundation.dart' show visibleForTesting;` eklenir. `_gpsLocationId` sabiti artık kullanılmıyorsa silinir.

- [ ] **Step 7: DI ve HomePage** — `service_locator.dart`: `register<GpsLocationService>(GpsLocationService(api: placesApi))` (PlacesApi kaydından sonra, `PlacesApi` değişkeni tutulur); `LocationMonitorService(locationRepository: …, gps: get<GpsLocationService>())`. `home_page.dart`: `import '../services/location_service.dart'` → `import '../../features/location/data/gps_location_service.dart'` ve `import '../utils/location_error_text.dart'`; `_locationService = GpsLocationService()` satırı → `ServiceLocator().get<GpsLocationService>()`; `_manualGpsRefresh` içinde:
```dart
      final resolution = await _locationService.locate();
      final locationRepository = ServiceLocator().get<LocationRepository>();
      final savedLocation = await locationRepository.saveOrUpdateGpsLocation(resolution.location);
      await locationRepository.setActiveLocation(savedLocation);
      appState.setActiveLocation(savedLocation);
      await _loadPrayerData(forceRefresh: true);
      // snackbar: l10n.gpsUpdated(savedLocation.displayName)
```
hata dalı: `Text(l10n.errorGpsRefresh(locationErrorText(l10n, e)))`; `_gpsErrorText` silinir. `git rm lib/presentation/services/location_service.dart`.

- [ ] **Step 8: Doğrula** — `flutter analyze`; `flutter test test/location test/presentation test/ramadan`. `grep -rn "placemarkFromCoordinates\|package:geocoding" lib` → yalnız `location_add_screen.dart` kalmalı (Task 6).

- [ ] **Step 9: Commit** — `feat(gps): cihaz koordinatı sunucuda ilçeye çözülür; izleyici yalnız ilçe değişince günceller`.

---

### Task 6: Konum ekleme ekranı yeniden; düzenlemede ilçe değiştir; Photon/ters-geocode silinir

**Files:**
- Rewrite: `lib/presentation/screens/location_add_screen.dart`
- Modify: `lib/presentation/screens/location_edit_screen.dart` (ilçe değiştir), `lib/presentation/screens/location_list_screen.dart` (`placesApi`, `gpsService` parametreleri), `lib/presentation/pages/app_root.dart`, `lib/presentation/pages/home_page.dart` (`LocationListScreen(...)` çağrısı), `lib/presentation/widgets/location/location_widgets.dart` (`LocationSelectionConfirm` `PlaceMatch`/`Location` — mevcut `Location` alır, kalır), `pubspec.yaml` (`geocoding` çıkar), `test/l10n/no_hardcoded_turkish_test.dart` (`photon` satırı), ARB
- Delete: `lib/features/location/data/photon_geocoding_service.dart`, `lib/features/location/data/place_suggestion.dart`, `lib/features/location/data/gps_label.dart`, `test/location/photon_geocoding_service_test.dart`, `test/widgets/screens/location_add_screen_test.dart` (eski; yenisi yazılır)
- Create: `test/widgets/screens/location_add_screen_test.dart` (yeni içerik), `test/widgets/screens/location_edit_screen_test.dart`

**Interfaces:**
- Consumes: `PlaceSearchPanel`, `GpsLocationService.locate/GpsResolution`, `locationErrorText`, `PlaceMatch.toLocation(type: manual)`, `LocationRepository`.
- Produces:
```dart
class LocationAddScreen extends StatefulWidget {
  const LocationAddScreen({super.key, required LocationRepository locationRepository, required PlacesApi placesApi, required GpsLocationService gpsService, bool fromLocationList = false});
}
class LocationEditScreen extends StatefulWidget {
  const LocationEditScreen({super.key, required LocationRepository locationRepository, required PlacesApi placesApi, required Location location});
}
class LocationListScreen extends StatefulWidget {
  // + required PlacesApi placesApi, required GpsLocationService gpsService
}
```

- [ ] **Step 1: ARB** (tr / en / ar):
```json
  "locationGpsConfirm": "Vakitler {place} için gösterilecek",
  "@locationGpsConfirm": {"description": "GPS çözümleme sonrası onay bandı", "placeholders": {"place": {"type": "String"}}},
  "actionConfirm": "Onayla",
  "@actionConfirm": {"description": "Onay düğmesi"},
  "locationEditChangeDistrict": "İlçeyi değiştir",
  "@locationEditChangeDistrict": {"description": "Konum düzenleme: ilçe arama panelini açar"},
  "locationsEmptyHint": "İlçeni ara ya da konumunu kullan",
  "locationPermissionBody": "Bulunduğun ilçeyi bulup vakitleri ona göre göstermek için konum iznine ihtiyaç var. Konumun yalnız en yakın ilçeyi bulmak için kullanılır."
```
en: `"Times will be shown for {place}"`, `"Confirm"`, `"Change district"`, `"Search your district or use your location"`, `"Location permission is needed to find your district and show its prayer times. Your location is used only to find the nearest district."`; ar: `"ستُعرض الأوقات لـ {place}"`, `"تأكيد"`, `"تغيير القضاء"`, `"ابحث عن قضائك أو استخدم موقعك"`, `"يلزم إذن الموقع للعثور على قضائك وعرض أوقاته. يُستخدم موقعك فقط للعثور على أقرب قضاء."`. `flutter gen-l10n`.

- [ ] **Step 2: Failing widget tests** — `test/widgets/screens/location_add_screen_test.dart` (eski dosya silinip yeniden yazılır; eski `displayName` testleri `test/models/location_diyanet_test.dart`'ta zaten var — `grep -n "displayName" test/models/location_diyanet_test.dart` ile doğrula, eksikse "Ozel isim verilmisse displayName onu kullanir" ve "Il merkezinde tekrar eden ad tek kez yazilir" oraya taşınır):
```dart
import 'dart:convert';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/features/location/data/gps_location_service.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/presentation/screens/location_add_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

const _headers = {'content-type': 'application/json; charset=utf-8'};

Map<String, dynamic> _match(int id, String name, String state, {bool centre = false, double lat = 41.0, double lon = 29.0}) => {
  'id': id, 'name': name, 'stateName': state,
  'displayName': centre ? '$name (Merkez)' : '$name, $state',
  'stateId': 539, 'countryId': 2, 'isCentre': centre, 'latitude': lat, 'longitude': lon,
};

http.Response _search(List<Map<String, dynamic>> results) =>
    http.Response(jsonEncode({'query': '', 'results': results}), 200, headers: _headers);

/// Geolocator'a dokunmadan GPS sonucu verir.
class _FakeGps extends GpsLocationService {
  final Future<GpsResolution> Function() onLocate;
  _FakeGps(this.onLocate) : super(api: PlacesApi(client: MockClient((_) async => http.Response('', 500))));
  @override
  Future<GpsResolution> locate({Future<bool> Function()? requestPermission}) => onLocate();
}

void main() {
  late FakeStorage storage;
  late List<String> cleared;
  late AppState appState;

  setUp(() {
    storage = FakeStorage();
    cleared = [];
    appState = AppState();
  });

  Widget screen({required Future<http.Response> Function(http.Request) handler, Future<GpsResolution> Function()? gps, bool fromList = false}) =>
      wrapWithTheme(
        LocationAddScreen(
          locationRepository: LocationRepository(storage: storage, clearPrayerCache: (id) async => cleared.add(id)),
          placesApi: PlacesApi(client: MockClient(handler), baseUrl: 'https://api.test'),
          gpsService: _FakeGps(gps ?? () async => throw StateError('gps not expected')),
          fromLocationList: fromList,
        ),
        appState: appState,
      );

  testWidgets('Aramadan secip kaydetmek manuel Diyanet konumu yazar ve aktif yapar', (tester) async {
    await tester.pumpWidget(screen(handler: (_) async => _search([_match(9547, 'Şile', 'İstanbul', lat: 41.1758, lon: 29.6127)])));
    await tester.pump();

    await tester.tap(find.text('Şile, İstanbul'));
    await tester.pump();
    expect(find.text('Kaydet'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Özel İsim (Opsiyonel)'), 'Yazlık');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final saved = (await storage.getSavedLocations()).single;
    expect(saved.id, 'diyanet-9547');
    expect(saved.cityId, 9547);
    expect(saved.type, LocationType.manual);
    expect(saved.latitude, 41.1758);
    expect(saved.customName, 'Yazlık');
    expect(saved.displayLabel, 'Şile, İstanbul');
    expect((await storage.getActiveLocation())?.id, 'diyanet-9547');
    expect(appState.activeLocation?.id, 'diyanet-9547');
    expect(cleared, ['diyanet-9547']);
  });

  testWidgets('Konumumu kullan: onay bandi, Onayla GPS kaydini yazar', (tester) async {
    const resolved = Location(id: 'gps', province: 'İstanbul', district: 'Şile', type: LocationType.gps, cityId: 9547, latitude: 41.2, longitude: 29.7, displayLabel: 'Şile, İstanbul');
    await tester.pumpWidget(screen(
      handler: (_) async => _search([]),
      gps: () async => const GpsResolution(location: resolved, distanceKm: 3.1),
    ));
    await tester.pump();

    await tester.tap(find.text('Konumumu kullan'));
    await tester.pump();

    expect(find.text('Vakitler Şile, İstanbul için gösterilecek'), findsOneWidget);
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();

    final saved = (await storage.getSavedLocations()).single;
    expect(saved.id, 'gps');
    expect(saved.type, LocationType.gps);
    expect(saved.cityId, 9547);
    expect(saved.latitude, 41.2);
    expect(appState.activeLocation?.id, 'gps');
  });

  testWidgets('Degistir bandi kapatir, arama kalir', (tester) async {
    const resolved = Location(id: 'gps', province: 'İstanbul', district: 'Şile', type: LocationType.gps, cityId: 9547, displayLabel: 'Şile, İstanbul');
    await tester.pumpWidget(screen(handler: (_) async => _search([]), gps: () async => const GpsResolution(location: resolved, distanceKm: 1)));
    await tester.pump();
    await tester.tap(find.text('Konumumu kullan'));
    await tester.pump();

    await tester.tap(find.text('Değiştir'));
    await tester.pump();

    expect(find.textContaining('için gösterilecek'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(await storage.getSavedLocations(), isEmpty);
  });

  testWidgets('Kapsama disi GPS anlasilir hata gosterir', (tester) async {
    await tester.pumpWidget(screen(handler: (_) async => _search([]), gps: () async => throw NoCoverageException()));
    await tester.pump();

    await tester.tap(find.text('Konumumu kullan'));
    await tester.pump();

    expect(find.text('Bu bölge henüz desteklenmiyor; ilçeni ara ve seç.'), findsOneWidget);
  });

  testWidgets('Listeden acildiginda kayit sonrasi konumla geri doner', (tester) async {
    Object? popped;
    await tester.pumpWidget(wrapWithTheme(
      Builder(builder: (context) => ElevatedButton(
        onPressed: () async {
          popped = await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LocationAddScreen(
              locationRepository: LocationRepository(storage: storage),
              placesApi: PlacesApi(client: MockClient((_) async => _search([_match(9206, 'Ankara', 'Ankara', centre: true)])), baseUrl: 'https://api.test'),
              gpsService: _FakeGps(() async => throw StateError('x')),
              fromLocationList: true,
            ),
          ));
        },
        child: const Text('open'),
      )),
      appState: appState,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ankara (Merkez)'));
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(popped, isA<Location>());
    expect((popped as Location).cityId, 9206);
    expect(appState.activeLocation, isNull, reason: 'listeden acilinca aktif konumu cagiran degistirir');
  });
}
```
`test/widgets/screens/location_edit_screen_test.dart`:
```dart
  testWidgets('Ilceyi degistir: yeni ilce secilince kimlik ve ad korunur, konum guncellenir', (tester) async {
    // storage'da const Location(id: 'diyanet-9547', province: 'İstanbul', district: 'Şile', cityId: 9547, customName: 'Yazlık', latitude: 41.17, longitude: 29.61, displayLabel: 'Şile, İstanbul')
    // Ekran: LocationEditScreen(locationRepository:, placesApi: MockClient → _search([_match(9548, 'Silivri', 'İstanbul', lat: 41.07, lon: 28.24)]), location: ...)
    // tap 'İlçeyi değiştir' → pump → tap 'Silivri, İstanbul' → pump → tap 'Kaydet' → pumpAndSettle
    // expect saved: id 'diyanet-9547' (kimlik korunur), cityId 9548, district 'Silivri', latitude 41.07, customName 'Yazlık', displayLabel 'Silivri, İstanbul'; cleared == ['diyanet-9547']
  });
  testWidgets('Yalniz ozel ad degisince ilce ve onbellek dokunulmaz', (tester) async {
    // enterText özel ad 'Ev' → Kaydet → customName 'Ev', cityId 9547, cleared boş
  });
```
(Testi yukarıdaki yorumları koda çevirerek tam yaz; ekran `Navigator.pop(updated)` döndüğü için `wrapWithTheme` içinde `Builder` + `push` kalıbı kullan.)

- [ ] **Step 3: Run, fail.**

- [ ] **Step 4: `LocationAddScreen` (yeni)**
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/location.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/utils/app_logger.dart';
import '../../features/location/data/gps_location_service.dart';
import '../../features/location/data/places_api.dart';
import '../../features/location/domain/location_repository.dart';
import '../../l10n/l10n_extensions.dart';
import '../utils/location_error_text.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/location/location_widgets.dart';
import '../widgets/location/place_search_panel.dart';

/// Konum ekleme: üstte il/ilçe araması, altında "Konumumu kullan".
///
/// Seçim bir Diyanet ilçesidir (`cityId`); koordinat manuelde ilçe merkezi,
/// GPS'te cihazınki. GPS çözümlemesi bir onay bandıyla gösterilir: yanlış ilçe
/// bulunduysa kullanıcı aramaya döner. İlk konumsa kayıttan sonra
/// [AppState] üzerinden ana ekrana geçilir; listeden açıldıysa kayıt geri
/// döndürülür ve aktifleştirme çağırana kalır.
class LocationAddScreen extends StatefulWidget {
  final LocationRepository locationRepository;
  final PlacesApi placesApi;
  final GpsLocationService gpsService;
  final bool fromLocationList;

  const LocationAddScreen({
    super.key,
    required this.locationRepository,
    required this.placesApi,
    required this.gpsService,
    this.fromLocationList = false,
  });

  @override
  State<LocationAddScreen> createState() => _LocationAddScreenState();
}

class _LocationAddScreenState extends State<LocationAddScreen> {
  final _customNameController = TextEditingController();

  PlaceMatch? _selected;
  GpsResolution? _pendingGps;
  bool _gpsBusy = false;
  String? _gpsError;
  bool _saving = false;

  AppTokens get tokens => context.tokens;

  @override
  void dispose() {
    _customNameController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() {
      _gpsBusy = true;
      _gpsError = null;
    });
    final l10n = context.l10n; // await sonrası context kullanılmaz
    try {
      final resolution = await widget.gpsService.locate(
        requestPermission: _showLocationRationale,
      );
      if (!mounted) return;
      setState(() => _pendingGps = resolution);
    } catch (e) {
      AppLogger().warning('GPS detection failed', e);
      if (mounted) setState(() => _gpsError = locationErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  Future<bool> _showLocationRationale() async { /* mevcut diyalog aynen */ }

  Future<void> _save(Location location) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // Silinip yeniden eklenen yerin eski vakit kayıtları konumla silinmez;
      // taze çekim için bu kimliğin önbelleği temizlenir.
      await widget.locationRepository.clearPrayerTimeCache(location.id);
      if (location.type == LocationType.gps) {
        await widget.locationRepository.saveOrUpdateGpsLocation(location);
      } else {
        await widget.locationRepository.saveLocation(location);
      }
      if (!mounted) return;
      if (widget.fromLocationList) {
        Navigator.of(context).pop(location);
      } else {
        await widget.locationRepository.setActiveLocation(location);
        if (mounted) context.read<AppState>().setActiveLocation(location);
      }
    } catch (e) {
      AppLogger().error('Location save failed', e);
      if (mounted) _showSnackBar(context.l10n.locationSaveFailed('$e'), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onManualSave() async {
    final place = _selected;
    if (place == null) return;
    final customName = _customNameController.text.trim();
    final location = place
        .toLocation(type: LocationType.manual)
        .copyWith(customName: customName.isEmpty ? null : customName);
    await _save(location);
  }

  void _showSnackBar(String message, {bool isError = false}) { /* mevcut */ }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: context.l10n.locationAddTitle,
        showBack: widget.fromLocationList,
      ),
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _pendingGps != null
              ? _buildGpsConfirm(_pendingGps!)
              : _selected != null
              ? _buildSelection(_selected!)
              : _buildSearch(),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.locationsEmptyHint,
          textAlign: TextAlign.center,
          style: AppTypography.rowSubtitle.copyWith(color: tokens.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PlaceSearchPanel(
            api: widget.placesApi,
            autofocus: false,
            onSelected: (match) => setState(() => _selected = match),
          ),
        ),
        if (_gpsError != null) ...[
          const SizedBox(height: 12),
          LocationErrorCard(error: _gpsError!),
        ],
        const SizedBox(height: 12),
        LocationChoiceButton(
          icon: Icons.my_location_rounded,
          title: _gpsBusy ? context.l10n.locationGettingPosition : context.l10n.locationUseGps,
          subtitle: context.l10n.locationAutoDetect,
          isLoading: _gpsBusy,
          isHighlighted: true,
          onTap: _detectLocation,
        ),
      ],
    );
  }

  Widget _buildGpsConfirm(GpsResolution resolution) {
    final location = resolution.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.my_location_rounded, size: 48, color: tokens.accent),
        const SizedBox(height: 20),
        Text(
          context.l10n.locationGpsConfirm(location.displayName),
          textAlign: TextAlign.center,
          style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary, height: 1.4),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _saving ? null : () => _save(location),
          style: ElevatedButton.styleFrom(
            backgroundColor: tokens.accent,
            foregroundColor: tokens.backgroundStops.last,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(context.l10n.actionConfirm),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => setState(() => _pendingGps = null),
          style: OutlinedButton.styleFrom(
            foregroundColor: tokens.textSecondary,
            side: BorderSide(color: tokens.border),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(context.l10n.locationChange),
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildSelection(PlaceMatch match) {
    final preview = match.toLocation(type: LocationType.manual);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              LocationSelectionConfirm(location: preview),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _selected = null),
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: Text(context.l10n.locationChange),
                  style: TextButton.styleFrom(foregroundColor: tokens.accent),
                ),
              ),
              const SizedBox(height: 8),
              _buildCustomNameField(), // mevcut alan
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _saving ? null : _onManualSave,
          style: /* mevcut kaydet stili */,
          child: Text(context.l10n.actionSave, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildCustomNameField() { /* mevcut */ }
}
```
Eski `_buildChoiceScreen/_buildManualSelection/_buildResults/_buildResultTile/_buildAttribution/_buildActionButtons/_reverseGeocodeLabel/_loadBiasLocation` ve `geocoding`/`geolocator`/Photon importları silinir (`geolocator` bu ekranda artık gerekmez).

- [ ] **Step 5: `LocationEditScreen`** — `placesApi` alanı; state `PlaceMatch? _replacement; bool _picking = false;`. Gövde: `_picking` ise `PlaceSearchPanel(api:, onSelected: (m) => setState(() { _replacement = m; _picking = false; }))` + geri düğmesi; değilse başlık (`_replacement` varsa onun `displayName`'i), özel ad alanı, `OutlinedButton.icon(Icons.search_rounded, locationEditChangeDistrict)` → `_picking = true`, Kaydet. `_save`:
```dart
    final replacement = _replacement;
    final base = replacement == null
        ? widget.location
        : replacement.toLocation(type: widget.location.type, id: widget.location.id,
            latitude: widget.location.type == LocationType.gps ? widget.location.latitude : null,
            longitude: widget.location.type == LocationType.gps ? widget.location.longitude : null);
    final toSave = customName.isEmpty ? base /* customName null */ : base.copyWith(customName: customName);
    // base widget.location ise ve özel ad silindiyse null'lu kopya gerekir (Task 1'deki _withoutCustomName).
    if (replacement != null && replacement.id != widget.location.cityId) {
      await widget.locationRepository.clearPrayerTimeCache(widget.location.id);
    }
    await widget.locationRepository.updateLocation(toSave);
```
Liste ekranı aktif konum düzenlenince zaten `onLocationSelected(updated)` çağırıp yeniden yüklüyor (mevcut davranış korunur).

- [ ] **Step 6: Bağlantılar** — `LocationListScreen`'e `placesApi`/`gpsService` alanları; `_addNewLocation` ve `_editLocation` bunları geçirir. `AppRoot`: `LocationAddScreen(locationRepository:, placesApi: ServiceLocator().get<PlacesApi>(), gpsService: ServiceLocator().get<GpsLocationService>())`. `HomePage._navigateToLocationList`: aynı iki nesne geçilir.

- [ ] **Step 7: Photon ve ters-geocode silinir** — `git rm lib/features/location/data/photon_geocoding_service.dart lib/features/location/data/place_suggestion.dart lib/features/location/data/gps_label.dart test/location/photon_geocoding_service_test.dart`; `pubspec.yaml`'dan `geocoding: ^3.0.0` satırı; `flutter pub get`; `no_hardcoded_turkish_test.dart` `allowed` haritasından photon satırı. `grep -rn "package:geocoding\|Photon\|PlaceSuggestion\|resolveGpsLabel\|osmAttribution" lib test` → `osmAttribution` yalnız ARB'de kalır (Task 8'de yenisiyle değişir).

- [ ] **Step 8: Doğrula** — `dart format <dokunulan>`; `flutter analyze`; `flutter test test/widgets test/location test/models`.

- [ ] **Step 9: Commit** — `feat(konum): ekleme ekranı sunucu araması + GPS onay bandı; Photon ve ters-geocode kaldırıldı`.

---

### Task 7: Migrasyon ekranı ve açılış akışı (UYG.7)

**Files:**
- Create: `lib/presentation/screens/location_migration_screen.dart`, `test/widgets/screens/location_migration_screen_test.dart`
- Modify: `lib/presentation/pages/app_root.dart`, `lib/presentation/pages/home_page.dart` (`_loadPrayerData` eşlenmemiş konum koruması + `_verifyLocation`), `lib/core/di/service_locator.dart` (`LocationMigrationService`), ARB

**Interfaces:**
- Consumes: `LocationMigrationService.run() → MigrationReport{items, needsUserInput, mappedCount}`, `MigrationItem{location, decision, suggestions}`, `MigrationDecision{mapped, ambiguous, unsupported}`, `PlaceSearchPanel`, `LocationRepository`.
- Produces:
```dart
class LocationMigrationScreen extends StatefulWidget {
  const LocationMigrationScreen({super.key, required MigrationReport report, required LocationRepository locationRepository, required PlacesApi placesApi, required Future<void> Function() onFinished});
}
```
Davranış: yalnız `decision != mapped` öğeler listelenir. Her kart: eski `displayName`, karar metni (`migrationAmbiguousHint` / `migrationUnsupported`), öneri satırları (`ambiguous`), eylemler: **Başka ilçe ara** (panel açar), **Sil** (aktif konumsa gizli; yerine `migrationActiveCannotDelete` ipucu). Seçim: `match.toLocation(type: LocationType.manual).copyWith(customName: old.customName)`; kimlik değiştiyse eski silinir + yeni `saveLocation`, aynıysa `updateLocation`; `clearPrayerTimeCache(new.id)`; eski aktifse `setActiveLocation(new)`. Tüm öğeler çözülünce (liste boş) `onFinished()` çağrılır; **Şimdilik geç** düğmesi yok — spec "tek seferlik" der; ancak ağ hatasında ekran zaten açılmaz.

- [ ] **Step 1: ARB** (tr / en / ar):
```json
  "migrationTitle": "Konumlarını doğrula",
  "migrationIntro": "Vakitler artık Diyanet'in ilçe tablosundan geliyor. Aşağıdaki kayıtlı konumlar için doğru ilçeyi seç.",
  "migrationAmbiguousHint": "Birden fazla eşleşme var; doğru ilçeyi seç.",
  "migrationUnsupported": "Bu konum artık desteklenmiyor.",
  "migrationSearchOther": "Başka ilçe ara",
  "migrationActiveCannotDelete": "Aktif konum silinemez; bir ilçe seç.",
  "locationNeedsVerification": "Bu konum için ilçe doğrulaması gerekiyor. İnternete bağlanıp yeniden dene.",
  "actionSelect": "Seç"
```
en: `"Verify your locations"`, `"Prayer times now come from Diyanet's district tables. Pick the right district for the saved locations below."`, `"More than one match; pick the right district."`, `"This location is no longer supported."`, `"Search another district"`, `"The active location can't be deleted; pick a district."`, `"This location needs its district verified. Connect to the internet and try again."`, `"Select"`; ar: `"تحقق من مواقعك"`, `"أوقات الصلاة تأتي الآن من جداول الأقضية لدى ديانت. اختر القضاء الصحيح للمواقع المحفوظة أدناه."`, `"هناك أكثر من تطابق؛ اختر القضاء الصحيح."`, `"هذا الموقع لم يعد مدعومًا."`, `"ابحث عن قضاء آخر"`, `"لا يمكن حذف الموقع النشط؛ اختر قضاءً."`, `"يحتاج هذا الموقع إلى التحقق من قضائه. اتصل بالإنترنت وحاول مجددًا."`, `"اختيار"`. Açıklamalar (`@…`) eklenir; `flutter gen-l10n`.

- [ ] **Step 2: Failing widget test** — `test/widgets/screens/location_migration_screen_test.dart`:
```dart
// importlar: dart:convert, Location, PlacesApi/PlaceMatch, LocationRepository,
// LocationMigrationService (MigrationReport/MigrationItem/MigrationDecision), LocationMigrationScreen,
// flutter_test, http, http/testing, FakeStorage, theme_harness

void main() {
  const oldKemer = Location(id: 'photon-3', province: 'Antalya', district: 'Kemer', customName: 'Tatil', latitude: 36.6, longitude: 30.5);
  const oldParis = Location(id: 'photon-4', province: 'Paris', district: 'Paris');
  PlaceMatch match(int id, String name, String state) => PlaceMatch.fromJson({
    'id': id, 'name': name, 'stateName': state, 'displayName': '$name, $state',
    'stateId': 7, 'countryId': 2, 'isCentre': false, 'latitude': 36.60, 'longitude': 30.56,
  });

  late FakeStorage storage;
  late List<String> cleared;
  late int finished;

  setUp(() async {
    storage = FakeStorage();
    cleared = [];
    finished = 0;
    await storage.saveLocation(oldKemer);
    await storage.saveLocation(oldParis);
    await storage.saveActiveLocation(oldKemer);
  });

  Widget screen(MigrationReport report, {Future<http.Response> Function(http.Request)? handler}) => wrapWithTheme(
    LocationMigrationScreen(
      report: report,
      locationRepository: LocationRepository(storage: storage, clearPrayerCache: (id) async => cleared.add(id)),
      placesApi: PlacesApi(client: MockClient(handler ?? (_) async => http.Response('', 500)), baseUrl: 'https://api.test'),
      onFinished: () async => finished++,
    ),
  );

  testWidgets('Oneriden secmek konumu esler, aktif kaydi gunceller, onbellegi temizler', (tester) async {
    final report = MigrationReport([
      MigrationItem(location: oldKemer, decision: MigrationDecision.ambiguous, suggestions: [match(1, 'Kemer', 'Burdur'), match(2, 'Kemer', 'Antalya')]),
    ]);
    await tester.pumpWidget(screen(report));
    await tester.pump();

    expect(find.text('Konumlarını doğrula'), findsOneWidget);
    expect(find.text('Tatil'), findsOneWidget);
    await tester.tap(find.text('Kemer, Antalya'));
    await tester.pumpAndSettle();

    final saved = await storage.getSavedLocations();
    expect(saved.any((l) => l.id == 'photon-3'), isFalse, reason: 'eski kimlik silinir');
    final mapped = saved.firstWhere((l) => l.id == 'diyanet-2');
    expect(mapped.cityId, 2);
    expect(mapped.customName, 'Tatil');
    expect((await storage.getActiveLocation())?.id, 'diyanet-2');
    expect(cleared, ['diyanet-2']);
    expect(finished, 1, reason: 'son oge cozulunce biter');
  });

  testWidgets('Desteklenmeyen aktif olmayan konum silinebilir', (tester) async {
    final report = MigrationReport([
      MigrationItem(location: oldParis, decision: MigrationDecision.unsupported),
    ]);
    await tester.pumpWidget(screen(report));
    await tester.pump();

    expect(find.text('Bu konum artık desteklenmiyor.'), findsOneWidget);
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect((await storage.getSavedLocations()).map((l) => l.id), ['photon-3']);
    expect(finished, 1);
  });

  testWidgets('Aktif konumda Sil yoktur; Baska ilce ara panelden secim yapar', (tester) async {
    final report = MigrationReport([
      MigrationItem(location: oldKemer, decision: MigrationDecision.unsupported),
    ]);
    await tester.pumpWidget(screen(report, handler: (_) async => http.Response(
      jsonEncode({'query': '', 'results': [ {'id': 2, 'name': 'Kemer', 'stateName': 'Antalya', 'displayName': 'Kemer, Antalya', 'stateId': 7, 'countryId': 2, 'isCentre': false, 'latitude': 36.6, 'longitude': 30.56} ]}),
      200, headers: {'content-type': 'application/json; charset=utf-8'})));
    await tester.pump();

    expect(find.text('Sil'), findsNothing);
    expect(find.text('Aktif konum silinemez; bir ilçe seç.'), findsOneWidget);
    await tester.tap(find.text('Başka ilçe ara'));
    await tester.pump();
    await tester.tap(find.text('Kemer, Antalya'));
    await tester.pumpAndSettle();

    expect((await storage.getActiveLocation())?.cityId, 2);
    expect(finished, 1);
  });
}
```

- [ ] **Step 3: Run, fail.**

- [ ] **Step 4: `LocationMigrationScreen`** — `SimpleAppBar(title: migrationTitle, showBack: false)`; `_pending = List<MigrationItem>` (`decision != mapped`); `_picking: MigrationItem?`. Gövde: `_picking != null` ise `PlaceSearchPanel(onSelected: (m) => _resolve(_picking!, m))` + üstte geri düğmesi (`actionBack`); değilse `ListView[ intro metni, for item in _pending _card(item) ]`. `_card`: `GroupedList` içinde başlık `item.location.displayName`, alt satır `migrationAmbiguousHint`/`migrationUnsupported`, önerilerde `GroupedRow(title: Text(s.displayName), subtitle: alias?, trailing: Text(actionSelect), onTap: () => _resolve(item, s))`, altta `Row[ TextButton(migrationSearchOther), if (!isActive) TextButton(actionDelete) else Text(migrationActiveCannotDelete) ]`. `_resolve`:
```dart
  Future<void> _resolve(MigrationItem item, PlaceMatch match) async {
    final old = item.location;
    final replacement = match
        .toLocation(type: LocationType.manual)
        .copyWith(customName: old.customName);
    final active = await widget.locationRepository.getActiveLocation();
    if (replacement.id == old.id) {
      await widget.locationRepository.updateLocation(replacement);
    } else {
      await widget.locationRepository.deleteLocation(old.id);
      await widget.locationRepository.saveLocation(replacement);
    }
    await widget.locationRepository.clearPrayerTimeCache(replacement.id);
    if (active?.id == old.id) {
      await widget.locationRepository.setActiveLocation(replacement);
    }
    _complete(item);
  }

  Future<void> _delete(MigrationItem item) async {
    await widget.locationRepository.deleteLocation(item.location.id);
    _complete(item);
  }

  void _complete(MigrationItem item) {
    if (!mounted) return;
    setState(() {
      _pending.remove(item);
      _picking = null;
    });
    if (_pending.isEmpty) widget.onFinished();
  }
```
Aktiflik: `initState`'te `getActiveLocation()` okunup `_activeId` tutulur.

- [ ] **Step 5: AppRoot** — `_checkInitialSetup`:
```dart
  MigrationReport? _migration;

  Future<void> _checkInitialSetup() async {
    final locationRepository = ServiceLocator().get<LocationRepository>();
    final appState = context.read<AppState>();
    try {
      _migration = await _runMigrationIfNeeded(locationRepository);
      final active = await locationRepository.getActiveLocation();
      if (active != null) appState.setActiveLocation(active);
    } catch (e) {
      AppLogger().error('Initial setup failed', e);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  /// Eşlenmemiş (cityId'siz) kayıt varsa sunucuda eşler. Ağ/sunucu hatası
  /// sessizce ertelenir: bir sonraki açılışta yeniden denenir; eşlenmemiş
  /// aktif konum için ana ekran "doğrula" durumunu gösterir.
  Future<MigrationReport?> _runMigrationIfNeeded(LocationRepository repo) async {
    final saved = await repo.getSavedLocations();
    if (saved.every((l) => l.isMapped)) return null;
    try {
      final report = await ServiceLocator().get<LocationMigrationService>().run();
      return report.needsUserInput ? report : null;
    } catch (e) {
      AppLogger().warning('Location migration deferred', e);
      return null;
    }
  }
```
`build`: `_migration != null` → `LocationMigrationScreen(report: _migration!, locationRepository:, placesApi:, onFinished: () async { final active = await repo.getActiveLocation(); if (!mounted) return; appState.setActiveLocation(active); setState(() => _migration = null); })`; sonrası mevcut `Consumer`.

- [ ] **Step 6: HomePage koruması** — `_loadPrayerData` başında `location == null` kontrolünden sonra:
```dart
    if (!location.isMapped) {
      // Eski kayıt henüz Diyanet ilçesine bağlanmadı (açılışta ağ yoktu).
      appState.setError(context.l10n.locationNeedsVerification);
      appState.setRefreshing(false);
      await _verifyLocation(location);
      return;
    }
```
```dart
  /// Eşlenmemiş aktif konumu yeniden eşlemeyi dener; belirsizse doğrulama
  /// ekranını açar. Hata sessizce kalır (mesaj zaten ekranda), yenileme
  /// tekrar dener.
  Future<void> _verifyLocation(Location location) async {
    final repo = ServiceLocator().get<LocationRepository>();
    try {
      final report = await ServiceLocator().get<LocationMigrationService>().run();
      if (!mounted) return;
      if (report.needsUserInput) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LocationMigrationScreen(
            report: report,
            locationRepository: repo,
            placesApi: ServiceLocator().get<PlacesApi>(),
            onFinished: () async { if (mounted) Navigator.of(context).pop(); },
          ),
        ));
      }
      final active = await repo.getActiveLocation();
      if (!mounted || active == null || !active.isMapped) return;
      context.read<AppState>().setActiveLocation(active);
      await _loadPrayerData(forceRefresh: true);
    } catch (e) {
      AppLogger().warning('Location verification deferred', e);
    }
  }
```
(`ErrorState.onRetry` = `_refreshData` → `_loadPrayerData` → aynı yol.) `service_locator.dart`: `register<LocationMigrationService>(LocationMigrationService(storage: localStorage, api: placesApi, clearPrayerCache: prayerTimesRepository.clearCacheForLocation))` (`PrayerTimesRepository` kaydından sonra).

- [ ] **Step 7: Doğrula** — `flutter analyze`; `flutter test test/widgets/screens test/location`.

- [ ] **Step 8: Commit** — `feat(konum): eski kayıtlar için açılışta Diyanet ilçe doğrulama ekranı`.

---

### Task 8: Ayarlar/gizlilik metinleri, izin açıklamaları, l10n temizliği

**Files:**
- Modify: `lib/presentation/screens/settings_screen.dart` (Bilgi bölümü: OSM atfı satırı), ARB'ler (`privacyBody`, `osmDistrictAttribution`, `settingsFooter`; kullanılmayan anahtarlar silinir), `ios/Runner/{tr,en,ar}.lproj/InfoPlist.strings` ve `ios/Runner/Info.plist` (konum izin açıklamaları), `test/widgets/screens/settings_screen_test.dart`

- [ ] **Step 1: ARB metinleri**
```json
  "privacyBody": "Konumun ve kayıtlı ilçelerin cihazında saklanır. Arama metni ve konum çözümleme için yaklaşık koordinat (~100 m) yalnızca bize ait vakit sunucusuna gönderilir; sunucu bunları saklamaz ve kimliğinle ilişkilendirmez. Vakit verisi Diyanet İşleri Başkanlığı'ndan alınır.",
  "osmDistrictAttribution": "İlçe koordinatları © OpenStreetMap katkıcıları",
  "@osmDistrictAttribution": {"description": "Ayarlar > Bilgi altındaki atıf satırı"},
  "settingsFooter": "Vakitler cihazında saklanır; sunucuya yalnız ilçe araması ve konum çözümleme gider."
```
en: `"Your location and saved districts stay on your device. Search text and an approximate coordinate (~100 m) for location resolution are sent only to our own prayer-time server; it does not store them or link them to you. Prayer times come from the Presidency of Religious Affairs (Diyanet)."`, `"District coordinates © OpenStreetMap contributors"`, `"Times are stored on your device; only district search and location resolution reach the server."`; ar: `"يبقى موقعك والأقضية المحفوظة على جهازك. يُرسل نص البحث وإحداثية تقريبية (~100 م) لتحديد القضاء إلى خادم الأوقات الخاص بنا فقط؛ ولا يخزنها ولا يربطها بهويتك. تأتي أوقات الصلاة من رئاسة الشؤون الدينية (ديانت)."`, `"إحداثيات الأقضية © مساهمو OpenStreetMap"`, `"تُحفظ الأوقات على جهازك؛ لا يصل إلى الخادم سوى البحث عن القضاء وتحديد الموقع."`.

- [ ] **Step 2: Kullanılmayan anahtarları sil** — her anahtar için `grep -rn "\.<anahtar>\b" lib --exclude-dir=l10n` boşsa üç ARB'den (değer + `@` meta) sil: `settingsCalculation`, `calcMethodLabel`, `calcAsrLabel`, `calcAdvanced`, `calcLatitudeLabel`, `calcGlobalNote`, `calcTuneSection`, `asrShafi`, `asrHanafi`, `latAuto`, `latMidnight`, `latOneSeventh`, `latAngle`, `locationUseGlobalCalculation`, `locationUseGlobalCalculationHint`, `locationCalculationFromGlobal`, `locationGlobalCalculation`, `locationSearchAddress`, `locationSearchHint`, `locationFindWithGps`, `locationSearchStart`, `locationSearch`, `gpsFallbackLabel`, `osmAttribution`, `locationSelectFirst`. Kullanılan çıkarsa **silme**. `flutter gen-l10n` → `flutter analyze` (kaldırılan getter'a referans kalmadıysa temiz).

- [ ] **Step 3: SettingsScreen Bilgi bölümü** — veri kaynağı satırının altına atıf satırı (`GroupedRow(icon: Icons.map_outlined, title: Text(context.l10n.osmDistrictAttribution))`, dokunulmaz). Test: `expect(find.textContaining('OpenStreetMap'), findsOneWidget);` ve gizlilik diyaloğu testinde `find.textContaining('vakit sunucusuna')`.

- [ ] **Step 4: iOS izin metinleri** — `tr.lproj`: `"Bulunduğun ilçeyi bulup vakitleri ona göre göstermek için konum iznine ihtiyaç var."` (iki anahtar); `en.lproj`: `"Location access is used to find your district and show its prayer times."`; `ar.lproj`: `"يُستخدم الوصول إلى الموقع للعثور على قضائك وعرض أوقات الصلاة فيه."`; `Info.plist` İngilizce varsayılanı en ile aynı. Android manifest'te metin yok (kontrol: `grep -n "location" android/app/src/main/AndroidManifest.xml`).

- [ ] **Step 5: Doğrula** — `flutter gen-l10n && flutter analyze && flutter test test/widgets/screens/settings_screen_test.dart test/l10n`.

- [ ] **Step 6: Commit** — `feat(ayarlar): gizlilik ve izin metinleri vakit-api'ye göre; OSM atfı; kullanılmayan çeviriler silindi`.

---

### Task 9: Belgeler, ADR 0006, CI sunucu adresi

**Files:**
- Modify: `docs/PRIVACY.md`, `docs/privacy.html`, `docs/PLAY_DATA_SAFETY.md`, `docs/adr/README.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `CHANGELOG.md`, `docs/DEVELOPMENT.md`, `docs/superpowers/specs/2026-09-17-diyanet-uygulama-design.md` (sapma notu), `.github/workflows/android-play.yml`, `.github/workflows/ios-testflight.yml`
- Create: `docs/adr/0006-diyanet-single-source.md`

- [ ] **Step 1: Gizlilik belgeleri** — `PRIVACY.md` ve `privacy.html`: "Son güncelleme: 17 Eylül 2026"; Özet: "Kişisel verileriniz için bize ait bir sunucu yoktur" → "Hesap oluşturmanız gerekmez; vakit ve ilçe verisini sunan sunucumuz kimlik bilgisi almaz ve isteklerinizi saklamaz."; İşlenen veriler: "Konum bilgisi: GPS koordinatınız en yakın ilçeyi bulmak için ~100 m hassasiyete yuvarlanarak sunucumuza gönderilir; cihazınızda saklanan koordinat kıble yönü içindir." ve "hesaplama yöntemi/mezhep seçimleri" → "vakit düzeltme tercihi"; Üçüncü taraf: Aladhan/Photon/platform ters-geocode maddeleri silinir, yerine "**Ezan Vakti vakit sunucusu** (bize ait): ilçe araması için yazdığınız metin ve konum çözümleme için yaklaşık koordinat; saklanmaz, loglanmaz." ve "Vakit tabloları Diyanet İşleri Başkanlığı'ndan alınır; ilçe koordinatları © OpenStreetMap katkıcıları." `PLAY_DATA_SAFETY.md`: Shared? → **No** (veri yalnız geliştiricinin kendi sunucusuna, işlev için, geçici; Play "shared" üçüncü tarafa aktarım demektir) — not paragrafı buna göre; "Processed ephemerally" satırı korunur.

- [ ] **Step 2: ADR 0006** — `docs/adr/0006-diyanet-single-source.md`: Durum Kabul edildi, Tarih 2026-09-17; Bağlam (Aladhan m13 ±1–2 dk mevsimsel fark — `docs/investigations/2026-09-15-aladhan-resmi-tablo-farklari.md`; Diyanet şartı veriyi kendi sunucunda barındır; hesap parametresi seçimi Diyanet tablosunda anlamsız), Karar (tek kaynak Diyanet, `vakit-api`; konum = ilçe kimliği; arama/GPS çözümleme sunucuda; Hicri veriden; tune yerelde kalır — ADR 0004; sağlayıcı arayüzü `Location.cityId` taşır), Sonuçlar (olumlu: birebir vakit, cihazda liste yok, üçüncü tarafa koordinat yok; bedeller: yalnız Türkiye, sunucu bağımlılığı — yıl önbelleği ile çevrimdışı, migrasyon ekranı), Alternatifler (Aladhan + tune: mevsimsel fark sabit kaydırmayla kapanmaz; cihazda gömülü il/ilçe: güncelleme gerektirir, kullanıcı kararı; Diyanet API'yi uygulamadan çağırmak: kimlik bilgisi cihaza gömülür, şart dışı), Referanslar (Spec A/B, Plan B1/B2, `diyanet_provider.dart`, `location_migration_service.dart`, commit hash'leri `git log --oneline` ile). `docs/adr/README.md` tablosuna satır.

- [ ] **Step 3: README/ARCHITECTURE/ROADMAP/CHANGELOG/DEVELOPMENT** — README özellik ve teknoloji satırları (Photon/Aladhan → "Diyanet vakit tablosu, kendi sunucumuz `server/`", konum: `geolocator` + sunucu araması/çözümleme); ARCHITECTURE "Vakit kaynağı" ve "Adres araması" bölümleri yeniden yazılır (DiyanetProvider yıl dosyası + ETag, PlacesApi, GpsLocationService, LocationMonitorService resolve, migrasyon; hesap ayarları kalktı); ROADMAP: Diyanet maddesi ✅ "uygulama tarafı (Spec B) bitti; API onayı bekleniyor", global bölümü "diğer ülkeler sunucuda açıldıkça"; CHANGELOG Unreleased: Eklendi (sunucu araması, GPS onay bandı, doğrulama ekranı, OSM atfı), Değişti (tek kaynak Diyanet; ayarlar), Kaldırıldı (Aladhan, Photon, ters-geocode, hesap yöntemi/mezhep/enlem seçimi, `geocoding`); DEVELOPMENT: "Plan B2'de alacak" cümlesi → CI değişkeni açıklaması. Spec B'ye "Sapmalar" alt bölümü (bu planın başındaki 4 madde).

- [ ] **Step 4: CI dart-define** — iki workflow'a ortak guard adımı (build'den önce):
```yaml
      - name: Sunucu adresi (VAKIT_API_BASE_URL) tanimli mi
        env:
          VAKIT_API_BASE_URL: ${{ vars.VAKIT_API_BASE_URL }}
        run: |
          if [ -z "$VAKIT_API_BASE_URL" ]; then
            echo "HATA: repository variable VAKIT_API_BASE_URL tanimli degil (Settings > Variables)." >&2
            exit 1
          fi
```
`flutter build appbundle --release --dart-define=VAKIT_API_BASE_URL=${{ vars.VAKIT_API_BASE_URL }}` ve `flutter build ios --config-only --release --no-codesign --dart-define=VAKIT_API_BASE_URL=${{ vars.VAKIT_API_BASE_URL }}` (`--config-only` DART_DEFINES'ı `Generated.xcconfig`'e yazar; sonraki `xcodebuild` bunu kullanır). DEVELOPMENT.md'ye: "Üretim adresi GitHub → Settings → Secrets and variables → Actions → Variables → `VAKIT_API_BASE_URL` (ör. `https://api.<domain>`)."

- [ ] **Step 5: Doğrula** — `git diff --check`; dosya referansları (`ls` ile) doğru.

- [ ] **Step 6: Commit** — `docs: gizlilik, ADR 0006 (tek kaynak Diyanet), mimari/yol haritası ve CI sunucu adresi`.

---

### Task 10: Son doğrulama ve teslim

- [ ] **Step 1:** `git diff --name-only c5af14f HEAD -- 'lib/**/*.dart' 'test/**/*.dart' | xargs dart format --set-exit-if-changed` (yalnız bu iki plana ait dosyalar) → 0 değişiklik.
- [ ] **Step 2:** `flutter analyze` → No issues. `flutter test` → tümü geçer.
- [ ] **Step 3:** `flutter build apk --debug` ve `flutter build ios --simulator --debug` (InfoPlist değişti).
- [ ] **Step 4:** Sunucu yerelde (`cd server && make smoke` ya da `vakit serve`) çalışırken iOS simülatöründe uçtan uca: yeni kurulum → arama → İstanbul (Merkez) seç → vakitler + Hicri; "Konumumu kullan" (simülatör konumu Apple → Türkiye dışı → kapsama dışı mesajı; Custom Location ile İstanbul → onay bandı); eski şemalı veritabanıyla açılış (Task 7 senaryosu: `sqlite3` ile `city_id` NULL bırakılmış kayıt) → doğrulama ekranı. Bu adımı **Ekrem** cihazda/simülatörde yürütür (bellek: manuel test Ekrem'de); Claude komutları ve beklenen sonuçları raporda listeler.
- [ ] **Step 5:** Teslim raporu: değişen alanlar, doğrulama çıktıları, test edilmeyenler (gerçek cihazda GPS izni/izleme, TestFlight define'ı), API onayı sonrası adımlar (`.env`, `VAKIT_SOURCE=awqat`, `vakit sync quota`, `dev`'e merge onayı).

---

## Plan sonu — teslim kontrolü

- Spec kapsamı: UYG.2 (Task 4, 6), UYG.3 (Task 5), UYG.6 (değişmez; koordinat ilçe merkezi/cihaz — Task 6), UYG.7 ekran + açılış (Task 7), UYG.8 (Task 1, 2, 3, 8, 9), UYG.9 (B1'de; değişmez), B8 CI (Task 9).
- Sapmalar başta listelendi; spec'e Task 9'da işlenir.
- Test edilmeyen: gerçek cihazda izin akışı ve GPS izleme; Cloudflare arkasındaki üretim adresi; native alarmın gerçek cihazda çalması (proje kuralı).
