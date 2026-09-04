# Değişiklik Günlüğü

Bu projedeki dikkate değer değişiklikler bu dosyada belgelenir.
Biçim [Keep a Changelog](https://keepachangelog.com/tr/1.0.0/) temellidir ve
proje [Semantic Versioning](https://semver.org/lang/tr/) kullanır.

## [0.11.4] - 2026-09-04

### Değişti
- **Sessiz pencereler artık yalnızca Android'de.** iPhone'da bir uygulama telefonu sessize alamıyor; ayar orada yalnızca uygulamanın kendi bildirimlerini susturuyordu, yani "Cuma namazında telefonum sussun" beklentisini karşılamıyordu. iOS'ta Ayarlar'daki satır kaldırıldı ve pencereler hiç okunmuyor. Android'de aynen çalışmaya devam ediyor.
- Sessiz pencere açıklaması güncellendi: artık iPhone'a atıf yok, ayarın telefonun zil profiline ve alarmlara dokunmadığı yazıyor.

### Teknik not
- `NotificationScheduler` yeni bir `quietWindowsEnabled` bayrağı taşıyor (varsayılan `Platform.isAndroid`); iOS'ta sessiz pencereler depodan hiç okunmuyor. Platform ayrımını iki test kilitliyor.
- `notification_sound_test.dart` sabit bir tarihe (2026-09-04 Cuma) dayanıyordu ve o günün öğle vakti geçince kırılıyordu; fixture artık "öğlesi gelmemiş ilk Cuma"yı kendisi buluyor.

## [0.11.3] - 2026-08-31

### Değişti
- **Uygulama içindeki dil seçimi kaldırıldı.** Uygulama artık telefonun diline uyar ve değiştirilemez. Telefon Türkçe/İngilizce/Arapça ise arayüz o dilde, başka bir dilse İngilizce olur.
- **Uygulama adı, izin metinleri, widget galerisi ve Siri komutları da çevrildi.** Ana ekrandaki uygulama adı, konum/kamera/alarm izin diyalogları, widget galerisindeki açıklama ve "sıradaki vakit" sesli komutu artık telefonun dilinde geliyor.
- **Tarihler cihaz diline göre yazılıyor.** Gün ve ay adları sabit Türkçe biçimlendirmeyle basılıyordu; İngilizce/Arapça telefonda da Türkçe görünüyordu.
- Hesaplama yöntemlerindeki Türkçeleştirilmiş yer adları uluslararası yazımına çekildi ("Mekke" → "Makkah", "Kuveyt" → "Kuwait"). Kurum adları özel isim olduğu için çevrilmiyor.

### Düzeltildi
- Ekranlarda kalan son sabit Türkçe metinler çevrildi: alarm düzenleme bölüm başlıkları, alarm durdurma ara ekranı, görev ekranlarındaki düğmeler, QR tarayıcı, hata ekranındaki "Yeniden Dene", konum ekranlarındaki kaydet/geri düğmeleri ve konum türü etiketleri.

### Teknik not
- iOS tarafında `tr/en/ar.lproj` altında `InfoPlist.strings`, `Localizable.strings` ve `AppShortcuts.strings`; Android tarafında `values-tr/` ve `values-ar/` eklendi. Taban dil (çevirisi olmayan cihazlar için) İngilizce.
- Sabit Türkçe metin testi artık yalnızca Türkçe'ye özgü harflere değil, ASCII yazılan Türkçe kelimelere de bakıyor — "Ayarlar", "Kaydet", "dk" gibi sızıntılar bu yüzden gözden kaçmıştı. Log çağrıları taramadan muaf.

## [0.11.2] - 2026-08-31

### Değişti
- **Uygulamada tek bir sabit Türkçe metin kalmadı.** Görev ekranları (matematik, sallama, QR), acil çıkış, alarm durdurma, hatırlatıcı ekleme, hesaplama ayarları, konum ekranları, hata ve bilgi mesajları — hepsi üç dilde.
- **Hicri ay adları ve dini gün adları çevrildi.** Arapça'da ay adları kendi yazımıyla (رمضان, شعبان), İngilizce'de yerleşik karşılıklarıyla (Ramadan, Sha'ban) görünüyor.
- **Acil çıkışta yazılacak cümle artık kendi dilinde.** Önce sabit Türkçe cümle isteniyordu; İngilizce ya da Arapça arayüzde bu anlamsızdı.
- Hesaplama yöntemi adları uluslararası yazımlarına çevrildi ("Karaçi" → "Karachi", "Körfez Bölgesi" → "Gulf Region"). Diyanet İşleri Başkanlığı kurum adı olduğu için olduğu gibi kalıyor.

### Düzeltildi
- Vakit adları, ikon seçimi ve gün dilimi paleti artık **ada değil kimliğe** bakıyor. Çeviri gelince bu eşleşmeler sessizce bozulacaktı.

### Teknik not
- Bir test artık `lib/` altında sabit Türkçe metin kalmadığını sürekli doğruluyor; yeni ekranlarda çeviri unutulursa test kırılıyor.
- Kullanılmayan çevrimdışı durum mesajları ve ölü etiket metotları kaldırıldı.

## [0.11.1] - 2026-08-31

### Düzeltildi
- **Desteklenmeyen cihaz dilinde artık İngilizce kullanılıyor.** Önce Arapça'ya düşüyordu (desteklenen diller listesi alfabetikti).
- Uygulama içinde bir dil seçtiysen **bildirimler de o dilde** geliyor; önce cihaz dilini kullanıyordu.

### Eklendi
- **Widget ve Siri kısayolu artık uygulamanın dilinde.** Metinler widget'a uygulamayla birlikte gönderiliyor (snapshot v3), böylece uygulama içinde seçtiğin dil cihaz dilinden farklı olsa bile widget ona uyuyor.
- **Konum ekranları çevrildi:** konum listesi, konum ekleme (arama ve GPS) ve konum düzenleme.

### Teknik not
- Widget'ta vakit eşleşmesi artık ada değil dile bağlı olmayan bir anahtara bakıyor; adlar çevrildiğinde gün dilimi paleti bozulmuyor.

## [0.11.0] - 2026-08-31

### Eklendi
- **Ramazan modu.** Ramazan boyunca ana ekrandaki sayaç sıradaki vakit yerine **iftara** (gündüz) ya da **sahurun bitişine** (imsaktan önce ve akşamdan sonra) sayar. Takvim sekmesi "Ramazan İmsakiyesi" adını alır.
- **Sahur ve iftar hatırlatmaları.** Ramazan'ın ilk gününde bir kez sorulur; kabul edersen normal bildirim satırı olarak eklenir — Hatırlatıcılar listesinde görünür ve silinebilir. Gizli otomatik bildirim yok, yılda bir kez sorulur.
- **Oruç takibi.** Ramazan'da Namaz takibi ekranında oruç ızgarası (tuttum / kaza / muaf) ve kaza orucu sayacı.
- Ramazan modu Ayarlar'dan kapatılabilir.

### Bilinen sınır
- Ramazan'ın başlangıcı hicri takvimden hesaplanır; Diyanet ilanından bir gün sapabilir. Sayaç ve imsakiye o günün gerçek vakitlerinden hesaplandığı için içerik doğru kalır.
- Widget'ta Ramazan'a özel görünüm yok; widget sıradaki vakti göstermeye devam eder.

## [0.10.0] - 2026-08-31

### Eklendi
- **Üç dil: Türkçe, İngilizce, Arapça.** Ayarlar > Genel > Dil'den seçiliyor; "Sistem" seçilirse cihaz dili kullanılır, desteklenmeyen bir dilde Türkçe'ye düşer.
- **Arapça'da sağdan sola yerleşim (RTL).** Oklar, kenar boşlukları ve hizalamalar yöne göre dönüyor.
- Bildirim metinleri de çevrildi: uygulamayı açmadan gelen bildirimler seçili dilde geliyor.

### Bilinen sınır
- Çeviriler tarafımızdan yapıldı; Arapça metinler için anadili Arapça olan bir gözden geçirme faydalı olur.
- Widget ve Siri kısayolu metinleri henüz Türkçe (iOS tarafında ayrı bir çeviri dosyası gerekiyor).
- Konum ekranları ve bazı hata mesajları henüz Türkçe.

## [0.9.0] - 2026-08-31

### Eklendi
- **Araçlar sekmesi.** Alt gezinmede dördüncü sekme: Vakitler · Takvim · Hatırlatıcılar · Araçlar.
- **Kıble pusulası.** Kâbe yönü konumundan hesaplanıyor, cihazın pusulası gerçek kuzeye göre okunuyor. Kıbleye dönünce titreşimle haber veriyor; pusula kalibrasyon isterse uyarı çıkıyor.
- **Namaz takibi ve kaza sayacı.** Son yedi günün ızgarasında her vakte dokunarak "kıldım → kaza → boş" arasında geçiş yapılıyor; ayrıca vakit başına kaza sayacı var. Seri/rozet yok — defter gibi, oyun gibi değil.
- **Zikirmatik.** Tam ekran dokunma alanı, hedef seçimi (33/99/100/500/1000), tur sayısı; tur tamamlanınca ayrı titreşim. Sayaç günlük tutuluyor.
- **"Sıradaki vakit" Siri kısayolu.** Uygulamayı açmadan sıradaki vakti ve kalan süreyi söylüyor; Spotlight'ta da çıkıyor.
- **Kilit ekranı halka widget'ı** (`accessoryCircular`): vakte kalan süre halkası ve vaktin saati.
- Widget artık uygulamadaki **12/24 saat tercihini** kullanıyor.

### Bilinen sınır
- Kıble ve Siri kısayolu yalnızca gerçek cihazda anlamlı çalışır.
- Denetim Merkezi'ne "ezan sessiz" düğmesi eklenmedi: widget uzantısından planlanmış bildirimleri değiştirmek güvenilir değil, çalışmayan bir düğme yanlış güven verirdi.

## [0.8.0] - 2026-08-31

### Eklendi
- **Türetilmiş vakit hatırlatmaları.** Altı vaktin yanına beş yeni nokta: İşrak (kerahat bitişi), zeval ve akşam öncesi kerahat, şer'i gece yarısı ve gecenin son üçte biri (teheccüd). Hepsi mevcut vakitlerden cihazda hesaplanıyor — ek veri indirilmiyor. Hatırlatıcı eklerken "Türetilmiş Vakitler" bölümünden seçiliyor.
- **Dini günler.** Kandiller, Ramazan başlangıcı, bayramlar, Aşure, Arefe ve Regaib için akşam vaktinde bildirim; istersen bir gün önce öğle vaktinde de hatırlatır. Ayarlar > Bildirim ve ses'ten açılıyor.
- **Takvimi paylaş.** Vakit Takvimi sekmesindeki paylaş düğmesi aylık tabloyu görsel olarak paylaşıyor.

### Bilinen sınır
- Dini gün tarihleri **hicri takvimden hesaplanır**, ilan edilmiş tarihler değildir. Diyanet astronomik gözleme dayandığı için bir gün farklı olabilir; bildirim metni ve ayar açıklaması bunu belirtir.
- Bildirim kimliği türetilmiş noktayı da kapsadığı için bu sürüme geçerken bekleyen "yalnızca bu sefer atla" işaretleri sıfırlanır. Bildirimlerin kendisi korunur.

## [0.7.0] - 2026-08-31

### Eklendi
- **Sessiz pencereler.** Belirlediğin aralıklarda bildirimler sessiz gösterilir ya da hiç gösterilmez. Cuma namazı şablonu **açık geliyor** (öğleden 15 dk önce – 60 dk sonra); süresini değiştirebilir, modunu seçebilir ya da tamamen kapatabilirsin — istediğin vakit için kendi pencereni de ekleyebilirsin. Not: iPhone'da bir uygulama telefonu sessize alamaz — bu ayar yalnızca Ezan Vakti bildirimlerini etkiler, alarmlara dokunmaz.
- **Bildirim başına ses:** sistem sesi, uygulamanın kısa uyarı tonu ya da sessiz. Yeni bildirimlerin varsayılan sesi Ayarlar'dan seçiliyor.
- **Odak modunda göster.** Açıkken bildirimler Odak modunda özete düşmeden anında görünür. (Telefonun sessiz anahtarını delmez.)
- **Bildirimlere gün filtresi ve etiket.** Bir hatırlatma yalnızca seçtiğin günlerde çalabiliyor; etiket verirsen bildirim başlığında o yazıyor. Bildirim listesinde tek dokunuşla **Cuma namazı hatırlatıcısı** ekleniyor.
- **Vakit düzeltmeleri.** Her vakti −15…+15 dk kaydırabilirsin; bildirimler, alarmlar ve widget düzeltilmiş vakti kullanır.
- **Saat biçimi** (sistem / 24 saat / 12 saat) ve **konumu otomatik izle** anahtarı.

### Değişti
- Ayarlar ekranı bölümlendi: Genel · Bildirim ve ses · Sessiz pencereler · Görünüm · Bilgi.
- Vakit düzeltmesi değiştiğinde vakitler yeniden indirilmiyor; düzeltme cihazda uygulanıyor.

### Bilinen değişiklik
- Bildirimlerin kimliği gün bilgisini de kapsadığı için, bu sürüme geçerken bekleyen "yalnızca bu sefer atla" işaretleri sıfırlanır. Bildirimlerin kendisi korunur.

## [0.6.0] - 2026-08-31

### Düzeltildi
- **Tekrarlı alarmlar artık uygulama açılmadan da her gün kurulu.** 31 Ağustos'ta alarmların hiç çalmaması bu tasarım açığındandı: sisteme yalnızca tek sonraki çalış yazılıyor, ertesi gün uygulamanın açılmasına kalıyordu. Sabit saatli tekrarlı alarmlar sistemin kendi haftalık tekrarıyla kuruluyor; vakte çıpalı alarmların önümüzdeki 7 çalışı önden diziliyor.
- **Alarm çalmadan açılan bayat görev ekranı.** Dünden kalan görev oturumu artık 60 dakika sonra kendiliğinden kapanıyor; zincir güvenlik tavanına çarptığında da oturum kapatılıp alarmlar yeniden kuruluyor.
- **Ses seçicideki hayalet "Özel ses".** Yeni alarm, 0.5.1'de kaldırılan bir ses kimliğiyle başladığı için seçici "Özel ses" gösteriyordu; gerçekte sistem varsayılanı çalıyordu. Varsayılan düzeltildi, eski kayıtlar veritabanında temizleniyor.
- Kurulamayan alarm satırında artık "Kurulamadı" uyarısı görünüyor; sessiz kaybolmuyor.

### Eklendi
- **Alarm kopyalama:** satıra uzun basınca Kopyala/Sil menüsü; kopya "(kopya)" etiketiyle düzenleme ekranında açılıyor.
- **QR kod kütüphanesi:** okutulan kod adlandırılıp kaydedilebiliyor; yeni alarm kurarken "Kayıtlı kodlardan seç" ile yeniden kullanılıyor. Silmede kodu kullanan alarmlar uyarıyla listeleniyor.
- Ses satırının altında bilgilendirme: alarm, sistemin "Zil Sesi ve Uyarılar" seviyesiyle çalar (iOS üçüncü taraflara ses düzeyi denetimi vermiyor).

## [0.5.5] - 2026-08-30

### Düzeltildi
- **Always-On ekranda widget geri sayımı 15 dakikaya kadar bayatlayabiliyordu.** 0.5.4'teki ölçüm sistemin aralık sayacının Always-On'da çalıştığını gösterdi; geri sayım artık her iki modda da sistem tarafından çiziliyor, dakikalık kare üretimi kaldırıldı. Vakit geçince sayaç 0:00'da duruyor (eskiden yukarı saymaya başlıyordu).

## [0.5.4] - 2026-08-30

### Eklendi
- **Alarm durunca karar ekranı.** Alarmı durdurunca uygulama açılıyor ve büyük iki düğme çıkıyor: görevli alarmda "Görevi yap / Ertele", görevsizde "Tamam / Ertele". Erteleme süresi düğmenin üstünde, kalan hak altında.

### Düzeltildi
- **Görevsiz alarmlarda "Erteleme sayısı" ayarı hiçbir şey yapmıyordu** — sistem uyarısındaki Ertele düğmesi sayılamıyordu, sınırsız ertelenebiliyordu. Erteleme artık uygulama içinde sayılıyor; sistem düğmesi kaldırıldı.
- Görevsiz alarm çalıp kapatıldıktan sonra ertesi günkü alarm, uygulama açılana kadar kurulmuyordu; "Tamam" artık ertesi günü kuruyor.

### Değişti
- Görevli alarmda ara ekranda seçim süresi 30 sn (dolarsa alarm döner). Görevsizde ekran 45 sn sonra kendini kapatıyor.
- Erteleme kapalı görevsiz alarmlar eskisi gibi: durdurunca uygulama açılmaz.

## [0.5.3] - 2026-08-30

### Düzeltildi
- **Bir alarmın görevi tamamlanınca aynı güne kurulu diğer alarmlar siliniyordu.** Güneş alarmının QR görevi bitince 08:45 alarmı hiç çalmıyordu. Artık yalnızca biten alarmın zinciri temizleniyor ve görev bitince alarmlar yeniden kuruluyor.

### Değişti
- QR görevinin süresi 120 saniyeden 90 saniyeye indi.
- Always-On ekranda geri sayım deneme amaçlı sistemin aralık sayacıyla çiziliyor (bayatlama sorunu için ölçüm).

## [0.5.2] - 2026-08-30

### Düzeltildi
- **Widget'a dokununca uygulama üzerine ikinci bir ana sayfa açılıyordu** ("sağdan ekran geliyormuş gibi"). Widget'ın gönderdiği adres, Flutter'ın derin bağlantı işlemiyle ana sayfanın üstüne bir kopya olarak push ediliyordu; adres kaldırıldı, dokunuş uygulamayı doğrudan açıyor.
- **Always-On ekranda geri sayım canlı sayacın bir dakika önünde kalıyordu** (açıkken 4:25:33, kilitleyince 4:26). Kareler artık tam dakikaya hizalı ve her kare geçerli olduğu dakikayı gösteriyor.

### Değişti
- Widget yazı boyutları yeniden ayarlandı: tarih satırları büyüdü, vakit saati ve geri sayım küçülüp inceldi.
- Orta boy widget'ta vakit listesindeki ad–saat arası boşluk daraltıldı.
- Hizalama ayarı (sol/orta/sağ) kilit ekranı widget'ında da geçerli.

## [0.5.1] - 2026-08-29

### Eklendi
- Widget'lara **tarih**: gün adı, miladi tarih ve hicri tarih. Hicri tarih uygulamanın hesabıyla birebir aynı.
- Widget'a **hizalama ayarı**: sola yaslı, ortalı veya sağa yaslı. Widget'a uzun basıp "Widget'ı Düzenle" ile seçiliyor.
- Sıradaki vakit ertesi güne aitse widget artık **"YARIN"** yazıyor.

### Düzeltildi
- **Orta boy widget iki farklı günü gösteriyordu:** Yatsı'dan sonra soldaki vakit yarına, sağdaki liste bugüne aitti ve listede hiçbir satır vurgulanmıyordu.
- **Kilit ekranı kapalıyken (Always-On) geri sayım** "5 hours 51 minutes" gibi okunmaz bir biçime düşüyordu; artık `5:34:--` yazıyor.
- Açık temada widget zemini düz beyaz kart gibi görünüyordu.
- Widget'a dokununca açılan adres uygulamada tanımlı değildi.
- **Alarm ses seçicisindeki üç seçenek aynı sesi çalıyordu.** Projede ses dosyası olmadığı için "Ezan" ve "Alarm sesi" de sistem varsayılanına düşüyordu; çalışmayan iki seçenek kaldırıldı, varsayılan sistem alarm sesi oldu.

### Değişti
- Widget'lar dikeyde yeniden düzenlendi: tarih ve konum üstte küçük, vakit ve geri sayım altta baskın. Alt boşluklar kapandı.
- Kilit ekranı widget'ından "SIRADAKİ" etiketi kalktı, geri sayım büyüdü.
- Saatin üstündeki tek satırlık (inline) kilit ekranı widget'ı kaldırıldı.

## [0.5.0] - 2026-08-26

### Eklendi
- **iOS ana ekran widget'ı** (küçük ve orta boy): sıradaki vakit, saati ve geri sayım. Orta boyda ayrıca günün altı vaktinin şeridi — geçenler soluk, sıradaki vurgulu.
- **iOS kilit ekranı widget'ı** (dikdörtgen ve satır içi).
- Widget uygulamanın gün dilimi paletini kullanıyor: vakit geçtikçe zemin sabahtan geceye kayıyor.
- Widget uygulama açılmadan da doğru kalıyor — bir haftalık vakit verisi paylaşılıyor ve sıradaki vakti widget kendisi hesaplıyor.

### Değişti
- **iOS minimum sürümü 13.0'dan 17.0'a yükseldi.** Kilit ekranı widget'ları için gerekli; iOS 13–16 çalıştıran cihazlar bu sürümden itibaren güncelleme alamayacak.
- Hatırlatıcı satırlarındaki ayrı "Bu seferi atla" eylemi kalktı; tek seferlik atlama artık kapatma anahtarının uzantısı. Anahtarı kapatınca çıkan çubuktan "Yalnızca bu sefer" seçilebiliyor, atlanan satır kapalı görünüyor ve alt metni hangisi olduğunu yazıyor.

### Düzeltildi
- **Görev ekranları uykulu gözle okunacak hâle getirildi.** Uygulama tamamen kapalıyken alarm durdurulduğunda görev ekranı hiç açılmıyor, ertelenmiş görevli alarm da satırdan kapatılabiliyordu — soğuk açılışta bekleyen görev oturumu okunmuyordu.
- Eylemli bildirim çubukları ekranda kalıcı oluyor ve iki satıra taşıyordu; artık süresi dolunca kendiliğinden kapanıyor ve tek satırda duruyor.

## [0.4.1] - 2026-08-25

### Düzeltildi
- Alarm oluştururken QR kod okutulduktan sonra ekran donuyordu: kod alana yazılıyor ama **"Kaydet" ve geri düğmesi cevap vermiyordu**. Kamera, kod görüş alanında kaldığı sürece aynı kodu her karede yeniden okuyor ve her okuma bir sayfa kapatıyordu; okuyucunun altındaki alarm ekranı da böylece yığından düşüyordu. Artık ilk kod kabul ediliyor, sonrakiler yok sayılıyor.
- Aynı sorun **QR göreviyle alarm kapatmada** da vardı; görev tamamlandıktan sonra ekranın altındaki sayfa kapanıyordu.

## [0.4.0] - 2026-08-21

### Eklendi
- **Görevle kapatma:** alarm artık kaydırıp geçilemiyor; susturmak için seçtiğin görevi yapman gerekiyor. Üç görev var — **Matematik** (soruları çöz), **Sallama** (telefonu hedeflenen sayıda salla), **QR okutma** (yatağından uzağa yapıştırdığın kodu okut). Görev yapılmazsa alarm geri döner. *Şimdilik yalnızca iOS'ta.*
- QR görevinin kodu alarm oluşturulurken **okutularak ya da elle yazılarak** kaydedilir. Kod girilmeden görevli alarm kaydedilemez.
- **Erteleme sayısı sınırı:** her alarm için kaç kez ertelenebileceği seçilebiliyor. Görevli alarmlarda "Sınırsız" listelenmez — görev hiç yapılmadan sonsuza kadar ertelenebilirdi.
- **Kademeli acil çıkış:** görevi yapamadığın durumlar için çıkış hep duruyor, ama her kullanımda zorlaşıyor: basılı tutma → cümle yazma → cümle + geri sayım. Bir hafta kullanılmazsa kademe geriler.
- Ertelenen alarmın ne zaman çalacağı **alarm satırında ve ana ekrandaki SIRADAKİ kartında** görünüyor. Ertelenmiş görevli alarm, görev yapılmadan kapatılamıyor.
- Bildirim satırına da **tek seferlik atlama** eylemi eklendi; daha önce yalnızca alarmlarda vardı.

### Değiştirildi
- **Silme onayı kalktı.** Alarm, bildirim ve konum listelerinde satırı sola kaydırmak doğrudan siliyor; altta "Geri al" çıkıyor. İki adımlık onay, tek adımlık geri almadan daha zahmetliydi.
- Alarm ekranındaki seçim satırları (ses, erteleme, görev) uygulamanın satır diline geçti; değerler sağa yaslı, erteleme ayarları "Ertele"ye bağlı olduğu belli.
- Alt gezinme çubuğunda seçili sekme, ikonu **ve** etiketiyle birlikte vurgulanıyor; öğeler kenarlara daha dengeli dağıldı.
- Çalar ekran uygulamanın tasarım diline taşındı; iOS'a Türkçe yerelleştirme eklendi.
- Matematik görev ekranı yeniden düzenlendi: soru tek odak noktası, ilerleme noktalarla gösteriliyor.

### Düzeltildi
- Silme geri bildirimi tüm bildirim ve alarmların yeniden planlanmasını bekliyordu; "Geri al" satır kaybolduktan saniyeler sonra beliriyordu.
- Görev zincirinin güvenlik tavanı her planlamada sıfırlanıyordu; durmuş bir zincir yeniden canlanıp alarmın sürekli çalmasına yol açabiliyordu.
- Görev ekranı üst üste açılabiliyor, her açılış geri sayımı baştan başlatıyordu.
- Görev süresi dolmadan nöbetçi alarmı erken çaldırıyordu.
- Görev gövdeleri dar ekranda taşıyordu.

## [0.3.3] - 2026-08-04

### Düzeltildi
- İl merkezlerinde konum adı "Ankara, Ankara" gibi iki kez yazılıyordu; tekrar eden ad artık tek kez gösteriliyor. Kayıtlı konumlar da kendiliğinden düzelir.

## [0.3.2] - 2026-08-04

### Değiştirildi
- Varsayılan tema modu **Sistem** oldu; uygulama ilk açılışta cihazın açık/koyu tercihini izliyor. Ayarlar → Görünüm'den her zaman değiştirilebilir.
- Açık temada kayan segmentteki seçili hapın altındaki gri gölge kaldırıldı.

### Düzeltildi
- Açık temada **dakika seçme tekerleğinde** seçili dakika görünmüyordu; seçim bandı satırın üzerini opak beyazla örtüyordu. Hem bildirim ekleme hem alarm ekranında düzeltildi.

## [0.3.1] - 2026-08-04

### Düzeltildi
- Vakitler sekmesindeki **ayarlar (dişli) ikonu** ekranın sağ kenarına yaslanmıyor, diğer içeriğin hizasından yaklaşık iki kat içeride duruyordu.

## [0.3.0] - 2026-08-04

### Eklendi
- **Vakte göre renk:** arayüz paleti gün içinde namaz vakitleriyle birlikte ilerler — ÇİVİT (İmsak–Öğle), KURŞUNİ (Öğle–İkindi), ERGUVAN (İkindi–Yatsı), SÜMBÜL (Yatsı–İmsak). Her paletin açık temada bir karşılığı var: NİLÜFER, SEDEF, GÜLKURUSU, LEYLAK.
- **Açık tema** ve **Sistem** tema modu. Ayarlar → Görünüm'den seçilir.
- "Vakte göre renk" kapatıldığında dört paletten biri **sabit** olarak seçilebilir.
- Ana ekrandaki **SIRADAKİ** kartından bildirimi veya alarmı **yalnızca o seferliğine** kapatma. Kalıcı kapatma Bildirimler ve Alarmlar ekranlarında kalır; karttaki anahtar kapalıyken satır "Yalnızca bu sefer atlanacak" yazar ve örnek geçince kendiliğinden normale döner.
- Yeni **ERGUVAN uygulama ikonu** ve uyumlu açılış ekranı. İkon yalnızca launcher ve açılış ekranında görünür; uygulama içi başlıklardan kaldırıldı.

### Değiştirildi
- **Gezinme yeniden düzenlendi:** alt çubukta **Vakitler · Takvim · Hatırlatıcılar** olmak üzere üç sekme var. Hamburger menü kaldırıldı; Ayarlar'a Vakitler sekmesinin sağ üstündeki dişli ikonundan gidiliyor. Geri tuşu ikinci veya üçüncü sekmedeyken Vakitler'e döner.
- **Bildirimler ve Alarmlar tek "Hatırlatıcılar" ekranında birleşti**; aralarında üstteki segment ile geçiliyor. Sağ üstteki "+" seçili bölümün tipini ekler.
- Uygulama tipografisi **Manrope**'a geçti; sayaç ve saat kolonları sabit genişlikli rakam kullanıyor, rakamlar değişirken satır oynamıyor.
- Tüm ekranlar tek bir yüzey düzenine taşındı: kart içinde kart yok, gruplar ayıraçla bölünüyor.
- Sekme ve seçim şeritleri **kayan hap** animasyonuna geçti.
- Alarm, bildirim ve konum listelerinde "ekle" düğmesi üst çubuğa taşındı; kayan düğme artık son satırın üzerini kapatmıyor.
- Konum adları her yerde aynı sırada gösteriliyor: "Kadıköy, İstanbul".
- Palet değişimleri 400 ms yumuşak geçişle uygulanıyor.

### Düzeltildi
- Bildirim veya alarm eklendikten, silindikten ya da kapatıldıktan sonra ana ekrandaki **SIRADAKİ** kartı eski listeyi göstermeye devam ediyordu. Listeler artık tek yerde tutuluyor.
- Aktif konum satırı yeniden düzenlenebiliyor; AKTİF rozeti düzenleme ikonunun yerini almıyor.
- Uzun konum ve alarm etiketleri satırdan taşmak yerine kırpılıyor.
- GPS ile konum değişimi artık manuel değişimle aynı kanonik yolu izliyor; hesaplama önbelleği ve eski konumun bildirimleri doğru temizleniyor.
- Alarm planlaması başarısız olduğunda hata sessizce yutulmuyor, loglanıyor.

## [0.2.1] - 2026-06-11

### Değiştirildi
- Alarmlar artık ana ekranda ayrı bir **alt sekmede** (önceki menü girişi kaldırıldı); namaz vakitleri ile alarmlar arasında tek dokunuşla geçiş.
- Alarm ekleme ekranı yenilendi:
  - Tekrar günleri tek satırda; **"Her gün"** ve **"Hafta içi"** hızlı seçimleri gün seçimiyle çift yönlü senkron çalışır.
  - "Vakte göre" alarmlarda dakika seçimi artık (bildirimlerdeki gibi) **vakit-başına sınırlı tekerlek** ile yapılıyor; Önce / Tam vaktinde / Sonra.
- Alarm ekranları uygulamanın geneliyle görsel olarak hizalandı (gece gradyanı, altın vurgular).

## [0.2.0] - 2026-06-09

### Eklendi
- **Sesli alarm** özelliği: kapatılana kadar çalan, sessiz modu delen, ertelenebilir alarmlar (bildirimlerden ayrı).
  - İki tür: **sabit saat** ve **vakte göre** (bir namaz vaktinden önce/sonra dakika sapmasıyla).
  - Haftanın günlerine göre tekrar, etiket, titreşim ve erteleme (snooze) ayarları.
  - **Ses seçimi:** gömülü sesler (ezan/alarm) ya da cihazınızdan kendi ses dosyanız.
  - **Android:** kilit ekranında açılan tam ekran çalar ekran; cihaz yeniden başladığında alarmlar yeniden kurulur.
  - **iOS:** AlarmKit ile sistem alarmı; erteleme desteği. (Yalnızca **iOS 26 ve üzeri**; daha eski sürümlerde alarm kaydedilir ancak çalmaz.)

> Not: iOS'ta özel ses olarak yalnızca desteklenen biçimler (caf/aiff/wav, ≤30 sn) çalar; diğer biçimler varsayılan alarm sesine düşer.

## [0.1.15] - 2026-06-09

### Eklendi
- Android dağıtım altyapısı: Play internal testing'e otomatik yükleme (GitHub Actions + fastlane), mağaza varlıkları ve Data Safety dokümanları.
- Tek tag ile iOS + Android yayını; gerektiğinde tek platforma sürüm (`--ios` / `--android`).

### Değiştirildi
- Android bildirim durum çubuğu ikonu monokrom hale getirildi (beyaz kare görünümü giderildi).

> Not: Bu sürümde iOS tarafında kullanıcıya yönelik davranış değişikliği yoktur; değişiklikler Android dağıtım altyapısı ve ortak araçlarla ilgilidir.

## [0.1.14] - 2026-06-07

### Değiştirildi
- İşlem bildirimleri (snackbar) artık birbirini beklemiyor: yeni bir işlem yapıldığında önceki mesaj anında kaldırılıp yeni mesaj hemen gösterilir.

## [0.1.13] - 2026-06-07

### Düzeltildi
- Tüm bildirimler silindiğinde, daha önce zamanlanmış OS bildirimlerinin (örn. "Yatsı 15 dk önce") iptal edilmeyip tetiklenmeye devam etmesi giderildi. Bildirim planlayıcı, ayar listesi boş olsa da önce tüm zamanlanmış bildirimleri iptal eder. Ek olarak, vakit verisi yokken yapılan silme/değişikliklerde de eski bildirimler iptal edilir.

## [0.1.12] - 2026-06-07

### Değiştirildi
- Ana ekran başlığında ikon ile uygulama adı arasına boşluk eklendi.

## [0.1.11] - 2026-06-07

### Değiştirildi
- Ana ekran başlığındaki uygulama ikonu biraz küçültüldü (58 → 44 px).

## [0.1.10] - 2026-06-07

### Düzeltildi
- Otomatik TestFlight dağıtım hattı (GitHub Actions) çalışır hale getirildi: fastlane `multi_json` bağımlılığı eklendi, sürüm script'i yalnızca `main` dalında çalışacak şekilde sınırlandı ve dağıtım imzalaması Apple Distribution sertifikasıyla yapılandırıldı. Workflow elle de tetiklenebilir (`workflow_dispatch`).

## [0.1.9] - 2026-06-07

### Düzeltildi
- Ana ekran başlığındaki uygulama ikonu yuvarlatıldı; full-bleed ikon köşeli/kare görünüyordu.

### Eklendi
- GitHub Actions ile tag tabanlı otomatik TestFlight dağıtımı (`scripts/release_tag.sh` ile tag at → bulutta derle ve yükle; fastlane).

## [0.1.8] - 2026-06-06

Görsel iyileştirmeler.

### Değiştirildi
- Uygulama ikonu yeniden düzenlendi: artık tam-taşan (full-bleed) lacivert zemin + altın motif. iOS'taki şeffaf köşelerden kaynaklanan "kutu içinde kutu"/siyah köşe görünümü giderildi.

### Eklendi
- Açılış ekranı (splash): lacivert zemin üzerinde altın motif (`flutter_native_splash`). Önceki varsayılan placeholder ve buna bağlı "default launch image" uyarısı giderildi.

## [0.1.7] - 2026-06-06

iOS yükleme uyarısı düzeltmesi.

### Düzeltildi
- `Info.plist`'e `NSLocationAlwaysAndWhenInUseUsageDescription` açıklama metni eklendi. Konum kütüphaneleri "Always" konum API'sine referans verdiğinden App Store Connect yüklemesinde "Missing purpose string" (90683) uyarısı çıkıyordu; uygulama bu izni kullanmasa da Apple açıklama metnini bekliyor.

## [0.1.6] - 2026-06-06

iOS derleme düzeltmesi.

### Düzeltildi
- iOS derlemesi CocoaPods'a sabitlendi: `flutter_local_notifications` Swift Package Manager'ı (SPM) desteklemediğinden SPM açıkken Xcode paket çözümlemesi başarısız oluyordu (`Xcode failed to resolve Swift Package Manager dependencies`). Release scripti artık derlemeden önce SPM'i kapatır; tüm eklentiler CocoaPods üzerinden gelir.

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

[0.1.15]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.15
[0.1.14]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.14
[0.1.13]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.13
[0.1.12]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.12
[0.1.11]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.11
[0.1.10]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.10
[0.1.9]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.9
[0.1.8]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.8
[0.1.7]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.7
[0.1.6]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.6
[0.1.5]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.5
[0.1.4]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.4
[0.1.3]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.3
[0.1.2]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.2
[0.1.1]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.1
[0.1.0]: https://github.com/ekrembulbul/ezanvakti/releases/tag/v0.1.0
