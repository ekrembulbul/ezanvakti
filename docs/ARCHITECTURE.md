# Mimari

Uygulama **katmanlı (layered) + feature-first** bir mimari kullanır. Amaç: iş kurallarını UI'dan ve dış kaynaklardan (API, SQLite, platform servisleri) yalıtmak, böylece kaynak/depolama değişse bile çekirdek kurallar bozulmasın.

## Katmanlar ve bağımlılık yönü

```
presentation  ──▶  features (domain ──▶ data)  ──▶  core
     │                                                 ▲
     └─────────────────────────────────────────────────┘
```

Bağımlılıklar **içe doğru** akar: `presentation` domain'e, domain `core` soyutlamalarına bağımlıdır. `core` hiçbir üst katmana bağımlı değildir.

### `lib/core` — paylaşılan altyapı
- **`interfaces/`** — soyutlamalar: `PrayerTimeProvider`, `LocalStorage`, `NotificationService`. Üst katmanlar somut sınıflara değil bu arayüzlere bağlanır.
- **`models/`** — değer nesneleri: `PrayerTime`, `Location`, `NotificationSetting`, `calculation_params` (yöntem/mezhep katalogu). `Location`; koordinat ve etiketin yanı sıra konuma özel `method`/`school`/`latitudeAdjustmentMethod` taşır. `fromJson`/`toJson` içerir.
- **`di/service_locator.dart`** — basit, elle yazılmış servis kayıt/çözümleme (singleton). Uygulama açılışında tüm servisleri kurar ve register eder.
- **`providers/app_state.dart`** — `ChangeNotifier` tabanlı global UI state (aktif lokasyon, vakitler, yükleme durumu).
- **`services/`** — `TimezoneService`, `DstChangeDetector`, `ExactAlarmService` gibi platform/zaman yardımcıları.
- **`theme/`**, **`utils/`**, **`constants/`**, **`errors/`**, **`exceptions/`**.

### `lib/features` — iş alanları
Her feature kendi içinde `data/` (dış dünya) ve `domain/` (iş kuralları) olarak ikiye ayrılır:

| Feature | data | domain |
|---|---|---|
| `prayer_times` | `diyanet_provider` (`vakit-api`, yıllık dosya + ETag), `sqlite_storage` | `prayer_times_repository`, `offline_state_manager`, `prayer_time_tuner` |
| `notifications` | `flutter_local_notification_service` | `notification_scheduler`, `notification_settings_manager` |
| `location` | `places_api` (sunucuda il/ilçe araması + koordinat→ilçe), `gps_location_service` (izin + cihaz koordinatı + çözümleme) | `location_repository`, `location_service`, `location_monitor_service`, `location_migration_service` |
| `home_widget` | `home_widget_publisher` (App Group'a yazma) | `widget_snapshot`, `widget_snapshot_builder`, `widget_snapshot_publish` |

### `lib/presentation` — UI
- **`pages/`** — `AppRoot` (ilk açılış yönlendirmesi), `HomePage` (ana orkestrasyon).
- **`screens/`** — ekranlar (home, calendar, settings, location, notification ayarları).
- **`widgets/`** — yeniden kullanılabilir UI parçaları (feature'a göre gruplu).
- **`controllers/`**, **`services/`** — UI'a özel ince koordinasyon (örn. GPS izleme kontrolcüsü).

## Vakit kaynağı: Diyanet, kendi sunucumuzdan (ADR 0006)

Vakit kaynağı `PrayerTimeProvider` arayüzünün arkasındadır; tek implementasyon `DiyanetProvider`. Veri, `server/` altındaki Go servisinin (`vakit`) `/v1` sözleşmesinden gelir — bkz. `docs/superpowers/specs/2026-09-15-vakit-api-sunucu-design.md` ve `server/README.md`. Sunucu adresi derleme zamanında verilir (`--dart-define=VAKIT_API_BASE_URL`, `lib/core/config/vakit_api_config.dart`; varsayılan yerel geliştirme adresi).

- **Yıllık dosya:** `GET /v1/prayer-times/{cityId}/{year}` istenen aralığın yıllarını çeker; depo hepsini gün gün (Hicri tarihle birlikte) önbelleğe yazar, çağırana yalnız istenen pencereyi döner. `If-None-Match`/ETag `settings` tablosunda; `304` önbelleği geçerli sayar, `404` (yıl yayınlanmamış) boş liste döner.
- **Düzeltme okurken uygulanır** (`PrayerTimeTuner`, ADR 0004): önbellek ham Diyanet verisi; kullanıcının tek ayarı vakit başına ± dakika (`PrayerTuneSettings`). Hesap yöntemi/mezhep/enlem seçimi yoktur.
- **Hicri tarih** her günün satırında Diyanet'ten gelir; hesaplanmaz. Veri yoksa gösterilmez (Ramazan modu ve dinî günler de aynı veriden türetilir).

## Konum: Diyanet ilçesi

- **Model:** `Location` bir Diyanet ilçesidir (`cityId/stateId/countryId`, sunucunun `displayLabel`'ı). Koordinat yalnız kıble içindir: GPS kaydında cihazın koordinatı, seçilmiş konumda sunucudan ilçe merkezi. `cityId` yoksa kayıt "eşlenmemiş"tir (eski sürümden kalan).
- **Arama:** `PlaceSearchPanel` → `PlacesApi.search` (`GET /v1/places/search?q=&limit=`). Boş sorgu il merkezlerini döner; 300 ms debounce, 2 karakter alt sınırı. Cihazda il/ilçe listesi yok.
- **GPS:** `GpsLocationService.locate` izin akışı + cihaz koordinatı + `PlacesApi.resolve` (`GET /v1/places/resolve?lat&lon`). Ekleme ekranı sonucu onay bandıyla gösterir. Türkiye dışı `NO_COVERAGE` → kullanıcı ilçe seçer. Ters-geocode ve üçüncü taraf adres servisi yok.
- **İzleme:** `LocationMonitorService` 5 km / 30 dk eşiklerini korur; yeni fix `resolve` ile ilçeye çözülür. Yalnız `cityId` değişince kayıt güncellenir, önbellek temizlenir ve `onLocationChanged` yayılır; aynı ilçe içinde koordinat sessizce tazelenir. Ağ yoksa deneme atlanır (referans güncellenmez, sonraki fix dener).
- **Önbellek tutarlılığı:** `prayer_times` tablosu `location_id` ile anahtarlı. Konumun ilçesi değişince (düzenleme ekranı, GPS başka ilçeye geçti, yeniden ekleme) o kimliğin önbelleği `clearPrayerTimeCache` ile temizlenir; koordinat oynaması önbelleği etkilemez.
- **Migrasyon:** Açılışta (`AppRoot`) eşlenmemiş kayıt varsa `LocationMigrationService` sunucuda eşler (GPS: `resolve`; manuel: ada göre arama, il **ve** ilçe tutarsa otomatik). Belirsiz/desteklenmeyen kayıtlar `LocationMigrationScreen`'de seçtirilir; ağ yoksa ertelenir, eşlenmemiş aktif konumda ana ekran "doğrula" mesajı verir.

## Veri akışı — vakit gösterimi

```
HomePage / DataLoaderService
        │  ister
        ▼
PrayerTimesRepository ──┬─▶ DiyanetProvider (vakit-api) → yıl dosyasını SQLite'a yazar
                        └─▶ SqliteStorage (cache)       → offline / fallback
        │
        ▼
   AppState (ChangeNotifier) ──▶ UI rebuild
```

- **Online:** Repository API'den çeker, SQLite'a yazar, "son güncelleme zamanı"nı kaydeder.
- **Offline / API hatası:** Repository cache'e düşer; `OfflineStateManager` cache tazeliğini (stale/expired) belirler ve UI uygun mesajı gösterir.

## Veri akışı — bildirim planlama

```
NotificationSettingsManager (kullanıcı tercihleri, SQLite)
        │
        ▼
NotificationScheduler ──▶ NotificationService (flutter_local_notifications)
        │                         │
   vakitler × ayarlar        timezone-aware zamanlama (exact alarm + fallback)
```

- Her vakit için iki tetik mümkün: tam vakit (offset 0) ve X dk önce.
- Lokasyon/kaynak değişiminde eski planlar iptal edilip yenileri kurulmalıdır.
- Android 12+ için exact alarm izni `ExactAlarmService` ile kontrol edilir; izin yoksa inexact zamanlamaya düşülür.

## Veri akışı — sesli alarm ve görev

`AlarmsManager` tanım değişikliklerini `AlarmScheduler` ile aynı kuyruğa alır. Scheduler güncel SQLite tanımlarından protocolVersion=2 istenen planı üretir; toplu iptal yapmaz. iOS `AlarmPlanEngine` + `AlarmKitPlatform`, Android `AlarmReconciler` + `AlarmScheduling` değişmeyen kayıtları ve etkin görev zincirlerini koruyarak planı uygular. Silme/pasifleştirme tüm kökü kapatır.

Görev ve erteleme durumu native depoda tutulur. `MissionCoordinator` tekrar okunabilen snapshot'lardan tek ekran seçer; `AppState` bütün bekleyen oturumları saklar. Komutlar kök id ile birlikte asıl çalma zamanını taşır. iOS arka plan Stop aksiyonu ve uygulamayı açan görev aksiyonu ayrıdır.

Ayrıntılı kontrat ve hata davranışları: [alarm motoru tasarımı](superpowers/specs/2026-09-08-alarm-engine-design.md).

## Veri akışı — iOS widget

```
_loadPrayerData (home_page.dart)
        │  başarılı yükleme sonrası
        ▼
WidgetSnapshotBuilder (saf) ──▶ WidgetPublisher ──▶ App Group (tek JSON)
                                                            │
                                            WidgetKit extension (ayrı process)
```

- Payload 7 gün taşır; widget uygulama açılmadan da doğru kalır.
- Saatler `"HH:mm"` olarak yazılır, offset'li ISO değil — uygulama vakitleri
  timezone taşımayan cihaz-yerel wall-clock olarak üretiyor
  (`awqat_salah_provider.dart:407`). Offset yazmak widget'a uygulamada olmayan
  bir semantik uydurmak olurdu.
- **Sıradaki vakit ve gün dilimi Swift tarafında hesaplanır** (`ios/WidgetCore/`).
  Snapshot'a yazılsaydı widget, uygulama açılmadıkça bir sonraki vakte
  geçemezdi.
- Yayınlama hatası yukarı sızmaz; vakit gösterimi widget yüzünden bozulmaz.
- Görünüm ayarı (tema, vakte göre renk, sabit palet) snapshot'tan ayrı bir
  anahtarla (`ezanvakti_appearance`) gider; `ThemeController` her değişimde ve
  açılışta yazar. Widget ayrı süreçte uygulamanın temasını göremez; bu yayın
  olmadan yalnızca cihazın görünümünü izler.
- Sorumluluk sınırı testlerin de sınırı: paketleme Dart'ta (`test/home_widget/`),
  yorumlama Swift'te (`ios/RunnerTests/`) sınanır.
- Payload'da her gün kendi **hicri tarihini** taşır (Diyanet verisi). Swift'te
  hesaplanmaz: iOS'un `islamicUmmAlQura` takvimi Diyanet takviminden gün
  kayabilir. Veri yoksa alan `null`, satır gizlenir.
- Timeline yalnızca **vakit sınırlarında** giriş üretir (48 saat ufuk). Geri
  sayımı sistemin aralık sayacı (`Text(timerInterval:)`) çizer. Sayaç hedef
  tarihten hesaplandığı için hangi girişin ekranda olduğu önemsiz. Kilit
  ekranı widget'ı Always-On'da (`isLuminanceReduced`) sayacı gizler: orada
  yanlış kalan süre gösteriyordu (2026-09-14 cihaz gözlemi).
- Hizalama `AppIntentConfiguration` ile widget ayarıdır.

## Zaman / timezone

- `TimezoneService` `timezone` paketini başlatır (şu an `Europe/Istanbul`).
- Bildirim zamanları timezone-aware planlanır; `DstChangeDetector` yaz saati geçişlerini saptayıp yeniden planlama gereğini belirtir.

## Tasarım kararları ve sınırlar

- **DI:** Olgun bir paket (örn. `get_it`) yerine ~9 servislik basit elle yazılmış locator yeterli görüldü. Servis sayısı/karmaşıklığı artarsa `get_it`'e geçiş değerlendirilebilir.
- **State:** Tek `AppState` ChangeNotifier. Ekran sayısı artarsa feature bazlı provider'lara bölünebilir.
- **Sunucu yok:** Hesap, senkronizasyon, remote config kapsam dışı (bkz. [PRODUCT_SPEC.md](PRODUCT_SPEC.md)).
