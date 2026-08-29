# iOS Widget — İkinci Tur Tasarım Spec'i

0.5.0'daki widget cihazda kullanıldı; bu spec oradan gelen düzeltmeleri ve
eklemeleri tanımlar. [İlk tur tasarımının](2026-08-25-ios-widget-design.md)
eki niteliğindedir: orada alınan D3, D4, D12 ve D14 kararlarını değiştirir,
geri kalanı olduğu gibi geçerlidir.

## 1. Sorun

Cihaz kullanımı üç sınıf sorun ortaya çıkardı:

- **Bozuk davranış:** Always-On ekranda geri sayım okunmaz bir biçime düşüyor;
  orta boy widget iki farklı günü aynı anda gösteriyor.
- **Zayıf tasarım:** her iki boyutta da alt tarafta ölü alan kalıyor, geri
  sayım — widget'ın asıl işi — küçük ve silik duruyor.
- **Eksik özellik:** hizalama seçeneği ve tarih yok.

## 2. Cihaz ölçümleri

iPhone 17, iOS 26. Gözlemler kullanıcı testinden; kod referansları doğrulandı.

| # | Bulgu | Kaynak |
|---|---|---|
| M1 | Ekran **açıkken** geri sayım doğru çalışıyor: `5:34:42`, saniye canlı akıyor | Ana ekran ve uyanık kilit ekranı |
| M2 | **Always-On** ekranda aynı metin `5 hours 51 minutes` olarak çiziliyor | Sönük kilit ekranı |
| M3 | Medium'da sol sütun **yarının** İmsak'ını (04:38), sağ sütun **bugünün** İmsak'ını (04:37) gösteriyor | `MediumView.swift:37` — gün `entry.date`'e göre seçiliyor, sıradaki vakte göre değil |
| M4 | Sağ sütunda hiçbir satır vurgulu değil, altısı da soluk | M3'ün sonucu: `next` listede bulunamıyor, `isPast` hepsi için doğru |
| M5 | Açık tema + gece dilimi, 4x2 kutuda düz beyaz kart gibi okunuyor | `Palette.swift` LEYLAK açık: `#EBE4F1 → #FCFBFD` |
| M6 | `ezanvakti://` şeması `Info.plist`'te tanımlı **değil**, Dart tarafında da işlenmiyor | `EzanVaktiWidget.swift` `widgetURL` çağrısı |
| M7 | Uygulama hicri tarihi `hijri` paketiyle hesaplıyor | `hijri_formatter.dart:7` |

M2 bu turun taşıyıcı bulgusu: sistemin çizdiği sayaç (`Text(date, style: .timer)`)
biçimini Always-On'da kendi kararına göre değiştiriyor ve buna müdahale
edilemiyor.

M7 önemli çünkü iOS'un kendi hicri takvimi (`islamicUmmAlQura`) `hijri`
paketinden gün kayabilir; widget'ın uygulamadan farklı tarih göstermesi kabul
edilemez.

## 3. Alınan kararlar

