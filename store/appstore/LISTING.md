# App Store — mağaza kaydı, gizlilik ve inceleme cevapları

App Store Connect'e kopyalanacak metinler. Sınırlar: ad ve alt başlık 30, anahtar
kelimeler 100, tanıtım metni 170, açıklama 4000 karakter. Play karşılığı:
[`store/play/LISTING.md`](../play/LISTING.md).

---

## Uygulama bilgileri

| Alan | Değer |
|------|-------|
| Ad | Ezan Vakti & Alarm |
| Alt başlık | Diyanet vakitleri, sesli alarm |
| Birincil kategori | Yaşam Tarzı (Lifestyle) |
| İkincil kategori | Araçlar (Utilities) |
| Gizlilik politikası | https://ezanvakti.ekrembulbul.com/privacy |
| Destek adresi | https://ezanvakti.ekrembulbul.com/privacy (sayfada iletişim e-postası var) |
| Telif | 2026 Ekrem Bülbül |
| Fiyat | Ücretsiz |

## Sürüm sayfası — Türkçe

**Tanıtım metni** (129 karakter)

```
Diyanet'in namaz vakitleri, kapatana kadar çalan vakit alarmı, kerahat uyarısı, imsakiye, kıble ve widget. Hesap yok, reklam yok.
```

**Anahtar kelimeler** (95 karakter; ad ve alt başlıktaki kelimeler tekrar edilmez)

```
namaz,ezan,vakit,diyanet,imsakiye,kıble,alarm,sahur,iftar,kerahat,hutbe,zikirmatik,cami,ramazan
```

**Açıklama:** Play'deki tam açıklamanın aynısı ([`store/play/LISTING.md`](../play/LISTING.md)
"Tam açıklama"). iOS'ta bildirim çubuğundaki "sıradaki vakit" satırı yok; o madde
yerine "Kilit ekranı widget'ı: sıradaki vakit ve geri sayım" yazılır.

## Ekran görüntüleri

`integration_test/store_screenshots_test.dart` ile simülatörde alınır (komut dosyanın
başında). Gerekli boyutlar:
- iPhone 6,9": 1320 × 2868 (iPhone 18 Pro Max simülatörü)
- iPad 13": 2064 × 2752 (iPad Pro 13-inch simülatörü)

## Yükleme

Metin ve görüntüler fastlane `upload_to_app_store` eylemiyle yüklenir (2 Kasım 2026'da
1.0 sayfasına böyle yüklendi). Dikkat edilecekler:
- Yönetici yetkili API anahtarı gerekir (`A4VC6423F7`); TestFlight'ın `X4PW7D9887`
  anahtarı "Developer" yetkisinde, metin yazamaz. API JSON'unda anahtar dosya yolu
  değil içerik olarak (`key`) verilir.
- Sayfada "App Review Information" hiç kaydedilmemişse eylem metinleri yükledikten
  sonra "No data" ile düşer; görüntüler o zaman `skip_metadata:true` ile ayrıca yüklenir.
- Sürüm sayfası `1.0`; bu sayfaya yalnız sürüm adı 1.0.0 olan bir derleme bağlanabilir.

## Uygulama gizliliği (App Privacy)

Apple, yalnız isteği o anda karşılamak için işlenip saklanmayan veriyi "toplanan"
saymaz. Bu yüzden ~100 m'ye yuvarlanan GPS koordinatı ve il/ilçe arama metni
beyan dışıdır. Sunucunun erişim günlüğü IP adresini tutar; IP kaba konum verdiği
için muhafazakâr olarak beyan edilir.

| Veri türü | Toplanıyor | Kimliğe bağlı | İzleme | Amaç |
|-----------|-----------|---------------|--------|------|
| Konum → Kaba konum (Coarse Location) | Evet | Hayır | Hayır | Uygulama işlevselliği |

Diğer tüm veri türleri: toplanmıyor.

## Yaş derecelendirmesi

Tüm içerik soruları "Yok". Sınırsız web erişimi: Hayır (hutbe PDF'i ve kaynak
bağlantısı yalnız Diyanet sayfalarını açar). Beklenen sonuç: 4+.

## İnceleme notu (App Review Information)

Giriş gerekmez; demo hesabı yok.

```
No account or sign-in is needed.

On first launch, choose a district (e.g. search "Istanbul") or allow location to find the nearest one. Prayer times come from the Presidency of Religious Affairs of Türkiye (Diyanet) through our own server.

Alarms use AlarmKit: on the Reminders tab, add an alarm (fixed time or relative to a prayer time) and grant alarm permission when asked; it rings like the Clock app until stopped or snoozed. Location is used only to pick the nearest district and the qibla direction; the camera is used only if the user chooses the optional "scan QR code" task to stop an alarm.
```

### 2.1 "Information Needed" cevabı (1.0 reddi, 4 Kasım 2026)

Apple, inceleme notuna şunların eklenmesini istedi: gerçek cihazda, uygulamanın
açılışıyla başlayan ekran kaydı; amaç ve hedef kitle; kurulum ve ana özelliklere
erişim; dış servisler; bölgesel farklar; gerekiyorsa yetki belgesi. Kayıt 1.0.1
derlemesiyle (yeni sunucu adresi) çekilmelidir; 1.0.0 sunucuya ulaşamaz. Notlar
alanına aşağıdaki metin, kaydın bağlantısıyla birlikte yazılır.

```
1. Screen recording (physical iPhone, latest iOS, starting from app launch):
<RECORDING LINK>

2. Purpose and audience
Ezan Vakti & Alarm is a free prayer-times app for Muslims in Türkiye. It shows the daily prayer times published by the Presidency of Religious Affairs of Türkiye (Diyanet) for the user's district and rings an alarm at a prayer time (or a set offset before/after it) until the user stops or snoozes it, like the Clock app. It also offers a monthly prayer calendar, makruh (kerahat) time warnings, qibla direction, nearby mosques, the weekly Friday sermon, daily religious content, a dhikr counter and home/lock screen widgets. It solves a common problem: generic alarm apps cannot follow prayer times that shift every day, and notifications are easy to miss. There are no accounts, ads, in-app purchases or user-generated content.

3. Setup and main features
No login or sample files are needed. On first launch, search for a district (e.g. "Istanbul") or allow location to pick the nearest one; the home screen then shows today's times and a countdown. To create an alarm: Reminders tab > add > choose a prayer time (optionally with an offset) or a fixed time, choose days, save, and allow alarm permission when asked. Other features are on the main tabs and the home screen cards.

4. External services
- Our own server (ezanvakti.ekrembulbul.com) serves prayer times, district lists, religious days, the Friday sermon and daily content. The server collects this public data from Diyanet's official websites; the app never talks to third parties for this data. The server sits behind Cloudflare.
- Apple frameworks: AlarmKit (alarms), WidgetKit (widgets), Core Location (nearest district and qibla only), User Notifications.
- Apple Maps / Google Maps are opened by link only when the user taps a mosque.
No authentication, payment, analytics, advertising or AI services are used.

5. Regional differences
The app works the same in every region and its interface is available in Turkish, English and Arabic. Prayer-time data is currently provided for districts in Türkiye only, because the data source is Diyanet.

6. Regulated industry / third-party material
Not applicable. Prayer times, the Friday sermon and daily content are public information published by Diyanet, a government body, and are shown with their source.
```

## İhracat uyumluluğu

`ITSAppUsesNonExemptEncryption = false` (Info.plist); yalnız standart HTTPS.
