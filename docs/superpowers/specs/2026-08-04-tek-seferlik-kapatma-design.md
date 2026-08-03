# Tek Seferlik Kapatma — Tasarım Spec'i

Ana ekrandaki **SIRADAKİ** kartında gösterilen bildirim ve alarmın, o tek
seferliğine atlanabilmesi.

## 1. Sorun

Kart bugün "sıradaki bildirim" ve "sıradaki alarm" satırlarını gösteriyor ama
kullanıcı yalnızca bakabiliyor. Bir kereliğine (toplantı var, uyumak istiyor)
susturmak isterse tek yolu Bildirimler/Alarmlar ekranına girip **kalıcı**
kapatmak — sonra da geri açmayı hatırlamak zorunda.

Alarm satırındaki mevcut anahtar bugün `AlarmsManager.setActive` çağırıyor,
yani kalıcı kapatıyor. Bu, kartın bağlamına (şu an sırada olan tek örnek)
aykırı ve kullanıcıyı yanıltıyor.

## 2. Kapsam

**Bu turda:**
- Kartta bir bildirim + bir alarm satırı (bugünkü gibi).
- Her satırda tek seferlik kapatma anahtarı.
- Atlama kaydının kalıcı saklanması ve planlamaya yansıması.

**Kapsam dışı:**
- Kartta ikiden fazla satır.
- "Bugünün tamamını sustur" / sessiz saatler.
- Bildirimler ve Alarmlar ekranlarının davranışı — oradaki anahtarlar
  **kalıcı** kapatmaya devam eder, dokunulmaz.

## 3. Alınan kararlar

| # | Konu | Karar | Gerekçe |
|---|---|---|---|
| D1 | Atlamanın kapsamı | **Yalnızca o tek örnek.** Yarınki İmsak bildirimi atlanırsa öbür gün normal çalar. | "Tek seferlik" ifadesinin en dar ve öngörülebilir okuması; saklanacak durum da en küçüğü. |
| D2 | Atladıktan sonra kart | **Satır yerinde kalır**, bir sonrakine geçmez. | Kullanıcı fikrini değiştirip geri açabilsin. Kart bir sonrakine atlasaydı geri alma yolu kalmazdı. |
| D3 | Kullanıcıya bildirme | Kapalıyken **alt metin değişir**: `Yalnızca bu sefer atlanacak · 04:02` | Hem kapatma anında görünür hem kapalı kaldığı sürece açıklamaya devam eder. Snackbar ya da sürekli duran yardım metni ana ekranı yeniden kalabalıklaştırırdı. |
| D4 | Kalan süre | Sağdan alt metne taşınır: `Tam vaktinde · 04:02 · 4s 54dk` | Sağ taraf tek işlevli (aç/kapa) olur, iki satır aynı iskelete oturur, bilgi kaybolmaz. |
| D5 | Saklama | `settings` tablosunda tek satır, JSON liste | Aynı anda en fazla iki canlı kayıt var. Yeni tablo + şema migration (v6→v7) bu hacim için orantısız risk. |
| D6 | Ömür | Örneğin zamanı geçince kayıt ölür; yüklemede temizlenir | Kullanıcının ayrıca "geri aç" demesi gerekmez; ertesi gün kendiliğinden normale döner. |

## 4. Davranış

### 4.1 Bildirim satırı

| Durum | Alt metin | Sağ |
|---|---|---|
| Normal | `Tam vaktinde · 04:02 · 4s 54dk` | anahtar **açık** |
| Atlanmış | `Yalnızca bu sefer atlanacak · 04:02` | anahtar **kapalı** |

Sapmalı bildirimde ilk parça `15 dk önce` olur.

### 4.2 Alarm satırı

| Durum | Alt metin | Sağ |
|---|---|---|
| Normal | `İmsak −30 dk · yarın 03:43` | anahtar **açık** |
| Atlanmış | `Yalnızca bu sefer atlanacak · yarın 03:43` | anahtar **kapalı** |

Başlık her iki durumda da alarmın etiketi (`Sahur`).

### 4.3 Etkileşim

- Anahtar **kapatılınca**: atlama kaydı yazılır, bildirimler ve alarmlar
  yeniden planlanır, satır yerinde kalır.
