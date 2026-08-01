# Tema Altyapısı (Faz 6 + Faz 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uygulamayı, vakte göre değişen 8 paletli bir token sistemine taşımak — ekran görünümünü **değiştirmeden**.

**Architecture:** Renkler ve tipografi `AppTokens` adlı bir `ThemeExtension` içinde toplanır. Hangi paletin geçerli olduğunu, namaz vakitlerinden gün dilimini hesaplayan saf bir fonksiyon (`DayPhaseResolver`) belirler. `ThemeController` bu ikisini birleştirip `MaterialApp`'e verir; palet değişimleri `AnimatedTheme` ile 400 ms'de yumuşatılır. Widget'lar renk sabiti yazmaz, `context.tokens` üzerinden okur.

**Tech Stack:** Flutter (Dart SDK `^3.10.4`), `provider` 6.x, `sqflite` 2.x, `flutter_test`. Yeni paket eklenmez.

**Spec:** `docs/superpowers/specs/2026-08-01-redesign-0.3.0-design.md`

## Global Constraints

- Tüm kod, dosya adı, değişken, sınıf ve fonksiyon adları **İngilizce**. Kullanıcıya görünen metinler ve yorumlar Türkçe.
- Palet geçişi **400 ms `Curves.easeOutCubic`**. Kontrol animasyonları (segment pill) 220 ms — bu planda kullanılmaz.
- Açık tema mürekkebi = **paletin Metin1 rengi**. Ayrı sabit tutulmaz, türetilir.
- Font ölçeği yalnızca şu 10 basamak: `11 · 12 · 13 · 14 · 16 · 17 · 20 · 24 · 44 · 62`.
- Gün dilimi sınırları: `morning` İmsak→Öğle, `afternoon` Öğle→İkindi, `evening` İkindi→**Yatsı**, `night` Yatsı→(ertesi gün) İmsak.
- Vakit verisi yoksa palet `DayPhase.evening` (D5).
- `appearance_theme_mode` varsayılan `dark`, `appearance_time_based_color` varsayılan `true`, `appearance_fixed_palette` varsayılan `evening`.
- **Bu planın kabul ölçütü: ekran görünümü değişmez.** Faz 1 sonunda alınan ekran görüntüleri, plan öncesi görüntülerle aynı olmalı (renkler mevcut `AppTheme` değerlerinden `evening` paletine geçtiği için birebir aynı olmayacak — farkın *yalnızca* palet renklerinden geldiği, yapı/yerleşim/boyutun değişmediği doğrulanır).
- Her task sonunda `flutter analyze` temiz ve `flutter test` yeşil olmalı.
- Commit'ler **`dev`'e değil**, bu planın branch'i `redesign/0.3.0` üzerine atılır.

---

## File Structure

**Yeni dosyalar**

| Dosya | Sorumluluk |
|---|---|
| `lib/core/theme/day_phase.dart` | `DayPhase` enum'ı ve vakitlerden dilim/sınır hesaplayan saf fonksiyonlar. Flutter'a bağımlı değil. |
| `lib/core/theme/app_tokens.dart` | `AppTokens` — renk ve gradyan token'ları taşıyan `ThemeExtension`. |
| `lib/core/theme/app_typography.dart` | 10 basamaklı font ölçeği ve adlandırılmış `TextStyle` sabitleri. |
| `lib/core/theme/palettes.dart` | 8 sabit `AppTokens` (4 dilim × 2 parlaklık). |
| `lib/core/models/appearance_settings.dart` | `AppearanceSettings` modeli + serileştirme. |
| `lib/core/theme/theme_controller.dart` | `ChangeNotifier`; ayar + vakit + saatten aktif `AppTokens`'ı üretir, sınır timer'ını yönetir. |
| `lib/core/theme/tokens_context.dart` | `context.tokens` kısayolu (`BuildContext` extension). |

**Değişen dosyalar**

| Dosya | Değişiklik |
|---|---|
| `lib/presentation/screens/location_edit_screen.dart` | Task 1 — `SwitchListTile` ink uyarısı |
| `lib/presentation/controllers/location_monitor_controller.dart` | Task 2 — GPS yolunu `LocationService.changeLocation`'a delege et |
| `lib/core/interfaces/local_storage.dart` | Task 4 — iki yeni metot |
| `lib/features/prayer_times/data/sqlite_storage.dart` | Task 4 — metotların implementasyonu |
| `lib/core/di/service_locator.dart` | Task 6 — `ThemeController` kaydı |
| `lib/main.dart` | Task 7 — `AnimatedTheme` + `ThemeController` bağlanması |
| `lib/core/theme/app_theme.dart` | Task 7 — `AppTokens`'tan `ThemeData` üreten hâle gelir |
| `pubspec.yaml` | Task 8 — Manrope font tanımı |

---

## Task 1: `SwitchListTile` ink uyarısını gider

Bu uyarı, o ekrana uğrayan **her integration test'i düşürüyor**. Önce bu kapanmalı ki sonraki task'ların test çıktısı okunabilir olsun.

**Files:**
- Modify: `lib/presentation/screens/location_edit_screen.dart:252-258`

**Interfaces:**
- Consumes: yok
- Produces: yok (davranış değişmiyor)

- [ ] **Step 1: Uyarıyı üret ve gör**

Run: `flutter test integration_test/screenshots_test.dart -d <simulator-udid>` yerine daha hızlısı — mevcut widget testiyle üretilemiyor, doğrudan koda bak:

Run: `grep -n -A3 "child: SwitchListTile" lib/presentation/screens/location_edit_screen.dart`

Beklenen çıktı: `SwitchListTile`'ın, `decoration:` içinde `color:` taşıyan bir `Container`'ın doğrudan çocuğu olduğu görülür. Flutter bu durumda şu assertion'ı atar:
`ListTile background color or ink splashes may be invisible.`

- [ ] **Step 2: Regresyon testini yaz (başarısız olmalı)**

Create: `test/widgets/location_edit_switch_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// SwitchListTile, arka plan rengi olan bir Container'in dogrudan cocugu
/// oldugunda Flutter "ink splashes may be invisible" assertion'i atar ve
/// o ekrani ziyaret eden butun integration testler duser.
void main() {
  testWidgets('renkli kapsayici icindeki SwitchListTile assertion atmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                title: const Text('Genel hesaplama ayarını kullan'),
                value: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 3: Testi çalıştır, geçtiğini gör**

Run: `flutter test test/widgets/location_edit_switch_test.dart`
Expected: PASS — bu test doğru deseni (Material sarmalı) belgeler.

Şimdi aynı testi `Material` sarmalı **olmadan** yazıp assertion'ın gerçekten atıldığını kanıtla: testte `Material(...)` satırlarını geçici olarak kaldır, çalıştır, `takeException()`'ın `FlutterError` döndüğünü gör, sonra `Material`'ı geri koy.

- [ ] **Step 4: Ekrandaki kodu düzelt**

Modify: `lib/presentation/screens/location_edit_screen.dart` — `_buildUseGlobalSwitch()` içindeki `child: SwitchListTile(` satırını `Material` ile sar:

```dart
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Genel hesaplama ayarını kullan',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          subtitle: Text(
            'Kapatırsan bu konuma özel yöntem/mezhep seçebilirsin',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          value: _useGlobal,
          activeThumbColor: AppTheme.gold,
          onChanged: (value) => setState(() => _useGlobal = value),
        ),
      ),
```

Kapanış parantezini de bir seviye içeri alarak dengelemeyi unutma.

- [ ] **Step 5: Analiz ve testler**

Run: `flutter analyze lib/presentation/screens/location_edit_screen.dart && flutter test`
Expected: `No issues found` ve tüm testler PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/location_edit_screen.dart test/widgets/location_edit_switch_test.dart
git commit -m "fix: SwitchListTile ink uyarisi (konum duzenleme)

SwitchListTile arka plan rengi olan Container'in dogrudan cocuguydu;
Flutter 'ink splashes may be invisible' assertion'i atiyor ve o ekrani
ziyaret eden integration testler dusuyordu. Transparent Material ile
sarildi, dogru desen regresyon testiyle belgelendi."
```

---

## Task 2: GPS konum değişimini kanonik yola delege et

Manuel konum değişimi `LocationService.changeLocation`'a indirilmişti; GPS canlı akışı hâlâ repository'yi doğrudan çağırıyor. Bu yüzden GPS ile konum değişince **önbellek geçersizleştirme ve eski bildirimlerin iptali atlanıyor**.

**Files:**
- Modify: `lib/presentation/controllers/location_monitor_controller.dart`
- Test: `test/location/location_monitor_controller_test.dart`

**Interfaces:**
- Consumes: `LocationService.changeLocation(Location newLocation) → Future<void>` (mevcut, `lib/features/location/domain/location_service.dart:21`)
- Produces: `LocationMonitorController({required LocationMonitorService monitorService, required LocationService locationService, required AppLogger logger, required Function(Location) onLocationChanged})` — `locationRepository` parametresi **kalkıyor**, yerine `locationService` geliyor.

- [ ] **Step 1: Başarısız testi yaz**

Create: `test/location/location_monitor_controller_test.dart`

