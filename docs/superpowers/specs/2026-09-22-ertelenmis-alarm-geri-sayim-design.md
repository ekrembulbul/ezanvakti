# Ertelenmiş Alarm Geri Sayımı — Tasarım Spec'i

Ertelenmiş bir alarm, erteleme süresi boyunca alarm satırında ve ana ekrandaki
Sıradaki kartında büyük bir geri sayım rozetiyle görünür; rozete ya da satıra
dokununca mevcut ara ekran "ertelenmiş" kipinde açılır ve kullanıcı görevi
yapar, yeniden erteler ya da (görevsizde) alarmı kapatır. Anahtardan görev
ekranına düşme kalkar. Alarm ara ekranı tasarımını
([2026-08-30](2026-08-30-alarm-ara-ekran-design.md)) ve ADR 0002'nin kapatma
kapısını değiştirir. İki platform.

## 1. Sorun

Alarm ertelendikten sonra (5–20 dk) uygulama sessizdir: satır ve kart yalnızca
"Ertelendi · 05:49'te çalacak · 8 dk" yazar, 10 sn'de bir yenilenir. Kullanıcı
bu sürede fikrini değiştirirse — görevi hemen yapıp alarmı bitirmek, bir kez
daha ertelemek ya da görevsiz alarmı kapatmak — ara ekrana geri dönecek bir
giriş yoktur. Tek giriş, anahtarı kapatmaya çalışmaktır; o da seçim sunmadan
doğrudan görev ekranına düşürür (`resolveMissionBeforeDismiss`). Kullanıcı
kararı: erteleme ilk bakışta belli olsun, dokununca seçim ekranı gelsin.

İkinci, sessiz sorun: erteleme sürerken ikinci bir "Ertele" iki platformda da
**hiçbir şey yapmaz** — native store etkin ertelemeyi görünce oturumu
değiştirmeden döner, Dart tarafı bunu başarı sayar. "Tekrar ertele" için bu
düzeltilmelidir.

## 2. Bugünkü durum ve kod referansları

