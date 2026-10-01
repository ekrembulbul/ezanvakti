# Günün Ayeti, Hadisi ve Duası — Tasarım Spec'i

1 Ekim 2026'da kullanıcı ana sayfaya üç içerik istedi: günün ayeti, hadisi
ve duası. Hutbe ve yakındaki camiler ayrı alt projelerdir; kendi spec'leri
`2026-10-01-hutbe-design.md` ve `2026-10-01-yakin-camiler-design.md`.

Brainstorming'de çok dilli açık kaynaklar (Tanzil, QuranEnc, HadeethEnc)
araştırıldı. Kullanıcı sonunda en sade yolu seçti: "Direkt Diyanet'in
API'sinden devam edelim, dallanıp budaklanmaya gerek yok." Araştırma
bulguları §7'de, ileride Kur'an bölümü eklenirse kullanılmak üzere duruyor.

## 1. Kullanıcı kararları

| # | Karar |
|---|---|
| K1 | Kaynak yalnız Diyanet Awqat Salah API'sinin günlük içeriği. Arapça metin yok, açık kaynak zenginleştirmesi yok |
| K2 | Her gün üç kart: ayet, hadis, dua. Her biri tam metin ve altında kaynak satırı |
| K3 | Geçmiş günler tutulmaz ve gezilmez; yalnız o günün içeriği gösterilir |
| K4 | Kartlar yalnız uygulama dili Türkçeyken görünür; İngilizce ve Arapça arayüzde hiç görünmez |
| K5 | Her kartta paylaş düğmesi; karta basılı tutunca metin panoya kopyalanır |
| K6 | Ayetin meali Diyanet'inki olmalı (güvenilirlik); bu yüzden içerik başka kaynakla karıştırılmaz |
| K7 | Ayrıntılar onaylandı: sunucu 00:05–06:05 arası saat başı dener; uygulama "henüz yok" ya da hatadan sonra 30 dk beklemeden yeniden denemez; 7 günden eski içerik gösterilmez ve sunucuda silinir |

## 2. Bugünkü durum ve bulgular

