# Faz 4–6: İkon, Kontrast, Sürüm ve Devreden Borçlar — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 0.3.0 yeniden tasarımını yayına hazır hale getirmek — ERGUVAN uygulama ikonu ve splash, sekiz paletin kontrast doğrulaması, sekiz kombinasyonlu ekran görüntüsü kanıtı, sürüm/CHANGELOG ve MVP kabul testleri.

**Architecture:** İkon, tasarım dosyasının içindeki `__bundler_thumbnail` SVG'sinden türetilir; SVG'ler `tool/generate_icons.sh` içinde metin olarak yaşar ve headless Chrome ile PNG'ye rasterize edilir (makinede `rsvg-convert`/ImageMagick/Inkscape yok). Kontrast doğrulaması saf Dart birim testidir — `paletteFor` çıktısını okuyup WCAG 2.1 oranını hesaplar. Sekiz kombinasyonlu ekran görüntüsü, `ThemeController`'ın **mevcut public API'siyle** (`setTimeBasedColor(false)` + `setFixedPalette` + `setThemeMode`) sürülür; spec'in önerdiği test-only `overridePhase` girişine gerek yok, üretim koduna test kancası eklenmez.

**Tech Stack:** Flutter, `flutter_launcher_icons ^0.13.1`, `flutter_native_splash ^2.4.0`, `integration_test`, headless Google Chrome (rasterizer), Python 3 (PNG başlık doğrulaması).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-01-redesign-0.3.0-design.md`. Bu plan onun **Faz 4, Faz 5 ve Faz 6**'sını kapatır.
- **D7 — ikon varyantı:** ERGUVAN. Zemin radyal gradyan `#5A2A50` → `#150F1F`, hilal ve yıldız `#E09FB8`. Geometri tasarım dosyasındaki SVG'nin birebir aynısı (512 viewBox; hilal `cx=233 cy=256 r=141` eksi `cx=292 cy=218 r=125`; yıldız `cx=361 cy=179 r=18`).
- **D1 — tek sabit ikon**, her iki platformda. Palete göre değişen ikon kapsam dışı.
- **Kontrast eşikleri (spec §8):** Metin1/2/3/Değer ≥ **4.5:1**, accent ≥ **5.1:1**; ölçüm zemini **`backgroundStops` ortalaması** üzerine `surface` bindirilmiş hâl.
- Tüm iş `redesign/0.3.0` dalında kalır. `push` ve `merge` yok.
- Türkçe kullanıcı metinleri tam Türkçe karakterle. Kod içi yorumlar mevcut dosyaların stilini izler.
- Her task sonunda `flutter analyze` temiz ve `flutter test` yeşil olmadan commit yok.

### Ekran görüntüsü koşturma protokolü (zorunlu)

`flutter drive` çalıştıran her adımda **önce simülatör yeniden başlatılır**. Sebebi: AlarmKit izin dialog'u gibi artık bir sistem uyarısı ekranda kalırsa Flutter render'ı durur ve `takeScreenshot` bayat kareyi döner — 18 dosyanın 18'i de bayt bayt aynı çıkar. `simctl uninstall` bu uyarıyı **kapatmaz**, yalnızca `shutdown` + `boot` kapatır.

```bash
SIM=86EB40FD-7B75-4BCC-91CA-DCBED258902C   # iPhone 17 Pro, iOS 26.5
xcrun simctl shutdown "$SIM" || true
xcrun simctl boot "$SIM"
sleep 15
```

Koşturma sonrası **geçerlilik kontrolü** — benzersiz hash sayısı dosya sayısına eşit olmalı:

```bash
ls screenshots/*.png | wc -l
shasum screenshots/*.png | awk '{print $1}' | sort -u | wc -l
```

İki sayı eşit değilse kareler bayattır; sonuç geçersizdir, tekrar koşulur.

### Devreden borçların güncel durumu (spec §9 "Faz 6")

Plan yazılırken üçünün de kodu okundu:

| # | Borç | Durum |
|---|---|---|
| 1 | `SwitchListTile` ink assertion'ı (`location_edit_screen.dart`) | **Kapalı.** Plan 5'te satır `GroupedRow`+`Switch`'e taşındı; `SwitchListTile` kalmadı. |
| 2 | GPS konum değişim konsolidasyonu (`location_monitor_controller.dart`) | **Kapalı.** `_locationService.changeLocation(newLocation)` çağrılıyor, `setActiveLocation` doğrudan çağrısı yok. |
| 3 | MVP kabul testleri (`docs/PLAN_CHECKLIST.md`) | **Açık.** Task 5 kapatıyor. |

---

## Dosya Yapısı

**Oluşturulacak:**

| Dosya | Sorumluluk |
|---|---|
| `test/theme/contrast_test.dart` | Sekiz paletin WCAG oranlarını hesaplar ve eşikleri assert eder. WCAG matematiği bu dosyada, üretim kodunda değil — yalnızca test ihtiyacı. |
| `tool/generate_icons.sh` | İkon SVG'lerini üretip headless Chrome ile 1024×1024 PNG'ye rasterize eder. Build'in parçası değil; varlıklar yenilenecekse elle çalıştırılır. |
| `test/acceptance/mvp_acceptance_test.dart` | Dört MVP kabul senaryosunu katmanları gerçek nesnelerle birleştirip uçtan uca doğrular. |

**Değiştirilecek:**

