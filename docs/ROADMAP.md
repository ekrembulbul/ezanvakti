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

Son sürümlerde tamamlananlar (0.1.1–0.1.3):

- ✅ Bildirim planlaması 7 günlük pencereye sınırlandı ve iOS 64 bildirim sınırına göre en yakın olanlar seçilerek kontrollü kapatıldı.
- ✅ Çakışmaya dayanıklı sayısal bildirim kimlikleri; bekleyen bildirim bilgisi kimlikten doğru çözülüyor.
- ✅ Uygulama ön plana geldiğinde bildirimlerin otomatik yeniden planlanması (saatte bir throttle).
- ✅ Android 12+ exact alarm izni kapalıyken uyarı + sistem ayarlarına yönlendirme.
- ✅ Aladhan 429/5xx/zaman aşımı için sınırlı yeniden deneme + backoff (`Retry-After` uyumlu); 429'da aylık→günlük istek amplifikasyonu kaldırıldı, kalıcı sınırda önbelleğe düşülür.
- ✅ Varsayılan bildirimler yalnızca ilk açılışta bir kez oluşturulur (kalıcı DB bayrağı); kullanıcı silince konum değişiminde geri gelmiyor.
- ✅ Arka plan vakit penceresi 28 → 13 güne daraltıldı (bugünden önce 2, sonra 10 gün); gereksiz API isteği azaltıldı.
- ✅ Flutter yükseltmesi + iOS UIScene yaşam döngüsüne geçiş; iOS 26 / Xcode 26.5 ile debug modu çökmesi (EXC_BAD_ACCESS) giderildi.

Açık kalanlar:

- ~~Bildirim duplicate kontrolünün **kalıcı** (DB tabanlı) hale getirilmesi.~~ **Gerekli değil:** `scheduleNotifications` her çalışmada başta `cancelAllNotifications()` çağırıyor ve ID'ler `(gün, vakit, ofset)`'ten deterministik üretiliyor; aynı ID platformda üzerine yazılıyor. Duplicate birikme yolu yok, DB'ye taşımak gereksiz karmaşıklık olur.
- ✅ **Lokasyon değişim mantığının konsolidasyonu (manuel yol):** `HomePage._switchLocation` artık domain `LocationService.changeLocation`'a delege ediyor. `changeLocation` veri çekme sorumluluğundan arındırıldı (yalnızca aktif konum + parametre değişiminde önbellek geçersizleştirme + bildirim iptali); vakit yükleme tek pencerede (`DataLoaderService`) kalıyor, böylece çift çekim ve offline sıralama sorunu yok. **Kalan küçük takip:** GPS canlı akış yolu (`LocationMonitorController`) hâlâ doğrudan `locationRepository.setActiveLocation` kullanıyor; o da bu servise delege edilebilir.
- **Diyanet birebir vakit:** Aladhan method=13 yaklaşık hesaptır; resmi tablo için Diyanet API'si + backend proxy gerekir (bkz. PRODUCT_SPEC).

## Planlanan özellikler

> **Mimari karar — native özellikler için Flutter korunur.** Widget ve alarm gibi native
> özellikler için tamamen native (ayrı Swift + Kotlin uygulaması) yazmaya gerek **yok**.
> Bu özellikler native bir uygulamada bile native kodla yazılır; doğru yaklaşım Flutter
> çekirdeği koruyup native parçayı **platform channel + native modül** olarak eklemektir.
> Tam native'e geçiş yalnızca uygulamanın neredeyse her yeri derin platform-özel davranış
> olsaydı mantıklı olurdu — bu uygulamada paylaşılan mantık (vakit hesabı, ayarlar, bildirim)
> baskın, native dokunuş az (alarm, widget, kıble).
>
> **Sıradaki somut adım:** Küçük bir **native fizibilite spike'ı** — Android gerçek alarm
> (`AlarmManager.setAlarmClock` + full-screen intent) + iOS 26 AlarmKit + her iki platformda
> basit bir widget. Davranışı tahminle değil ölçümle netleştirip sonra tasarıma geçilecek.

### 🔔 Alarm / Ezan sesi (öncelikli)

Hedef: Vakitte yalnızca sessiz bildirim değil, **sesli alarm/ezan** çalması. İki alarm türü:
- **Sabit alarm:** kullanıcının seçtiği saat (klasik alarm).
- **Vakte çıpalı (anchored) alarm:** vakit + ofset; her gün vakit kaydıkça otomatik güncellenir.
  Asıl ihtiyaç burada: **sabah (imsaktan X dk önce/sonra — sahur, teheccüd)** ve
  **güneş (güneşten X dk önce uyanıp sabahı kerahatten önce kılmak)**. Sabit saat bunu çözmez
  çünkü vakitler yıl boyunca kayar; çıpalı alarm uygulamadaki vakit verisini kullanır.

> Not: zamanlama mantığı (vakit + `minutesBefore`) bildirim altyapısında **zaten var**; eklenecek
> asıl yeni parça **çalma/teslim katmanı** (yüksek sesle, döngüde, ertelenebilir, kilit ekranında).

