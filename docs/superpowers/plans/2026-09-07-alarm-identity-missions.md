# Alarm kimliği ve görev güvenilirliği düzeltme planı

**Goal:** Farklı alarmların etiket/görev durumlarının karışmasını, ileri günlerde görev kaybını ve durdurma anının çalma saati olarak gösterilmesini düzeltmek.

**Execution:** Kullanıcı tercihiyle inline; keşif, implementasyon, test ve review aynı agent tarafından yapılır. Kullanıcı düzeltmeleri açıkça onayladı.

**Architecture:** Planlanan native kayıt kimliği ile kullanıcı alarmının kimliği ayrılır. Native yapılandırmalar ve canlı görev durumları alarm/çalış bazında tutulur; durdurma intent'i kendi kayıt kimliğini taşır. Native olay kuyruğu farklı alarmları tüketip kaybetmez. Flutter, gösterdiği alarmın olaylarını işler; yanlış kimlikli begin/snooze/complete işlemleri diğer oturuma dokunmaz.

**Tech Stack:** Dart/Flutter, AlarmKit/AppIntents, Android AlarmManager/foreground service, mevcut SQLite/SharedPreferences/UserDefaults.

**Spec:** Kullanıcının “İş / Sabah namazı yedek” etiket karışması, görevli alarmın QR'siz kapanması ve 4–5 dakika gecikme şikâyetlerinin incelemesi. İncelenen başlangıç commit'i `d9cff79` (0.15.0+49). Kontrollü Swift örneğinde ortak native session son alarmı seçti; Dart örneğinde ileri gün kayıtları `mission=none` ve gösterilen `firedAt=stoppedAt` oldu. Android köprüsünde mission işlemleri yoktu. Gerçek cihaz gecikmesi kanıtlanmadı.

## Ortak kurallar

- İmsak/vakit offset hesabına keyfî dakika düzeltmesi eklenmez.
- Görev ve erteleme ayrı tercihlerdir. Görevli alarmın native ekranı Flutter görev akışına gider; uygulama içi sınırlı erteleme mevcut ayara uyar.
- Çıpalı her ileri gün kaydı görevi ve ana alarm kimliğini korur. Native kayıt kimliği çalış zamanına bağlı ve kararlı olur: `<alarmId>#at<epochMillis>`.
- `chainConfig` bütün kayıtlarda `alarmId`, `fireAtMillis`, `chainDeadlineMillis`, `graceSeconds`, `maxRearms`, `missionTimeoutSeconds`, `maxSnoozes` içerir. Mevcut ön yedekler yalnız sıradaki çalışma için +5/+10/+15 dakikada kalır; ileri günler stop intent'i üzerinden kendi nöbetçisini kurar, alarm sayısı gereksiz çoğalmaz.
- Olay kontratı: `alarmId`, `stoppedAt`, isteğe bağlı `firedAt`, `snoozeUsed`, `rearmCount`, `chainStopped`. Eski olaylar okunabilir; yeni olaylar planlanan çalışma zamanını açıkça taşır.
- `consumeMissionEvents({String? alarmId})`: belirtilmişse yalnız o alarm; belirtilmemişse kuyruktaki ilk alarmın olayları. Diğer alarmlar native kalıcı kuyrukta kalır.
- Tamamlama yalnız ilgili çalışın nöbetçi/yedeklerini temizler. Rutin yeniden planlama canlı görev zincirini kesmez. Eski parametresiz intent başka bir alarm tahmin ederek yönlendirilmez.
- iOS SDK schedule/cancel işlemleri sıralanır; bekleyen bir schedule iptalden sonra hayalet alarm bırakmaz. Android PendingIntent kimliği hash'e ek olarak tam id URI'siyle ayrılır.
- QR payload veya kullanıcı etiketi loglanmaz. Tanı için opak alarm kimliği, beklenen zaman, Android receiver zamanı ve durdurma zamanı ayrı loglanır.
- Yeni runtime dependency eklenmez. Native test için gerekirse yalnız test dependency kullanılır. `dev` üzerinde yerel commit; push/merge/release yok.

## 1. Dart planlama, olay ve görev akışı

**Files:** `alarm_scheduler.dart`, `mission_stop_event.dart`, `mission_coordinator.dart`, `alarm_service.dart`, `native_alarm_service.dart`, `mission_launcher.dart`, ilgili fakes/testler.