| Dosya | Değişiklik |
|---|---|
| `lib/core/theme/palettes.dart:163` | `_eveningLight.accent` `#9E4266` → `#983F62` (ölçülen 5.01 → 5.32). |
| `integration_test/screenshots_test.dart` | Üçüncü `testWidgets` bloğu: 4 dilim × 2 parlaklık = 8 kare. |
| `pubspec.yaml` | `version: 0.2.1+19` → `0.3.0+20`; `flutter_launcher_icons` adaptive giriş/zemin yolları; `flutter_native_splash` renk ve görsel yolu. |
| `CHANGELOG.md` | `## [0.3.0]` bölümü. |
| `docs/PLAN_CHECKLIST.md:79` | MVP kabul testi maddesi işaretlenir. |
| `assets/icon/*` | Yeniden üretilen varlıklar. |
| `ios/`, `android/`, `web/`, `macos/`, `windows/` ikon ve splash çıktıları | `flutter_launcher_icons` + `flutter_native_splash` tarafından üretilir. |

**Silinecek:**

| Dosya | Gerekçe |
|---|---|
| `assets/icon/splash_logo.png` | Yerini `app_icon_foreground.png` alıyor; splash ve Android adaptive ön plan aynı görseli kullanır (aynı ihtiyaç: saydam zeminde ortalanmış hilal). |

---

## Task 1: Kontrast testi ve GÜLKURUSU accent düzeltmesi

**Files:**
- Create: `test/theme/contrast_test.dart`
- Modify: `lib/core/theme/palettes.dart:163`

**Interfaces:**
- Consumes: `paletteFor(DayPhase, Brightness)` → `AppTokens` (`lib/core/theme/palettes.dart:190`); `AppTokens` alanları `accent, surface, textPrimary, textSecondary, textTertiary, textValue, backgroundStops` (`lib/core/theme/app_tokens.dart`).
- Produces: Başka task'ın kullandığı yeni API yok. `_eveningLight.accent` değeri değişir; Task 2'nin ekran görüntülerinde GÜLKURUSU accent'i bu yeni renk olur.

**Bağlam — ölçülen değerler.** Plan yazılırken sekiz palet Python ile ölçüldü. `backgroundStops` ortalaması üzerine `surface` (mürekkep %5) bindirilerek:

| Palet | Metin1 | Metin2 | Metin3 | Değer | Accent |
|---|---|---|---|---|---|
| morningDark | 9.87 | 5.84 | 4.60 | 7.70 | 6.11 |
| afternoonDark | 10.31 | 6.20 | 4.90 | 8.06 | 9.01 |
| eveningDark | 12.56 | 6.39 | 5.06 | 8.51 | 6.72 |
| nightDark | 13.83 | 6.93 | 5.31 | 10.12 | 7.77 |
| morningLight | 13.70 | 5.84 | 4.58 | 7.47 | 5.42 |
| afternoonLight | 14.30 | 6.00 | 4.71 | 7.71 | 6.18 |
| eveningLight | 13.97 | 6.78 | 5.27 | 8.61 | **5.01** |
| nightLight | 14.57 | 7.47 | 5.82 | 9.46 | 7.12 |

Tek ihlal: `eveningLight` accent 5.01 < 5.1. `#9E4266`'nın her kanalı 0.96 ile çarpılınca `#983F62` çıkıyor → 5.32. Ton korunuyor, kanal başına 6/3/4 fark gözle ayırt edilemez.

- [ ] **Step 1: Testi yaz (başarısız olacak)**

`test/theme/contrast_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:ezanvakti/core/theme/app_tokens.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec §8 / V4: sekiz paletin metin rampasi ve accent'i okunabilir olmali.
///
/// Olcum zemini `backgroundStops` **ortalamasi**dir: arka plan radyal bir
/// gradyan, metin ekranin herhangi bir yerinde durabiliyor; tek bir stop'u
/// secmek ya fazla iyimser ya fazla karamsar olurdu. Zeminin uzerine ayrica
/// `surface` bindirilir, cunku metinlerin cogu kart icinde.
const double _minTextRatio = 4.5;

/// Sayac ve vurgular icin tasarimin iddia ettigi daha yuksek esik.
const double _minAccentRatio = 5.1;

/// WCAG 2.1 goreli parlaklik.
double _relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// [top] rengini [bottom] uzerine alfasiyla harmanlar (src-over).
Color _composite(Color top, Color bottom) {
  final alpha = top.a;
  return Color.from(
    alpha: 1.0,
    red: top.r * alpha + bottom.r * (1 - alpha),
    green: top.g * alpha + bottom.g * (1 - alpha),
    blue: top.b * alpha + bottom.b * (1 - alpha),
  );
}

Color _measurementBackground(AppTokens tokens) {
  final stops = tokens.backgroundStops;
  final average = Color.from(
    alpha: 1.0,
    red: stops.map((c) => c.r).reduce((a, b) => a + b) / stops.length,
    green: stops.map((c) => c.g).reduce((a, b) => a + b) / stops.length,
    blue: stops.map((c) => c.b).reduce((a, b) => a + b) / stops.length,
  );
  return _composite(tokens.surface, average);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final phase in DayPhase.values) {
      final label = '${phase.name}/${brightness.name}';
      final tokens = paletteFor(phase, brightness);
      final background = _measurementBackground(tokens);

      test('$label metin rampasi 4.5:1 esigini geciyor', () {
        final ramp = <String, Color>{
          'Metin1': tokens.textPrimary,
          'Metin2': tokens.textSecondary,
          'Metin3': tokens.textTertiary,
          'Deger': tokens.textValue,
        };

        ramp.forEach((name, color) {
          final ratio = _contrastRatio(color, background);
          expect(
            ratio,
            greaterThanOrEqualTo(_minTextRatio),
            reason: '$label $name orani ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });

      test('$label accent 5.1:1 esigini geciyor', () {
        final ratio = _contrastRatio(tokens.accent, background);
        expect(
          ratio,
          greaterThanOrEqualTo(_minAccentRatio),
          reason: '$label accent orani ${ratio.toStringAsFixed(2)}:1',
        );
      });
    }
  }

  test('Kontrast hesabi bilinen uc degerlerde dogru', () {
    expect(
      _contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21.0, 0.01),
    );
    expect(
      _contrastRatio(const Color(0xFF808080), const Color(0xFF808080)),
      closeTo(1.0, 0.01),
    );
  });
}
```

