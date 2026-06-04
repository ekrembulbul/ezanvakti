# Yol Haritası

Mevcut durum, kısa vadeli iyileştirmeler ve planlanan özellikler. Ürün sınırları için [PRODUCT_SPEC.md](PRODUCT_SPEC.md)'e bakın.

## Mevcut durum (MVP)

- ✅ Online adres araması (Photon/OSM, global typeahead) ve GPS ile lokasyon seçimi
- ✅ Konuma özel hesaplama yöntemi (Diyanet vb.) ve İkindi mezhebi; konum düzenleme ekranı
- ✅ Günün vakitleri + geri sayım, 30 günlük takvim
- ✅ Aladhan (Diyanet method=13) kaynağı, SQLite cache, offline gösterim
- ✅ Vakit bazlı bildirimler (tam vakit + X dk önce), izin yönetimi
- ✅ Hicri tarih, karanlık tema

## Kısa vadeli iyileştirmeler (teknik borç)

Tamamlananlar (önceki refactor + konum çalışması):

- ✅ Lokasyon değişiminde bildirimlerin yeniden planlanması.
- ✅ GPS izleme stream subscription temizliği (memory leak).
- ✅ API çağrılarına timeout; parse/ağ hatalarının ayrıştırılması.
- ✅ Loglamada debug/release ayrımı ve koordinat loglamama (gizlilik).
- ✅ Modellerde `==`/`hashCode`/`copyWith`.

Açık kalanlar:

- Bildirim duplicate kontrolünün **kalıcı** (DB tabanlı) hale getirilmesi.
- **Lokasyon değişim mantığının konsolidasyonu:** Canlı akış bildirimleri `HomePage` içinde yeniden planlıyor; ayrıca test edilmiş ama UI'a bağlanmamış bir `LocationService.changeLocation` (domain) var (artık parametre değişiminde önbellek temizliği de içeriyor). Tek kanonik yola indirgenmeli (home_page bu servise delege etmeli).
- **Diyanet birebir vakit:** Aladhan method=13 yaklaşık hesaptır; resmi tablo için Diyanet API'si + backend proxy gerekir (bkz. PRODUCT_SPEC).

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
Büyük ölçüde uygulandı: kayıtlı lokasyon listesi, ekleme (arama/GPS), düzenleme (yöntem/mezhep/isim) ve hızlı geçiş mevcut. İyileştirme: lokasyonları sıralama/etiketleme, GPS ile eklenen konuma da düzenleme akışında parametre seçimi (zaten düzenleme ekranından mümkün).

### 🌍 Yeni kaynak/ülke desteği
Aladhan koordinat tabanlı olduğundan **global vakit zaten çalışıyor**; kullanıcı konum başına hesaplama yöntemini (`method`) seçebiliyor. İleride: `PrayerTimeProvider` soyutlamasıyla farklı bir sağlayıcı (ör. backend proxy üzerinden Diyanet resmi API) eklenebilir.

### 🧩 Ana ekran widget'ı
Bir sonraki vakti gösteren home screen widget'ı (platforma özgü iş). MVP sonrası.

### 🌐 Lokalizasyon altyapısı
Kullanıcıya görünen metinler şu an kod içinde Türkçe sabit. İleride çoklu dil için `flutter_localizations` + ARB dosyalarına taşınabilir.

## Değerlendirme aşamasındaki fikirler

- Vakit sesleri için kısa/uzun ezan seçeneği
- Kıble pusulası
- Namaz takip / kaza sayacı
- Tema seçenekleri (açık/koyu/sistem)