```dart
import 'dart:async';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/utils/app_logger.dart';
import 'package:ezanvakti/features/location/domain/location_monitor_service.dart';
import 'package:ezanvakti/features/location/domain/location_service.dart';
import 'package:ezanvakti/presentation/controllers/location_monitor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMonitorService implements LocationMonitorService {
  final _controller = StreamController<Location>.broadcast();
  bool started = false;

  @override
  Stream<Location> get onLocationChanged => _controller.stream;

  @override
  Future<void> startMonitoring() async => started = true;

  @override
  void stopMonitoring() => started = false;

  void emit(Location location) => _controller.add(location);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyLocationService implements LocationService {
  final List<Location> changed = [];

  @override
  Future<void> changeLocation(Location newLocation) async {
    changed.add(newLocation);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const gpsLocation = Location(
    id: 'gps',
    province: 'İstanbul',
    district: 'Kadıköy',
    type: LocationType.gps,
  );
  const newLocation = Location(
    id: 'gps',
    province: 'Ankara',
    district: 'Çankaya',
    type: LocationType.gps,
  );

  test('GPS konum degisimi LocationService.changeLocation uzerinden gider', () async {
    final monitor = _FakeMonitorService();
    final service = _SpyLocationService();
    final seen = <Location>[];

    final controller = LocationMonitorController(
      monitorService: monitor,
      locationService: service,
      logger: AppLogger(),
      onLocationChanged: seen.add,
    );

    await controller.startMonitoring(gpsLocation);
    monitor.emit(newLocation);
    await Future<void>.delayed(Duration.zero);

    expect(service.changed, [newLocation]);
    expect(seen, [newLocation]);

    await controller.stopMonitoring();
  });

  test('GPS olmayan aktif konumda izleme baslatilmaz', () async {
    final monitor = _FakeMonitorService();
    final service = _SpyLocationService();

    final controller = LocationMonitorController(
      monitorService: monitor,
      locationService: service,
      logger: AppLogger(),
      onLocationChanged: (_) {},
    );

    await controller.startMonitoring(
      const Location(id: '1', province: 'İstanbul', district: 'Kadıköy'),
    );

    expect(monitor.started, isFalse);
    expect(service.changed, isEmpty);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/location/location_monitor_controller_test.dart`
Expected: FAIL — `locationService` adlı bir named parameter olmadığı için derleme hatası.

- [ ] **Step 3: Controller'ı değiştir**

Modify: `lib/presentation/controllers/location_monitor_controller.dart` — tamamı:

```dart
import 'dart:async';

import '../../core/models/location.dart';
import '../../core/utils/app_logger.dart';
import '../../features/location/domain/location_monitor_service.dart';
import '../../features/location/domain/location_service.dart';

class LocationMonitorController {
  final LocationMonitorService _monitorService;
  final LocationService _locationService;
  final AppLogger _logger;
  final Function(Location) _onLocationChanged;

  StreamSubscription<Location>? _locationSubscription;

  LocationMonitorController({
    required LocationMonitorService monitorService,
    required LocationService locationService,
    required AppLogger logger,
    required Function(Location) onLocationChanged,
  }) : _monitorService = monitorService,
       _locationService = locationService,
       _logger = logger,
       _onLocationChanged = onLocationChanged;

  Future<void> startMonitoring(Location? activeLocation) async {
    if (activeLocation?.type != LocationType.gps) return;

    // Avoid stacking subscriptions if monitoring is started more than once.
    await _locationSubscription?.cancel();
    _locationSubscription = _monitorService.onLocationChanged.listen((
      newLocation,
    ) async {
      _logger.debug('GPS location changed, refreshing prayer times');
      // Tek kanonik yol: aktif konum atama, hesaplama parametresi degisince
      // onbellek gecersizlestirme ve eski konumun bildirimlerinin iptali
      // domain LocationService'e aittir (manuel yolla ayni davranis).
      await _locationService.changeLocation(newLocation);
      _onLocationChanged(newLocation);
    });

    await _monitorService.startMonitoring();
  }

  Future<void> stopMonitoring() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _monitorService.stopMonitoring();
  }
}
```

- [ ] **Step 4: Çağıran tarafı güncelle**

Modify: `lib/presentation/pages/home_page.dart` — `_startLocationMonitoring()` içindeki yapıcı çağrısında `locationRepository:` satırını `locationService:` ile değiştir:

```dart
    _locationMonitorController = LocationMonitorController(
      monitorService: ServiceLocator().get<LocationMonitorService>(),
      locationService: ServiceLocator().get<LocationService>(),
      logger: AppLogger(),
      onLocationChanged: (newLocation) async {
        appState.setActiveLocation(newLocation);
        await _loadInitialData();
      },
    );
```

`home_page.dart` içinde iki farklı `LocationService` import'u var (`features/location/domain/location_service.dart` ve `presentation/services/location_service.dart` — ikincisi `GpsLocationService` sınıfını taşır). `ServiceLocator().get<LocationService>()` domain olanı döndürür; ek import gerekmez, `LocationRepository` import'u başka yerlerde kullanıldığı için **silinmez**.

- [ ] **Step 5: Testler ve analiz**

Run: `flutter test && flutter analyze`
Expected: tüm testler PASS, `No issues found`.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/controllers/location_monitor_controller.dart lib/presentation/pages/home_page.dart test/location/location_monitor_controller_test.dart
git commit -m "refactor: GPS konum degisimini kanonik yola delege et

LocationMonitorController dogrudan locationRepository.setActiveLocation
cagiriyordu; boylece GPS ile konum degisince onbellek gecersizlestirme ve
eski bildirimlerin iptali atlaniyordu. Artik manuel yolla ayni sekilde
LocationService.changeLocation kullaniliyor."
```

---

## Task 3: `DayPhase` ve dilim çözümleyicisi

Saf Dart; Flutter'a bağımlı değil, bu yüzden hızlı ve deterministik test edilir.

**Files:**
- Create: `lib/core/theme/day_phase.dart`
- Test: `test/theme/day_phase_test.dart`

**Interfaces:**
- Consumes: `PrayerTime` (`lib/core/models/prayer_time.dart`) — alanlar: `fajr`, `sunrise`, `dhuhr`, `asr`, `maghrib`, `isha`, `date` (hepsi `DateTime`)
- Produces:
  - `enum DayPhase { morning, afternoon, evening, night }`
  - `DayPhase resolveDayPhase({PrayerTime? today, PrayerTime? tomorrow, required DateTime now})`
  - `DateTime? nextDayPhaseBoundary({PrayerTime? today, PrayerTime? tomorrow, required DateTime now})`

- [ ] **Step 1: Başarısız testi yaz**

Create: `test/theme/day_phase_test.dart`

```dart
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerTime _day(int day, {int fajr = 4, int dhuhr = 13, int asr = 17, int isha = 22}) {
  DateTime at(int hour) => DateTime(2026, 8, day, hour, 0);
  return PrayerTime(
    fajr: at(fajr),
    sunrise: at(fajr + 2),
    dhuhr: at(dhuhr),
    asr: at(asr),
    maghrib: at(20),
    isha: at(isha),
    date: DateTime(2026, 8, day),
  );
}

void main() {
  final today = _day(1);
  final tomorrow = _day(2);

  group('resolveDayPhase', () {
    test('Imsak ile Ogle arasi morning', () {
      expect(
        resolveDayPhase(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 9, 0),
        ),
        DayPhase.morning,
      );
    });

    test('Ogle ile Ikindi arasi afternoon', () {
      expect(
        resolveDayPhase(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 15, 0),
        ),
        DayPhase.afternoon,
      );
    });

    test('Ikindi ile Yatsi arasi evening — sinir Aksam degil Yatsi', () {
      // Aksam 20:00'de; tasarim geregi palet burada degismez.
      expect(
        resolveDayPhase(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 21, 0),
        ),
        DayPhase.evening,
      );
    });

    test('Yatsi sonrasi night', () {
      expect(
        resolveDayPhase(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 23, 0),
        ),
        DayPhase.night,
      );
    });

    test('Gece yarisindan sonra, Imsak oncesi hala night', () {
      expect(
        resolveDayPhase(
          today: _day(2),
          tomorrow: _day(3),
          now: DateTime(2026, 8, 2, 2, 0),
        ),
        DayPhase.night,
      );
    });

    test('Vakit verisi yoksa evening dondurur', () {
      expect(
        resolveDayPhase(
          today: null,
          tomorrow: null,
          now: DateTime(2026, 8, 1, 9, 0),
        ),
        DayPhase.evening,
      );
    });

    test('Sinir anlari dahil: tam Ogle vaktinde afternoon', () {
      expect(
        resolveDayPhase(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 13, 0),
        ),
        DayPhase.afternoon,
      );
    });
  });

  group('nextDayPhaseBoundary', () {
    test('morning icindeyken sonraki sinir Ogle', () {
      expect(
        nextDayPhaseBoundary(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 9, 0),
        ),
        DateTime(2026, 8, 1, 13, 0),
      );
    });

    test('evening icindeyken sonraki sinir Yatsi', () {
      expect(
        nextDayPhaseBoundary(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 18, 0),
        ),
        DateTime(2026, 8, 1, 22, 0),
      );
    });

    test('Yatsi sonrasi sonraki sinir ertesi gunun Imsak i', () {
      expect(
        nextDayPhaseBoundary(
          today: today,
          tomorrow: tomorrow,
          now: DateTime(2026, 8, 1, 23, 0),
        ),
        DateTime(2026, 8, 2, 4, 0),
      );
    });

    test('Vakit verisi yoksa null', () {
      expect(
        nextDayPhaseBoundary(today: null, tomorrow: null, now: DateTime(2026, 8, 1, 9, 0)),
        isNull,
      );
    });
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/theme/day_phase_test.dart`
Expected: FAIL — `day_phase.dart` yok, import çözülemiyor.

- [ ] **Step 3: Implementasyonu yaz**

Create: `lib/core/theme/day_phase.dart`

```dart
import '../models/prayer_time.dart';

