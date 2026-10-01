# Hutbe — Tasarım Spec'i

1 Ekim 2026 brainstorming'inde ana sayfa içerikleri üç alt projeye ayrıldı:
günün içeriği (`2026-10-01-gunun-icerigi-design.md`), hutbe ve yakındaki
camiler (`2026-10-01-yakin-camiler-design.md`). Bu spec Diyanet'in haftalık
cuma ve bayram hutbelerini kapsar.

## 1. Kullanıcı kararları

| # | Karar |
|---|---|
| H1 | Son 20 hutbe listelenir (Diyanet Haber akışının verdiği kadar); daha eskisi tutulmaz |
| H2 | Araçlar ekranında "Hutbe" girişi; ayrıca hutbe günü ve bir gün öncesinde ana sayfada "Bu haftanın hutbesi" kartı |
| H3 | Ses yok, bildirim yok |
| H4 | Türkçe arayüz: hutbe uygulamanın kendi okuma ekranında metin olarak okunur |
| H5 | İngilizce ve Arapça arayüz: o dildeki Diyanet PDF'i açılır ("en kolayı bu") |
| H6 | Türkçe okuma ekranında yazı boyutu ayarı, paylaş (kaynak bağlantısı), dipnotlar ve "kaynakta aç" |

## 2. Bulgular (1 Ekim 2026 araştırması)

| # | Bulgu | Kaynak |
|---|---|---|
| B1 | Diyanet Haber (sahibi Diyanet İşleri Başkanlığı) hutbe RSS'i yayımlıyor; son 20 kayıt. Hutbeler genelde perşembe 10:00–21:00 arası çıkıyor, bayram hutbesi bayramdan birkaç gün önce | https://www.diyanethaber.com.tr/rss/hutbeler (doğrulandı) |
| B2 | Hutbe sayfasında Türkçe metnin tamamı ve dipnotlar düz metin olarak (JSON-LD `articleBody`) duruyor | araştırma raporu, 25.09.2026 sayfası |
| B3 | Künye: "ajans kaynaklı haberler hariç diğer haberlerin AKTİF LİNK kaynak belirtilerek kullanılması serbesttir" | https://www.diyanethaber.com.tr/kunye (doğrulandı) |
| B4 | Metin bazen cuma ~11:30'da düzeltiliyor (25.09 hutbesi cuma 11:28'de güncellenmiş) | araştırma raporu |
| B5 | İngilizce ve Arapça yalnız Din Hizmetleri GM sitesinde PDF ve DOC eki olarak var. 25.09.2026 sayfası: TR/EN/AR `.pdf` + `.doc` + Türkçe `.mp3`. Haziran 2026'ya kadar cuma hutbeleri 8 dildeydi, bayram hutbeleri hâlâ 8 dilde | https://dinhizmetleri.diyanet.gov.tr/Detay/1318/… (doğrulandı) |
| B6 | Din Hizmetleri sayfa adresi `/Detay/{id}/{ddmmyyyy}-cuma-hutbesi-…`; ana sayfa son hutbelere bağlantı veriyor. robots.txt `/kategoriler/`'i kapatıyor, `/Detay/` ve `/Documents/` açık | araştırma raporu (doğrulandı: ana sayfada ~40 hutbe bağlantısı) |
| B7 | Ek dosya adları başlıktır: Türkçe PDF Türkçe başlıkla, Arapça PDF Arapça harflerle, İngilizce PDF İngilizce başlıkla adlandırılmış | 25.09.2026 sayfası (doğrulandı) |
| B8 | Din Hizmetleri sitesinde kullanım şartı sayfası yok; yalnız telif satırı | araştırma raporu |
| B9 | Uygulamada bağlantı açma eklentisi yok (`url_launcher` yok); paylaşım `share_plus` ile var | `pubspec.yaml` |

## 3. Sunucu

1. **Akış:** Diyanet Haber hutbe RSS'i okunur. Her kayıt için hutbe günü
   başlıktan çıkarılır ("25 Eylül 2026 - Cuma Hutbesi"), tür cuma ya da
   bayram. Hutbe kimliği `{tarih}-{tür}` (ör. `2026-09-25-cuma`).