| # | Bulgu | Kaynak |
|---|---|---|
| M1 | Alarm satırı ertelemeyi alt metinde gösterir; sağda anahtar; dokunma düzenlemeye gider | `alarms_section.dart:155-260` |
| M2 | Sıradaki kartı ertelemeyi alt metinde gösterir; sağda atlama anahtarı; satıra dokunma yok | `upcoming_card.dart:157-226` |
| M3 | Anahtar kapatma ve atlama, görev borcu varsa doğrudan görev ekranı açar | `mission_launcher.dart:133-194`, `reminders_screen.dart:693-702`, `home_page.dart:459-466` |
| M4 | Ara ekran yalnızca durdurma sonrası, `openMissionIfPending` üzerinden açılır; ertelenmişte `StopDecision.none` | `stop_gate.dart:33-42`, `mission_launcher.dart:196-279` |
| M5 | Ara ekran kabuğu durdurma olayını dinler ve oturumu tazeler; görevlide `graceSeconds`, görevsizde `stopScreenSeconds` sayacı | `mission_launcher.dart:281-444` |
| M6 | Erteleme sürerken ikinci erteleme native'de no-op | iOS `AlarmMissionStore.swift:370-384`, Android `AlarmMissions.kt:257-269` |
| M7 | Dart koordinatörü etkin ertelemede limit kontrolünü atlar (native no-op'a güvenerek) | `mission_coordinator.dart:126-145` |
| M8 | Yeni bir zamanlayıcı anı verilince native motor yeni kayıt kurar, eskisini iptal eder | iOS `AlarmPlanEngine.swift:385-398`, Android `AlarmScheduling.kt:108-118` |
| M9 | Görev başlatmak etkin ertelemeyi bitirir (19 Eylül) | `AlarmMissionStore.swift:351-368` |
| M10 | Satır ve kart saatleri 10 sn'lik zamanlayıcıyla yenilenir | `reminders_screen.dart:95`, `home_screen.dart:109` |

## 3. Kararlar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D1 | Kapsam | Yalnızca **ertelenmiş** oturum (`snoozedUntil` gelecekte). Durdurma akışı, 30 sn nöbetçi penceresi ve görev süresi değişmez | Kullanıcı kararı. Diğer pencerelerde ara/görev ekranı zaten açık |
| D2 | Rozet | Ertelenmişken satırın ve kartın sağındaki anahtar yerine **geri sayım rozeti**: üstte "ERTELENDİ", altında `m:ss` (A1) | "İlk bakışta belli olsun"; anahtar zaten kilitli |
| D3 | Sayaç | Rozet kendi 1 sn'lik zamanlayıcısıyla işler; sayfanın 10 sn'lik saati değişmez. Sıfıra inince "0:00" kalır | Yalnızca ertelenmiş satırlar tıklar; alarm çalıp durdurulunca oturum yenilenir ve rozet kalkar |
| D4 | Alt metin | Rozet varken alt metin yalnızca "05:49'te çalacak"; "Ertelendi ·" öneki rozete taşınır | Aynı bilgiyi iki kez yazmamak |
| D5 | Dokunma | Ertelenmişken satıra ya da rozete dokunmak **ara ekranı** açar (düzenleme değil). Kartta satır tıklanabilir olur | Kullanıcı kararı: "üstüne basınca ara ekran" |
| D6 | Anahtar kilidi | Ertelenmişte anahtar ve atlama anahtarının yerini rozet alır; görev borcu olup ertelenmemişte (`blocksDismissal`: nöbetçi ya da görev süresi penceresi) anahtar **gri/devre dışı**. Görevsiz taze durdurmada (45 sn penceresi) anahtar bugünkü gibi çalışır | Kullanıcı kararı. Çıkışsız kalınmaz: ertelenmişte satır, borçluda kendiliğinden açılan ekran |
| D7 | Kapı kaldırma | `resolveMissionBeforeDismiss`, `resolveSkipBeforeDismiss`, `onDisableBlocked` ve çağrıları kalkar; `StopGate.blocksDismissal` kilit kararı için kalır | Anahtardan görev ekranına düşme istenmiyor |
| D8 | Ara ekran kipi | Aynı ekran, "ertelenmiş" kipinde: başlık "ALARM ERTELENDİ"; kahraman **geri sayım** (accent), altında "05:49'te çalar"; alarm saati ve erteleme sayısı küçük satırda (C2). Sağ üstte X | Uyku sersemi kullanıcı için tek dil; en önemli bilgi "ne zaman çalacak" |
| D9 | Düğmeler | Görevli: **Görevi yap** / **Ertele · n dk**. Görevsiz: **Alarmı kapat** / **Ertele · n dk**. "n hak kaldı" satırı aynen | Görevi yap ertelemeyi bitirip görevi başlatır (M9); Alarmı kapat = `complete` + yeniden kurulum (bugünkü Tamam) |
| D10 | X | Hiçbir şeyi değiştirmeden kapatır; erteleme kurulu kalır. Yalnızca ertelenmiş kipte; kendiliğinden açılan kipte yok | Kullanıcı ekranı kendi açtı; kazara seçim yapmadan çıkabilmeli |
| D11 | Otomatik kapanma | Ertelenmiş kipte yok: ne `graceSeconds` uyarısı ne `stopScreenSeconds` kapanışı | Erteleme native'de kurulu; ekran bilgi ve seçim sunar |
| D12 | Yeniden ertele | Yeni çalma anı = **şimdi + `snoozeMinutes`**, `snoozeUsed` +1. Native'de etkin erteleme artık engel değil; limit ve (görevlide) zincir tavanı kontrolü aynen | Kullanıcı kararı: "10 dk daha" |
| D12a | Yeniden deneme | Native no-op kalkınca yeniden deneme (zamanlayıcı kuruldu, eski kaydın temizliği patladı, kullanıcı "Tekrar dene" dedi) ikinci erteleme sayılırdı. İdempotentlik Dart koordinatörüne taşındı: çağıran ekranda gördüğü sayacı verir (`expectedSnoozeUsed`); native sayaç bir ileri ve erteleme etkinse istek zaten uygulanmıştır, native'e gidilmez. Yarım kalan eski zamanlayıcıyı sonraki uzlaştırma temizler | Uygulama sırasında görüldü (iOS `testCleanupRetryDoesNotSpendAnotherSnooze`, Android `retryOfAcceptedSnoozeDoesNotConsumeAnAdditionalRight` eski sözleşmeyi kodluyordu) |
| D13 | Ertele düğmesinin görünürlüğü | Hak yoksa ya da görevlide `now + snoozeMinutes >= chainDeadlineAt` ise düğme çizilmez | Native'in reddedeceği isteği kullanıcıya sunmamak |
| D14 | Kip değişimi | Ekran açıkken erteleme dolup alarm çalar ve durdurulursa, dinlenen durdurma olayı oturumu tazeler; ekran kendiliğinden **durduruldu** kipine geçer (X kalkar, sayaç `grace`/kapanış sayacına döner) | Bugünkü tazeleme deseni (M5); ikinci ekran açılmaz |
| D15 | Düzenleme | Ertelenmişken satırdan düzenleme açılmaz; uzun basma menüsü (kopyala/sil) aynen | Düzenleme yeniden kurulum tetikler ve oturumla çelişir; erteleme bitince satır normale döner |
| D16 | Silme | Değişmez: silme kapıya tabi değil (ADR 0002) | Kalıcı ve niyetli eylem |

## 4. Akış

```
alarm çalar → durdur → uygulama → ara ekran → [Ertele]        (değişmedi)
                                                  │
                                    erteleme sürüyor (5–20 dk)
                                                  │
        Alarmlar satırı / Sıradaki kartı:  [ERTELENDİ 7:42] rozeti, anahtar yok
                                                  │ dokun
                                   ara ekran, "ertelenmiş" kipi
                     ┌──────────────┬──────────────┬──────────────┐
                 Görevi yap     Ertele · 10 dk   Alarmı kapat        X
              (görevli) →       şimdi+10 dk,    (görevsiz) →      hiçbir şey
              görev ekranı      hak −1, kapan   bitir + kur, kapan  değişmez
```

Erteleme dolunca alarm çalar; durdurulunca bugünkü akış aynen devam eder
(durdurma olayı → uygulama → ara ekran, hak sayısı bir eksik).

### Dart

- **Rozet:** yeni `SnoozeCountdown` widget'ı (kendi 1 sn zamanlayıcısı,
  `snoozedUntil`'i alır, `m:ss` yazar; 0'da "0:00"). İki yerde kullanılır:
  `alarms_section.dart` satır `trailing`'i ve `upcoming_card.dart` alarm satırı
  `trailing`'i.
