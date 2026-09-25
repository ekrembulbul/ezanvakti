# 0006. Tek vakit kaynağı Diyanet (`vakit-api`); hesap yöntemi seçimi kaldırıldı

- **Durum:** Kabul edildi
- **Tarih:** 2026-09-17
- **Etkilenen alan:** Vakit sağlayıcısı, konum modeli ve ekranları, GPS izleme, Hicri tarih, ayarlar, gizlilik
- **İlgili:** [ADR 0004](0004-single-source-prayer-time.md) (düzeltme okurken uygulanır — korunur), [Spec A](../superpowers/specs/2026-09-15-vakit-api-sunucu-design.md), [Spec B](../superpowers/specs/2026-09-17-diyanet-uygulama-design.md)

## Bağlam ve problem

Uygulama vakitleri Aladhan API'sinden koordinat + hesap yöntemi (`method=13`, "Diyanet") ile hesaplatıyordu. Türkiye'de kullanıcıların karşılaştırdığı referans ise Diyanet'in yayımladığı ilçe tablosudur ve iki kaynak arasında **mevsime göre değişen ±1–2 dakikalık** fark ölçüldü (`docs/investigations/2026-09-14-diyanet-vakit-farki.md`, `docs/investigations/2026-09-15-aladhan-resmi-tablo-farklari.md`). Fark sabit olmadığı için kullanıcının ± dakika düzeltmesiyle kapanmıyordu; imsak/akşam gibi hassas vakitlerde "yanlış saatte ezan" şikâyeti üretiyordu.

Diyanet'in resmi API kullanım şartı, verinin geliştiricinin **kendi sunucusunda** barındırılmasını ve kimlik bilgilerinin uygulamaya gömülmemesini ister (Spec A, K1). Ayrıca Diyanet tablosu bir **hesap değil veri**dir: hesap yöntemi, İkindi mezhebi ve yüksek enlem düzeltmesi seçicileri bu modelde anlamsızdır.

Konum tarafında uygulama Photon/OpenStreetMap araması ve platform ters-geocode'u ile koordinat üretiyordu; Diyanet modelinde konum bir **ilçe kimliği**dir. İl/ilçe listesini cihazda tutmak, her düzeltmede uygulama güncellemesi gerektireceği için kullanıcı kararıyla (2026-09-17) elendi.

## Karar

**Tek vakit kaynağı Diyanet'tir; veri kendi sunucumuzdan (`server/`, `vakit-api`, `/v1`) gelir.**

- **Konum = Diyanet ilçesi.** `Location` `cityId/stateId/countryId` ve sunucunun `displayLabel`'ını taşır; koordinat yalnız kıble içindir (GPS: cihazın koordinatı, seçilmiş: sunucudan ilçe merkezi). Hesap parametreleri (`method/school/latitudeAdjustmentMethod`) modelden ve depodan kalktı; SQLite sütunları okunmaz (`sqlite_storage.dart`, şema 15).
- **Arama ve GPS çözümleme sunucuda.** `PlacesApi.search` (`GET /v1/places/search`) ve `PlacesApi.resolve` (`GET /v1/places/resolve`); cihazda liste yok, üçüncü tarafa koordinat gitmez. Sunucu arama metnini ve koordinatı loglamaz, koordinatı ~100 m'ye yuvarlar (Spec A).
- **Vakitler ilçe-yıl dosyası olarak** çekilir (`DiyanetProvider`, `GET /v1/prayer-times/{cityId}/{year}`, `If-None-Match`/304 — `diyanet_provider.dart:86-112`), gün gün önbelleğe Hicri tarihle birlikte yazılır. Depo sözleşmesi değişmedi; sağlayıcı arayüzü `Location` alır ve `cityId`'yi oradan okur.
- **Hicri tarih yalnız Diyanet verisinden.** `hijri` paketi kaldırıldı; veri olmayan gün için tahmin yapılmaz, satır gizlenir.
- **Kullanıcının tek ayarı ± dakika düzeltmesi** (`PrayerTuneSettings`), ADR 0004 gereği okurken uygulanır (`prayer_time_tuner.dart:22`). Önbellek ham Diyanet verisini tutar.
- **Önbellek geçersizliği ilçeye bağlıdır.** Aynı GPS kaydı aynı ilçe içinde koordinat değiştirirse yalnız kayıt tazelenir; ilçe değişirse önbellek temizlenir ve bildirimler yeniden planlanır (`location_monitor_service.dart:123`, `location_service.dart`).
- **Mevcut kayıtlar migrasyonla eşlenir.** Açılışta cityId'siz kayıt varsa GPS için `resolve`, manuel için ada göre arama; yalnız il **ve** ilçe (ya da il merkezi / sunucu alias'ı) tutuyorsa otomatik (`location_migration_service.dart:170`), aksi hâlde tek seferlik doğrulama ekranı. Ağ yoksa ertelenir; eşlenmemiş aktif konumda vakit çekilmez, ekran "doğrula" der.
- **Şimdilik yalnız Türkiye.** Diğer ülkeler sunucuda açıldıkça uygulama değişmeden gelir (ülke seçici o zaman eklenir).

