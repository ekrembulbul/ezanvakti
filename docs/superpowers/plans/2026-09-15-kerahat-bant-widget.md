# Kerahat bandı ve iOS widget yeni düzeni — uygulama planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. (Bu repoda global talimat gereği plan **inline** yürütülür.)

**Goal:** Ana ekranda tarih satırının altına iki durumlu kerahat bandı koymak; iOS küçük/orta widget'ı "üst blok · çizgi · vakit adı ile saat yan yana · ince sayaç" düzenine geçirmek ve kerahat çipi eklemek.

**Architecture:** Kural (`KerahatWarning`), snapshot v4 ve Swift timeline anları değişmez; yalnız sunum katmanı. Dart'ta bant `CountdownHero` içinde (tek saat kaynağı), Türkçe bulunma eki saf yardımcı. Swift'te çip metni `WidgetCore` içinde saf fonksiyon (test edilir), görünümler ortak alt bileşenleri paylaşır, kerahatte zemin palet bağımsız bordo duraklara geçer.

**Tech Stack:** Flutter/Dart (intl, flutter gen-l10n), SwiftUI + WidgetKit (iOS 17), XCTest (`RunnerTests`).

**Spec:** `docs/superpowers/specs/2026-09-15-kerahat-bant-widget-design.md`

## Global Constraints

- Renk: bordo. Token değerleri `palettes.dart` ↔ `Palette.swift` birebir (koyu line `#A14158` surface `#3C1F2A` text `#FF9292`; açık line `#8D243B` surface `#F9E9EC` text `#8D243B`).
- Kerahatte widget zemini: koyu `[#4B1E30, #2A1421, #150C11]`, açık `[#E9B9C6, #F3D8DF, #FAEEF0]`.
- Parıltı `kerahatGlow`: koyu `kerahatLine` α.34, açık α.16.
- Ekranlarda çıplak `fontSize` yok (`AppTypography` stilleri). Kullanıcı metni ARB'de (tr kaynak, en/ar karşılık), `flutter gen-l10n` sonrası üretilen dosyalar elle düzenlenmez.
- Widget çipi ek almaz ("Kerahat 18:38"); canlı dakika yok.
- `WidgetAlignment.default` ve intent varsayılanı `.center`.
- Her iş `dev` üzerinde Türkçe Conventional Commit; push yok.

---

### Task 1: Türkçe bulunma eki yardımcısı

**Files:**
- Create: `lib/core/utils/turkish_suffix.dart`
- Test: `test/core/turkish_suffix_test.dart`

**Interfaces:**
- Produces: `String turkishLocativeSuffix({required int hour, required int minute})` → `"'de" | "'da" | "'te" | "'ta"`; aralık dışı değerde `RangeError`.

- [ ] **Step 1: Başarısız testi yaz**

```dart
import 'package:ezanvakti/core/utils/turkish_suffix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dakika sıfır değilse dakikanın son kelimesine göre ek gelir', () {
    expect(turkishLocativeSuffix(hour: 18, minute: 38), "'de"); // sekiz
    expect(turkishLocativeSuffix(hour: 19, minute: 23), "'te"); // üç
    expect(turkishLocativeSuffix(hour: 18, minute: 45), "'te"); // beş
    expect(turkishLocativeSuffix(hour: 18, minute: 46), "'da"); // altı
    expect(turkishLocativeSuffix(hour: 18, minute: 49), "'da"); // dokuz
    expect(turkishLocativeSuffix(hour: 18, minute: 40), "'ta"); // kırk
    expect(turkishLocativeSuffix(hour: 18, minute: 30), "'da"); // otuz
    expect(turkishLocativeSuffix(hour: 18, minute: 50), "'de"); // elli
    expect(turkishLocativeSuffix(hour: 18, minute: 10), "'da"); // on
  });

  test('dakika sıfırsa saat okunur', () {
    expect(turkishLocativeSuffix(hour: 13, minute: 0), "'te"); // on üç
    expect(turkishLocativeSuffix(hour: 10, minute: 0), "'da"); // on
    expect(turkishLocativeSuffix(hour: 20, minute: 0), "'de"); // yirmi
    expect(turkishLocativeSuffix(hour: 6, minute: 0), "'da"); // altı
    expect(turkishLocativeSuffix(hour: 0, minute: 0), "'da"); // sıfır
  });

  test('aralık dışı saat veya dakika hata fırlatır', () {
    expect(() => turkishLocativeSuffix(hour: 24, minute: 0), throwsRangeError);
    expect(() => turkishLocativeSuffix(hour: 1, minute: 60), throwsRangeError);
    expect(() => turkishLocativeSuffix(hour: -1, minute: 5), throwsRangeError);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/core/turkish_suffix_test.dart`
Expected: derleme hatası — `turkish_suffix.dart` yok.

- [ ] **Step 3: Yardımcıyı yaz**

```dart
/// Saat okunuşuna gelen Türkçe bulunma eki: "18:38'de", "19:23'te", "18:40'ta".
///
/// Ek, saatin okunuşundaki **son kelimeye** göre seçilir: dakika sıfır değilse
/// dakika, sıfırsa saat okunur ("on sekiz otuz sekiz-de", "on üç-te"). Son
/// kelime birler basamağıdır; birler sıfırsa onlar basamağı. Ünlü uyumu ve
/// ünsüz sertleşmesi kelimeye gömülü olduğundan tablo yeterlidir.
String turkishLocativeSuffix({required int hour, required int minute}) {
  if (hour < 0 || hour > 23) {
    throw RangeError.range(hour, 0, 23, 'hour');
  }
  if (minute < 0 || minute > 59) {
    throw RangeError.range(minute, 0, 59, 'minute');
  }
  final spoken = minute == 0 ? hour : minute;
  final units = spoken % 10;
  final suffix = units != 0 ? _unitsSuffix[units]! : _tensSuffix[spoken ~/ 10]!;
  return "'$suffix";
}

/// bir, iki, üç, dört, beş, altı, yedi, sekiz, dokuz.
const Map<int, String> _unitsSuffix = {
  1: 'de',
  2: 'de',
  3: 'te',
  4: 'te',
  5: 'te',
  6: 'da',
  7: 'de',
  8: 'de',
  9: 'da',
};

/// sıfır, on, yirmi, otuz, kırk, elli.
const Map<int, String> _tensSuffix = {
  0: 'da',
  1: 'da',
  2: 'de',
  3: 'da',
  4: 'ta',
  5: 'de',
};
```