- **Giriş:** `mission_launcher.dart`'a `openSnoozedAlarm(context, alarm)`:
  oturumları tazeler, alarmın ertelenmiş oturumunu bulur (yoksa döner), ekran
  açıksa döner, `_StopHost`'u iter; sonuç `mission` ise `_MissionHost`'u iter
  (bugünkü sıralı iki push deseni). Alarm satırı ve kart bu fonksiyona çıkan
  `onSnoozedTap` callback'i alır; `reminders_screen.dart` ve `home_page.dart`
  bağlar.
- **Kabuk (`_StopHost`):** kip oturumdan türetilir —
  `snoozed = session.snoozedUntil?.isAfter(now) == true`. Ertelenmişte sayaç
  `snoozedUntil − now`; `_tick` otomatik kapanış yapmaz; `_primary` görevlide
  `mission` sonucu, görevsizde `complete` + `rearmAlarms`; yeni `_close` yalnız
  pop. Durdurma olayıyla oturum tazelenince kip kendiliğinden değişir (D14).
- **Ekran (`AlarmStopScreen`):** yeni `snoozedUntil` ve `onClose` alanları.
  `snoozedUntil != null` iken: başlık `stopSnoozedHeadline`, kahraman sayaç
  accent renkte, altında `stopRingsAt(time)`, küçük satırda alarm saati ve
  `stopSnoozedCount(n)`; alt bilgi satırı çizilmez; sağ üstte X. Görevsiz
  birincil etiket `stopCloseAlarm`.
