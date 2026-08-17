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
| D9 | Acil çıkış | Görev ekranında **3 sn basılı tutma + onay** ile "Alarmı tamamen kapat" | Hiç çıkışı olmayan alarm hem güvenlik hem App Store riski. Basılı tutma, uykulu bir parmağın kazayla basmasını engelleyecek kadar bilinçli bir hareket |
| D10 | Kurulan alarmların kaydı | Zincirin kurduğu **her** alarm id'si kalıcı deftere yazılır | Spike'ta rastgele UUID kullandığım için kurduğum alarmları iptal edemedim, uygulamayı silmek zorunda kaldık. Kaydedilmeyen alarm iptal edilemez |
| D11 | Zincir mantığı nerede çalışır | **Swift tarafında** | Kullanıcı uygulamayı hiç açmayabilir; Dart o zaman çalışmaz. `stopIntent` ise Flutter engine olmadan da çalışır |
| D12 | Native → Dart haberleşmesi | `stopIntent` olayı UserDefaults'taki kuyruğa yazar; uygulama öne gelince Dart kuyruğu tüketir | Intent anında Flutter engine ayakta olmayabilir. Kuyruk, olayın kaybolmamasını garanti eder |
| D13 | Görev süresi nasıl işler | **Sabit sayaç değil, yenilenen kira.** Görev ekranı etkileşimdeyken uygulama kirayı ileri atar; bırakılınca kira dolar ve alarm döner | Sabit süre kullanıcıyı haksız cezalandırır: zor soru, kamera odaklanmaz, banyoya yürümek uzun sürer. Kira modelinde görevle uğraşan kullanıcıya alarm hiç dönmez, bırakan kullanıcıya hemen döner. Yakalanmak istenen davranış tam olarak "bıraktı" |
| D14 | Kira süreleri kimin ayarı | **Bizim.** Tek bir yapılandırma dosyasında sabit; kullanıcı arayüzünde görünmez | Doğru değerler ölçümle bulunur, kullanıcının bilebileceği bir şey değil. Ayarlanabilir tutulmasının sebebi kalibrasyon, kişiselleştirme değil |
| D15 | Erteleme ayarları kimin | **Kullanıcının**, ama kapalı seçenek listesinden. Süre: bugünkü `5/10/15/20 dk`. Sayı: `1/2/3/5` ve görev kapalıysa ayrıca `Sınırsız` | Serbest metin alanı anlamsız değerlere ve kenar durumlara açık. Görev açıkken sınırsız erteleme kapıyı işlevsiz bırakırdı — kullanıcı görevi hiç yapmadan sonsuza kadar erteleyebilirdi |
| D16 | Tek çalışta çalma süresi | Kullanıcıya **sunulmaz**. Alarm kapatılana kadar çalar | iOS kısıtı (D1). Sunulup çalışmayan bir ayar, olmayan ayardan kötüdür |

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
         Uygulama görev ekranını gösterir
         ↓ ekran etkileşimdeyken, her renew saniyede bir:
           nöbetçi alarm now+lease'e ötelenir      ← kira yenileme (D13)
         ↓ görev tamamlanır
         Dart: defterdeki tüm alarmları iptal eder, oturumu kapatır