- [ ] **Step 4: Testi çalıştır, geçtiğini gör**

Run: `flutter test test/core/turkish_suffix_test.dart`
Expected: 3 test PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/utils/turkish_suffix.dart test/core/turkish_suffix_test.dart
git add lib/core/utils/turkish_suffix.dart test/core/turkish_suffix_test.dart
git commit -m "feat(core): saat okunuşuna göre Türkçe bulunma eki yardımcısı"
```

---

### Task 2: `kerahatGlow` token'ı

**Files:**
- Modify: `lib/core/theme/app_tokens.dart` (alan, kurucu, `copyWith`, `lerp`)
- Modify: `lib/core/theme/palettes.dart:38-48` (sabitler), `_palette(...)`
- Test: `test/theme/palettes_test.dart` (mevcut değilse oluştur; `test/theme/` altındaki mevcut palet testine ekle)

**Interfaces:**
- Produces: `AppTokens.kerahatGlow: Color` — kerahatLine'ın alfa düşürülmüş hâli (koyu .34, açık .16).

- [ ] **Step 1: Başarısız testi yaz** (`test/theme/` altında mevcut palet test dosyasına, yoksa `palettes_test.dart`)

```dart
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kerahatGlow kerahatLine renginin alfası düşürülmüş hâlidir', () {
    for (final phase in DayPhase.values) {
      final dark = paletteFor(phase, Brightness.dark);
      final light = paletteFor(phase, Brightness.light);
      expect(dark.kerahatGlow.a, closeTo(0.34, 0.001));
      expect(light.kerahatGlow.a, closeTo(0.16, 0.001));
      expect(dark.kerahatGlow.withValues(alpha: 1), dark.kerahatLine);
      expect(light.kerahatGlow.withValues(alpha: 1), light.kerahatLine);
    }
  });
}
```

- [ ] **Step 2: Testi çalıştır** — Expected: derleme hatası (`kerahatGlow` yok).

- [ ] **Step 3: Token'ı ekle**

`app_tokens.dart` — `kerahatText` alanının altına:

```dart
  /// Kerahatte sayacın arkasındaki parıltı; [kerahatLine]'ın alfası
  /// düşürülmüş hâli (koyu temada daha belirgin).
  final Color kerahatGlow;
```
Kurucuya `required this.kerahatGlow,`; `copyWith` parametrelerine `Color? kerahatGlow,` ve gövdeye `kerahatGlow: kerahatGlow ?? this.kerahatGlow,`; `lerp` gövdesine `kerahatGlow: Color.lerp(kerahatGlow, other.kerahatGlow, t)!,` — her seferinde `kerahatText` satırının hemen altına.

`palettes.dart` — kerahat sabitlerinin altına:

```dart
/// Kerahatte sayaç parıltısı: koyu zeminde daha belirgin.
const double _kerahatGlowDarkAlpha = 0.34;
const double _kerahatGlowLightAlpha = 0.16;
```
`_palette(...)` içinde `kerahatText:` satırının altına:

```dart
    kerahatGlow: isDark
        ? _kerahatLineDark.withValues(alpha: _kerahatGlowDarkAlpha)
        : _kerahatLineLight.withValues(alpha: _kerahatGlowLightAlpha),
```
`grep -rn "AppTokens(" lib test` ile başka kurucu çağrısı varsa aynı alanı ekle.

- [ ] **Step 4: Testi çalıştır** — Run: `flutter test test/theme/` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/theme test/theme
git add lib/core/theme test/theme
git commit -m "feat(tema): kerahat parıltısı için kerahatGlow token'ı"
```

---

### Task 3: Ana ekran kerahat bandı ve sayaç parıltısı

**Files:**
- Modify: `lib/l10n/app_tr.arb:2272-2290`, `lib/l10n/app_en.arb:494-496`, `lib/l10n/app_ar.arb:494-496`
- Create: `lib/presentation/widgets/home/kerahat_band.dart`
- Modify: `lib/presentation/widgets/home/countdown_hero.dart` (`build`, `_activeCard` ve `_withSoonLine` silinir)
- Test: `test/widgets/home/countdown_hero_test.dart`

**Interfaces:**
- Consumes: `turkishLocativeSuffix` (Task 1), `AppTokens.kerahatGlow` (Task 2), `KerahatWarning.resolve` / `KerahatStatus.interval` (mevcut), `formatCompactDuration` (mevcut), `context.formatTime` (mevcut).
- Produces: `KerahatBand({required KerahatStatus status, required DateTime now})`; `kKerahatBandKey = Key('kerahat_band')`, `kKerahatBandFillKey = Key('kerahat_band_fill')`, `kKerahatGlowKey = Key('kerahat_glow')`; l10n `kerahatStartsAt(time, suffix)`, `kerahatActiveLine(time)`.

- [ ] **Step 1: ARB anahtarlarını ekle**

`app_tr.arb` — `kerahatSoonLine` bloğunun hemen altına:

```json
  "kerahatStartsAt": "Kerahat {time}{suffix} başlar",
  "@kerahatStartsAt": {
    "description": "Ana ekran kerahat bandı, yaklaşırken: başlangıç saati; suffix Türkçe bulunma eki ('de/'da/'te/'ta), diğer dillerde kullanılmaz.",
    "placeholders": {
      "time": {"type": "String"},
      "suffix": {"type": "String"}
    }
  },
  "kerahatActiveLine": "Kerahat vakti · bitiş {time}",
  "@kerahatActiveLine": {
    "description": "Ana ekran kerahat bandı, kerahatte: yaklaşık bitiş saati.",
    "placeholders": {"time": {"type": "String"}}
  },
```
`app_en.arb` (496. satırın altına): `"kerahatStartsAt": "Disliked time starts at {time}",` ve `"kerahatActiveLine": "Disliked time · until {time}",`.
`app_ar.arb`: `"kerahatStartsAt": "يبدأ وقت الكراهة عند {time}",` ve `"kerahatActiveLine": "وقت الكراهة · حتى {time}",`.

