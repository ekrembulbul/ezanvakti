# 0001. Nöbetçi alarm zinciri ve sert tavanlar

- **Durum:** Kabul edildi
- **Tarih:** 2026-09-09
- **Etkilenen alan:** Görevli alarmların durdurulduktan sonraki davranışı

## Bağlam ve problem

Görevli alarmda amaç, kullanıcının alarmı susturup tekrar uyumasını engellemektir. Ancak platformların hiçbirinde alarm durdurulduğu anda görev ekranını zorla gösterme imkânı yoktur:

- Android'de `AlarmRingService` durdurulunca servis biter; uygulama ön planda olmayabilir.
- iOS'ta `AlarmKit`'in `stopIntent`'i arka planda çalışır ve uygulamayı açmaz.

Yani **native durdurma yalnızca durumu kaydeder** (`mission_launcher.dart:71-73`). Görev ekranı ancak kullanıcı uygulamayı açtığında gösterilebilir. Kullanıcı hiç açmazsa görev borcu ödenmemiş olarak kalır ve alarm işlevini yitirir.

Karşı risk de gerçektir: alarmı sürekli geri getiren bir mekanizma, bir hata durumunda sonsuz alarma dönüşüp kullanıcıyı telefonundan edebilir. Gerçek cihaz incelemelerinde zincirin yanlış davrandığı vakalar kaydedilmiştir (`docs/investigations/2026-09-08-device-alarm-audit.md`, commit `9886baf`, `71f0586`).

## Karar

Görevli alarm durdurulduğunda, görev tamamlanana kadar alarmı geri getiren bir **nöbetçi (watchdog) zinciri** kurulur. Zincirin kararları `MissionChain` saf domain sınıfında verilir ve **iki bağımsız sert tavanla** sınırlanır — hangisi önce dolarsa zincir durur:

| Tavan | Değer | Anlamı |
|---|---|---|
| `maxRearms` | 40 | Zincirin en fazla kaç kez yeniden kurulacağı |
| `chainDeadlineMinutes` | 60 | Alarmın ilk çaldığı andan itibaren zincirin yaşayacağı süre |

Ek olarak, `stopIntent` hiç çalışmazsa devreye giren bir **sağlama merdiveni** alarm kurulurken önden dizilir: 3 adet yedek, 5'er dakika arayla (`MissionTuning.ladderStepMinutes`, `ladderCount`).

Nöbetçi alarmlar ana alarmdan ayrı bir kimlik uzayında yaşar: `MissionChain.watchdogId()` → `<alarmId>#w<index>`. Defter (journal) iptali bu kimlik üzerinden yapıldığı için çakışma kabul edilemez.

**Mantık Dart tarafında durur.** Native taraf zincir değerlerini kalıcı depodan (Android `SharedPreferences`, iOS `UserDefaults`) okur ve yalnızca iki karşılaştırma yapar; karar mantığını taşımaz (`mission_chain.dart:5-7`).

## Sonuçlar

### Olumlu

- Zincir kararları saf fonksiyonlarla test edilebilir; `DateTime.now()` çağrılmaz, zaman dışarıdan verilir.
- İki tavanın OR ile birleşmesi, tek bir sayacın bozulmasına karşı ikinci bir emniyet sağlar.
- Aynı mantığın Kotlin ve Swift'te ikinci ve üçüncü kez yazılması gerekmez.

### Bedeller

- Kalibrasyon sabitleri Dart'ta, uygulama noktası native'de: değer değişince iki tarafın da doğru okuduğu doğrulanmalıdır.
- 60 dakikalık pencere dolduktan sonra görev borcu **düşer** — kullanıcı görevi yapmadan da gün kapanır. Bu bilinçli bir taviz: koruma bir noktadan sonra cezalandırmaya döner (`mission_tuning.dart:27-29`).
- Nöbetçi alarmlar OS'un alarm kotasını tüketir; ladder ile birlikte tek bir alarm olayı birden fazla kayıt yaratır.

## Değerlendirilen alternatifler

**Sınırsız zincir.** Görev yapılana kadar alarm dönmeye devam etsin. Reddedildi: tek bir hata kullanıcıyı telefonundan eder, geri alınamaz bir kullanıcı deneyimi hasarı üretir.

**Tek yeniden kurulum.** Alarm bir kez geri dönsün, sonra sussun. Reddedildi: görevli alarmın caydırıcılığını ortadan kaldırır — kullanıcı iki kez susturup uyumaya devam edebilir.

**Karar mantığını native'e taşımak.** Zincir kararı Kotlin ve Swift'te ayrı ayrı verilsin, Dart hiç karışmasın. Reddedildi: aynı kural üç yerde (Dart testleri, Kotlin, Swift) tutulmak zorunda kalır ve platformlar arası davranış farkı kaçınılmaz hale gelir.

## Doğrulanmamış noktalar

⚠️ `maxRearms = 40` ve `chainDeadlineMinutes = 60` değerlerinin ölçümle kalibre edildiğine dair kayıt yok. `mission_tuning.dart:4-6` bunları açıkça "tahmin" olarak işaretliyor: *"Başlangıç değerleri tahmindir; cihazda ölçülüp güncellenecek."* Cihaz ölçümü yapıldığında bu ADR güncellenmelidir.

## Referanslar

- `lib/features/alarms/domain/mission_chain.dart` — zincir kararları ve tarih hesapları
- `lib/core/config/mission_tuning.dart:24-30` — tavanlar ve merdiven sabitleri
- `lib/features/alarms/domain/mission_coordinator.dart` — zincirin oturum yaşam döngüsü
- `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmMissions.kt`, `ios/Runner/AlarmPlanEngine.swift` — native uygulama noktaları
- Commit `9886baf` — kilit ekranı ve alarm zinciri hatalarının giderilmesi
- Commit `71f0586` — alarm kimliğinin ve görev zincirinin her çalışta korunması
- `docs/investigations/2026-09-08-device-alarm-audit.md` — gerçek cihaz bulguları
