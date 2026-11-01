# Android ilk geri bildirim turu

## Özet

**Amaç** — Android'de kalıcı bildirim ve widget'larda yazılar dengeli olsun, vakit saati kesilmesin;
bildirime dokununca bildirim kaybolmasın; sessiz pencereler ekranı anlaşılır olsun; alarmlara "Bir kez"
seçeneği gelsin. Bitti ölçütü: testler ve iki platformun build'i yeşil, sürüm iki platforma çıkmış.

**Kapsam** — Bildirim, widget ve sessiz vakitler yalnız Android. Tek seferlik alarm iki platform. iOS
widget'ları ve görünümleri değişmez. Widget renk paleti ve telefonu susturma mantığı kapsam dışı.

**Yaklaşım**
- Bildirim planları yeniden kurulurken yalnız planlanmış bildirimler silinir; ekrandaki kalıcı bildirim
  silinmez.
- Bildirimde geri sayım küçülür (kapalı 22, açık 26, normal ağırlık); yer daralırsa saat değil etiket
  kısalır. Açık görünüm içeriği kadar uzar, altta boş alan kalmaz.
- Widget'larda esnek boşluklar kalkar; içerik sabit aralıklarla tek blok halinde dikeyde ortalanır.
  Büyük widget'ta vakit adı ile saati üst üste durur, saat 24'e büyür.
- Tek seferlik alarm: ayrı bayrak ve hedef kaynak gün saklanır; alarm çalıp zincir süresi geçince
  ve bekleyen oturum yoksa uygulama alarmı kapatır. Native taraf değişmez.

**Davranış**
- Ekranın adı "Sessiz vakitler". Üstte basit bir "Cuma namazında sessiz" kartı: tek anahtar ve bu
  cumanın saat aralığı; dokununca ayrıntı paneli. Altta özel sessiz vakitler listesi; her satır bugünün
  gerçek saat aralığını gösterir. Ekle düğmesi düzenleme panelini açar. Panelde aralık bir çizgi üzerinde
  görünür; bildirim seçeneği "Sessiz gelsin / Hiç gelmesin" iki parçalı düğme.
- Tekrar bölümünde "Bir kez" seçeneği; seçilince gün kutuları söner ve ne zaman çalacağı tek cümleyle
  yazar. Listede "Bir kez · Yarın". Çalıp bitince kapanır; yeniden açılırsa sıradaki uygun güne kurulur.
  Bu alarmlarda "Yalnızca bu sefer" atlama seçeneği gösterilmez.

**Riskler** — Alarm çaldıktan sonra zincir süresi boyunca açık görünebilir. Veritabanı geçişi (v17)
gerekir. Testler cihazda zamanında çalmayı ve Samsung'daki gerçek görünümü kanıtlamaz.

## Görevler

- [x] **Görev 1 — Kalıcı bildirim yeniden planlamada silinmez** · dosyalar:
  `lib/features/notifications/data/flutter_local_notification_service.dart`, ilgili test · doğrulama:
  `flutter test test/notifications`
- [x] **Görev 2 — Bildirim ve widget yerleşimi** · dosyalar: `android/app/src/main/res/layout/notification_next_prayer*.xml`,
  `widget_medium.xml`, `widget_small.xml`, `widget_preview.xml`, `widget/NextPrayerNotification.kt`,
  `widget/WidgetRenderer.kt` · doğrulama: `./gradlew :app:testDebugUnitTest`, `flutter build apk --debug`
- [x] **Görev 3 — Sessiz vakitler ekranı** · dosyalar: `lib/presentation/screens/quiet_windows_screen.dart`,
  `lib/l10n/app_{tr,en,ar}.arb`, ekran testleri · doğrulama: `flutter test test/widgets/screens/quiet_windows*`
- [ ] **Görev 4 — Tek seferlik alarm** · dosyalar: alarm modeli, SQLite şeması (v17), alarm planlayıcı,
  alarm düzenleme ekranı, etiketler, alarm listesi ve hatırlatmalar ekranı, ARB, ADR 0004, testler ·
  doğrulama: `flutter test test/alarms test/storage test/presentation test/widgets` · önce: Görev 3 (ARB)
- [ ] **Görev 5 — Tam doğrulama** · `flutter analyze`, `flutter test`, `flutter build apk --debug`,
  `flutter build ios --simulator --debug`

## Kararlar

- 2026-11-01 Cuma sessizliği ayrı ve basit bir kart olarak kalır (kullanıcı geri bildirimi); listede
  rozetli satır önerisi geri alındı.
- 2026-11-01 Açık bildirimin altında boş alan bırakılmaz (kullanıcı geri bildirimi).
