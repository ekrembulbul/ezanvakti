# Fiziksel cihazda alarm incelemesi — 8 Eylül 2026

İncelenen uygulama: **0.17.0 (51)**. Cihaz: **iPhone 17, iOS 26.6.1 (23G83)**. Bu bilgiler bağlı cihazdan okundu. İnceleme salt okunur yürütüldü; telefona build yüklenmedi, test alarmı eklenmedi ve mevcut alarmlar değiştirilmedi.

Bu rapor, [kod ve simülatör incelemesini](2026-09-08-alarm-017-audit.md) fiziksel cihaz kanıtlarıyla tamamlar. Ham log arşivi, SQLite kopyası, native preferences ve cihaz kimlikleri yalnız yerel, ignore edilen `build/alarm-device-audit-20260908/` dizininde tutulur. QR içerikleri rapora alınmadı.

## 8 Eylül için ana sonuç

**Kritik hata, görev kaydının oluşturulmasını uygulamanın kilit ekranından başarıyla açılmasına bağlamak.** Sistem alarmı önce durduruyor. `MissionStopIntent.openAppWhenRun=true` nedeniyle `perform()` çağrılmadan önce uygulamanın öne açılması bekleniyor. Telefon açılamazsa sistem `Locked / RequestDenied` ile çıkıyor. Böylece bizim durdurma kaydımız, görev session'ı ve kısa nöbetçi kurulumu hiç çalışmıyor. Önden kurulmuş +5/+10/+15 alarmlar ise bağımsız olarak devam ediyor.

İkinci somut hata: kilit ekranında başarısız kalan ertelenmiş alarmdan sonra uygulama açılınca **geçmişteki snooze tarihi yeniden planlanıyor**. 08.38'de görülen tekrarlı `invalidInput` hatalarının bu kod yolu ile eşleştiği doğrulandı.

## Kanıt kaynakları ve sınırları

- Native UserDefaults: `ezanvakti_alarm_missions_v2` ve UUID eşlemeleri. Kaynak çalış, fallback rolü, erteleme sayacı ve görev session'ı okunabildi.
- SQLite: üç aktif alarmın QR görevi ve QR yapılandırması var. Üçünde de erteleme **açık**, süre **10 dakika**, sınır **1 kez**. Bu, görev tanımının tek başına ertelemeyi kapatmadığını gösterir; sistem düğmesindeki metnin kaynağını tek başına açıklamaz.
- Sistem arşivi: ilk aktarım 7 Eylül 19.27–8 Eylül 13.27 aralığını kapsıyor. `mobiletimerd`, `com.apple.AlarmKitCore` ve `com.apple.appintents` olayları zaman ve native kayıt kimliğiyle eşleştirildi.
- Root ve Retired çökme listelerinde uygulamaya ait bir crash raporu bulunmadı. Bu, uygulamanın hiçbir hata yaşamadığı anlamına gelmez; foreground açılış reddi ve schedule hataları loglarda mevcut.
- `Firing event` / `.alerting` kaydı, OS tetiklemesini kanıtlar. Sesin kullanıcı tarafından duyulduğunu veya fiziksel hoparlör çıkışını ölçmez.

## Görev açılmamasının kesinleşen zinciri

Kaynaklar: [AppDelegate.swift](../../ios/Runner/AppDelegate.swift), `MissionStopIntent` (30–43); [AlarmKitHandler.swift](../../ios/Runner/AlarmKitHandler.swift), `handleStop` (111–135).

05.46 ana çalışı için:

| Yerel saat | Gerçek cihaz kaydı |
| --- | --- |
| 05:45:59.980 | AlarmKit `Firing event`, ardından `Scheduled alarm is due to begin`. |
| 05:45:59.981 | `.alerting` durumunda sistem activity'si oluşturuluyor. |
| 05:46:06.732 | Sistem intent aksiyonunu başlatıyor ve alarmı durduruyor. |
| 05:46:06.763 | `MissionStopIntent` bulunuyor; `scheduleId` çözülüyor. |
| 05:46:06.763 | `ContinueInApp` başlıyor. |
| 05:46:17.296 | Uygulamayı açma isteği `FBSOpenApplicationServiceErrorDomain / RequestDenied`, alt neden `Locked` ile reddediliyor. |
| 05:46:17.297 | PerformAction sonlanıyor. `MissionStopIntent.perform()` çağrısı gerçekleşmiyor. |
| 05:50:59.980 | Ayrı ilk fallback alarmı tetikleniyor. |
| 05:51:07.572 | Bu kez `MissionStopIntent.perform()` çalışıyor. Native session'ın başlangıç kaydı ilk fallback. |