Numaralandırma ilk turdan devam eder.

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D19 | Geri sayım çizimi | **Hibrit.** Ekran açıkken sistem çizer; `isLuminanceReduced` doğruyken (Always-On) biz çizeriz | M1 + M2: sistem yalnızca sönük ekranda bozuluyor. Her yerde kendimiz çizmek, çalışan canlı saniyeyi de feda etmek olurdu |
| D20 | Kendi çizimimizin biçimi | Sistemle **aynı**: sıfır dolgusu yok, saniye yerine tire — `5:34:--` | Kullanıcı kararı: iki mod arasında geçerken biçim değişmemeli. Saniye tamamen atılmıyor ki gözün alıştığı şekil korunsun |
| D21 | Timeline yoğunluğu | **Dakika başına giriş.** ~2 saatlik pencere, sonra yenileme. **D12 ve D14 iptal** | Kendi çizdiğimiz sayının doğru olması için tek yol. Widget görünümleri önceden çiziliyor; `Date()` render anında değil, hazırlama anında okunur |
| D22 | Yenileme bütçesi | 2 saatlik pencere ≈ 120 giriş, günde ~12 yenileme | Girişler bütçe harcamaz, yenilemeler harcar. 12/gün, gözlenen tavanların çok altında |
| D23 | Hizalama | Sol/orta/sağ, **widget ayarı** olarak. `StaticConfiguration` → `AppIntentConfiguration`. **D4 genişler** | Galeriye üç kopya koymak yerine iOS'un standart "Widget'ı Düzenle" akışı. D4'ün konum kararı değişmiyor: konum hâlâ aktif konumu izler |
| D24 | Hizalamanın kapsamı | Yalnızca `systemSmall` ve `systemMedium` | Kullanıcı kararı. Kilit ekranı ailelerinde yerleşimi sistem dayatıyor, ayarın görünür etkisi olmazdı |
| D25 | `accessoryInline` | **Kaldırılır.** **D3 daralır** | Kullanıcı kararı. Tek satır, tek renk; bu turdaki iyileştirmelerin hiçbiri oraya uygulanamıyor ve kullanıcı özelliği istemiyor |
| D26 | Dikdörtgen kilit ekranı | "SIRADAKİ" satırı kalkar, geri sayım büyür | Etiket bilgi taşımıyor; yerini widget'ın asıl işine bırakıyor |
| D27 | Bilgi hiyerarşisi | Tarih ve konum **üstte ve küçük**; vakit adı, saati ve geri sayım **altta ve baskın** | Kullanıcı kararı: "asıl önemli olan ezan saati ve geri sayım" |
| D28 | Medium'un gün seçimi | Liste, **sıradaki vaktin gününü** gösterir | M3/M4'ün düzeltmesi. İki sütun aynı güne bakar ve vurgulanan satır her zaman listede bulunur |
| D29 | Gün ibaresi | Sıradaki vakit ertesi güne aitse **YARIN** yazılır | Şu an 04:38'in hangi güne ait olduğu hiçbir yerde yazmıyor |
| D30 | Hicri tarih | **Payload'dan gelir**, her gün için ayrı alan | M7. Swift'te hesaplamak widget ile uygulamanın farklı tarih göstermesi riskini doğurur |
| D31 | Gün adı ve miladi tarih | **Swift'te** biçimlendirilir, `tr_TR` zorlanır | Takvim kayması riski yok; payload'ı şişirmeye gerek yok. Locale zorlaması büyük harf dönüşümündeki kararla aynı gerekçeye dayanır |
| D32 | Tarihin günü | Gösterilen günü izler (D28 ile aynı gün) | Sıradaki vakit yarınınsa yarının tarihi yazmalı; aksi halde YARIN ibaresiyle çelişir |
| D33 | Açık tema zemini | `Palette.swift`'e **widget'a özel açık tema durakları** eklenir; uygulamanın `palettes.dart`'ı değişmez | M5. Uygulamada koca ekrana yayılan geçiş, küçük kutuda görünmez oluyor. Değerler cihazda 2x2 boyutunda bakılarak seçilir; palet ailesi (ton) korunur, yalnızca duraklar arası kontrast açılır |
| D34 | Derin bağlantı | `ezanvakti://` şeması `Info.plist`'e tanımlanır ve uygulama tarafında karşılanır | M6. Şu an hiçbir yerde tanımlı olmayan bir adrese bağlanıyoruz |
| D35 | `schemaVersion` | **2**'ye çıkar, ama widget **1'i de kabul eder**; v1 payload'da hicri satırı çizilmez | D30 payload'a alan ekliyor ama alan isteğe bağlı. v1'i reddetmek, güncelleme anında App Group'ta duran eski payload yüzünden kullanıcıya "uygulamayı güncelleyin" gösterirdi — uygulama zaten güncelken. Yanlış mesaj, eksik bir tarih satırından kötüdür |

## 4. Payload değişikliği

`schemaVersion` 2. Tek ekleme: her günün kendi hicri tarihi.

```json
{
  "schemaVersion": 2,
  "locationLabel": "Ankara",
  "generatedAt": "2026-08-29T23:03:00",
  "days": [
    {
      "date": "2026-08-29",
      "hijri": "13 Rebiülevvel 1448",
      "times": { "fajr": "04:37", "sunrise": "06:06", "dhuhr": "12:55",
                 "asr": "16:36", "maghrib": "19:32", "isha": "20:55" }
    }
  ]
}
```

