# 0002. StopGate — alarm durdurulduktan sonra hangi ekranın açılacağı

- **Durum:** Kabul edildi
- **Tarih:** 2026-09-09
- **Etkilenen alan:** Alarm durdurma akışı, ara ekran, görev ekranı

## Bağlam ve problem

Alarm durdurulduğunda kullanıcıya ne gösterileceği tek bir cevabı olan bir soru değil. Durum çok boyutlu:

- Alarmın görevi var mı? (`AlarmMission.requiresGate`)
- Erteleme açık mı, kaç hakkı kaldı?
- Oturum halen ertelenmiş durumda mı?
- Alarm bu arada silinmiş mi?
- Oturum bayat mı — dün gece durdurulan bir alarmın görev ekranı bu sabah açılmalı mı?

Bu kararın ekran kodunun içine dağılması, üzerinde test yazılamayan ve her düzeltmede yeni bir kenar durumu kaçıran bir yapı üretiyordu. Somut vaka: dünkü oturumun bugünkü açılışta görev ekranı açması (`stop_gate.dart:54-56`'de "31 Ağustos olayı" olarak anılıyor).

Ayrıca bir ürün kararı gerekiyordu: **kullanıcıya her durumda ara ekran gösterilmeli mi?** Uykulu bir kullanıcı için tek düğmelik bir ekran, bilgi değil fazladan bir dokunuştur.

## Karar

Karar mantığı `StopGate.decide()` saf fonksiyonunda toplanır. Zamanı dışarıdan alır, dört sonuçtan birini döndürür; `mission_launcher.dart` yalnızca sonucu uygular, karar vermez.

| Karar | Koşul | Sonuç |
|---|---|---|
| `none` | Oturum halen ertelenmiş (`snoozedUntil` gelecekte) | Hiçbir ekran açılmaz |
| `closeAndRearm` | Alarm silinmiş, seçim yok ya da oturum bayat | Oturum kapanır, alarmlar yeniden kurulur, ekran açılmaz |
| `showStopScreen` | Görevlide gerçek bir seçim var; görevsizde taze her durdurma | Ara ekran: görevlide "Görevi yap / Ertele", görevsizde karşılama — "Tamam", hak varsa "Ertele" |
| `openMission` | Görevli alarm, erteleme hakkı bitmiş | Doğrudan görev ekranı |

Yönetici kural, görevli yolda: **ekran yalnızca gerçek bir seçim varsa açılır** (spec 2026-08-30 D6).

**Görevsiz yolda D6, 9 Eylül'de bilinçli olarak esnetildi.** iOS'ta stop intent artık uygulamayı öne getirdiği için (bkz. [0003](0003-platform-alarm-models.md)) görevsiz alarmda kullanıcı bir seçimi olmasa da uygulamaya düşüyordu ve karşısında boş ana ekran buluyordu. Karşılama ekranı bu boşluğu doldurur: alarmın adı ve saati, **sıradaki vakit ve kalan süre** (ana ekranla aynı hesap, ADR 0004), tek "Tamam"; erteleme hakkı varsa yanında "Ertele". Dokunulmazsa `stopScreenSeconds` sonunda kendini kapatır — D6'nın koruduğu "uykulu kullanıcıya fazladan dokunuş yükleme" ilkesi böyle korunur. Bayatlık kuralı (D7) değişmedi. Bu, "Görevi yap" düğmesinin varlık sebebidir — düğme tek başına değil, "Ertele" ile birlikte bir çift oluşturur. Erteleme hakkı bittiğinde ara ekran hiç açılmaz, akış doğrudan göreve gider.

Bayatlık eşikleri iki yolda farklıdır:

- **Görevsiz:** `stopScreenSeconds` (45 sn). Durdurma zaten kesindir; saatler sonra eski bir "Ertele" ekranıyla karşılaşılmamalıdır (D3/D7).
- **Görevli:** zincirin sert tavanı ile aynı pencere (`chainDeadlineAt`, bkz. [0001](0001-alarm-watchdog-chain.md)). Tavan dolduğunda görev borcu da düşer; iki mekanizma aynı anda sona erer.

### Kapatma girişimleri: kilit ve satırdan giriş (22 Eylül 2026)

`decide()` "ortada çalan alarm var mı" sorusunu cevaplar. Ödenmemiş görev borcu ise alarm ertelenmişken de durur, ve o sırada alarmı listeden pasife almak ya da sıradaki çalışını atlamak borçtan kaçmanın arka kapısıydı.

`StopGate.blocksDismissal()` bu ikinci soruyu sorar: *bu alarmın ödenmemiş görev borcu var mı?* Cevap evetse anahtar ve tek seferlik atlama anahtarı **devre dışıdır**; ertelenmiş alarmda anahtarın yerini geri sayım rozeti alır (spec 2026-09-22 D2/D6). Çıkış iki yoldan biridir:

- **Ertelenmişken** satıra ya da rozete dokunmak ara ekranı "ertelenmiş" kipinde açar (`openSnoozedAlarm`): kullanıcı görevi yapar (erteleme biter, görev ekranı; oradaki kademeli acil çıkış da borcu kapatır), yeniden erteler ya da görevsizde alarmı kapatır. X hiçbir şeyi değiştirmeden çıkar.
- **Ertelenmemişken** (nöbetçi ya da görev süresi penceresi) ara/görev ekranı zaten `openMissionIfPending` ile kendiliğinden açılır; kilit kısa sürer.

9 Eylül–22 Eylül arasındaki çözüm, kapatma girişimini doğrudan görev ekranına yönlendiriyordu (`resolveMissionBeforeDismiss`): koruma ile çıkış aynı yerdeydi ama seçim sunmuyordu — kullanıcı "kapat" deyip kendini QR okuturken buluyordu. Kullanıcı kararıyla kaldırıldı; seçim ara ekranda, giriş satırda.

Ondan önceki çözüm (kilitli anahtar + "görevi yapmadan kapatılamaz" uyarısı) kullanıcıyı çıkışsız bırakıyordu; bugünkü kilit satırdan girişle birlikte geldiği için o soruna dönmez.

Silme kapıya tabi değildir — kalıcı ve niyetli bir eylemdir, ve silinmiş bir alarmın görevini yaptırmak anlamsız olurdu.

**Yeniden erteleme (22 Eylül).** Erteleme sürerken ikinci "Ertele" iki platformda da sessizce yok sayılıyordu; artık uygulanır: yeni çalma anı şimdi + süre, hak bir eksilir (spec D12). Bunun bedeli, native'in yeniden denemeyi ayırt edememesi: zamanlayıcı kurulup eski kaydın temizliği patlarsa kullanıcı "Tekrar dene"ye basar ve native bunu ikinci erteleme sayardı. İdempotentlik bu yüzden Dart koordinatörüne taşındı — çağıran ekranda gördüğü sayacı verir; native sayaç bir ileri ve erteleme etkinse istek zaten uygulanmıştır, native'e gidilmez. Yarım kalan eski zamanlayıcı bir sonraki uzlaştırmada temizlenir.

Erteleme hakkı ayrı bir kural taşır: görev açıkken sınırsız erteleme kapıyı işlevsiz bırakacağı için limit en büyük sonlu seçeneğe indirilir (`snooze_options.dart:19-21`).

## Sonuçlar

### Olumlu

- Dört sonuçlu bir enum, ekran kodundan bağımsız olarak tablo halinde test edilebilir.
- Bayatlık kuralı tek yerde; yeni bir ekran eklendiğinde kural tekrar yazılmaz.
- Görevli ve görevsiz yolların farklı eşikleri açıkça görünür durumda.

### Bedeller

- `decide()` çağrılırken alarmın kendisi, oturum ve şimdiki zaman birlikte hazır edilmelidir; çağıran tarafta hazırlık yükü vardır.
- Ara ekranın açılmadığı durumlar (`none`, `closeAndRearm`) kullanıcı için sessizdir. Kullanıcı "neden hiçbir şey olmadı" diye sorabilir; bu, D6 kuralının kabul edilmiş bedelidir.

## Değerlendirilen alternatifler

**Her durdurmada ara ekran göstermek.** Tutarlı ve tahmin edilebilir. Reddedildi: tek seçenekli ekran uykulu kullanıcıya değer üretmeden bir dokunuş maliyeti bindirir (D6).

**Kararı ekran widget'ının `initState`'inde vermek.** Daha az dolaylılık. Reddedildi: karar zaman bağımlı ve çok boyutlu; widget içinde test edilmesi pratikte mümkün olmuyordu.

**Kapatma girişimini doğrudan görev ekranına yönlendirmek (9–22 Eylül).** Terk edildi: seçim sunmadan göreve düşürüyordu; ayrıca erteleme sürerken yeniden ertelemek için giriş yoktu.

**Bayatlık için tek bir global eşik.** Basit. Reddedildi: görevsiz yolda 45 saniye doğru, görevli yolda ise zincir tavanıyla hizalanmak zorunlu — tek eşik iki mekanizmayı ayrıştırır ve tutarsız durumlar üretir.

## Referanslar

- `lib/features/alarms/domain/stop_gate.dart` — `decide()` karar fonksiyonu, enum ve `blocksDismissal()` borç sorgusu
- `lib/presentation/screens/mission_launcher.dart` — `openSnoozedAlarm()` ve `_StopHost` ertelenmiş kipi
- `lib/presentation/widgets/reminders/snooze_countdown.dart` — rozet
- `lib/features/alarms/domain/mission_coordinator.dart` — `snooze(expectedSnoozeUsed:)` yeniden deneme koruması
- `docs/superpowers/specs/2026-09-22-ertelenmis-alarm-geri-sayim-design.md` — D2/D5/D6/D12 kararları
- `lib/features/alarms/domain/snooze_options.dart:14-21` — erteleme limiti normalleştirme
- `lib/presentation/screens/mission_launcher.dart:205-283` — kararın uygulanması (`_openNextMission`)
- `lib/presentation/screens/alarm_stop_screen.dart:298-323` — birincil düğme metni (`stopDoMission` / `stopCloseAlarm` / `actionOk`)
- `docs/superpowers/plans/2026-08-30-alarm-ara-ekran.md` — D3/D6/D7/D8 kararlarının kaynağı