Run: `flutter gen-l10n` — Expected: hatasız; `AppLocalizations.kerahatStartsAt(String time, String suffix)` üretildi.

- [ ] **Step 2: Başarısız testleri yaz** — `countdown_hero_test.dart` içinde `CountdownHero` grubunun kerahat testlerini şu dört testle **değiştir** (diğer testler kalır):

```dart
    for (final brightness in [Brightness.dark, Brightness.light]) {
      testWidgets(
        '${brightness.name} kerahatte bant dolgulu, sayaç kerahat renginde ve parıltılı',
        (tester) async {
          final now = DateTime(2026, 9, 7, 6, 35);
          final tokens = tokensFor(brightness: brightness, phase: DayPhase.morning);
          await tester.pumpWidget(
            wrapWithTheme(
              CountdownHero(
                nextPrayerTime: DateTime(2026, 9, 7, 12, 52),
                nextPrayerName: 'Öğle',
                clock: () => now,
                kerahatIntervals: [
                  KerahatInterval(
                    kind: KerahatKind.afterSunrise,
                    start: DateTime(2026, 9, 7, 6, 15),
                    end: DateTime(2026, 9, 7, 7),
                  ),
                ],
              ),
              brightness: brightness,
              phase: DayPhase.morning,
            ),
          );

          final counter = tester.widget<Text>(find.byKey(const Key('countdown_value')));
          expect(counter.style?.color, tokens.kerahatText);
          expect(find.text('Kerahat vakti · bitiş 07:00'), findsOneWidget);
          expect(find.text('25 dk'), findsOneWidget);
          final band = tester.widget<Container>(find.byKey(kKerahatBandKey));
          expect((band.decoration! as BoxDecoration).color, tokens.kerahatLine);
          expect(
            tester.widget<Text>(find.text('Kerahat vakti · bitiş 07:00')).style?.color,
            Colors.white,
          );
          expect(
            tester.getRect(find.byKey(kKerahatBandKey)).bottom,
            lessThan(tester.getRect(find.byKey(const Key('countdown_value'))).top),
          );
          expect(find.byKey(kKerahatGlowKey), findsOneWidget);
          final fill = tester.widget<FractionallySizedBox>(
            find.ancestor(of: find.byKey(kKerahatBandFillKey), matching: find.byType(FractionallySizedBox)),
          );
          // 06:15–07:00 aralığının 20/45'i geçti.
          expect(fill.widthFactor, closeTo(20 / 45, 0.001));
          expect(find.text('SONRAKİ'), findsOneWidget);
          expect(find.text('ÖĞLE'), findsOneWidget);
          expect(find.text('06:17:00'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final locale in [const Locale('tr'), const Locale('ar')]) {
      testWidgets('${locale.languageCode} kerahat bandı büyük metinde taşmaz', (tester) async {
        final now = DateTime(2026, 9, 7, 6, 15);
        await tester.pumpWidget(
          wrapWithTheme(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                child: Center(
                  child: SizedBox(
                    width: 280,
                    child: CountdownHero(
                      nextPrayerTime: DateTime(2026, 9, 7, 13),
                      nextPrayerName: locale.languageCode == 'ar' ? 'الظهر' : 'Öğle',
                      clock: () => now,
                      kerahatIntervals: [
                        KerahatInterval(
                          kind: KerahatKind.afterSunrise,
                          start: DateTime(2026, 9, 7, 6),
                          end: DateTime(2026, 9, 7, 6, 45),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            locale: locale,
          ),
        );
        expect(find.byKey(kKerahatBandKey), findsOneWidget);
        expect(
          find.text(locale.languageCode == 'ar' ? 'وقت الكراهة · حتى 06:45' : 'Kerahat vakti · bitiş 06:45'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('countdown_value')).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('bant yaklaşırken çerçeveli, başlangıçta dolguya döner, bitişte kaybolur', (tester) async {
      final start = DateTime(2026, 9, 7, 19, 41);
      final end = DateTime(2026, 9, 7, 20, 26);
      var now = start.subtract(const Duration(minutes: 31));
      await tester.pumpWidget(
        wrapWithTheme(
          CountdownHero(
            nextPrayerTime: end,
            nextPrayerName: 'Akşam',
            clock: () => now,
            kerahatIntervals: [
              KerahatInterval(kind: KerahatKind.beforeMaghrib, start: start, end: end),
            ],
          ),
        ),
      );
      // 31 dakika kala bant yok.
      expect(find.byKey(kKerahatBandKey), findsNothing);
      expect(find.byKey(kKerahatGlowKey), findsNothing);

      now = start.subtract(const Duration(minutes: 20));
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(kKerahatBandKey), findsOneWidget);
      expect(find.text("Kerahat 19:41'de başlar"), findsOneWidget);
      expect(find.text('20 dk'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text("Kerahat 19:41'de başlar")).style?.color,
        tokensFor().kerahatText,
      );
      final band = tester.widget<Container>(find.byKey(kKerahatBandKey));
      expect((band.decoration! as BoxDecoration).color, tokensFor().kerahatSurface);
      expect(find.byIcon(Icons.wb_twilight_rounded), findsOneWidget);
      final fill = tester.widget<FractionallySizedBox>(
        find.ancestor(of: find.byKey(kKerahatBandFillKey), matching: find.byType(FractionallySizedBox)),
      );
      // 30 dakikalık pencerenin 10 dakikası geçti.
      expect(fill.widthFactor, closeTo(10 / 30, 0.001));
      expect(find.byKey(kKerahatGlowKey), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('countdown_value'))).style?.color,
        tokensFor().accent,
      );

      now = start;
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Kerahat vakti · bitiş 20:26'), findsOneWidget);
      expect(find.text('45 dk'), findsOneWidget);
      expect(find.byKey(kKerahatGlowKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('countdown_value'))).style?.color,
        tokensFor().kerahatText,
      );
      expect(find.text('Akşam vakti 20:26'), findsOneWidget);

      now = end;
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(kKerahatBandKey), findsNothing);
      expect(find.byKey(kKerahatGlowKey), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('countdown_value'))).style?.color,
        tokensFor().accent,
      );
    });

    testWidgets('saat başı başlangıçta ek saate göre seçilir', (tester) async {
      final start = DateTime(2026, 9, 7, 13);
      await tester.pumpWidget(
        wrapWithTheme(
          CountdownHero(
            nextPrayerTime: DateTime(2026, 9, 7, 13, 10),
            nextPrayerName: 'Öğle',
            clock: () => start.subtract(const Duration(minutes: 5)),
            kerahatIntervals: [
              KerahatInterval(
                kind: KerahatKind.beforeDhuhr,
                start: start,
                end: DateTime(2026, 9, 7, 13, 10),
              ),
            ],
          ),
        ),
      );
      expect(find.text("Kerahat 13:00'te başlar"), findsOneWidget);
    });
```
İmport ekle: `import 'package:ezanvakti/presentation/widgets/home/kerahat_band.dart';`.

