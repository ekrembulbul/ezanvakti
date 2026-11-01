# 0007. Tek seferlik ("Bir kez") alarm

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-01
- **Etkilenen alan:** Alarm modeli ve şeması, alarm planlayıcı, düzenleme ekranı, alarm listesi

## Bağlam ve problem

Kullanıcı bir kez çalıp kendiliğinden kapanan bir alarm istedi (Android ilk geri bildirim turu). Mevcut model buna yer bırakmıyordu:

- Tekrar, alarmın gün kümesiyle tutuluyor ve **boş küme "her gün" demek** (`lib/core/models/alarm.dart:27-29`, `firesOnWeekday`). Kayıtlı bütün "her gün" alarmları boş kümeyle duruyor; boş kümeye yeni bir anlam yüklemek onları sessizce tek seferliğe çevirirdi.
- Sabit alarmın her kaydına haftalık şablon (`templateWeekdays`) gidiyor ve şablon boşsa 1..7'ye tamamlanıyordu. Şablonu gören Android uzlaştırması tarihli kaydı haftalık tekrara çevirir (`AlarmReconciler.kt:49-53`); iOS durdurma akışı da durdurulan alarmı şablondan haftalık kayda geri kurar (`AlarmPlanEngine.swift:322-341`). Tek seferlik alarm böylece haftalık alarma dönüşürdü.
- Native taraf tekrar günü olmayan tarihli kaydı zaten destekliyor: çaldıktan sonra yeniden kurmuyor (`AlarmRepeats.kt:8`, `AlarmReceiver.kt:29`, `AlarmBootReceiver.kt:80-83`; iOS'ta `.fixed(date)`, `AlarmKitPlatform.swift:43-44`). Ama native, Dart veritabanına bir şey yazmıyor; görevsiz ve ertelemesiz durdurulan alarm Dart'a sinyal de bırakmıyor. "Alarm çaldı, artık kapalı" bilgisini native'den alamayız.

## Karar

**Ayrı bayrak ve hedef gün.** Modele iki alan eklenir: `isOnce` (varsayılan `false`) ve `onceDate` (yalnız tarih; alarmın çalacağı **kaynak vakit günü**, çıpalıda vaktin okunduğu gün — ofset gece yarısını geçirse de). Tek seferlikte gün kümesi yok sayılır ama saklanır; kullanıcı tekrara dönünce seçimi geri gelir. Şema v17: `alarms` tablosuna `once INTEGER NOT NULL DEFAULT 0` ve `once_date TEXT` (`yyyy-MM-dd`). Mevcut kayıtlar `0` ile tekrarlı kalır.

**Hedef gün tek hesaptan.** `onceDate` kaydederken ve kapalı alarm yeniden açılırken `AlarmScheduler.nextOnceOccurrence` ile bulunur: gün kümesi yok sayılıp yedi günün tamamı kabul edilerek sıradaki ilk geçerli çalışın kaynak günü. Atlanan örnek kuralı aynen geçerli. Düzenleme ekranındaki "Yalnız {gün} {saat} için kurulur, çaldıktan sonra kendiliğinden kapanır." cümlesi de aynı fonksiyonu çağırır; ekranda görünen an planlanan andır ([0004](0004-single-source-prayer-time.md)). Hesaplanamazsa (çıpalı alarmda vakit verisi yok) mevcut tarih **korunur**, silinmez.

**Kaydetmede hedef günün korunması.** Kayıtlı tek seferlik alarmın saati, türü, vakti ve ofseti değişmediyse ve o çalış hâlâ sürüyorsa (bekleyen oturum var ya da çalış geçmiş ama zincir süresi dolmamış) hedef gün korunur; çalan ya da yeni çalmış alarmın etiketini düzeltmek onu ertesi güne yeniden kurmaz. Diğer her durumda yeniden hesaplanır (`onceDateForSave`). Düzenleme ekranında kaydedilen tek seferlik alarm her zaman **açık** kaydedilir: kendiliğinden kapanmış alarmı düzenleyip kaydetmek yeniden kurma niyetidir.

**Planlama.** Tek seferlik alarmda yalnız `onceDate` günü için tek tarihli kayıt üretilir (`limit` 1), kimlik tarihli kaydın kimliğidir (`<id>#at<ms>`). `templateWeekdays` **gönderilmez**; sabit alarmda `repeatHour`/`repeatMinute` gitmeye devam eder ki Android saat dilimi değişince kaydı aynı duvar saatine taşısın (`AlarmTimeShift.kt`). Eksik vakit taraması yalnız hedef günü kapsar. Hedef gün yoksa ya da o günün vakti hesaplanamıyorsa mevcut eksik vakit davranışı izlenir: çıpalı alarm korunur, kapatılmaz.

**Kendini onarma.** Açık, tek seferlik ve hedef günü boş bir alarm (hiç hesaplanamamış ya da bozuk tarih okunmuş; sabit alarm da dahil) için planlama, vakit verisi varsa hedef günü hesaplayıp kaydeder ve alarmı o güne kurar. Kaydedilemezse alarm o planlamada kurulmaz: her planlamada yeniden hesaplanan bir gün alarmı her gün çaldırırdı.

**Kendini kapatma, zincir süresi grace'iyle.** Her planlamada (`scheduleAlarms`; açılış, ön plana dönüş, görev sonu, ayar değişikliği hep buradan geçer) açık bir tek seferlik alarmın hedef gündeki çalış anı + zincir süresi (`MissionTuning.chainDeadlineMinutes`, 60 dk) geçmişse **ve** o alarmın bekleyen oturumu (erteleme ya da görev) yoksa alarm `isActive = false` kaydedilir; plana girmediği için native kaydı da kurulmaz. Hedef gün bugünden en az iki gün önceyse vakit verisine bakılmadan "geçmiş" sayılır: en büyük ofset 240 dk ve zincir 60 dk o noktada kesin dolmuştur. Bu olmadan, uygulama günler sonra açıldığında hedef günü vakit penceresinin dışında kalan çıpalı alarm hiç kapanmazdı. Daha yakın günde vakti hesaplanamayan çıpalı alarm kapatılmaz. Zincir süresi dolmadan kapatma yoktur: kök plandan çıkınca iOS çalan alerti keser, görev zinciri düşer. Oturumlar okunamazsa güvenli taraf seçilir, alarm açık kalır. Kapatılan ve onarılan kimlikler `onceAlarmsChanged` akışıyla yayılır; ana sayfa listeyi depodan yeniden okuyup `AppState`'e yazar.

**Native'e dokunulmaz.** Şablonsuz tarihli kayıt iki platformda da bugünkü yoldan geçer: Android uzlaştırması şablon yoksa kayıtları olduğu gibi kurar; iOS `setTemplates` şablonsuz ilk kayıtta alarmın kayıtlı şablonunu siler (`AlarmMissionStore.swift:196-207`), bu yüzden durdurma sonrası haftalığa geri kurma (`restoreWeeklyTemplateIfReady`) çalışmaz.

**Arayüz.** Tekrar bölümünde hızlı seçimlerin başında "Bir kez" çipi; seçiliyken gün kutuları söner, altında cümle çıkar. Başka bir çipe ya da gün kutusuna dokunmak tek seferlik modundan çıkarır. Kartta, alt başlıkta ve durdurma ekranının tekrar özetinde "Bir kez" yazar (`weekdaysLabel` bildirimlerle paylaşıldığı için dal çağıranda: `alarmRepeatLabel`). Anahtar kapatılırken "Yalnızca bu sefer" atlaması sunulmaz; alarm doğrudan kapanır. Yeni alarmın varsayılanı "her gün" kalır.

## Sonuçlar

### Olumlu

- Mevcut alarmların anlamı ve native sözleşme değişmez; Kotlin ve Swift'e yeni kod girmez.
- Ekrandaki cümle, kart ve planlayıcı aynı hedef gün hesabını kullanır.
- Kapatma kararı Dart'ta, saf girdilerle (alarm, vakitler, oturumlar, saat) verilir ve test edilir.

### Bedeller

- Alarm çaldıktan sonra **zincir süresi boyunca (60 dk) açık görünür**; bekleyen oturum varsa oturum kapanana kadar uzar.
- Kapatma uygulama içinde planlama yapılınca olur. **Uygulama hiç açılmazsa veritabanında alarm "açık" kalır**, ama native kayıt geçmişte kaldığı için bir daha çalmaz. Kullanıcı açtığında ilk planlama kapatır.
- Çıpalı tek seferlik alarm vakit verisi olmadan kaydedilirse hedef gün boş kalır; vakit verisi gelince ilk planlama günü hesaplayıp kurar.
- Vakit verisi yokken yeniden açılan çıpalı tek seferlik alarm eski hedef gününü korur; o gün iki günden eskiyse sıradaki planlama alarmı yeniden kapatır.
- Zincir penceresinde çıpalı tek seferlik alarmın satırı, sıradaki çalış olmadığı için "vakit yok" durumunu gösterebilir.
- Testler native alarmın cihazda zamanında çaldığını kanıtlamaz.

### Bilinen sınırlar

- **Saat dilimi değişimi.** Kapatma kararı, hedef gün ve alarm saatinden **o anki yerel saate göre** yeniden hesaplanan çalış anına dayanır. Alarm A diliminde çaldıktan sonra cihaz saati geride olan bir dilime geçerse aynı gün için hesaplanan an yeniden gelecekte kalır; planlayıcı onu tekrar kurar ve alarm aynı gün ikinci kez çalabilir.
- **Sınırsız çalma süresi.** Çalma süresi "sınırsız" seçiliyken alarm 60 dakikadan uzun süre durdurulmadan çalarsa, iOS'ta oturum ancak durdurmayla oluştuğu için bekleyen oturum görünmez; zincir süresi dolunca yapılan planlama alarmı kapatır ve kök plandan çıkınca iOS çalan alerti keser.
- **Cümle dakika sınırında yenilenmez.** Düzenleme ekranındaki cümle yalnız ekrandaki seçim değişince yeniden hesaplanır; ekran açıkken alarm saati geçerse "bugün" yazmaya devam eder. Kaydetme anı yeniden hesaplandığı için kurulan gün doğrudur.

## Değerlendirilen alternatifler

**Boş gün kümesini "bir kez" saymak.** Şema değişmezdi. Reddedildi: boş küme bugün "her gün" demek; kayıtlı her-gün alarmlarının hepsi tek seferliğe dönerdi.

**Native çaldıktan sonra kaydı kapatsın.** Kapanış anında olurdu. Reddedildi: native Dart veritabanına yazmıyor, görevsiz ve ertelemesiz durdurma Dart'a sinyal bırakmıyor; iki platformda yeni kod ve yeni bir veri yolu gerekirdi.

**Çalış anı geçer geçmez kapatmak.** Görünüm hemen doğru olurdu. Reddedildi: kök plandan çıkınca iOS çalan alerti keser, görev ve erteleme zinciri ([0001](0001-alarm-watchdog-chain.md)) düşer.

## Referanslar

- `lib/core/models/alarm.dart:36-41`, `:105` — alanlar ve `firesOnDay`
- `lib/features/prayer_times/data/sqlite_storage.dart:39`, `:189-190`, `:355-362` — şema v17
- `lib/features/alarms/domain/alarm_scheduler.dart:80`, `:102` — `withOnceDate`, `onceDateForSave`
- `lib/features/alarms/domain/alarm_scheduler.dart:238`, `:320-460` — kendini onarma ve kapatma, iki gün kuralı
- `lib/features/alarms/domain/alarm_scheduler.dart:258`, `:508-518` — tek kayıt, şablonsuz zincir ayarı
- `lib/features/alarms/domain/alarm_scheduler.dart:627` — `nextOnceOccurrence`
- `lib/presentation/screens/alarm_edit_screen.dart:165`, `:661` — her zaman açık kaydetme, düzenleme ekranındaki cümle
- `lib/presentation/screens/reminders_screen.dart:754` — atlama teklifinin kalkması
- `lib/presentation/pages/home_page.dart:131` — kapanma ve onarma sonrası liste yenilemesi
- `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmReconciler.kt:49-53`, `:89-90` — şablon dönüşümü, çalmış tarihli kaydın zincir süresince korunması
- `ios/Runner/AlarmMissionStore.swift:196-207`, `ios/Runner/AlarmPlanEngine.swift:194-198`, `:322-341` — şablon silme, korunma, haftalığa geri kurma
- `test/alarms/alarm_once_test.dart` — planlama, kapanma, onarma ve hedef gün davranışı
