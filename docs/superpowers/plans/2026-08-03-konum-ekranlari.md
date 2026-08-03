# Konum Ekranları ve Bildirim Ekleme Sayfası (Faz 3.6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kalan altı dosyayı tasarım sistemine taşımak — konum ekle/liste/düzenle ekranları ve bildirim ekleme alt sayfası — ve `AppTheme` renk sabitlerini sıfıra indirmek.

**Architecture:** Bu planda yeni bir tasarım kararı yok; iş büyük ölçüde mekanik. Önce ölü kod siliniyor (409 satır), sonra kalan ekranlar `AppSurface` + `SectionLabel` + `GroupedList` + token'lara taşınıyor. Ekranların yapısı korunuyor: konum arama akışı çalışıyor ve değiştirilmesi bu turun kapsamı dışında.

**Tech Stack:** Flutter, `provider`, `intl`, `geolocator`, `geocoding`, `flutter_test`. Yeni paket eklenmez.

**Spec:** `docs/superpowers/specs/2026-08-01-redesign-0.3.0-design.md` §4.1, §6.7
**Önceki planlar:** `2026-08-01-tema-altyapisi.md`, `2026-08-02-ana-ekran.md`, `2026-08-03-alarm-ve-bildirim-ekranlari.md`, `2026-08-03-ayarlar-ve-takvim.md` (dördü de tamamlandı)

## Global Constraints

- Kod/dosya/sınıf/fonksiyon adları **İngilizce**; kullanıcıya görünen metin ve yorumlar Türkçe.
- **Dokunulan hiçbir dosyada renk sabiti kalmaz.** Renk `context.tokens`, tipografi `AppTypography`.
- Font boyutu için çıplak sayı yok; ölçek `11 · 12 · 13 · 14 · 16 · 17 · 20 · 24 · 44 · 62`.
- Yarıçap: 16 (grup/kart) · 12 (alan/çip) · 999 (pill).
- Uyarı, seçim ve pasif durumlar **nötr kalır**; vurgu yalnızca vakit bilgisi ve tek birincil eylem için.
- **Konum arama akışının davranışı değişmez** — Photon sorgusu, debounce, seçim ve kaydetme aynı kalır. Yalnızca görünüm taşınır.
- Her task sonunda `flutter analyze` temiz ve `flutter test` yeşil.
- Commit'ler `redesign/0.3.0` branch'ine.

### Renk sabiti sayacı

Plan başında **86**. Her task sonunda ölçülür:

```bash
grep -rho 'AppTheme\.[a-zA-Z]*' lib --include='*.dart' | grep -v 'AppTheme.build' | wc -l
```

Plan sonunda **0** olmalı ve `AppTheme`'in `@Deprecated` sabitleri silinebilmeli.

### Ekran görüntüsü alırken

Her koşudan önce simülatörü sıfırla; yoksa alarm izin dialog'u kareleri bayatlatır:

```bash
UDID=<simulator-udid>
xcrun simctl shutdown $UDID; sleep 3
xcrun simctl boot $UDID; sleep 10
xcrun simctl uninstall $UDID com.ekrembulbul.ezanvakti
rm -rf screenshots
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart -d $UDID
```

**Doğrula** — 19 çıkmalı (açık tema karesi dahil):

```bash
shasum screenshots/*.png | awk '{print $1}' | sort -u | wc -l
```

---

## File Structure

**Silinen (ölü kod)**

| Ne | Satır | Renk sabiti |
|---|---|---|
| `lib/presentation/widgets/notifications/offset_picker.dart` (tüm dosya) | 219 | 11 |
| `location_widgets.dart` içindeki `LocationTile` + `_LocationIcon` + `_LocationInfo` + `_ActiveBadge` + `_LocationTypeBadge` | ~190 | ~20 |

**Değişen**

