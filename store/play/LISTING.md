# Google Play — mağaza kaydı ve App content cevapları

Play Console'a kopyalanacak metinler. Uzunluk sınırları: ad 30, kısa açıklama 80,
tam açıklama 4000 karakter. Data Safety cevapları ayrı: `docs/PLAY_DATA_SAFETY.md`.

---

## Uygulama oluşturma

| Alan | Değer |
|------|-------|
| Uygulama adı | Ezan Vakti & Alarm |
| Varsayılan dil | Türkçe – tr-TR |
| Uygulama mı, oyun mu? | Uygulama |
| Ücretsiz mi, ücretli mi? | Ücretsiz |
| Beyanlar | Geliştirici Programı Politikaları ve ABD ihracat yasaları kutuları işaretlenir |

Paket adı (`com.ekrembulbul.ezanvakti`) ilk AAB yüklemesinden gelir.

## Mağaza ayarları

| Alan | Değer |
|------|-------|
| Kategori | Yaşam Tarzı |
| İletişim e-postası | ekrembulbull@proton.me (gizlilik politikasındaki adres) |
| Gizlilik politikası | `docs/privacy.html` yayımlandığı URL |

---

## Ana mağaza kaydı — Türkçe (tr-TR)

**Kısa açıklama** (76 karakter)

```
Diyanet vakitleri, sesli vakit alarmı, kıble, imsakiye ve widget. Reklamsız.
```

**Tam açıklama**

```
Ezan Vakti & Alarm, Diyanet İşleri Başkanlığı'nın namaz vakitlerini gösterir; vakitler için bildirim ya da sen kapatana kadar çalan alarm kurar. Hesap açman gerekmez, reklam yoktur.

VAKİTLER
• Bulunduğun ya da seçtiğin ilçenin Diyanet vakitleri ve sıradaki vakte geri sayım
• Kerahat vakitleri; kerahat yaklaşırken uyarı
• Aylık vakit takvimi, Ramazan'da imsakiye; takvimi görsel olarak paylaşma
• Vakitler cihazda saklanır, internet yokken de görünür

HATIRLATICILAR
• Her vakit için bildirim: vaktinde, önce ya da sonra; istediğin günlerde
• Sesli alarm: telefon sessizdeyken de çalar, kapatana kadar sürer, ertelenebilir
• Vakte göre alarm ("İmsaktan 15 dk önce" gibi) ya da sabit saatli alarm
• Görevle kapatma: matematik sorusu, telefonu sallama ya da QR kod okutma
• Sesin yavaşça yükselmesi seçeneği
• Sessiz pencereler: cuma namazı gibi aralıklarda bildirimleri sessize alma
• Dini günler: kandiller, bayramlar, Ramazan başlangıcı
• Bir vakti yalnız o seferlik atlama

ARAÇLAR
• Kıble pusulası
• Diyanet'in cuma hutbesi
• Yakındaki camiler (harita uygulamanda)
• Namaz ve oruç takibi, kaza sayacı
• Zikirmatik
• Günün ayeti, hadisi ve duası

WIDGET
• Ana ekran widget'ı: sıradaki vakit, geri sayım ve günün vakitleri
• İstersen bildirim çubuğunda sabit "sıradaki vakit" satırı

DİĞER
• Türkçe, İngilizce ve Arapça
• Açık ve koyu tema; gün içinde vakitle değişen renkler
• Her vakti −15 ile +15 dakika arasında düzeltme

GİZLİLİK
Konumun yalnız en yakın ilçeyi bulmak için, yaklaşık olarak ve saklanmadan kullanılır. Ayarların ve vakitler yalnız cihazında tutulur. Analitik ya da reklam servisi kullanılmaz.
```

## Çeviri — English (en-US)

Uygulama adı: `Prayer Times & Alarm`

**Short description** (79 karakter)

```
Diyanet prayer times, loud alarms, qibla, monthly timetable and widget. No ads.
```