- [ ] **Step 3: Testleri çalıştır** — Run: `flutter test test/widgets/home/countdown_hero_test.dart` — Expected: derleme hatası (`kerahat_band.dart` yok).

- [ ] **Step 4: `KerahatBand`'ı yaz**

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/utils/turkish_suffix.dart';
import '../../../features/prayer_times/domain/kerahat_status.dart';
import '../../../features/prayer_times/domain/kerahat_times.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../utils/time_format_context.dart';

const Key kKerahatBandKey = Key('kerahat_band');
const Key kKerahatBandFillKey = Key('kerahat_band_fill');

const double _kRadius = 14;
const double _kBarHeight = 4;

/// Yaklaşırken çubuğun yatağı: metin renginin soluk hâli.
const double _kTrackAlpha = 0.16;

/// Kerahatte dolgulu bant: beyaz çubuk, karartılmış yatak, bordo gölge.
const double _kActiveFillAlpha = 0.85;
const double _kActiveTrackAlpha = 0.20;
const double _kActiveShadowAlpha = 0.35;

/// Tarih satırının altındaki tam genişlik kerahat bandı.
///
/// İki durum, iki ağırlık: yaklaşırken çerçeveli ve açık zeminli, kerahatte
/// dolgulu. Çubuk yaklaşırken 30 dakikalık uyarı penceresinin, kerahatte
/// aralığın geçen kısmını gösterir. Saati ve yeniden çizimi [CountdownHero]
/// verir; bant kendi zamanlayıcısını tutmaz.
class KerahatBand extends StatelessWidget {
  final KerahatStatus status;
  final DateTime now;

  const KerahatBand({super.key, required this.status, required this.now});

  /// Uyarı penceresinin geçen kısmı (0..1).
  static double approachingProgress(KerahatInterval interval, DateTime now) {
    final remaining = interval.start.difference(now).inSeconds;
    return (1 - remaining / KerahatWarning.lead.inSeconds).clamp(0.0, 1.0);
  }

