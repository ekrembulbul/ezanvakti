# Ayarlar, Görünüm Bölümü ve Takvim (Faz 3.4–3.5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ayarlar ekranına **Görünüm** bölümünü eklemek — tema modu ve vakte göre renk ayarları ilk kez kullanıcıya açılıyor — ve takvimi tasarımdaki tablo düzenine geçirmek.

**Architecture:** Ayarlar ekranı kendi `SettingsGroup`/`SettingsRow`/`SettingsSectionTitle` üçlüsünü taşıyor; bunlar Plan 3'teki `GroupedList`/`GroupedRow`/`SectionLabel` ile birebir aynı işi yapıyor. Kopyalar silinip ortak bileşenlere devrediliyor. Görünüm bölümü ayrı bir widget olarak yazılıyor çünkü `ThemeController`'a bağlanan tek yer orası. Takvim, genişleyen kart listesinden sabit başlıklı tabloya dönüyor.

**Tech Stack:** Flutter, `provider`, `intl`, `flutter_test`. Yeni paket eklenmez.

**Spec:** `docs/superpowers/specs/2026-08-01-redesign-0.3.0-design.md` §6.5, §6.6, D4
**Önceki planlar:** `2026-08-01-tema-altyapisi.md`, `2026-08-02-ana-ekran.md`, `2026-08-03-alarm-ve-bildirim-ekranlari.md` (üçü de tamamlandı)

## Global Constraints

- Kod/dosya/sınıf/fonksiyon adları **İngilizce**; kullanıcıya görünen metin ve yorumlar Türkçe.
- **Yeni ve dokunulan kod renk sabiti yazmaz.** Renk `context.tokens`, tipografi `AppTypography`.
- Font boyutu için çıplak sayı yok; ölçek `11 · 12 · 13 · 14 · 16 · 17 · 20 · 24 · 44 · 62`.
- Kontrol animasyonları **220 ms `Curves.easeOutCubic`**; palet geçişi `ThemeController`'ın işi (400 ms).
- Uyarı, seçim ve pasif durumlar **nötr kalır**; vurgu yalnızca vakit bilgisi ve tek birincil eylem için.
- Her task sonunda `flutter analyze` temiz ve `flutter test` yeşil.
- Commit'ler `redesign/0.3.0` branch'ine.

### Ekran görüntüsü alırken

Alarm izin dialog'u ekranda kalırsa Flutter yeni kare çizmez ve 18 kare de aynı çıkar. **Her koşudan önce simülatörü sıfırla:**

```bash
UDID=<simulator-udid>
xcrun simctl shutdown $UDID; sleep 3
xcrun simctl boot $UDID; sleep 10
xcrun simctl uninstall $UDID com.ekrembulbul.ezanvakti
rm -rf screenshots
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart -d $UDID
```

**Sonucu daima doğrula** — 18 çıkmalı:

```bash
shasum screenshots/*.png | awk '{print $1}' | sort -u | wc -l
```

---

## File Structure

**Silinen (ölü kod — hiçbir yerden referans verilmiyor)**

| Dosya | Satır | Renk sabiti |
|---|---|---|
| `lib/presentation/widgets/settings/about_card.dart` | 110 | 10 |
| `lib/presentation/widgets/home/quick_action_card.dart` | 84 | 3 |
| `lib/presentation/widgets/date_card.dart` | 67 | 6 |
| `lib/presentation/widgets/notifications/notification_empty_state.dart` | 79 | 8 |

**Silinen (ortak bileşenle ikame)**

| Dosya | Yerine geçen |
|---|---|
| `lib/presentation/widgets/settings/settings_cards.dart` | `GroupedList` · `GroupedRow` · `SectionLabel` |
| `lib/presentation/widgets/calendar/calendar_day_card.dart` | `CalendarTable` |

**Yeni**

| Dosya | Sorumluluk |
|---|---|
| `lib/presentation/widgets/settings/appearance_section.dart` | Görünüm bölümü: tema seçici, vakte göre renk anahtarı, palet şeridi |
| `lib/presentation/widgets/calendar/calendar_table.dart` | Sabit başlıklı vakit tablosu |

**Değişen**

