# Diyanet takvimi ile uygulama vakitleri arasındaki fark

- **Tarih:** 2026-09-14
- **Soru:** Uygulamadaki vakitler namazvakitleri.diyanet.gov.tr ile neden birebir uyuşmuyor?
- **Kaynak:** `lib/features/prayer_times/data/awqat_salah_provider.dart` (Aladhan `/calendar`, `method=13`, `school=0`)

## Yöntem

Diyanet'in ilçe sayfası (`/tr-TR/<ilçeId>`) yaklaşık 13 aylık tablo veriyor. Sekiz ilçe için
bu tablo, aynı koordinatlarla Aladhan `method=13` sonucuyla gün gün karşılaştırıldı
(14 Eylül 2026 – Ekim 2027, 396 gün). Aşağıdaki değerler **Diyanet − Aladhan** dakikadır.

Aladhan'ın 13 numaralı yöntemi "Diyanet İşleri Başkanlığı, Turkey (**experimental**)"
olarak etiketli; Fecr 18°, Yatsı 17° ve sabit dakika ofsetleri uyguluyor:
Güneş −7, Öğle +5, İkindi +4, Akşam +7 (API `meta.offset`).

## Bulgular

| Vakit | Fark dağılımı (İstanbul, 396 gün) | Yorum |
|---|---|---|
| İmsak | 0 dk: %86 · ±1 dk: %14 | yuvarlama farkı |
| Güneş | 0 dk: %86 · ±1 dk: %14 | yuvarlama farkı |
| Öğle | 0 dk: %90 · ±1 dk: %10 | yuvarlama farkı |
| İkindi | −2…+2 dk; 0 dk yalnız %26 | **sistematik, mevsimsel** |
| Akşam | −1…+2 dk; 0 dk yalnız %33 | **sistematik, mevsimsel** |
| Yatsı | −1…+2 dk; 0 dk yalnız %23 | **sistematik, mevsimsel** |

Aynı desen Şile, Silivri, Ankara, Erzurum, Antalya, Van ve Edirne'de de var; konuma bağlı değil.

Aylık ortalama fark (İstanbul):

| Ay | İkindi | Akşam | Yatsı |
|---|---|---|---|
| Eylül–Ekim 2026 | −0,8 / −0,9 | +1,1 / +1,3 | +1,3 / +1,3 |
| Ocak–Nisan 2027 | +0,8 … +1,2 | −0,8 … −0,6 | −0,8 … −0,7 |
| Haziran 2027 | +0,1 | −0,2 | −0,3 |
| Ağustos–Ekim 2027 | −0,6 … −1,0 | +0,9 … +1,2 | +1,1 … +1,4 |

İşaret mevsime göre değişiyor: sonbaharda Diyanet'in Akşam ve Yatsı'sı 1–2 dk **geç**,
İkindi'si 1 dk **erken**; kış–ilkbaharda tersine dönüyor. Bu yüzden fark sabit bir
`tune` ofsetiyle kapatılamaz; Aladhan'ın sabit ofsetli taklidi ile Diyanet'in kendi
hesabı arasında algoritmik bir ayrım var (açı/ufuk/temkin tanımı; Aladhan'ın kendi
etiketiyle "experimental").

Ek not: uygulama ham GPS koordinatını kullanıyor; Diyanet ilçe merkezini. Aynı ilçe
içinde bu ≤1 dk fark yaratır ve yukarıdaki desenden bağımsızdır.

## Kullanıcıya görünen etki

Bugün (14 Eylül 2026, İstanbul): İmsak/Güneş/Öğle aynı; İkindi 1 dk geç, Akşam 1 dk erken,
Yatsı 2 dk erken. En çok Ramazan'da (iftar = Akşam, sahur = İmsak) fark edilir; İmsak
tutuyor, iftar 1–2 dk erken görünebilir.

## Seçenekler

