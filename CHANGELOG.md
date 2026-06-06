# Değişiklik Günlüğü

Bu projedeki dikkate değer değişiklikler bu dosyada belgelenir.
Biçim [Keep a Changelog](https://keepachangelog.com/tr/1.0.0/) temellidir ve
proje [Semantic Versioning](https://semver.org/lang/tr/) kullanır.

## [0.1.5] - 2026-06-06

Mağaza çıkışı hazırlığı (iOS TestFlight).

### Değiştirildi
- Uygulama adı "Ezan Vakti - Hatırlatıcı"dan **"Ezan Vakti & Alarm"a** güncellendi.
- Android uygulama kimliği gerçek pakete taşındı (`com.example.ezanvakti` → `com.ekrembulbul.ezanvakti`); iOS bundle kimliğiyle tutarlı hâle getirildi.

### Eklendi
- Gizlilik politikası taslağı (konum ve üçüncü taraf servis kullanımını açıklar).
- Android release imzalama altyapısı (`key.properties` deseni; anahtar repoya konmaz).
- iOS export compliance beyanı (yalnızca standart HTTPS; `ITSAppUsesNonExemptEncryption=false`).
- iOS TestFlight yükleme otomasyon scripti (`scripts/release_ios.sh`): sürüm/build yönetimi, IPA derleme ve yükleme tek komutta.

## [0.1.4] - 2026-06-06

İç iyileştirme.

### Değiştirildi
- Konum değişim mantığı tek kanonik yola indirildi: aktif konum ayarlama, hesaplama parametresi değişiminde önbellek geçersizleştirme ve bildirim iptali artık `LocationService.changeLocation` üzerinden yürür; vakit yükleme tek pencerede kalır. Konum değişiminde oluşabilecek gereksiz çift veri çekimi ve nadir bir bildirim-iptali sıralama sorunu giderildi.

## [0.1.3] - 2026-06-06

Performans iyileştirmesi.

### Değiştirildi
- Arka planda tutulan vakit penceresi daraltıldı: bugünden önce 7 yerine 2 gün, sonra 21 yerine 10 gün (toplam 28 → 13 gün). Gereksiz API isteği azaltıldı; 7 günlük bildirim planlama penceresi tamponuyla korundu.

## [0.1.2] - 2026-06-05

Kararlılık düzeltmeleri.

### Düzeltildi
- Aladhan API hız sınırı (429) yönetimi: geçici hatalarda (429/5xx/zaman aşımı) sınırlı yeniden deneme ve bekleme (backoff) uygulanır, `Retry-After` başlığına uyulur. Hız sınırı aşıldığında aylık uçtan günlük uca düşüp istek sayısını katlama davranışı kaldırıldı; kalıcı sınırda önbelleğe düşülür.
- Kullanıcı tüm bildirimleri silse bile konum değiştirince varsayılanların geri gelmesi giderildi; varsayılan bildirimler artık yalnızca ilk açılışta bir kez oluşturulur.

### Değiştirildi
- Flutter sürümü yükseltildi; iOS 26 / Xcode 26.5 ile debug modunda yaşanan başlatma çökmesi (EXC_BAD_ACCESS) giderildi ve iOS UIScene yaşam döngüsüne geçildi.

## [0.1.1] - 2026-06-05

Bildirim güvenilirliği düzeltmeleri.

### Eklendi
- Uygulama ön plana geldiğinde bildirimler otomatik yeniden planlanır; kullanıcı uzun süre açmasa bile kapsama güncel kalır.
- Android 12+ exact alarm izni kapalıyken uyarı ve sistem ayarlarına yönlendirme.

### Düzeltildi
- Bildirim planlaması 7 günlük pencereye sınırlandı ve iOS'un 64 bildirim sınırına göre kapatıldı (aşırı planlama ve sessizce düşen bildirimler giderildi).
- Bildirim kimlikleri çakışmaya dayanıklı sayısal değere geçti.
- Bekleyen bildirim bilgisi artık kimlikten doğru çözülüyor.
- Bildirim izni alınamadığında daha güvenli (false) varsayım.

### Değiştirildi
- Bildirim ayarı ekleme/silme depolama arayüzüne taşındı (iç refaktör).

## [0.1.0] - 2026-06-04

İlk sürüm. Türkiye odaklı, global desteğe de açık bir namaz vakti ve hatırlatma uygulaması (Android + iOS). Vakitler **Aladhan API** ile koordinat tabanlı hesaplanır, cihazda saklanır ve internet olmadan da görüntülenir; kişisel veri hiçbir sunucuya gönderilmez.

**Konum**
- Online adres araması (Photon / OpenStreetMap, anahtarsız, global) veya GPS ile otomatik konum.
- Birden çok kayıtlı konum; ekleme, düzenleme ve hızlı geçiş.
- İlk konum eklenince ülkeye göre bölgesel varsayılan hesaplama yöntemi.

**Hesaplama**
- Uygulama geneli varsayılan + konuma özel override: yöntem (Diyanet vb.), İkindi mezhebi (Şafi/Hanefi) ve yüksek enlem düzeltmesi.
- Türkiye varsayılanı Diyanet; İkindi asr-ı evvel (standart/Şafi) ile hesaplanır.

**Vakitler ve bildirimler**
- Günün vakitleri, sonraki vakte geri sayım ve 30 günlük takvim.
- Vakit bazlı bildirimler: tam vaktinde ve/veya X dakika önce, izin yönetimiyle.
- Hicri tarih gösterimi ve offline çalışma (vakitler cihazda SQLite ile saklanır).

**Arayüz**
- Her ekran boyutuna uyan, kaydırmasız ana ekran; karanlık tema.
- Takvim, bildirim ve ayarları toplayan modern menü.

[0.1.5]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.5
[0.1.4]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.4
[0.1.3]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.3
[0.1.2]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.2
[0.1.1]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.1
[0.1.0]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.0
