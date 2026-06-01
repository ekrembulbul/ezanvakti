# Yol Haritası

Mevcut durum, kısa vadeli iyileştirmeler ve planlanan özellikler. Ürün sınırları için [PRODUCT_SPEC.md](PRODUCT_SPEC.md)'e bakın.

## Mevcut durum (MVP)

- ✅ İl/ilçe ve GPS ile lokasyon seçimi
- ✅ Günün vakitleri + geri sayım, 30 günlük takvim
- ✅ Awqat Salah (Diyanet) kaynağı, SQLite cache, offline gösterim
- ✅ Vakit bazlı bildirimler (tam vakit + X dk önce), izin yönetimi
- ✅ Hicri tarih, karanlık tema

## Kısa vadeli iyileştirmeler (teknik borç)

Bu maddeler kod denetiminde tespit edildi:

- Lokasyon değişiminde bildirimlerin **yeniden planlanması** (şu an yalnızca iptal ediliyor).
- GPS izleme stream'inde **subscription temizliği** (memory leak).
- API çağrılarına **timeout** ve hata kategorilendirmesi (4xx/5xx).
- Loglamada **debug/release ayrımı** ve hassas veri (koordinat) loglamama.
- Modellerde `==`/`hashCode`/`copyWith` tamamlama.
- Bildirim duplicate kontrolünün **kalıcı** (DB tabanlı) hale getirilmesi.
- **Lokasyon değişim mantığının konsolidasyonu:** Canlı akış bildirimleri `HomePage` içinde yeniden planlıyor; ayrıca test edilmiş ama UI'a bağlanmamış bir `LocationService.changeLocation` (domain) var. Tek kanonik yola indirgenmeli (home_page bu servise delege etmeli).

## Planlanan özellikler

### 🔔 Alarm / Ezan sesi (öncelikli)

Hedef: Vakitte yalnızca sessiz bildirim değil, **sesli alarm/ezan** çalması.

**Mevcut hazırlık** (altyapı büyük ölçüde hazır):
- `flutter_local_notifications` ile exact alarm zamanlama çalışıyor.
- `ExactAlarmService` Android 12+ exact alarm iznini kontrol ediyor.
- `AndroidManifest` izinleri mevcut: `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`. Boot receiver cihaz yeniden başlatınca planları koruyacak şekilde tanımlı.

**Gerekli işler:**
- Bildirim kanalına **özel ses** (azan ses dosyası) ve ses/titreşim ayarı eklemek.
- Android'de tam ekran alarm deneyimi için **full-screen intent** bildirimi (kilit ekranında açılır, "kapat" gerektirir).
- Ayarlar ekranına: alarm aç/kapat, ses seçimi, ses düzeyi/titreşim seçenekleri.
- Vakit bazında "bildirim mi / alarm mı" ayrımı (mevcut `NotificationSetting` modeli bir `mode` alanıyla genişletilebilir).

**⚠️ Platform kısıtları (doğrulanması önerilir):**
- **iOS**, üçüncü taraf uygulamaların güvenilir şekilde yüksek sesli/sürekli alarm çalmasına büyük ölçüde izin vermez. Standart bildirim sesi ~30 sn ile sınırlı ve sessiz moddan etkilenebilir. Gerçek "kritik alarm" için Apple'ın **Critical Alerts** entitlement'ı gerekir (özel başvuru/onay gerektirir). Bu nedenle iOS'ta deneyim Android'den farklı/sınırlı olabilir.
- **Android** tarafında tam ekran alarm + özel ses büyük ölçüde mümkündür; pil optimizasyonları bazı cihazlarda gecikmeye yol açabilir.

> Bu kısıtlar resmî platform dokümanlarından doğrulanmalıdır (Apple Critical Alerts, Android `USE_EXACT_ALARM` politikaları). Tasarımı netleştirmeden önce iOS hedef deneyiminin ne olacağına karar verilmeli.

### 📍 Çoklu / favori lokasyonlar
`LocalStorage` arayüzü zaten `getSavedLocations`/`saveLocation`/`updateLocation`/`deleteLocation` içeriyor — altyapı kısmen hazır. UI'da favori lokasyon listesi ve hızlı geçiş eklenebilir.

### 🌍 Yeni kaynak/ülke desteği
`PrayerTimeProvider` soyutlaması sayesinde yeni bir kaynak eklemek mimari olarak mümkün. Ayarlarda kaynak seçimi UI'ı eklenebilir.

### 🧩 Ana ekran widget'ı
Bir sonraki vakti gösteren home screen widget'ı (platforma özgü iş). MVP sonrası.

### 🌐 Lokalizasyon altyapısı
Kullanıcıya görünen metinler şu an kod içinde Türkçe sabit. İleride çoklu dil için `flutter_localizations` + ARB dosyalarına taşınabilir.

## Değerlendirme aşamasındaki fikirler

- Vakit sesleri için kısa/uzun ezan seçeneği
- Kıble pusulası
- Namaz takip / kaza sayacı
- Tema seçenekleri (açık/koyu/sistem)