```

**Kira modeli (D13).** Nöbetçi alarm sabit bir "görevi şu kadar sürede bitir"
sayacı değil, sürekli ötelenen bir son tarihtir:

| Durum | Sonuç |
|---|---|
| Durdurdu, uygulamayı hiç açmadı | `grace` dolar, alarm döner |
| Görev ekranında, uğraşıyor | Kira yenilenir, alarm **dönmez** — görev ne kadar sürerse sürsün |
| Uygulamayı arka plana attı / kapattı / telefonu bıraktı | Yenileme durur, `lease` dolar, alarm döner |

Yakalanmak istenen davranış "görevi yavaş yaptı" değil, **"bıraktı"**.

Yenileme yalnızca görev ekranı ön plandayken yapılır. Uygulama arka plana
düştüğü anda yenileme durur; kalan kira kadar sonra alarm döner.

QR görevinde kullanıcı telefonu elinde tutup banyoya yürürken kamera ekranı ön
plandadır, yani kira yenilenmeye devam eder. İstenen davranış budur.

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
  "leaseSeconds":  30,             // gorev ekrani acikken kira
  "leaseExpiry":   <epoch ms>,     // yenileme bunu ileri atar
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
| `chainConfig` | `Map?` | §5.6'daki sabitler: `grace`, `lease`, `renew`, `maxRearms`, `chainDeadline`, `ladderStep`, `ladderCount` |

Yeni method'lar:

| Method | Yön | İş |
|---|---|---|
| `consumeMissionEvents` | Dart → native | Kuyruğu okuyup temizler, olay listesi döner |
| `renewMissionLease` | Dart → native | Kirayı `now + leaseSeconds`'e öteler, nöbetçi alarmı yeniden kurar (D13) |
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

Kira ve zincir değerleri tek bir dosyada toplanır (`lib/core/config/
mission_tuning.dart`) ve `chainConfig` ile native'e geçer. **Ayarlar ekranında
görünmezler** (D14) — burada ayarlanabilir olmalarının sebebi ölçümle kalibre
edebilmek, kullanıcıya seçenek sunmak değil.

| Sabit | Başlangıç | Anlamı |
|---|---|---|
| `graceSeconds` | 20 | Durdurdu ama uygulamayı açmadı; alarmın dönmesi için beklenen süre |
| `leaseSeconds` | 30 | Görev ekranı ön plandayken kiranın uzunluğu |
| `renewSeconds` | 10 | Kiranın hangi sıklıkla ötelendiği. `leaseSeconds`'ten belirgin küçük olmalı, yoksa yenileme gecikmesi alarmı tetikler |
| `ladderStepMinutes` | 5 | Sağlama merdiveni adımı (§5.2) |
| `ladderCount` | 3 | Merdiven basamak sayısı |
| `maxRearms` | 40 | Zincirin sert tekrar tavanı (§7) |
| `chainDeadlineMinutes` | 60 | Zincirin sert süre tavanı (§7) |

Başlangıç değerleri tahmindir; cihazda ölçülüp kesinleştirilecek (§11).
`renewSeconds < leaseSeconds` bağıntısı zorunludur ve testle korunur.

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

## 7. Güvenlik sınırları

Bunlar kabul kriteridir, opsiyonel değil. Gerekçesi spike'ta yaşanan kaza:
ispat alarmına da `stopIntent` bağlanınca her kapatış yenisini doğurdu ve
telefonu susturmanın tek yolu uygulamayı silmek oldu.

1. **Tek doğuş noktası.** Yeni alarm yalnızca zincir mantığından kurulur.
   `stopIntent` dışında hiçbir yol nöbetçi kurmaz.
2. **Çift sınır.** `rearmCount >= maxRearms` **veya** `now >= chainDeadline`
   olduğunda zincir durur ve oturum kapanır. Varsayılanlar: 40 tekrar, 60 dk.
3. **Defter zorunlu.** Kurulan her alarm, kurulduğu anda deftere yazılır;
   iptal defter üzerinden yürür. Deftere yazılamayan alarm kurulmaz.
4. **Acil çıkış her zaman erişilebilir** (D9). Görev çözülemese bile kullanıcı
   alarmdan çıkabilir. Kabul kriterleri:
   - Görev ekranında **her zaman görünür** — belirli sayıda başarısızlıktan
     sonra açılan gizli bir yol değil. Kamera bozulduysa ya da kod
     kaybolduysa kullanıcı kilitlenmiş olmamalı
   - **3 sn basılı tutma + onay** ile tetiklenir. Uykulu bir parmağın kazayla
     basmasını engelleyecek kadar bilinçli, panik anında ulaşılamayacak kadar
     zor değil
   - `abortMission` çağırır: zincirdeki **tüm** alarmlar iptal edilir, oturum
     kapanır. `completeMission` ile aynı temizlik
   - Görevden bağımsız çalışır: görev kodu çökse, izin reddedilse, sensör
     yanıt vermese bile çıkış yolu ayakta kalır
5. **Görev kapalıyken zincir yok** (D6). Özelliği açmayan kullanıcı bu
   mekanizmanın hiçbir parçasına maruz kalmaz.

## 8. Test

**Birim (Dart, cihaz gerektirmez)**
- Zincir sınırları: `maxRearms` ve `chainDeadline` ayrı ayrı ve birlikte durdurur
- Kira: yenileme geldikçe son tarih ötelenir; yenileme kesilince dolar
- `renewSeconds < leaseSeconds` bağıntısı korunur (sabitler testle doğrulanır)
- Erteleme sayacı: limit dolunca erteleme kapanır; görev açıkken `null`
  seçilemez, `5`'e düşer
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
| Pil | Zincir çok sık alarm kurarsa | Kira yenilemesi alarmı yeniden kurar, sıklığı `renewSeconds` belirler; merdiven yalnızca 3 basamak. Değerler §5.6'da tek yerde, ölçümle düşürülebilir |

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
- Uygulama arka plana düştüğünde kiranın hemen mi dolması yoksa kalan süreyi mi
  kullanması gerektiği: spec kalan süreyi kullanıyor. Kullanıcı yanlışlıkla ana
  ekrana çıkarsa geri dönmek için birkaç saniyesi olur; doğru seçim cihazda
  denenecek
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