| | Yaklaşım | Artı | Eksi |
|---|---|---|---|
| A | Türkiye için Diyanet ilçe sayfasını okuyan yeni `PrayerTimeProvider` (yıllık tablo, ilçe kimliği koordinattan en yakın ilçeyle) | Birebir resmi; 1 istek/yıl; çevrimdışı uzun ömür | HTML kırılgan, resmi API değil; ilçe kimlik tablosu (≈970 kayıt) gömülmeli |
| B | Diyanet AwqatSalah API + kendi proxy sunucusu (ROADMAP'te de var) | Resmi, sözleşmeli | Hesap/onay, sunucu maliyeti ve bakımı |
| C | Üçüncü taraf ayna API (ör. ezanvakti.emushaf.net; erişilebilirliği doğrulanmadı) | Hızlı | Bağımlılık, sürdürülebilirlik belirsiz |
| D | Olduğu gibi bırak; ekranda "Aladhan · Diyanet yöntemi (yaklaşık)" ibaresi | Sıfır iş | Fark kalır |

**Öneri:** Türkiye konumlarında Diyanet verisini birincil kaynak, Aladhan'ı yedek yapan
A seçeneği; yurt dışı konumlar Aladhan'da kalır. `PrayerTimeProvider` soyutlaması buna
hazır (`docs/ARCHITECTURE.md` → Provider soyutlaması); ADR 0004 gereği düzeltme ve
türetilmiş vakitler yine okuma anında uygulanır. Karar kullanıcıya bırakıldı.

## Yeniden üretme

```
curl "https://api.aladhan.com/v1/calendar/2026/9?latitude=41.0082&longitude=28.9784&method=13&school=0"
curl -A "Mozilla/5.0" "https://namazvakitleri.diyanet.gov.tr/tr-TR/9541"   # İstanbul; Şile 9547, Ankara 9206
```

## Ek — 2026-09-15: teyit ve resmi API kısıtları

Bugün İstanbul (`method=13`, ham koordinat) yeniden karşılaştırıldı; desen aynı
(Diyanet − Aladhan): İmsak/Güneş/Öğle 0, **İkindi −1, Akşam +1, Yatsı +2 dk**.
Diyanet ilçe sayfası `Yıllık Namaz Vakti` sekmesinde (`table#yourTable`) bugünden
31 Aralık 2027'ye 403 satır veriyor; sütunlar `Miladi Tarih, Hicri Tarih, İmsak, Güneş,
Öğle, İkindi, Akşam, Yatsı`. Sayfa `/tr-TR/<ilçeId>` → `/tr-TR/<ilçeId>/<slug>` 302 yapıyor.

Resmi AwqatSalah REST API (https://awqatsalah.diyanet.gov.tr, kılavuz ve taahhüt formu
aynı sayfadan indirildi):

- Erişim: imzalı "Kullanıcı İstek ve Taahhüt Formu" (ad, TC kimlik, iletişim, uygulama
  bilgisi) `dinisleriyk@diyanet.gov.tr` adresine gönderilir; onayla kullanıcı adı/şifre
  verilir. Taahhüt: kimlik bilgisi 3. kişiyle paylaşılmaz → **uygulamaya gömülemez**.
- Kimlik doğrulama: JWT access token 45 dk; refresh token 7 gün, her kullanımda döner.
- Uçlar: `Place/{Countries,States,Cities}` (Türkiye'de "City" = ilçe; `CityDetail` koordinat
  vermiyor, kıble açısı/Kâbe mesafesi veriyor), `PrayerTime/{Daily,Weekly,Monthly,Eid,Ramadan}/{cityId}`,
  `POST PrayerTime/DateRange` (yıllık; yer bazında **ayda 10 istek**), `Quota/My`.
- Kota: Developer rolü ilk 15 gün 100/gün; sonra Standart rol — genel olarak her endpoint,
  parametresiyle birlikte **~5–10 istek/gün**. Kılavuz s.5: *"geliştiriciler mobil veya web
  uygulamaları için kendi imkanları ile bu verileri host ederek kullanabileceklerdir."*
  Yani cihazdan doğrudan çağrı tasarım gereği yok; **kendi hosting katmanı şart**.
- Yanıt alanları: `fajr, sunrise, dhuhr, asr, maghrib, isha, astronomicalSunrise/Sunset,
  hijriDate*, gregorianDate*, qiblaTime, greenwichMeanTimeZone`.

Bu kısıtlar seçenek tablosunu daraltır: B seçeneği "runtime proxy" olmak zorunda değil;
zamanlanmış bir iş (CI cron) ilçe başına aylık/yıllık JSON üretip statik olarak yayınlayabilir
(GitHub Pages / Cloudflare Pages). Uygulama tarafı yalnızca `<host>/tr/<ilçeId>/<yıl>.json`
okur; kaynak (resmi API ya da onay gelene dek ilçe sayfası) uygulamayı etkilemez. Karar bekliyor.