| # | Bulgu | Kaynak |
|---|---|---|
| B1 | Sunucuda günlük içerik iskeleti var: yayın ucu `GET /v1/daily-content/{YYYY-MM-DD}` (günlük cache, 404 `no-store`), dosya yolu, durum sayacı, `vakit sync daily-content --ahead N` işi | `server/internal/httpapi/handler.go:90`, `server/internal/jobs/dailycontent.go`, `server/internal/store/paths.go:18` |
| B2 | İş tarihli uca (`/api/DailyContent/VerseHadithAndPrayer?date=`) gidiyor; hesabın rolü bu uca yetkili değil (403). Bu yüzden cron'dan çıkarılmış | `server/deploy/crontab:4`, `server/README.md:78` |
| B3 | Tarihsiz uç `GET /api/DailyContent` 1 Ekim 2026'da canlı denendi: 200, alanlar `id, dayOfYear, verse, verseSource, hadith, hadithSource, pray, praySource`. `dayOfYear` 274 (1 Ekim'le doğru). İstemci metodu var ama hiçbir yerden çağrılmıyor | `server/internal/awqat/endpoints.go:151` |
| B4 | Yalnız *bugünün* içeriği alınabiliyor; ileri ya da geri tarih çekilemez | B2, B3 |
| B5 | Metinler kendi tırnaklarıyla geliyor (`"…"` ya da `“…”`); kaynaklar parantez içinde (`(Nahl, 16/45)`) | B3 deneme çıktısı |
| B6 | Uygulamada anahtar–değer `settings` tablosu ve `getSetting` / `setSetting` var; tek bir kaydı saklamak için migration gerekmez | `lib/features/prayer_times/data/sqlite_storage.dart:65`, `lib/core/interfaces/local_storage.dart:87` |
| B7 | Ana sayfa sırası: tarih satırı, sayaç, gün cetveli, vakit ızgarası; altı boş (Sıradaki kartı 0.28.0'da kalktı). Gün dönümü timer'ı ve ön plana geliş akışı ana sayfa koordinatöründe | `lib/presentation/screens/home_screen.dart:167-200`, `lib/presentation/pages/home_page.dart:118-170` |
| B8 | HTTP istemci kalıbı yer uçlarında (zaman aşımı, ayrıştırma hatası); paylaşım `share_plus` ile takvimde kullanılıyor | `lib/features/location/data/places_api.dart:100`, `lib/presentation/services/calendar_share_service.dart` |

## 3. Sunucu

1. **Tarihsiz çekim.** Günlük içerik işi tarihli uç yerine tarihsiz ucu
   çağırır. Kaynak arayüzündeki günlük içerik metodu tarih almaz hale gelir;
   web kaynağı "desteklenmiyor" döner (bugünkü gibi).
2. **Türkiye günü.** İçeriğin günü Türkiye saatine göre (sabit UTC+3;
   Türkiye 2016'dan beri yaz saati uygulamıyor) hesaplanır. Dosya bu tarihle
   yazılır.
3. **Gün doğrulaması.** Gelen `dayOfYear` Türkiye'deki bugünün yılın günüyle
   eşleşmezse kayıt yazılmaz, uyarı loglanır. Böylece Diyanet yeni güne
   geçmeden yapılan çekim dünün içeriğini bugüne yazmaz.
4. **Boş içerik.** Ayet, hadis ya da duadan biri boşsa kayıt yazılmaz,
   uyarı loglanır. Üç kart birlikte gösterildiği için eksik kayıt tutulmaz.
5. **Tekrar etmeme.** O günün dosyası varsa iş Diyanet'e istek atmaz.
6. **Temizlik.** Her çalışmada 7 günden eski içerik dosyaları silinir (K3).
7. **Zamanlama.** Cron, Türkiye saatiyle 00:05'ten 06:05'e kadar saat başı
   çalışır (UTC 21:05–03:05). İlk başarılı çalışmadan sonrakiler istek
   atmadan biter; normal günde Diyanet'e 1 istek gider (kota 100/gün).
8. **CLI.** `--ahead` bayrağı kalkar. README'deki ve crontab'daki "403"
   notları güncellenir.
9. **Yayın ucu değişmez.** Bir tarihin içeriği değişmediği için günlük cache
   uygundur; henüz yazılmamış gün 404 `no-store` döner, Cloudflare'de
   önbelleğe girmez.

## 4. Uygulama

### 4.1 Veri

- **İstemci:** `GET /v1/daily-content/{tarih}` çağrısı; tarih cihazın yerel
  takvim günü. 404 "henüz yok" olarak ayrışır, diğer hatalar istisna olarak
  çağırana gider. Zaman aşımı ve ayrıştırma hatası yer uçlarındaki kalıpla.
- **Saklama:** Son başarılı içerik tek kayıt olarak `settings` tablosunda JSON
  saklanır. Yeni gün gelince üzerine yazılır; geçmiş birikmez (K3).
- **Ne zaman çekilir:** Ana sayfa açılışında, ön plana gelişte ve gün
  dönümünde. Saklanan içerik bugünün ise istek atılmaz. "Henüz yok" ya da hata
  aldıktan sonra 30 dakika yeniden denenmez.
- **Ne gösterilir:** Bugünün içeriği; yoksa saklanan son içerik, en çok 7
  günlükse. Daha eskiyse ya da hiç yoksa kartlar görünmez.
- **Dil:** Uygulama dili Türkçe değilse istek de atılmaz, kartlar da
  görünmez (K4).
- **Hatalar:** Ağ ve sunucu hataları `AppLogger` ile loglanır, ekranda hata
  gösterilmez; kartlar saklanan içerikle kalır. Bu akıştaki hiçbir hata vakit
  yüklemesini, bildirim ya da alarm planlamasını etkilemez.

### 4.2 Ana sayfa kartları

- Vakit ızgarasının altında sırayla Günün Ayeti, Günün Hadisi, Günün Duası.
- Kart: başlık, tam metin (Diyanet'ten geldiği gibi, tırnaklarıyla), altta
  kaynak satırı. Sağ üstte paylaş düğmesi.
- Paylaş: sistem paylaşım menüsü; metin `Başlık + boş satır + metin +
  kaynak`.
- Basılı tutma: metin ve kaynak panoya kopyalanır, kısa bir onay mesajı
  görünür.
- Renk ve tipografi tema token'larından; büyük metin ölçeğinde kart uzar,
  metin kesilmez.
- Görünüm kodlanmadan önce PNG mockup ile onaylanır.

### 4.3 Lokalizasyon

Kart başlıkları, paylaş düğmesinin erişilebilirlik etiketi ve "Kopyalandı"
mesajı `app_tr.arb`'a eklenir; `app_en.arb` ve `app_ar.arb` karşılıkları da
yazılır (kartlar orada görünmese de anahtarlar eksik kalmaz).

### 4.4 Gizlilik

Gizlilik belgesindeki "Sunucuya giden veriler" listesine "Günlük içerik için
yalnız tarih" eklenir (`docs/PRIVACY.md`, `docs/privacy.html`).

## 5. Test

- **Sunucu:** gün eşleşince yazma; eşleşmeyince yazmama; dosya varken istek
  atmama; boş alanlı kaydı yazmama; 7 günden eski dosyaları silme; Türkiye
  günü hesabının UTC 21:00 sınırında doğru gün vermesi.
- **Uygulama veri:** ayrıştırma; 404'ün "henüz yok" olması; bugünün kaydı
  varken istek atmama; 30 dakika bekleme; 7 günlük gösterim sınırı; Türkçe
  dışı dilde istek atmama.
- **Uygulama arayüz:** kartların Türkçede görünmesi, diğer dillerde ve
  içerik yokken görünmemesi; basılı tutmanın panoya yazması.
- **Elle:** deploy sonrası ilk gecenin sunucu logunda kaydın yazıldığı;
  kartların cihazdaki görünümü (kullanıcı).

## 6. Kapsam dışı

- Arapça metin, İngilizce ve Arapça içerik, açık kaynak mealler.
- Geçmiş günler, arşiv, favoriler.
- Widget'ta günün içeriği.
- Yakın camiler ve hutbe (ayrı alt projeler).

## 7. Açık noktalar ve araştırma notları

- **Artık yıl.** Diyanet'in `dayOfYear` alanının artık yılda 1 Mart'tan
  sonra nasıl saydığı bilinmiyor; ilk artık yıl 2028. Eşleşmezse kayıt
  yazılmaz ve log uyarısı görünür; o zaman doğrulama gözden geçirilir.
- **Diyanet'in yeni güne geçiş saati** bilinmiyor; 00:05–06:05 aralığındaki
  saat başı denemeler bunu karşılar.
- **İleride Kur'an bölümü için** (1 Ekim araştırması, kaynaklar doğrulandı):
  Arapça metin Tanzil (CC BY 3.0, değiştirmeden). Türkçe ve İngilizce meal
  QuranEnc (değiştirmeden, atıf + sürüm no, güncel sürümü kullanma). QuranEnc
  "Ali Özek ve diğerleri" metni Diyanet Vakfı mealiyle neredeyse aynı, ancak
  Nahl 45'in sonu eksik geliyor; kullanmadan önce Tanzil'deki Vakıf metniyle
  karşılaştırılmalı. Diyanet İşleri meali toplu olarak alınamıyor
  (acikkaynakkuran-dev.diyanet.gov.tr: toplu aktarma ve yeniden yayın
  talepleri karşılanmıyor). Hadis için HadeethEnc (AR/TR/EN, derece bilgisi,
  aynı şartlar).