- Anahtar **açılınca**: kayıt silinir, yeniden planlanır, satır normale döner.
- Örneğin zamanı geçince: kayıt temizlenir, kart bir sonraki örneği gösterir,
  anahtar açık gelir.

### 4.4 Kalıcı kapatmayla ilişkisi

Bildirimler/Alarmlar ekranından kapatmak bugünkü gibi kalıcıdır. Kalıcı kapalı
bir bildirim/alarm zaten "sıradaki" olamaz, dolayısıyla kartta görünmez ve iki
mekanizma çakışmaz.

## 5. Mimari

### 5.1 Model

```dart
enum SkipKind { notification, alarm }

/// Tek bir örneğin atlanması.
///
/// [reference] bildirim için NotificationScheduler'ın ürettiği kimlik
/// (gün · vakit · offset), alarm için alarmın kendi id'si. [fireAt] ile
/// birlikte tek bir örneği işaret eder: aynı alarmın farklı günleri ayrı
/// kayıtlardır.
class SkippedOccurrence {
  final SkipKind kind;
  final String reference;
  final DateTime fireAt;
}
```

Kimlik = `kind + reference + fireAt`.

### 5.2 Saklama

`LocalStorage`'a iki metot eklenir:

```dart
Future<List<SkippedOccurrence>> getSkippedOccurrences();
Future<void> saveSkippedOccurrences(List<SkippedOccurrence> occurrences);
```

`SqliteStorage` bunları `settings` tablosunda tek anahtarda (`skipped_occurrences`)
JSON liste olarak tutar — `AppearanceSettings`'in kullandığı desenin aynısı,
şema değişikliği yok.

> **Maliyet.** `LocalStorage` bir arayüz ve testlerde **11 sahte sınıf**
> uyguluyor (`test/support/fakes.dart` + 10 test dosyası). İki yeni metot
> hepsine eklenmeli. Alternatif — arayüze dokunmayıp `SkipManager`'ı doğrudan
> `SqliteStorage`'a bağlamak — sahteleri kurtarırdı ama testleri gerçek
> veritabanına bağlardı; kabul edilmedi. Ekleme mekanik ve derleyici hepsini
> gösterecek.

### 5.3 Yönetim

`SkipManager` (yeni, `lib/features/notifications/domain/`):

```dart
Future<Set<SkippedOccurrence>> load();       // süresi geçenleri eleyerek
Future<void> skip(SkippedOccurrence occurrence);
Future<void> unskip(SkippedOccurrence occurrence);
Future<void> purgeExpired(DateTime now);     // load() bunu kendi çağırır
```

Saf yardımcı (`skip_rules.dart`), test edilebilir olsun diye ayrı:

```dart
bool isSkipped(Set<SkippedOccurrence> skips, SkipKind kind, String reference,
    DateTime fireAt);
List<SkippedOccurrence> withoutExpired(List<SkippedOccurrence> skips,
    DateTime now);
```

### 5.4 Planlamaya etkisi

**Bildirim** — `NotificationScheduler.scheduleNotifications` aday listesini
kurarken atlanmışları eler. Kimlik zaten `_generateNotificationId(date,
prayerType, minutesBefore)` ile üretiliyor; aynı kimlik `reference` olarak
kullanılır, `fireAt` de adayın `notificationTime`'ı. Diğer günler etkilenmez.

**Alarm** — `AlarmScheduler.computeNextFire` imzası `Set<SkippedOccurrence>
skips` alacak şekilde genişler (varsayılan boş küme, mevcut çağıranlar
bozulmaz) ve atlanmış çalma anını geçip bir sonrakini döner. Böylece yarın
atlanan Sahur, öbür gün normal çalar.

**Kart** — `resolveNextNotification` / `resolveNextAlarm` atlanmışları
**dışlamaz**; D2 gereği satır yerinde kalmalı. Atlanmış olup olmadığı UI'a ayrı
bir bayrak olarak geçer.

> **Dikkat — iki çağıran, iki farklı davranış.** `resolveNextAlarm` da
> `computeNextFire` kullanıyor. Skip kümesi oraya da geçirilirse kart atlanan
> alarmı atlayıp bir sonrakini gösterir ve D2 bozulur; kullanıcının geri açma
> yolu kalmaz. Kural: **`scheduleAlarms` skip'leri geçirir, `resolveNextAlarm`
> geçirmez.** Bu ayrım bir testle korunacak.