- [x] RED: ileri yedi çalışın tamamı QR/ana alarm id'si taşır; ilk native saat offset hesabıyla aynıdır; `firedAt` durdurmadan önceki gerçek plan zamanıdır; yanlış alarmı erteleme/başlatma diğer oturumu değiştirmez; farklı alarm olayları korunur.
- [x] `MissionStopEvent` isteğe bağlı zaman ve sayaç alanlarını ayrıştırır. Coordinator aynı alarmın yeni günü için sayaçları sıfırlar; aynı çalışı native sayaçlarıyla sürdürür.
- [x] Scheduler batch'lerini sıraya al; bütün çıpalı çalışlarda görev konfigürasyonunu ilet. Takvim günlerini `DateTime(year, month, day + i)` ile ilerlet.
- [x] Açık görev ekranı yalnız kendi id'sinin olaylarını tüketir; ekran kapandığında bekleyen sonraki alarm açılır. Başlatma/erteleme/tamamlama kimlik kontrolü uygulanır; erteleme kapalıysa çağrı reddedilir.
- [x] İlgili Dart/widget testleri ve analyze GREEN.

## 2. iOS alarm bazında durum ve kimlikli intent

**Files:** `ios/Runner/AppDelegate.swift`, yeni `AlarmMissionStore.swift`, `MissionChainKeys.swift`, native testler ve Xcode source üyeliği.

- [x] RED: A ve B yapılandırıldıktan sonra A'nın durdurulması A olayını üretir; B'nin bitmiş zinciri A'yı kapatmaz; A tamamlanınca B ve ileri günler kalır; olay filtresi B'yi kuyrukta bırakır; haftalık sonraki çalışma yeni zaman/sayaç alır.
- [x] Yapılandırma ve canlı durum ayrı kayıtlar olsun. `MissionStopIntent` schedule id parametresini handler'a geçirir; kaynak id kayıttan çözülür.
- [x] `firedAt`, sabit kayıtta kayıt zamanı; haftalık tekrarda kayıt saat/günlerine göre son geçerli çalışma anıdır. Watchdog, ilk çalışın zamanını korur.
- [x] Native bridge ve intent mutasyonlarını aynı async kuyruğa al; yedek schedule işlemlerini await et. Aktif zincir rutin refresh'te korunur; explicit cancel ana alarma ait kayıtları temizler.
- [x] Eski ortak session güvenilir alarm tahmini olarak kullanılmaz; yeni planlama id'li intent'leri kurar. Destek bildirimi gerçek iOS API tabanıyla aynı olur.
- [x] Native testler ve iOS simulator build GREEN.

## 3. Android görev köprüsü ve çalar ekranı

**Files:** `AlarmArgs.kt`, `AlarmChannel.kt`, `AlarmScheduling.kt`, `AlarmReceiver.kt`, `AlarmRingService.kt`, `AlarmRingActivity.kt`, `AlarmBootReceiver.kt`, yeni görev store/policy dosyası, Android testleri.

- [x] RED: görev/id/zaman alanları Intent ve kalıcı kayıtta korunur; iki alarmın session/event'leri ayrıdır; görevli STOP olay oluşturur ve Flutter'a gider; native SNOOZE görevi atlamaz.
- [x] Görevli alarmın STOP işlemi kalıcı event ve sınırlı watchdog üretir; Activity kullanıcı eyleminden Flutter'ı açar. Hazır engine'e callback, cold start'a kalıcı queue sağlanır.
- [x] begin/snooze/complete/abort/consume RPC'lerini uygula; native sayaç sınırları ve kaynak alarm id'si korunur. Foreground service başka id'nin STOP işlemiyle susturulmaz; önceki player sızdırılmaz; yeni intent ekranı yeniler.
- [x] PendingIntent tam kayıt id'siyle ayrılır. Fixed haftalık tekrar Android'de receiver üzerinden yeniden kurulur; reboot mevcut gelecek planları korur.
- [x] Native testler ve Android debug build GREEN.

## 4. Bütünlük kontrolü ve teslim

- [x] Birlikte iki görevli alarm, ileri gün, erteleme sınırı, başlatma/bitirme ve yeniden planlama senaryolarını inline review et.
- [x] `dart format`, `flutter analyze`, `flutter test`, native testler, Android debug ve iOS simulator build.
- [x] Mümkün olan simulator smoke; gerçek cihazda 4–5 dakika gecikmenin düzelmiş olduğu iddia edilmez. Planlanan/çalan/durdurulan zaman ayrımı doğrulanır.
- [x] Doğrulanmış değişiklikleri Türkçe Conventional Commit ile yerel `dev` dalına kaydet.

## Uygulama kaydı