| Dosya | Renk sabiti | Değişiklik |
|---|---|---|
| `lib/presentation/widgets/location/location_widgets.dart` | 34 → 0 | Ölü sınıflar çıkar, kalan üçü token'lara |
| `lib/presentation/screens/location_add_screen.dart` | 41 → 0 | Token'lar + GPS fallback etiketi |
| `lib/presentation/screens/location_list_screen.dart` | 32 → 0 | `GroupedList`, yinelenen alt satır kalkar |
| `lib/presentation/screens/location_edit_screen.dart` | 21 → 0 | Token'lar |
| `lib/presentation/widgets/notifications/add_notification_bottom_sheet.dart` | 26 → 0 | Token'lar |
| `lib/main.dart` | 1 → 0 | Sistem çubuğu rengi temadan |
| `lib/core/theme/app_theme.dart` | — | `@Deprecated` sabitler silinir |

---

## Task 1: Ölü kodu sil

**Files:**
- Delete: `lib/presentation/widgets/notifications/offset_picker.dart`
- Modify: `lib/presentation/widgets/location/location_widgets.dart`

- [ ] **Step 1: Referanssızlığı doğrula**

```bash
for c in OffsetPicker LocationTile; do
  echo "$c:"
  grep -rn "\b$c\b" lib test integration_test --include='*.dart' \
    | grep -v "widgets/notifications/offset_picker.dart\|widgets/location/location_widgets.dart"
done
```
Expected: hiçbir satır dönmemeli. Dönerse o sınıfı **silme**, plandan çıkar ve raporla.

- [ ] **Step 2: `offset_picker.dart`'ı sil**

```bash
git rm lib/presentation/widgets/notifications/offset_picker.dart
```

> Bildirim ekleme sayfası kendi `CupertinoPicker`'ını içinde taşıyor; bu dosya
> hiç kullanılmıyordu.

- [ ] **Step 3: `LocationTile` ve yardımcılarını çıkar**

`lib/presentation/widgets/location/location_widgets.dart` dosyasında satır 1–191 arası `LocationTile`, `_LocationIcon`, `_LocationInfo`, `_ActiveBadge`, `_LocationTypeBadge` sınıfları duruyor. Bunları sil; dosyada yalnızca `LocationChoiceButton`, `LocationErrorCard` ve `LocationSelectionConfirm` kalsın. Kullanılmayan import'ları temizle.

- [ ] **Step 4: Analiz, testler, commit**

```bash
flutter analyze && flutter test
git add -A lib
git commit -m "chore: kullanilmayan konum ve ofset widget'larini sil

offset_picker.dart hic kullanilmiyordu (bildirim ekleme sayfasi kendi
CupertinoPicker'ini tasiyor). LocationTile ve dort yardimcisi da
referanssizdi; konum listesi kendi satirini ciziyor.

409 satir ve 31 renk sabiti gitti."
```

---

## Task 2: `location_widgets.dart` kalanları

**Files:**
- Modify: `lib/presentation/widgets/location/location_widgets.dart`
- Test: `test/widgets/location/location_widgets_test.dart`

**Interfaces:**
- Consumes: `context.tokens`, `AppTypography`
- Produces: `LocationChoiceButton`, `LocationErrorCard`, `LocationSelectionConfirm` — parametre listeleri **değişmez**

- [ ] **Step 1: Testi yaz**

Create: `test/widgets/location/location_widgets_test.dart`

```dart
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/presentation/widgets/location/location_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  testWidgets('LocationChoiceButton baslik ve alt metni gosterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        LocationChoiceButton(
          icon: Icons.search_rounded,
          title: 'Adres Ara',
          subtitle: 'Şehir, ilçe veya yer adıyla ara',
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Adres Ara'), findsOneWidget);
    expect(find.text('Şehir, ilçe veya yer adıyla ara'), findsOneWidget);
  });

  testWidgets('LocationChoiceButton dokunma callback tetikler', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      wrapWithTheme(
        LocationChoiceButton(
          icon: Icons.my_location_rounded,
          title: 'GPS ile Bul',
          subtitle: 'Otomatik konum tespiti',
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('GPS ile Bul'));
    expect(tapped, isTrue);
  });

  testWidgets('LocationChoiceButton yuklenirken gosterge cizer', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        LocationChoiceButton(
          icon: Icons.my_location_rounded,
          title: 'Konum Alınıyor...',
          subtitle: 'Otomatik konum tespiti',
          isLoading: true,
          onTap: () {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('LocationErrorCard hata rengini ColorScheme ten alir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(const LocationErrorCard(error: 'Konum izni reddedildi.')),
    );

    expect(find.text('Konum izni reddedildi.'), findsOneWidget);
  });

  testWidgets('LocationSelectionConfirm secilen yerin adini gosterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const LocationSelectionConfirm(
          location: Location(
            id: '1',
            province: 'İstanbul',
            district: 'Kadıköy',
          ),
        ),
      ),
    );

    expect(find.textContaining('Kadıköy'), findsWidgets);
  });
}
```