### 5.5 Veri akışı

```
HomePage._loadPrayerData
  └─ SkipManager.load()  →  AppState.setSkips(...)
HomeScreen
  └─ UpcomingCard(notification:, alarm:, skips:, onSkipChanged:)
HomePage._toggleSkip(kind, reference, fireAt, skipped)
  ├─ SkipManager.skip() / unskip()
  ├─ AppState.setSkips(...)
  └─ NotificationScheduler + AlarmScheduler yeniden planlar
```

`AppState` yeni bir alan taşır: `Set<SkippedOccurrence> skips`.

## 6. Hata ve kenar durumlar

| Durum | Davranış |
|---|---|
| Atlanan örneğin zamanı geçti | Kayıt `load()` sırasında elenir; kart bir sonrakini gösterir, anahtar açık |
| Kullanıcı atlayıp uygulamayı kapattı | Kayıt kalıcı; alarm çalmaz |
| Aynı alarm iki gün üst üste atlanmak istenirse | İki ayrı kayıt (`fireAt` farklı); biri diğerini etkilemez |
| Kalıcı kapatılan bir alarm atlanmışken | Atlama kaydı ortada kalır ama zararsız; süresi dolunca temizlenir |
| Bozuk JSON | Boş liste kabul edilir, uygulama atlamasız açılır (bkz. `AppearanceSettings.fromMap` deseni) |
| Vakit verisi yeniden çekildi ve saat kaydı | `fireAt` değişirse eski kayıt eşleşmez, bildirim/alarm çalar. Kabul edildi: alternatifi (gün+vakit bazlı eşleşme) sapması değişen alarmlarda yanlış örneği atlardı |

## 7. Test stratejisi

**Saf (`test/notifications/skip_rules_test.dart`):**
- `isSkipped`: kimliğin üç alanının da eşleşmesi; farklı `fireAt` eşleşmemesi.
- `withoutExpired`: geçmiş kayıtların elenmesi, gelecektekilerin kalması.

**Depo (`test/notifications/skip_manager_test.dart`, mevcut sahtelerle):**
- `skip` → `load` turunda kaydın geri gelmesi.
- `unskip` → kaydın gitmesi.
- Bozuk JSON'da boş liste.

**Planlama:**
- `NotificationScheduler`: atlanmış kimliğin planlanmaması, diğer günlerin
  etkilenmemesi.
- `AlarmScheduler.computeNextFire`: atlanmış çalma anını geçip bir sonrakini
  bulması; art arda iki atlamada üçüncüyü bulması.

**Ayrım koruması:**
- `resolveNextAlarm` atlanmış alarmı **döndürmeye devam eder** (kart onu
  gösterebilsin); `scheduleAlarms` ise **planlamaz**. Aynı senaryoda iki ayrı
  beklenti.

**Widget (`test/widgets/home/upcoming_card_test.dart`):**
- Atlanmışken alt metnin `Yalnızca bu sefer atlanacak · …` olması ve anahtarın
  kapalı gelmesi.
- Anahtarın `onSkipChanged`'i doğru argümanlarla çağırması.
- Atlanmış satırın kartta kalması (bir sonrakine geçmemesi).

## 8. Uygulamadan önce doğrulanacaklar

| # | Varsayım | Doğrulama |
|---|---|---|
| V1 | `settings` tablosunda JSON liste tutmak mevcut desenle uyumlu | `AppearanceSettings` aynı tabloyu anahtar-değer olarak kullanıyor; tek fark değerin JSON olması |
| V2 | `computeNextFire`'a `skips` eklemek mevcut çağıranları bozmaz | **Doğrulandı:** üretimde iki çağıran (`scheduleAlarms`, `resolveNextAlarm`), testlerde 6 çağrı. Varsayılan boş küme hepsini korur |
| V4 | `LocalStorage`'ı uygulayan sahte sayısı | **Doğrulandı:** 11 sınıf (`grep -rl "implements LocalStorage" test/`) |
| V3 | Kart satırı iki satırlık alt metinle 62px'e sığar | `Yalnızca bu sefer atlanacak · yarın 03:43` tek satır, `ellipsis` zaten var |