## Sonuçlar

### Olumlu

- Ekrandaki vakit Diyanet tablosuyla **birebir**; mevsimsel sapma sınıfı hata yapısal olarak kapanır.
- Hicri tarih ve dinî günler aynı kaynaktan; "bir gün kayma" biter.
- Cihazda il/ilçe listesi yok; ad/koordinat düzeltmeleri sunucuda yapılır, uygulama güncellemesi gerekmez.
- Konum verisi üçüncü taraf servislere (Aladhan, Photon, platform jeokodlama) gitmez; gizlilik beyanı sadeleşir (`docs/PRIVACY.md`).
- Hesap yöntemi/mezhep/enlem ekranları ve katalogları silindi; ayar yüzeyi küçüldü.

### Bedeller

- **Sunucu bağımlılığı.** Konum ekleme ve ilk yıl çekimi internet ister; yıllık dosya önbelleği sayesinde sonrası çevrimdışı çalışır. Sunucu Cloudflare Tunnel arkasında, cache/rate kuralları Spec A'da.
- **Yalnız Türkiye.** Türkiye dışı GPS `NO_COVERAGE` döner; kullanıcı ilçe seçmek zorundadır.
- **Migrasyon yükü.** Eski kayıtlar için bir kerelik doğrulama ekranı; aktif konum silinemez, seçilmelidir.
- API onayı gelene kadar sunucu web kaynağından beslenir (Spec A); dinî gün ve günlük içerik uçları boş döner, uygulama "veri yok" davranır.

## Değerlendirilen alternatifler

- **Aladhan + kalıcı tune.** Fark mevsimsel (±1–2 dk) olduğu için sabit kaydırma bir mevsimde doğru, diğerinde yanlış olur. Elendi.
- **Diyanet API'yi uygulamadan doğrudan çağırmak.** Kimlik bilgisi cihaza gömülür; kullanım şartına aykırı ve kota tek noktadan tükenir. Elendi (Spec A, K1).
- **Cihazda gömülü il/ilçe listesi + koordinat.** Her ad/koordinat düzeltmesi mağaza güncellemesi ister; ~900 kayıt ve alias tablosu bakımını sunucuya taşımak daha ucuz. Kullanıcı kararıyla elendi (2026-09-17).
- **Sağlayıcı arayüzünü `fetchYear(cityId, year)` olarak daraltmak.** Spec B önerisi; depo ve altı sahte sağlayıcıyı taramanın kazancı yok. Arayüz `Location` almaya devam eder, `cityId` oradan okunur (Plan B2 "Sapmalar").

## Referanslar

- Sunucu: `server/` (Go, `vakit serve|sync`), Spec A `docs/superpowers/specs/2026-09-15-vakit-api-sunucu-design.md`, Plan A `docs/superpowers/plans/2026-09-16-vakit-api-sunucu.md`
- Uygulama: Spec B `docs/superpowers/specs/2026-09-17-diyanet-uygulama-design.md`, Plan B1 `docs/superpowers/plans/2026-09-17-diyanet-uygulama-veri-katmani.md`, Plan B2 `docs/superpowers/plans/2026-09-17-diyanet-uygulama-ekranlar.md`
- Kod: `lib/features/prayer_times/data/diyanet_provider.dart`, `lib/features/location/data/places_api.dart`, `lib/features/location/data/gps_location_service.dart`, `lib/features/location/domain/location_monitor_service.dart`, `lib/features/location/domain/location_migration_service.dart`, `lib/presentation/screens/location_add_screen.dart`, `lib/presentation/screens/location_migration_screen.dart`, `lib/core/models/prayer_tune_settings.dart`
- Commit'ler: `af23e6d`, `be8b7c9`, `a5c6102`, `ed1a4ee`, `0c5a8f6`, `b7c5050`, `d188c44` (veri katmanı); `3398881`, `0283171`, `8464edf`, `f0e033b`, `2fd39cf`, `d06ef98`, `0f81b7d`, `d589ccf` (ekranlar ve temizlik)
