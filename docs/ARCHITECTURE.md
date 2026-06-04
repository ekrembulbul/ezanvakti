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
| `prayer_times` | `awqat_salah_provider` (API), `sqlite_storage` | `prayer_times_repository`, `offline_state_manager` |
| `notifications` | `flutter_local_notification_service` | `notification_scheduler`, `notification_settings_manager` |
| `location` | `photon_geocoding_service` (online adres araması), `place_suggestion`, `gps_label` | `location_repository`, `location_service`, `location_monitor_service` |

### `lib/presentation` — UI
- **`pages/`** — `AppRoot` (ilk açılış yönlendirmesi), `HomePage` (ana orkestrasyon).
- **`screens/`** — ekranlar (home, calendar, settings, location, notification ayarları).
- **`widgets/`** — yeniden kullanılabilir UI parçaları (feature'a göre gruplu).
- **`controllers/`**, **`services/`** — UI'a özel ince koordinasyon (örn. GPS izleme kontrolcüsü).

## Provider soyutlaması (genişleme noktası)

Vakit kaynağı `PrayerTimeProvider` arayüzünün arkasındadır. Bugün tek implementasyon var: `AwqatSalahProvider` (Diyanet). Yeni bir ülke/kaynak eklemek için:

1. `PrayerTimeProvider`'ı implement eden yeni bir sınıf yaz (kaynağa özgü parse).
2. `ServiceLocator`'da register et.

Uygulamanın geri kalanı `PrayerTimeProvider` arayüzüne bağlı olduğu için değişmeden çalışır. `AwqatSalahProvider` koordinat tabanlı Aladhan API'sini kullanır; namaz açıları konuma özel `method` (otorite, ör. Diyanet=13) ve `school` (İkindi mezhebi) parametreleriyle istenir.

## Lokasyon seçimi ve hesaplama parametreleri

- **Adres araması:** `PhotonGeocodingService` (Photon/OpenStreetMap, anahtarsız, global, debounce + konum bias'lı typeahead). Sonuç `PlaceSuggestion` → `Location`'a çevrilir. Eski gömülü il/ilçe listesi kaldırıldı; vakit yalnızca koordinata bağlı olduğundan eksiksiz liste tutmaya gerek yok.
- **GPS:** Ham koordinat doğrudan API'ye gider; il/ilçe yalnızca etikettir (`gps_label` ile reverse-geocode). Listeye snap yapılmaz.
- **Hesaplama parametreleri konuma özeldir** (`method`/`school`/`latitudeAdjustmentMethod`). Varsayılan: Diyanet (13) + standart/Şafi İkindi (school=0) — Diyanet takvimi asr-ı evvel'i kullanır. Yöntem değişince İkindi mezhebi bölgesel varsayılana (`CalculationDefaults.schoolForMethod`) ayarlanır.
- **Önbellek tutarlılığı:** `prayer_times` tablosu `location_id` ile anahtarlı, parametrelerle değil. Bu yüzden bir konumun parametreleri değişince (düzenleme ekranı, yeniden ekleme, GPS hareketi) o konumun önbelleği `clearPrayerTimeCache` ile temizlenir; sonraki yükleme güncel parametrelerle taze çeker.

## Veri akışı — vakit gösterimi

```
HomePage / DataLoaderService
        │  ister
        ▼
PrayerTimesRepository ──┬─▶ AwqatSalahProvider (API)   → başarılıysa SQLite'a yazar
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

## Zaman / timezone

- `TimezoneService` `timezone` paketini başlatır (şu an `Europe/Istanbul`).
- Bildirim zamanları timezone-aware planlanır; `DstChangeDetector` yaz saati geçişlerini saptayıp yeniden planlama gereğini belirtir.

## Tasarım kararları ve sınırlar

- **DI:** Olgun bir paket (örn. `get_it`) yerine ~9 servislik basit elle yazılmış locator yeterli görüldü. Servis sayısı/karmaşıklığı artarsa `get_it`'e geçiş değerlendirilebilir.
- **State:** Tek `AppState` ChangeNotifier. Ekran sayısı artarsa feature bazlı provider'lara bölünebilir.
- **Sunucu yok:** Hesap, senkronizasyon, remote config kapsam dışı (bkz. [PRODUCT_SPEC.md](PRODUCT_SPEC.md)).