- Dart ilk RED: yanlış id erteleme, başka session'ı silen complete, kapalı snooze, firedAt/stoppedAt ve ileri gün kimlik/görev testleri başarısız oldu (6 bulgu). Core düzeltmelerinden sonra ilgili 47 test geçti.
- UI RED: iki görevli alarmın sırayla açılması ve eşzamanlı açma çağrısı eklendi. Queue başlatılırken eager Future'ın test zone'u dışında kalması keşfedildi; lazy Future.sync ile düzeldi. Launcher/coordinator/QR koruma grubunda 48 test geçti.
- Erteleme kapatılırken normalizeAlarmSnoozeLimit'in QR payload'ını düşürdüğü ek hata RED/GREEN ile düzeltildi.
- iOS AlarmMissionStore yeni Foundation birimi ve 8 testi SwiftPM/XCTest host koşusunda geçti. Handler AppDelegate'den ayrıldı, id'li stop intent ve sıralı SDK operasyonları bağlanıyor; simulator build kontrolü sürüyor.
- Native store son yedekten ilk görevi başlatma ve son izinli rearm sınırı için ek testler yazıldı. Android görev köprüsü henüz uygulanmadı. Üretim değişiklikleri henüz commit'lenmedi.
- iOS handler'ın ilk simulator build'i başarılı (33,8 sn). AlarmMissionStore ve zincir seçim testleri 14/14 geçti; yedek başlangıcı ve son rearm sınırı ek RED/GREEN ile düzeltildi. Flutter launcher/coordinator/QR koruma 48/48 geçti. Android aşamasına geçiliyor; son tüm-suite/native SDK doğrulaması ve commit henüz bekliyor.
- Android native görev köprüsü, tam id'li PendingIntent, Activity intent yenileme, haftalık tekrar ve boot kurtarma eklendi. JVM testleri 10/10 geçti. Android 16 emülatöründe gerçek AlarmManager teslimi ve Flutter açılışı test edildi.
- İlk tüm Flutter koşusunda eski native id bekleyen üç assertion ve çift log beklentisi düzeltildi. Saat tam 13:15 olduğunda cetvel saatiyle karışan eski Home testinin seçicisi PrayerGrid'e daraltıldı. Son tüm Flutter koşusu 1108 geçti, 1 koşullu skip.
- Cold start yeniden planlamasının stop intent'inden önce kaydı silebildiği yarış için ek iOS testleri yazıldı. Yakın zamanda çalan kayıtlar kısa süre tutulur; haftalık template sonraki güne güncellense bile son çalışma doğru çözülür. iOS simulator XCTest 23/23 geçti.
- Android instrumented test başlangıcında Flutter integration_test runner sürümüyle çakışma ve eski helper manifest'lerinin exported bilgisi çözüldü. İlk iki platform testi geçti. Çok yakın (+2 sn) kurulan alarmda yaklaşık 3 sn teslim farkı gözlendi; +10 sn ölçümü için ayrı geçici emulator data alanı kullanıldı. Ölçümler 132/141 ms oldu. Nöbetçi kaydı bitmeden assert eden test, geçişin tamamlanmasını bekleyecek şekilde düzeltildi.
- Android debug APK build başarılı; mevcut KGP/deprecation uyarıları sürüyor. Son native test tekrarı, format/analyze, dokümantasyon ve yerel commit kapanışı bekliyor.


## Son doğrulama

- Flutter: 1108 test geçti, 1 koşullu DST testi skip edildi; analyze temiz.
- iOS: simulator XCTest 23/23; son simulator debug build başarılı.
- Android: 10 JVM unit testi ve Android 16 emülatöründe 2 instrumented test geçti; debug APK build başarılı.
- Native zaman gözlemi: ilk +2 saniyelik testte ~3 saniye teslim farkı; +10 saniyelik örneklerde 132/141 ms gözlendi. Bu ölçüm gerçek kullanıcı cihazında 4–5 dakikalık gecikmenin ortadan kalktığını kanıtlamaz.
- Kod geçişi: yeni build yüklenip uygulama açılınca eski native planlar yeni kimlikli kayıtlarla yenilenir. Önceki sürümde QR içeriği silinmişse veri tahmin edilmez; kullanıcının kodu yeniden seçmesi gerekir.
- Native test runner sürüm/manifest uyumu, geçici emülatör depolama sınırı ve testin ara durumu erken okuması giderildi; başarısız denemeler gizlenmeden takip edildi.
- Tüm çalışma inline yürütüldü; push, merge veya release yapılmadı.
