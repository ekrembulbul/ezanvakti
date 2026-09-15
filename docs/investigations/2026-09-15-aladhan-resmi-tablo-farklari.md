# Aladhan yöntemleri ile ülkelerin resmi tabloları arasındaki fark

- **Tarih:** 2026-09-15
- **Soru:** Türkiye'deki (Aladhan `method=13` vs Diyanet) sapma başka ülkelerde de var mı?
  "experimental" etiketi güvenilir bir gösterge mi?
- **Bağlam:** [Diyanet farkı incelemesi](2026-09-14-diyanet-vakit-farki.md); vakit-api tasarımında
  Aladhan'ın TR dışı ve fallback rolü.

## Yöntem

Resmi kaynağı programatik erişilebilen ülkeler için aynı ay/yıl, aynı koordinatla Aladhan
`/v1/calendar` çıktısı gün gün karşılaştırıldı. Değerler **resmi − Aladhan** dakikadır.
Aladhan `/v1/methods` listesinde yalnız iki yöntem "experimental" etiketli: **13 Diyanet** ve **16 Dubai**.

## Bulgular

| Ülke / şehir | Resmi kaynak | Aladhan | Fark (resmi − Aladhan) | Karakter |
|---|---|---|---|---|
| Türkiye / İstanbul | Diyanet ilçe tablosu | m13 (experimental) | İmsak, Güneş, Öğle 0; İkindi, Akşam, Yatsı ±1–2 | mevsimsel; sabit `tune` ile kapanmaz |
| Malezya / Kuala Lumpur (zon WLY01) | JAKIM e-solat API, 2026 tüm yıl (365 gün) | m17 (etiketsiz) | Fajr **+10,3** (+9…+12), Güneş −0,8, Öğle +2,8, İkindi +1,8 (0…+4), Akşam +2,0 (+1…+3), Yatsı +2,0 (+1…+3) | büyük sabit bileşen (ihtiyat dakikaları + zon referans noktası) **ve** ±1–1,5 dk mevsimsel bileşen |
| Fas / Rabat | Habous aylık tablo (13 Eyl–12 Eki 2026, 30 gün) | m21 (Aladhan Öğle +5, Akşam +5 ofset uygular) | Fajr 0/−1, Güneş **−3** (sabit), Öğle 0, İkindi −1, Akşam **−1** (sabit), Yatsı 0 | sabit; `tune` ile kapanır |
| Mısır / Kahire | Dar al-Ifta aylık tablo (Eylül 2026, 30 gün) | m5 | tümü 0/−1 | birebir; yalnız yuvarlama |

Erişilemeyen resmi kaynaklar (karşılaştırılamadı): Suudi Arabistan (ummulqura.org.sa SPA, API
görünmüyor), BAE (awqaf.gov.ae paketi obfuscate), Katar (JS kabuğu), Endonezya (Kemenag WAF
engeli), Singapur (MUIS sayfa yolu değişmiş), Ürdün/Cezayir/Tunus/Kuveyt (tablo yok).

## Yorum

- "experimental" etiketi resmi tabloyla uyumun göstergesi değil: etiketsiz m17 Fajr'da 10 dk
  sapıyor; etiketsiz m5 birebir; etiketli m13 ±2 dk.
- Uyumsuzluk üç türde: **yuvarlama** (Mısır), **sabit ofset** (Fas; Aladhan `tune` ile kapanır),
  **algoritmik/mevsimsel** (Türkiye, Malezya'nın artık bileşeni; yalnız resmi veriyle kapanır).
- Aladhan TR dışı konumlar ve fallback için yeterli; birebir resmi vakit her ülke için ayrı
  veri kaynağı projesidir. Türkiye için tek yol Diyanet verisi (bkz. vakit-api tasarımı).

## Yan bulgu — saat dilimi

tzdata 2026c `Africa/Casablanca`'yı 20 Eylül 2026'dan itibaren UTC+0 yapıyor; Aladhan da bu
kuralı uyguluyor (`19:33 (+01)` → `18:32 (+00)`), Habous tablosu ise UTC+1'de devam ediyor.
Hangisi doğru olsun, uygulama `HH:MM`'yi cihazın yerel saatine göre kuruyor
(`AwqatSalahProvider._parseTime`); Aladhan'ın varsaydığı dilim ile cihazın dilimi ayrışırsa
60 dk hata olur. Kural değişikliği yaşayan ülkeler için ayrı ele alınmalı (kapsam dışı).

## Yeniden üretme

```
curl "https://www.e-solat.gov.my/index.php?r=esolatApi/takwimsolat&period=year&zone=WLY01"
curl "https://api.aladhan.com/v1/calendar/2026/9?latitude=3.1390&longitude=101.6869&method=17"
curl -A "Mozilla/5.0" "https://www.habous.gov.ma/prieres/index.php"          # Rabat, Hicri ay
curl "https://api.aladhan.com/v1/calendar/2026/9?latitude=34.0209&longitude=-6.8416&method=21"
curl -A "Mozilla/5.0" "https://www.dar-alifta.org/ar/prayer"                 # Kahire, aylık
curl "https://api.aladhan.com/v1/calendar/2026/9?latitude=30.0444&longitude=31.2357&method=5"
```