- **Kapı (`StopGate`):** yeni saf `canSnoozeAgain(alarm, session, now)`: hak
  kalmış **ve** (görevsiz ya da `now + snoozeMinutes < chainDeadlineAt`).
  `blocksDismissal` kalır, kilit kararı için. `decide` değişmez.
- **Koordinatör:** `snooze` etkin ertelemede limit kontrolünü artık atlamaz.
- **Kilit:** `alarms_section.dart` — ertelenmişte `trailing` rozet, `onTap`
  `onSnoozedTap`; borçlu-ertelenmemişte `Switch(onChanged: null)`.
  `upcoming_card.dart` — ertelenmişte rozet ve `onTap`; borçlu-ertelenmemişte
  atlama anahtarı devre dışı. `onDisableBlocked` ve kapı fonksiyonları silinir.

### Native

- **iOS `AlarmMissionStore.snooze`:** "etkin erteleme → oturumu değiştirmeden
  dön" satırı kalkar; limit ve tavan kontrolü sonra `snoozedUntil = now +
  minutes`, `snoozeUsed += 1`. Motorun `rearm`'ı yeni kaydı kurar, eskisini
  iptal eder (M8).
- **Android `AlarmMissions.snooze`:** aynı değişiklik; `AlarmScheduling.rearm`
  yeni kaydı kurar (M8).
- Snapshot sözleşmesi değişmez (`snoozedUntil` zaten aktarılıyor).

## 5. Görünüm

Onaylanan mockup: A1 + C2 (22 Eylül).

```
Alarmlar satırı (ertelenmiş)                Sıradaki kartı (ertelenmiş)
┌────────────────────────────────────┐      ┌────────────────────────────────────┐
│ Her gün                 ┌────────┐ │      │ ⏰ Güneş −60 dk ⌗       ┌────────┐ │
│ Güneş −60 dk ⌗          │ERTELENDİ│ │      │    Sabah Namazı         │ERTELENDİ│ │
│ Sabah Namazı            │  7:42  │ │      │    05:49'te çalacak     │  7:42  │ │
│ 05:49'te çalacak        └────────┘ │      │                         └────────┘ │
└────────────────────────────────────┘      └────────────────────────────────────┘

