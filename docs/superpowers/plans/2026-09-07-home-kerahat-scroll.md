# Ana ekran: kerahat erişimi ve kaydırma

Kullanıcının onayladığı kapsam: ortadaki kerahat kartını kaldır; ayrıntıları küçük bir kontrolle aç; kerahat sırasında ana sayaçta uyarı göster; büyük metinde de düzgün kaydır.

## Tasarım

- Vakitler üst çubuğunda, ayarların yanında küçük bir kerahat ikonu. Erişilebilir adı mevcut “Kerahat vakitleri” çevirisi.
- Üç aralık ve Diyanet açıklaması açılır panelde kalır. Gün cetvelindeki renkler korunur.
- Ana sayacın alt bilgisinde yalnızca aktif aralıkta kırmızı “Kerahat vakti” uyarısı görünür; sayaçla birlikte saniye sınırında güncellenir.
- Ana ekranın dikey kaydırması içerik sınırında durur. Tarih ve sayaç başlığı sarılabilir; sıradaki hatırlatıcılar büyüyen metne göre uzar.

## Kanıt ve uygulama

- [x] Mevcut akışı ve çağıranlarını incele.
- [x] iOS widget testinde liste sonunun 130 piksel aşılabildiğini doğrula. Normal kaydırma ve 10 saniyelik yenilemede konum korunuyor; reset hatası yeniden üretilemedi.
- [x] 320×480, yüzde 200 metinde tarih, sayaç başlığı ve hatırlatıcı satırlarının taşmasını doğrula.
- [x] Üst çubuk erişimini ve aktif uyarıyı uygula; eski kartı kaldır.
- [x] Kaydırma sınırlarını ve metin taşmalarını düzelt.
- [x] Açılır panel, zaman sınırları, Türkçe/Arapça büyük metin, kaydırma ve sekmeye dönüş testlerini çalıştır.
- [x] Format, analyze, tüm Flutter testleri ve simulator görünümünü doğrula.

Tüm adımlar ana agent tarafından inline yürütülür. Native alarm planlaması ve kerahat hesaplama süreleri değişmez.

## Doğrulama

- `flutter test --no-pub`: **1113 geçti, 1 mevcut koşullu atlama**.
- Lint düzeltmesinden sonra ilgili widget kontrolleri: **90 geçti, 1 mevcut koşullu atlama**.
- `flutter analyze --no-pub`: sorun yok.
- `dart format` ve `git diff --check`: temiz.
- `flutter build ios --simulator --debug --no-pub`: başarılı.
- iPhone 17 Pro / iOS 26.5 simulator: ortadaki kart yok; üst çubuk düğmesi paneli açıyor, üç doğru aralık ve kaynak görünüyor; kapatınca ana ekrana dönülüyor.
- Simulator otomasyonunun sürükleme girdisi hem ana ekranda hem mevcut takvimde sonuç vermedi. Klavye Escape de çalışmadı; erişilebilirlik eylemleri çalıştı. Bu deneme fiziksel kaydırma doğrulaması sayılmadı. Kaydırma sınırları, yenilemede/sekme dönüşünde konum ve yüzde 200 metin widget testleriyle doğrulandı; kullanıcının fiziksel cihazındaki titreme doğrudan denenmedi.

Teslim, doğrulanan değişikliklerin `dev` üzerinde yerel commit olarak kaydedilmesidir.
