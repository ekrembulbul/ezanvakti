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
| `showStopScreen` | Gerçek bir seçim var | Ara ekran: görevlide "Görevi yap / Ertele", görevsizde "Tamam / Ertele" |
| `openMission` | Görevli alarm, erteleme hakkı bitmiş | Doğrudan görev ekranı |

Yönetici kural: **ekran yalnızca gerçek bir seçim varsa açılır** (spec 2026-08-30 D6). Bu, "Görevi yap" düğmesinin varlık sebebidir — düğme tek başına değil, "Ertele" ile birlikte bir çift oluşturur. Erteleme hakkı bittiğinde ara ekran hiç açılmaz, akış doğrudan göreve gider.

Bayatlık eşikleri iki yolda farklıdır:

- **Görevsiz:** `stopScreenSeconds` (45 sn). Durdurma zaten kesindir; saatler sonra eski bir "Ertele" ekranıyla karşılaşılmamalıdır (D3/D7).
- **Görevli:** zincirin sert tavanı ile aynı pencere (`chainDeadlineAt`, bkz. [0001](0001-alarm-watchdog-chain.md)). Tavan dolduğunda görev borcu da düşer; iki mekanizma aynı anda sona erer.

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

**Bayatlık için tek bir global eşik.** Basit. Reddedildi: görevsiz yolda 45 saniye doğru, görevli yolda ise zincir tavanıyla hizalanmak zorunlu — tek eşik iki mekanizmayı ayrıştırır ve tutarsız durumlar üretir.

## Referanslar

- `lib/features/alarms/domain/stop_gate.dart` — karar fonksiyonu ve enum
- `lib/features/alarms/domain/snooze_options.dart:14-21` — erteleme limiti normalleştirme
- `lib/presentation/screens/mission_launcher.dart:145-197` — kararın uygulanması
- `lib/presentation/screens/alarm_stop_screen.dart:196-217` — birincil düğme metni (`stopDoMission` / `actionOk`)
- `docs/superpowers/plans/2026-08-30-alarm-ara-ekran.md` — D3/D6/D7/D8 kararlarının kaynağı