Sistemin açıkladığı hata nedeni:

```text
Unable to launch com.ekrembulbul.ezanvakti because the device
was not, or could not be, unlocked.
```

Aynı foreground açılış reddi 05.26, 05.31, 05.36 ve 08.10'daki durdurmalarda da var. 05.41'de uygulama açılabiliyor ve görev akışı ilk kez başlayabiliyor.

**Önemli ayrım:** gerçek telefonda `MissionStopIntent` bulunuyor. Önceki iOS 26.5 simülatör denemesindeki “intent bulunamadı” hatası bu sabahın kök nedeni değil. Telefonda kırılma daha sonraki `ContinueInApp` aşamasında.

## Beş dakikalık gecikme bildirimi

05.46 ana alarmı OS tarafından zamanında tetiklenmiş ve yaklaşık 7 saniye sonra durdurulmuş. 05.51'deki olay aynı kaydın geç teslimi değil, farklı native kimlik taşıyan **+5 dakika fallback** kaydı.

Native görev session'ının yapılandırması da bunu bağımsız doğruluyor: kaynak saat 05.46, session'ın başladığı kayıt `#ladder0`, bu kaydın plan saati 05.51.

05.26 alarmının session'ı ise 05.41'deki `#ladder2` kaydından başlamış. Önceki durdurmalarda uygulama açılamadığı için session oluşturulamamış.

05.51 civarında ayrıca iki ayrı alarm var: ikinci alarmın fallback'i 05:50:59.980'de; ilk alarmın 10 dakikalık ertelemesi 05:51:15.873'te tetikleniyor. Aynı dakika içinde farklı kaynakların çalması, bu olayları id ile takip etmeyi gerekli kılıyor.

Bu bulgular, bütün cihazlarda zamanlama sorunu olmadığını kanıtlamaz. **Bu sabah incelenen ana çalışta beş dakikalık OS planlama gecikmesi görülmüyor.** Duyulan ses ile OS durumu arasındaki fark ayrıca fiziksel olarak test edilmeli.

## 08.00 alarmı ve 08.38 hata ekranı

| Yerel saat | Olay |
| --- | --- |
| 08:00:00.028 | Sabit saatli ana alarm için `Firing event` ve `.alerting`. |
| 08:00:08.694 | Sistem alarmı durduruyor, uygulamayı açma akışını başlatıyor. |
| 08:00:15.495 | `MissionStopIntent.perform()` başarıyla çalışıyor. Native durdurma session'ı oluşuyor. |
| 08:00:21.032 | Yeni erteleme alarmı kuruluyor. Native kayıtta erteleme sayacı 1. |
| 08:10:21.001 | Ertelenmiş alarm tetikleniyor. |
| 08:10:29.708 | Sistem bu alarmı durduruyor. |
| 08:10:40.253 | Uygulama yine kilit nedeniyle açılamıyor; `perform()` çalışmıyor. |
| 08:38:31–08:38:39 | Altı kurulum denemesi, geçmiş fixed tarih nedeniyle reddediliyor. |

OS hataları:

```text
Cannot schedule an alarm with a fixed date in the past
AlarmKit.AlarmServiceError.Code.invalidInput
```

Kodda karşılığı: [AlarmMissionStore.swift](../../ios/Runner/AlarmMissionStore.swift), `begin` (221); [AlarmKitHandler.swift](../../ios/Runner/AlarmKitHandler.swift), begin/snooze işleminde tarih seçimi (81).

`begin`, süresi geçmiş `snoozedUntilMillis` değerine izin veriyor ve yeni `deadlineMillis` hesaplıyor, fakat eski `snoozedUntilMillis` alanını temizlemiyor. Handler şu önceliği kullanıyor:

```swift
session.snoozedUntilMillis ?? session.deadlineMillis
```

Bu yüzden 08.38'de yeni görev son tarihi yerine geçmiş erteleme saati seçiliyor. Sonraki retry da aynı eski değeri seçiyor. Bu akış, native store'un gerçek kodunu kullanan ek testte yeniden üretildi: yeni görev deadline'ı gelecekte, handler'ın seçtiği tarih geçmişte. Test beklenen şekilde RED oldu; üretim düzeltmesi henüz uygulanmadı.

Kullanıcının ses duymaması göz ardı edilmiyor; ancak bu kayıtlar karşısında 08.00 alarmının hiç kurulmadığı veya OS tarafından hiç tetiklenmediği sonucuna varılamaz.

## Silinen kopyanın yeniden çalması

Veritabanında kopya artık yok. Native store'da 05.54 kaynak saatli, bitmiş bir kopya session'ı var. Güncel plan haritasında kopyaya ait gelecek kayıt veya UUID bulunmuyor; kalan geçmiş session tek başına yeni alarm kurmaz.

