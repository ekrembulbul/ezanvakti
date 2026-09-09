# 0003. iOS ve Android için ayrı alarm modelleri

- **Durum:** Kabul edildi
- **Tarih:** 2026-09-09
- **Etkilenen alan:** Alarm çalma, ses, tam ekran sunum, platform davranış farkları

## Bağlam ve problem

"Alarm çal" tek bir cümle ama iki platformda taban tabana zıt iki mekanizmaya karşılık geliyor:

- **Android**, uygulamanın kendi ön plan servisini çalıştırmasına izin verir. Ses, titreşim ve tam ekran sunum uygulamanın kontrolündedir.
- **iOS**, uygulamanın arka planda süresiz ses çalmasına izin vermez. iOS 26 ile gelen `AlarmKit`, alarmı **sistemin** çalmasını sağlar; uygulama yalnızca alarmı tarif eder.

Ortak bir soyutlamayı zorlamak, her iki tarafta da yanlış davranış üretiyordu. Aynı zamanda bu fark, ürün seviyesinde de sonuç doğuruyor: sessiz pencere özelliği yalnızca Android'de yayınlanabildi (commit `2cfc4b8`).

## Karar

İki platform **ayrı alarm modelleriyle** uygulanır; ortak katman yalnızca Dart tarafındaki `AlarmService` arayüzü ve `MissionChain` / `StopGate` gibi saf karar sınıflarıdır.

### Android — uygulama sahipliğinde

`AlarmRingService` bir ön plan servisidir. Sesi `MediaPlayer` ile alarm akışında döngüde çalar, `RingtoneManager` sistem varsayılanına düşer, titreşimi kendisi yönetir ve tam ekran `AlarmRingActivity`'yi açan bir bildirim gösterir.

### iOS — sistem sahipliğinde

`AlarmKitPlatform`, `AlarmManager.shared.schedule()` ile alarmı sisteme kaydeder. Ses `AlarmManager`'a bir `sound` parametresi olarak verilir; uygulama ses akışına dokunmaz. Sunum `AlarmPresentation` ile tarif edilir.

iOS alert'inde bir **ikincil düğme** bulunur (`AlarmKitPlatform.swift:31-38`). Sebebi teknik bir zorunluluktu: `stopIntent` arka planda çalışır ve uygulamayı açmaz, dolayısıyla görev ekranı gösterilemezdi. İkincil düğme `MissionOpenIntent` ile uygulamayı öne getirir. Düğme yalnızca gerekliyse eklenir (`record.gated || record.snoozeEnabled`) ve başlığı duruma göre değişir: görevlide "Open task", görevsizde "Open alarm".

**Neden stop doğrudan uygulamayı açmıyor?** Denendi ve 8 Eylül'de gerçek cihazda kaybedildi: `openAppWhenRun = true` (iOS 26 adıyla `.foreground(.immediate)`) sistemin `perform()`'u çalıştırmadan *önce* kilit açılmasını istemesine yol açıyor; kilitli telefonda `Locked / RequestDenied` ile çıkıyor ve stop kaydı, görev oturumu, nöbetçi zincir hiç oluşmuyordu (`docs/investigations/2026-09-08-device-alarm-audit.md`).

**9 Eylül, aşama 1:** stop intent `supportedModes = [.background, .foreground(.dynamic)]` ile önce arka planda kaydeder, sonra `continueInForeground()` ile öne gelmeyi *dener*. Reddedilirse (kilitli cihaz) kayıt korunur ve red journal'a `stop_foreground / declined` olarak yazılır. İkincil düğme, cihaz doğrulaması tamamlanana kadar geri düşüş yolu olarak yerinde kalır; doğrulanınca kaldırılması planlanıyor (aşama 2).

> Bu düğme, Flutter tarafındaki ara ekranın "Görevi yap" düğmesinden **farklı bir şeydir**. İkisi ayrı katmanlarda, ayrı sebeplerle vardır: iOS'taki düğme uygulamayı açmak için, Flutter'daki düğme erteleme ile görev arasında seçim sunmak içindir (bkz. [0002](0002-stop-gate.md)).