- [ ] **Step 2: Testi çalıştır**

Run: `flutter test test/widgets/location/location_widgets_test.dart`
Expected: geçebilir (widget'lar zaten var). Amaç davranışı kilitlemek; Step 3'teki dönüşüm bunları bozmamalı.

- [ ] **Step 3: Token'lara taşı**

Üç sınıftaki renk kullanımlarını çevir:

| Eski | Yeni |
|---|---|
| `AppTheme.gold` | `tokens.accent` |
| `AppTheme.gold.withValues(alpha: X)` | `tokens.accent.withValues(alpha: X)` |
| `AppTheme.primaryDark` | `tokens.backgroundStops.last` |
| `AppTheme.primaryMedium` | `tokens.backgroundStops[1]` |
| `Colors.white` | `tokens.textPrimary` |
| `Colors.white70` / `alpha: 0.6–0.7` | `tokens.textSecondary` |
| `Colors.white54` / `alpha: 0.3–0.5` | `tokens.textTertiary` |
| `Colors.white.withValues(alpha: 0.04–0.08)` | `tokens.surface` |
| `Colors.white.withValues(alpha: 0.1–0.2)` | `tokens.border` |
| `Colors.red*` | `Theme.of(context).colorScheme.error` |

Her `build` metodunun başına `final tokens = context.tokens;` ekle. `tokens` içeren ifadelerden `const` kaldır. Metin stillerini `AppTypography.rowTitle` / `rowSubtitle` / `hint` ile değiştir.

- [ ] **Step 4: Doğrula ve commit**

```bash
grep -c "AppTheme\.\|Colors\.white\|Colors\.red" lib/presentation/widgets/location/location_widgets.dart
```
Expected: **0**.

```bash
flutter analyze && flutter test
git add -A lib test
git commit -m "refactor: konum widget'larini token'lara tasi"
```

---

## Task 3: Konum ekleme ekranı

En büyük dosya (690 satır, 41 renk sabiti). Arama akışı **değişmez**.

**Files:**
- Modify: `lib/presentation/screens/location_add_screen.dart`
- Test: `test/widgets/screens/location_add_screen_test.dart`

**Interfaces:**
- Consumes: `AppSurface`, `SectionLabel`, `context.tokens`, `AppTypography`
- Produces: `LocationAddScreen` — parametre listesi değişmez

- [ ] **Step 1: GPS fallback etiketini düzelt**

`_reverseGeocodeLabel` reverse geocoding başarısız olduğunda şunu döndürüyor:

```dart
return (province: 'GPS Konumu', district: coordsLabel, countryCode: null);
```

`Location.displayName` artık `'$district, $province'` ürettiği için bu etiket
`"41.008, 28.978, GPS Konumu"` diye okunuyor. Sırayı düzelt:

```dart
    // displayName "$district, $province" urettigi icin okunabilir sira:
    // "GPS Konumu, 41.008, 28.978".
    return (province: coordsLabel, district: 'GPS Konumu', countryCode: null);
```

- [ ] **Step 2: Testi yaz**

Create: `test/widgets/screens/location_add_screen_test.dart`

```dart
import 'package:ezanvakti/core/models/location.dart';
import 'package:flutter_test/flutter_test.dart';

/// GPS reverse geocoding basarisiz oldugunda uretilen etiketin okunabilir
/// sirada olmasi gerekiyor. displayName "$district, $province" uretiyor.
void main() {
  test('GPS fallback etiketi okunabilir sirada', () {
    // location_add_screen._reverseGeocodeLabel fallback dali ile ayni yapi.
    const coordsLabel = '41.008, 28.978';
    const location = Location(
      id: 'gps',
      province: coordsLabel,
      district: 'GPS Konumu',
      type: LocationType.gps,
    );

    expect(location.displayName, 'GPS Konumu, 41.008, 28.978');
  });

  test('Normal GPS etiketi ilce, il sirasinda', () {
    const location = Location(
      id: 'gps',
      province: 'İstanbul',
      district: 'Kadıköy',
      type: LocationType.gps,
    );

    expect(location.displayName, 'Kadıköy, İstanbul');
  });
}
```

- [ ] **Step 3: Testi çalıştır**

Run: `flutter test test/widgets/screens/location_add_screen_test.dart`
Expected: 2 test PASS.

- [ ] **Step 4: Ekranı token'lara taşı**

- `Scaffold` → `backgroundColor: Colors.transparent`, gövde `AppSurface`.
- `_buildChoiceScreen`, `_buildManualSelection`, `_buildSearchField`, `_buildResults`, `_buildResultTile`, `_buildConfigSection`, `_buildCustomNameField`, `_buildAttribution`, `_buildActionButtons`, `_showLocationRationale`, `_showSnackBar` — hepsinde Task 2'deki eşleme tablosunu uygula.
- `ElevatedButton` ve `OutlinedButton`'ların `styleFrom` renkleri kaldırılır; temadan gelir.
- Arama alanı `InputDecoration` temadan besleniyor; `fillColor`/`border` ezmeleri kalkar.

- [ ] **Step 5: Doğrula ve commit**

```bash
grep -c "AppTheme\.\|Colors\.white" lib/presentation/screens/location_add_screen.dart
```
Expected: **0**.

```bash
flutter analyze && flutter test
git add -A lib test
git commit -m "refactor: konum ekleme ekranini token'lara tasi

Arama akisi degismedi; yalnizca gorunum tasindi. GPS reverse geocoding
basarisiz oldugunda uretilen etiketin sirasi duzeltildi: displayName
'\$district, \$province' urettigi icin 'GPS Konumu, 41.008, 28.978'
okunuyor artik."
```

---

## Task 4: Konum listesi ekranı

**Files:**
- Modify: `lib/presentation/screens/location_list_screen.dart`
- Test: `test/widgets/screens/location_list_screen_test.dart`

**Interfaces:**
- Consumes: `AppSurface`, `GroupedList`, `GroupedRow`, `SectionLabel`, `SwipeToDelete`, `EmptyState`
- Produces: `LocationListScreen` — parametre listesi değişmez

- [ ] **Step 1: Testi yaz**

Create: `test/widgets/screens/location_list_screen_test.dart`

```dart
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

/// Ekran repository'ye bagli oldugu icin burada satir bileseni test ediliyor;
/// ekranin tamamini kurmak icin sahte repository gerekirdi ve bu turun
/// kapsami disinda.
void main() {
  testWidgets('Aktif konum satiri rozetle isaretlenir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        GroupedList(
          children: [
            GroupedRow(
              icon: Icons.location_on_rounded,
              title: const Text('Kadıköy, İstanbul'),
              trailing: const Text('AKTİF'),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Kadıköy, İstanbul'), findsOneWidget);
    expect(find.text('AKTİF'), findsOneWidget);
  });

  test('displayName tek satirda yeterli bilgi tasiyor', () {
    const location = Location(
      id: '1',
      province: 'İstanbul',
      district: 'Kadıköy',
    );

    // Liste satirinda ayrica "il / ilce" alt satiri gostermeye gerek yok.
    expect(location.displayName, 'Kadıköy, İstanbul');
  });
}
```

- [ ] **Step 2: Ekranı yeniden düzenle**

- `Scaffold` → şeffaf, gövde `AppSurface`.
- `_LocationTileWithDelete` kaldırılır; yerine `GroupedList` + `GroupedRow` + `SwipeToDelete`.
- Satır: konum ikonu · `displayName` başlık · alt metinde konum türü (`location.type.displayName`) · sağda aktifse `AKTİF` rozeti, değilse ayar ikonu.
- **Yinelenen alt satır kalkar:** mevcut kod başlıkta `displayName` ("Kadıköy, İstanbul"), altında `'${location.province} / ${location.district}'` ("İstanbul / Kadıköy") gösteriyor — aynı bilgi iki kez, iki farklı sırada. Alt satır konum türüyle değiştirilir.
- Silme, çöp kutusu düğmesi yerine `SwipeToDelete` ile. Aktif konum silinemez (mevcut davranış korunur): aktif satır `SwipeToDelete` ile sarılmaz.
- Düzenleme, satıra dokununca değil sağdaki ayar ikonuyla açılır (mevcut davranış).
- `N konum` başlığı için `SectionLabel`.

- [ ] **Step 3: Doğrula ve commit**

```bash
grep -c "AppTheme\.\|Colors\.white\|Colors\.red" lib/presentation/screens/location_list_screen.dart
```
Expected: **0**.

```bash
flutter analyze && flutter test
git add -A lib test
git commit -m "refactor: konum listesini yeni duzene gecir

Kart listesi yerine ayiracli grup, sola kaydirarak silme. Yinelenen alt
satir kalkti: baslik 'Kadikoy, Istanbul' derken altinda 'Istanbul /
Kadikoy' yaziyordu - ayni bilgi iki kez, iki farkli sirada. Alt satir
artik konum turunu gosteriyor."
```

---

## Task 5: Konum düzenleme ekranı

**Files:**
- Modify: `lib/presentation/screens/location_edit_screen.dart`

- [ ] **Step 1: Token'lara taşı**

Task 2'deki eşleme tablosunu uygula. Plan 3'te eklenen `Material` sarmalı (SwitchListTile ink düzeltmesi) **korunur**; `SwitchListTile` yerine `GroupedRow` + `Switch` kullanılırsa sarmal gereksizleşir — bu tercih edilir:

```dart
  Widget _buildUseGlobalSwitch() {
    return GroupedList(
      children: [
        GroupedRow(
          icon: Icons.public_rounded,
          title: const Text('Genel hesaplama ayarını kullan'),
          subtitle: const Text(
            'Kapatırsan bu konuma özel yöntem/mezhep seçebilirsin',
          ),
          trailing: Switch(
            value: _useGlobal,
            onChanged: (value) => setState(() => _useGlobal = value),
          ),
        ),
      ],
    );
  }
```

Bu değişiklik Plan 3'teki `Material` sarmalını gereksiz kılar; `GroupedRow` zaten kendi `Material`'ını kuruyor. `test/widgets/location_edit_switch_test.dart` **kalır** — doğru deseni belgeliyor.

- [ ] **Step 2: Doğrula ve commit**

```bash
grep -c "AppTheme\.\|Colors\.white" lib/presentation/screens/location_edit_screen.dart
```
Expected: **0**.

```bash
flutter analyze && flutter test
git add -A lib
git commit -m "refactor: konum duzenleme ekranini token'lara tasi

SwitchListTile yerine GroupedRow + Switch; GroupedRow kendi Material'ini
kurdugu icin Plan 3'teki ink sarmali gereksizlesti."
```

---

## Task 6: Bildirim ekleme alt sayfası

**Files:**
- Modify: `lib/presentation/widgets/notifications/add_notification_bottom_sheet.dart`
- Test: `test/widgets/notifications/add_notification_sheet_test.dart`

**Interfaces:**
- Consumes: `SectionLabel`, `SlidingSegment`, `context.tokens`, `AppTypography`
- Produces: `AddNotificationBottomSheet` — parametre listesi değişmez

- [ ] **Step 1: Testi yaz**

Create: `test/widgets/notifications/add_notification_sheet_test.dart`

```dart
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/presentation/widgets/notifications/add_notification_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    void Function(PrayerType, int)? onAdd,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        AddNotificationBottomSheet(onAdd: onAdd ?? (_, _) {}),
      ),
    );
    await tester.pump();
  }

  testWidgets('Alti vakit secenegi cizilir', (tester) async {
    await pumpSheet(tester);

    for (final name in ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('Bolum basliklari buyuk harf', (tester) async {
    await pumpSheet(tester);

    expect(find.text('NAMAZ VAKTİ'), findsOneWidget);
    expect(find.text('BİLDİRİM ZAMANI'), findsOneWidget);
  });

  testWidgets('Oncesinde secilince dakika tekerlegi acilir', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Dakika seçin'), findsNothing);

    await tester.tap(find.text('Öncesinde'));
    await tester.pumpAndSettle();

    expect(find.text('Dakika seçin'), findsOneWidget);
  });

  testWidgets('Tam vaktinde secilince sifir dakika ile eklenir', (
    tester,
  ) async {
    PrayerType? type;
    int? minutes;

    await pumpSheet(
      tester,
      onAdd: (t, m) {
        type = t;
        minutes = m;
      },
    );

    await tester.tap(find.text('Bildirim Ekle'));
    await tester.pumpAndSettle();

    expect(type, PrayerType.fajr);
    expect(minutes, 0);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/widgets/notifications/add_notification_sheet_test.dart`
Expected: "Bolum basliklari buyuk harf" düşer — başlıklar şu an `_buildSectionLabel` ile çiziliyor ve büyük harfe çevrilmiyor.

- [ ] **Step 3: Token'lara taşı**

- `_buildSectionLabel` yerine ortak `SectionLabel` kullan (`'Namaz Vakti'`, `'Bildirim Zamanı'` — büyütmeyi kendisi yapar).
- Zemin `AppTheme.nightGradient` yerine `tokens.backgroundGradient`.
- `_buildPrayerTypeSelector`, `_buildTimeSelector`, `_buildTimeChip` ve dakika tekerleği token'lara.
- `ElevatedButton` `styleFrom` renkleri kalkar, temadan gelir.
- `CupertinoPicker` `selectionOverlay` arka planı `tokens.surface`.

- [ ] **Step 4: Doğrula ve commit**

```bash
grep -c "AppTheme\.\|Colors\.white" lib/presentation/widgets/notifications/add_notification_bottom_sheet.dart
```
Expected: **0**.

```bash
flutter analyze && flutter test
git add -A lib test
git commit -m "refactor: bildirim ekleme sayfasini token'lara tasi

Bolum basliklari ortak SectionLabel'a gecti (buyuk harf donusumu tek
yerden). Zemin, cipler ve dakika tekerlegi token'lardan besleniyor."
```

---

## Task 7: `AppTheme`'i temizle ve doğrula

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/core/theme/app_theme.dart`

- [ ] **Step 1: Sistem çubuğu rengini temaya bağla**

`lib/main.dart` içindeki `SystemChrome.setSystemUIOverlayStyle` sabit
`Color(0xFF120E1B)` kullanıyor — Akşam paletinin en koyu durağı. Palet ve tema
değişince bu güncellenmiyor. `MyApp`'in `Consumer<ThemeController>` gövdesine
taşı:

```dart
          // Sistem cubugu, aktif paletin zeminiyle ve parlakligiyla uyumlu
          // kalsin; palet gun icinde degistigi icin her yapida guncellenir.
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: controller.brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
              systemNavigationBarColor: controller.tokens.backgroundStops.last,
              systemNavigationBarIconBrightness:
                  controller.brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
            ),
          );
