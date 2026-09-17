# Diyanet il/ilçe modeli — uygulama tarafı (Spec B)

- **Tarih:** 2026-09-17 · **Durum:** kabul edildi (sözlü, 2026-09-17), uygulandı (Plan B1 + B2) · **Branch:** `feature/vakit-api`
- **Eşi:** [Spec A — vakit-api sunucusu](2026-09-15-vakit-api-sunucu-design.md); bu belge oradaki `/v1` sözleşmesini tüketir.
- **Bağlam:** [Diyanet vakit farkı](../../investigations/2026-09-14-diyanet-vakit-farki.md), [Aladhan–resmi tablo karşılaştırması](../../investigations/2026-09-15-aladhan-resmi-tablo-farklari.md)

## Amaç

Uygulama vakitleri Aladhan'dan hesaplatmak yerine Diyanet'in yayınladığı tabloyu kendi sunucumuzdan
(`vakit-api`) alır. Konum artık koordinat + hesap yöntemi değil, **bir Diyanet ilçesi**dir. İl/ilçe
listesi ve koordinatlar cihazda tutulmaz; arama ve GPS çözümleme sunucuda yapılır. Hicri tarih
hesaplanmaz, Diyanet verisinden okunur. Şimdilik yalnız Türkiye; diğer ülkeler sunucuda açıldıkça
uygulama değişmeden gelir (ülke seçici o zaman eklenir).

## Kararlar

| # | Karar | Gerekçe |
|---|---|---|
| B1 | Konum = Diyanet ilçe kimliği (`cityId`, `stateId`, `countryId`) + görünen adlar; koordinat yalnız kıble için (GPS: cihazın gerçek koordinatı; seçilmiş: sunucudan ilçe merkezi) | Vakit ilçe bazlı; hesap parametresi anlamsız |
| B2 | Konum başına hesap yöntemi/mezhep/enlem düzeltmesi kaldırılır; ± dakika düzeltmesi (tune) genel ayar olarak kalır ve okuma anında uygulanır (ADR 0004) | Diyanet tablosu hesap değil, veri |
| B3 | Gömülü il/ilçe listesi yok; arama `GET /v1/places/search`, GPS çözümleme `GET /v1/places/resolve` | Tek kaynak sunucu; düzeltmeler uygulama güncellemesi istemez (kullanıcı kararı 2026-09-17) |
| B4 | Vakitler ilçe-yıl dosyası olarak (`GET /v1/prayer-times/{cityId}/{year}`) çekilir, gün gün mevcut önbellek tablosuna Hicri ile birlikte yazılır | Yıl boyu çevrimdışı; ETag ile ucuz tazeleme |
| B5 | Hicri tarih yalnız Diyanet verisinden; `hijri` paketi kaldırılır, veri olmayan gün için tahmin yapılmaz | Bir gün kayma (1 Ramazan 1447 örneği) bitmeli (kullanıcı kararı) |
| B6 | Aladhan sağlayıcısı, Photon adres araması, cihaz ters-geocode'u, yöntem katalogları ve ülke→yöntem varsayılanları silinir | Ölü yol bırakılmaz; üçüncü tarafa koordinat gitmez |
| B7 | Mevcut kayıtlar güncelleme sonrası ilk açılışta sunucuda ada göre eşlenir; belirsizler tek seferlik doğrulama ekranında seçtirilir; Türkiye dışı kayıtlar desteklenmez | Kullanıcı veri kaybetmeden geçer |
| B8 | Sunucu adresi derleme zamanı sabiti (`--dart-define=VAKIT_API_BASE_URL`; varsayılan yerel geliştirme adresi `http://127.0.0.1:8080`, üretim adresi sürüm derlemesinde define ile geçilir — domain kurulum sonrası); TLS Cloudflare'de | Yerel sunucuya karşı geliştirme |

## Kapsam

### UYG.1 — Konum modeli ve saklama

