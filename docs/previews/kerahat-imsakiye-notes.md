# Kerahat ve Ramazan imsakiyesi — tasarım önerisi

Durum: araştırma ve tasarım; uygulama koduna alınmadı. Kullanıcının yerleşim ve hesap yaklaşımı kararı bekleniyor. Önizlemedeki tüm saatler örnektir; canlı namaz vakti veya gerçek imsakiye verisi değildir.

## Mevcut durum

- [Takvim](../../lib/presentation/screens/calendar_screen.dart) başlığı yalnızca bugünün hicri ayı Ramazan ise “Ramazan İmsakiyesi” oluyor. Yıl boyunca erişilen bağımsız imsakiye ve ay/yıl seçimi yok.
- [Veri yükleyici](../../lib/presentation/services/data_loader_service.dart) bugünden iki gün önce ile on gün sonrasını istiyor. Mevcut tablo tam Ramazan ayını göstermiyor.
- Ramazan sayacı ve oruç takibi var. Tasarım belgesindeki İmsak/Akşam sütunu vurgusu ve tam imsakiye paylaşımı mevcut takvimde tamamlanmış değil.
- [Türetilmiş vakitler](../../lib/features/prayer_times/domain/derived_times.dart) güneş +45 dk, öğle −10 dk ve akşam −45 dk noktalarını hesaplıyor. Bunlara Hatırlatıcılar → Bildirimler → + → Türetilmiş Vakitler yolundan bildirim eklenebiliyor. Ana ekranda sürekli kerahat aralığı gösterimi yok.

## Araştırma ve önerilen hesap

[Diyanet Din İşleri Yüksek Kurulu](https://kurul.diyanet.gov.tr/tr/fetva/mekruh-vakitler-hangileridir-hangi-vakitlerde-kaza-ve-hangi-vakitlerde-nafile-namaz-kilinmaz/0193c42d-52b7-7186-d5b4-f1d3c950ad73), mutedil bölgelerde doğuştan sonra 40–50 dakika, öğle öncesinde yaklaşık 10 dakika ve batıştan önce 40–50 dakika açıklıyor. Bu kaynak, genel bir 30 dakika kuralını doğrulamıyor.

Öneri: mevcut **45/10/45 dakika** değerlerini yaklaşık gösterim olarak kullanmak. Bunlar her enlem ve mevsim için kesin astronomik sınır diye sunulmamalı. Namaz türü ve mezhebe göre istisnalar olduğu için “hiçbir namaz kılınamaz” gibi genel bir yasak metni kullanılmamalı.

## Vakitler ekranı

1. Mevcut ana sayaç sıradaki namaz vaktini göstermeye devam eder.
2. 24 saatlik cetvel üzerinde üç yaklaşık kerahat aralığı bordo olur. Dolgu ve tarama önizlemede karşılaştırılabilir.
3. Cetvelin altında tek kompakt durum satırı bulunur:
   - Öncesinde: “Sıradaki kerahat · Gün batımı”, başlangıç/bitiş ve başlamasına kalan süre.
   - Sırasında: koyu kırmızı kenarlı, hafif kırmızı yüzeyli “Kerahat vakti”; bitiş ve kalan süre.
   - Sonrasında: nötr renkte günlük aralıklara erişim.
4. Satıra dokununca üç aralığın saatlerini, yaklaşık hesap bilgisini ve Diyanet kaynağını gösteren panel açılır.
5. Altı namaz vaktinin tamamı veya İkindi aralığının tamamı kerahat rengine boyanmaz. Renk, yalnızca hesaplanan kerahat aralıklarını işaret eder.

Kırmızı bilgi tek başına kullanılmaz: başlık, aralık ve süre metinleri de bulunur. Bildirim/alarmlar ve tek seferlik atlama kontrolleri bu gösterimden bağımsızdır.

## İmsakiyenin bulunabilirliği

Takvim ekranının üstünde **Vakit takvimi / Ramazan İmsakiyesi** seçimi yıl boyunca görünür olsun. İmsakiye görünümü seçilen Ramazan ayının tüm günlerini yüklesin; İmsak ve İftar odaklı sunum ve yıl seçimi bulunsun. Ayın resmi başlangıcı/bitişi veri kaynağıyla doğrulanmalı. Mevcut sezonluk başlık değişikliği bu özelliğin tamamlandığı anlamına gelmemeli.

Önizlemede gezinmenin ve sütun vurgusunun anlaşılması için beş örnek satır var; gerçek tam ay yükleme veya paylaşım uygulanmış değil.

## Uygulamaya geçildiğinde

- Kerahat başlangıç/bitişleri tek domain hesabından üretilmeli; metin, cetvel ve mevcut türetilmiş bildirim noktaları aynı sınırları kullanmalı.
- [DayRuler](../../lib/presentation/widgets/home/day_ruler.dart) yeni kerahat sınırlarında mevcut 3 px vakit boşluğunu uygulamamalı. 10 dk, 360 px cetvelde yalnızca 2,5 px: aksi hâlde öğle aralığı kaybolur. Görsel genişlik saat oranını izlemeli, dokunma alanı ayrıca genişletilmeli.
- Bitiş anında aktif durum kapanmalı; gece yarısı, eksik vakit verisi, DST ve RTL kontrol edilmeli. Veri yokken aralık uydurulmamalı.
- İmsakiye, ana ekranın 13 günlük penceresinden ayrı olarak seçilen ayın tamamını istemeli. Tam ay paylaşımı mevcut ekran görüntüsü paylaşımından ayrıca doğrulanmalı.

## Önizleme

[Etkileşimli tasarım](kerahat-imsakiye.html) uygulamanın görsel dilini taklit eden yerel bir tasarım fragmanıdır. Durum, görünüm, cetvel dolgusu ve ekran seçimleri destekleyen görüntüleyicide değiştirilebilir. Kerahat satırı ayrıntı panelini; Takvim düğmesi imsakiye girişini açar.
