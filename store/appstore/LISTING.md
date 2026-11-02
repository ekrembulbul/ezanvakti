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
| Gizlilik politikası | https://ezanvakti.ekrembulbul.me/privacy |
| Destek adresi | https://ezanvakti.ekrembulbul.me/privacy (sayfada iletişim e-postası var) |
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

## İhracat uyumluluğu

`ITSAppUsesNonExemptEncryption = false` (Info.plist); yalnız standart HTTPS.
