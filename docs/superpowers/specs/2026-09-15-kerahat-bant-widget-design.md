# Kerahat bandı ve iOS widget yeni düzeni — tasarım

Tarih: 2026-09-15 · Baz: `dev` (394436c sonrası) · Platform: Flutter (ana ekran) + iOS WidgetKit (küçük/orta widget). Android widget yok.

Kaynak tasarım: [Kerahat Tasarımı canvas'ı](https://claude.ai/artifact/PFLN8WwCFrdyujSLSj9VeY); artboard kaynakları `design/kerahat/`. Renk kararı: **bordo** (canvas'taki `hue: amber` yalnızca deneme, uygulanmaz).

Kerahat altyapısı Tur 7 (§7, `2026-09-10-tur7-…-design.md`) ile kuruldu: `KerahatWarning.resolve` (30 dk önceden `approaching`, aralıkta `active`), snapshot v4 `days[].kerahat`, Swift `KerahatStatus` ve timeline anları. Bu tur **yalnızca sunum katmanını** değiştirir; kural, snapshot şeması ve timeline anları aynen kalır. ADR değişikliği yok (0004 "widget hesap yapmaz" korunur).

## Revizyon — 2026-09-22

Ekrem'in isteğiyle vakit satırı ile sayaç arası daraltıldı (scratchpad `gap/gen.py` mockup'ı; seçim: ortadaki boşluk 18, artan yer üste ve alta eşit). Kural, snapshot şeması ve timeline anları aynı:

- **Widget alt blok, şerit yokken sabit orta boşluk:** `NextPrayerBlock` içinde vakit satırı ile sayaç arasındaki `Spacer` yalnızca `entry.kerahat == nil` iken `NextPrayerBlock.midGap` (18) yüksekliğinde sabitlenir; kalan yüksekliği iki eşit `Spacer` paylaşır, görünen boşluklar ~25/25/25 yerine ~28/18/28 olur. Ölçü yine mürekkepten (`InkInsets` + `inkBounds`). Kerahat şeridi varken üç `Spacer` eşit kalır (~14/14/14) — şerit zaten alanı kısalttığı için dokunulmadı. Küçük widget ve orta widget'ın sol sütunu aynı bloğu kullandığından ikisi birlikte değişir.

## Revizyon — 2026-09-21

Ekrem'in 0.24.0 cihaz geri bildirimiyle ölçü ve metin ayarları (scratchpad `fix_round/gen.py` mockup'ı, onay: "tamam güzel oldu"); kural, snapshot şema sürümü ve timeline anları aynı:

- **Widget alt blok, üç eşit görünen boşluk:** çizgi–vakit satırı, vakit satırı–sayaç, sayaç–alt sınır (kerahat yokken görünen alt kenar, kerahatte şeridin üstü) göze eşit. Ölçü satır kutusundan değil mürekkepten: `InkInsets.system(size:weight:)` (WidgetCore, `UIFont` ascender − capHeight / −descender) ile her metnin kutusu `inkBounds` (negatif padding) altında rakam yüksekliğine iner, kalan yüksekliği `NextPrayerBlock` içindeki üç eşit `Spacer` paylaşır. B2 (`CenteredBelowDivider`) ve sabit 8 aralık kalktı; kutudan ölçülünce 27/18/29 görünüyordu, şimdi ~25/25/25 (kerahatte ~16/16/16). `HomeContentInsets(bottom:)`: hazır içerikte 0, mesajlarda 12; orta boyda liste ve ayraç her durumda 12 alt pay.
- **Widget şeridi:** yazı 13 → 15 (`KerahatRibbon.fontSize`), yükseklik 26 → 32 (0.25.0 cihaz geri bildirimi "biraz daha yüksek", seçenek B; alt blok boşlukları ~14'e iner). Yaklaşırken kelime **"Kerahate"** (`labels.kerahatSoon`, yoksa Türkçe varsayılan), kerahatte "Kerahat": `KerahatRibbonLabel.text(labels:status:)`.
- **Snapshot etiketi:** `labels.kerahatSoon` (Dart `WidgetLabels.kerahatSoon`, ARB `widgetKerahatSoon`); şema sürümü 4 aynı, eski widget alanı yok sayar, eski uygulama göndermezse widget Türkçe varsayılana düşer.
- **Kilit ekranı (`RectangularView`):** vakit satırı 15 → 17, sayaçla arası 1 → 4.
- **Ana ekran üst satır:** etiket `heroLabel` 13 → 14 (aralık 2.8), saat 16 aynı; dört parça ortak `AppTypography.heroStrut` (16, `forceStrutHeight`) alır ki `Wrap` içinde kutuları eşitlenip etiket saatin taban çizgisine otursun — ortalanınca etiket yukarıda duruyordu.
- **Ana ekran bandı yaklaşırken:** kelime **"Kerahate"** (`kerahatSoonBandLabel`), çubuk yok, dikey pay 11/11 (bant ~12 pt kısalır; kerahat başlayınca alttaki cetvel o kadar iner). Kerahatte bant aynen: "Kerahat", çubuk aralığın geçen kısmı. `KerahatBand.approachingProgress` silindi.
- Çeviriler: EN "Disliked time in", AR "حتى وقت الكراهة" (her iki anahtar).

## Revizyon — 2026-09-20 (akşam)

Ekrem'in mockup turlarıyla (scratchpad `band_bottom/`: `gen_home.py`, `gen_widget2.py`, `gen_final.py`) yerleşim değişti; kural, snapshot şeması ve timeline anları yine aynı:

- **Ana ekran, bant sayacın altında:** `CountdownHero` → `[sayaç bloğu, 20, KerahatBand]`; parıltı sayaçla birlikte. Bantta "Kerahat" ve dk:sn sayaç **aynı punto, 20** (`AppTypography.kerahatBandLabel` w600 / `kerahatBandValue` w700 tabular), ikon 22.
- **Ana ekran, tek satır etiket:** sayacın altındaki "Akşam vakti 19:23" kalktı (`prayerTimeAt` anahtarı ve `timeCaptionName` silindi). Üstte `SONRAKİ  AKŞAM · 19:23`: etiketler `heroLabel` (13 w800, aralık 2.6), saat `heroTime` (16 w800 tabular), ayraç `textTertiary`; saat ve vakit adı vurgu (kerahatte kerahat) renginde. Ramazan'da `SONRAKİ  İFTARA · 19:23`.
- **Widget, kerahat şeridi en altta:** üst bloktaki kapsül (`KerahatChip`) kalktı; tarih **her durumda üç satır**. Kerahat bilgisi widget'ın alt kenarına dayanan tam genişlik şerit (`KerahatRibbon`, 13 pt, 26 yüksek): yaklaşırken `kerahatSoonSurface` zemin + üstte 1 pt `kerahatSoonLine` + `kerahatSoonText`; kerahatte `kerahatLine` dolgu + beyaz. Köşeleri widget'ın kendi yuvarlağı kırpar. Orta boyda şerit iki sütunun altında tam genişliktir; liste ve ayraç şeridin üstünde 12 pt pay bırakır.
- **Widget kenar payı:** `contentMarginsDisabled()`; ana ekran aileleri `HomeContentInsets` ile üstte 12, yatayda sistemin `widgetContentMargins` değeri, altta kerahat yokken 12 / kerahatte 0 (şerit bitişik). Kilit ekranı sistem değerini `.padding(widgetContentMargins)` ile aynen alır. Gerekçe: sistemin 16'sı üç satır tarih + çizgi + vakit satırı + 26 pt sayaç + şeridi sığdırmıyordu.
- **Widget alt blok:** kerahat yokken çizgi ile *görünen* alt kenar arasında ortalı (B2; üstten `WidgetInsets.vertical` pay), kerahatte çizgi ile şerit arasında ortalı (pay yok). Vakit satırı–sayaç aralığı 8 aynı.
- `KerahatChipLabel` → `KerahatRibbonLabel` (WidgetCore + RunnerTests); içerik aynı.

## Revizyon — 2026-09-19

Ekrem'in cihaz geri bildirimiyle sunum sadeleşti; yerleşim, timeline anları ve payload şeması (v4) aynı kaldı:

- **Metin tek kelime:** bant ve çip yalnız "Kerahat" yazar; başlangıç saati, "vakti", "bitiş {time}" ve Türkçe bulunma eki kalktı (`kerahatStartsAt`, `kerahatActiveLine`, `widgetKerahatActive`, `widgetKerahatUntil`, `turkish_suffix.dart` silindi; yeni anahtar `kerahatBandLabel`).
- **Canlı sayaç:** kelimenin yanında dk:sn sayaç — yaklaşırken başlangıca, kerahatte bitişe. Ana ekranda `formatMinutesSeconds` ile saniyelik tik (`CountdownHero` zaten tikliyor); widget'ta `Text(timerInterval:)` (yenileme gerekmez). Büyük sayaç değişmedi: sıradaki vakte sayar.
- **Bant düzeni:** ortalı tek satır ikon · Kerahat · sayaç; altında çubuk aynı.
- **Renk:** yaklaşırken turuncu aile (`kerahatSoonLine/Surface/Text`; koyu `#E0832E` / `#3B2412` / `#FFB45C`, açık `#C9681C` / `#FDEFE1` / `#A9540E`), kerahatte bordo dolgu aynen. Cetvel ve büyük sayaç bordo kalır.
- **Widget alt blok:** çizgi ile alt kenar arasında dikeyde ortalı (altta boş şerit kalıyordu).
- **Widget alt blok, 2026-09-20 (B2):** üst blok yukarıda kalır; alt blok çizgi ile widget'ın *görünen* alt kenarı arasında ortalı — içerik alanı sistem kenar boşluğunda bittiğinden blok o boşluk kadar üstten pay alır (`widgetContentMargins`). Vakit satırı ile sayaç arası 8 pt (bitişik duruyordu). Küçük ve orta aynı; liste değişmedi.
- Çip metni artık `KerahatChipLabel.text(labels:)` + `countdownTarget(status:)`; `compact` ayrımı kalktı. Not: akşam ve öğle kerahatinde bitiş sıradaki vakit olduğundan çip/bant sayacı ile büyük sayaç aynı değeri gösterir; yalnız sabah kerahatinde ayrışır.

Aşağıdaki bölümler 15 Eylül tasarımını anlatır; çelişen yerlerde bu revizyon geçerlidir.

## 1. Ana ekran — kerahat bandı

### Yerleşim

Tarih satırının altında, içerik genişliğinde (390 − 2×20) tek bant. Bant `CountdownHero`'nun içinde çizilir (tek saat kaynağı, saniyelik tik zaten orada): `Column(crossAxisAlignment: stretch)` → `[KerahatBand, 20px, sayaç bloğu]`. Kerahat yoksa bant yok, sayaç bugünkü yerinde. Bugünkü `_withSoonLine` (sayaç altı hap) ve `_activeCard` (bordo kart) kaldırılır.

### `KerahatBand` (`lib/presentation/widgets/home/kerahat_band.dart`)

Girdi: `KerahatStatus status`, `DateTime now`. Radius 14, padding `12 16 10`, içerik: satır (ikon 16 `wb_twilight_rounded` · metin 13/w600 tabular, tek satır ellipsis · sağda kalan süre 12/w700 tabular) + 8px + 4px ilerleme çubuğu (radius 2).

| | Yaklaşırken (`KerahatApproaching`) | Kerahatte (`KerahatActive`) |
|---|---|---|
| Zemin / çerçeve | `kerahatSurface` / 1px `kerahatLine` | `kerahatLine` dolgu, gölge `kerahatLine` α.35 blur 28 offset (0,6) |
| Metin rengi | `kerahatText` | beyaz |
| Metin | `kerahatStartsAt(time, suffix)` → "Kerahat 18:38'de başlar" | `kerahatActiveLine(time)` → "Kerahat vakti · bitiş 19:23" |
| Sağ | `formatCompactDuration(start − now)` → "14 dk" | `formatCompactDuration(end − now)` → "33 dk" |
| Çubuk dolgu / yatak | `kerahatText` / `kerahatText` α.16 | beyaz α.85 / siyah α.20 |
| Çubuk oranı | `(lead − (start − now)) / lead` (30 dk penceresinin geçen kısmı) | `(now − start) / (end − start)` |

Oranlar `0..1` kırpılır. Metin `Semantics(liveRegion)`. Anahtarlar: `Key('kerahat_band')`, `Key('kerahat_band_fill')`.

### Sayaç ve parıltı

- `active`: `SONRAKİ · AKŞAM` etiketi ve sayaç `kerahatText` (bugünkü davranış); hedef sıradaki vakit (değişmez).
- `active`: sayaç bloğunun arkasında radial parıltı — `Stack(clipBehavior: none)` + `Positioned(top −60, bottom −80, left −40, right −40)`, `RadialGradient(center (0, −0.1), radius 0.9, stops [0, .45, .78])`, renkler `kerahatGlow` → α ×1, ×0.47, ×0.
- Yeni token `AppTokens.kerahatGlow`: koyu `kerahatLine` α.34, açık α.16 (palet bağımsız, diğer kerahat token'ları gibi `palettes.dart` sabitleri). `copyWith`/`lerp`/`toString` güncellenir.
- Cetvel değişmez: kerahat parçaları zaten `kerahatLine`.

### Lokalizasyon

- Yeni: `kerahatStartsAt` (tr `"Kerahat {time} başlar"`, en `"Disliked time starts at {time}"`, ar `"يبدأ وقت الكراهة عند {time}"`), `kerahatActiveLine` (tr `"Kerahat vakti · bitiş {time}"`, en `"Disliked time · until {time}"`, ar `"وقت الكراهة · حتى {time}"`).
- Kaldırıldı: `kerahatSoonLine`, `kerahatActiveTitle`, `kerahatEndsAt` (yalnız `countdown_hero.dart` kullanıyordu).
- **Türkçe bulunma eki**: saat okunuşunun son kelimesine göre (`turkishLocativeSuffix(hour, minute)` → `'de | 'da | 'te | 'ta`, `lib/core/utils/turkish_suffix.dart`, saf). Dakika > 0 ise dakika, değilse saat belirler; birler basamağı sıfır değilse birler (bir/iki/yedi/sekiz → de, üç/dört/beş → te, altı/dokuz → da), sıfırsa onlar (on/otuz/sıfır → da, yirmi/elli → de, kırk → ta). Ek mesaja değil `{time}` değerine eklenir ve yalnız `tr` locale'inde (`KerahatBand._startLabel`): ARB yer tutucuları her dilde aynı kalmalı (`arb_consistency_test`). 12 saatlik biçimde ek "PM" sonrasına düşer ("6:38 PM'de"); tr + 12 saat nadir, kabul edilen bedel.

### Testler (Dart)

`countdown_hero_test.dart` yeni davranışa göre güncellenir: yaklaşırken bant metni/sağ değer/dolgu oranı ve `kerahatText`; 31 dk kala bant yok; kerahatte bant `kerahatLine` zeminli, beyaz metin, sayaç `kerahatText`, bant sayacın üstünde; bitişte bant gider ve sayaç `accent`; 2× metin ölçeğinde (tr/ar) taşma yok. `turkish_suffix_test.dart`: 18:38→'de, 19:23→'te, 18:40→'ta, 18:30→'da, 13:00→'te, 10:00→'da, 00:00→'da, 18:46→'da.

## 2. iOS widget — küçük ve orta

### Ortak düzen (sol blok)

Sistem kenar boşlukları korunur (iOS 17 `containerBackground`, ek padding yok). Dikey sıra:

1. **Üst blok** — kerahat yokken üç satır 12pt regular `textSecondary`, `spacing 1`: `DayLabel.gregorian(day)` ("Pazartesi, 14 Eylül" — biçim zaten `EEEE, d MMMM`, **yıl yok**), `day.hijri` ("3 Rebiülahir 1448", aynen), konum/`stale`. Kerahat yaklaşırken/aktifken: `KerahatChip` + 6pt + tek satır `DayLabel.short(day)` ("14 Eylül") + " · " + konum.
2. **Çizgi** — 1pt, `palette.divider` (`textSecondary` α.40 koyu / α.30 açık), üstte 7pt, altta 12pt boşluk; tam genişlik.
3. **Alt blok** — `HStack(firstTextBaseline, spacing 6)`: vakit adı 11pt semibold `accent` (büyük harf, `isTomorrow` ise "YARIN · " öneki) · saat 16pt semibold `textPrimary`; altında `CountdownLabel(size 26, weight .light, textPrimary)`. Kalan alan boş (`Spacer`).

Hizalama (`WidgetAlignment`) üst ve alt blokların metin hizasını belirler; çizgi ve çip her zaman tam genişlik. Tasarım ortalı olduğu için `WidgetAlignment.default` `.leading` → `.center` olur (intent parametresini elle değiştirmiş kullanıcılar etkilenmez).

### `KerahatChip` (`ios/EzanVaktiWidget/Views/KerahatChip.swift`, `KerahatLine.swift` silinir)

Kapsül, yükseklik 22, tam genişlik, içerik ortalı: `Image(systemName: "sun.horizon")` 11pt + metin 11pt semibold, `lineLimit 1`, `minimumScaleFactor 0.7`.

| | Yaklaşırken | Kerahatte |
|---|---|---|
| Zemin / çerçeve / metin | `kerahatSurface` / 1pt `kerahatLine` / `kerahat` | `kerahatLine` / — / beyaz |
| Küçük | `kerahat` + " " + saat → "Kerahat 18:38" | `kerahatActive` → "Kerahat vakti" |
| Orta | aynı ("Kerahat 18:38") | `kerahat` + " · " + `kerahatUntil` → "Kerahat · bitiş 19:23" |

Canlı dakika yok (widget dakikada bir yenilenemez); timeline anları (`start − 30 dk`, `start`, `end`) yeterli. Metin bileşimi `WidgetCore/KerahatChipLabel.swift` içinde saf fonksiyon (`KerahatChipLabel.text(status:compact:labels:timeFormat:)`, `compact` = küçük widget) — test edilebilir. Tasarımdaki orta boy "Kerahat 18:38'de" metni **bilinçli sapma** ile eksiz: bulunma ekini Swift'te üretmek ya da snapshot'a saat başına etiket taşımak, kazandırdığı iki karaktere değmez.

### Orta widget

`HStack(spacing 0)`: sol blok `frame(width: 158)` (küçük widget içeriğiyle aynı) · 14pt · 1pt dikey çizgi (`textSecondary` α.20, dikeyde 0 ek boşluk) · 16pt · vakit listesi (`maxWidth ∞`, satırlar arasında `Spacer` — bugünkü davranış, yalnız sütun genişledi). Satır stilleri değişmez (sıradaki `accent` semibold, geçmiş `textSecondary` α.5, gelecek `textPrimary`).

### Zemin

`PhaseBackground` `.active` kerahatte bordo duraklara geçer (palet bağımsız sabitler, uygulamanın kerahat token'ları gibi): koyu `[#4B1E30, #2A1421, #150C11]`, açık `[#E9B9C6, #F3D8DF, #FAEEF0]`; geometri aynı (`backgroundGradient` ile ortak yardımcı). Yaklaşırken zemin değişmez.

### Palet

`Palette`'e eklenir: `kerahatLine` (koyu `#A14158`, açık `#8D243B`), `kerahatSurface` (koyu `#3C1F2A`, açık `#F9E9EC`), `divider`. Mevcut `kerahat` (metin) kalır. Değerler `palettes.dart` ile birebir.

### Testler (Swift, `RunnerTests`)

`DayLabelTests`: `short` → "14 Eylül". `KerahatChipLabelTests`: dört bileşim + etiket yokken Türkçe varsayılanlar + 12 saat biçimi. `WidgetAlignmentTests`: varsayılan `.center`. `PrayerTimelineTests` değişmez.

### Kilit ekranı

Değişmez; "yalnız sıradaki vakit, dikeyde ortalı" 394436c ile kodda.

## 3. Kapsam dışı

Amber tonu; snapshot şeması (v4 yeterli); kerahat ayrıntı sayfası (`kerahat_details_sheet.dart`); Android widget; kerahat bildirimi; ana ekranda kerahat yokken görünüm (bugünkü gibi).

## 4. Doğrulama

- Dart: `dart format`, `flutter gen-l10n`, `flutter analyze`, `flutter test`.
- iOS: `flutter build ios --simulator --debug`; `xcodebuild test -only-testing:RunnerTests/DayLabelTests -only-testing:RunnerTests/KerahatChipLabelTests -only-testing:RunnerTests/WidgetAlignmentTests -only-testing:RunnerTests/PrayerTimelineTests` (simülatör).
- Android: native değişmedi; `flutter build apk --debug` çalıştırılmaz.
- Unit/widget testleri widget'ın cihazda doğru anda yenilendiğini kanıtlamaz; cihaz kabulü Ekrem'de: 18:08–18:38 arası bant ve çip "yaklaşırken", 18:38–19:23 arası "kerahatte" (bordo zemin, sayaç rengi), 19:23'te normal görünüm.