```

`main()` içindeki eski çağrıyı sil.

- [ ] **Step 2: Sayacı kontrol et**

```bash
grep -rn 'AppTheme\.' lib --include='*.dart' | grep -v 'AppTheme.build'
```
Expected: hiçbir satır. Dönerse ilgili dosyayı bitir, sonra devam et.

- [ ] **Step 3: `@Deprecated` sabitleri sil**

`lib/core/theme/app_theme.dart` içindeki `gold`, `primaryDark`, `primaryMedium`, `nightGradient`, `glassDecoration` üyelerini sil. Geriye yalnızca `AppTheme.build` kalır.

- [ ] **Step 4: Analiz ve testler**

Run: `flutter analyze && flutter test`
Expected: `No issues found`, hepsi PASS.

- [ ] **Step 5: Görsel doğrulama**

Yukarıdaki "Ekran görüntüsü alırken" bloğunu çalıştır. Benzersiz hash **19** olmalı.

Kontrol listesi:
- `01-konum-secimi`, `02-adres-arama`, `03-arama-sonuclari`, `04-konum-onay` — konum ekleme akışı yeni renklerde
- `13-konumlar` — ayıraçlı grup, aktif rozet, yinelenen alt satır yok
- `14-konum-duzenle` — anahtar satırı grup içinde
- `09-bildirim-ekle`, `10-bildirim-ekle-oncesinde` — bölüm başlıkları büyük harf, çipler token renginde
- `11b-ayarlar-acik` — açık tema hâlâ çalışıyor
- Hiçbir ekranda taşma yok

- [ ] **Step 6: Commit**

```bash
git add -A lib
git commit -m "chore: AppTheme renk sabitlerini kaldir

