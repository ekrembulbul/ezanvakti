# 0.3.0 Yeniden Tasarım — Uygulama Planı

Kaynak: `design/Ezan Vakti - Son Tasarim.html` (tasarım kanvası export'u).
Bu doküman, o dosyadan çıkarılan **karar verilen sistemi** ve uygulama sırasını
tanımlar. Ürün sınırları için [PRODUCT_SPEC.md](PRODUCT_SPEC.md), genel yol
haritası için [ROADMAP.md](ROADMAP.md).

> Tasarım dosyası tek satırlık gömülü HTML + base64 varlıklar içerir; token'lar
> inline style olarak durur. Aşağıdaki değerler o markup'tan birebir okundu.

## Alınan kararlar

| Konu | Karar | Gerekçe |
|---|---|---|
| Uygulama ikonu | **iOS'ta 4 varyant, Android'de tek sabit ikon** | Android'de launcher ikonunu çalışma zamanında değiştirmek `activity-alias` gerektirir; uygulama launcher'dan kaybolup yeniden görünür ve kullanıcının ana ekran kısayolu kırılır. iOS'ta `setAlternateIconName` temiz çalışır. |
| Kapsam | **Önce görsel (Faz 1–3), yeni davranışlar sonra (Faz 4)** | Sessiz saatler ve "SIRADAKİ" kartı scheduler'a dokunuyor; görsel turdan ayrı tutulunca risk düşüyor. |
| Tipografi | **Manrope gömülü, 4 ağırlık (500/600/700/800)** | Uygulama offline-first; `google_fonts` runtime indirmesi uygun değil. ~400 KB bundle artışı kabul edildi. |

---

## Tasarım sistemi

### Kurallar

- **Tek yüzey seviyesi.** Koyu temada `white %5`, açık temada `#FFFFFF`.
  **Kart içinde kart yok** — gruplar ayıraçla (`divider`) bölünür.
- **Yarıçap:** 16 (grup/kart) · 12 (alan/çip) · 999 (pill).
- **Tipografi (Manrope):** sayaç 62 w800 (`ls -.045em`), ekran başlığı 17 w800,
  satır 17 w600, bölüm etiketi 11 w800 (`ls +.16em`, uppercase). Taban 11px.
  **Saatlerde tabular figures** zorunlu.
- **Sekme:** ortak yatak 52 / r26 (padding 4) + kayan pill 42 / r21, kenarlık
  içte. Geçiş **220 ms `easeOutCubic`**. Aynı bileşen üç yerde kullanılır:
  alt gezinme, alarm türü, tema seçimi.
- **Vurgu yalnızca iki iş yapar:** vakit bilgisi ve tek birincil eylem.
  Uyarı, seçim ve pasif durumlar nötr kalır.
- En düşük metin kontrastı **5.1:1** (her palet ayrı denetlendi).

### Vakte göre palet

Zemin, vurgu ve (iOS'ta) uygulama ikonu birlikte kayar. Vurgu her zaman zeminin
hue ailesinde kalır. Geçiş vakit girişinde **20 dakikada** tamamlanır.

Dilim sınırları — **gece Akşam'da değil Yatsı'da başlar** (akşam ezanı ile yatsı
arasında gökyüzü hâlâ aydınlık):

| Dilim | Aralık |
|---|---|
| Sabah | İmsak → Öğle |
| Öğle sonrası | Öğle → İkindi |
| Akşam | İkindi → **Yatsı** |
| Gece | Yatsı → İmsak |

#### Koyu tema

| Dilim | Ad | Vurgu | Zemin (radial 125% 58% @ 70% -4%) | Metin 1 | Metin 2 | Metin 3 | Değer |
|---|---|---|---|---|---|---|---|
| Sabah | ÇİVİT | `#93C4E8` | `#2C5279` → `#143049` → `#08141F` | `#E8F0F8` | `#A5BDD2` | `#8DA8C2` | `#C4D7E8` |
| Öğle sonrası | KURŞUNİ | `#D8E8EE` | `#40525C` → `#202C33` → `#10171B` | `#F0F5F7` | `#AFC3CB` | `#98AEB7` | `#CDDCE2` |
| Akşam | ERGUVAN | `#E09FB8` | `#4A2144` → `#241634` → `#120E1B` | `#F3EEF4` | `#B5A8C1` | `#A294AF` | `#CFC3D6` |
| Gece | SÜMBÜL | `#CDA6E4` | `#2A2038` → `#17111F` → `#0A080E` | `#F2ECF6` | `#B3A5C1` | `#9D8FAB` | `#D5C9DF` |

#### Açık tema

| Dilim | Ad | Vurgu | Zemin | Metin 1 | Metin 2 | Metin 3 | Değer |
|---|---|---|---|---|---|---|---|
| Sabah | NİLÜFER | `#265F8E` | `#DCE9F7` → `#EDF3FA` → `#F8FBFD` | `#0E1D2C` | `#43596D` | `#53697C` | `#33495E` |
| Öğle sonrası | SEDEF | `#2A5B68` | `#E2ECF0` → `#F1F6F8` → `#F9FCFC` | `#0F1C21` | `#435A62` | `#536A72` | `#334A52` |
| Akşam | GÜLKURUSU | `#9E4266` | `#F7E7EB` → `#FAF2F4` → `#FDFAFA` | `#201A1E` | `#5A4A50` | `#6B5A60` | `#4A3B41` |
| Gece | LEYLAK | `#5E3A80` | `#EBE4F1` → `#F7F4F9` → `#FCFBFD` | `#1A1424` | `#4F4260` | `#5F5270` | `#3F3350` |

**Metin rolleri:** Metin 1 = başlık/birincil, Metin 2 = ikincil, Metin 3 = etiket
(11px bölüm başlıkları, pasif sekme), Değer = liste içindeki saat değerleri.

### Uygulama ikonu

Hilal iki daireden oluşur (biri diğerini keser), yanında tek yıldız. Mevcut
ikondaki cami silueti kaldırıldı — 40px'te okunmuyordu. Zemin ve hilal, o anki
paletin zemini ve vurgusudur.

Dört 512×512 PNG tasarım dosyasında gömülü. Çıkarmak için:

```bash
python3 -c "
import json, pathlib, base64
p = pathlib.Path('design/Ezan Vakti - Son Tasarim.html')
assets = json.loads(p.read_text(errors='replace').splitlines()[384])
out = pathlib.Path('assets/icon'); out.mkdir(parents=True, exist_ok=True)
for k, v in assets.items():
    if v.get('mime') == 'image/png':
        (out / f'{k[:8]}.png').write_bytes(base64.b64decode(v['data']))
"
```

---

## Uygulama planı

### Faz 1 — Tema altyapısı

En kritik ve en riskli adım. Mevcut durum ölçüldü: **29 dosya, 209 `AppTheme.*`
referansı, 238 hardcoded `Colors.white/black`** — hepsi tek bir statik koyu tema
varsayıyor. Açık tema + 4 palet bunun üzerine oturmaz, önce zemin atılmalı.

- `lib/core/theme/app_tokens.dart` — `ThemeExtension<AppTokens>`:
  `surface`, `border`, `divider`, `textPrimary/Secondary/Tertiary`, `textValue`,
  `accent`, `accentSoft`, `bgGradient`. `lerp` implementasyonu 20 dakikalık
  yumuşak geçişi bedavaya getirir.
- `lib/core/theme/palettes.dart` — yukarıdaki 8 palet sabiti.
- `lib/core/theme/day_phase.dart` — `DayPhase.resolve(PrayerTime, DateTime)`
  saf fonksiyon. **Birim test zorunlu:** Yatsı sınırı, gece sarması (Yatsı→İmsak
  ertesi güne taşar), vakit verisi yokken fallback.
- `lib/core/theme/theme_controller.dart` — `ChangeNotifier`; `themeMode`
  (koyu/açık/sistem) ve `timeBasedColor` ayarlarını `LocalStorage`'a persist
  eder, aktif paleti hesaplar.
- `AppTheme`'i tokenlardan `ThemeData` üreten yapıya çevir; eski statikleri sil.
- `assets/fonts/` altına Manrope 500/600/700/800; `pubspec.yaml` font tanımı.

> Bu fazda ekran görünümü **kasten değişmez** — hedef, mevcut görünümü token'lar
> üzerinden yeniden üretmek. Regresyonu ekran görüntüsü testiyle karşılaştır.

### Faz 2 — Ortak bileşenler

- `SlidingSegment` — kayan pill; alt gezinme, alarm türü ve tema seçimi aynı
  widget'ı kullanır (52/r26 yatak + 42/r21 pill, 220ms easeOutCubic).
- `SectionLabel` — 11 w800, `ls +.16em`, uppercase.
- `GroupedList` + `RowDivider` — ayıraçlı grup (r16, `margin-left` ile ikon
  hizasından başlayan ayıraç).
- `AppScaffold` — radial gradient zemin + şeffaf app bar.
- `TextTheme` ölçeği; saat gösterimleri için tabular figures yardımcısı.

### Faz 3 — Ekranlar

Her ekran bitince `integration_test` ile görüntü alınıp tasarımla karşılaştırılır.

1. **Ana ekran** — en büyük değişiklik: ortalanmış sayaç (62 w800) ve tarih,
   gün cetveli (5px şerit + vakit çentikleri + şu anki saat göstergesi),
   6 kolonluk vakit ızgarası (kolon genişliğinde 3px gösterge barı),
   "YARIN" şeridi (yarının 6 vakti + Takvim kısayolu), "SIRADAKİ" kartı için
   yer ayrılır (içerik Faz 4), kayan pill alt gezinme.
2. **Alarmlar** + **Alarm ekle** — grup listesi, "N ALARM" bölüm etiketi,
   swipe-to-delete, kayan segment (Sabit saat / Vakte göre),
   SAAT / TEKRAR / DETAY bölümleri.
3. **Bildirimler** — grup listesi, swipe-to-delete, alt bilgi satırı.
4. **Takvim** — kart listesi yerine **tablo düzeni**: vakit kolonları,
   BUGÜN / ŞİMDİ işaretleri.
5. **Ayarlar** — GENEL / GÖRÜNÜM / BİLGİ bölümleri; GÖRÜNÜM'de tema seçici
   (3'lü kayan segment) + "Vakte göre renk" anahtarı ve palet önizlemesi.
6. **Konum ekranları** — aynı sistemle hizala (ekle / liste / düzenle).

### Faz 4 — Yeni davranışlar (görsel tur bittikten sonra)

- **Sessiz saatler** — "Yatsıdan sonra sustur"; model + `NotificationScheduler`
  entegrasyonu.
- **"SIRADAKİ" kartı** — sıradaki bildirim ve sıradaki alarm, geri sayımlı.
- **Alarm canlı önizlemesi** — "Bu alarm 03:39'da çalacak (yarın, İmsak 04:09)".
- **iOS alternate app icon** — palete göre 4 varyant; native channel +
  `Info.plist` `CFBundleAlternateIcons`. Android tek sabit ikonla kalır.

### Faz 5 — Doğrulama ve sürüm

- Ekran görüntüsü testini **8 kombinasyona** genişlet (4 palet × koyu/açık).
  `DayPhase`'i test için enjekte edilebilir yap ki saat beklemeden palet
  zorlanabilsin.
- Kontrast denetimi: her palette metin rampaları ≥ 4.5:1, sayaç ≥ 5.1:1.
- `CHANGELOG.md` 0.3.0 + sürüm yükseltme.

### Faz 6 — Önceki turdan açık kalan küçük işler

Redesign'dan bağımsız, birikmiş teknik borç. Faz 1'e başlamadan **önce**
kapatılması tercih edilir; hepsi küçük ve dosyaları redesign'la çakışıyor.

- **`SwitchListTile` ink uyarısı** — `location_edit_screen.dart:253`,
  `SwitchListTile` arka plan rengi olan bir `Container` içinde; Flutter
  *"ListTile background color or ink splashes may be invisible"* assertion'ı
  atıyor. Ripple görünmüyor ve **o ekrana uğrayan her integration test düşüyor**.
  Çözüm: `SwitchListTile`'ı kendi `Material`'ına sar ya da rengi tile'a taşı.
  (Faz 3.6'da o ekran zaten elden geçecek — orada birlikte düzeltilebilir.)
- **GPS konum değişim konsolidasyonu** —
  `presentation/controllers/location_monitor_controller.dart:35` hâlâ doğrudan
  `locationRepository.setActiveLocation` çağırıyor. Manuel yol domain
  `LocationService.changeLocation`'a indirildi; GPS canlı akış yolu da aynı
  kanonik yola delege edilmeli. (bkz. ROADMAP "Açık kalanlar")
- **MVP kabul testleri** — `PLAN_CHECKLIST.md:79` tek işaretsiz madde: uçtan uca
  senaryolar (online/offline, konum değişimi, izin yok). Artık `integration_test`
  altyapısı mevcut, bu testler oraya yazılabilir.

---

## Açık riskler

- **Faz 1 geniş yüzeye dokunuyor.** 209 referansın mekanik dönüşümü sırasında
  görsel regresyon riski var; bu yüzden Faz 1'in çıktısı "görünüm değişmedi"
  olmalı ve ekran görüntüleriyle kanıtlanmalı.
- **Palet geçişi ile veri yükleme yarışı.** Vakit verisi gelmeden `DayPhase`
  hesaplanamaz; ilk frame'de tanımlı bir fallback palet (Gece) kullanılmalı,
  veri gelince yumuşak geçiş yapılmalı.
- **Açık tema denetlenmemiş yüzeyler.** 238 hardcoded `Colors.white*` çağrısının
  bir kısmı açık temada okunmaz hale gelecek; ekran ekran denetlenmeli.
