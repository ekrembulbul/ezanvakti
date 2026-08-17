# Görev Tabanlı Kapatma (iOS) — Tasarım Spec'i

Alarmın, kullanıcı bir görevi (matematik, QR okutma, sallama) tamamlamadan
kapatılamaması. Bu tur yalnızca **iOS**; Android sonraki turda.

## 1. Sorun

Bugün alarm tek dokunuşla — daha doğrusu tek kaydırmayla — kapanıyor. Uykulu
bir kullanıcı bunu farkında olmadan yapıp uyumaya devam edebiliyor. İstenen:
alarmın ancak kullanıcıyı gerçekten uyandıran bir eylemden sonra susması.

AlarmKit bunu doğrudan desteklemiyor. Uyarıyı sistem çiziyor, durdurma jestini
sistem işliyor ve alarmı sistem durduruyor; "kullanıcı şunu yapmadan
kapatamasın" diyebileceğimiz bir API yok. Çalma süresini sınırlayan bir
parametre de yok (bkz. §3 D1).

## 2. Ölçümler

Tasarım tahmine değil, `spike/alarmkit-davranis` dalında yapılan ölçümlere
dayanıyor. Ölçüm kodu atıldı; sonuçlar burada.

| # | Soru | Sonuç | Ortam |
|---|---|---|---|
| M1 | Eşzamanlı kayıtlı alarm tavanı var mı? | Hayır — 200 alarm hatasız kuruldu | Simülatör |
| M2 | `stopIntent`, sistemin kaydırmalı durdurmasında tetikleniyor mu? | **Evet** | Gerçek cihaz, iOS 26.5.2 |
| M3 | Simülatörde App Intent çalışır mı? | Hayır. `linkd`: `Unable to get teamId` → `Rejecting invalid client due to requiresValidBundle`. Simülatör build'i ad-hoc imzalı | Simülatör |
| M4 | Alarm kendiliğinden susuyor mu? | Hayır — 11 dk 1 sn kesintisiz çaldı, durma olayı yok | Simülatör |
| M5 | `secondaryButtonBehavior: .custom` + çalışmayan intent | Erteleme **ve** durdurma düğmesi ölüyor, alarm kapatılamaz hale geliyor | Simülatör |
| M6 | `postAlert` erteleme süresi | Tam tutuyor: 21:49:15 → 21:54:15 (300 sn) | Simülatör |

M2, bu tasarımın taşıyıcı bulgusu: kullanıcı alarmı durdurduğunda **bizim
kodumuz çalışabiliyor**. M5, `.custom`'dan neden kaçındığımızı açıklıyor.