| Dosya | Değişiklik |
|---|---|
| `lib/presentation/screens/settings_screen.dart` | GENEL / GÖRÜNÜM / BİLGİ düzeni, sürüm satırı |
| `lib/presentation/screens/calculation_settings_screen.dart` | Token'lara taşınır |
| `lib/presentation/screens/calendar_screen.dart` | Tablo düzenine geçer |
| `lib/presentation/widgets/home/home_menu_sheet.dart` | Token'lara taşınır |

---

## Task 1: Ölü widget'ları sil

Dört widget hiçbir yerden referans verilmiyor; taşımak yerine silmek doğru. Toplam 340 satır ve 27 renk sabiti bedavaya gidiyor.

**Files:**
- Delete: `about_card.dart`, `quick_action_card.dart`, `date_card.dart`, `notification_empty_state.dart`

- [ ] **Step 1: Referanssız olduklarını doğrula**

```bash
for w in AboutCard FeatureChip QuickActionCard DateCard NotificationEmptyState; do
  echo "$w:"; grep -rn "$w" lib test integration_test --include='*.dart' | grep -v "widgets/settings/about_card.dart\|widgets/home/quick_action_card.dart\|widgets/date_card.dart\|widgets/notifications/notification_empty_state.dart"
done
```
Expected: hiçbir satır dönmemeli. Dönerse o widget'ı **silme**, plandan çıkar ve bunu raporla.

- [ ] **Step 2: Sil**

```bash
git rm lib/presentation/widgets/settings/about_card.dart \
       lib/presentation/widgets/home/quick_action_card.dart \
       lib/presentation/widgets/date_card.dart \
       lib/presentation/widgets/notifications/notification_empty_state.dart
```

- [ ] **Step 3: Analiz ve testler**

Run: `flutter analyze && flutter test`
Expected: `No issues found`, hepsi PASS.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: kullanilmayan widget'lari sil

AboutCard, QuickActionCard, DateCard ve NotificationEmptyState hicbir
yerden referans verilmiyordu. 340 satir ve 27 renk sabiti gitti."
```

---

## Task 2: Ayar bileşenlerini ortak bileşenlere devret

`SettingsGroup` = `GroupedList`, `SettingsRow` = `GroupedRow`, `SettingsSectionTitle` = `SectionLabel`. Üç kopya yerine tek kaynak.

**Files:**
- Delete: `lib/presentation/widgets/settings/settings_cards.dart`
- Modify: `lib/presentation/screens/settings_screen.dart`
- Test: `test/widgets/screens/settings_screen_test.dart`

**Interfaces:**
- Consumes: `GroupedList`, `GroupedRow`, `SectionLabel`, `context.tokens`, `AppTypography`
- Produces: `SettingsRow` yerine doğrudan `GroupedRow` kullanımı; `value` + `chevron` `trailing`'e taşınır

- [ ] **Step 1: Testi yaz**

Create: `test/widgets/screens/settings_screen_test.dart`

```dart
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

const _location = Location(id: '1', province: 'İstanbul', district: 'Kadıköy');