`hijri` dizesi `HijriFormatter.format` çıktısıdır — uygulamanın gösterdiğiyle
birebir aynı.

`hijri` **isteğe bağlıdır** ve widget `schemaVersion` 1 ile 2'yi birlikte
kabul eder (D35). Güncellemeden hemen sonra App Group'ta hâlâ v1 payload
durur; widget o aralıkta hicri satırını çizmez, uygulama bir kez açılınca
tarih gelir. Bilinmeyen bir sürüm (3 ve üzeri) hâlâ reddedilir.

## 5. Düzenler

```
small (2x2)                    medium (4x2)
┌──────────────────┐           ┌────────────────────────┬────────────────┐
│ Cuma, 26 Ağustos │  küçük    │ Cuma, 26 Ağustos       │ İmsak   04:38  │ vurgulu
│ 13 Rebiülevvel   │  küçük    │ 13 Rebiülevvel ·Ankara │ Güneş   06:06  │
│ Ankara           │  küçük    │                        │ Öğle    12:55  │
│                  │           │ YARIN · İMSAK          │ İkindi  16:36  │
│ İMSAK            │           │ 04:38                  │ Akşam   19:32  │
│ 04:38            │           │ 5:34:42                │ Yatsı   20:55  │
│ 5:34:42          │  baskın   │                        │                │
└──────────────────┘           └────────────────────────┴────────────────┘
```

Medium'un sağ sütunundaki altı satır dikeyde yayılıp yüksekliğin tamamını
kaplar; 0.5.0'daki alt boşluk kapanır.

Kilit ekranı dikdörtgeni üç satır kalır: vakit adı + saati, geri sayım, ve
yalnızca bayat veride "GÜNCEL DEĞİL".

Hizalama ayarı `small` ve `medium`'da tüm blokların yatay hizasını belirler
(sol/orta/sağ). Medium'da yalnızca sol sütun hizalanır; vakit listesi kendi
düzenini korur.

## 6. Kapsam dışı

`systemLarge` (4x4) · `accessoryCircular` · widget başına konum seçimi ·
etkileşimli widget · Live Activity · widget lokalizasyonu.

`accessoryInline` bu turda **kaldırılıyor** (D25), kapsam dışı değil.

## 7. Riskler

**R5 — `isLuminanceReduced` davranışı.** Değerin varlığından eminim; kilit
ekranı ailelerinde Always-On'a girildiğinde güvenilir şekilde `true` olup
olmadığı cihazda doğrulanmalı. Olmuyorsa D19 düşer ve her yerde kendimiz
çizeriz (canlı saniye kaybıyla).

**R6 — Dakikalık timeline'ın bütçeye etkisi.** D22'deki hesap gözleme değil
yaygın pratiğe dayanıyor; Apple resmî bir tavan yayımlamıyor. Widget'ın
güncellenmediği gözlenirse pencere kısaltılır ya da dakikalık giriş yalnızca
sıradaki vakte bir saat kala üretilir.

**R7 — Derin bağlantı teşhisi.** D34, M6'daki eksikliği kapatıyor; ancak
kullanıcının bildirdiği "sağdan ekran gelmesi" belirtisinin sebebi henüz
doğrulanmadı. Uygulama sırasında teşhis edilecek; şema tanımı belirtiyi
çözmezse ayrıca ele alınır.

## 8. Test

**Dart** (`test/home_widget/`): `hijri` alanının payload'a `HijriFormatter`
çıktısıyla birebir yazılması, `schemaVersion` 2.

**Swift** (`ios/RunnerTests/`): dakikalık giriş üretimi (pencere sınırı, giriş
sayısı tavanı), sıradaki vaktin gününe göre liste seçimi (D28), YARIN
koşulu (D29), hizalama seçiminin görünüme yansıması, `schemaVersion` 1'in
hicri alanı olmadan kabul edilmesi, bilinmeyen sürümün reddi.

**Cihaz:** Always-On'da geri sayım biçimi (R5), widget ayarından hizalama
değişimi, dokununca uygulamanın açılışı (R7), gece dilimi + açık temada zemin
kontrastı (D33).