2. **Türkçe metin:** Yeni ya da değişmiş (RSS'teki tarih farklı) kayıtta
   sayfa bir kez çekilir; başlık, paragraflar, dipnotlar ve kaynak adresi
   saklanır. Metne dokunulmaz (kısaltma, düzeltme yok); yalnız paragraf ve
   dipnot ayrılır.
3. **İngilizce ve Arapça PDF:** Din Hizmetleri ana sayfasında aynı tarihli ve
   türdeki hutbe sayfası bulunur, eklerdeki PDF'ler ayrılır: Arapça harfli
   ad → Arapça; Türkçe başlıkla eşleşen ad → Türkçe (kullanılmaz); kalan
   Latin harfli ad → İngilizce. Dosya adı (uzantısız) o dilin başlığıdır.
   PDF kopyalanmaz, Diyanet'teki adresi saklanır. Bulunamazsa sonraki
   çalışmalarda (hutbe günü geçene kadar) yeniden aranır.
4. **Koruma:** Metin boş ya da 500 karakterden kısa gelirse kayıt
   güncellenmez, uyarı loglanır. Site yapısı değişip hiçbir kayıt
   çözülemezse eski kayıtlar korunur, iş hata koduyla biter.
5. **Saklama:** En yeni 20 hutbe tutulur; dizin dosyası (kimlik, tarih, tür,
   Türkçe başlık, EN/AR başlık ve PDF adresi, kaynak adresi, güncellenme
   zamanı) ve hutbe başına Türkçe metin dosyası. Listeden düşen hutbenin
   dosyası silinir.
6. **Uçlar:** `GET /v1/sermons` (dizin, kısa cache: 15 dk) ve
   `GET /v1/sermons/{id}` (Türkçe metin, 1 saat cache; cuma düzeltmesi için
   uzun tutulmaz). Bilinmeyen kimlik 404 `no-store`.
7. **Zamanlama (Türkiye saati):** her gün 22:00, ek olarak perşembe 17:00 ve
   cuma 11:30. RSS isteği hafiftir; değişmeyen kayıt için sayfa çekilmez.
8. **İlk kurulum:** İlk çalışmada RSS'teki 20 hutbe alınır; istekler arasında
   en az 1 sn beklenir. Din Hizmetleri için tanımlayıcı bir User-Agent
   gönderilir, `/kategoriler/` hiç istenmez.
9. **Durum:** Sağlık ucundaki durum, son başarılı çekim zamanını ve hutbe
   sayısını gösterir.

## 4. Uygulama

### 4.1 Veri

- Dizin açılışta (Araçlar'dan hutbe listesine girişte ve ana sayfa
  yüklenirken) en sık saatte bir istenir; son dizin telefonda saklanır.
- Türkçe metin hutbe ilk açıldığında indirilir ve saklanır; ağ yokken
  açılmış hutbeler okunabilir. Dizinden düşen hutbenin metni silinir.
- Hatalar `AppLogger` ile loglanır; liste ekranı ağ yoksa saklanan dizini
  gösterir, hiç yoksa boş durum ve yeniden dene düğmesi.

### 4.2 Ekranlar

- **Araçlar → Hutbe:** tarih sırasıyla liste (yeni üstte). Türkçe arayüzde
  Türkçe başlık + tarih + tür ("Cuma"/"Bayram"); dokununca okuma ekranı.
  İngilizce/Arapça arayüzde yalnız o dilde PDF'i olan hutbeler, o dildeki
  başlıkla; dokununca PDF uygulama içi tarayıcı görünümünde açılır.
- **Okuma ekranı (Türkçe):** başlık, tarih, paragraflar, altta dipnotlar
  ve "Kaynak: Diyanet Haber" satırı (dokununca orijinal sayfa tarayıcıda).
  Üst çubukta yazı boyutu (küçült/büyüt, 5 kademe, seçim hatırlanır) ve
  paylaş (Diyanet Haber bağlantısı + başlık). Sistem yazı ölçeğine ek olarak
  uygulanır.
- **Ana sayfa kartı:** tarihi bugün (yoksa yarın) olan hutbe varsa vakit
  ızgarasının altında, günün içeriği kartlarının üstünde "Bu haftanın hutbesi"
  / bayramda "Bayram hutbesi" kartı: başlık + "Oku". Her dilde görünür;
  İngilizce/Arapça'da o dilin PDF'i yoksa görünmez.
- Görünüm kodlanmadan önce PNG mockup ile onaylanır.

### 4.3 Platform ve bağımlılık

- `url_launcher` eklenir (PDF ve kaynak sayfası; yakındaki camiler de
  kullanır).
- Lokalizasyon: ekran başlıkları, tür adları, boş/hata durumları, "Oku",
  "Kaynak" — `app_tr/en/ar.arb`.

### 4.4 Gizlilik

Hutbe istekleri kişisel veri taşımaz. Gizlilik belgesinde veri kaynakları
bölümüne "Hutbeler Diyanet İşleri Başkanlığı'nın yayınlarından alınır"
eklenir.

## 5. Test

- **Sunucu:** RSS ayrıştırma (cuma/bayram, tarih); sayfa metninden paragraf
  ve dipnot ayırma (kaydedilmiş örnek sayfalarla); PDF dil ayrımı (25.09
  sayfası örneği); kısa metin koruması; 20 sınırı ve silme; değişmeyen
  kayıtta sayfa çekmeme.
- **Uygulama:** dizin/metin ayrıştırma; saklama ve çevrimdışı okuma; dile
  göre liste süzme; kartın görünme günleri (perşembe/cuma, bayram);
  yazı boyutunun hatırlanması.
- **Elle:** sunucu deploy'undan sonra perşembe akşamı yeni hutbenin
  geldiği; PDF'in iOS ve Android'de açıldığı (kullanıcı).

## 6. Kapsam dışı

Ses, bildirim, 20'den eski arşiv, İngilizce/Arapça metin çıkarma, DİTİB
hutbeleri, il müftülüklerinin yerel hutbeleri.

## 7. Açık noktalar

- **İzin kapsamı:** Diyanet Haber izninin uygulama içinde tam metni
  kapsadığı çıkarımdır; istenirse Awqat ilişkisi üzerinden yazılı teyit
  alınır. Bölüm adı "Diyanet'in haftalık hutbesi" olarak anılır (bazı
  haftalar il kurulları kendi hutbesini okuyabiliyor).
- **Site değişikliği:** Diyanet Haber ve Din Hizmetleri sayfa yapısı
  değişirse çekim durur; 4. madde eski kayıtları korur, sağlık ucu ve log
  uyarı verir.