void main() {
  Future<void> pumpSettings(WidgetTester tester, {VoidCallback? onCalc}) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        SettingsScreen(
          currentLocation: _location,
          onCalculationSettings: onCalc,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Uc bolum basligi buyuk harfle cizilir', (tester) async {
    await pumpSettings(tester);

    expect(find.text('GENEL'), findsOneWidget);
    expect(find.text('GÖRÜNÜM'), findsOneWidget);
    expect(find.text('BİLGİ'), findsOneWidget);
  });

  testWidgets('Konum ve hesaplama satirlari gorunur', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Konum'), findsOneWidget);
    expect(find.text('Hesaplama'), findsOneWidget);
    expect(find.text('Kadıköy, İstanbul'), findsOneWidget);
  });

  testWidgets('Hesaplama satirina dokunmak callback tetikler', (tester) async {
    var tapped = false;
    await pumpSettings(tester, onCalc: () => tapped = true);

    await tester.tap(find.text('Hesaplama'));
    expect(tapped, isTrue);
  });

  testWidgets('Veri kaynagi ve gizlilik satirlari BILGI altinda', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text('Veri kaynağı'), findsOneWidget);
    expect(find.text('Aladhan API'), findsOneWidget);
    expect(find.text('Gizlilik'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/widgets/screens/settings_screen_test.dart`
Expected: FAIL — `GÖRÜNÜM` ve `Gizlilik` yok, başlıklar `SettingsSectionTitle` ile farklı biçimde.

- [ ] **Step 3: `settings_cards.dart`'ı sil ve ekranı devret**

```bash
git rm lib/presentation/widgets/settings/settings_cards.dart
```

Modify: `lib/presentation/screens/settings_screen.dart` — `SettingsGroup`/`SettingsRow`/`SettingsSectionTitle` kullanımlarını değiştir. Satır kalıbı:

```dart
  /// Ayar satırı: sağda değer metni, dokunulabilirse ok.
  Widget _row({
    required IconData icon,
    required String title,
    String? value,
    VoidCallback? onTap,
  }) {
    final tokens = context.tokens;

    return GroupedRow(
      icon: icon,
      title: Text(title),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.rowSubtitle.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: tokens.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Analiz ve testler**

Run: `flutter analyze && flutter test`
Expected: temiz; settings testi hâlâ `GÖRÜNÜM`/`Gizlilik` yüzünden düşer (Task 3–4'te kapanacak). **Bu task'ta yalnızca `flutter analyze` temiz olmalı ve diğer testler geçmeli.**

- [ ] **Step 5: Commit**

```bash
git add -A lib
git commit -m "refactor: ayar bilesenlerini ortak bilesenlere devret

SettingsGroup/SettingsRow/SettingsSectionTitle, GroupedList/GroupedRow/
SectionLabel ile birebir ayni isi yapiyordu. Kopyalar silindi, ayarlar
ekrani ortak bilesenlere gecti."
```

---

## Task 3: `AppearanceSection`

Spec D4: "Vakte göre renk" **kapalıyken** palet şeridi seçici olur, açıkken salt gösterim.

**Files:**
- Create: `lib/presentation/widgets/settings/appearance_section.dart`
- Test: `test/widgets/settings/appearance_section_test.dart`

**Interfaces:**
- Consumes: `ThemeController` (`settings`, `setThemeMode`, `setTimeBasedColor`, `setFixedPalette`), `AppThemeMode`, `DayPhase`, `paletteFor`, `SlidingSegment`, `GroupedList`, `context.tokens`
- Produces: `class AppearanceSection extends StatelessWidget` — `AppearanceSection({Key? key})`; `ThemeController`'ı `context.watch` ile alır

- [ ] **Step 1: Testi yaz**

Create: `test/widgets/settings/appearance_section_test.dart`

```dart
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/theme_controller.dart';
import 'package:ezanvakti/presentation/widgets/settings/appearance_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../theme_harness.dart';

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

void main() {
  Future<ThemeController> pumpSection(
    WidgetTester tester, {
    AppearanceSettings? initial,
  }) async {
    final storage = _InMemoryStorage();
    if (initial != null) storage.stored = initial;
    final controller = ThemeController(
      storage: storage,
      clock: () => DateTime(2026, 8, 3, 12),
    );
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeController>.value(
        value: controller,
        child: wrapWithTheme(const AppearanceSection()),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('Tema secici uc secenek gosterir', (tester) async {
    await pumpSection(tester);

    expect(find.text('Koyu'), findsOneWidget);
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Sistem'), findsOneWidget);
  });

  testWidgets('Tema secimi controller a yazilir', (tester) async {
    final controller = await pumpSection(tester);

    await tester.tap(find.text('Açık'));
    await tester.pumpAndSettle();

    expect(controller.settings.themeMode, AppThemeMode.light);
  });

  testWidgets('Vakte gore renk anahtari acik baslar ve kapatilabilir', (
    tester,
  ) async {
    final controller = await pumpSection(tester);

    expect(controller.settings.timeBasedColor, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(controller.settings.timeBasedColor, isFalse);
  });

  testWidgets('Anahtar acikken palet seridi secilemez', (tester) async {
    final controller = await pumpSection(tester);

    await tester.tap(find.byKey(const Key('palette_swatch_morning')));
    await tester.pumpAndSettle();

    // Acikken serit salt gosterim; secim degismemeli.
    expect(controller.settings.fixedPalette, DayPhase.evening);
  });

  testWidgets('Anahtar kapaliyken palet secilebilir', (tester) async {
    final controller = await pumpSection(
      tester,
      initial: const AppearanceSettings(timeBasedColor: false),
    );

    await tester.tap(find.byKey(const Key('palette_swatch_morning')));
    await tester.pumpAndSettle();

    expect(controller.settings.fixedPalette, DayPhase.morning);
  });

  testWidgets('Dort palet ornegi cizilir', (tester) async {
    await pumpSection(tester);

    for (final phase in DayPhase.values) {
      expect(
        find.byKey(Key('palette_swatch_${phase.name}')),
        findsOneWidget,
        reason: phase.name,
      );
    }
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/widgets/settings/appearance_section_test.dart`
Expected: FAIL — `appearance_section.dart` yok.

- [ ] **Step 3: Bileşeni yaz**

Create: `lib/presentation/widgets/settings/appearance_section.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/appearance_settings.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/day_phase.dart';
import '../../../core/theme/palettes.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/tokens_context.dart';
import '../common/sliding_segment.dart';

/// Ayarlar → Görünüm bölümü.
///
/// Tema modu ve "vakte göre renk" ayarlarının tek kullanıcı arayüzü.
/// Palet şeridi, anahtar **kapalıyken** seçici olur (spec D4): sabit renk bir
/// kimlik tercihidir, uygulamanın dayatması değil.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final tokens = context.tokens;
    final settings = controller.settings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tema',
            style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: 12),
          SlidingSegment<AppThemeMode>(
            items: const [
              SegmentItem(value: AppThemeMode.dark, label: 'Koyu'),
              SegmentItem(value: AppThemeMode.light, label: 'Açık'),
              SegmentItem(value: AppThemeMode.system, label: 'Sistem'),
            ],
            selected: settings.themeMode,
            onChanged: controller.setThemeMode,
            height: 40,
            radius: 12,
            padding: 3,
          ),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: tokens.divider),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vakte göre renk',
                      style: AppTypography.rowTitle.copyWith(
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      settings.timeBasedColor
                          ? 'Zemin gün içinde ilerler'
                          : 'Sabit bir palet seçin',
                      style: AppTypography.rowSubtitle.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.timeBasedColor,
                onChanged: controller.setTimeBasedColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PaletteStrip(controller: controller),
        ],
      ),
    );
  }
}

/// Dört paletin önizleme şeridi. Anahtar kapalıyken seçici.
class _PaletteStrip extends StatelessWidget {
  final ThemeController controller;

  const _PaletteStrip({required this.controller});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final settings = controller.settings;
    final selectable = !settings.timeBasedColor;

    return Row(
      children: [
        for (final phase in DayPhase.values) ...[
          if (phase != DayPhase.values.first) const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              key: Key('palette_swatch_${phase.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: selectable
                  ? () => controller.setFixedPalette(phase)
                  : null,
              child: Container(
                height: 34,
                decoration: BoxDecoration(
                  gradient: paletteFor(
                    phase,
                    controller.brightness,
                  ).backgroundGradient,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: _isMarked(phase)
                        ? tokens.accent
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Anahtar açıkken o anki dilim, kapalıyken kullanıcının seçtiği palet
  /// çerçeveyle işaretlenir.
  bool _isMarked(DayPhase phase) => controller.phase == phase;
}
```

- [ ] **Step 4: Testleri çalıştır**

Run: `flutter test test/widgets/settings/appearance_section_test.dart`
Expected: 6 test PASS.

- [ ] **Step 5: Analiz, testler, commit**

```bash
flutter analyze && flutter test
git add lib/presentation/widgets/settings/appearance_section.dart test/widgets/settings/appearance_section_test.dart
git commit -m "feat: Ayarlar Gorunum bolumu

Tema modu (koyu/acik/sistem) ve vakte gore renk ayarlari ilk kez
kullaniciya aciliyor. Palet seridi anahtar kapaliyken secici oluyor
(spec D4); acikken o anki dilim cerceveyle isaretli, salt gosterim."
```

---

## Task 4: Ayarlar ekranı

**Files:**
- Modify: `lib/presentation/screens/settings_screen.dart`
- Test: `test/widgets/screens/settings_screen_test.dart` (Task 2'de yazıldı)

**Interfaces:**
- Consumes: `AppearanceSection`, `GroupedList`, `GroupedRow`, `SectionLabel`, `AppSurface`
- Produces: `SettingsScreen` — mevcut **kullanılmayan** `onAbout` alanı `onPrivacy` olarak yeniden adlandırılır (yeni alan eklenmez; `onAbout` hiçbir yerden geçilmiyor)

- [ ] **Step 1: Ekranı yeniden düzenle**

Modify: `lib/presentation/screens/settings_screen.dart`

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const SimpleAppBar(title: 'Ayarlar'),
      body: AppSurface(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            const SectionLabel('Genel'),
            const SizedBox(height: 10),
            GroupedList(
              children: [
                _row(
                  icon: widget.currentLocation.type == LocationType.gps
                      ? Icons.my_location_rounded
                      : Icons.location_on_rounded,
                  title: 'Konum',
                  value: widget.currentLocation.displayName,
                  onTap: widget.onChangeLocation,
                ),
                _row(
                  icon: Icons.tune_rounded,
                  title: 'Hesaplama',
                  onTap: widget.onCalculationSettings,
                ),
              ],
            ),
            const SizedBox(height: 26),
            const SectionLabel('Görünüm'),
            const SizedBox(height: 10),
            const AppearanceSection(),
            const SizedBox(height: 26),
            const SectionLabel('Bilgi'),
            const SizedBox(height: 10),
            GroupedList(
              children: [
                _row(
                  icon: Icons.cloud_download_rounded,
                  title: 'Veri kaynağı',
                  value: widget.dataSource,
                ),
                _row(
                  icon: Icons.lock_rounded,
                  title: 'Gizlilik',
                  onTap: widget.onPrivacy ?? _showPrivacy,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildFooter(),
          ],
        ),
      ),
    );
  }
```

Başlık bloğu (`_buildHeader`) token'lara taşınır; sürüm satırı `Sürüm $_version` kalır (`package_info_plus` 0.3.0'ı `pubspec.yaml`'dan okur, sabit yazılmaz).

`_showPrivacy` basit bir diyalog gösterir — ayrı ekran açmak bu turun kapsamı dışında:

```dart
  /// Gizlilik özeti. Tam metin `docs/privacy.html`'de; uygulamaya gömmek ayrı
  /// bir iş olduğu için burada özet gösteriliyor.
  void _showPrivacy() {
    final tokens = context.tokens;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.backgroundStops[1],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Gizlilik',
          style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
        ),
        content: Text(
          'Konumunuz yalnızca namaz vakitlerini hesaplamak için kullanılır ve '
          'cihazınızda saklanır. Vakit verisi Aladhan API üzerinden koordinatla '
          'sorgulanır; kişisel bilgi gönderilmez.',
          style: AppTypography.rowSubtitle.copyWith(
            color: tokens.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
```

`SettingsScreen`'deki `final VoidCallback? onAbout;` alanı `onPrivacy` olarak yeniden adlandırılır. Bu alan hiçbir çağırandan geçilmiyor (doğrulandı), bu yüzden yeniden adlandırma kırılma yaratmaz ve ikinci bir ölü callback eklenmemiş olur.

- [ ] **Step 2: Testleri çalıştır**

Run: `flutter test test/widgets/screens/settings_screen_test.dart`
Expected: 4 test PASS. `AppearanceSection` `ThemeController` istediği için test sarmalayıcısına provider eklemek gerekebilir; gerekirse `pumpSettings` içine Task 3'teki `ChangeNotifierProvider` kalıbını kopyala.

- [ ] **Step 3: Analiz, testler, commit**

```bash
flutter analyze && flutter test
git add -A lib test
git commit -m "feat: ayarlar ekranini yeni duzene gecir

GENEL / GORUNUM / BILGI bolumleri; Gorunum bolumu tema modu ve vakte
gore renk ayarlarini aciyor. Gizlilik satiri eklendi (ozet diyalog;
tam metin docs/privacy.html'de). Ekran renk sabiti yazmiyor."
```

---

## Task 5: Hesaplama ekranı

**Files:**
- Modify: `lib/presentation/screens/calculation_settings_screen.dart`
- Modify: `lib/presentation/widgets/location/calculation_params_selector.dart`

**Interfaces:**
- Consumes: `AppSurface`, `SectionLabel`, `context.tokens`
- Produces: parametre listeleri değişmez

- [ ] **Step 1: Token'lara taşı**

İki dosyadaki `AppTheme.*` ve `Colors.white*` kullanımlarını token'lara çevir:

| Eski | Yeni |
|---|---|
| `AppTheme.gold` | `context.tokens.accent` |
| `AppTheme.primaryMedium` | `context.tokens.backgroundStops[1]` |
| `AppTheme.nightGradient` (zemin) | `AppSurface` sarmalayıcısı |
| `Colors.white` | `context.tokens.textPrimary` |
| `Colors.white70` / `alpha: 0.7` | `context.tokens.textSecondary` |
| `Colors.white.withValues(alpha: 0.5)` ve altı | `context.tokens.textTertiary` |
| `Colors.white.withValues(alpha: 0.05–0.1)` (yüzey) | `context.tokens.surface` |
| `Colors.white.withValues(alpha: 0.1–0.15)` (kenarlık) | `context.tokens.border` |

`Scaffold`'a `backgroundColor: Colors.transparent` ver, gövdeyi `AppSurface` ile sar.

- [ ] **Step 2: Doğrula**

```bash
grep -c "AppTheme\.\|Colors\.white" \
  lib/presentation/screens/calculation_settings_screen.dart \
  lib/presentation/widgets/location/calculation_params_selector.dart
```
Expected: ikisi de **0**.

Run: `flutter analyze && flutter test`
Expected: temiz ve yeşil.

- [ ] **Step 3: Commit**

```bash
git add -A lib
git commit -m "refactor: hesaplama ekranini token'lara tasi"
```

---

## Task 6: Takvim tablo düzeni

Genişleyen kart listesi yerine sabit başlıklı tablo.

**Files:**
- Create: `lib/presentation/widgets/calendar/calendar_table.dart`
- Delete: `lib/presentation/widgets/calendar/calendar_day_card.dart`
- Modify: `lib/presentation/screens/calendar_screen.dart`
- Test: `test/widgets/calendar/calendar_table_test.dart`

**Interfaces:**
- Consumes: `PrayerTime`, `PrayerType`, `PrayerUtils`, `context.tokens`, `AppTypography.gridPrayerName/gridValue`
- Produces:
  - `class CalendarTable extends StatelessWidget` — `CalendarTable({required List<PrayerTime> days, required DateTime now, ScrollController? controller, Key? key})`
  - `class CalendarHeaderRow extends StatelessWidget` — sabit başlık satırı

- [ ] **Step 1: Testi yaz**

Create: `test/widgets/calendar/calendar_table_test.dart`

```dart
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/widgets/calendar/calendar_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../theme_harness.dart';

PrayerTime _day(int day) {
  DateTime at(int h, int m) => DateTime(2026, 8, day, h, m);
  return PrayerTime(
    fajr: at(4, 8),
    sunrise: at(5, 53),
    dhuhr: at(13, 15),
    asr: at(17, 10),
    maghrib: at(20, 27),
    isha: at(22, 4),
    date: DateTime(2026, 8, day),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  Future<void> pumpTable(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        CalendarTable(
          days: [_day(2), _day(3), _day(4)],
          now: DateTime(2026, 8, 3, 17, 34),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Sabit baslik satiri alti vakit adini gosterir', (tester) async {
    await pumpTable(tester);

    for (final name in ['İMSAK', 'GÜNEŞ', 'ÖĞLE', 'İKİNDİ', 'AKŞAM', 'YATSI']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('Her gun icin bir satir cizilir', (tester) async {
    await pumpTable(tester);

    expect(find.byKey(const Key('calendar_row')), findsNWidgets(3));
  });

  testWidgets('Bugun rozetle isaretlenir', (tester) async {
    await pumpTable(tester);

    expect(find.text('BUGÜN'), findsOneWidget);
  });

  testWidgets('Bugun disindaki gunler gun adiyla yazilir', (tester) async {
    await pumpTable(tester);

    expect(find.text('Pazar'), findsOneWidget);
    expect(find.text('Salı'), findsOneWidget);
  });

  testWidgets('Bos gun listesinde tablo cizilmez', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        CalendarTable(days: const [], now: DateTime(2026, 8, 3)),
      ),
    );

    expect(find.byKey(const Key('calendar_row')), findsNothing);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/widgets/calendar/calendar_table_test.dart`
Expected: FAIL — `calendar_table.dart` yok.

- [ ] **Step 3: `CalendarTable`'ı yaz**

Create: `lib/presentation/widgets/calendar/calendar_table.dart`

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/prayer_utils.dart';
import '../common/section_label.dart';

/// Takvimin sabit başlık satırı: vakit adları.
class CalendarHeaderRow extends StatelessWidget {
  const CalendarHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.divider)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 64),
          for (final type in PrayerType.values)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  SectionLabel.toTurkishUpperCase(
                    PrayerUtils.getPrayerName(type),
                  ),
                  style: AppTypography.gridPrayerName.copyWith(
                    color: tokens.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Günleri satır, vakitleri kolon olarak gösteren takvim tablosu.
class CalendarTable extends StatelessWidget {
  final List<PrayerTime> days;
  final DateTime now;
  final ScrollController? controller;

  const CalendarTable({
    super.key,
    required this.days,
    required this.now,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CalendarHeaderRow(),
        Expanded(
          child: ListView.builder(
            controller: controller,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: days.length,
            itemBuilder: (context, index) =>
                _CalendarRow(day: days[index], now: now),
          ),
        ),
      ],
    );
  }
}

class _CalendarRow extends StatelessWidget {
  final PrayerTime day;
  final DateTime now;

  const _CalendarRow({required this.day, required this.now});

  bool get _isToday =>
      day.date.year == now.year &&
      day.date.month == now.month &&
      day.date.day == now.day;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      key: const Key('calendar_row'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _isToday ? tokens.secondarySurface : null,
        border: Border(bottom: BorderSide(color: tokens.divider)),
      ),
      child: Row(
        children: [
          SizedBox(width: 64, child: _dayLabel(context)),
          for (final type in PrayerType.values)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  DateFormat(
                    'HH:mm',
                  ).format(PrayerUtils.getPrayerTime(day, type)),
                  style: AppTypography.gridValue.copyWith(
                    color: _isToday ? tokens.textPrimary : tokens.textValue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayLabel(BuildContext context) {
    final tokens = context.tokens;
    final dayNumber = DateFormat('d MMM', 'tr_TR').format(day.date);
    final weekday = DateFormat('EEEE', 'tr_TR').format(day.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dayNumber,
          style: AppTypography.hint.copyWith(
            color: _isToday ? tokens.accent : tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        if (_isToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'BUGÜN',
              style: AppTypography.sectionLabel.copyWith(
                color: tokens.backgroundStops.last,
                letterSpacing: 0.5,
              ),
            ),
          )
        else
          Text(
            weekday,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.hint.copyWith(color: tokens.textTertiary),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Takvim ekranını tabloya geçir**

Modify: `lib/presentation/screens/calendar_screen.dart`

- `Scaffold` → `backgroundColor: Colors.transparent`, gövde `AppSurface`.
- App bar: başlık `Vakit Takvimi`, alt satırda `${location.displayName} · ${days.length} gün`.
- Gövde `CalendarTable(days: widget.prayerTimes, now: DateTime.now(), controller: _scrollController)`.
- `calendar_day_card.dart` import'u ve `_itemKeys`/`GlobalKey` mekanizması kaldırılır; bugüne kaydırma `ListView`'in `initialScrollOffset`'iyle değil, `_todayIndex * satırYüksekliği` yaklaşımı yerine `Scrollable.ensureVisible` gerektirmeyen basit yolla yapılır: `CalendarTable`'a `initialIndex` verip `ScrollController(initialScrollOffset: index * 64.0)` kurulur. **Satır yüksekliği sabit 64** kabul edilir (dikey padding 12 + içerik).

```bash
git rm lib/presentation/widgets/calendar/calendar_day_card.dart
```

- [ ] **Step 5: Testler, analiz, commit**

```bash
flutter test test/widgets/calendar/calendar_table_test.dart
flutter analyze && flutter test
git add -A lib test
git commit -m "feat: takvimi tablo duzenine gecir

Genisleyen kart listesi yerine sabit baslikli tablo: gunler satir,
vakitler kolon. Bugun rozetle ve zemin tonuyla isaretli.
calendar_day_card kaldirildi."
```

---

## Task 7: Menü sayfası ve görsel doğrulama

**Files:**
- Modify: `lib/presentation/widgets/home/home_menu_sheet.dart`

- [ ] **Step 1: Menüyü token'lara taşı**

`AppTheme.primaryMedium`/`primaryDark` gradyanı → `tokens.backgroundStops[1]` ve `backgroundStops.last`; `AppTheme.gold` → `tokens.accent`; `Colors.white*` → uygun token. Başlık `AppTypography.rowTitle`, alt metin `AppTypography.rowSubtitle`.

- [ ] **Step 2: Kalan renk sabitlerini say**

```bash
grep -rho 'AppTheme\.[a-zA-Z]*' lib --include='*.dart' | grep -v 'AppTheme.build' | wc -l
```
Expected: Plan 3 sonundaki 138'den belirgin düşük. Kalanlar konum ekranları ve bildirim ekle sayfası (Plan 5).

- [ ] **Step 3: Simülatörü sıfırla ve görüntü al**

Yukarıdaki "Ekran görüntüsü alırken" bloğu.

- [ ] **Step 4: Benzersiz hash sayısını doğrula**

Run: `shasum screenshots/*.png | awk '{print $1}' | sort -u | wc -l`
Expected: **18**.

- [ ] **Step 5: Tasarımla karşılaştır**

`06-menu.png`, `07-takvim.png`, `11-ayarlar.png`, `12-hesaplama.png` karelerini kontrol et:
- Ayarlar'da GENEL / GÖRÜNÜM / BİLGİ üç bölüm, Görünüm'de tema segmenti + anahtar + palet şeridi
- Takvim tablo düzeninde, bugün rozetli
- Taşma yok

- [ ] **Step 6: Açık temayı ilk kez gerçek uygulamada dene**

Ayarlar → Görünüm → **Açık**. Ekranları gez ve okunabilirliği kontrol et. Bu, açık temanın ilk gerçek denemesi; okunamayan yüzey çıkarsa **not al ve raporla** — düzeltmesi Plan 5'te ilgili ekranla birlikte yapılır.

- [ ] **Step 7: Commit**

```bash
git add -A lib
git commit -m "refactor: ana ekran menusunu token'lara tasi"
```

---

## Self-Review

**1. Spec coverage**

| Spec | Karşılığı |
|---|---|
| §6.6 Ayarlar: GENEL/GÖRÜNÜM/BİLGİ, sürüm, Gizlilik | Task 4 |
| §6.6 GÖRÜNÜM: tema segmenti, vakte göre renk, palet şeridi | Task 3 |
| D4 anahtar kapalıyken palet seçilebilir | Task 3, iki ayrı testle (açıkken seçilemez / kapalıyken seçilir) |
| §6.5 Takvim: sabit başlık, gün satırları, BUGÜN rozeti | Task 6 |
| §6.7 Konum ekranları | **Plan 5** |
| Bildirim ekle alt sayfası | **Plan 5** |
| §10 V4 kontrast, 8 kombinasyon testi | **Plan 6** |

**2. Placeholder scan:** Temiz. Task 5 mekanik dönüşüm ama eşleme tablosu verilmiş ve Step 2 sonucu sayıyla doğruluyor. Task 6 Step 4'te satır yüksekliği varsayımı (64) açıkça yazılı.

**3. Type consistency**

- `AppearanceSection()` Task 3'te tanımlandı, Task 4'te kullanıldı.
- `CalendarTable({days, now, controller})` Task 6 Step 3'te tanımlandı, Step 4'te aynı adlarla çağrıldı.
- `SectionLabel.toTurkishUpperCase` Plan 3'te eklenmişti; Task 6'da `CalendarHeaderRow` onu kullanıyor.
- `GroupedRow({icon, title, subtitle, trailing, onTap, dimmed})` Plan 3'ten; Task 2'deki `_row` yardımcısı `trailing` üzerinden `value` + chevron veriyor.
- `SettingsScreen`'in kullanılmayan `onAbout` alanı `onPrivacy` olarak yeniden adlandırılıyor; hiçbir çağıran geçmediği için `home_page.dart` değişmiyor.

**4. Bilinen risk**

Task 6 Step 4'teki "bugüne kaydır" davranışı sabit satır yüksekliği (64) varsayıyor. Yükseklik değişirse kaydırma hedefi kayar. Görsel doğrulamada (Task 7 Step 5) takvimin bugüne açıldığı kontrol edilmeli; kaymışsa `Scrollable.ensureVisible` yaklaşımına dönülür.