  /// Aralığın geçen kısmı (0..1); bozuk aralıkta 0.
  static double activeProgress(KerahatInterval interval, DateTime now) {
    final total = interval.end.difference(interval.start).inSeconds;
    if (total <= 0) return 0;
    return (now.difference(interval.start).inSeconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final interval = status.interval;
    final isActive = status is KerahatActive;
    final foreground = isActive ? Colors.white : tokens.kerahatText;
    final text = isActive
        ? l10n.kerahatActiveLine(context.formatTime(interval.end))
        : l10n.kerahatStartsAt(
            context.formatTime(interval.start),
            turkishLocativeSuffix(
              hour: interval.start.hour,
              minute: interval.start.minute,
            ),
          );
    final remaining = formatCompactDuration(
      (isActive ? interval.end : interval.start).difference(now),
      l10n,
    );
    final progress = isActive
        ? activeProgress(interval, now)
        : approachingProgress(interval, now);

    return Container(
      key: kKerahatBandKey,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: isActive ? tokens.kerahatLine : tokens.kerahatSurface,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: tokens.kerahatLine),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: tokens.kerahatLine.withValues(
                    alpha: _kActiveShadowAlpha,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.wb_twilight_rounded, size: 16, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.rowSubtitle.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      fontVariations: const [FontVariation('wght', 600)],
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                remaining,
                style: AppTypography.hint.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ProgressBar(
            progress: progress,
            fill: isActive
                ? Colors.white.withValues(alpha: _kActiveFillAlpha)
                : tokens.kerahatText,
            track: isActive
                ? Colors.black.withValues(alpha: _kActiveTrackAlpha)
                : tokens.kerahatText.withValues(alpha: _kTrackAlpha),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color fill;
  final Color track;

  const _ProgressBar({
    required this.progress,
    required this.fill,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kBarHeight / 2),
      child: SizedBox(
        height: _kBarHeight,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              heightFactor: 1,
              child: ColoredBox(key: kKerahatBandFillKey, color: fill),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: `CountdownHero.build`'i yeniden yaz**

`countdown_hero.dart` — `build`, `_activeCard`, `_withSoonLine` yerine:

```dart
const Key kKerahatGlowKey = Key('kerahat_glow');

/// Parıltının sayaç kutusunu aşma payı; yerleşimi etkilemez.
const EdgeInsets _kGlowBleed = EdgeInsets.fromLTRB(40, 60, 40, 80);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final now = _now();
    final status = KerahatWarning.resolve(widget.kerahatIntervals, now);
    final isActive = status is KerahatActive;
    final countdown = _countdown(
      context,
      now: now,
      color: isActive ? tokens.kerahatText : tokens.accent,
    );
    if (status == null) return countdown;

    // Bant tarih satırının altında, sayaçtan bağımsız tam genişlikte durur;
    // iki durum iki ağırlık. Kerahatte sayaç kerahat rengine döner ve arkasına
    // hafif parıltı gelir; hedefi yine sıradaki vakit.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KerahatBand(status: status, now: now),
        const SizedBox(height: 20),
        if (isActive) _withGlow(tokens.kerahatGlow, countdown) else countdown,
      ],
    );
  }

  Widget _withGlow(Color glow, Widget countdown) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -_kGlowBleed.left,
          top: -_kGlowBleed.top,
          right: -_kGlowBleed.right,
          bottom: -_kGlowBleed.bottom,
          child: IgnorePointer(
            child: DecoratedBox(
              key: kKerahatGlowKey,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 0.9,
                  colors: [
                    glow,
                    glow.withValues(alpha: glow.a * 0.47),
                    glow.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.45, 0.78],
                ),
              ),
            ),
          ),
        ),
        countdown,
      ],
    );
  }
```
Sınıf dokümanını güncelle ("Aktif kerahatte…" → "Kerahat yaklaşırken ya da sürerken sayacın üstünde [KerahatBand] çizilir; kerahatte sayaç kerahat rengine döner."). Kullanılmayan import'ları (`kerahat_times.dart` gerekiyorsa kalır) temizle; `kerahat_band.dart` import et.

- [ ] **Step 6: Eski ARB anahtarlarını kaldır**

tr/en/ar'dan `kerahatActiveTitle`, `kerahatEndsAt`, `kerahatSoonLine` ve tr'deki `@` metadata blokları silinir. Run: `flutter gen-l10n`.

- [ ] **Step 7: Doğrula**

Run: `dart format lib test && flutter analyze && flutter test test/widgets/home/countdown_hero_test.dart`
Expected: analyze temiz; hero testleri PASS. Ardından `flutter test` (tüm suite) PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/l10n lib/presentation/widgets/home/kerahat_band.dart lib/presentation/widgets/home/countdown_hero.dart test/widgets/home/countdown_hero_test.dart
git commit -m "feat(ana-ekran): tarih satırı altında iki durumlu kerahat bandı ve sayaç parıltısı"
```

---

### Task 4: iOS palet, hizalama varsayılanı, `DayLabel.short`, `KerahatChipLabel`

**Files:**
- Modify: `ios/EzanVaktiWidget/Theme/Palette.swift`
- Modify: `ios/WidgetCore/WidgetAlignment.swift:13`, `ios/EzanVaktiWidget/Configuration/EzanVaktiWidgetIntent.swift` (`default: .center`)
- Modify: `ios/WidgetCore/DayLabel.swift`, `ios/WidgetCore/PrayerTimeline.swift` (`PrayerEntry.isKerahatActive`)
- Create: `ios/WidgetCore/KerahatChipLabel.swift`, `ios/RunnerTests/KerahatChipLabelTests.swift`
- Modify: `ios/RunnerTests/WidgetAlignmentTests.swift`, `ios/RunnerTests/DayLabelTests.swift`, `ios/Runner.xcodeproj/project.pbxproj` (iki yeni dosya)

**Interfaces:**
- Produces: `Palette.kerahatLine`, `.kerahatSurface`, `.divider`, `.kerahatBackgroundGradient(in:)`; `DayLabel.short(_ day: SnapshotDay) -> String?` ("14 Eylül"); `KerahatChipLabel.text(status:compact:labels:timeFormat:locale:timeZone:) -> String`; `PrayerEntry.isKerahatActive: Bool`.

- [ ] **Step 1: Başarısız testleri yaz**

`WidgetAlignmentTests.swift`: `testDefaultIsLeading` → 
```swift
    func testDefaultIsCenter() {
        XCTAssertEqual(WidgetAlignment.default, .center)
    }
```
`DayLabelTests.swift` sonuna:
```swift
    func testShortLabelHasDayAndMonthOnly() {
        XCTAssertEqual(DayLabel.short(day("2026-09-14")), "14 Eylül")
    }

    func testShortLabelMalformedReturnsNil() {
        XCTAssertNil(DayLabel.short(day("bozuk")))
    }
```
Yeni `KerahatChipLabelTests.swift`:
```swift
import XCTest

final class KerahatChipLabelTests: XCTestCase {
    private let zone = TimeZone(identifier: "Europe/Istanbul")!
    private let locale = Locale(identifier: "tr_TR")

    private func at(_ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 14, hour: hour, minute: minute
        ))!
    }

    /// Etiketler snapshot'tan JSON olarak geldiği için testte de öyle kurulur.
    private func labels(_ json: String) throws -> SnapshotLabels {
        try JSONDecoder().decode(SnapshotLabels.self, from: Data(json.utf8))
    }

    private var approaching: KerahatStatus { .approaching(start: at(18, 38), end: at(19, 23)) }
    private var active: KerahatStatus { .active(end: at(19, 23)) }

    func testApproachingWritesLabelAndStartTimeWithoutSuffix() throws {
        let text = KerahatChipLabel.text(
            status: approaching, compact: true,
            labels: try labels(#"{"kerahat":"Kerahat"}"#),
            timeFormat: .h24, locale: locale, timeZone: zone)
        XCTAssertEqual(text, "Kerahat 18:38")
    }

    func testApproachingIsSameOnMedium() throws {
        let text = KerahatChipLabel.text(
            status: approaching, compact: false,
            labels: try labels(#"{"kerahat":"Kerahat"}"#),
            timeFormat: .h24, locale: locale, timeZone: zone)
        XCTAssertEqual(text, "Kerahat 18:38")
    }

    func testActiveCompactUsesActiveLabelOnly() throws {
        let text = KerahatChipLabel.text(
            status: active, compact: true,
            labels: try labels(#"{"kerahat":"Kerahat","kerahatActive":"Kerahat vakti","kerahatUntil":"bitiş {time}"}"#),
            timeFormat: .h24, locale: locale, timeZone: zone)
        XCTAssertEqual(text, "Kerahat vakti")
    }

    func testActiveMediumAppendsUntil() throws {
        let text = KerahatChipLabel.text(
            status: active, compact: false,
            labels: try labels(#"{"kerahat":"Kerahat","kerahatActive":"Kerahat vakti","kerahatUntil":"bitiş {time}"}"#),
            timeFormat: .h24, locale: locale, timeZone: zone)
        XCTAssertEqual(text, "Kerahat · bitiş 19:23")
    }

    func testFallsBackToTurkishWithoutLabels() {
        XCTAssertEqual(
            KerahatChipLabel.text(status: active, compact: true, labels: nil,
                                  timeFormat: .h24, locale: locale, timeZone: zone),
            "Kerahat vakti")
        XCTAssertEqual(
            KerahatChipLabel.text(status: active, compact: false, labels: nil,
                                  timeFormat: .h24, locale: locale, timeZone: zone),
            "Kerahat · bitiş 19:23")
        XCTAssertEqual(
            KerahatChipLabel.text(status: approaching, compact: true, labels: nil,
                                  timeFormat: .h24, locale: locale, timeZone: zone),
            "Kerahat 18:38")
    }

    func testTwelveHourPreference() {
        let text = KerahatChipLabel.text(
            status: approaching, compact: true, labels: nil,
            timeFormat: .h12, locale: Locale(identifier: "en_US"), timeZone: zone)
        XCTAssertEqual(text, "Kerahat 6:38 PM")
    }

    func testEntryIsKerahatActiveOnlyInActiveState() {
        var entry = PrayerEntry(date: at(18, 50), content: .noData)
        XCTAssertFalse(entry.isKerahatActive)
        entry.kerahat = approaching
        XCTAssertFalse(entry.isKerahatActive)
        entry.kerahat = active
        XCTAssertTrue(entry.isKerahatActive)
    }
}
```

- [ ] **Step 2: pbxproj'a iki dosyayı ekle** (`KerahatChipLabel.swift` → WidgetCore grubu + RunnerTests Sources + EzanVaktiWidgetExtension Sources; `KerahatChipLabelTests.swift` → RunnerTests grubu + RunnerTests Sources). Mevcut `DayLabel.swift` / `DayLabelTests.swift` satırlarını şablon al; 24 karakterlik benzersiz kimlikler: `E5A1B0000000000000000001`…`E5A1B0000000000000000005`. Python ile ekle:

```python
import re
p = 'ios/Runner.xcodeproj/project.pbxproj'
s = open(p).read()
R = {  # id: (isim, satır şablonu)
  'ref_label': 'E5A1B0000000000000000001', 'bf_label_tests': 'E5A1B0000000000000000002',
  'bf_label_ext': 'E5A1B0000000000000000003', 'ref_tests': 'E5A1B0000000000000000004',
  'bf_tests': 'E5A1B0000000000000000005',
}
def after(anchor, line): 
    global s; assert anchor in s, anchor; s = s.replace(anchor, anchor + line, 1)
after('\t\t604C2AFCEC70EFE56FB7AB4C /* DayLabelTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = 0CD673697130AB97D2EBC5AF /* DayLabelTests.swift */; };\n',
      f"\t\t{R['bf_tests']} /* KerahatChipLabelTests.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {R['ref_tests']} /* KerahatChipLabelTests.swift */; }};\n"
      f"\t\t{R['bf_label_tests']} /* KerahatChipLabel.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {R['ref_label']} /* KerahatChipLabel.swift */; }};\n"
      f"\t\t{R['bf_label_ext']} /* KerahatChipLabel.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {R['ref_label']} /* KerahatChipLabel.swift */; }};\n")
after('\t\t0CD673697130AB97D2EBC5AF /* DayLabelTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = DayLabelTests.swift; sourceTree = "<group>"; };\n',
      f"\t\t{R['ref_tests']} /* KerahatChipLabelTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KerahatChipLabelTests.swift; sourceTree = \"<group>\"; }};\n"
      f"\t\t{R['ref_label']} /* KerahatChipLabel.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KerahatChipLabel.swift; sourceTree = \"<group>\"; }};\n")
after('\t\t\t\t1AAC6FB0C672D65512B05353 /* DayLabel.swift */,\n', f"\t\t\t\t{R['ref_label']} /* KerahatChipLabel.swift */,\n")
after('\t\t\t\t0CD673697130AB97D2EBC5AF /* DayLabelTests.swift */,\n', f"\t\t\t\t{R['ref_tests']} /* KerahatChipLabelTests.swift */,\n")
after('\t\t\t\t604C2AFCEC70EFE56FB7AB4C /* DayLabelTests.swift in Sources */,\n',
      f"\t\t\t\t{R['bf_tests']} /* KerahatChipLabelTests.swift in Sources */,\n\t\t\t\t{R['bf_label_tests']} /* KerahatChipLabel.swift in Sources */,\n")
after('\t\t\t\tD7459E1754EE4D54E44C20C6 /* DayLabel.swift in Sources */,\n', f"\t\t\t\t{R['bf_label_ext']} /* KerahatChipLabel.swift in Sources */,\n")
open(p, 'w').write(s)
```
Kontrol: `plutil -lint ios/Runner.xcodeproj/project.pbxproj` → OK.

- [ ] **Step 3: Testleri çalıştır, başarısız olduğunu gör**

Run: `cd ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:RunnerTests/KerahatChipLabelTests -only-testing:RunnerTests/DayLabelTests -only-testing:RunnerTests/WidgetAlignmentTests 2>&1 | tail -30`
Expected: derleme hatası (`KerahatChipLabel`, `DayLabel.short`, `isKerahatActive` yok; `.default` `.leading`).

- [ ] **Step 4: Uygula**

`WidgetAlignment.swift:13` → `static let \`default\`: WidgetAlignment = .center` (yorum: tasarım ortalı; elle seçen kullanıcı etkilenmez). `EzanVaktiWidgetIntent.swift` → `@Parameter(title: "Hizalama", default: .center)`.

`DayLabel.swift` — `formatter`'ın altına:
```swift
    /// Kerahat satırındaki kısa biçim: `"14 Eylül"` (çip yer kapladığı için gün adı yok).
    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    static func short(_ day: SnapshotDay) -> String? {
        guard let date = parser.date(from: day.date) else { return nil }
        return shortFormatter.string(from: date)
    }
```

`PrayerTimeline.swift` — `PrayerEntry` içine `labels` alanının altına:
```swift
    /// Zemin bordo tona yalnız kerahat sürerken kayar; yaklaşırken değil.
    var isKerahatActive: Bool {
        if case .active = kerahat { return true }
        return false
    }
```

`KerahatChipLabel.swift` (yeni):
```swift
import Foundation

/// Widget'taki kerahat çipinin metni.
///
/// Saf tutuluyor ki XCTest'te sınansın; görünüm (`KerahatChip`) yalnız bunu
/// çizer. Canlı dakika yok: widget dakikada bir yenilenemez, timeline kareleri
/// yaklaşma, başlangıç ve bitiş anlarında zaten değişiyor. Başlangıç saati
/// Türkçe bulunma eki almaz ("Kerahat 18:38"): eki burada üretmek ya da
/// snapshot'la taşımak kazandırdığı iki karaktere değmez.
enum KerahatChipLabel {
    /// - Parameter compact: küçük widget; kerahatte yalnız "Kerahat vakti"
    ///   yazar, orta boyda bitiş saati de sığar.
    static func text(
        status: KerahatStatus,
        compact: Bool,
        labels: SnapshotLabels?,
        timeFormat: TimeFormatPreference,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let kerahat = labels?.kerahat ?? "Kerahat"
        func clock(_ date: Date) -> String {
            TimeFormatting.clock(date, preference: timeFormat, locale: locale, timeZone: timeZone)
        }
        switch status {
        case let .approaching(start, _):
            return "\(kerahat) \(clock(start))"
        case let .active(end):
            if compact { return labels?.kerahatActive ?? "Kerahat vakti" }
            let until = (labels?.kerahatUntil ?? "bitiş {time}")
                .replacingOccurrences(of: "{time}", with: clock(end))
            return "\(kerahat) · \(until)"
        }
    }
}
```

`Palette.swift` — `struct Palette` içine `backgroundStops` altına `var isDark = true` (memberwise kurucu sonuna düşer; `light(_:)` içindeki dört `Palette(...)` çağrısına `isDark: false` eklenir). Hesaplanan alanlar:
```swift
    /// `palettes.dart` kerahatLine / kerahatSurface ile birebir; palet bağımsız.
    var kerahatLine: Color { Color(hex: isDark ? 0xA14158 : 0x8D243B) }
    var kerahatSurface: Color { Color(hex: isDark ? 0x3C1F2A : 0xF9E9EC) }

    /// Üst blok ile alt bloğu ayıran çizgi; açık zeminde daha soluk yeter.
    var divider: Color { textSecondary.opacity(isDark ? 0.4 : 0.3) }

    /// Kerahat sürerken zemin bordo tona kayar; tasarımdan örneklenen sabit
    /// duraklar, kerahat renkleri gibi palet bağımsız.
    private var kerahatBackgroundStops: [Color] {
        isDark
            ? [Color(hex: 0x4B1E30), Color(hex: 0x2A1421), Color(hex: 0x150C11)]
            : [Color(hex: 0xE9B9C6), Color(hex: 0xF3D8DF), Color(hex: 0xFAEEF0)]
    }

    func kerahatBackgroundGradient(in size: CGSize) -> RadialGradient {
        Self.gradient(stops: kerahatBackgroundStops, in: size)
    }
```
`backgroundGradient(in:)` gövdesi `Self.gradient(stops: backgroundStops, in: size)` olur; geometri `private static func gradient(stops: [Color], in size: CGSize) -> RadialGradient` içine taşınır (mevcut merkez/yarıçap/duraklar aynen).

- [ ] **Step 5: Testleri çalıştır** — Step 3 komutu — Expected: PASS (KerahatChipLabel 8, DayLabel 5, WidgetAlignment 4).

- [ ] **Step 6: Commit**

```bash
git add ios/WidgetCore ios/RunnerTests ios/EzanVaktiWidget/Theme/Palette.swift ios/EzanVaktiWidget/Configuration/EzanVaktiWidgetIntent.swift ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat(widget): kerahat çip metni, kısa tarih etiketi, kerahat paleti ve ortalı varsayılan hiza"
```

---

### Task 5: iOS görünümler — küçük/orta widget yeni düzeni

**Files:**
- Create: `ios/EzanVaktiWidget/Views/KerahatChip.swift`, `ios/EzanVaktiWidget/Views/WidgetBlocks.swift`
- Delete: `ios/EzanVaktiWidget/Views/KerahatLine.swift`
- Modify: `ios/EzanVaktiWidget/Views/SmallView.swift`, `MediumView.swift`, `PhaseBackground.swift`, `ios/EzanVaktiWidget/EzanVaktiWidget.swift:60-66`

**Interfaces:**
- Consumes: Task 4'ün tamamı; `CountdownLabel(entry:target:size:color:weight:)` (mevcut).
- Produces: `KerahatChip(entry:status:palette:compact:)`, `WidgetHeader(entry:day:palette:alignment:locationLabel:isStale:compact:)`, `WidgetDivider(color:)`, `NextPrayerBlock(entry:next:palette:alignment:isTomorrow:)`, `PhaseBackground(phase:appearance:kerahatActive:)`.

Görünümler `RunnerTests` kapsamında değil; doğrulama build + simülatör önizlemesi. `EzanVaktiWidget` klasörü Xcode'da senkron grup: dosya ekleme/silme pbxproj gerektirmez.

- [ ] **Step 1: `KerahatChip.swift`**

```swift
import SwiftUI

/// Üst bloğun başındaki kerahat şeridi: yaklaşırken çerçeveli, kerahatte dolgulu.
struct KerahatChip: View {
    let entry: PrayerEntry
    let status: KerahatStatus
    let palette: Palette
    var compact = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.horizon")
            Text(KerahatChipLabel.text(
                status: status, compact: compact,
                labels: entry.labels, timeFormat: entry.timeFormat))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(entry.isKerahatActive ? Color.white : palette.kerahat)
        .frame(maxWidth: .infinity)
        .frame(height: 22)
        .background(Capsule().fill(entry.isKerahatActive ? palette.kerahatLine : palette.kerahatSurface))
        .overlay(Capsule().strokeBorder(palette.kerahatLine, lineWidth: 1))
    }
}
```

- [ ] **Step 2: `WidgetBlocks.swift`**

```swift
import SwiftUI

/// Küçük widget'ın ve orta widget'ın sol sütununun ortak parçaları.
/// Sıra: üst blok · çizgi · vakit adı ile saat yan yana · ince sayaç.

/// Üst blok: kerahat yokken tarih, hicri tarih ve konum; kerahat yaklaşırken ya
/// da sürerken çip ve tek satırda kısa tarih ile konum.
struct WidgetHeader: View {
    let entry: PrayerEntry
    let day: SnapshotDay
    let palette: Palette
    let alignment: WidgetAlignment
    let locationLabel: String
    let isStale: Bool
    var compact = true

    private var place: String {
        isStale ? (entry.labels?.stale ?? "Güncel değil") : locationLabel
    }

    var body: some View {
        VStack(alignment: alignment.horizontal, spacing: 1) {
            if let status = entry.kerahat {
                KerahatChip(entry: entry, status: status, palette: palette, compact: compact)
                    .padding(.bottom, 5)
                Text([DayLabel.short(day), place].compactMap { $0 }.joined(separator: " · "))
            } else {
                if let gregorian = DayLabel.gregorian(day) {
                    Text(gregorian)
                }
                if let hijri = day.hijri {
                    Text(hijri)
                }
                Text(place)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(palette.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .multilineTextAlignment(alignment.textAlignment)
        .frame(maxWidth: .infinity, alignment: alignment.frame)
    }
}

/// Üst ve alt bloğu ayıran tam genişlik çizgi.
struct WidgetDivider: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .padding(.top, 7)
            .padding(.bottom, 12)
    }
}

/// Alt blok: vakit adı ile saati yan yana, altında ince geri sayım.
struct NextPrayerBlock: View {
    let entry: PrayerEntry
    let next: PrayerSlot
    let palette: Palette
    let alignment: WidgetAlignment
    let isTomorrow: Bool

    private var name: String {
        (isTomorrow ? "\((entry.labels?.tomorrow ?? "Yarın").uppercased()) · " : "")
            + next.name.uppercased(with: Locale(identifier: "tr_TR"))
    }

    var body: some View {
        VStack(alignment: alignment.horizontal, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(TimeFormatting.clock(next.date, preference: entry.timeFormat))
                    .font(.system(size: 16, weight: .semibold).monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
            }
            CountdownLabel(
                entry: entry, target: next.date, size: 26,
                color: palette.textPrimary, weight: .light)
        }
        .frame(maxWidth: .infinity, alignment: alignment.frame)
    }
}
```

- [ ] **Step 3: `SmallView.ready` gövdesi**

```swift
        let palette = Palette.resolve(entry.appearance, phase: phase, colorScheme: colorScheme)

        return VStack(alignment: alignment.horizontal, spacing: 0) {
            WidgetHeader(
                entry: entry, day: day, palette: palette, alignment: alignment,
                locationLabel: locationLabel, isStale: isStale, compact: true)
            WidgetDivider(color: palette.divider)
            NextPrayerBlock(
                entry: entry, next: next, palette: palette,
                alignment: alignment, isTomorrow: isTomorrow)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(isStale ? 0.55 : 1)
```

- [ ] **Step 4: `MediumView.ready` gövdesi** (`row(slot:next:palette:)` aynen kalır)

```swift
        let palette = Palette.resolve(entry.appearance, phase: phase, colorScheme: colorScheme)
        let slots = NextPrayer.slots(days: [day], calendar: .current)

        return HStack(spacing: 0) {
            // Sol sütun küçük widget'ın aynısı; genişliği sabit ki liste
            // cihazdan cihaza değişen artığı alsın.
            VStack(alignment: alignment.horizontal, spacing: 0) {
                WidgetHeader(
                    entry: entry, day: day, palette: palette, alignment: alignment,
                    locationLabel: locationLabel, isStale: isStale, compact: false)
                WidgetDivider(color: palette.divider)
                NextPrayerBlock(
                    entry: entry, next: next, palette: palette,
                    alignment: alignment, isTomorrow: isTomorrow)
                Spacer(minLength: 0)
            }
            .frame(width: 158)

            Rectangle()
                .fill(palette.textSecondary.opacity(0.2))
                .frame(width: 1)
                .padding(.leading, 14)
                .padding(.trailing, 16)

            VStack(spacing: 0) {
                ForEach(Array(slots.enumerated()), id: \.element.name) { index, slot in
                    if index > 0 { Spacer(minLength: 0) }
                    row(slot: slot, next: next, palette: palette)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(isStale ? 0.55 : 1)
```

- [ ] **Step 5: `PhaseBackground` ve giriş görünümü**

```swift
struct PhaseBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: DayPhase
    let appearance: WidgetAppearance
    var kerahatActive = false

    var body: some View {
        GeometryReader { geometry in
            let palette = Palette.resolve(appearance, phase: phase, colorScheme: colorScheme)
            if kerahatActive {
                palette.kerahatBackgroundGradient(in: geometry.size)
            } else {
                palette.backgroundGradient(in: geometry.size)
            }
        }
    }
}
```
`EzanVaktiWidget.swift`: `PhaseBackground(phase: phase, appearance: entry.appearance, kerahatActive: entry.isKerahatActive)`.

- [ ] **Step 6: `KerahatLine.swift`'i sil** — `git rm ios/EzanVaktiWidget/Views/KerahatLine.swift`.

- [ ] **Step 7: Build ve testler**

Run: `flutter build ios --simulator --debug 2>&1 | tail -5` — Expected: `Built build/ios/iphonesimulator/Runner.app`.
Run: Task 4 Step 3 komutu + `-only-testing:RunnerTests/PrayerTimelineTests` — Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add ios/EzanVaktiWidget
git commit -m "feat(widget): küçük/orta widget yeni düzeni — üst blok, çizgi, vakit adı ile saat yan yana, kerahat çipi ve bordo zemin"
```

---

### Task 6: Kapanış

- [ ] `flutter test` tüm suite PASS; `flutter analyze` temiz; `git status` temiz.
- [ ] Memory notunu güncelle (tasarım uygulandı, cihaz kabulü bekliyor).
- [ ] Rapor: ne değişti, doğrulama çıktıları, test edilmeyen davranış (cihazda widget yenileme zamanlaması, 12 saat + tr ek), varsayımlar.
