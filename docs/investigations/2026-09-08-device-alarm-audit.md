# Fiziksel cihazda alarm incelemesi — 1–8 Eylül 2026

8 Eylül'de cihazdan okunan uygulama: **0.17.0 (51)**. Cihaz: **iPhone 17, iOS 26.6.1 (23G83)**. Önceki sabahlarda çalışan uygulama sürümleri aşağıda ayrıca eşleştirildi; geçmiş günlerin iOS sürümünün aynı olduğu varsayılmadı. İnceleme salt okunur yürütüldü; telefona build yüklenmedi, test alarmı eklenmedi ve mevcut alarmlar değiştirilmedi.

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

## Önceki sabahlar — 7 günlük arşivin sonucu

İkinci arşiv alındı ve okundu. Gerçek kapsamı **1 Eylül 14.43–8 Eylül 14.43**. Günlük karşılaştırma, log mesajlarının kendi timestamp'leri üzerinden yapıldı. 1 Eylül sabahı kapsam dışında; 2–7 Eylül kayıtları incelendi.

Eski günlerin ayrıntılı `Firing event`, `MissionStopIntent.perform()` ve foreground açılış hata dizileri bu arşivde bulunamadı. Bununla birlikte, AlarmKit'in koruduğu **AlarmManager durum dökümleri** ve kurulu sürüm kayıtları var. Bir durum dökümü o andaki `scheduled` / `alerting` durumunu gösterir; geçmişte hangi düğmeye basıldığını veya hangi QR görevinin açıldığını tek başına göstermez.

| Sabah | Cihazda gözlenen uygulama sürümü | Korunmuş alarm kanıtı | Çıkarılabilecek sonuç |
| --- | --- | --- | --- |
| 2–4 Eylül | 0.5.5 (31) | Sürüm, izin ve widget kayıtları; ilgili tetikleme/görev ayrıntıları yok. | O sabahların alarm hatasına kesin neden atanamaz. Kayıt yokluğu, hata olmadığı anlamına gelmez. |
| 5 Eylül | 0.11.5 (43) | 05:04:05 dökümünde uygulamaya ait 14 plan; o sabah için 05:23, 05:28, 05:33, 05:38 kayıtları. | Beş dakikalık yedek düzeni o tarihte de kurulmuş. Bu döküm tek başına çalma/stop zamanını kanıtlamaz. |
| 6 Eylül | 0.11.7 (45) | 05:24:06'da 05:29'a kurulu kayıt, 05:29:06'da aynı id ile `alerting`. 05:48:03'te 05:49'a kurulu kayıt, 05:49:06'da aynı id ile `alerting`. | Beş dakika aralıklı plandaki iki kayıt gerçekten alarm durumuna geçmiş. Bunlar kendi plan saatlerinden beş dakika geç tetiklenmiş kayıtlar değil. Ana çalışların ses başlangıcı ayrı olarak doğrulanamıyor. |
| 7 Eylül | 0.14.0 (48) | 05:31:54'te uygulamaya ait **iki ayrı kayıt aynı anda `alerting`**; 05:48:06'da bir kayıt `alerting`. 05:31 dökümünde 08:00/08:05/08:10/08:15 planları var. | Üst üste binen alarm kayıtları ve yedek planları somut. Hangi iki kullanıcı etiketinin çaldığı durum dökümünde yok. |
| 8 Eylül | 0.17.0 (51) | Ayrıntılı tetikleme/stop, `Locked` reddi, native session ve geçmiş tarih hataları mevcut. | Bu raporun önceki bölümlerindeki kök nedenler doğrudan cihaz kaydıyla eşleşiyor. |

6 Eylül'deki eşleştirme yalnız saate bakılarak yapılmadı: iki durum dökümünde **aynı native id** takip edildi. 7 Eylül 05:31:54'teki iki `alerting` kayıt da uygulamanın kendi bundle identifier'ına ait; başka bir alarm uygulamasının kaydı sayılmadı.

7 Eylül 08:00:08 dökümünde 08:05/08:10/08:15 yedekleri hâlâ planlı; 08:05:11 dökümünde 08:10/08:15 kalmış. Bu, yedeklerin o sabah da işletim sistemi tarafında bulunduğunu gösterir. Bu iki dökümden 08:00 ana alarmının sesinin duyulduğu veya tam hangi saniyede durdurulduğu çıkarılmadı.

### Sürüm geçişleri neden önemli?

App Store/TestFlight'ın kurulu uygulama sorgularında:

