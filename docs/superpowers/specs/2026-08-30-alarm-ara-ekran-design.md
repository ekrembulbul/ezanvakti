# Alarm Ara Ekranı — Tasarım Spec'i

Alarm durdurulunca açılan, büyük düğmeli bir karar ekranı: görevli alarmda
"Görevi yap / Ertele", görevsiz alarmda "Tamam / Ertele". Görevsiz alarmlarda
erteleme sayısını uygulanabilir kılar ve görev tabanlı kapatma tasarımının
([2026-08-17](2026-08-17-gorev-tabanli-kapatma-design.md)) D3, D6 ve D15
kararlarını genişletir. Yalnızca **iOS**.

## 1. Sorun

Görevsiz bir alarmda sistem uyarısının üstünde "Ertele" düğmesi var ama
**sayılmıyor**: düğme AlarmKit'in kendi `.countdown` davranışı, basıldığında
bizim kodumuz hiç çalışmıyor. Alarm düzenleme ekranındaki "Erteleme sayısı: 1
kez" ayarı görevsiz alarmda hiçbir şey yapmıyor — sınırsız ertelenebiliyor.
Kullanıcı kararı: sayı sayılmıyorsa erteleme uygulama içine, büyük düğmeli bir
ara ekrana taşınsın.

İkinci, daha sessiz sorun: görevsiz alarm çalıp sistemden kapatılınca uygulama
açılmıyor; alarmlar AlarmKit'e tek seferlik kurulu olduğu için ertesi günün
kaydı kullanıcı uygulamayı açana kadar kurulmuyor.

## 2. Ölçümler ve kod referansları

| # | Bulgu | Kaynak |
|---|---|---|
| M1 | Görevsiz + erteleme açık alarmda uyarı `secondaryButtonBehavior: .countdown` ile kuruluyor; kod çalışmıyor | `AppDelegate.swift:242-251` |
| M2 | `stopIntent` cihazda sistemin durdurma jestinde tetikleniyor ve `openAppWhenRun` uygulamayı öne getiriyor | Görev spec'i M2; 0.4.0–0.5.3 cihaz kullanımı |
| M3 | Oturum tek: `MissionChainStore.sessionKey` altında bir kayıt | `AppDelegate.swift:50-55` |
| M4 | `handleStop` her durdurmada `grace` sonrasına nöbetçi kuruyor | `AppDelegate.swift:92-101` |
| M5 | Görev bitince alarmlar yeniden kuruluyor (`rearmAlarms`), ertelemede kurulmuyor | 0.5.3, `mission_launcher.dart` |
| M6 | `openMissionIfPending` görevsiz alarmda oturumu hemen kapatıyor | `mission_launcher.dart:46-50` |

## 3. Alınan kararlar

