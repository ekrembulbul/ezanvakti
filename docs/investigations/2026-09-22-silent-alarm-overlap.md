# Sessiz alarm incelemesi — 22 Eylül 2026 sabahı

Cihaz: **iPhone 17, iOS 27.0 (24A437)**; uygulama **0.25.1 (64)**, TestFlight. Kullanıcı bildirimi: "sabah 6 civarı alarm sessiz çaldı".

Kaynaklar: uygulamanın alarm defteri (`ezanvakti_alarm_journal_v1`, `ezanvakti_alarm_missions_v2`; `xcrun devicectl device copy from --domain-type appDataContainer` ile alındı) ve cihazın sistem log arşivi (`sudo /usr/bin/log collect --device-udid … --last 1d`; zsh'te `log` builtin olduğu için tam yol gerekir). Ham veri yalnız yerel scratchpad'de; repoya alınmadı. İnceleme salt okunur yürütüldü; cihaza build yüklenmedi, alarm değiştirilmedi.

Defterle sistem logu saniyesine kadar eşleşti (ör. `stop_stale` 06:02:47.431 ↔ AlarmKit `Stopping alarm` 06:02:47.431).

## Zaman çizelgesi (yerel saat)

A = 05:39 "Sabah Namazı" (görevli), B = 05:59 "Sabah Namazı" (görevli). Her ikisi de nöbetçi zinciri ve +5/+10/+15 merdiveniyle kurulu.

| Saat | Kayıt |
| --- | --- |
| 05:39:00.014 | A `Firing event`; ton (`system:Radial`) 05:39:00.068. |
| 05:39:23.228 | Kullanıcı durdurdu; kilitli olduğu için öne alma reddedildi. Nöbetçi 05:39:53. |
| 05:39:53 → 05:40:09 | Nöbetçi çaldı, durduruldu. Nöbetçi 05:40:39. |
| 05:40:39.412 | Nöbetçi çaldı; ton 05:40:39.701. |
| 05:40:41.402 | Ton kapandı: yan tuş (backboardd "2 Button", `deviceDidLock` 05:40:41.327). Alert `alerting` kaldı, **15 dk sessiz durdu**. |
| 05:55:28.554 | Kullanıcı durdurdu; uygulama açıldı; 05:55:32 erteleme → nöbetçi 06:00:32. |
| 05:55:45.965 | Uyku. Seçilen RTC uyanma: alarm, `02:58:50Z` (05:58:50), `UserVisible = 1`. |
| 05:56:41.781 | AOP uyanması (`spu_activity_alarm`), ~8 sn uyanık. |
| 05:56:49.616 | Tekrar uyku. **Seçilen RTC uyanma: `AlwaysOnPresentationEngine`, `03:01:57Z` (06:01:57), `UserVisible = 0`.** Alarmın 05:58:50 isteği seçilmedi. |
| 06:01:58.543 | RTC ile uyanma. |
| 06:01:59.325 | B `Firing event` — **2 dk 59 sn geç**; ton 06:01:59.365. |
| 06:02:01.342 | A nöbetçisi `Firing event` — 1.5 dk geç. Ton teardown + yeniden post: **tek ton slotu, ses yeni alerte geçti.** |
| 06:02:03.328 | Kullanıcı A nöbetçisini durdurdu (`Executing intent`); ton teardown 06:02:03.359. **B için yeniden ton post edilmedi → B alerti ekranda, sessiz.** |
| 06:02:10 – 06:02:47 | A görevi: `begin` ×2, `complete`. |
| 06:02:47.431 | Uzlaştırma `stop_stale` → B alerti **uygulama tarafından** durduruldu. Kullanıcı B'yi hiç durdurmamıştı. |
| 06:04:00.008 | B `#ladder0` çaldı (sesli); 06:04:06 durduruldu; görev 06:04:17 tamamlandı. |

07:45 "İş" alarmı normal: 07:46:02 durduruldu, erteleme, 07:58:18 nöbetçi durduruldu, görev 07:58:35.

## Bulgular

1. **iOS uyanmayı kaçırdı (ikinci vaka).** `mobiletimerd` 05:58:50 için user-visible RTC isteği kurmuştu; 05:56:41 AOP uyanmasından sonraki uyku girişinde `powerd` bu isteği değil, AOD motorunun 06:01:57 isteğini seçti. B 3 dk, A nöbetçisi 1.5 dk geç çaldı. İlk vaka 11 Eylül (ADR 0001, doğrulanmamış noktalar). Uygulamanın planlamasıyla ilgisi yok; Apple Feedback adayı.
2. **iOS tek ton slotu çalıştırıyor.** İki AlarmKit alerti üst üste bindiğinde ses sonrakine geçiyor; sonraki durdurulunca ses öncekine geri verilmiyor. `MTAnalyticsCoordinator` kayıtları: 06:02:01 `didTearDownToneAlert` + `didPostToneAlert`, 06:02:03 yalnız `didTearDownToneAlert`, sonraki `didPostToneAlert` 06:04:00. AlarmKit'te sesi geri getiren çağrı yok (ADR 0003, DTS yanıtı).
3. **Uygulama hatası — bayat alert temizliği çalışı ayırt etmiyordu.** `AlarmPlanEngine.stopStaleAlerts` alarmın *son* oturumuna bakıyordu; oturumlar bitince silinmediği için B'nin 21 Eylül'de bitmiş oturumu, 22 Eylül'ün henüz dokunulmamış çalışını "bitmiş" saydırdı. Sonuç: uygulama, kullanıcının hiç durdurmadığı bir alarmı sustururdu. Merdiven olmasaydı (görevsiz alarm) alarm kaybolurdu. Defterde (17–22 Eylül) ilk tetiklenme; ilk kez iki alarm bu şekilde çakıştı.
4. **05:40:41 sessizliği yan tuş.** Kullanıcı tuşa bastı, iOS tonu kesip alerti ekranda tuttu. iOS davranışı; hata değil.

## Yapılanlar

- Bayat temizliği çalış-farkında: oturum daha eski bir çalışa aitse alert korunur; aynı çalış bitmişse ya da alert daha eski bir çalışa aitse durdurulur. Regresyon testi: `testRefreshKeepsANewAlertWhenThePreviousOccurrenceFinished`.
- Bir alarm durdurulunca **başka** bir alarmın sessiz kalan alerti için `graceSeconds` sonra sesli bir yedek kurulur (`rering`): çalışa kimse dokunmadıysa `isFallback` kaydı (durdurmak oturumu merdiven basamağı gibi açar); zincir sürüyorsa sessiz nöbetçi susturulup zincir taze nöbetçiyle geri gelir, sayaç artmaz. Testler: `testStoppingOneAlarmReringsAnotherAlarmsSilentAlert`, `testStoppingOneAlarmReringsAnotherChainsSilentWatchdog`.
- ADR 0001 güncellendi (22 Eylül eki, ikinci uyanma vakası).

## Sınırlar

- Ses analitiği (`Digital Sound Emitted: false`, `Alert volume: nil`) bütün alarmlarda aynı ve "Validation Concerns" ile işaretli; hoparlör çıkışını kanıtlamaz. Sesin çaldığı/çalmadığı, ton post/teardown kayıtlarından ve kullanıcı ifadesinden çıkarıldı.
- Daha eski alerti durdurunca yeni alertin tonunun da kesilip kesilmediği bugün görülmedi; `rering` her iki yönü de kapsayacak şekilde tüm diğer çalan alarmlara uygulanır.
- Unit testler cihazda sesin çaldığını kanıtlamaz; iki alarmı üst üste bindirip birini durdurarak cihazda doğrulanmalı.