/// Günün, palet değişimini belirleyen dört dilimi.
///
/// Sınırlar: [morning] İmsak→Öğle, [afternoon] Öğle→İkindi,
/// [evening] İkindi→**Yatsı**, [night] Yatsı→(ertesi gün) İmsak.
///
/// Gece Akşam'da değil Yatsı'da başlar: akşam ezanı ile yatsı arasında
/// gökyüzü hâlâ aydınlıktır.
enum DayPhase { morning, afternoon, evening, night }

/// Vakit verisi olmadığında kullanılan dilim (spec D5).
const DayPhase _fallbackPhase = DayPhase.evening;

/// [now] anının hangi dilime düştüğünü döner.
///
/// Sınır anları bir sonraki dilime aittir: tam Öğle vaktinde [DayPhase.afternoon].
/// [today] yoksa [DayPhase.evening] döner.
DayPhase resolveDayPhase({
  PrayerTime? today,
  PrayerTime? tomorrow,
  required DateTime now,
}) {
  if (today == null) return _fallbackPhase;

  if (now.isBefore(today.fajr)) {
    // Gece yarısı ile İmsak arası: dünün Yatsı'sından süregelen gece.
    return DayPhase.night;
  }
  if (now.isBefore(today.dhuhr)) return DayPhase.morning;
  if (now.isBefore(today.asr)) return DayPhase.afternoon;
  if (now.isBefore(today.isha)) return DayPhase.evening;
  return DayPhase.night;
}