Bu spec'in kendi numaralandırması; görev spec'ine atıflar tarihle.

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D1 | Yapı | **Tek ekran** (`AlarmStopScreen`), iki tip için; mevcut oturum/koordinatör/nöbetçi altyapısı aynen | En az yeni parça, tek UX dili. Native sayım (`.custom` intent) görev spec'i M5'te iki düğmeyi de öldürmüştü |
| D2 | Görevsiz alarmın uyarısı | `stopIntent` alır, sistemin Ertele düğmesi kalkar — **yalnızca erteleme açıksa** | Erteleme kapalı görevsiz alarmda ara ekranın tek düğmesi olurdu; boş ekran için uygulamayı açmak anlamsız. Bugünkü davranış korunur |
| D3 | Görevsizde durdurmanın anlamı | **Kesin.** Nöbetçi kurulmaz; ara ekran yalnızca erteleme fırsatı | Kullanıcı kararı. Kapı yok; durdurma = alarm bitti |
| D4 | Görevlide ara ekranda oyalanma | Süre dolarsa **alarm döner** (bugünkü `grace` nöbetçisi) | Kapı görevli alarmın asıl amacı; ara ekran onu delmemeli |
| D5 | Erteleme sayımı | İki tipte de `snoozeMission` üzerinden, uygulama içinde. Görev spec'i **D3 ve D15 tüm alarmlara genişler, D6 kalkar** | Sayabilmenin tek yolu kodumuzun çalışması |
| D6 | Ekranın açılma koşulu | **Yalnızca gerçek bir seçim varsa:** erteleme açık ve hak kalmış. Aksi halde bugünkü yol (görevli → doğrudan görev ekranı; görevsiz → oturum kapanır) | Tek düğmelik ekran uykulu kullanıcıya fazladan dokunuş. Görevsizde hak bittikten sonraki son çalışta uygulama yine açılır ama ekran çıkmaz — native kalan hakkı bilmiyor; kabul edilen küçük bedel |
| D7 | Bayatlık | `stoppedAt + stopScreenSeconds < şimdi` ise ekran açılmaz; oturum kapanır, alarmlar yeniden kurulur | Görevsiz alarmı durdurup telefonu açmayan kullanıcı saatler sonra eski bir Ertele ekranıyla karşılaşmamalı |
| D8 | Tamam ve otomatik kapanma | `complete()` + `rearmAlarms` | Oturum kapanır, ertesi gün kurulur — §1'deki ikinci sorun burada kapanıyor |
| D9 | Oturum modeli | `MissionSession`'a `stoppedAt` eklenir; her yeni durdurma olayında güncellenir | Geri sayım ve bayatlık buna bağlı. `firedAt` ilk çalışta sabitleniyor, erteleme sonrası ikinci durdurmada değişmiyor |
| D10 | `gated` bayrağı | Yalnızca **native** oturumda; Dart'ta `alarm.mission.requiresGate`'ten türetilir | `handleStop` nöbetçi kararını Dart olmadan veriyor; Dart tarafında ise alarm zaten elde |
| D11 | Sağlama merdiveni | Görevsizde **kurulmaz** | Kapı yok; merdiven kapıyı kapalı tutmak içindi |
| D12 | Süreler | `graceSeconds` 20 → **30**; yeni `stopScreenSeconds` = **45** | Kullanıcı kararı. 20 sn ara ekranı okuyup basmak için dar; görevsizde ceza yok ama ekran sonsuza kadar açık da kalmasın |
| D13 | Görsel dil | Görev ekranıyla aynı: palet zemini, `AppTypography.counter`, `kMissionButton*` ölçüleri | Yan yana durunca tek uygulama gibi görünmeli |
| D14 | Düğme rolleri | Birincil (dolu accent): görevlide "Görevi yap", görevsizde "Tamam". Ertele iki tipte de ikincil (çerçeveli) ama aynı boyda | Amaçlanan eylem birincil; iki büyük hedef |
| D15 | Çıkış | `fullscreenDialog`, geri tuşu/kaydırma yok; çıkış yalnızca düğmelerle ya da süre dolunca | Görev ekranıyla aynı; kazara kapanma yok |
| D16 | Görev ekranındaki Ertele | **Kalır** | Görevi yapmaya başlayıp vazgeçen kullanıcı için; kaldırmak gerileme olurdu |
| D17 | Tek oturum sınırı | Korunur (M3) | İki alarm dakikalar içinde üst üste çalarsa ikincisi birincinin oturumunu ezer. Bugün de böyle; bu turun kapsamı dışında |

## 4. Akış

```
alarm çalar → sistem uyarısı (yalnızca durdur) → stopIntent → uygulama açılır
                                                        │
                                          ┌─────────────┴─────────────┐
                                     görevli                       görevsiz
                                          │                             │
                                 [Görevi yap] [Ertele·n]        [Tamam] [Ertele·n]
                                          │                             │
                              süre dolarsa alarm DÖNER        süre dolarsa ekran KAPANIR
                              (graceSeconds nöbetçisi)        (stopScreenSeconds, Tamam sayılır)
```

Erteleme iki tipte de aynı: `snoozeMission` → nöbetçi `snoozeMinutes` sonrasına
kurulur → çalar → durdur → uygulama → ara ekran, sayaç bir eksik.

### Native (`AppDelegate.swift`)

- `scheduleAlarm`: `stopIntent` koşulu `missionEnabled || snoozeEnabled`.
  Görevsiz + erteleme açıkta `.countdown` düğmesi ve `countdownDuration`
  kurulmaz. Oturuma `gated = missionEnabled` yazılır; merdiven yalnızca
  `gated` iken.
- `handleStop`: olay her zaman kuyruğa yazılır ve `notifyDart` çağrılır;
  nöbetçi ve `rearmCount` artışı **yalnızca `gated`** iken.
- `beginMission`, `snoozeMission`, `endMission` değişmez.

### Dart — kapı mantığı (`openMissionIfPending`)

| Durum | Sonuç |
|---|---|
| Oturum yok / ertelenmiş ve süresi dolmamış | Hiçbir şey |
| Alarm silinmiş | `complete` + yeniden kur (bugünkü) |
| Görevsiz, erteleme kapalı | `complete` + yeniden kur (bugünkü) |
| Görevsiz, bayat (D7) | `complete` + yeniden kur, ekran yok |
| Görevsiz, taze, hak var | `AlarmStopScreen` [Tamam] [Ertele·n] |
| Görevsiz, taze, hak yok | `complete` + yeniden kur, ekran yok |
| Görevli, hak yok | Doğrudan görev ekranı (bugünkü) |
| Görevli, hak var | `AlarmStopScreen` [Görevi yap] [Ertele·n] |