Sabahın logları:

- 05:54:09.823'te erteleme için bir kayıt kuruluyor.
- 05:54:28'de büyük yenileme gerçekleşiyor: 30 kayıt iptal ediliyor, 24 kayıt kuruluyor. Erteleme kaydı bu iptallerde yer almıyor.
- Aynı erteleme kimliği 06:04:09.837'de tetikleniyor; 06:04:24'te durduruluyor.
- Native kopya session'ında bir erteleme kullanılmış ve son durdurma 06:04:25.

Bu, [önceki incelemede](2026-09-08-alarm-017-audit.md) yeniden üretilen “silinen alarmın aktif nöbetçisini rutin yenilemenin koruması” açığıyla örtüşüyor. SQLite silme anı ayrı bir journal'a yazılmadığından silme düğmesinin tam zamanı loglardan tek başına kanıtlanamıyor.

UI'da ek tutarsızlık: [alarms_section.dart](../../lib/presentation/widgets/reminders/alarms_section.dart) ertelenmiş görevli alarmın toggle ile kapatılmasını engelliyor, fakat swipe ve uzun basma menüsündeki silmeyi aynı kurala bağlamıyor. Mevcut silme yolu da native `cancelAlarm(id)` çağırmıyor.

## Düzeltme önceliğinin güncellenmesi

1. **Görev kaydı ve nöbetçi kurulumu foreground açılışına bağlı olmamalı.** Native stop işlemi, kilit açılamasa da kendi durum geçişini güvenilir biçimde tamamlayabilmeli. Görev ekranını açmak ayrı kullanıcı aksiyonu/foreground aşaması olmalı. Kilit ekranını veya cihaz kimlik doğrulamasını aşmaya çalışmak çözüm değildir.
2. **Süresi geçmiş snooze durumu temizlenmeli.** Begin ve yeniden kurma yalnız gelecekteki, geçerli deadline'ı kullanmalı. Flutter sayacı ile native deadline aynı kaynaktan gelmeli.
3. **Explicit delete bütün zinciri kapatmalı.** Rutin plan yenilemesinin canlı zincir koruması, silinmiş kök alarm için uygulanmamalı. Silme/snooze/undo sıralaması native id ile doğrulanmalı.
4. **Toplu iptal ve yeniden kurma azaltılmalı.** Değişmeyen alarmlar korunmalı; fallback'ler ana çalışlardan ve kullanıcı ertelemesinden ayrı izlenmeli.
5. **Release cihaz testi:** kilit açılmadan stop, kilit açılıp görev, ertelemeden sonra kilitli stop ve daha geç uygulama açılışı, aktif erteleme sırasında silme, yakın iki alarmın çakışması aynı senaryoda doğrulanmalı.

Arşivdeki generic `unknownAlarm` activity temizleme satırları tek başına başarısız alarm iptali diye sınıflandırılmadı; gelecekteki bir alarmın henüz activity'si olmayabilir. Sayısal AlarmKit kapasite limitinin aşıldığına ilişkin bir kanıt da bu sabahki seçili akışta bulunmadı.

## Release loglama açığı

[AppLogger](../../lib/core/utils/app_logger.dart) release için `Level.warning` seçiyor, fakat bir `filter` belirtmiyor. [Kilitli dependency sürümü](../../pubspec.lock) `logger 2.7.0`; bu sürümün varsayılan filtresi `DevelopmentFilter`. Bu filtre, assert'ler kapalıyken seviyesinden bağımsız olarak bütün logları eliyor.

Assert'leri kapalı normal Dart koşusunda, uygulamayla aynı logger kuruluşu ve kayıt sayan output kullanılarak şu sonuç alındı:

```text
assertsEnabled=false defaultErrorCount=0 productionErrorCount=1
```

Dolayısıyla AppLogger'ın açıklamasındaki “release'te warning ve error basılır” iddiası implementasyonla uyuşmuyor. Bu bulgu Dart logları içindir; native `NSLog` kayıtlarının arşivde bulunmamasını tek başına açıklamaz. Refactor kapsamında doğru release filtresi ve kalıcı, sınırlı alarm journal'ı gerekli.

## Önceki sabahların kapsamı

Kullanıcı önceki günlerin de incelenmesini istedi. İlk arşivin gerçek başlangıcı **7 Eylül 19.27**; daha önceki sabahlar bu aktarımda yok. Telefon yeniden bağlanıp tutulmuş son 7 günün arşivi alınmadan o günler hakkında doğrulanmış sonuç verilemez. Bu raporun mevcut bulguları 8 Eylül sabahına aittir.