**Full description**

```
Prayer Times & Alarm shows the official prayer times of the Presidency of Religious Affairs of Türkiye (Diyanet) and sets notifications or alarms that keep ringing until you stop them. No account, no ads.

PRAYER TIMES
• Diyanet times for your current or chosen district, with a countdown to the next prayer
• Makruh (kerahat) times, with a heads-up before they begin
• Monthly timetable and Ramadan imsakiye; share the timetable as an image
• Times are stored on the device and work offline

REMINDERS
• Notifications for each prayer: on time, before or after, on the days you pick
• Loud alarms that ring even when the phone is silent, until you stop or snooze them
• Alarms relative to a prayer ("15 min before Fajr") or at a fixed time
• Dismiss with a task: math question, shake the phone or scan a QR code
• Gradually increasing volume
• Quiet windows, e.g. during Friday prayer
• Religious days: holy nights, Eids, start of Ramadan
• Skip a single prayer just once

TOOLS
• Qibla compass
• Diyanet's Friday sermon
• Nearby mosques (in your maps app)
• Prayer and fasting tracker, missed prayer counter
• Tasbih counter
• Verse, hadith and prayer of the day

WIDGET
• Home screen widget: next prayer, countdown and today's times
• Optional pinned "next prayer" line in the notification shade

MORE
• Turkish, English and Arabic
• Light and dark themes; colours that follow the time of day
• Adjust each prayer time by −15 to +15 minutes

PRIVACY
Your location is used only to find the nearest district, approximately and without being stored. Your settings and prayer times stay on your device. No analytics or ad services.
```

## Grafikler

- Uygulama simgesi: `store/play/icon_512.png`
- Öne çıkan grafik: `store/play/feature_graphic_1024x500.png`
- Telefon ekran görüntüleri: 1080×2160 (2:1); emülatörden release APK ile alınır

---

## App content cevapları

| Bölüm | Cevap |
|-------|-------|
| Gizlilik politikası | `docs/privacy.html` yayımlandığı URL |
| Reklamlar | Uygulamamda reklam yok |
| Uygulama erişimi | Tüm işlevler özel erişim gerektirmez |
| İçerik derecelendirme | Kategori: "Diğer tüm uygulama türleri"; şiddet, cinsellik, dil, madde, kumar, kullanıcı etkileşimi, konum paylaşımı, dijital satın alma sorularının hepsi **Hayır** |
| Hedef kitle | 13–15, 16–17, 18+ (13 yaş altı seçilmez; Aile politikası devreye girer). "Çocukların ilgisini çekebilir mi?" → Hayır |
| Haber uygulaması | Hayır |
| Devlet uygulaması | Hayır |
| Finansal özellikler | Finansal özellik yok |
| Sağlık | Sağlık özelliği yok |
| Data safety | `docs/PLAY_DATA_SAFETY.md` |

### İzin beyanları (İngilizce yazılır, inceleme ekibi okur)

**Foreground service — `mediaPlayback`**

- Feature: `Prayer-time alarms. When an alarm the user set fires, a mediaPlayback foreground service plays the alarm sound until the user stops or snoozes it, so the alarm keeps ringing while the screen is locked or another app is open.`
- Impact if deferred or interrupted: `The alarm would be silent or stop early and the user would miss the prayer time they explicitly asked to be alerted for.`
- Video: alarm kurma → telefon kilitliyken alarmın çalması → kaydırarak durdurma akışını gösteren liste dışı YouTube bağlantısı.

**Full-screen intent**

- Uygulamanın çekirdek işlevi alarm olduğu için "alarm" beyanı seçilir.
- Açıklama: `Alarm clock app: when a user-set prayer-time alarm rings while the device is locked, a full-screen alarm screen lets the user stop or snooze it.`

**Exact alarm (`USE_EXACT_ALARM`)** — Console isterse

- `Alarm clock app: users set alarms at prayer times or a fixed time and expect them to ring at that exact minute.`
