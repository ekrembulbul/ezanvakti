# Ezan Vakti — Hatırlatıcı

Türkiye için namaz vakitlerini gösteren ve vakitlere göre bildirim/hatırlatma gönderen bir Flutter mobil uygulaması (Android + iOS). Vakit verisi **Awqat Salah API** (Diyanet kaynaklı) üzerinden alınır, cihazda SQLite ile saklanır ve internet olmadan da çalışır.

> Vakitler cihazda yerel tutulur; kullanıcı verisi hiçbir sunucuya gönderilmez.

## Özellikler

- 🕌 Günün namaz vakitleri + bir sonraki vakte geri sayım
- 📅 30 güne kadar vakit takvimi
- 🔍 Online adres araması (Photon/OpenStreetMap, global) veya GPS ile otomatik konum
- ⚙️ Konuma özel hesaplama yöntemi (Diyanet vb.) ve İkindi mezhebi (Şafi/Hanefi)
- 🔔 Vakit bazlı bildirimler: tam vaktinde ve/veya X dakika önce
- 📴 Offline çalışma — son çekilen vakitler cache'den gösterilir (yeni konum eklemek internet ister)
- 🌙 Hicri tarih gösterimi
- 🌑 Karanlık tema

## Teknoloji

| Alan | Seçim |
|---|---|
| Framework | Flutter (Dart SDK `^3.10.4`) |
| State yönetimi | `provider` (ChangeNotifier) |
| Yerel depolama | `sqflite` (SQLite) |
| Bildirimler | `flutter_local_notifications` + `timezone` |
| Konum | `geolocator` (GPS), `geocoding` (reverse-geocode), Photon/OSM (adres araması) |
| Vakit kaynağı | Aladhan API (koordinat tabanlı, `method`=Diyanet vb.) |
| HTTP | `http` |
| Loglama | `logger` |

## Hızlı Başlangıç

Gereksinimler: [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable), Android Studio/Xcode.

```bash
# Bağımlılıkları kur
flutter pub get

# iOS için (yalnızca macOS'ta, ilk kurulumda veya plugin değişince)
pod install --project-directory=ios

# Bağlı cihazları listele
flutter devices

# Çalıştır (cihazı -d ile belirtmek en güvenlisi)
flutter run -d "iPhone 17"     # iOS simulator
flutter run -d emulator-5554   # Android emulator
```

Ayrıntılı geliştirici kurulumu, iOS pod sorunları ve konvansiyonlar için **[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)**.

## Proje Yapısı

Katmanlı (layered) mimari kullanılır: `core` (paylaşılan altyapı), `features` (iş alanları) ve `presentation` (UI).

```
lib/
├── core/            # constants, models, interfaces, DI, theme, utils, services
├── features/        # prayer_times, notifications, location (data + domain)
├── presentation/    # screens, pages, widgets, controllers, presentation services
└── main.dart        # uygulama girişi + ServiceLocator başlatma
```

Mimarinin detayları (veri akışı, DI, provider soyutlaması): **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

## Test

```bash
flutter test                 # tüm testler
flutter test test/notifications/notifications_test.dart   # tek dosya
```

Testler `test/` altında, kaynak yapısını (`prayer_times`, `notifications`, `location`, `offline`, …) yansıtır.

## Dokümantasyon

| Doküman | İçerik |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Katmanlar, bağımlılık yönü, veri akışı, DI |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Kurulum, çalıştırma, test, kod konvansiyonları |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Mevcut durum ve planlanan özellikler (alarm dahil) |
| [docs/PRODUCT_SPEC.md](docs/PRODUCT_SPEC.md) | Ürün sınırları ve iş kuralları |
| [docs/PLAN_CHECKLIST.md](docs/PLAN_CHECKLIST.md) | MVP checklist |

## Konvansiyon

Tüm kod (dosya, değişken, sınıf, fonksiyon adları) **İngilizce** yazılır. Yalnızca kullanıcıya görünen metinler ve dokümantasyon Türkçedir.