- `Location` alanları: `id`, `cityId`, `stateId`, `countryId`, `province` (il adı, görünen), `district` (ilçe adı, görünen), `displayLabel` (sunucunun `displayName`'i: "Şile, İstanbul" / "İstanbul (Merkez)"), `latitude`/`longitude` (GPS: cihaz; seçilmiş: ilçe merkezi), `type` (gps | manual), `customName`. `method`/`school`/`latitudeAdjustmentMethod` modelden ve kullanımlardan kalkar.
- SQLite `locations` tablosu sürüm 15: `city_id INTEGER`, `state_id INTEGER`, `country_id INTEGER`, `display_label TEXT` eklenir (nullable; eski satırlar `NULL` → UYG.7 migrasyonu). Eski `method/school/latitude_adjustment` sütunları silinmez, okunmaz.
- Aktif konum `settings` tablosundaki JSON'da kalır; `fromJson` eski JSON'ı (cityId yok) okuyabilmeli — cityId `null` ise konum "eşlenmemiş" sayılır.
- Eşitlik/`copyWith`/JSON testleri yeni alanları kapsar. GPS konumu tek satır, kimliği sabit `gps` (bugünkü gibi).

### UYG.2 — Konum ekleme ekranı

Tek ekran; üstte arama kutusu, altında "Konumumu kullan".

- **Arama:** 300 ms debounce, en az 2 karakter (boş kutu = sunucunun büyük il listesi, hemen gösterilir). İstek `GET /v1/places/search?q=&limit=10`. Satır: `displayName`; `matchedAlias` doluysa ikinci satır "Kadıköy buna dahil". Seçim → `Location(type: manual, cityId..., latitude/longitude = ilçe merkezi)`.
- **GPS:** izin akışı bugünkü gibi; konum alınınca `GET /v1/places/resolve?lat&lon` → onay bandı "Vakitler **Şile, İstanbul** için gösterilecek — Onayla / Değiştir". Onay → `Location(type: gps, id: 'gps', cihaz koordinatı, cityId...)`. `404 NO_COVERAGE` → "Bu bölge henüz desteklenmiyor; ilçeni seç". Konum servisleri kapalı/izin yok → mevcut mesajlar.
- **Ağ yok / 503 NOT_READY / zaman aşımı:** "Konum eklemek için internet gerekli" + Tekrar dene. Sunucu 5xx: aynı mesaj, ayrıntı log'da.
- İlk konum ise kayıttan sonra ana ekrana geçilir (bugünkü akış). Photon, OSM önerileri, ters-geocode etiketi, koordinattan konum kaydetme yolları kalkar.
- OSM atfı ekleme ekranından kalkar; Ayarlar → Hakkında'ya "İlçe koordinatları © OpenStreetMap contributors" gelir (sunucu koordinatları OSM'den).

### UYG.3 — GPS izleme

Mevcut eşikler (5 km / 30 dk / `autoLocation` ayarı) korunur. Konum değişince ters-geocode yerine `resolve` çağrılır; **yalnız `cityId` değiştiyse** konum güncellenir, önbellek temizlenir, vakitler yeniden çekilir. Ağ yoksa deneme sessizce atlanır (bir sonraki değişimde tekrar). Cihaz koordinatı her güncellemede kaydedilir (kıble).

### UYG.4 — Vakit sağlayıcısı ve önbellek

