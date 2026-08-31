# Tur 4 — Araçlar ve Sistem Yüzeyleri (0.9.0)

Tarih: 2026-08-31 · Baz: Tur 3 (`feat/tur3-turetilmis-vakitler`, DB v11) · Platform: yalnızca iOS

Tam tasarım artifact'ta ("Ezan Vakti 0.6+ Tasarımı", rev. 3, Tur 4 bölümü).

## Amaç

Rakiplerde istisnasız bulunan ama bizde olmayan üç araç (kıble, namaz takibi, zikirmatik) ve iOS'un uygulama dışı yüzeyleri (Siri, kilit ekranı halkası).

## Navigasyon kararı

Dördüncü sekme: **Vakitler / Takvim / Hatırlatıcılar / Araçlar**. Araçlar sekmesi kıble, takip ve zikirmatiği barındırır. (App bar ikonlarına dağıtmak üç araçla sıkışıyordu.)

## Kapsam

### ARC.1 — Kıble pusulası
- Kâbe yönü (21.4225°K, 39.8262°D) büyük daire formülüyle **saf Dart**'ta hesaplanır: `QiblaDirection.bearing(from)` → 0–360° (kuzeyden saat yönünde).
- Cihaz yönü için yeni bağımlılık **yok**: `EventChannel('com.ekrembulbul.ezanvakti/heading')` — iOS'ta `CLLocationManager.startUpdatingHeading` (gerçek/true heading, manyetik değil). Mevcut alarm MethodChannel'ıyla aynı disiplin.
- Kalibrasyon: `headingAccuracy < 0` ya da > 25° ise arayüz "pusulayı sekiz çizerek kalibre et" uyarısı gösterir.
- Hizalanınca (±5°) haptik geri bildirim. AR ve harita kapsam dışı.
- Konum yoksa/izin yoksa: açıklayıcı boş durum, hesap yapılmaz.

### ARC.2 — Namaz takibi ve kaza sayacı
- **DB v12:** `prayer_log(date TEXT, prayer_type TEXT, status TEXT, PRIMARY KEY(date, prayer_type))` — status: `done | qada | missed`; `qada_counts(prayer_type TEXT PRIMARY KEY, count INTEGER NOT NULL)`.
- Araçlar > Takip: son 7 günün 5×7 ızgarası (güneş hariç), dokunuşla döngü `boş → kıldım → kaza → boş`.
- Kaza sayacı: vakit başına +/− ve elle giriş.
- **Bilinçli dışarıda:** streak/rozet oyunlaştırması — ürünün tonuna uymuyor.

### ARC.3 — Zikirmatik
- **DB v12:** `dhikr_log(date TEXT PRIMARY KEY, count INTEGER NOT NULL)` — günlük toplam.
- Tam ekran dokunma alanı, haptik, hedef (33/99/100/500/1000/özel), tur sayısı, sıfırlama onayı.
- Widget düğmesi bu turda yok.

### ARC.4 — Sistem yüzeyleri
- **App Shortcuts (Siri):** `NextPrayerIntent` — widget extension'daki `SnapshotStore`dan okur, "Akşam 19:42, 1 sa 12 dk kaldı" döner. Salt okuma.
- **`accessoryCircular` widget:** `ProgressView(timerInterval:)` ile vakte kalan oran halkası + vakit kısaltması.
- **Widget saat formatı:** kullanıcının 12/24 tercihi App Group üzerinden widget'a taşınır (snapshot şeması değişmez, ayrı anahtar).
- **Control Center toggle:** araştırma sonucu **kapsam dışı** — widget extension'dan `UNUserNotificationCenter`a erişim ve planlanmış bildirimleri değiştirme güvenilir değil; toggle "sessiz" iddiasında bulunup çalışmazsa yanlış güven verir. Yerine Siri/Spotlight'tan "Sıradaki vakit" yeterli.

## Kapsam dışı
- Namaz takibinde bildirimden "Kıldım" aksiyonu, istatistik ekranı, bulut yedeği.
- Zikir türü kataloğu, widget'tan sayaç.
- Android native (sensör köprüsü, widget).

## Doğrulama
`flutter analyze` + `flutter test`; kıble açısı, takip döngüsü ve depo katmanı birim testli. Swift saf mantık RunnerTests'e. Cihaz testi Ekrem'de (pusula ve Siri yalnızca cihazda anlamlı).
