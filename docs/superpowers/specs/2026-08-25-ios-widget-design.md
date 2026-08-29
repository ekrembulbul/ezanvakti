# iOS Widget (Ana Ekran + Kilit Ekranı) — Tasarım Spec'i

Sıradaki vakti ve geri sayımı, uygulamayı açmadan ana ekranda ve kilit
ekranında göstermek. Bu tur yalnızca **iOS**; Android sonraki turda.

## 1. Sorun

Kullanıcı "ne kadar kaldı" sorusunun cevabını almak için uygulamayı açmak
zorunda. Bu, günde onlarca kez sorulan bir soru için fazla yüksek bir bedel.
`docs/ROADMAP.md` §"Ana ekran widget'ı" bunu zaten planlanan özellik olarak
kaydetmiş; bu spec o kaydı uygulanabilir bir tasarıma çeviriyor.

Widget ayrı bir process'te çalışır ve içinde Flutter engine barındıramaz.
Dolayısıyla asıl mühendislik işi UI değil, **veriyi Flutter çalışmadan
okunabilir bir yere taşımak**.

## 2. Mevcut durumun ölçümleri

Tasarım, kod tabanından okunan şu gerçeklere dayanıyor:

| # | Bulgu | Kaynak |
|---|---|---|
| M1 | iOS deployment target **13.0** | `ios/Runner.xcodeproj/project.pbxproj:468` |
| M2 | Vakitler **timezone taşımayan cihaz-yerel wall-clock** olarak üretiliyor (`DateTime(y,m,d,h,m)`) | `lib/features/prayer_times/data/awqat_salah_provider.dart:407` |
| M3 | Önbellek 30 gün ileriyi tutuyor; yükleme penceresi bugünden 10 gün sonrasına kadar | `prayer_times_repository.dart:11`, `data_loader_service.dart:38` |
| M4 | Tüm veri yükleme yolları tek fonksiyondan geçiyor | `lib/presentation/pages/home_page.dart:248` |
| M5 | Gün dilimi (palet) sınırları İmsak/Öğle/İkindi/**Yatsı**; gece Akşam'da değil Yatsı'da başlar | `lib/core/theme/day_phase.dart:49` |
| M6 | Uygulamadaki geri sayım biçimi `HH:MM:SS` | `lib/presentation/widgets/home/countdown_hero.dart:79-81` |
| M7 | iOS imzalama **manuel** ve tek bundle ID'ye kilitli | `ios/fastlane/Fastfile:6-7,37-44` |
| M8 | Projede App Group entitlement dosyası yok | `ios/` altında `*.entitlements` bulunamadı |

M2 tasarımın taşıyıcı bulgusu: widget'a offset'li ISO timestamp yazmak,
uygulamada var olmayan bir timezone semantiği uydurmak olurdu. M4, senkron
için tek ve yeterli bir kanca noktası olduğunu gösteriyor.

⚠️ Doğrulanmamış: `.timer` ve `.relative` metinlerinin kilit ekranı
ailelerindeki (`accessoryRectangular`, `accessoryInline`) güncelleme sıklığı.
Implementasyonun ilk adımında gerçek cihazda ölçülecek (bkz. §9 R2).

## 3. Alınan kararlar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D1 | Platform kapsamı | **Yalnızca iOS.** Snapshot üretimi platformdan bağımsız yazılır | Android widget'ı ayrı bir native UI işi. Saf Dart tarafı ortak kaldığı için Android turu yalnızca native yazıcıyı ve UI'ı ekler |
| D2 | Deployment target | **13.0 → 17.0** | Kilit ekranı aileleri iOS 16+, `containerBackground` ve etkileşimli widget 17+. 17'yi seçmek `#available` dallanmasını sıfırlar. Bedeli §9 R1'de |
| D3 | Desteklenen aileler | `systemSmall`, `systemMedium`, `accessoryRectangular`, `accessoryInline` | Kullanıcı kararı. `systemLarge` ve `accessoryCircular` kapsam dışı (§8) |
| D4 | Konum seçimi | **Aktif konumu takip eder.** `StaticConfiguration`, yapılandırma UI'ı yok | Payload tek konumluk kalır, `AppIntent`/entity sağlayıcı altyapısı hiç kurulmaz. Widget başına konum §8'de |
| D5 | Flutter↔native köprüsü | **`home_widget` paketi** | App Group yazımını ve `WidgetCenter` reload'unu hazır veriyor; Android turunda aynı köprü kullanılır. Paket uyumsuz çıkarsa elle `MethodChannel`'a düşülür — veri sözleşmesi aynı kaldığı için tasarım hayatta kalır (§9 R3) |
| D6 | Payload biçimi | App Group'ta **tek key altında tek JSON string** | Çok sayıda düz key, kısmi yazımda widget'a tutarsız veri gösterir. Tek string atomik okunur |
| D7 | Saat serileştirmesi | `"HH:mm"` + ayrı `date` alanı; **ISO timestamp değil** | M2. Swift `Calendar.current` ile `Date`e çevirir; uygulama ile widget bit-bit aynı davranır |
| D8 | Payload penceresi | **7 gün** | M3 sayesinde bedava. Uygulama bir hafta açılmasa bile widget doğru kalır. Payload ~1 KB |
| D9 | Şema sürümü | Payload'da `schemaVersion`; Swift bilmediği sürümde "uygulamayı güncelleyin" durumuna düşer | Uygulama güncellenip widget extension eski kalabilir (nadir ama mümkün). Çöp çizmek yerine dürüst hata |
| D10 | Senkron tetikleyicisi | **Yalnızca `_loadPrayerData`** (`home_page.dart:248`), `ReminderRescheduler.reschedule` ile aynı desende | M4: pull-to-refresh, konum değişimi, GPS, gece yarısı yenilemesi, resume ve hesaplama ayarı değişimi hepsi buradan geçiyor. Yeni timer/lifecycle kancası icat etmeye gerek yok |
| D11 | Yayınlama hatası | Yakalanır, `logger.warning` ile loglanır, **kullanıcı akışını kesmez** | Vakit gösterimi widget yüzünden bozulmamalı. Widget bir önceki snapshot'ıyla çalışmaya devam eder |
| D12 | Geri sayım | SwiftUI'ın kendiliğinden güncellenen `Text(date, style: .timer)` metni; **geri sayım için timeline girişi üretilmez** | Saniyelik timeline girişi widget refresh bütçesini yakar. `.timer` sistem tarafından reload'suz çizilir ve M6'daki biçimle aynı şeyi gösterir |
| D13 | `.timer` biçim farkı | Kabul edilir ("1:12:34" vs uygulamadaki "01:12:34") | Alternatifi kendi saniyelik reload'umuzu yazmak; bütçe buna izin vermez. Fark tek karakter |
| D14 | Timeline girişleri | Yalnızca **içerik değiştiğinde** — her vakit geçişinde. Önümüzdeki **48 saat** (~12 giriş), `.after(son giriş)` policy'si | Vakit geçişi aynı zamanda gün dilimi sınırı (M5), tek giriş listesi hem sıradaki vakti hem gradyanı taşır. 48 saatlik pencere, 7 günlük payload'dan her reload'da tazelenir |
| D15 | Görsel dil | Gün dilimi gradyanı **Swift'e portlanır** | Widget uygulamanın kimliğini taşımalı. Paletin snapshot ile gönderilmesi, uygulama günlerdir açılmadığında gradyanı bayatlatırdı |
| D16 | Gün dilimi mantığı | `resolveDayPhase` Swift'e portlanır (~10 satır), saf fonksiyon olarak ayrı dosyada | M5'teki iki kural (gece Yatsı'da başlar; gece yarısı–İmsak dünün gecesi) korunmalı. Saf tutulunca unit test edilir |
| D17 | Kilit ekranı görselleri | Gradyan yok; `AccessoryWidgetBackground()` + `.widgetAccentable()` | Sistem bu aileleri tek renge indirger. Gradyan denemek boşa iş |
| D18 | Metin dili | Türkçe sabit metinler, lokalizasyon altyapısı yok | Uygulama tamamen Türkçe (`ios/Runner/Info.plist` `CFBundleLocalizations`). Lokalizasyon ayrı bir roadmap maddesi |

## 4. Mimari

Dizin yapısı `docs/ARCHITECTURE.md`'deki feature-first + katmanlı düzene uyar:

```
lib/core/interfaces/widget_publisher.dart                     soyutlama
lib/features/home_widget/domain/widget_snapshot.dart          model + toJson
lib/features/home_widget/domain/widget_snapshot_builder.dart  saf dönüşüm
lib/features/home_widget/domain/widget_snapshot_publish.dart  üret + yayınla + hatayı yut
lib/features/home_widget/data/home_widget_publisher.dart      home_widget kabuğu
```

Ayrımın mantığı: **snapshot üretimi saf**, `(List<PrayerTime>, Location,
DateTime now)` alıp `WidgetSnapshot` döner, hiçbir platform bağımlılığı yoktur
ve testlerin asıl hedefidir. **Yayınlama ise arayüz arkasındadır**
(`WidgetPublisher`); testlerde fake ile değiştirilir, iOS dışı platformlarda
no-op'tur.

`widget_snapshot_publish.dart` ikisini birleştiren ince bir fonksiyondur ve
D11'deki hata izolasyonunun yaşadığı yerdir. Ayrı durmasının sebebi test
edilebilirlik: `HomePage`'in içine gömülseydi "yayınlama patlarsa akış kesilmez"
kuralı ancak bir widget testiyle doğrulanabilirdi.

Swift tarafı:

```
ios/EzanVaktiWidget/
  EzanVaktiWidgetBundle.swift          @main, widget kayıtları
  Snapshot/WidgetSnapshot.swift        Codable model + schemaVersion guard
  Snapshot/SnapshotStore.swift         UserDefaults(suiteName:) okuma
  Timeline/NextPrayer.swift            "şu anda sıradaki vakit" — saf
  Timeline/PrayerTimelineProvider.swift
  Theme/DayPhase.swift                 day_phase.dart portu — saf
  Theme/Palette.swift                  palettes.dart gradyanlarının portu
  Views/{Small,Medium,Rectangular,Inline}View.swift
  Info.plist
  EzanVaktiWidget.entitlements         App Group
```

WidgetKit'e dokunmayan saf tipler (`NextPrayer`, `DayPhase`,
`WidgetSnapshot`) ayrı dosyalarda durur ki normal bir XCTest target'ı
kapsayabilsin.

## 5. Veri sözleşmesi

App Group: `group.com.ekrembulbul.ezanvakti`
Key: `ezanvakti_snapshot`

```json
{
  "schemaVersion": 1,
  "locationLabel": "Kadıköy, İstanbul",
  "generatedAt": "2026-08-25T14:03:00",
  "days": [
    {
      "date": "2026-08-25",
      "times": {
        "fajr": "04:12",
        "sunrise": "05:52",
        "dhuhr": "13:15",
        "asr": "16:58",
        "maghrib": "20:26",
        "isha": "21:58"
      }
    }
  ]
}
```

`days` bugünden başlayarak en fazla 7 gün taşır (D8); önbellekte daha az gün
varsa kısalır, hiç yoksa boş dizi olur.

`generatedAt` yalnızca teşhis içindir (log/hata ayıklama); bayatlık kararı ona
değil, `days`'in son gününe bakılarak verilir (§7) — çünkü haftalarca açılmayan
bir uygulamanın eski `generatedAt`'i, payload hâlâ geleceği kapsıyorsa bir
sorun değildir.

App Group kimliği Dart tarafında uygulama açılışında bir kez ayarlanır
(`HomeWidget.setAppGroupId`); `ServiceLocator` kurulumuyla aynı yerde durur.

## 6. Veri akışı

```
_loadPrayerData (home_page.dart:248)
        │  başarılı yükleme sonrası
        ▼
WidgetSnapshotBuilder  (saf: PrayerTime listesi + Location → WidgetSnapshot)
        │
        ▼
WidgetPublisher ──▶ HomeWidgetPublisher ──▶ App Group (JSON) + WidgetCenter reload
                                                    │
                                                    ▼
                              PrayerTimelineProvider (Swift, ayrı process)
                                                    │
                                                    ▼
                                        48 saatlik timeline girişleri
```

## 7. Düzenler ve durumlar

| Aile | İçerik |
|---|---|
| `systemSmall` | Gün dilimi gradyanı zemin; sıradaki vakit adı + saati, altında büyük geri sayım, en altta konum etiketi |
| `systemMedium` | Sol: sıradaki vakit + geri sayım. Sağ: günün 6 vakti şeridi — geçenler soluk, sıradaki accent ile vurgulu |
| `accessoryRectangular` | Üç satır: "SIRADAKİ" / "İkindi 16:58" / geri sayım |
| `accessoryInline` | Tek satır: "İkindi 16:58 · 1:12:34" |

Ana ekran aileleri zemini `.containerBackground(for: .widget)` ile verir; iOS
17'de bu olmadan widget kırpılır. Tıklama `.widgetURL` ile uygulamaya
deep-link eder.

Boş ve bayat durumlar ayrı çizilir, hiçbiri boş kutu değildir:

| Durum | Gösterim |
|---|---|
| Snapshot yok (widget kurulmuş, uygulama hiç açılmamış) | "Vakitler için uygulamayı aç" |
| `schemaVersion` bilinmiyor | "Uygulamayı güncelleyin" |
| Snapshot'ın son günü bugünden eski | Son bilinen vakitler soluk + "Güncel değil" rozeti |

## 8. Kapsam dışı (YAGNI)

Android widget · widget başına konum seçimi (`AppIntentConfiguration`) ·
`systemLarge` · `accessoryCircular` · etkileşimli widget / `AppIntent` ·
Live Activity ve Dynamic Island · widget lokalizasyonu · hicri tarih
(`hijri_formatter.dart` hazır, medium düzenine sonradan eklenebilir).

Bunların hepsi aynı veri sözleşmesinden beslenebilir; sonradan eklemek
snapshot şemasını değiştirmez.

## 9. Riskler ve dışarıya bağımlı işler

**R1 — iOS 13→17 sıçraması (ürün kararı).** iOS 13–16'daki mevcut kullanıcılar
artık güncelleme alamaz. `ios/Podfile` ve tüm plugin'ler etkilenir; `pod
install` + tam build doğrulaması gerekir. `docs/ROADMAP.md` iOS 26/AlarmKit'ten
bahsederken projenin gerçek hedefinin hâlâ 13.0 olması bir tutarsızlık; bu iş
kapsamında düzeltilir.

**R2 — `.timer` metninin kilit ekranındaki davranışı.** Accessory ailelerde
güncelleme sıklığı gerçek cihazda ölçülmeli. Beklenenden seyrekse
`accessoryInline` içeriği geri sayım yerine yalnızca saate indirilir.

**R3 — `home_widget` paket uyumu.** Güncel Flutter/iOS sürümleriyle uyumu
implementasyonun ilk adımında doğrulanmalı. Uymazsa elle `MethodChannel`'a
düşülür; veri sözleşmesi ve Swift tarafı aynen kalır.

**R4 — İmzalama (elle yapılacak portal işleri).** M7 nedeniyle widget
extension ikinci bir bundle ID demek:

1. Apple portalında yeni App ID: `com.ekrembulbul.ezanvakti.EzanVaktiWidget`
2. Onun için ayrı **App Store dağıtım profili** (Runner'ınki geçmez)
3. App Group `group.com.ekrembulbul.ezanvakti` **her iki** App ID'ye eklenir
4. `ios/fastlane/Fastfile`'da `update_code_signing_settings` içindeki
   `targets:` listesine widget target'ı, `export_options.provisioningProfiles`
   map'ine ikinci giriş

1–3 portalda elle yapılır, kodla halledilemez. 4 atlanırsa CI yeşil görünür,
yükleme aşamasında patlar.

## 10. Test stratejisi

Sorumluluk sınırı testlerin de sınırıdır: **paketleme** Dart'ta, **yorumlama**
(sıradaki vakit, gün dilimi) Swift'te yaşar (§4), dolayısıyla her biri kendi
tarafında test edilir. Aynı kuralı iki dilde test etmek, iki kopyanın
birbirinden sessizce ayrışmasını engellemez — asıl koruma D16'daki portun saf
tutulmasıdır.

**Dart birim testleri** (`test/home_widget/`) — `WidgetSnapshotBuilder` saf
olduğu için paketleme kapsaması burada:

- bugünden önceki günler elenir, bugün dahil edilir
- gece yarısından sonra (ör. 02:00) çalıştırıldığında bugünün günü hâlâ dahil edilir
- pencere en fazla 7 gün (D8)
- önbellekte daha az gün varsa pencere kısalır
- boş vakit listesi → boş `days`
- saatler sıfır dolgulu `"HH:mm"` (D7)
- `locationLabel`, `Location.displayName` ile aynı

**Yayınlama testi** — `WidgetPublisher` fake'i ile `_loadPrayerData`'nın
yayınlamayı çağırdığı ve **yayınlama hata verse bile yükleme akışının
kesilmediği** (D11) doğrulanır.

**Swift birim testleri** — WidgetKit'e dokunmayan saf tipler olduğu için normal
XCTest target'ında koşar:

- `NextPrayer`: gün içindeki sıradaki vaktin seçilmesi; Yatsı sonrası ertesi
  günün İmsak'ına geçiş; pencerenin son gününde sıradaki vakit bulunamaması
- `DayPhase`: dört dilimin sınırları; gecenin Akşam'da değil **Yatsı'da**
  başlaması; gece yarısı–İmsak aralığının `night` olması; tam vakit anının bir
  **sonraki** dilime ait olması (M5)
- `WidgetSnapshot`: geçerli JSON decode; bilinmeyen `schemaVersion`'ın
  reddedilmesi (D9); bozuk saat biçiminin çökme değil hata üretmesi

**Cihaz testi** — widget'ın gerçek davranışı (timeline reload'ları, kilit
ekranı render'ı, `.timer` metninin accessory ailelerdeki güncellenmesi)
simülatörde güvenilir ölçülmez; gerçek cihazda elle doğrulanır.