/// Bir sonraki dilim sınırının zamanı. Çağıran bu ana tek seferlik bir
/// `Timer` kurar; dakikalık yoklamaya gerek kalmaz.
///
/// Gece diliminde sınır ertesi günün İmsak'ıdır; [tomorrow] yoksa
/// [today]'in İmsak'ına 24 saat eklenir. [today] yoksa `null` döner.
DateTime? nextDayPhaseBoundary({
  PrayerTime? today,
  PrayerTime? tomorrow,
  required DateTime now,
}) {
  if (today == null) return null;

  for (final boundary in [today.fajr, today.dhuhr, today.asr, today.isha]) {
    if (now.isBefore(boundary)) return boundary;
  }

  // Yatsı geçildi: sıradaki sınır ertesi günün İmsak'ı.
  return tomorrow?.fajr ?? today.fajr.add(const Duration(days: 1));
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini gör**

Run: `flutter test test/theme/day_phase_test.dart`
Expected: 11 test PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/day_phase.dart test/theme/day_phase_test.dart
git commit -m "feat: gun dilimi cozumleyicisi (DayPhase)

Namaz vakitlerinden palet dilimini ve bir sonraki dilim sinirini
hesaplayan saf fonksiyonlar. Sinir Aksam degil Yatsi; gece ertesi gunun
Imsak'ina kadar surer. Vakit verisi yoksa evening."
```

---

## Task 4: `AppearanceSettings` modeli ve kalıcılık

`settings` tablosu zaten `key TEXT PRIMARY KEY, value TEXT` şemasına sahip — **migration gerekmez**.

**Files:**
- Create: `lib/core/models/appearance_settings.dart`
- Modify: `lib/core/interfaces/local_storage.dart`
- Modify: `lib/features/prayer_times/data/sqlite_storage.dart`
- Test: `test/theme/appearance_settings_test.dart`

**Interfaces:**
- Consumes: `DayPhase` (Task 3)
- Produces:
  - `enum AppThemeMode { dark, light, system }`
  - `class AppearanceSettings { final AppThemeMode themeMode; final bool timeBasedColor; final DayPhase fixedPalette; }` — `const AppearanceSettings({this.themeMode = AppThemeMode.dark, this.timeBasedColor = true, this.fixedPalette = DayPhase.evening})`, `copyWith`, `==`, `hashCode`, `toMap()/fromMap()` (`Map<String, String>`)
  - `LocalStorage.getAppearanceSettings() → Future<AppearanceSettings>`
  - `LocalStorage.saveAppearanceSettings(AppearanceSettings) → Future<void>`

- [ ] **Step 1: Başarısız testi yaz**

Create: `test/theme/appearance_settings_test.dart`

```dart
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Varsayilanlar: koyu tema, vakte gore renk acik, sabit palet evening', () {
    const settings = AppearanceSettings();

    expect(settings.themeMode, AppThemeMode.dark);
    expect(settings.timeBasedColor, isTrue);
    expect(settings.fixedPalette, DayPhase.evening);
  });

  test('toMap/fromMap gidis donusu degeri korur', () {
    const original = AppearanceSettings(
      themeMode: AppThemeMode.system,
      timeBasedColor: false,
      fixedPalette: DayPhase.night,
    );

    expect(AppearanceSettings.fromMap(original.toMap()), original);
  });

  test('Bilinmeyen ya da eksik anahtarlar varsayilana duser', () {
    final restored = AppearanceSettings.fromMap({
      'appearance_theme_mode': 'bilinmeyen',
      'appearance_fixed_palette': '',
    });

    expect(restored, const AppearanceSettings());
  });

  test('copyWith yalnizca verilen alani degistirir', () {
    const original = AppearanceSettings();
    final changed = original.copyWith(timeBasedColor: false);

    expect(changed.timeBasedColor, isFalse);
    expect(changed.themeMode, original.themeMode);
    expect(changed.fixedPalette, original.fixedPalette);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/theme/appearance_settings_test.dart`
Expected: FAIL — `appearance_settings.dart` yok.

- [ ] **Step 3: Modeli yaz**

Create: `lib/core/models/appearance_settings.dart`

```dart
import '../theme/day_phase.dart';

/// Kullanıcının seçtiği tema modu. [system] cihazın parlaklık tercihini izler.
enum AppThemeMode { dark, light, system }

/// Görünüm tercihleri. `settings` tablosunda anahtar-değer olarak saklanır.
class AppearanceSettings {
  static const String themeModeKey = 'appearance_theme_mode';
  static const String timeBasedColorKey = 'appearance_time_based_color';
  static const String fixedPaletteKey = 'appearance_fixed_palette';

  /// Koyu / açık / sistem.
  final AppThemeMode themeMode;

  /// Açıkken palet gün içinde vakte göre ilerler.
  final bool timeBasedColor;

  /// [timeBasedColor] kapalıyken kullanılacak sabit palet. Anahtar açıkken
  /// değer korunur ama etkisizdir — kullanıcı kapatıp açtığında seçimi
  /// kaybolmasın diye.
  final DayPhase fixedPalette;

  const AppearanceSettings({
    this.themeMode = AppThemeMode.dark,
    this.timeBasedColor = true,
    this.fixedPalette = DayPhase.evening,
  });

  AppearanceSettings copyWith({
    AppThemeMode? themeMode,
    bool? timeBasedColor,
    DayPhase? fixedPalette,
  }) {
    return AppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      timeBasedColor: timeBasedColor ?? this.timeBasedColor,
      fixedPalette: fixedPalette ?? this.fixedPalette,
    );
  }

  Map<String, String> toMap() {
    return {
      themeModeKey: themeMode.name,
      timeBasedColorKey: timeBasedColor.toString(),
      fixedPaletteKey: fixedPalette.name,
    };
  }

  factory AppearanceSettings.fromMap(Map<String, String> map) {
    const defaults = AppearanceSettings();
    return AppearanceSettings(
      themeMode: _enumByName(
        AppThemeMode.values,
        map[themeModeKey],
        defaults.themeMode,
      ),
      timeBasedColor: switch (map[timeBasedColorKey]) {
        'true' => true,
        'false' => false,
        _ => defaults.timeBasedColor,
      },
      fixedPalette: _enumByName(
        DayPhase.values,
        map[fixedPaletteKey],
        defaults.fixedPalette,
      ),
    );
  }

  static T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) {
    return other is AppearanceSettings &&
        other.themeMode == themeMode &&
        other.timeBasedColor == timeBasedColor &&
        other.fixedPalette == fixedPalette;
  }

  @override
  int get hashCode => Object.hash(themeMode, timeBasedColor, fixedPalette);
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini gör**

Run: `flutter test test/theme/appearance_settings_test.dart`
Expected: 4 test PASS.

- [ ] **Step 5: `LocalStorage` arayüzüne iki metot ekle**

Modify: `lib/core/interfaces/local_storage.dart` — dosyanın başına import ekle ve `getCalculationSettings` bildiriminin hemen altına:

```dart
import '../models/appearance_settings.dart';
```

```dart
  /// Görünüm tercihlerini döner; kayıt yoksa [AppearanceSettings] varsayılanları.
  Future<AppearanceSettings> getAppearanceSettings();

  /// Görünüm tercihlerini `settings` tablosuna yazar.
  Future<void> saveAppearanceSettings(AppearanceSettings settings);
```

- [ ] **Step 6: `SqliteStorage`'da implemente et**

Modify: `lib/features/prayer_times/data/sqlite_storage.dart` — dosyanın başına import ekle:

```dart
import '../../../core/models/appearance_settings.dart';
```

`markNotificationDefaultsInitialized` metodunun hemen ardına:

```dart
  @override
  Future<AppearanceSettings> getAppearanceSettings() async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key IN (?, ?, ?)',
      whereArgs: [
        AppearanceSettings.themeModeKey,
        AppearanceSettings.timeBasedColorKey,
        AppearanceSettings.fixedPaletteKey,
      ],
    );
    final map = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return AppearanceSettings.fromMap(map);
  }

  @override
  Future<void> saveAppearanceSettings(AppearanceSettings settings) async {
    final db = await database;
    final batch = db.batch();
    settings.toMap().forEach((key, value) {
      batch.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }
```

- [ ] **Step 7: Analiz ve testler**

Run: `flutter analyze && flutter test`
Expected: `No issues found`, tüm testler PASS.

`LocalStorage`'ı implemente eden test sahteleri varsa (`test/` altında `implements LocalStorage` arayan `grep -rn "implements LocalStorage" test/`) yeni metotlar yüzünden derleme hatası verir; her birine varsayılan döndüren birer metot ekle:

```dart
  @override
  Future<AppearanceSettings> getAppearanceSettings() async =>
      const AppearanceSettings();

  @override
  Future<void> saveAppearanceSettings(AppearanceSettings settings) async {}
```

- [ ] **Step 8: Commit**

```bash
git add lib/core/models/appearance_settings.dart lib/core/interfaces/local_storage.dart lib/features/prayer_times/data/sqlite_storage.dart test/theme/appearance_settings_test.dart
git commit -m "feat: gorunum tercihleri modeli ve kaliciligi

AppearanceSettings (tema modu, vakte gore renk, sabit palet) mevcut
anahtar-deger settings tablosuna yaziliyor; migration gerekmedi.
Bilinmeyen degerler varsayilana duser."
```

---

## Task 5: Tipografi ölçeği ve `AppTokens`

**Files:**
- Create: `lib/core/theme/app_typography.dart`
- Create: `lib/core/theme/app_tokens.dart`
- Create: `lib/core/theme/palettes.dart`
- Test: `test/theme/app_tokens_test.dart`

**Interfaces:**
- Consumes: `DayPhase` (Task 3)
- Produces:
  - `class AppTypography` — statik `TextStyle` sabitleri (`counter`, `screenTitle`, `rowTitle`, `rowSubtitle`, `gridValue`, `tomorrowValue`, `counterLabel`, `sectionLabel`, `gridPrayerName`, `rulerTime`, `tabLabel`, `dateLine`, `hint`). Renk taşımaz — renk `AppTokens`'tan gelir.
  - `class AppTokens extends ThemeExtension<AppTokens>` — alanlar: `accent`, `surface`, `border`, `divider`, `secondarySurface`, `mutedTrack`, `textPrimary`, `textSecondary`, `textTertiary`, `textValue`, `backgroundStops` (`List<Color>`, 3 eleman). `copyWith`, `lerp`.
  - `AppTokens paletteFor(DayPhase phase, Brightness brightness)`

- [ ] **Step 1: Başarısız testi yaz**

Create: `test/theme/app_tokens_test.dart`

```dart
import 'package:ezanvakti/core/theme/app_tokens.dart';
import 'package:ezanvakti/core/theme/app_typography.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('paletteFor', () {
    test('Sekiz palet de tanimli ve zemin uc duraga sahip', () {
      for (final phase in DayPhase.values) {
        for (final brightness in Brightness.values) {
          final tokens = paletteFor(phase, brightness);
          expect(tokens.backgroundStops.length, 3, reason: '$phase/$brightness');
        }
      }
    });

    test('Koyu Aksam paleti spec degerlerini tasir', () {
      final tokens = paletteFor(DayPhase.evening, Brightness.dark);

      expect(tokens.accent, const Color(0xFFE09FB8));
      expect(tokens.textPrimary, const Color(0xFFF3EEF4));
      expect(tokens.backgroundStops.first, const Color(0xFF4A2144));
      expect(tokens.backgroundStops.last, const Color(0xFF120E1B));
    });

    test('Acik temada murekkep paletin Metin1 rengidir', () {
      // Kural: acik tema yuzey/kenarlik/ayirac renkleri textPrimary uzerinden
      // turetilir. GULKURUSU'ndaki tasarim sapmasi kurala uyduruldu.
      final tokens = paletteFor(DayPhase.evening, Brightness.light);

      expect(tokens.textPrimary, const Color(0xFF201A1E));
      expect(tokens.surface.a, lessThan(0.2)); // dusuk alfa
      expect(tokens.surface.r, closeTo(tokens.textPrimary.r, 0.001));
      expect(tokens.surface.g, closeTo(tokens.textPrimary.g, 0.001));
      expect(tokens.surface.b, closeTo(tokens.textPrimary.b, 0.001));
    });
  });

  group('AppTokens.lerp', () {
    test('t=0 ve t=1 uc degerleri dondurur', () {
      final a = paletteFor(DayPhase.morning, Brightness.dark);
      final b = paletteFor(DayPhase.night, Brightness.dark);

      expect(a.lerp(b, 0).accent, a.accent);
      expect(a.lerp(b, 1).accent, b.accent);
    });

    test('Ara degerde zemin duraklari kaybolmaz', () {
      final a = paletteFor(DayPhase.morning, Brightness.dark);
      final b = paletteFor(DayPhase.night, Brightness.dark);

      final mid = a.lerp(b, 0.5);

      expect(mid.backgroundStops.length, 3);
      expect(mid.accent, isNot(a.accent));
      expect(mid.accent, isNot(b.accent));
    });
  });

  group('AppTypography', () {
    test('Tum boyutlar 10 basamakli olcek icinde', () {
      const scale = {11.0, 12.0, 13.0, 14.0, 16.0, 17.0, 20.0, 24.0, 44.0, 62.0};
      final styles = <TextStyle>[
        AppTypography.counter,
        AppTypography.screenTitle,
        AppTypography.rowTitle,
        AppTypography.rowSubtitle,
        AppTypography.gridValue,
        AppTypography.tomorrowValue,
        AppTypography.counterLabel,
        AppTypography.sectionLabel,
        AppTypography.gridPrayerName,
        AppTypography.rulerTime,
        AppTypography.tabLabel,
        AppTypography.dateLine,
        AppTypography.hint,
      ];

      for (final style in styles) {
        expect(scale, contains(style.fontSize), reason: '${style.fontSize}px olcek disi');
      }
    });

    test('Saat gosteren stiller tabular figures kullanir', () {
      for (final style in [
        AppTypography.counter,
        AppTypography.gridValue,
        AppTypography.tomorrowValue,
        AppTypography.rulerTime,
      ]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/theme/app_tokens_test.dart`
Expected: FAIL — dosyalar yok.

- [ ] **Step 3: Tipografiyi yaz**

Create: `lib/core/theme/app_typography.dart`

```dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Uygulamanın font ölçeği ve adlandırılmış metin stilleri.
///
/// Tasarım markup'ında 21 ad-hoc boyut vardı; hepsi aşağıdaki 10 basamağa
/// normalize edildi. Ekranlarda çıplak `fontSize` yazılmaz, bu sabitler
/// kullanılır. Stiller renk taşımaz — renk `AppTokens`'tan gelir.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Manrope';

  /// İzin verilen tek font boyutu kümesi.
  static const Set<double> scale = {11, 12, 13, 14, 16, 17, 20, 24, 44, 62};

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Ana ekrandaki geri sayım.
  static const TextStyle counter = TextStyle(
    fontFamily: fontFamily,
    fontSize: 62,
    fontWeight: FontWeight.w800,
    letterSpacing: -2.79,
    height: 1,
    fontFeatures: _tabular,
  );

  /// App bar başlığı.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w800,
  );

  /// Liste satırı başlığı ve konum başlığı.
  static const TextStyle rowTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.24,
  );

  /// Liste satırı alt metni.
  static const TextStyle rowSubtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Ana ekrandaki vakit ızgarasının saat değeri.
  static const TextStyle gridValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.43,
    fontFeatures: _tabular,
  );

  /// "Yarın" şeridindeki saat değeri.
  static const TextStyle tomorrowValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );

  /// Sayacın üstündeki "SONRAKİ · AKŞAM" etiketi.
  static const TextStyle counterLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.4,
  );

  /// "3 ALARM", "SESSİZ SAATLER" gibi bölüm etiketleri.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.76,
  );

  /// Izgaradaki "İMSAK", "GÜNEŞ" vakit adları.
  static const TextStyle gridPrayerName = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.66,
  );

  /// Gün cetvelindeki saatler.
  static const TextStyle rulerTime = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabular,
  );

  /// Kayan segment etiketi.
  static const TextStyle tabLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.14,
  );

  /// Miladi/hicri tarih satırı.
  static const TextStyle dateLine = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Yardım ve alt bilgi metinleri.
  static const TextStyle hint = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
}
```

- [ ] **Step 4: `AppTokens`'ı yaz**

Create: `lib/core/theme/app_tokens.dart`

```dart
import 'package:flutter/material.dart';

/// Tek bir paletin tüm renk token'ları.
///
/// Widget'lar renk sabiti yazmaz; `Theme.of(context).extension<AppTokens>()!`
/// (ya da `context.tokens`) üzerinden okur. `lerp` sayesinde palet değişimi
/// `AnimatedTheme` ile yumuşatılabilir.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  /// Vurgu rengi. Yalnızca vakit bilgisi ve tek birincil eylem kullanır.
  final Color accent;

  /// Grup/kart yüzeyi (mürekkep %5).
  final Color surface;

  /// Kart kenarlığı (mürekkep %7).
  final Color border;

  /// Satır ayıracı (mürekkep %9).
  final Color divider;

  /// "Yarın" satırı gibi ikincil yüzeyler (mürekkep %4).
  final Color secondarySurface;

  /// Cetvel yatağı gibi pasif şeritler (mürekkep %9).
  final Color mutedTrack;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Liste ve ızgaradaki saat değerleri.
  final Color textValue;

  /// Zemin radial gradyanının üç durağı (0%, 44%, 100%).
  final List<Color> backgroundStops;

  const AppTokens({
    required this.accent,
    required this.surface,
    required this.border,
    required this.divider,
    required this.secondarySurface,
    required this.mutedTrack,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textValue,
    required this.backgroundStops,
  });

  /// Zemin gradyanı. Geometri her palette aynıdır; yalnızca renkler değişir.
  /// CSS karşılığı: `radial-gradient(125% 58% at 70% -4%, ...)`.
  RadialGradient get backgroundGradient => RadialGradient(
    center: const Alignment(0.40, -1.08),
    radius: 1.25,
    colors: backgroundStops,
    stops: const [0.0, 0.44, 1.0],
  );

  @override
  AppTokens copyWith({
    Color? accent,
    Color? surface,
    Color? border,
    Color? divider,
    Color? secondarySurface,
    Color? mutedTrack,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textValue,
    List<Color>? backgroundStops,
  }) {
    return AppTokens(
      accent: accent ?? this.accent,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      secondarySurface: secondarySurface ?? this.secondarySurface,
      mutedTrack: mutedTrack ?? this.mutedTrack,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textValue: textValue ?? this.textValue,
      backgroundStops: backgroundStops ?? this.backgroundStops,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      accent: Color.lerp(accent, other.accent, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      secondarySurface: Color.lerp(
        secondarySurface,
        other.secondarySurface,
        t,
      )!,
      mutedTrack: Color.lerp(mutedTrack, other.mutedTrack, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textValue: Color.lerp(textValue, other.textValue, t)!,
      backgroundStops: [
        for (var i = 0; i < backgroundStops.length; i++)
          Color.lerp(backgroundStops[i], other.backgroundStops[i], t)!,
      ],
    );
  }
}
```

- [ ] **Step 5: 8 paleti yaz**

Create: `lib/core/theme/palettes.dart`

```dart
import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'day_phase.dart';

/// Yüzey/kenarlık/ayıraç alfa değerleri sabittir; değişen yalnızca üzerine
/// bindirilen **mürekkep** rengidir. Koyu temada mürekkep her palette beyaz,
/// açık temada paletin kendi Metin1 rengidir — böylece kartlar gri değil,
/// zeminin renkli gölgesi olur.
const double _surfaceAlpha = 0.05;
const double _borderAlpha = 0.07;
const double _dividerAlpha = 0.09;
const double _secondarySurfaceAlpha = 0.04;
const double _mutedTrackAlpha = 0.09;

AppTokens _palette({
  required Color accent,
  required Color ink,
  required Color textPrimary,
  required Color textSecondary,
  required Color textTertiary,
  required Color textValue,
  required List<Color> backgroundStops,
}) {
  return AppTokens(
    accent: accent,
    surface: ink.withValues(alpha: _surfaceAlpha),
    border: ink.withValues(alpha: _borderAlpha),
    divider: ink.withValues(alpha: _dividerAlpha),
    secondarySurface: ink.withValues(alpha: _secondarySurfaceAlpha),
    mutedTrack: ink.withValues(alpha: _mutedTrackAlpha),
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textTertiary: textTertiary,
    textValue: textValue,
    backgroundStops: backgroundStops,
  );
}

/// Koyu temada mürekkep her palette beyazdır.
const Color _darkInk = Color(0xFFFFFFFF);

// ── Koyu tema ───────────────────────────────────────────────────────────────

/// ÇİVİT — İmsak → Öğle.
final AppTokens _morningDark = _palette(
  accent: const Color(0xFF93C4E8),
  ink: _darkInk,
  textPrimary: const Color(0xFFE8F0F8),
  textSecondary: const Color(0xFFA5BDD2),
  textTertiary: const Color(0xFF8DA8C2),
  textValue: const Color(0xFFC4D7E8),
  backgroundStops: const [
    Color(0xFF2C5279),
    Color(0xFF143049),
    Color(0xFF08141F),
  ],
);

/// KURŞUNİ — Öğle → İkindi.
final AppTokens _afternoonDark = _palette(
  accent: const Color(0xFFD8E8EE),
  ink: _darkInk,
  textPrimary: const Color(0xFFF0F5F7),
  textSecondary: const Color(0xFFAFC3CB),
  textTertiary: const Color(0xFF98AEB7),
  textValue: const Color(0xFFCDDCE2),
  backgroundStops: const [
    Color(0xFF40525C),
    Color(0xFF202C33),
    Color(0xFF10171B),
  ],
);

/// ERGUVAN — İkindi → Yatsı.
final AppTokens _eveningDark = _palette(
  accent: const Color(0xFFE09FB8),
  ink: _darkInk,
  textPrimary: const Color(0xFFF3EEF4),
  textSecondary: const Color(0xFFB5A8C1),
  textTertiary: const Color(0xFFA294AF),
  textValue: const Color(0xFFCFC3D6),
  backgroundStops: const [
    Color(0xFF4A2144),
    Color(0xFF241634),
    Color(0xFF120E1B),
  ],
);

/// SÜMBÜL — Yatsı → İmsak.
final AppTokens _nightDark = _palette(
  accent: const Color(0xFFCDA6E4),
  ink: _darkInk,
  textPrimary: const Color(0xFFF2ECF6),
  textSecondary: const Color(0xFFB3A5C1),
  textTertiary: const Color(0xFF9D8FAB),
  textValue: const Color(0xFFD5C9DF),
  backgroundStops: const [
    Color(0xFF2A2038),
    Color(0xFF17111F),
    Color(0xFF0A080E),
  ],
);

// ── Açık tema ───────────────────────────────────────────────────────────────
// Mürekkep = paletin Metin1 rengi (spec §4.1).

/// NİLÜFER — İmsak → Öğle.
final AppTokens _morningLight = _palette(
  accent: const Color(0xFF265F8E),
  ink: const Color(0xFF0E1D2C),
  textPrimary: const Color(0xFF0E1D2C),
  textSecondary: const Color(0xFF43596D),
  textTertiary: const Color(0xFF53697C),
  textValue: const Color(0xFF33495E),
  backgroundStops: const [
    Color(0xFFDCE9F7),
    Color(0xFFEDF3FA),
    Color(0xFFF8FBFD),
  ],
);

/// SEDEF — Öğle → İkindi.
final AppTokens _afternoonLight = _palette(
  accent: const Color(0xFF2A5B68),
  ink: const Color(0xFF0F1C21),
  textPrimary: const Color(0xFF0F1C21),
  textSecondary: const Color(0xFF435A62),
  textTertiary: const Color(0xFF536A72),
  textValue: const Color(0xFF334A52),
  backgroundStops: const [
    Color(0xFFE2ECF0),
    Color(0xFFF1F6F8),
    Color(0xFFF9FCFC),
  ],
);

/// GÜLKURUSU — İkindi → Yatsı.
final AppTokens _eveningLight = _palette(
  accent: const Color(0xFF9E4266),
  ink: const Color(0xFF201A1E),
  textPrimary: const Color(0xFF201A1E),
  textSecondary: const Color(0xFF5A4A50),
  textTertiary: const Color(0xFF6B5A60),
  textValue: const Color(0xFF4A3B41),
  backgroundStops: const [
    Color(0xFFF7E7EB),
    Color(0xFFFAF2F4),
    Color(0xFFFDFAFA),
  ],
);

/// LEYLAK — Yatsı → İmsak.
final AppTokens _nightLight = _palette(
  accent: const Color(0xFF5E3A80),
  ink: const Color(0xFF1A1424),
  textPrimary: const Color(0xFF1A1424),
  textSecondary: const Color(0xFF4F4260),
  textTertiary: const Color(0xFF5F5270),
  textValue: const Color(0xFF3F3350),
  backgroundStops: const [
    Color(0xFFEBE4F1),
    Color(0xFFF7F4F9),
    Color(0xFFFCFBFD),
  ],
);

/// Verilen dilim ve parlaklık için paleti döner.
AppTokens paletteFor(DayPhase phase, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return switch (phase) {
    DayPhase.morning => isDark ? _morningDark : _morningLight,
    DayPhase.afternoon => isDark ? _afternoonDark : _afternoonLight,
    DayPhase.evening => isDark ? _eveningDark : _eveningLight,
    DayPhase.night => isDark ? _nightDark : _nightLight,
  };
}
```

- [ ] **Step 6: Testi çalıştır, geçtiğini gör**

Run: `flutter test test/theme/app_tokens_test.dart`
Expected: 7 test PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/app_typography.dart lib/core/theme/app_tokens.dart lib/core/theme/palettes.dart test/theme/app_tokens_test.dart
git commit -m "feat: tipografi olcegi ve 8 palet token'i

AppTypography 10 basamakli olcegi ve adlandirilmis stilleri tasiyor;
saat gosteren stiller tabular figures kullaniyor. AppTokens bir
ThemeExtension olarak renk token'larini ve lerp'i sagliyor. Sekiz palet
(4 dilim x koyu/acik) tanimlandi; acik temada murekkep paletin Metin1
rengi."
```

---

## Task 6: `ThemeController`

**Files:**
- Create: `lib/core/theme/theme_controller.dart`
- Create: `lib/core/theme/tokens_context.dart`
- Modify: `lib/core/di/service_locator.dart`
- Test: `test/theme/theme_controller_test.dart`

**Interfaces:**
- Consumes: `resolveDayPhase(...)`, `nextDayPhaseBoundary(...)` (Task 3); `AppearanceSettings`, `AppThemeMode`, `LocalStorage.getAppearanceSettings/saveAppearanceSettings` (Task 4); `paletteFor(DayPhase, Brightness)` (Task 5)
- Produces:
  - `class ThemeController extends ChangeNotifier` — `ThemeController({required LocalStorage storage, DateTime Function()? clock})`
  - `Future<void> load()`, `void updatePrayerTimes({PrayerTime? today, PrayerTime? tomorrow})`, `void setPlatformBrightness(Brightness)`, `Future<void> setThemeMode(AppThemeMode)`, `Future<void> setTimeBasedColor(bool)`, `Future<void> setFixedPalette(DayPhase)`
  - `AppearanceSettings get settings`, `Brightness get brightness`, `DayPhase get phase`, `AppTokens get tokens`
  - `extension TokensContext on BuildContext { AppTokens get tokens; }`

- [ ] **Step 1: Başarısız testi yaz**

Create: `test/theme/theme_controller_test.dart`

```dart
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:ezanvakti/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryStorage implements LocalStorage {
  AppearanceSettings stored = const AppearanceSettings();

  @override
  Future<AppearanceSettings> getAppearanceSettings() async => stored;

  @override
  Future<void> saveAppearanceSettings(AppearanceSettings settings) async {
    stored = settings;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PrayerTime _day(int day) {
  DateTime at(int hour) => DateTime(2026, 8, day, hour, 0);
  return PrayerTime(
    fajr: at(4),
    sunrise: at(6),
    dhuhr: at(13),
    asr: at(17),
    maghrib: at(20),
    isha: at(22),
    date: DateTime(2026, 8, day),
  );
}

void main() {
  test('Vakit verisi yokken evening paleti kullanilir', () async {
    final controller = ThemeController(
      storage: _InMemoryStorage(),
      clock: () => DateTime(2026, 8, 1, 9, 0),
    );
    await controller.load();

    expect(controller.phase, DayPhase.evening);
    expect(controller.tokens.accent, paletteFor(DayPhase.evening, Brightness.dark).accent);
  });

  test('Vakit verisi gelince dilim hesaplanir', () async {
    final controller = ThemeController(
      storage: _InMemoryStorage(),
      clock: () => DateTime(2026, 8, 1, 9, 0),
    );
    await controller.load();

    controller.updatePrayerTimes(today: _day(1), tomorrow: _day(2));

    expect(controller.phase, DayPhase.morning);
  });

  test('Vakte gore renk kapaliyken sabit palet kullanilir', () async {
    final storage = _InMemoryStorage()
      ..stored = const AppearanceSettings(
        timeBasedColor: false,
        fixedPalette: DayPhase.night,
      );
    final controller = ThemeController(
      storage: storage,
      clock: () => DateTime(2026, 8, 1, 9, 0),
    );
    await controller.load();
    controller.updatePrayerTimes(today: _day(1), tomorrow: _day(2));

    expect(controller.phase, DayPhase.night);
  });

  test('Tema modu system iken platform parlakligi izlenir', () async {
    final controller = ThemeController(
      storage: _InMemoryStorage()..stored = const AppearanceSettings(themeMode: AppThemeMode.system),
      clock: () => DateTime(2026, 8, 1, 9, 0),
    );
    await controller.load();

    controller.setPlatformBrightness(Brightness.light);

    expect(controller.brightness, Brightness.light);
  });

  test('Ayar degisimi kalici olur ve dinleyicileri uyarir', () async {
    final storage = _InMemoryStorage();
    final controller = ThemeController(
      storage: storage,
      clock: () => DateTime(2026, 8, 1, 9, 0),
    );
    await controller.load();

    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setTimeBasedColor(false);

    expect(storage.stored.timeBasedColor, isFalse);
    expect(notified, greaterThan(0));
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/theme/theme_controller_test.dart`
Expected: FAIL — `theme_controller.dart` yok.

- [ ] **Step 3: Controller'ı yaz**

Create: `lib/core/theme/theme_controller.dart`

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../interfaces/local_storage.dart';
import '../models/appearance_settings.dart';
import '../models/prayer_time.dart';
import 'app_tokens.dart';
import 'day_phase.dart';
import 'palettes.dart';

/// Palet geçişlerinin süresi. Vakit sınırı, tema değişimi ve sabit palet
/// seçimi — hepsi aynı süreyi kullanır (spec D6).
const Duration kPaletteTransition = Duration(milliseconds: 400);

/// Görünüm ayarlarını, gün dilimini ve aktif paleti yöneten tek merkez.
///
/// Dakikalık yoklama yapmaz: bir sonraki dilim sınırına tek seferlik bir
/// [Timer] kurar, tetiklenince yeniden hesaplayıp timer'ı yeniler.
class ThemeController extends ChangeNotifier {
  final LocalStorage _storage;
  final DateTime Function() _clock;

  AppearanceSettings _settings = const AppearanceSettings();
  Brightness _platformBrightness = Brightness.dark;
  PrayerTime? _today;
  PrayerTime? _tomorrow;
  Timer? _boundaryTimer;

  ThemeController({required LocalStorage storage, DateTime Function()? clock})
    : _storage = storage,
      _clock = clock ?? DateTime.now;

  AppearanceSettings get settings => _settings;

  /// Etkin parlaklık: kullanıcı seçimi, `system` ise platformunki.
  Brightness get brightness => switch (_settings.themeMode) {
    AppThemeMode.dark => Brightness.dark,
    AppThemeMode.light => Brightness.light,
    AppThemeMode.system => _platformBrightness,
  };

  /// Etkin dilim. "Vakte göre renk" kapalıysa kullanıcının seçtiği sabit palet.
  DayPhase get phase {
    if (!_settings.timeBasedColor) return _settings.fixedPalette;
    return resolveDayPhase(
      today: _today,
      tomorrow: _tomorrow,
      now: _clock(),
    );
  }

  AppTokens get tokens => paletteFor(phase, brightness);

  /// Kayıtlı ayarları okur. Uygulama açılışında bir kez çağrılır.
  Future<void> load() async {
    _settings = await _storage.getAppearanceSettings();
    notifyListeners();
  }

  /// Vakit verisi değiştiğinde çağrılır; dilimi ve sınır timer'ını tazeler.
  void updatePrayerTimes({PrayerTime? today, PrayerTime? tomorrow}) {
    _today = today;
    _tomorrow = tomorrow;
    _scheduleBoundary();
    notifyListeners();
  }

  /// Cihazın gece/gündüz tercihi değiştiğinde çağrılır.
  void setPlatformBrightness(Brightness brightness) {
    if (_platformBrightness == brightness) return;
    _platformBrightness = brightness;
    if (_settings.themeMode == AppThemeMode.system) notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) =>
      _persist(_settings.copyWith(themeMode: mode));

  Future<void> setTimeBasedColor(bool enabled) =>
      _persist(_settings.copyWith(timeBasedColor: enabled));

  Future<void> setFixedPalette(DayPhase palette) =>
      _persist(_settings.copyWith(fixedPalette: palette));

  Future<void> _persist(AppearanceSettings next) async {
    if (next == _settings) return;
    _settings = next;
    await _storage.saveAppearanceSettings(next);
    _scheduleBoundary();
    notifyListeners();
  }

  /// Uygulama ön plana geldiğinde çağrılır: arka planda timer'ın çalışmamış
  /// olma ihtimaline karşı dilimi ve timer'ı yeniden kurar.
  void refresh() {
    _scheduleBoundary();
    notifyListeners();
  }

  void _scheduleBoundary() {
    _boundaryTimer?.cancel();
    _boundaryTimer = null;

    // Sabit palet modunda sınır beklemenin anlamı yok.
    if (!_settings.timeBasedColor) return;

    final boundary = nextDayPhaseBoundary(
      today: _today,
      tomorrow: _tomorrow,
      now: _clock(),
    );
    if (boundary == null) return;

    final delay = boundary.difference(_clock());
    if (delay.isNegative) return;

    _boundaryTimer = Timer(delay, () {
      notifyListeners();
      _scheduleBoundary();
    });
  }

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: `context.tokens` kısayolunu yaz**

Create: `lib/core/theme/tokens_context.dart`

```dart
import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Widget'ların renk token'larına kısa yoldan erişmesi için.
///
/// `Theme.of(context).extension<AppTokens>()!` yerine `context.tokens`.
extension TokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
```

- [ ] **Step 5: Testi çalıştır, geçtiğini gör**

Run: `flutter test test/theme/theme_controller_test.dart`
Expected: 5 test PASS.

- [ ] **Step 6: DI'ya kaydet**

Modify: `lib/core/di/service_locator.dart` — dosyanın başına import ekle:

```dart
import '../theme/theme_controller.dart';
```

`initialize()` metodunun sonuna, `register<AlarmsManager>(...)` satırının hemen ardına:

```dart
    final themeController = ThemeController(storage: localStorage);
    await themeController.load();
    register<ThemeController>(themeController);
```

- [ ] **Step 7: Analiz ve tüm testler**

Run: `flutter analyze && flutter test`
Expected: `No issues found`, tüm testler PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/core/theme/theme_controller.dart lib/core/theme/tokens_context.dart lib/core/di/service_locator.dart test/theme/theme_controller_test.dart
git commit -m "feat: ThemeController ve context.tokens kisayolu

Ayarlari okuyup yazan, vakit verisinden dilimi hesaplayan ve bir sonraki
dilim sinirina tek seferlik Timer kuran merkez. Dakikalik yoklama yok.
Vakte gore renk kapaliyken kullanicinin sectigi sabit palet kullanilir."
```

---

## Task 7: `AppTheme`'i token'lardan üret ve uygulamaya bağla

Bu task'tan sonra uygulama gerçekten yeni palette çalışır. **Görsel karşılaştırma burada yapılır.**

**Files:**
- Modify: `lib/core/theme/app_theme.dart`
- Modify: `lib/main.dart`
- Test: `test/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: `AppTokens` (Task 5), `AppTypography` (Task 5), `ThemeController`, `kPaletteTransition` (Task 6)
- Produces: `ThemeData AppTheme.build(AppTokens tokens, Brightness brightness)`

- [ ] **Step 1: Plan öncesi ekran görüntülerini sakla**

Run:
```bash
mkdir -p /tmp/faz1-oncesi && cp screenshots/*.png /tmp/faz1-oncesi/ 2>/dev/null || \
  echo "screenshots/ bos — once mevcut dev uzerinde bir tur cek"
```

Eğer `screenshots/` boşsa, önce mevcut hâlin görüntülerini üret:
```bash
xcrun simctl uninstall booted com.ekrembulbul.ezanvakti
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart -d <simulator-udid>
cp screenshots/*.png /tmp/faz1-oncesi/
```

- [ ] **Step 2: Başarısız testi yaz**

Create: `test/theme/app_theme_test.dart`

```dart
import 'package:ezanvakti/core/theme/app_theme.dart';
import 'package:ezanvakti/core/theme/app_tokens.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('build, tokenlari ThemeData extension olarak tasir', () {
    final tokens = paletteFor(DayPhase.evening, Brightness.dark);
    final theme = AppTheme.build(tokens, Brightness.dark);

    expect(theme.extension<AppTokens>(), same(tokens));
  });

  test('ColorScheme vurgu rengini kullanir', () {
    final tokens = paletteFor(DayPhase.morning, Brightness.dark);
    final theme = AppTheme.build(tokens, Brightness.dark);

    expect(theme.colorScheme.primary, tokens.accent);
    expect(theme.brightness, Brightness.dark);
  });

  test('Acik temada brightness light olur', () {
    final tokens = paletteFor(DayPhase.morning, Brightness.light);
    final theme = AppTheme.build(tokens, Brightness.light);

    expect(theme.brightness, Brightness.light);
  });

  test('Font ailesi Manrope', () {
    final tokens = paletteFor(DayPhase.night, Brightness.dark);
    final theme = AppTheme.build(tokens, Brightness.dark);

    expect(theme.textTheme.bodyMedium?.fontFamily, 'Manrope');
  });
}
```

- [ ] **Step 3: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/theme/app_theme_test.dart`
Expected: FAIL — `AppTheme.build` tanımlı değil.

- [ ] **Step 4: `AppTheme`'i yeniden yaz**

Modify: `lib/core/theme/app_theme.dart` — dosyanın **tamamını** aşağıdakiyle değiştir. Eski statik renkler (`gold`, `primaryDark`, `nightGradient` vb.) hâlâ ekranlarda kullanılıyor; bu yüzden **silinmez**, `@Deprecated` işaretlenir ve Plan 2'de ekran ekran kaldırılır.

```dart
import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  // ── Gecis donemi sabitleri ────────────────────────────────────────────────
  // Bu degerler ekranlar token'lara tasinana kadar (Plan 2) yerinde kalir.
  // Yeni kod bunlari kullanmaz; `context.tokens` uzerinden okur.

  @Deprecated('AppTokens.accent kullanin — context.tokens.accent')
  static const Color gold = Color(0xFFD4AF37);
  @Deprecated('AppTokens.backgroundStops kullanin')
  static const Color primaryDark = Color(0xFF1A1A2E);
  @Deprecated('AppTokens.surface kullanin')
  static const Color primaryMedium = Color(0xFF16213E);
  @Deprecated('AppTokens.backgroundGradient kullanin')
  static const LinearGradient nightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
  );

  /// Verilen token setinden uygulama temasını üretir.
  static ThemeData build(AppTokens tokens, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: tokens.backgroundStops.last,
      extensions: <ThemeExtension<dynamic>>[tokens],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: tokens.accent,
        onPrimary: tokens.backgroundStops.last,
        secondary: tokens.accent,
        onSecondary: tokens.backgroundStops.last,
        error: isDark ? const Color(0xFFEF9A9A) : const Color(0xFFB3261E),
        onError: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
        surface: tokens.backgroundStops.last,
        onSurface: tokens.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.screenTitle.copyWith(
          color: tokens.textPrimary,
        ),
        iconTheme: IconThemeData(color: tokens.textPrimary),
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.counter.copyWith(color: tokens.accent),
        titleLarge: AppTypography.screenTitle.copyWith(color: tokens.textPrimary),
        titleMedium: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
        bodyLarge: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
        bodyMedium: AppTypography.rowSubtitle.copyWith(
          color: tokens.textSecondary,
        ),
        bodySmall: AppTypography.hint.copyWith(color: tokens.textTertiary),
        labelSmall: AppTypography.sectionLabel.copyWith(
          color: tokens.textTertiary,
        ),
      ),
      dividerTheme: DividerThemeData(color: tokens.divider, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: tokens.accent,
        textColor: tokens.textPrimary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.backgroundStops.last,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.backgroundStops.last,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: AppTypography.rowSubtitle.copyWith(
          color: tokens.textTertiary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? tokens.accent
              : tokens.textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? tokens.accent.withValues(alpha: 0.3)
              : tokens.mutedTrack;
        }),
      ),
    );
  }
}
```

Eski `AppTheme` içindeki `glassDecoration`, `softShadow`, `primaryGradient`, `sunriseGradient`, `cardGradient`, `primaryLight`, `accent`, `goldLight`, `white`, `offWhite`, `grey`, `darkGrey` ve `darkTheme` üyelerini **silme** — hâlâ kullanılıyorlar. `grep -rn "AppTheme\." lib --include='*.dart' | grep -v "AppTheme.build"` ile hangilerinin kullanıldığını doğrula ve yalnızca **hiç kullanılmayanları** kaldır.

- [ ] **Step 5: `main.dart`'ı bağla**

Modify: `lib/main.dart` — `MyApp` sınıfını aşağıdakiyle değiştir; `ServiceLocator` ve `ThemeController` import'larını ekle:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ServiceLocator().get<ThemeController>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
      ],
      child: Consumer<ThemeController>(
        builder: (context, controller, _) {
          // Cihazin gece/gunduz tercihi degisince "Sistem" modu izlesin.
          controller.setPlatformBrightness(
            MediaQuery.platformBrightnessOf(context),
          );

          return MaterialApp(
            title: AppConstants.appTitle,
            theme: AppTheme.build(controller.tokens, controller.brightness),
            themeAnimationDuration: kPaletteTransition,
            themeAnimationCurve: Curves.easeOutCubic,
            home: const AppRoot(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
```

`MediaQuery.platformBrightnessOf(context)` `MaterialApp`'in **üstünde** çağrıldığı için `WidgetsApp` henüz yok; bu yüzden `MyApp`'in `runApp` ile doğrudan verilmesi yeterlidir — Flutter kök `MediaQuery`'yi `View` üzerinden sağlar. Derleme hatası alırsan `MaterialApp`'i `Builder` ile sarıp `platformBrightnessOf` çağrısını `Builder` içine al.

`main()` içindeki `SystemChrome.setSystemUIOverlayStyle` çağrısı sabit renk kullanıyor; şimdilik olduğu gibi bırak — Plan 2'de token'a bağlanacak.

- [ ] **Step 6: Testler ve analiz**

Run: `flutter analyze && flutter test`
Expected: `No issues found`, tüm testler PASS.

`@Deprecated` işaretli üyelerin kullanımı `flutter analyze`'da `deprecated_member_use_from_same_package` uyarısı üretir. Bu beklenen bir durumdur ve Plan 2'de kapanır; **uyarıyı susturmak için `// ignore` ekleme.** Uyarı sayısını not al: `flutter analyze 2>&1 | grep -c deprecated_member_use_from_same_package`

- [ ] **Step 7: Uygulamayı çalıştır ve görsel karşılaştırma yap**

Run:
```bash
xcrun simctl uninstall booted com.ekrembulbul.ezanvakti
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart -d <simulator-udid>
```

`/tmp/faz1-oncesi/` ile `screenshots/` klasörlerini yan yana karşılaştır. **Beklenen fark:** renkler altın/lacivertten erguvana kaydı, font Manrope oldu. **Beklenmeyen fark:** yerleşim kayması, taşan metin, kaybolan öğe, okunmayan kontrast. Beklenmeyen fark varsa düzelt ve görüntüleri yeniden al.

- [ ] **Step 8: Commit**

```bash
git add lib/core/theme/app_theme.dart lib/main.dart test/theme/app_theme_test.dart
git commit -m "feat: temayi token'lardan uret ve uygulamaya bagla

AppTheme.build(AppTokens, Brightness) ThemeData uretiyor ve token'lari
ThemeExtension olarak tasiyor. MaterialApp ThemeController'i dinliyor;
palet gecisleri themeAnimationDuration ile 400 ms easeOutCubic.
Eski statik renkler @Deprecated isaretlendi, Plan 2'de kaldirilacak."
```

---

## Task 8: Manrope fontunu göm

**Files:**
- Create: `assets/fonts/Manrope-Medium.ttf`, `Manrope-SemiBold.ttf`, `Manrope-Bold.ttf`, `Manrope-ExtraBold.ttf`
- Modify: `pubspec.yaml`
- Test: `test/theme/font_test.dart`

**Interfaces:**
- Consumes: `AppTypography.fontFamily` (Task 5)
- Produces: yok

- [ ] **Step 1: Fontları indir**

Manrope, SIL Open Font License 1.1 ile dağıtılır — gömmek serbesttir. Statik `.ttf` dosyalarını resmî depodan al:

```bash
mkdir -p assets/fonts
cd /tmp && rm -rf manrope && git clone --depth 1 https://github.com/sharanda/manrope.git
cp /tmp/manrope/fonts/ttf/Manrope-Medium.ttf \
   /tmp/manrope/fonts/ttf/Manrope-SemiBold.ttf \
   /tmp/manrope/fonts/ttf/Manrope-Bold.ttf \
   /tmp/manrope/fonts/ttf/Manrope-ExtraBold.ttf \
   <proje-koku>/assets/fonts/
```

Depo yapısı farklıysa `find /tmp/manrope -name "Manrope-*.ttf"` ile dosyaları bul. Lisans dosyasını da kopyala: `cp /tmp/manrope/LICENSE assets/fonts/Manrope-LICENSE.txt`

- [ ] **Step 2: `pubspec.yaml`'a ekle**

Modify: `pubspec.yaml` — `assets:` bloğunun hemen ardına, aynı girinti seviyesinde:

```yaml
  fonts:
    - family: Manrope
      fonts:
        - asset: assets/fonts/Manrope-Medium.ttf
          weight: 500
        - asset: assets/fonts/Manrope-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Manrope-Bold.ttf
          weight: 700
        - asset: assets/fonts/Manrope-ExtraBold.ttf
          weight: 800
```

Run: `flutter pub get`

- [ ] **Step 3: Doğrulama testini yaz**

Create: `test/theme/font_test.dart`

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Manrope agirliklari assets altinda mevcut', () {
    for (final name in [
      'Manrope-Medium',
      'Manrope-SemiBold',
      'Manrope-Bold',
      'Manrope-ExtraBold',
    ]) {
      expect(
        File('assets/fonts/$name.ttf').existsSync(),
        isTrue,
        reason: '$name.ttf eksik',
      );
    }
  });

  test('pubspec Manrope ailesini dort agirlikla tanimliyor', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('family: Manrope'));
    for (final weight in [500, 600, 700, 800]) {
      expect(pubspec, contains('weight: $weight'));
    }
  });
}
```

- [ ] **Step 4: Testleri çalıştır**

Run: `flutter test test/theme/font_test.dart && flutter test`
Expected: hepsi PASS.

- [ ] **Step 5: Tabular figures'ı gerçek cihazda doğrula (spec V1)**

Uygulamayı simülatörde çalıştırıp ana ekranın geri sayımına bak: saniye değişirken rakam genişliği sabit kalmalı, sayaç sağa sola oynamamalı.

Run:
```bash
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart -d <simulator-udid>
```

`screenshots/05-ana-ekran.png` içindeki sayacı incele. Rakamlar eşit genişlikte değilse Manrope `tnum` desteklemiyor demektir; o durumda `AppTypography` içindeki `fontFeatures: _tabular` satırlarını kaldırıp her rakam için sabit genişlikli bir `SizedBox` sarmalı gerekir — bunu Plan 2'ye not düş, bu planda değiştirme.

- [ ] **Step 6: Commit**

```bash
git add assets/fonts pubspec.yaml pubspec.lock test/theme/font_test.dart
git commit -m "feat: Manrope fontunu gom (4 agirlik)

Uygulama offline-first oldugu icin runtime font indirme uygun degil;
500/600/700/800 agirliklari assets/fonts altina eklendi (SIL OFL 1.1).
Lisans dosyasi da kopyalandi."
```

---

## Self-Review

**1. Spec coverage**

| Spec bölümü | Karşılığı |
|---|---|
| §4.1 yüzey/mürekkep kuralı | Task 5 (`_palette` yardımcısı, alfa sabitleri) |
| §4.2 tipografi ölçeği | Task 5 (`AppTypography`), Task 8 (font dosyaları) |
| §4.3 8 palet + gradyan geometrisi | Task 5 (`palettes.dart`, `AppTokens.backgroundGradient`) |
| §5.1 `DayPhase`, `DayPhaseResolver` | Task 3 |
| §5.1 `AppTokens`, `ThemeController` | Task 5, Task 6 |
| §5.2 veri akışı + `AnimatedTheme` | Task 7 (`themeAnimationDuration`) |
| §5.3 saklama, 3 ayar anahtarı | Task 4 |
| §7 hata/kenar durumları | Task 3 (veri yok → evening; gece sarması), Task 6 (sabit palet, sistem parlaklığı) |
| §8 birim testleri | Task 3, 4, 5, 6, 7 |
| §9 Faz 6 borçları | Task 1, Task 2 |
| §10 V1 (tabular figures) | Task 8 Step 5 |
| §4.4 kayan segment | **Plan 2** — bu planın kapsamı dışında |
| §6 ekran gereksinimleri | **Plan 2** |
| §10 V3 (gradyan eşleşmesi), V4 (kontrast), V5 (tipografi sapması) | **Plan 3** |
| Faz 6 madde 3 (MVP kabul testleri) | **Plan 3** |

Bu planda karşılığı olmayan spec maddeleri bilinçli olarak Plan 2 ve Plan 3'e bırakıldı; hiçbiri unutulmadı.

**2. Placeholder scan:** Temiz. Her kod adımı çalıştırılabilir kod içeriyor; "uygun hata yönetimi ekle" tarzı yönerge yok. Task 8 Step 1'deki depo yolu, yapı değişmişse `find` ile bulunacak şekilde alternatifiyle verildi.

**3. Type consistency**

- `resolveDayPhase` / `nextDayPhaseBoundary` — Task 3'te tanımlandı, Task 6'da aynı adlarla ve aynı parametrelerle çağrıldı. Spec §5.1 imzada bir `yesterday` parametresi listeliyordu; implementasyon buna ihtiyaç duymuyor (gece yarısı–İmsak arası `now < today.fajr` kontrolüyle çözülüyor), ölü parametre olacağı için **plandan ve spec'ten çıkarıldı**.
- `AppearanceSettings` alan adları (`themeMode`, `timeBasedColor`, `fixedPalette`) Task 4 ve Task 6'da aynı.
- `paletteFor(DayPhase, Brightness)` Task 5'te tanımlandı, Task 6 ve Task 7'de aynı imzayla kullanıldı.
- `AppTheme.build(AppTokens, Brightness)` Task 7'de tanımlandı ve yalnızca orada kullanıldı.
- `kPaletteTransition` Task 6'da tanımlandı, Task 7'de kullanıldı.
- `AppTokens` alan adları Task 5'te tanımlandı; Task 7'de `accent`, `surface`, `divider`, `mutedTrack`, `textPrimary`, `textSecondary`, `textTertiary`, `backgroundStops` kullanıldı — hepsi mevcut.
