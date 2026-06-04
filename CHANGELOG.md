# Değişiklik Günlüğü

Bu projedeki dikkate değer değişiklikler bu dosyada belgelenir.
Biçim [Keep a Changelog](https://keepachangelog.com/tr/1.0.0/) temellidir ve
proje [Semantic Versioning](https://semver.org/lang/tr/) kullanır.

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

İlk sürüm. Türkiye odaklı, global desteğe açık namaz vakti ve hatırlatma uygulaması.

### Eklendi
- Online adres araması (Photon / OpenStreetMap, global, anahtarsız) ve GPS ile konum seçimi.
- Konuma özel ve uygulama geneli **hesaplama ayarları**: yöntem (Diyanet vb.), İkindi mezhebi (Şafi/Hanefi), yüksek enlem düzeltmesi.
- Kayıtlı konumları düzenleme ekranı ("genel ayarı kullan" veya konuma özel override).
- İlk konum eklenince ülkeye göre **bölgesel varsayılan** hesaplama yöntemi.
- Modern ana ekran menüsü: Takvim, Bildirimler, Ayarlar.
- Vakit bazlı bildirimler (tam vaktinde ve/veya X dakika önce), izin yönetimi.
- 30 günlük vakit takvimi, sonraki vakte geri sayım, Hicri tarih.
- Offline çalışma: son çekilen vakitler cihazda (SQLite) saklanır.

### Değiştirildi
- Ana ekran artık scroll'suz; her ekran boyutunu tam kaplar. Geri sayım ve vakit kartı kalan alanı oransal paylaşıp birlikte ölçeklenir.
- Ayarlar ekranı gruplu, modern liste tasarımına geçti.
- Konum mimarisi koordinat tabanlı hale getirildi; gömülü il/ilçe listesi kaldırıldı.
- Vakitler **Aladhan API** üzerinden alınır (etiketler buna göre düzeltildi); hesaplama yöntemi kullanıcı tarafından değiştirilebilir.

### Düzeltildi
- Photon arama 403/400 hataları (tanımlayıcı User-Agent ve desteklenmeyen `lang` parametresinin kaldırılması).
- Başlıkta uzun/yabancı konum adının taşması (RenderFlex overflow).
- GPS konum değişiminde vakit önbelleğinin tutarlılığı.
- Diyanet İkindi varsayılanı asr-ı evvel (standart/Şafi) olarak düzeltildi.

[0.1.1]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.1
[0.1.0]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.0