Referans: [Apple forum 815064](https://developer.apple.com/forums/thread/815064)
— `stopIntent`, alarm kilitsiz ekranda çalıp kullanıcı cihazı kullanırken
kapatıldığında ya da Live Activity banner'ı yukarı kaydırıldığında
**tetiklenmiyor**. Tasarım bu boşluğu kapatmak zorunda (§5.2).

## 3. Alınan kararlar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D1 | Çalma süresi sınırı | **iOS'ta yok.** Android turuna bırakıldı | Susturmak için `AlarmManager.stop(id:)` gerekiyor; o da alarm çalarken ayakta olmayan kendi process'imizde çalışıyor. Public API'de zamanlayıcıyla durdurma yolu yok |
| D2 | Kapı nerede | **Yalnızca kapatmada.** Erteleme görev istemez | Kullanıcı kararı. En az riskli yüzey |
| D3 | Erteleme nerede yaşar | Sistem uyarısından **kaldırılır** (`secondaryButton: nil`), uygulama içine taşınır | Sayı limiti için ertelemeyi sayabilmemiz lazım; `.countdown`'da kodumuz hiç çalışmıyor, `.custom` ise M5'teki arızayı taşıyor. Uygulama içi erteleme ikisinden de bağımsız |
| D4 | Erteleme limiti | Alarm başına `maxSnoozes`; dolunca erteleme düğmesi kaybolur, yalnızca görev kalır | Kullanıcı kararı |
| D5 | Görev tercihi kapsamı | **Alarm başına** (`Alarm` modeline alan) | `soundId`/`vibrate`/`snoozeMinutes` ile aynı konvansiyon; mevcut `AlarmArgs` hattından kendiliğinden akar. Sahur alarmı görevli, öğle hatırlatması görevsiz olabilir |
| D6 | Görev kapalıysa | **Bugünkü davranış birebir korunur**: `.countdown` erteleme, `stopIntent` yok, zincir yok | Riski yalnızca özelliği açan kullanıcıya sınırlar. Mevcut, çalıştığı doğrulanmış yol bozulmaz |
| D7 | Tekrar çalma mekanizması | İki katman: `stopIntent` tabanlı **hızlı zincir** + önden kurulu **sağlama merdiveni** | `stopIntent` çalıştığı sürece kullanıcı saniyeler içinde görev ekranına düşer (iyi UX). Forum 815064'teki boşlukta hızlı zincir kurulamaz; merdiven kapıyı yine de kapalı tutar |
| D8 | Döngünün üst sınırı | `maxRearms` **ve** `chainDeadline` (ikisinden hangisi önce dolarsa) | Spike'ta yaşanan sonsuz döngü kazası: ispat alarmına da `stopIntent` bağlanınca her kapatış yenisini doğurdu, telefon susmadı. Bug varsa zincir kendini durdurmalı |
| D9 | Acil çıkış | Görev ekranında "Alarmı tamamen kapat". İlk kademe **3 sn basılı tutma + onay**; sonraki kademeler D17'de | Hiç çıkışı olmayan alarm hem güvenlik hem App Store riski. Basılı tutma, uykulu bir parmağın kazayla basmasını engelleyecek kadar bilinçli bir hareket |
| D10 | Kurulan alarmların kaydı | Zincirin kurduğu **her** alarm id'si kalıcı deftere yazılır | Spike'ta rastgele UUID kullandığım için kurduğum alarmları iptal edemedim, uygulamayı silmek zorunda kaldık. Kaydedilmeyen alarm iptal edilemez |
| D11 | Zincir mantığı nerede çalışır | **Swift tarafında** | Kullanıcı uygulamayı hiç açmayabilir; Dart o zaman çalışmaz. `stopIntent` ise Flutter engine olmadan da çalışır |
| D12 | Native → Dart haberleşmesi | `stopIntent` olayı UserDefaults'taki kuyruğa yazar; uygulama öne gelince Dart kuyruğu tüketir | Intent anında Flutter engine ayakta olmayabilir. Kuyruk, olayın kaybolmamasını garanti eder |
| D13 | Görev süresi | **Görev tipine göre sabit süre.** Süre görev ekranı açıldığında başlar; dolarsa alarm döner. Ayrıca kısa bir `grace`: durdurup uygulamayı hiç açmayan kullanıcıyı beklemeden yakalar | Sabit süre uyandırma baskısını korur. "Yavaş yapan cezalanır" itirazı süreyi göreve göre ayarlayarak karşılanıyor: QR'da banyoya yürümek dakikalar sürebilir, matematik saniyeler. Tek bir ortak süre ikisine birden yanlış gelirdi |
| D14 | Süreler kimin ayarı | **Bizim.** Tek bir yapılandırma dosyasında sabit; kullanıcı arayüzünde görünmez | Doğru değerler ölçümle bulunur, kullanıcının bilebileceği bir şey değil. Ayarlanabilir tutulmasının sebebi kalibrasyon, kişiselleştirme değil |
| D15 | Erteleme ayarları kimin | **Kullanıcının**, ama kapalı seçenek listesinden. Süre: bugünkü `5/10/15/20 dk`. Sayı: `1/2/3/5` ve görev kapalıysa ayrıca `Sınırsız` | Serbest metin alanı anlamsız değerlere ve kenar durumlara açık. Görev açıkken sınırsız erteleme kapıyı işlevsiz bırakırdı — kullanıcı görevi hiç yapmadan sonsuza kadar erteleyebilirdi |
| D16 | Tek çalışta çalma süresi | Kullanıcıya **sunulmaz**. Alarm kapatılana kadar çalar | iOS kısıtı (D1). Sunulup çalışmayan bir ayar, olmayan ayardan kötüdür |
| D17 | Acil çıkışın zorluğu | **Kademeli.** Her kullanımda bir üst seviyeye çıkar: basılı tutma → cümle yazma → uzun cümle + geri sayım. Çıkış metni bir sonraki seferin daha zor olacağını söyler | Acil çıkış gerçek bir ihtiyaç (kamera bozuldu, kod kayboldu) ama alışkanlığa dönüşürse özellik anlamını yitirir. Kademeli zorluk, arızi kullanımı ucuz, alışkanlığı pahalı tutar |
| D18 | Kademenin tavanı ve gerilemesi | En üst seviye sabit bir tavanla sınırlı; **7 gün** kullanılmazsa bir kademe geri iner | Tavan olmazsa çıkış fiilen imkânsızlaşır — §7'deki "her zaman erişilebilir" kuralı çiğnenir ve alarm yine kapatılamaz hale gelir. Gerileme, kötü bir haftanın kalıcı ceza olmasını engeller |
| D19 | Kademe kimin üzerinde tutulur | **Global** — tek sayaç, tüm alarmlar için ortak | Cezalandırılan davranış "görevden kaçmak", hangi alarmdan kaçıldığı değil. Alarm başına tutmak fazladan durum ve taşıma işi getirir, karşılığında bu aşamada gözle görülür bir fayda vermez |

## 4. Kapsam

**Bu turda:**
- iOS'ta görev tabanlı kapatma altyapısı: hızlı zincir, sağlama merdiveni,
  alarm defteri, görev tamamlanma sinyali, güvenlik sınırları
- Uygulama içi erteleme ve sayı limiti
- Üç görev tipi: matematik, QR okutma, sallama
- `Alarm` modeli ve kalıcılaştırma değişiklikleri (platform-nötr)

**Kapsam dışı:**
- **Android.** Model ve durum katmanı platform-nötr yazılır ama
  `AlarmRingActivity` tarafına bu turda dokunulmaz
- Çalma süresi sınırı (D1)
- Görev istatistikleri, "kaç kez ertelediniz" raporu
- Uyku takibi, akıllı uyandırma

## 5. Mimari

### 5.1 Normal akış (görev açık)

```
T        Ana alarm çalar (kapatılana kadar çalar, D16)
         ↓ kullanıcı kaydırıp durdurur
T+ε      stopIntent çalışır (Swift):
           - defterden zincir durumunu okur
           - sınır dolmadıysa T+ε+grace'e nöbetçi alarm kurar
           - "durduruldu" olayını kuyruğa yazar
           - openAppWhenRun ile uygulamayı açar
         ↓
         Uygulama görev ekranını gösterir → beginMission:
           nöbetçi alarm now+missionTimeout'a ötelenir   ← görev süresi (D13)
         ↓ görev tamamlanır
         Dart: defterdeki tüm alarmları iptal eder, oturumu kapatır
```

**Görev süresi (D13).** İki ayrı sayaç var, ikisi de bizim ayarımız (D14):

| Sayaç | Ne zaman işler | Dolarsa |
|---|---|---|
| `graceSeconds` | Alarm durdurulduğu andan görev ekranı açılana kadar | Alarm döner. Durdurup uykuya dönen kullanıcı beklemeden yakalanır |
| `missionTimeout` | Görev ekranı açıldığı andan itibaren, **görev tipine göre** | Alarm döner |

Görev ekranı süreyi görünür bir geri sayımla gösterir; kullanıcı ne kadar
kaldığını bilmeli, alarm sürpriz olmamalı.

Süre görev tipine göre ayrı ayarlanır (§5.6): QR'da banyoya yürümek dakikalar
sürebilirken matematik saniyeler alır. Tek ortak süre ikisine de yanlış gelirdi.

Uygulama arka plana atılırsa sayaç **durmaz**; süre işlemeye devam eder.
Telefonu bırakıp uyumaya dönen kullanıcı, görev ekranını açık bırakarak
alarmdan kaçamamalı.

### 5.2 stopIntent çalışmadığında

Forum 815064'teki senaryolarda 5.1'in ikinci adımı hiç gerçekleşmez: alarm
susar, hiçbir şey kurulmaz, kapı delinir. Bunu kapatmak için alarm
**kurulurken** sağlama merdiveni de kurulur:

```
T,  T+G,  T+2G,  T+3G      (G varsayılan 5 dk, 3 basamak)
```

Bunlar görev tamamlanınca iptal edilir. Hızlı zincir çalışıyorsa da iptal
edilir — merdiven yalnızca sessiz başarısızlık durumunda devreye girer.

Merdiven basamağı ana alarm hâlâ çalarken denk gelebilir (kullanıcı 5 dk
boyunca alarma dokunmadıysa). Bu zararsız: o senaryoda kullanıcı zaten
uyanmamıştır, fazladan bir uyarı sorun değil.

### 5.3 Zincir durumu (UserDefaults)

Swift'in Dart olmadan karar verebilmesi için gereken asgari kayıt. Dart alarmı
kurarken yazar, Swift günceller, Dart görev bitince siler.

```
ezanvakti_mission_session = {
  "alarmId":       "<alarm id>",
  "pending":       true,
  "rearmCount":    0,
  "maxRearms":     40,
  "chainDeadline": <epoch ms>,     // T + 60 dk
  "graceSeconds":  20,             // durdurdu, uygulamayi acmadi
  "missionTimeout": 90,            // gorev tipine gore, ekran acilinca isler
  "deadline":      <epoch ms>,     // yururlukteki sayacin bitisi
  "title":         "Sahur",
  "tintHex":       "#5E3A80",
  "soundId":       "adhan"
}

ezanvakti_mission_events = [ { "alarmId": "...", "stoppedAt": <epoch ms> } ]

ezanvakti_alarm_uuid_map = { "<id>": "<uuid>", "<id>#w1": "<uuid>", ... }
```

Üçüncüsü bugün de var (`AppDelegate.swift:233`, `mapKey`); zincirin kurduğu
alarmlar `<alarmId>#w<k>` türetilmiş id'lerle aynı deftere yazılır, böylece
`cancelAll` hepsini yakalar (D10).

**Hangi kayıt yetkili.** Zincirin canlı durumu için **UserDefaults yetkilidir**;
Swift, Dart olmadan da karar verebilmek zorunda (D11). §6'daki `MissionSession`
bunun Dart tarafındaki **türevidir**: uygulama öne geldiğinde
`consumeMissionEvents` ile güncellenir, kullanıcıya gösterilecek durumu ve
geçmişi tutar. İkisi çelişirse UserDefaults kazanır. Dart, zincir alanlarını
(`rearmCount`, `chainDeadline`) asla doğrudan yazmaz — yalnızca
`completeMission` / `abortMission` ile oturumu bitirir.

### 5.4 Native kontrat değişiklikleri

`AlarmService.scheduleAlarm` iki yeni alan alır:

| Alan | Tip | Anlam |
|---|---|---|
| `missionEnabled` | `bool` | true ise: erteleme düğmesi çizilmez, `stopIntent` bağlanır, merdiven kurulur |
| `chainConfig` | `Map?` | §5.6'daki sabitler: `grace`, `missionTimeout`, `maxRearms`, `chainDeadline`, `ladderStep`, `ladderCount` |

Yeni method'lar:

| Method | Yön | İş |
|---|---|---|
| `consumeMissionEvents` | Dart → native | Kuyruğu okuyup temizler, olay listesi döner |
| `beginMission` | Dart → native | Görev ekranı açıldı: nöbetçiyi `grace`ten `now + missionTimeout`'a taşır (D13) |
| `completeMission` | Dart → native | Oturumu kapatır, deftere kayıtlı tüm zincir alarmlarını iptal eder |
| `abortMission` | Dart → native | Acil çıkış (D9): `completeMission` ile aynı temizlik, ayrı isim çünkü raporlaması farklı |

`missionEnabled: false` geldiğinde native taraf bugünkü koda birebir düşer
(D6) — `.countdown`, `stopIntent` yok, zincir yok.

### 5.5 Görev arayüzü

Üç görev tipi aynı sözleşmeye oturur; altyapı görev tipini bilmez.

```dart
abstract class MissionChallenge {
  /// Görev ekranında çizilecek gövde.
  Widget build(BuildContext context, VoidCallback onCompleted);

  /// Göreve başlamadan önce gereken izin (QR için kamera). Yoksa null.
  Future<bool> Function()? get permissionRequest;
}
```

| Tip | Tamamlanma koşulu | Ek gereksinim |
|---|---|---|
| `math` | `level`'a göre üretilen N sorunun hepsi doğru | Yok |
| `qr` | Okunan kod, alarma kayıtlı `qrPayload` ile birebir eşleşir | `NSCameraUsageDescription`, kamera izni, kod kaydetme akışı |
| `shake` | İvmeölçerde eşiği aşan N sallama sayılır | Hareket sensörü erişimi |

QR'ın kaçış yolu olmalı: kod bulunamıyorsa (kullanıcı seyahatte, kâğıt yırtılmış)
D9'daki acil çıkış tek yol olarak kalır. Ayrı bir "kodu atla" düğmesi **konmaz**,
yoksa görev anlamını yitirir.

### 5.6 Kalibrasyon sabitleri

Görev süreleri ve zincir değerleri tek bir dosyada toplanır (`lib/core/config/
mission_tuning.dart`) ve `chainConfig` ile native'e geçer. **Ayarlar ekranında
görünmezler** (D14) — burada ayarlanabilir olmalarının sebebi ölçümle kalibre
edebilmek, kullanıcıya seçenek sunmak değil.

| Sabit | Başlangıç | Anlamı |
|---|---|---|
| `graceSeconds` | 20 | Durdurdu ama görev ekranını açmadı; alarmın dönmesi için beklenen süre |
| `ladderStepMinutes` | 5 | Sağlama merdiveni adımı (§5.2) |
| `ladderCount` | 3 | Merdiven basamak sayısı |
| `maxRearms` | 40 | Zincirin sert tekrar tavanı (§7) |
| `chainDeadlineMinutes` | 60 | Zincirin sert süre tavanı (§7) |
| `abortDecayDays` | 7 | Acil çıkış kademesinin bir basamak gerilemesi için geçmesi gereken süre (D18) |
| `abortMaxLevel` | 3 | Acil çıkış zorluk tavanı (D18) |

**Görev süreleri**, tipe ve seviyeye göre ayrı (D13):

| Görev | `missionTimeout` başlangıç | Gerekçe |
|---|---|---|
| `math` | 90 sn | Soru ekranda, yürümek gerekmiyor |
| `shake` | 60 sn | Tek hareket, hemen başlar |
| `qr` | 180 sn | Kodun bulunduğu yere yürümek gerekir |

`missionLevel` yükseldikçe süre değil **iş miktarı** artar (daha çok soru, daha
çok sallama). Süreyi de kısaltmak iki kaldıracı birden çekmek olurdu.

Başlangıç değerleri tahmindir; cihazda ölçülüp kesinleştirilecek (§11).

## 6. Veri modeli

`Alarm` modeline eklenenler:

| Alan | Tip | Varsayılan | Not |
|---|---|---|---|
| `mission` | `AlarmMission` | `none` | `none \| math \| qr \| shake` |
| `missionLevel` | `int` | `1` | 1–3; matematik zorluğu, sallama sayısı |
| `qrPayload` | `String?` | `null` | Yalnızca `mission == qr` |
| `maxSnoozes` | `int?` | `null` | `null` = sınırsız |

`snoozeEnabled` ve `snoozeMinutes` korunur; anlamları değişmez.

**Kullanıcıya sunulan seçenekler (D15).** İkisi de kapalı liste, serbest giriş yok:

| Ayar | Seçenekler | Not |
|---|---|---|
| Erteleme süresi | `5 / 10 / 15 / 20 dk` | Bugünkü liste (`alarm_edit_screen.dart:573`) korunur |
| Erteleme sayısı | `1 / 2 / 3 / 5` — görev kapalıysa ayrıca `Sınırsız` | Görev açıkken `Sınırsız` **listelenmez**: kullanıcı görevi hiç yapmadan sonsuza kadar erteleyebilirdi, kapı işlevsiz kalırdı |

**Öncelik kuralı:** `snoozeEnabled == false` ise erteleme hiç sunulmaz ve
`maxSnoozes` yok sayılır; süre ve sayı alanları da gizlenir. Görev açık bir
alarmda `maxSnoozes` `null` bırakılamaz — kaydederken en büyük sonlu seçeneğe
(`5`) düşürülür.

Görev kapalıyken erteleme bugünkü gibi sistem uyarısındaki düğmeden yürür
(D6); açıkken uygulama içine taşınır (D3). Yani erteleme sayacı yalnızca görev
açık alarmlarda anlamlıdır.

Çalışma zamanı oturumu (`MissionSession`) ayrı saklanır — `Alarm` kullanıcı
tercihidir, oturum geçici durumdur. Saklama için `settings` tablosunda tek JSON
satırı yeterli (aynı anda en fazla bir aktif oturum var); `2026-08-04
tek-seferlik-kapatma` spec'indeki D5 ile aynı gerekçe.

| Alan | Tip |
|---|---|
| `alarmId` | `String` |
| `firedAt` | `DateTime` |
| `snoozeUsed` | `int` |
| `rearmCount` | `int` |
| `completedAt` | `DateTime?` |

Acil çıkış kademesi global olduğu için (D19) oturumun değil, ayrı bir kalıcı
kaydın parçası — `settings` tablosunda iki alan yeter:

| Alan | Tip | Not |
|---|---|---|
| `abortLevel` | `int` | 0 … `abortMaxLevel` |
| `abortLastUsedAt` | `DateTime?` | Gerileme hesabı için (D18) |

## 7. Güvenlik sınırları

Bunlar kabul kriteridir, opsiyonel değil. Gerekçesi spike'ta yaşanan kaza:
ispat alarmına da `stopIntent` bağlanınca her kapatış yenisini doğurdu ve
telefonu susturmanın tek yolu uygulamayı silmek oldu.

1. **Sayılı doğuş noktası ve tek geçit.** Nöbetçi yalnızca iki yerden kurulur:
   alarm kurulurken sağlama merdiveni (§5.2) ve `stopIntent`. Nöbetçi
   durdurulduğunda zincirin devam etmesi **istenen** davranıştır — kapıyı bu
   tutuyor. Ama bu devam, her seferinde tek bir geçitten geçmek zorunda:
   `pending` bayrağı ve iki tavan (madde 2) kontrol edilmeden yeni alarm
   kurulmaz. Spike'ta sonsuz döngü tam olarak bu geçit olmadığı için oluştu:
   ispat alarmına `stopIntent` bağlanmıştı, hiçbir sınır yoktu, her kapatış
   yenisini doğurdu ve telefon susmadı.
2. **Çift sınır.** `rearmCount >= maxRearms` **veya** `now >= chainDeadline`
   olduğunda zincir durur ve oturum kapanır. Varsayılanlar: 40 tekrar, 60 dk.
3. **Defter zorunlu.** Kurulan her alarm, kurulduğu anda deftere yazılır;
   iptal defter üzerinden yürür. Deftere yazılamayan alarm kurulmaz.
4. **Acil çıkış her zaman erişilebilir** (D9), ama kullandıkça zorlaşır (D17).
   Kabul kriterleri:
   - Görev ekranında **her zaman görünür** — belirli sayıda başarısızlıktan
     sonra açılan gizli bir yol değil. Kamera bozulduysa ya da kod
     kaybolduysa kullanıcı kilitlenmiş olmamalı
   - `abortMission` çağırır: zincirdeki **tüm** alarmlar iptal edilir, oturum
     kapanır. `completeMission` ile aynı temizlik
   - Görevden bağımsız çalışır: görev kodu çökse, izin reddedilse, sensör
     yanıt vermese bile çıkış yolu ayakta kalır
   - **Tavanı var** (`abortMaxLevel`). Tavansız kademe, çıkışı fiilen imkânsız
     yapar ve alarmı yine kapatılamaz hale getirir — §7'nin ihlali olur

### 7.1 Acil çıkış kademeleri

Kademe **global** tutulur (D19): tek sayaç, tüm alarmlar için ortak. Her
kullanımda bir artar, `abortDecayDays` gün kullanılmazsa bir azalır (D18).

| Seviye | Ne isteniyor |
|---|---|
| 0 | 3 sn basılı tutma + onay |
| 1 | 3 sn basılı tutma + onay + kısa cümle yazma |
| 2 | 3 sn basılı tutma + onay + uzun cümle yazma |
| 3 (tavan) | Seviye 2 + atlanamayan 15 sn geri sayım |

Yazılacak cümle ekranda gösterilir ve **birebir** yazılması istenir; kopyala
yapıştır engellenir. Cümle uykulu bir kullanıcı için yeterince uğraştırıcı,
uyanık biri için birkaç saniyelik olmalı.

Onay metni bir sonraki seferi haber verir:

> Alarmı görevi yapmadan kapatıyorsun. **Bir dahaki sefere çıkış daha zor
> olacak.**

Tavana gelindiğinde metin bunu da söyler ("çıkış artık en zor kademede"),
böylece kullanıcı sonsuza kadar zorlaşacağını sanıp paniklemez.
5. **Görev kapalıyken zincir yok** (D6). Özelliği açmayan kullanıcı bu
   mekanizmanın hiçbir parçasına maruz kalmaz.

## 8. Test

**Birim (Dart, cihaz gerektirmez)**
- Zincir sınırları: `maxRearms` ve `chainDeadline` ayrı ayrı ve birlikte durdurur
- Görev süresi: `grace` dolunca alarm döner; `beginMission` sayacı
  `missionTimeout`'a taşır; arka plana düşmek sayacı durdurmaz
- Erteleme sayacı: limit dolunca erteleme kapanır; görev açıkken `null`
  seçilemez, `5`'e düşer
- Acil çıkış kademesi: her kullanımda artar, `abortMaxLevel`'da durur,
  `abortDecayDays` sonra bir azalır, sıfırın altına inmez
- Oturum yaşam döngüsü: tamamlama ve acil çıkış defteri temizler
- Görev tamamlanma koşulları (matematik doğrulama, sallama sayacı)

**Widget**
- Görev ekranı: her üç tip için tamamlanma callback'i
- Erteleme düğmesi limit dolunca kaybolur
- Acil çıkış 3 sn basılı tutmadan tetiklenmez

**Cihaz (manuel, kontrol listesi)**
- `stopIntent` sonrası uygulama görev ekranında açılıyor
- Görev tamamlanınca zincir tamamen susuyor, artık alarm gelmiyor
- Uygulama force-quit edilse bile nöbetçi çalıyor
- Sağlama merdiveni, `stopIntent` çalışmayan senaryoda devreye giriyor
  (alarm kilitsiz ekranda çalıp kullanıcı cihazı kullanırken kapatıldığında)
- `maxRearms` dolduğunda zincir kendiliğinden duruyor

Cihaz testi imzalı build gerektirir (M3). Simülatörde App Intent çalışmadığı
için `stopIntent`'e dokunan hiçbir davranış simülatörde doğrulanamaz.

## 9. Riskler

| Risk | Etki | Karşılık |
|---|---|---|
| Zincir bug'ı telefonu susturmaz | Yüksek — kullanıcı uygulamayı silmek zorunda kalır | §7'deki çift sınır, defter, acil çıkış |
| App Store incelemesi | Kolay kapatılamayan alarm dikkat çekebilir | Acil çıkışın varlığı ve görünürlüğü; inceleme notunda açıklama |
| `stopIntent` boşlukları | Kapı delinir | Sağlama merdiveni (§5.2) |
| Yeni bağımlılıklar (QR, sensör) | Bakım yükü, saldırı yüzeyi | Görev tipleri ayrı ayrı eklenebilir; matematik hiç bağımlılık istemiyor, önce o gelir |
| Pil | Zincir çok sık alarm kurarsa | Her tekrarda tek alarm kurulur, sıklığı `grace` ve `missionTimeout` belirler; merdiven yalnızca 3 basamak. Değerler §5.6'da tek yerde, ölçümle düşürülebilir |

## 10. Sıralama

Görev tipleri birbirinden bağımsız; altyapı bir kez oturunca her biri küçük
bir ek. Önerilen sıra:

1. Altyapı + **matematik** — hiç yeni bağımlılık istemez, zinciri en ucuz
   şekilde uçtan uca doğrular
2. **Sallama** — sensör bağımlılığı, orta iş
3. **QR** — kamera izni, kod kaydetme akışı, en fazla iş

## 11. Açık konular

- §5.6'daki sabitlerin tamamı cihazda ölçülüp kesinleştirilecek. Özellikle
  `graceSeconds`: kullanıcının alarmı durdurup uygulamanın açılmasını beklediği
  gerçek süre ölçülmeden seçilemez. AlarmK'in listelemesindeki "~10 saniye" bir
  referans noktası, doğrulanmadı
- Acil çıkışta yazdırılacak cümlelerin metni ve uzunluğu. Uykulu birini
  uğraştıracak kadar uzun, uyanık birini bunaltmayacak kadar kısa olmalı;
  kalibrasyon gerektiriyor
- Sallama ve QR için paket seçimi (`sensors_plus`, `mobile_scanner`) ayrı
  değerlendirilecek; bakım durumu ve lisans kontrolü yapılmadan eklenmez

## 12. İlgili, kapsam dışı düzeltmeler

Spike sırasında ortaya çıkan, bu spec'e dahil olmayan gerçek hatalar:

- `AppDelegate.swift:110` — `AlarmButton(text: "Kapat", …)` ve `stopButton`'lu
  **deprecated** init. iOS 26.1+ bunu tamamen yok sayıyor; ölü kod
- Repoda hiç ses dosyası yok (`res/raw/` boş, bundle'da `adhan.*` yok).
  Kullanıcı "Ezan" seçiyor, her iki platform da sistem varsayılanına düşüyor
- `lib/core/theme/theme_controller.dart:85` — `setPlatformBrightness` build
  sırasında `notifyListeners()` çağırıyor, ilk karede assertion fırlıyor
- Saat seçici Material dialog'u İngilizce ("Select time / Cancel / OK")
