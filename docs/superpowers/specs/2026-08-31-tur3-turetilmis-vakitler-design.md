# Tur 3 — Türetilmiş Vakitler ve Takvim (0.8.0)

Tarih: 2026-08-31 · Baz: Tur 2 (`feat/tur2-ses-sessizlik`, DB v10) · Platform: yalnızca iOS

Tam tasarım artifact'ta ("Ezan Vakti 0.6+ Tasarımı", rev. 3, Tur 3 bölümü).

## Amaç

Türk kullanıcının aradığı, global uygulamalarda bulunmayan ayrıntılar: kerahat vakitleri, nafile namaz pencereleri, dini günler. Hepsi **API'siz** — mevcut vakit verisinden yerelde hesaplanır.

## Kapsam

### VKT.1 — Türetilmiş vakitler
Altı vakitten hesaplanan beş yeni hatırlatma noktası. Hepsi varsayılan **kapalı**; kullanıcı Hatırlatıcılar'dan ekler.

| Nokta | Hesap | Anlamı |
|---|---|---|
| `ishraq` | güneş + 45 dk | Kerahat-1 biter, işrak/duha başlar |
| `istiwa` | öğle − 10 dk | Kerahat-2 (zeval) başlar |
| `preMaghrib` | akşam − 45 dk | Kerahat-3 başlar |
| `midnight` | akşam + gece/2 | Şer'i gece yarısı |
| `lastThird` | ertesi imsak − gece/3 | Teheccüd penceresi başlar |

`gece = ertesi gün imsak − akşam`. Ertesi günün verisi yoksa gece vakitleri o gün için üretilmez (planlayıcı sessizce atlar; cache −2/+10 gün taşıdığı için normalde hep var).

45/10 dk sabitleri `DerivedTimeSettings` ile ayarlanabilir (takvimler farklı kabul kullanıyor); varsayılanlar yukarıdaki tabloda.

### VKT.2 — Dini günler
Kandiller, Ramazan/bayram başlangıçları, Aşure. Bildirim isteğe bağlı: günün kendisinde sabah + isteğe bağlı bir gün önce.

- Veri: `lib/core/data/religious_days.dart` — 2026–2028 için **elle girilmiş** tarihler; kapsam dışı yıllarda `hijri` paketiyle hesap ve "hesaplanmış" işareti. Diyanet takvimiyle ±1 gün sapabileceği arayüzde belirtilir.
- Takvim sekmesinde işaret; ana ekranda o gün şerit.

### VKT.3 — Aylık vakit paylaşımı
Takvim sekmesinden aylık tabloyu görsel olarak paylaşma. Yeni bağımlılık: `share_plus`. (.ics dışa aktarma ikincil; bu turda yok.)

## Kimlik ve şema kararları

- **`ReminderPoint`:** `NotificationSetting`e `derivedKind: DerivedTimeKind?` alanı eklenir. `null` ise satır bir namaz vakti içindir (`prayerType`); dolu ise türetilmiş noktadır ve `prayerType` o noktanın **çıpası** olarak kalır (ishraq→sunrise, istiwa→dhuhr, preMaghrib/midnight/lastThird→maghrib). Böylece `PrayerType` enum'u, widget snapshot'ı ve alarm çıpası hiç değişmez.
- **Bildirim ID şeması genişler.** Eski şemada vakit alanı tek hane (0–9); 6 vakit + 5 türetilmiş + dini gün = sığmaz. Yeni:
  ```
  id = (dayOrdinal % 10000) · 200000 + pointIndex · 10000 + minutesBefore
  ```
  `pointIndex`: 0–5 vakitler, 6–10 türetilmiş, 11 dini gün. 32-bit güvenli (maks ≈ 2.0e9).
  **Geçişte bekleyen "yalnızca bu sefer atla" kayıtları geçersizleşir** (kısa ömürlü; changelog'a yazılır).
- **DB v11:** `notification_settings` tablosuna `derived_kind TEXT`; UNIQUE `(prayer_type, minutes_before, weekdays)` → `(prayer_type, derived_kind, minutes_before, weekdays)`.
- `notificationKey` `derivedKind`i de kapsar.

## Kapsam dışı
- Türetilmiş vakte **alarm** kurma (alarm çıpası `PrayerType` kalıyor).
- .ics dışa aktarma, dini gün içerik metinleri (yalnızca ad ve tarih).
- Widget'ta türetilmiş vakit gösterimi.
- Android native işler.

## Doğrulama
`flutter analyze` + `flutter test` temiz; hesaplar ve ID şeması birim testli. Cihaz testi Ekrem'de.