### Kabul edilen davranış farkları

| Konu | Android | iOS |
|---|---|---|
| Ses çalan taraf | Uygulama (`MediaPlayer`) | Sistem (`AlarmKit`) |
| Ses akışı kontrolü | Uygulamada | Yok |
| Sesin kademeli yükselmesi | Var (alarm başına ayar) | Yok |
| Sessiz pencere | Var | Yok (commit `2cfc4b8`) |
| Asgari sürüm kısıtı | — | `iOS 26.1` (`guard #available`) |
| Tam ekran sunum | `AlarmRingActivity` | Sistem alert'i |

## Sonuçlar

### Olumlu

- Her platform kendi işletim sistemine uygun, desteklenen yolu kullanır; kırılgan geçici çözümler yoktur.
- iOS'ta sistem alarmı olmak, uygulamanın öldürülmesi durumunda bile alarmın çalmasını sağlar.
- Karar mantığı (zincir, kapı) paylaşıldığı için davranış farkı sunum katmanıyla sınırlı kalır.

### Bedeller

- Her alarm özelliği iki kez tasarlanmak zorundadır ve bazıları tek platformda kalır.
- iOS'ta ses akışına erişim olmadığı için **ses seviyesi ve ses geçişleri üzerinde kontrol yoktur.** Apple'ın DTS mühendisi bunu forumda doğruluyor: *"AlarmKit does not directly support volume customization beyond utilizing the system ringer volume... there is no API in AlarmKit that allows for volume modification neither."* Önerdikleri geçici çözüm (local notification + `AVAudioPlayer`) bu ADR'de zaten elenen yaklaşımdır — alarmın çalma garantisini yok eder.
- Bunun somut sonucu: sesin kademeli yükselmesi (fade-in) yalnızca Android'de sunulur. Ayar iOS'ta kullanıcıya hiç gösterilmez; `Alarm.fadeIn` alanı payload'da taşınır ama iOS tarafı okumaz.
- `iOS 26.1` altındaki cihazlarda alarm motoru `EngineError.unavailable` fırlatır.

## Değerlendirilen alternatifler

**iOS'ta da uygulama içi audio player.** Android ile birebir aynı davranış. Reddedildi: iOS arka planda süresiz ses çalmaya izin vermez; alarm uygulama kapalıyken çalmaz — alarmın var oluş sebebini ortadan kaldırır.

**Her iki platformda yalnızca bildirim sesi.** En basit ortak payda. Reddedildi: bildirim sesi kısa ve susturulabilir; uyandırma garantisi vermez.

**Ortak bir "alarm çalar" soyutlaması.** Tek arayüz, iki uygulama. Reddedildi: iki modelin yaşam döngüsü ortak bir arayüzde buluşmuyor — iOS'ta çalma anı uygulamaya hiç uğramıyor. Ortaklık, çalma katmanında değil karar katmanında kuruldu.

## Referanslar

- `ios/Runner/AlarmKitPlatform.swift:31-60` — sunum ve zamanlama
- `ios/Runner/AlarmKitPlatform.swift:105-141` — ses seçimi ve özel ses içe aktarma
- `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmRingService.kt:133-186` — ses döngüsü, URI kararı, titreşim
- `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmRingActivity.kt` — tam ekran çalar ekranı
- `lib/core/interfaces/alarm_service.dart` — ortak Dart arayüzü
- `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmRingService.kt` — `startFadeIn()`, `MediaPlayer.setVolume` ile ramp
- Commit `2cfc4b8` — sessiz pencerelerin yalnızca Android'de yayınlanması
- [Apple Developer Forums 813519](https://developer.apple.com/forums/thread/813519) — AlarmKit'te ses seviyesi kontrolü olmadığına dair DTS yanıtı
