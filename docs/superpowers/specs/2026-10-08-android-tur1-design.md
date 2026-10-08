# Android Turu 1 — Eksikler ve Alarm Güvenilirliği

Tarih: 2026-10-08 · Baz: `dev` = `main` = 0.29.0 (`eb327d1`) · Platform: Android (Dart + Kotlin). iOS davranışı değişmez.

## Amaç

Android sürümünü mağazaya çıkmadan önce iOS düzeyine getirmek: bugün Android'de yanlış çalışan üç şeyi düzeltmek, iOS'ta yapılamadığı için "Android turuna" bırakılan alarm/ses özelliklerini yazmak ve hedef SDK 36 (Android 16) ile gelen davranış değişikliklerini kapatmak.

Bu tur Android yol haritasının 2. parçasıdır (1: Play hesabı ve kapalı test, 3: Android widget'ı, 4: gerçek cihaz doğrulaması). Widget, kalıcı "sıradaki vakit" bildirimi ve Android otomatik yedekleme bu turda yok (widget turu ve güvenlik taraması).

## Kullanıcı kararları

| # | Konu | Karar |
|---|---|---|
| K1 | Kapsam | Zorunlu 3 düzeltme + alarm ses seviyesi + çalma süresi sınırı + telefonu susturma + pil uyarısı + alarm yeniden kurma + sistemden dil + temalı ikon + Android 16 kontrolü |
| K2 | Telefonu susturma biçimi | Rahatsız Etme (öncelikli): kullanıcının o modda izin verdiği kişiler/tekrar arayanlar geçer |
| K3 | Susturmanın açılışı | Her aralıkta "Telefonu da sustur" anahtarı, kapalı gelir; açılınca izin ekranına gidilir |
| K4 | Alarm çalarken ses tuşu | Hiçbir şey yapmaz; ses sabit kalır |
| K5 | Çalma süresi dolunca | Erteleme hakkı varsa ertelenir; yoksa susar ve "Kaçırılan alarm" bildirimi kalır |
| K6 | Çalma süresi ayarı | Ayarlar'da tek genel ayar: 5/10/15/30 dk ya da sınırsız; varsayılan 10 dk |
| K7 | Pil uyarısı | Yalnız uygulamayı uyuttuğu bilinen markalarda, pil optimizasyonu açıksa ve açık alarm varken; "Bir daha gösterme" ile kapanır |
| K8 | Yaklaşım | Mevcut native katman genişletilir; yeni Flutter paketi eklenmez |

## Tasarım kararları

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D1 | Bildirim sesi | Ses başına kanal: `ezan_vakti_channel` (sistem sesi, **mevcut kimlik korunur**), `ezan_vakti_beep` (`res/raw/beep`), `ezan_vakti_silent` (sessiz, titreşimsiz). Kanal seçimi saf fonksiyonda | Android'de kanal sesi sonradan değişmez; mevcut kanal kimliği kullanıcının sistem ayarlarındaki tercihlerini taşır |
| D2 | Kısa ton dosyası | `ios/Runner/Sounds/beep.caf` → `android/app/src/main/res/raw/beep.wav` (16-bit PCM, `afconvert`) | Özgün sinüs tonu, telif riski yok; WAV bildirim sesi olarak desteklenir |
| D3 | Telefonu susturma API'si | `AutomaticZenRule` (Android 10+/API 29): uygulamanın tek kuralı, `INTERRUPTION_FILTER_PRIORITY`, `ZenPolicy` null (kullanıcının varsayılan politikası). Durum `setAutomaticZenRuleState` ile verilir | API 35+ hedefleyen uygulama genel DND'yi değiştiremiyor; sistem kuralları birleştirir (en kısıtlayıcı kazanır). "Eski haline dön" ve "kullanıcının kendi DND'sine dokunma" sistemden gelir |
| D4 | Susturma zamanlaması | Dart aralıkları hesaplar (saf planlayıcı), native'e tam listeyi verir. Native yalnız sıradaki sınıra (başlangıç/bitiş) tek bir `AlarmManager` alarmı kurar; her tetiklemede durumu uygular ve sonrakini kurar | Uygulama kapalıyken de çalışmalı; vakit verisi yalnız Dart'ta |
| D5 | Susturma ufku | ReminderRescheduler'a giden vakit listesi (bugün + 10 gün). Bildirim ve vakte bağlı alarmlarla aynı ufuk | Ayrı veri okuma yolu açmamak için; sınır kullanıcıya yazılır |
| D6 | Kullanıcının elle kapatması | Native son uyguladığı durumu saklar; yalnız istenen durum değişince sisteme yazar. Kullanıcı pencere içinde DND'yi kapatırsa uygulama açılınca yeniden açılmaz | K3'teki "elle değiştirdiyse geri alma" kuralı |
| D7 | Susturma izni yokken | Anahtar açık kayıtlı kalabilir; native `SecurityException`'ı yakalar, kural uygulanmaz. Ekranda anahtarın altında "Erişim kapalı — Aç" satırı | İzin sistem ayarlarından sessizce geri alınabiliyor |
| D8 | Alarm ses seviyesi | `Alarm.volume` (int?, %10–100, null = telefonun alarm seviyesi). DB v16: `alarms.volume INTEGER`. Çalarken `STREAM_ALARM` hedef seviyeye çekilir, 500 ms'lik koruyucu değişikliği geri alır, bitince önceki seviye geri yüklenir | "Çalarken kısılamasın" için tuş yutmak yetmez: çalar ekranı önde değilken tuşlar sistem akışını değiştirir |
| D9 | Ses tuşları | Çalar ekranında ses tuşları tüketilir (K4) | |
| D10 | Çalma süresi | `GeneralSettings.alarmRingLimitMinutes` (int?, null = sınırsız, varsayılan 10). AlarmScheduler her plana `ringLimitMinutes` olarak ekler; native servis zamanlayıcı kurar | Karar Dart'ta, uygulama native'de (ADR 0001 ilkesi); ayar değişince uzlaştırma kayıtları yeniler |
| D11 | Süre dolunca | Native mevcut erteleme geçişini (`AlarmMissions.snooze`) dener: başarılıysa nöbetçi zamanlayıcı kurulur ve çalma durur. Değilse kaydırarak durdurmayla aynı yol (`recordStop`). Görevsiz alarmda ya da zincir bittiyse "Kaçırılan alarm" bildirimi | Yeni durum makinesi yok; görevli alarmda zincir (ADR 0001) aynen sürer, alarm `graceSeconds` sonra yeniden çalar ve zincirin sert tavanları geçerlidir |
| D12 | Kaçırılan alarm bildirimi | Yeni sessiz kanal `ezan_vakti_alarm_missed` (IMPORTANCE_DEFAULT); alarm başına sabit kimlik, dokununca uygulama açılır | Alarm kanalı DND'yi deliyor ve heads-up; bilgi notu için fazla |
| D13 | Tam ekran izni | Android 14+ `NotificationManager.canUseFullScreenIntent()`; kapalıysa Hatırlatıcılar > Alarmlar'da uyarı, "Aç" → `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` (`package:` verisiyle; bulunamazsa uygulama ayrıntıları) | |
| D14 | Pil uyarısı | Native yalnız üreticiyi ve `isIgnoringBatteryOptimizations` sonucunu verir; karar saf Dart fonksiyonunda (marka listesi + kapatılmış mı + açık alarm var mı). "Aç" → `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS` (liste) | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` izni Play politikasında kısıtlı; liste ekranı izin gerektirmez |
| D15 | Marka listesi | xiaomi, redmi, poco, samsung, huawei, honor, oneplus, oppo, vivo, realme, meizu, asus, tecno, infinix (küçük harf, `Build.MANUFACTURER`/`BRAND`) | dontkillmyapp.com'daki yaygın vakalar; 4. parçadaki cihaz testinde güncellenir |
| D16 | Saat dilimi / saat değişimi | `AlarmBootReceiver` ayrıca `TIMEZONE_CHANGED`, `TIME_SET` ve `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`'i dinler. Saat dilimi değişince yalnız sabit saatli kayıtlar (`repeatHour` dolu) duvar saatini koruyacak biçimde kaydırılır; son bilinen dilim `ezanvakti_alarms` tercihinde tutulur | Vakte bağlı alarmlar ilçenin mutlak vaktine bağlı; Dart sonraki açılışta zaten yeniden planlar |
| D17 | Kıble pusulası | `HeadingStreamHandler.kt`: `TYPE_ROTATION_VECTOR` (yoksa `TYPE_GEOMAGNETIC_ROTATION_VECTOR`), ekran dönüşüne göre eksen düzeltmesi, `GeomagneticField` sapmasıyla gerçek kuzey. Koordinat Dart'tan dinleme argümanı olarak gelir; yoksa manyetik kuzey. Doğruluk: `values[4]` (radyan) varsa o, yoksa sensör doğruluk düzeyi (HIGH 10°, MEDIUM 20°, LOW 40°, UNRELIABLE −1). 1°'den küçük değişim yayımlanmaz | iOS'taki gibi gerçek kuzey; aynı olay sözleşmesi (`degrees`, `accuracy`) |
| D18 | Uygulama dili | `res/xml/locales_config.xml` (tr, en, ar) + `android:localeConfig`. Flutter yerel ayarı yapılandırmadan okuduğu için Dart değişmez | Android 13+ sistem ayarı; iOS'ta `CFBundleLocalizations` ile zaten var |
| D19 | Temalı ikon | Uyarlanabilir ikona `<monochrome android:drawable="@drawable/ic_launcher_foreground"/>` | Ön plan katmanı saydam zemin üstünde tek parça hilal (alfa ikili); ayrı çizim gerekmez |
| D20 | Android 16 geri hareketi | `AlarmRingActivity` API 33+'da `OnBackInvokedCallback` ile geri hareketini yutar; eski `onBackPressed` korunur | API 36 hedefte `onBackPressed` çağrılmıyor; çalar ekranı geri hareketiyle kapanabilirdi |
| D21 | Yeni native köprü | `com.ekrembulbul.ezanvakti/device` MethodChannel (`DeviceChannel.kt`): tam ekran izni, pil durumu, DND erişimi, susturma planı. Mevcut `exact_alarm` kanalı değişmez | Tek sorumluluk: cihaz ayarları/izinleri |

## Davranış

### 1. Ses ve sessizlik
- Bildirim sesi (Sistem / Kısa ton / Sessiz) Android'de seçilen kanaldan çıkar. Sessiz pencerenin "sessiz göster" kipi ve "Sessiz" ses seçimi sessiz kanala gider.
- `QuietWindow.silencePhone` (bool, varsayılan false, JSON'da `silencePhone`). Sessiz pencereler ekranında Cuma kartında ve özel aralık panelinde "Telefonu da sustur" anahtarı; özel satırın alt yazısına "· Telefon susar" eklenir.
- Anahtar açılırken erişim yoksa sistem ekranı açılır; uygulama öne dönünce erişim varsa anahtar açık kaydedilir, yoksa kapalı kalır.
- Android 9 ve öncesinde anahtar görünmez. `quietIntro` metni yeni davranışa göre güncellenir.

### 2. Alarm
- Alarm düzenleme ekranında (yalnız Android) "Telefonun ses seviyesi" anahtarı (varsayılan açık); kapatılınca %10–100 kaydırıcı (10'luk adım). iOS'taki "Zil Sesi ve Uyarılar seviyesiyle çalar" notu yalnız iOS'ta kalır. Altta ipucu: alarm çalarken ses tuşları sesi değiştirmez.
- Ayarlar'da (yalnız Android) "Alarm şu kadar sonra sussun" satırı: 5/10/15/30 dk, Sınırsız.
- Hatırlatıcılar > Alarmlar'da, en az bir açık alarm varken: tam ekran izni uyarısı (Android 14+) ve pil uyarısı (D14/D15, "Bir daha gösterme" kalıcı ayar `battery_warning_dismissed`).
- Saat dilimi değişince sabit saatli alarmlar yeni yerel saatte çalar; saat elle değişince ve kesin alarm izni yeniden verilince kayıtlar uygulama açılmadan yeniden kurulur. Kesin alarm izni yeniden verildiğinde susturma planı da yeniden kurulur.

### 3. Küçük eşitlik
- Kıble ekranı Android'de canlı yön alır; doğruluk eşiği aşılınca mevcut "sekiz çiz" uyarısı çıkar.
- Android 13+: Ayarlar > Uygulamalar > Ezan Vakti > Dil.
- Tek renk ikon teması açıkken hilal temaya uyar.

### 4. Android 16 kontrolü
Emülatörde (API 36): sekmeden geri → ana sekme, ana sekmede geri → çıkış; çalar ekranında geri hareketi bir şey yapmaz (D20); çalar ekranı sistem çubuklarının altına taşmaz; tablet/katlanabilir boyutta (≥600dp) yatay düzen bozulmaz. Bozuk çıkan küçükse bu turda düzeltilir, büyükse kullanıcıya sorulur.

## Mimari

### Dart
| Birim | Yer | Sorumluluk |
|---|---|---|
| `NotificationSounds.androidChannelFor` | `lib/core/constants/notification_sounds.dart` | (soundId, silent) → kanal kimliği; saf |
| `FlutterLocalNotificationService` | `lib/features/notifications/data/` | Üç kanalı `init`'te kurar; `scheduleNotification` kanalı seçer (API < 26 için ayrıntıda `playSound`/`sound`) |
| `QuietWindow.silencePhone` | `lib/core/models/quiet_window.dart` | Yeni alan, JSON, `copyWith` |
| `QuietPhonePlanner` | `lib/features/notifications/domain/quiet_phone_planner.dart` | Saf: pencereler + vakitler + şimdi → birleştirilmiş, sıralı, gelecekteki `QuietInterval` listesi |
| `QuietPhoneService` | `lib/features/notifications/data/quiet_phone_service.dart` | Planı native'e yollar; Android dışı no-op |
| `DeviceSettingsService` | `lib/core/services/device_settings_service.dart` | `device` kanalı: tam ekran izni, pil durumu, DND erişimi, ayar ekranları |
| `BatteryAdvice.shouldWarn` | `lib/features/alarms/domain/battery_advice.dart` | Saf karar (D14/D15) |
| `ReminderRescheduler` | `lib/presentation/services/` | Üçüncü bağımsız iş: susturma planı (hata diğerlerini engellemez) |
| `Alarm.volume`, DB v16 | model + `sqlite_storage.dart` | Kolon, map, migration |
| `GeneralSettings.alarmRingLimitMinutes` | `lib/core/models/general_settings.dart` | Anahtar `general_alarm_ring_limit` (`none` = sınırsız) |
| `AlarmPlanEntry.toMap` | `lib/core/models/alarm_plan.dart` | `volume`, `ringLimitMinutes` |
| `AlarmScheduler` | `lib/features/alarms/domain/` | Genel ayarı okuyup girdiye taşır |
| `HeadingService.headingsAt` | `lib/features/qibla/data/` | Koordinatı dinleme argümanı olarak verir; `headings` korunur |
| UI | `quiet_windows_screen.dart`, `alarm_edit_screen.dart`, `settings_screen.dart`, `alarms_section.dart`, `reminders_screen.dart`, `qibla_screen.dart` | Yukarıdaki davranış |

### Kotlin (`android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/`)
| Birim | Sorumluluk |
|---|---|
| `HeadingStreamHandler.kt` + saf `HeadingMath.kt` | Sensör akışı; açı normalleştirme, sapma, doğruluk eşlemesi |
| `DeviceChannel.kt` | `device` kanalı |
| `QuietSchedule.kt` (saf) | Aralık kodlama, içeride mi, sıradaki sınır |
| `QuietModeController.kt` | Kural oluşturma/silme, durum uygulama (D6), sınır alarmı |
| `QuietModeReceiver.kt` | Sınır alarmı alıcısı |
| `AlarmVolume.kt` (saf) | Hedef seviye indeksi |
| `AlarmTimeShift.kt` (saf) | Dilim değişiminde sabit kaydın yeni anı |
| `AlarmArgs.kt` | `volumePercent`, `ringLimitMinutes` (fromMap/JSON/isValid) |
| `AlarmRingService.kt` | Ses kilidi, çalma süresi zamanlayıcısı, kaçırılan alarm bildirimi |
| `AlarmRingActivity.kt` | Ses tuşları, geri hareketi |
| `AlarmBootReceiver.kt` | Yeni yayınlar, dilim kaydırma, susturma planını yeniden kurma |
| `MainActivity.kt` | Heading ve device kanallarını kaydeder |

Manifest: `ACCESS_NOTIFICATION_POLICY` izni, `QuietModeReceiver`, boot alıcısına yeni eylemler, `android:localeConfig`. Kaynaklar: `res/raw/beep.wav`, `res/xml/locales_config.xml`, `values{,-tr,-ar}/strings.xml` (kaçırılan alarm, kanal adı, kural adı).

## Hata yönetimi
- Native çağrıların hepsi `try/catch`; Dart tarafında `AppLogger` ile loglanır ve kullanıcı akışı sürer. Susturma planı hatası bildirim/alarm planlamasını engellemez (ReminderRescheduler'daki bağımsız işler).
- DND erişimi yokken `setAutomaticZenRuleState` / `addAutomaticZenRule` `SecurityException` atar; yakalanır, son uygulanan durum değişmez.
- Ses seviyesi yazılamazsa (`SecurityException`) alarm mevcut seviyede çalar; olay `AlarmJournal`'a yazılır.
- Süre dolunca erteleme zamanlayıcısı kurulamazsa oturum geri yüklenir ve durdurma yoluna düşülür.
- Pusula sensörü yoksa akış `heading_unavailable` hatası verir; kıble ekranı "bekleniyor"da kalmak yerine yeni "bu telefonda pusula yok" metnini gösterir.

## Test
- Dart birim: kanal seçimi; `QuietWindow` JSON (eski kayıtta `silencePhone` false); `QuietPhonePlanner` (Cuma, vakit tetiği, birleştirme, geçmişin atılması, `silencePhone`/`isActive` kapalı); `Alarm.volume` map; migration v15→v16 (`schema_migration_test`); `GeneralSettings` ring limit varsayılan/bozuk değer; `AlarmPlanEntry.toMap`; `AlarmScheduler` girdisi; `BatteryAdvice`; `ReminderRescheduler` üçüncü iş; `HeadingService.headingsAt` argümanı.
- Widget: sessiz pencere anahtarı (desteklenmeyen sürümde gizli), alarm ses seviyesi satırı (Android/iOS), ayar satırı, uyarı bantları.
- Kotlin JUnit: `AlarmArgs` yeni alanlar (map/JSON/isValid), `AlarmVolume`, `AlarmTimeShift`, `QuietSchedule`, `HeadingMath`.
- Komutlar: `dart format`, `flutter analyze`, `flutter test`, `flutter gen-l10n`, `cd android && ./gradlew testDebugUnitTest`, `flutter build apk --debug`.
- Emülatör (API 36): kanal listesi, kıble ekranı açılışı, dil ayarı, temalı ikon, geri hareketi, çalar ekranı.

## Sınırlar (teslimde yazılır)
- Unit/widget testleri ve emülatör, alarmın gerçek cihazda zamanında çaldığını, marka uyutmasını ve Rahatsız Etme'nin gerçek davranışını kanıtlamaz (4. parça).
- Susturma ufku yüklenmiş vakit penceresiyle sınırlı (bugün + 10 gün): uygulama ~10 gün hiç açılmazsa susturma durur.
- Saat dilimi değişiminde yalnız sabit saatli alarmlar kaydırılır; bildirimler uygulama açılınca yeniden planlanır.
- Pil uyarısının marka listesi tahmindir.

## Kapsam dışı
Android widget'ı ve kalıcı "sıradaki vakit" bildirimi (widget turu); otomatik yedekleme (güvenlik taraması); iOS'ta herhangi bir değişiklik; gömülü ezan kaydı; bildirim kanalı başına kategori ayrımı.

## Etkilenen ADR'ler
- 0003 (platform alarm modelleri): Android satırlarına ses seviyesi, çalma süresi ve DND kuralı eklenir.
- 0005 (bildirim planlaması): Android'de ses başına kanal ve telefon susturma planı.