- [ ] **Step 2: Testi çalıştır, tek bir hatanın çıktığını gör**

```bash
flutter test test/theme/contrast_test.dart
```

Beklenen: **1 test başarısız** — `evening/light accent orani 5.01:1`. Diğer 17 test geçer. Başka bir test de düşerse dur ve raporla: ölçüm varsayımı (`Color.r/g/b`'nin 0–1 aralığı, ortalama zemin) tutmuyor demektir.

- [ ] **Step 3: GÜLKURUSU accent'ini düzelt**

`lib/core/theme/palettes.dart` içinde `_eveningLight` tanımını güncelle (satır 157–173 arası doküman yorumunun altına ikinci bir paragraf eklenir):

```dart
/// GÜLKURUSU — İkindi → Yatsı.
///
/// Tasarımda mürekkep `#2D191E` idi ama Metin1 `#201A1E`; diğer üç palette
/// ikisi birebir aynı olduğu için sapma kurala uyduruldu. Görsel bedeli yok:
/// kırmızı kanalda 13/255 fark %9 alfayla bindiğinde ekrana 1.17/255 düşer.
///
/// Accent tasarımda `#9E4266` idi; ölçülen kontrastı 5.01:1, spec'in accent
/// eşiği 5.1:1. Her kanal 0.96 ile çarpılarak `#983F62`'ye indirildi → 5.32:1.
/// Ton korunuyor, sekiz paletin tek eşik ihlali böyle kapandı.
final AppTokens _eveningLight = _lightPalette(
  accent: const Color(0xFF983F62),
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
```

- [ ] **Step 4: Testler geçiyor mu**

```bash
flutter test test/theme/contrast_test.dart
```

Beklenen: 17 test geçer (8 palet × 2 + 1 sağlama).

- [ ] **Step 5: Tüm süiti ve analizi çalıştır**

```bash
flutter test
flutter analyze
```

Beklenen: hepsi yeşil, `No issues found!`. `test/theme/app_tokens_test.dart` gibi palet rengine bağlı bir test varsa ve `#9E4266` bekliyorsa onu da yeni değere güncelle.

- [ ] **Step 6: Commit**

```bash
git add test/theme/contrast_test.dart lib/core/theme/palettes.dart
git commit -m "test: sekiz paletin WCAG kontrastini dogrula

GULKURUSU accent'i olculen 5.01:1 ile spec'in 5.1:1 esiginin altinda
kaldigi icin #9E4266 -> #983F62 olarak koyulastirildi (5.32:1)."
```

---

## Task 2: Sekiz palet kombinasyonlu ekran görüntüsü

**Files:**
- Modify: `integration_test/screenshots_test.dart`

**Interfaces:**
- Consumes: `ServiceLocator().get<ThemeController>()`; `ThemeController.setTimeBasedColor(bool)`, `.setFixedPalette(DayPhase)`, `.setThemeMode(AppThemeMode)` (`lib/core/theme/theme_controller.dart:80-84`); `kPaletteTransition` (400 ms, aynı dosya:17); dosyadaki mevcut `_wait`, `shot`, `_seedAlarms` yardımcıları.
- Produces: `screenshots/19-palet-<phase>-<mode>.png` adında 8 kare. Toplam kare sayısı 19 → **27**.

**Neden test-only kanca yok.** Spec §8 `ThemeController`'a `overridePhase` eklemeyi öneriyordu. Gerek yok: "vakte göre renk" kapatıldığında dilim zaten `settings.fixedPalette`'ten okunuyor (`theme_controller.dart:47`), yani 4 dilim × 2 parlaklık mevcut public API ile zorlanabiliyor. Üretim koduna test kancası eklemek yerine kullanıcının gerçekten kullandığı yolu sürüyoruz — testin kanıt değeri de daha yüksek.

- [ ] **Step 1: Yeni import'ları ekle**

`integration_test/screenshots_test.dart` dosyasının import bloğuna:

```dart
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/theme_controller.dart';
```

- [ ] **Step 2: Üçüncü test bloğunu ekle**

`main()` içinde, mevcut `'dolu alarm listesi'` bloğunun **hemen ardına** (yani `main()`'in kapanış süslü parantezinden önce):

```dart
  // Sekiz palet kombinasyonu (4 dilim x koyu/acik). Konum ilk testte
  // kaydedildigi icin agac dogrudan ana ekranla aciliyor. Palet, kullanicinin
  // Ayarlar > Gorunum'de kullandigi ayni public API ile zorlanir; uretim
  // kodunda test-only bir kanca yok.
  testWidgets('sekiz palet kombinasyonu', (tester) async {
    final theme = ServiceLocator().get<ThemeController>();
    await theme.setTimeBasedColor(false);

    await tester.pumpWidget(const app.MyApp());
    await _wait(tester, const Duration(seconds: 8));

    for (final mode in [AppThemeMode.dark, AppThemeMode.light]) {
      await theme.setThemeMode(mode);
      for (final phase in DayPhase.values) {
        await theme.setFixedPalette(phase);
        // AnimatedTheme gecisi kPaletteTransition kadar surer; kare
        // gecis bitmeden alinirsa ara renk yakalanir.
        await _wait(tester, kPaletteTransition + const Duration(seconds: 1));
        await shot(tester, '19-palet-${phase.name}-${mode.name}');
      }
    }

    // Bir sonraki kosuma temiz baslasin diye varsayilana don.
    await theme.setThemeMode(AppThemeMode.dark);
    await theme.setTimeBasedColor(true);
  });
```

- [ ] **Step 3: Analiz ve derleme kontrolü**

```bash
flutter analyze
```

Beklenen: `No issues found!`. `ServiceLocator` zaten import edilmiş durumda (dosyanın ilk satırı); tekrar eklenmemeli.

- [ ] **Step 4: Simülatörü yeniden başlat ve koştur**

```bash
SIM=86EB40FD-7B75-4BCC-91CA-DCBED258902C
xcrun simctl shutdown "$SIM" || true
xcrun simctl boot "$SIM"
sleep 15
rm -rf screenshots
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d "$SIM"
```

Beklenen: `exit=0`, "All tests passed".

- [ ] **Step 5: Kareleri doğrula**

```bash
ls screenshots/*.png | wc -l                                    # 27
shasum screenshots/*.png | awk '{print $1}' | sort -u | wc -l    # 27
ls screenshots/19-palet-*.png | wc -l                            # 8
shasum screenshots/19-palet-*.png | awk '{print $1}' | sort -u | wc -l  # 8
```

Dört sayı sırasıyla 27, 27, 8, 8 olmalı. Eşit değilse kareler bayattır → Step 4'ü tekrarla. Ayrıca sekiz kareyi gözle aç: her biri farklı renkte olmalı, koyu dördü koyu, açık dördü açık.

- [ ] **Step 6: Taşma uyarısı taraması**

`flutter drive` çıktısında `A RenderFlex overflowed` veya `overflowed by` araması yapılır. Beklenen: **sıfır eşleşme**. Varsa hangi ekran ve hangi palet olduğunu not et; palete özgü taşma genelde açık temada uzun metnin farklı ölçülmesinden değil, sabit yükseklikten gelir — düzeltmesi bu task'ın parçasıdır.

- [ ] **Step 7: Commit**

```bash
git add integration_test/screenshots_test.dart
git commit -m "test: sekiz palet kombinasyonunun ekran goruntusunu al

Vakte gore renk kapatilip sabit palet ve tema modu dondurulerek
4 dilim x koyu/acik = 8 kare uretilir. Uretim kodunda test-only
kanca yok; kullanicinin kullandigi ayni ThemeController API'si surulur."
```

---

## Task 3: ERGUVAN uygulama ikonu ve splash

**Files:**
- Create: `tool/generate_icons.sh`
- Create: `assets/icon/app_icon_background.png`, `assets/icon/app_icon_foreground.png` (script üretir)
- Modify: `assets/icon/app_icon.png` (script üretir), `pubspec.yaml:118-148`
- Delete: `assets/icon/splash_logo.png`

**Interfaces:**
- Consumes: `flutter_launcher_icons` ve `flutter_native_splash` pubspec blokları.
- Produces: `assets/icon/app_icon.png` (1024×1024, alfasız, tam kaplama), `assets/icon/app_icon_background.png` (1024×1024, alfasız, yalnızca gradyan), `assets/icon/app_icon_foreground.png` (1024×1024, alfalı, yalnızca hilal). Sonraki task bu dosyalara dokunmaz.

**Neden headless Chrome.** Makinede `rsvg-convert`, `inkscape`, ImageMagick ve `cairosvg` yok; kurmak yeni bir sistem bağımlılığı demek. Chrome zaten kurulu ve `--headless --screenshot` ile SVG'yi doğru rasterize ediyor. Plan yazılırken denendi: tam kaplama render 1024×1024 colortype 2 (alfasız), `--default-background-color=00000000` ile saydam render colortype 6 çıktı.

**Neden üç varlık.** Android adaptive ikon ön planı 108dp tuvalin yalnızca ~66%'lık güvenli dairesine sığar; mevcut kurulum tam kaplama ikonu ön plan olarak veriyordu, yani gradyan zemin kırpılıp ortada küçülüyordu. Doğrusu: zemin ayrı görsel, ön plan saydam zeminde yalnızca hilal. Splash da aynı ihtiyacı taşıdığı için ön plan görselini paylaşır — `splash_logo.png` bu yüzden silinir.

- [ ] **Step 1: Üretici script'i yaz**

`tool/generate_icons.sh`:

```bash
#!/usr/bin/env bash
# ERGUVAN uygulama ikonunu (spec D7) uretir.
#
# Geometri, design/Ezan Vakti - Son Tasarim.html icindeki
# __bundler_thumbnail SVG'sinin birebir aynisidir.
#
# Build'in parcasi degil: varliklar degisecekse elle calistirilir, ciktilar
# commit'lenir. Rasterizer olarak headless Chrome kullanilir; makinede
# rsvg-convert / ImageMagick / Inkscape yok ve yeni sistem bagimliligi
# eklemek istemiyoruz.
#
# Kullanim:  bash tool/generate_icons.sh
# Sonrasi:   dart run flutter_launcher_icons && dart run flutter_native_splash:create

set -euo pipefail

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
SIZE=1024
OUT="assets/icon"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ ! -x "$CHROME" ]; then
  echo "Chrome bulunamadi: $CHROME" >&2
  echo "CHROME=/path/to/chrome bash tool/generate_icons.sh ile yol verilebilir." >&2
  exit 1
fi

# Hilal: buyuk daireden kaydirilmis bir daire cikarilir. Yildiz sagda kucuk daire.
GLYPH='<defs><mask id="m">
  <circle cx="233" cy="256" r="141" fill="#fff"/>
  <circle cx="292" cy="218" r="125" fill="#000"/>
</mask></defs>
<circle cx="233" cy="256" r="141" fill="#E09FB8" mask="url(#m)"/>
<circle cx="361" cy="179" r="18" fill="#E09FB8"/>'

# Erguvan gradyani: sol ustte acik, sag altta koyu.
GRADIENT='<defs><radialGradient id="t" cx="30%" cy="0%" r="115%">
  <stop offset="0" stop-color="#5A2A50"/><stop offset="1" stop-color="#150F1F"/>
</radialGradient></defs>
<rect width="512" height="512" fill="url(#t)"/>'

svg_open() {
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 512 512">' "$SIZE" "$SIZE"
}

# $1 = svg dosyasi, $2 = png dosyasi, $3 = "transparent" ise alfa korunur
render() {
  local args=(--headless --disable-gpu --hide-scrollbars
              --force-device-scale-factor=1
              --window-size="$SIZE,$SIZE" --screenshot="$2" "$1")
  if [ "${3:-}" = "transparent" ]; then
    args=(--default-background-color=00000000 "${args[@]}")
  fi
  "$CHROME" "${args[@]}" >/dev/null 2>&1
}

mkdir -p "$OUT"

# 1) Tam kaplama ikon: iOS, web, macOS, Windows ve Android legacy.
#    Kose yuvarlatmasi yok - her platform kendi maskesini uygular.
{ svg_open; printf '%s%s' "$GRADIENT" "$GLYPH"; printf '</svg>'; } > "$TMP/icon.svg"
render "$TMP/icon.svg" "$OUT/app_icon.png"

# 2) Android adaptive zemin: yalnizca gradyan.
{ svg_open; printf '%s' "$GRADIENT"; printf '</svg>'; } > "$TMP/background.svg"
render "$TMP/background.svg" "$OUT/app_icon_background.png"

# 3) Android adaptive on plan + splash: saydam zeminde hilal.
#    0.62 olcek, hilali adaptive maskesinin guvenli dairesine sokar.
{ svg_open
  printf '<g transform="translate(256 256) scale(0.62) translate(-256 -256)">%s</g>' "$GLYPH"
  printf '</svg>'; } > "$TMP/foreground.svg"
render "$TMP/foreground.svg" "$OUT/app_icon_foreground.png" transparent

echo "Uretildi:"
ls -la "$OUT"
```

- [ ] **Step 2: Script'i çalıştır ve çıktıları doğrula**

```bash
bash tool/generate_icons.sh
python3 - <<'PY'
import struct
for p in ['assets/icon/app_icon.png',
          'assets/icon/app_icon_background.png',
          'assets/icon/app_icon_foreground.png']:
    d = open(p, 'rb').read()
    w, h = struct.unpack('>II', d[16:24])
    print(p, w, h, 'colortype', d[25])
PY
```

Beklenen:
```
assets/icon/app_icon.png 1024 1024 colortype 2
assets/icon/app_icon_background.png 1024 1024 colortype 2
assets/icon/app_icon_foreground.png 1024 1024 colortype 6
```

`colortype 6` (RGBA) ön planda **şart** — 2 çıkarsa `--default-background-color` bayrağı tutmamıştır, Chrome sürümüne göre `--headless=new` denenir. Üç PNG'yi de gözle aç: `app_icon.png` mor gradyan üstünde pembe hilal, `app_icon_foreground.png` saydam zeminde ortalanmış küçük hilal olmalı.

- [ ] **Step 3: pubspec ikon ve splash bloklarını güncelle**

`pubspec.yaml` içinde `flutter_launcher_icons` bloğunu şu hâle getir:

```yaml
flutter_launcher_icons:
  image_path: assets/icon/app_icon.png
  android: true
  ios: true
  remove_alpha_ios: true
  min_sdk_android: 21
  # Adaptive ikon iki katman ister: on plan 108dp tuvalin ~66%'lik guvenli
  # dairesine kirpilir, bu yuzden tam kaplama gorsel on plan olarak
  # kullanilamaz. Zemin gradyan, on plan yalnizca hilal.
  adaptive_icon_background: assets/icon/app_icon_background.png
  adaptive_icon_foreground: assets/icon/app_icon_foreground.png
  web:
    generate: true
    image_path: assets/icon/app_icon.png
    background_color: "#150F1F"
    theme_color: "#4A2144"
  windows:
    generate: true
    image_path: assets/icon/app_icon.png
    icon_size: 48
  macos:
    generate: true
    image_path: assets/icon/app_icon.png
```

Ve `flutter_native_splash` bloğunu:

```yaml
# Acilis ekrani (launch/splash): erguvan zemin + hilal.
# Renk, ERGUVAN koyu paletinin orta durak degeridir (_eveningDark
# backgroundStops[1]); radyal gradyanin ekran ortasindaki tonu bu, boylece
# splash'tan ilk kareye gecis sicramaz.
# Yeniden uretmek icin: dart run flutter_native_splash:create
flutter_native_splash:
  color: "#241634"
  image: assets/icon/app_icon_foreground.png
  android_12:
    color: "#241634"
    image: assets/icon/app_icon_foreground.png
```

`pubspec.yaml` içinde `#0B1526` başka bir yerde kalmadığını doğrula:

```bash
grep -n "0B1526" pubspec.yaml
```

Beklenen: çıktı yok.

- [ ] **Step 4: Eski splash varlığını sil ve üreticileri çalıştır**

```bash
git rm assets/icon/splash_logo.png
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Beklenen: iki komut da hatasız biter. `flutter_native_splash` `splash_logo.png` bulunamadı derse pubspec'teki yol düzeltilmemiştir.

- [ ] **Step 5: Simülatörde gözle doğrula**

```bash
SIM=86EB40FD-7B75-4BCC-91CA-DCBED258902C
xcrun simctl shutdown "$SIM" || true
xcrun simctl boot "$SIM"
sleep 15
flutter run -d "$SIM"
```

Kontrol listesi:
- Ana ekrana çıkmadan önce açılış ekranı erguvan zeminde hilal gösteriyor.
- Uygulamadan çık (simülatörde Home): ana ekranda uygulama ikonu mor/pembe hilal, **köşelerde beyaz artık yok**.
- `flutter analyze` temiz.

Beyaz köşe görünürse `remove_alpha_ios` saydam köşeleri beyaza çevirmiştir; `app_icon.png`'de yuvarlatma olmadığından bu beklenmez, çıkarsa `app_icon.png`'nin colortype'ı 2 değil demektir.

- [ ] **Step 6: Commit**

```bash
git add -A tool/generate_icons.sh assets/icon pubspec.yaml \
  ios android web macos windows
git commit -m "feat: ERGUVAN uygulama ikonu ve splash

Ikon, tasarim dosyasindaki SVG'den headless Chrome ile uretiliyor
(tool/generate_icons.sh). Android adaptive ikon artik dogru iki katmanli:
zemin gradyan, on plan saydam zeminde hilal. Splash ayni on plan gorselini
ve ERGUVAN koyu paletinin orta durak rengini kullaniyor."
```

---

## Task 4: Sürüm 0.3.0 ve CHANGELOG

**Files:**
- Modify: `pubspec.yaml:19`, `CHANGELOG.md`

**Interfaces:**
- Consumes: `pubspec.yaml` `version` alanı. Ayarlar ekranı sürümü `package_info_plus` ile okuyor (`lib/presentation/screens/settings_screen.dart:48`), yani pubspec'i değiştirmek ekrandaki "Sürüm 0.3.0" metnini de düzeltir — ayrıca kod değişikliği gerekmez.
- Produces: Yayına hazır sürüm etiketi.

- [ ] **Step 1: Sürümü yükselt**

`pubspec.yaml:19`:

```yaml
version: 0.3.0+20
```

- [ ] **Step 2: CHANGELOG girdisini yaz**

`CHANGELOG.md` içinde, `## [0.2.1] - 2026-06-11` satırının **hemen üstüne**:

```markdown
## [0.3.0] - 2026-08-03

### Eklendi
- **Vakte göre renk:** arayüz paleti gün içinde namaz vakitleriyle birlikte ilerler — ÇİVİT (İmsak–Öğle), KURŞUNİ (Öğle–İkindi), ERGUVAN (İkindi–Yatsı), SÜMBÜL (Yatsı–İmsak). Her palet açık temada da bir karşılığa sahip: NİLÜFER, SEDEF, GÜLKURUSU, LEYLAK.
- **Açık tema** ve **Sistem** tema modu. Ayarlar → Görünüm'den seçilir.
- "Vakte göre renk" kapatıldığında dört paletten biri **sabit** olarak seçilebilir.
- Yeni **ERGUVAN uygulama ikonu** ve uyumlu açılış ekranı.

### Değiştirildi
- Uygulama tipografisi **Manrope**'a geçti; sayaç ve saat kolonları sabit genişlikli rakam kullanıyor, rakamlar değişirken satır oynamıyor.
- Tüm ekranlar tek bir yüzey düzenine taşındı: kart içinde kart yok, gruplar ayıraçla bölünüyor.
- Sekme ve seçim şeritleri **kayan hap** animasyonuna geçti.
- Alarm, bildirim ve konum listelerinde "ekle" düğmesi üst çubuğa taşındı; kayan düğme son satırın üzerini kapatmıyor.
- Konum adları her yerde aynı sırada gösteriliyor: "Kadıköy, İstanbul".
- Palet değişimleri 400 ms yumuşak geçişle uygulanıyor.

### Düzeltildi
- Aktif konum satırı yeniden düzenlenebiliyor (rozet, düzenleme ikonunun yerini almıyor).
- Uzun konum ve alarm etiketleri satırdan taşmak yerine kırpılıyor.
- GPS ile konum değişimi artık manuel değişimle aynı kanonik yolu izliyor; hesaplama önbelleği ve eski konumun bildirimleri doğru temizleniyor.
- Alarm planlaması başarısız olduğunda hata sessizce yutulmuyor, loglanıyor.
```

- [ ] **Step 3: Doğrula**

```bash
flutter pub get
flutter test
flutter analyze
grep -n "^version:" pubspec.yaml
```

Beklenen: testler yeşil, analiz temiz, `version: 0.3.0+20`.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: surumu 0.3.0'a yukselt ve CHANGELOG'u yaz"
```

---

## Task 5: MVP kabul testleri (devreden borç 3)

**Files:**
- Create: `test/acceptance/mvp_acceptance_test.dart`
- Modify: `docs/PLAN_CHECKLIST.md:79`

**Interfaces:**
- Consumes: `PrayerTimesRepository`, `LocationService`, `NotificationScheduler`, `NotificationSettingsManager` sınıfları ve `LocalStorage` / `PrayerTimeProvider` / `NotificationService` arayüzleri.
- Produces: Başka task'ın kullandığı API yok.

**Kapsam.** `docs/PLAN_CHECKLIST.md`'deki tek işaretsiz madde dört senaryo istiyor: online, offline, konum değişimi, izin yok. Mevcut testler bunları **katman katman** kanıtlıyor (`test/offline/`, `test/location/`, `test/notifications/`) ama katmanları birleştiren bir akış yok. Bu dosya tam olarak o boşluğu kapatır: aynı sahte altyapı üstünde gerçek repository/service nesneleri kurulur ve her senaryo tek bir akış olarak koşar.

**Uyarı — imzaları önce oku.** Aşağıdaki test kodu mevcut sınıfları çağırıyor. Yazmadan önce şu dosyalardaki constructor ve metot imzalarını oku; farklıysa testi imzaya uydur, üretim kodunu **değiştirme**:
- `lib/features/prayer_times/domain/prayer_times_repository.dart`
- `lib/features/location/domain/location_service.dart`
- `lib/features/notifications/domain/notification_scheduler.dart`
- `lib/features/notifications/domain/notification_settings_manager.dart`
- `lib/core/interfaces/local_storage.dart`, `prayer_time_provider.dart`, `notification_service.dart`

Sahte sınıflar için `test/offline/offline_behavior_test.dart:14` (`MockLocalStorage`) ve `:237` (`MockPrayerTimeProvider`) ile `test/notifications/notifications_test.dart:200` (`MockNotificationService`) hazır şablon — kopyalayıp bu dosyaya uyarla, `implements` ettikleri arayüzün **tüm** üyelerini karşıla.

- [ ] **Step 1: Senaryo 1 — online akış (başarısız olacak)**

`test/acceptance/mvp_acceptance_test.dart`, dosyanın başına sahte sınıflar (yukarıdaki şablonlardan) ve ardından:

```dart
void main() {
  group('MVP kabul - online', () {
    test('Konum secilince bugunun vakitleri gorulebiliyor', () async {
      final storage = FakeLocalStorage();
      final provider = FakePrayerTimeProvider();
      await storage.init();

      const location = Location(
        id: 'test-1',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.99,
        longitude: 29.03,
      );
      provider.seedMonth(location.id, DateTime.now());

      final repository = PrayerTimesRepository(
        provider: provider,
        storage: storage,
      );
      await storage.saveActiveLocation(location);

      final today = await repository.getDailyPrayerTime(
        location,
        DateTime.now(),
      );

      expect(today, isNotNull);
      expect(today!.fajr.isBefore(today.dhuhr), isTrue);
      expect(provider.fetchCount, greaterThan(0));
    });
  });
}
```

- [ ] **Step 2: Testi çalıştır, kırmızıyı gör**

```bash
flutter test test/acceptance/mvp_acceptance_test.dart
```

Beklenen: derleme hatası veya assertion hatası. Sahteler eksikse tamamla; **üretim kodunu değiştirme** — bu testler mevcut davranışı kanıtlamak için var, davranış değiştirmek için değil. Gerçek bir hata bulursan dur ve raporla.

- [ ] **Step 3: Senaryo 1'i yeşile al**

Sahte sınıfları ve `seedMonth` yardımcısını tamamla. `FakePrayerTimeProvider.seedMonth` verilen tarihten itibaren 30 günlük `PrayerTime` üretsin; `fetchCount` çağrı sayısını saysın.

```bash
flutter test test/acceptance/mvp_acceptance_test.dart
```

Beklenen: 1 test geçer.

- [ ] **Step 4: Senaryo 2 — offline**

Aynı dosyaya ekle:

```dart
  group('MVP kabul - offline', () {
    test('Ag yokken onbellekteki vakitler gosteriliyor', () async {
      final storage = FakeLocalStorage();
      final provider = FakePrayerTimeProvider();
      await storage.init();

      const location = Location(
        id: 'test-1',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.99,
        longitude: 29.03,
      );
      provider.seedMonth(location.id, DateTime.now());

      final repository = PrayerTimesRepository(
        provider: provider,
        storage: storage,
      );

      // Once online cek: onbellek dolar.
      await repository.getPrayerTimes(location);
      final fetchesWhileOnline = provider.fetchCount;

      // Sonra agi kes: ayni sorgu onbellekten cevaplanmali.
      provider.failWith = const NetworkException('Baglanti yok');
      final cached = await repository.getPrayerTimes(location);

      expect(cached, isNotEmpty);
      expect(
        provider.fetchCount,
        greaterThan(fetchesWhileOnline),
        reason: 'Once ag denenmeli, sonra onbellege dusulmeli',
      );
    });
  });
```

- [ ] **Step 5: Senaryo 2'yi çalıştır**

```bash
flutter test test/acceptance/mvp_acceptance_test.dart
```

Beklenen: 2 test geçer. Repository'nin gerçek fallback davranışı farklıysa (örneğin ağ hatasında istisna fırlatıyorsa) testi **gerçek davranışa** göre yaz ve farkı commit mesajında belirt.

- [ ] **Step 6: Senaryo 3 — konum değişimi**

```dart
  group('MVP kabul - konum degisimi', () {
    test('Konum degisince bildirimler yeniden planlaniyor', () async {
      final storage = FakeLocalStorage();
      final notifications = FakeNotificationService();
      await storage.init();

      const first = Location(
        id: 'loc-1',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.99,
        longitude: 29.03,
      );
      const second = Location(
        id: 'loc-2',
        province: 'Ankara',
        district: 'Çankaya',
        latitude: 39.92,
        longitude: 32.85,
      );

      await storage.saveActiveLocation(first);
      final service = LocationService(
        storage: storage,
        notificationService: notifications,
      );

      await service.changeLocation(second);

      expect((await storage.getActiveLocation())?.id, second.id);
      expect(
        notifications.cancelAllCount,
        greaterThan(0),
        reason: 'Eski konumun bildirimleri iptal edilmeli',
      );
    });
  });
```

- [ ] **Step 7: Senaryo 4 — bildirim izni yok**

```dart
  group('MVP kabul - izin yok', () {
    test('Izin reddedilince bildirim planlanmiyor ve durum raporlaniyor',
        () async {
      final notifications = FakeNotificationService()..permissionGranted = false;

      final granted = await notifications.requestPermission();

      expect(granted, isFalse);
      expect(
        notifications.scheduledCount,
        0,
        reason: 'Izin yokken hicbir bildirim planlanmamali',
      );
    });
  });
```

`NotificationScheduler` izin kontrolünü kendi içinde yapıyorsa testi scheduler üzerinden yaz — sahte servise değil, gerçek scheduler'a `schedule` çağır ve `scheduledCount`'un 0 kaldığını doğrula. İmzayı okuyup uyarla.

- [ ] **Step 8: Dört senaryoyu birlikte koştur**

```bash
flutter test test/acceptance/mvp_acceptance_test.dart
flutter test
flutter analyze
```

Beklenen: 4 kabul testi geçer, tüm süit yeşil, analiz temiz.

- [ ] **Step 9: Checklist maddesini işaretle**

`docs/PLAN_CHECKLIST.md:79`:

```markdown
- [x] Test: MVP kriterlerinin uçtan uca senaryolarla (online/offline, lokasyon değişimi, izin yok) doğrulandığı kabul testleri geçiyor mu? (`test/acceptance/mvp_acceptance_test.dart`)
```

- [ ] **Step 10: Commit**

```bash
git add test/acceptance/mvp_acceptance_test.dart docs/PLAN_CHECKLIST.md
git commit -m "test: MVP kabul senaryolarini uctan uca dogrula

Online, offline, konum degisimi ve izin yok senaryolari katmanlari
birlestirerek kosuluyor. PLAN_CHECKLIST'teki son isaretsiz madde kapandi."
```

---

## Task 6: Kapanış doğrulaması

**Files:**
- Değişiklik yok; yalnızca doğrulama.

- [ ] **Step 1: Tam süit ve analiz**

```bash
flutter test
flutter analyze
```

Beklenen: tüm testler geçer (Task 1 +17, Task 5 +4 → önceki 421'in üstüne), `No issues found!`.

- [ ] **Step 2: Ölü renk sabiti kalmadığını doğrula**

```bash
grep -rn 'AppTheme\.' lib | grep -v 'AppTheme.build\|AppTheme._' | wc -l
grep -rn 'Colors\.white\|Colors\.black' lib | wc -l
```

Birinci sayı **0** olmalı. İkinci sayı 0 olmak zorunda değil (saydamlık için `Colors.black.withValues` meşru); sıfır değilse her kullanımı gözden geçir, token'la ifade edilebilecek olan var mı bak.

- [ ] **Step 3: Ekran görüntülerini son kez üret**

```bash
SIM=86EB40FD-7B75-4BCC-91CA-DCBED258902C
xcrun simctl shutdown "$SIM" || true
xcrun simctl boot "$SIM"
sleep 15
rm -rf screenshots
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d "$SIM"
ls screenshots/*.png | wc -l
shasum screenshots/*.png | awk '{print $1}' | sort -u | wc -l
```

Beklenen: `exit=0`, iki sayı da **27**, çıktıda taşma uyarısı yok.

- [ ] **Step 4: Çalışma ağacı temiz mi**

```bash
git status --short
git log --oneline redesign/0.3.0 -12
```

Beklenen: `git status` boş. Commit yoksa bir task yarım kalmıştır.

---

## Öz-inceleme notları

**Spec kapsaması.** Faz 4 (ikon + splash) → Task 3. Faz 5 (8 kombinasyonlu görüntü, kontrast testi, CHANGELOG + 0.3.0) → Task 1, 2, 4. Faz 6 (devreden borçlar) → 1 ve 2 zaten kapalı (yukarıda kanıtlandı), 3 → Task 5. V4 doğrulaması Task 1'de gerçek sayılarla yapıldı ve tasarımın 5.1:1 iddiasının bir palette tutmadığı ortaya çıktı; düzeltmesi plana yazıldı. V2 (`setAlternateIconName`) D1 gereği kapsam dışı.

**Kapsam dışı bırakılanlar** (spec §2, bilinçli erteleme): sessiz saatler, "SIRADAKİ" kartının veri bağlaması, alarm canlı önizleme satırı. Bunlar `NotificationScheduler`'a dokunuyor ve görsel turdan ayrı tutuldu.

**Bilinen risk.** Task 5'teki test kodu mevcut sınıf imzalarına dayanıyor; imzalar farklıysa test kodu uyarlanır, üretim kodu değil. Bu yüzden o task'ın ilk adımı "imzaları oku".