Ara ekran, ertelenmiş kipi
┌──────────────────────────┐
│ ALARM ERTELENDİ       (X)│
│                          │
│       Sabah Namazı       │ 22 pt, ikincil metin
│          7:42            │ AppTypography.counter, accent
│      05:49'te çalar      │ 16 pt kalın, birincil metin
│ Güneş −60 dk · 05:39 ·   │ 15 pt, üçüncül metin
│ 1 kez ertelendi          │
│ ┌──────────────────────┐ │
│ │ ⚑ QR okutma · 90 sn  │ │ yalnız görevli
│ └──────────────────────┘ │
│                          │
│ [     GÖREVİ YAP      ]  │ birincil; görevsizde "ALARMI KAPAT"
│ [  ERTELE · 10 dk     ]  │ ikincil; D13 koşuluyla
│      1 hak kaldı         │
└──────────────────────────┘
```

- Rozet: accent %10 zemin, 12 radius, 7/12/6 pt iç boşluk, min 78 pt
  genişlik; "ERTELENDİ" 10 pt w800 1.4 aralık; sayaç 22 pt w800 tabular.
  Renkler token'lardan (`tokens.accent`), tipografi `AppTypography`
  türevleri.
- Kartta satır yüksekliği rozetle büyür (`growWithContent` zaten açık).
- Sıradaki vakit satırı ertelenmiş kipte de gösterilir (veri varsa).
- Dar ekran ve büyük metin: metin sütunu `Expanded` + ellipsis, rozet sabit;
  RTL'de rozet sola geçer.

## 6. Süreler

Yeni sabit yok. `graceSeconds` ve `stopScreenSeconds` ertelenmiş kipte
kullanılmaz.

## 7. Kapsam dışı

Nöbetçi (30 sn) ve görev süresi pencerelerinde satır sayacı · ertelenmişken
düzenleme · aynı anda birden fazla oturumun kartta gösterimi (bugün de tek
satır) · rozetin widget'a (WidgetKit/AppWidget) taşınması · AlarmKit'in kendi
ertelemesi.

## 8. Riskler

**R1 — Kilitli anahtar.** ADR 0002 bunu "çıkışsız bırakıyordu" diye
terk etmişti; şimdi çıkış satırın kendisi (ertelenmişte) ya da kendiliğinden
açılan ekran (borçlu-ertelenmemişte). ADR güncellenir.

**R2 — Yeniden erteleme ile zincir tavanı.** Görevlide 60 dk tavanı yeniden
ertelemelerle dolabilir; D13 düğmeyi saklar, native yine de reddederse mevcut
hata çubuğu görünür.

**R3 — Saniyelik sayaç.** Yalnızca ertelenmiş satırlar 1 sn'de bir yeniden
çizilir; liste geneli etkilenmez. Uygulama arka planda kalırsa zamanlayıcı
durur; öne gelişte oturum tazelenir.

## 9. Test

**Dart**
- `StopGate.canSnoozeAgain`: hak var/yok, görevsizde tavan yok, görevlide tavan
  sınırı (`now + minutes` tam tavan → false).
- `MissionCoordinator.snooze`: etkin ertelemede limit dolmuşsa `false`;
  dolmamışsa native çağrılır.
- `SnoozeCountdown` widget: `m:ss` biçimi, saniyede bir ilerler, sıfırda
  "0:00".
- `AlarmsSection` widget: ertelenmişte rozet var/anahtar yok, dokunma
  `onSnoozedTap`'i çağırır, alt metin öneksiz; borçlu-ertelenmemişte anahtar
  devre dışı; normalde anahtar ve düzenleme aynen.
- `UpcomingCard` widget: aynı üç durum.
- `mission_launcher` (`openSnoozedAlarm`): oturum yoksa açılmaz; ertelenmiş
  görevlide ekran açılır, "Görevi yap" görev ekranını açar ve `begun` dolar;
  "Ertele" `snoozed` dolar ve kapanır; görevsizde "Alarmı kapat" `completed` +
  `scheduled` dolar; X hiçbir şey çağırmadan kapatır; ekran açıkken durdurma
  olayı gelince X kalkar ve sayaç `grace`'e döner (D14); hak bitince Ertele
  yok.
- `AlarmStopScreen` widget: ertelenmiş kipte başlık, kahraman sayaç,
  `stopRingsAt`, X; görevsizde `stopCloseAlarm`; kendiliğinden kipte X yok.
- Kaldırılan kapı testleri (`resolveMissionBeforeDismiss` grubu) silinir;
  yerine kilit testleri.

**Swift (`RunnerTests`)** — `AlarmMissionStoreTests`: etkin erteleme sürerken
ikinci erteleme `snoozedUntil`'i `now + minutes` yapar ve `snoozeUsed`'ı
artırır; limit dolunca `nil`. `AlarmPlanEngineTests`: yeniden ertelemede eski
zamanlayıcı kaydı iptal, yenisi kurulu.

**Kotlin (`AlarmMissionsTest`)** — aynı iki store senaryosu.

**Cihaz (Ekrem)** — ertele → satır ve kartta rozet sayıyor → dokun → ekran;
Ertele → sayaç şimdi+10'a atlar, hak bir eksik; Görevi yap → görev, alarm
biter; X → değişmez; süre dolunca alarm çalar ve durdurma akışı aynen.
Unit/widget testleri native alarmın gerçek cihazda zamanında çaldığını
kanıtlamaz.

## 10. Doküman

- ADR 0002 "Kapatma girişimleri de aynı kapıdan geçer" bölümü: kapı yerine
  kilit + satırdan giriş; `resolveMissionBeforeDismiss` referansları kalkar.
- ADR 0001 değişmez (zincir kararları aynı).
- Yeni l10n anahtarları (tr/en/ar): `snoozeBadgeLabel`, `snoozeRingsAt`,
  `stopSnoozedHeadline`, `stopRingsAt`, `stopSnoozedCount`, `stopCloseAlarm`,
  `stopCloseTooltip`.