- 0.11.5 (43), 5 Eylül 03:48'de görülüyor.
- 0.11.7 (45), 5 Eylül 16:14'ten 6 Eylül 17:57'ye kadar görülüyor.
- 0.14.0 (48), 6 Eylül 20:24'ten 7 Eylül 18:09'a kadar görülüyor.
- 0.16.0 (50), ilk kez 7 Eylül **18:09:10**'da görülüyor.
- 0.17.0 (51), ilk kez 8 Eylül **00:48:19**'da görülüyor.

Bunlar kurulu sürüm gözlemleridir; loglarda görünmeyen bütün kurulum adımlarının eksiksiz tarihi olduğu iddia edilmiyor. Ancak 7 Eylül sabahını, o akşam cihaza gelen 0.16 düzeltmeleriyle değerlendirmek doğru olmaz.

### Eski sürümlerdeki ek kod hataları

`ios-v0.11.5`, `ios-v0.11.7` ve `ios-v0.14.0` tag'lerindeki `ios/Runner/AppDelegate.swift` dosyalarının Git blob'u aynı: `66e976eec40d0f12cb4ff2568b1a6a241bc6a334`. Bu üç sabah aynı native alarm implementasyonu kullanılmış.

Bu eski implementasyonda:

1. **Tek ortak mission session vardı.** Her alarm kurulumu aynı `ezanvakti_mission_session` kaydındaki `alarmId`, `label` ve görev ayarlarını yeniliyor. Stop intent kendi schedule id'sini taşımıyor; o sırada ortak kayıtta hangi alarm varsa onu işliyor. Bu, önceki etiket/görev karışmalarını mümkün kılan somut kod hatası. 7 Eylül'de aynı anda iki native alarmın `alerting` olması, alarm başına durum ayırmanın önemini ayrıca gösteriyor; arşivde bulunmayan eski Flutter etiketini tahmin etmiyoruz.
2. **İleri günlerin görevleri kapatılıyordu.** Çıpalı serinin yalnız ilk çalışı `alarm.mission` alıyor; diğer çalışlar `AlarmMission.none` ve erteleme kapalı kuruluyor. Uygulama yeniden planlama yapmadan ileri gün kaydı çalışırsa QR istemeden kapanabiliyor. Bu, kodda doğrulandı; her eski sabah için hangi serinin çalıştığı logdan kesin ayrıştırılamıyor.
3. **Foreground açılışı yine zorunluydu.** `openAppWhenRun=true` eski native kodda da var. Dolayısıyla 8 Eylül'de kanıtlanan kilit bağımlılığı 0.17 ile eklenmiş değil. Önceki günlerin `Locked` hata dizileri korunmadığından o günlerde aynı reddin gerçekleştiği kesin diye yazılmadı.

İlk iki yapı 0.16'da alarm/çalış başına kayıt ve her güne görev taşıma ile değişti. Foreground bağımlılığı kaldı. Ayrıca 8 Eylül'de yakalanan `snoozedUntilMillis ?? deadlineMillis` geçmiş tarih hatası yeni store/handler akışına aittir; eski sürümlere aynı hata yolu geriye dönük uygulanmamalı.

Kaynak karşılaştırmasını yeniden yapmak için:

```sh
git rev-parse ios-v0.11.5:ios/Runner/AppDelegate.swift ios-v0.11.7:ios/Runner/AppDelegate.swift ios-v0.14.0:ios/Runner/AppDelegate.swift
git show ios-v0.14.0:ios/Runner/AppDelegate.swift
git show ios-v0.14.0:lib/features/alarms/domain/alarm_scheduler.dart
```

### Kapsam doğrulaması

- Önceki günler için namespace, AppIntents ve AlarmKit araması tamamlandı; ayrıca arşivde uygulamaya ait olduğu belirlenen 11 kurulum yolu üzerinden daha geniş tarama yapıldı.
- Geniş taramanın kronolojik çıktısı 8 Eylül'e ulaştıktan sonra, zaten ayrı incelenmiş günü yeniden taramamak için okuyucu durduruldu. 1–7 Eylül bölümü tamam; JSON timestamp sıralamasında geriye gidiş olmadığı doğrulandı. Sonuçlar ayrıca `< 2026-09-08` ile sınırlandı.
- 5–7 Eylül için toplam 16 AlarmManager dökümü ayrıştırıldı. 6 Eylül'de iki `scheduled → alerting` id eşleşmesi, 7 Eylül'de eşzamanlı iki `alerting` kayıt ve 08:00 ailesinin yedekleri kontrol edildi.
- Ham id'ler, kurulum yolları ve kişisel içerikler commit'e alınmadı. Ayrıştırılmış yerel kanıtlar `previous-snapshots.json`, `previous-coverage.json` ve ilgili NDJSON dosyalarında tutuldu.