Tum ekranlar token'lara tasindigi icin gold/primaryDark/primaryMedium/
nightGradient/glassDecoration artik kullanilmiyor. Geriye AppTheme.build
kaldi. Sistem cubugu rengi de aktif paletten besleniyor."
```

---

## Self-Review

**1. Spec coverage**

| Spec | Karşılığı |
|---|---|
| §6.7 konum ekranları aynı sisteme hizalanır | Task 3, 4, 5 |
| §4.1 tek yüzey, ayıraç | Task 4 (`GroupedList`) |
| Bildirim ekleme sayfası (§6.4'ün parçası) | Task 6 |
| GPS fallback etiketi (Plan 3'te bırakılan kenar durum) | Task 3 Step 1 |
| `location_list_screen` yinelenen literal (Plan 3'te bırakılan) | Task 4 Step 2 |
| §10 V4 kontrast, 8 kombinasyon testi, ikon, CHANGELOG | **Plan 6** |

**2. Placeholder scan:** Temiz. Task 2, 3, 5 mekanik dönüşüm ama eşleme tablosu bir kez verilip diğerlerinden ona atıf yapılıyor ve her task sonu sayıyla doğrulanıyor.

**3. Type consistency**

- `GroupedList` / `GroupedRow` / `SwipeToDelete` / `SectionLabel` / `AppSurface` / `SlidingSegment` — hepsi önceki planlarda tanımlandı, burada yalnızca kullanılıyor.
- `LocationChoiceButton` / `LocationErrorCard` / `LocationSelectionConfirm` parametre listeleri Task 2'de korunuyor; Task 3'teki çağrılar değişmiyor.
- `Location.displayName` Plan 2'de `'$district, $province'` oldu; Task 3 Step 1 ve Task 4 Step 2 bu sıraya dayanıyor.

**4. Bilinen riskler**

- **Task 4 en riskli:** `_LocationTileWithDelete` yerine `GroupedList` gelirken aktif konumun silinemezliği ve düzenleme girişi korunmalı. Adımda ikisi de açıkça yazılı; görsel doğrulamada (Task 7 Step 5) `13-konumlar` karesi kontrol edilecek.
- **Task 6'daki "Tam vaktinde" testi** varsayılan seçili vaktin `PrayerType.fajr` olduğunu varsayıyor (`initState`'te öyle). Değişirse test kırılır ve bu doğru davranıştır.
- Ekran görüntüsü akışı konum ekleme ekranından geçiyor; Task 3'te yapı bozulursa `01`–`05` kareleri kırılır. Akışın davranışını değiştirmemek bu yüzden kısıt olarak yazıldı.