"Görevi yap" → görev ekranı (`_MissionHost`) `pushReplacement` ile; `begin`
oradan çağrılır, nöbetçi `grace`ten görev süresine taşınır.

Ekran açıkken yeni durdurma olayı gelirse (görevlide süre dolup alarm döndü ve
yine durduruldu) açık ekran `stoppedAt` ile geri sayımı tazeler; ikinci ekran
açılmaz — görev ekranının `missionStops` dinleme deseni.

## 5. Ekran

```
görevli                                 görevsiz
┌──────────────────────────┐            ┌──────────────────────────┐
│ ALARM DURDURULDU         │            │ ALARM DURDURULDU         │
│                          │            │                          │
│ Sabah Namazı             │ etiket     │ İş                       │
│ 05:06                    │ büyük      │ 08:45                    │
│ Güneş −60 dk · 2 dk önce │ ince       │ Her gün · 1 dk önce      │
│                          │            │                          │
│ ┌──────────────────────┐ │            │                          │
│ │ ⌗ QR okutma · 90 sn  │ │ görev kartı│                          │
│ └──────────────────────┘ │            │                          │
│                          │            │                          │
│ [     GÖREVİ YAP      ]  │ birincil   │ [       TAMAM        ]   │
│ [  ERTELE · 10 dk     ]  │ ikincil    │ [  ERTELE · 10 dk    ]   │
│      1 hak kaldı         │            │      1 hak kaldı         │
│                          │            │                          │
│ Seçim yapmazsan alarm    │ uyarı      │ Dokunmazsan 0:38 sonra   │ bilgi
│ 0:24 sonra döner         │            │ kapanır                  │
└──────────────────────────┘            └──────────────────────────┘
```

- Etiket ve saat satırı alarm listesindeki yardımcılardan (`alarm_labels.dart`).
- Hak sayısı satırı sınırsızda yok.
- Alt satır: görevlide uyarı tonu, görevsizde bilgi tonu. Geri sayım
  `stoppedAt + süre − şimdi`, saniyede bir işler.
- Görev kartı yalnızca görevlide: görev adı, seviye, süre.

## 6. Süreler (`MissionTuning`)

| Sabit | Değer | Anlamı |
|---|---|---|
| `graceSeconds` | **30** | Görevli ara ekranda seçim süresi; dolarsa alarm döner |
| `stopScreenSeconds` | **45** | Görevsiz ara ekran; dolarsa Tamam sayılır |

## 7. Kapsam dışı

Aynı anda birden fazla oturum (D17) · görevsiz alarmda native sayım ·
Android · AlarmKit'in kendi haftalık tekrarına geçiş (yapısal iyileştirme;
D8 ile aciliyeti düştü).

## 8. Riskler

**R1 — Kilitli cihazda `openAppWhenRun`.** Görevsiz alarmı kilit ekranından
durdurup telefonu açmayan kullanıcı ara ekranı hiç görmez; D3 gereği alarm
zaten bitmiştir, kaybedilen yalnızca erteleme fırsatıdır. D7 bayat oturumu
temizler.

**R2 — Görevsiz alarmda uygulamanın her durdurmada açılması.** Kullanıcı
kararı (yaklaşım 1). Rahatsız ederse D2'deki koşul daraltılabilir.

## 9. Test

**Dart:**
- `MissionCoordinator.resume`: yeni olayda `stoppedAt` güncellenir; olay yoksa
  korunur.
- `openMissionIfPending`: §4 tablosunun sekiz satırı, launcher testinde.
  Bayatlık sınırı (`stopScreenSeconds − 1` açılır, `+ 1` açılmaz).
- `AlarmStopScreen` widget testleri: iki tipte düğme etiketleri ve rolleri;
  hak sayısı satırı (var/yok/sınırsız); geri sayım metni; Tamam →
  `completed` + `scheduled` dolu; Ertele → `snoozed` dolu, `scheduled` boş;
  Görevi yap → görev ekranı açılır ve `begun` dolu; süre dolunca görevsizde
  ekran kapanır ve `completed` dolu.
- `MissionTuning`: 30 / 45.

**Swift:** `handleStop`'un `gated=false` iken nöbetçi kurmaması
`MissionChainStore` içinde; saf bir karar fonksiyonu ayrıştırılıp
`RunnerTests`'te sınanır.

**Cihaz:** görevsiz alarmı durdur → ara ekran; Ertele → `snoozeMinutes` sonra
tekrar çalar, ekran "0 hak" ile açılmaz; Tamam → ertesi gün alarm çalar.
Görevli: ara ekranda 30 sn bekle → alarm döner.