**Mevcut hazırlık** (altyapı büyük ölçüde hazır):
- `flutter_local_notifications` ile exact alarm zamanlama çalışıyor.
- `ExactAlarmService` Android 12+ exact alarm iznini kontrol ediyor.
- `AndroidManifest` izinleri mevcut: `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`. Boot receiver cihaz yeniden başlatınca planları koruyacak şekilde tanımlı.

**Gerekli işler:**
- Vakit bazında "bildirim mi / alarm mı" + "sabit mi / çıpalı mı" ayrımı (mevcut `NotificationSetting` modeli `mode` ve `anchor`/`offset` alanlarıyla genişletilebilir).
- Bildirim kanalına / alarm çalma katmanına **özel ses** (ezan ses dosyası) ve ses/titreşim ayarı.
- Android'de tam ekran alarm deneyimi için **full-screen intent** bildirimi (kilit ekranında açılır, "kapat" gerektirir).
- Ayarlar ekranına: alarm aç/kapat, ses seçimi, ses düzeyi/titreşim, ertele (snooze).

**Platform stratejisi (doğrulanması önerilir):**
- **Android** 🟢 — gerçek alarm mümkün: `AlarmManager.setAlarmClock()` + full-screen intent + foreground service. exact alarm izni (mevcut) gerekir; bazı cihazlarda pil optimizasyonu gecikme yapabilir.
- **iOS 26+** 🟡 — Apple **AlarmKit** (WWDC 2025) ile 3. parti uygulamalar sessiz mod/Focus'u delen gerçek sistem alarmı kurabiliyor. Uygulama iOS 26'ya geçti; bu kapı açık. Native (platform-channel) entegrasyon gerekir, olgun hazır plugin beklenmemeli.
- **iOS < 26** 🔴 — gerçek alarm API'si yok. Pratikte **arka plan ses** hilesiyle taklit edilir (uygulama canlı kaldıkça `.playback` oturumuyla sessiz modu delip döngüde çalar). Kırılgan: kullanıcı uygulamayı force-quit ederse çalmaz, pil tüketir. `Critical Alerts` entitlement'ı genel alarm uygulamalarına pratikte verilmiyor.

> Hedef deneyim: **iOS 26+ → AlarmKit**, **eski iOS → arka plan ses (sınırları kullanıcıya dürüstçe belirtilerek)**, **Android → gerçek AlarmManager alarmı**. Kısıtlar resmî dokümanlardan doğrulanmalı (Apple AlarmKit/Critical Alerts, Android `USE_EXACT_ALARM` politikaları).

### 📍 Çoklu / favori lokasyonlar
Büyük ölçüde uygulandı: kayıtlı lokasyon listesi, ekleme (arama/GPS), düzenleme (yöntem/mezhep/isim) ve hızlı geçiş mevcut. İyileştirme: lokasyonları sıralama/etiketleme, GPS ile eklenen konuma da düzenleme akışında parametre seçimi (zaten düzenleme ekranından mümkün).

### 🌍 Yeni kaynak/ülke desteği
Aladhan koordinat tabanlı olduğundan **global vakit zaten çalışıyor**; kullanıcı konum başına hesaplama yöntemini (`method`) seçebiliyor. İleride: `PrayerTimeProvider` soyutlamasıyla farklı bir sağlayıcı (ör. backend proxy üzerinden Diyanet resmi API) eklenebilir.

### 🧩 Ana ekran widget'ı
Bir sonraki vakti + geri sayımı gösteren home screen widget'ı. Native modül işi (yukarıdaki mimari karara göre Flutter korunur):
- Widget UI'ı **native** yazılır: iOS WidgetKit/SwiftUI, Android Glance/RemoteViews. Widget ayrı process'te çalışır; içinde Flutter engine çalışamaz.
- **Asıl mühendislik işi veri paylaşımı:** widget, vakitleri Flutter'ı çalıştırmadan okumak zorunda. Vakitler native'in erişebileceği paylaşılan alana yazılmalı — iOS **App Group** (paylaşılan UserDefaults/dosya), Android SharedPreferences/dosya. Kaynak veri zaten SQLite'ta hazır; "sonraki birkaç vakit"i bu paylaşılan store'a senkronlamak gerekir.
- `home_widget` paketi Flutter↔native köprüsünü ve güncellemeyi kolaylaştırır (versiyon/güncel API doğrulanmalı).
- Widget güncelleme tetikleyicileri: veri yenilenince + zamanlanmış (iOS timeline / Android WorkManager).

### 🌐 Lokalizasyon altyapısı
Kullanıcıya görünen metinler şu an kod içinde Türkçe sabit. İleride çoklu dil için `flutter_localizations` + ARB dosyalarına taşınabilir.

## Değerlendirme aşamasındaki fikirler

- Vakit sesleri için kısa/uzun ezan seçeneği
- Ramazan / imsakiye modu (sahur–iftar geri sayımı, imsak alarmı — çıpalı alarmın doğal uzantısı)
- Kıble pusulası
- Namaz takip / kaza sayacı
- Cuma hatırlatması
- Tema seçenekleri (açık/koyu/sistem)