- Yeni sağlayıcı `DiyanetProvider` (`PrayerTimeProvider`'ı uygular): istenen aralığın yıllarını (en fazla iki) `GET /v1/prayer-times/{cityId}/{year}` ile çeker, `days[]`'i `PrayerTime` listesine çevirir (yerel duvar saati, bugünkü gibi cihaz saat diliminde kurulur; `gmtOffset` şimdilik saklanmaz). `If-None-Match` ile ETag gönderir; `304` → mevcut önbellek geçerli sayılır. Zaman aşımı 15 s, 429/5xx'te bugünkü sınırlı yeniden deneme.
- Depo (`PrayerTimesRepository`) sözleşmesi değişmez; sağlayıcı bir yılın tamamını döndüğünde depo hepsini önbelleğe yazar. Gün-gün tamlık denetimi ve boşluk davranışı ("veri yok") aynen. `404` (yıl yayınlanmamış) → boş liste, önbellek korunur.
- `PrayerTime` modeli ve `prayer_times` tablosu Hicri alır: `hijri_day`, `hijri_month`, `hijri_year` (sürüm 15). ETag'ler `settings` tablosunda `etag:<locationId>:<year>` anahtarıyla.
- `AwqatSalahProvider` (Aladhan) ve testleri silinir; `PrayerTimeProvider` arayüzü konum yerine `cityId` alacak biçimde sadeleşir (`fetchYear(cityId, year)`), depo çevirir.

### UYG.5 — Hicri tarih, Ramazan, dinî günler

- `HijriFormatter` gün satırındaki Hicri değeri formatlar (ay adı l10n'dan, ay numarasıyla). Girdi `PrayerTime.hijri`; yoksa boş string döner (üst bar Hicri satırını gizler, widget `hijri` alanı `null`).
- Ramazan modu: bugünün satırında Hicri ay = 9. Ramazan dönemi (imsakiye): önbellekteki 9. ay günlerinin ilki/sonu; yoksa elle girilmiş dönem tablosu (`ramadan_periods`) yedek. Bayram günü = 10. ayın 1'i (bayram tarihi tablodan).
- Dinî günler: sunucuda `GET /v1/religious-days/{year}` varsa (API onayı sonrası) kullanılır ve önbelleğe yazılır; yoksa mevcut türetme kuralları önbellekteki Diyanet Hicri'siyle çalışır. `religious_days` sabit tablosu türetme için kalır; `isEstimated` yalnız sunucu verisi yoksa `true`.
- `hijri` paketi `pubspec`'ten çıkar; `HijriCalendar` çağrıları kalkar.

### UYG.6 — Kıble

Değişmez: `latitude/longitude` üzerinden yön. Seçilmiş konumda koordinat ilçe merkezidir (sunucudan). Koordinatsız konum (eşlenmemiş) → mevcut boş durum.

### UYG.7 — Mevcut kullanıcı migrasyonu

Uygulama açılışında (`AppRoot`), `cityId`'si `null` konum varsa:
1. GPS konumu: koordinatı varsa `resolve` → otomatik.
2. Seçilmiş konum: `search?q="<district> <province>"` → ilk sonuç ilçe **ve** il adında önek eşleşmesi taşıyorsa otomatik; aksi hâlde "belirsiz".
3. Belirsiz kayıt varsa tek seferlik **"Konumlarını doğrula"** ekranı: her satırda eski ad, sunucu önerileri, "Seç"; "Sil" seçeneği. Türkiye dışı (sonuç yok): "Bu konum artık desteklenmiyor" + Sil/Değiştir.
4. Ağ yoksa ekran açılmaz; eşlenmemiş konum seçiliyse ana ekran "konumu doğrula" bandı gösterir, vakit yüklenmez. Bir sonraki açılışta tekrar denenir.
Eşleme tamamlanan konumun önbelleği temizlenir ve yeniden çekilir. Migrasyon adımı test edilir (sahte sunucu).

### UYG.8 — Ayarlar ve temizlik

- Kaldırılır: hesaplama ayarları ekranı, yöntem/mezhep/enlem seçicileri, konum düzenleme ekranındaki "global/özel hesap" bölümü (düzenleme ekranı yalnız özel ad + ilçe değiştir), `CalculationMethods`, `AsrSchool`, `LatitudeAdjustment`, `RegionalDefaults`, `CalculationSettings.method/school/latitudeAdjustmentMethod` (yalnız `tune` kalır → `PrayerTuneSettings`).
- Ayarlar: "Vakit düzeltme" (tune) satırı kalır; "Veri kaynağı: Diyanet İşleri Başkanlığı" görünür; Hakkında'da OSM atfı.
- Bağımlılıklar: `geocoding` ve `hijri` çıkar; `geolocator` kalır; `http` kalır. Android/iOS konum izin metinleri "en yakın ilçeyi bulmak için" anlamında güncellenir.
- Gizlilik: `docs/PRIVACY.md`, `docs/privacy.html`, `docs/PLAY_DATA_SAFETY.md`, l10n `privacyBody`: bizim sunucuya arama metni ve ~100 m'ye yuvarlanmış koordinat gider; saklanmaz; Aladhan/Photon ifadeleri kalkar; "bize ait sunucu yoktur" cümlesi düzeltilir.
- ADR 0006: "Tek vakit kaynağı Diyanet (vakit-api); hesap yöntemi seçimi kaldırıldı" — bağlam, karar, elenen alternatifler (Aladhan tune, cihazda liste), referanslar.
- ROADMAP/ARCHITECTURE/README/CHANGELOG güncellenir.

### UYG.9 — Bildirim, alarm, widget

Sözleşmeler değişmez (görünen ad + vakit listesi). Widget snapshot'ındaki Hicri metni artık Diyanet verisinden gelir; veri yoksa `null` (Swift tarafı zaten opsiyonel). Dinî gün bildirimleri UYG.5'teki kaynaktan beslenir.

## Uygulamadaki sapmalar (Plan B2, 2026-09-17)

1. **`PrayerTimeProvider` arayüzü sadeleşmedi** (UYG.4 "fetchYear(cityId, year)"): `DiyanetProvider` mevcut `fetchPrayerTimes(location, start, end)` arayüzünü uygular ve `cityId`'yi `Location`'dan okur; depo sözleşmesi değişmedi. Arayüz değişikliği altı sahte sağlayıcıyı ve depo testlerini tarardı, kazancı yoktu.
2. **Düzeltme ayarının depo anahtarı `calculation_settings` kaldı:** `PrayerTuneSettings.fromJson` yalnız `tune`'u okur; mevcut kullanıcıların düzeltmesi korunur.
3. **Doğrulama ekranında aktif konum silinemez** (UYG.7 "Sil" yalnız aktif olmayanlarda): liste ekranındaki kuralla aynı; aktif konum seçilir ya da başka ilçeyle değiştirilir.
4. **Konum düzenleme ekranı** özel ad + "İlçeyi değiştir" (arama paneli ekranın içinde); GPS kaydında cihaz koordinatı korunur.

## Kapsam dışı

- Türkiye dışı ülkeler (sunucuda açılınca ülke seçici ve ülke bazlı arama).
- Sunucunun resmî kıble açısını kullanmak.
- Remote config, push, hesap/senkron (Faz 2–4).
- Konum düzenlemede ilçe değiştirmeden koordinat oynatma.

## Doğrulama

- `flutter analyze`, `flutter test` (yeni: sağlayıcı ayrıştırma, ETag/304, şema 15 migration, migrasyon eşleme, arama/GPS ekranı widget testleri, Hicri formatlayıcı, Ramazan dönemi türetme).
- Yerel sunucuya (`VAKIT_API_BASE_URL=http://127.0.0.1:8080`) karşı simülatörde uçtan uca: konum ekle (arama + GPS), vakitler ve Hicri, çevrimdışı gün, migrasyon senaryosu (eski şemalı veritabanı).
- Cihaz testi Ekrem'de: GPS onay bandı, izin akışı, gerçek sunucu adresi, widget Hicri.
- Unit/widget testleri native alarmın gerçek cihazda çaldığını kanıtlamaz (proje kuralı).

## Açık noktalar

- Üretim sunucu adresi (`api.<domain>`) kurulum sonrası sabitlenecek.
- API onayı öncesi dinî gün ve günlük içerik uçları boş döner; uygulama bunu "veri yok" olarak ele alır.
- `gmtOffset` ve `qiblaTime` alanları şimdilik saklanmaz; ülke açılınca değerlendirilir.
