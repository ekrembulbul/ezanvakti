# Konum Algılama ve Veri Yükleme Akışı — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uygulama açıldıktan birkaç saniye sonra GPS "konum değişti" deyip ekrandaki vakitleri tam ekran spinner ile değiştirmesin; veri yenilemesi ekranı boşaltmadan yerinde olsun.

**Architecture:** Dört bağımsız düzeltme, dördü de mevcut yapıyı koruyarak: (1) `LocationMonitorService` ilk GPS fix'ini kayıtlı koordinatla karşılaştırsın — bugün karşılaştıracak referansı olmadığı için her fix'i "önemli değişim" sayıyor; (2) önbellek, yeni veri gelmeden silinmesin — `PrayerTimesRepository`'nin `forceRefresh` + fallback yolu zaten bunu yapıyor, tek yapılacak erken `clearPrayerTimeCache` çağrısını kaldırmak; (3) soğuk açılıştaki iki ayrı ağ çağrısı tek aralık çağrısına insin; (4) tam ekran `LoadingState` yalnızca gösterilecek veri yokken çıksın, aksi halde üst çubukta ince bir gösterge dönsün.

**Tech Stack:** Flutter, `provider` (`AppState`), `geolocator`.

## Global Constraints

- İş `refactor/konum-ve-veri-yukleme` dalında. `push`/`merge` yok.
- Davranış değiştirmeyen yerlere dokunulmaz — özellikle `TomorrowStrip`'in görünürlük kuralı: **yarının vakti yalnızca Yatsı'dan sonra doldurulur.** Aksi halde şerit gün boyu görünür ve tasarım değişir.
- Kullanıcıya görünen yeni metin yok.
- Renk ve tipografi token'lardan gelir; `Colors.green`/`Colors.red` gibi sabitler kullanılmaz (0.3.0 kuralı).
- Her task sonunda `flutter test` yeşil ve `flutter analyze` temiz olmadan commit yok.

### Alınan kararlar

| # | Konu | Karar |
|---|---|---|
| K1 | Yenileme sırasında ekran | Stale-while-revalidate: eldeki vakitler kalır. Tam ekran `LoadingState` yalnızca gösterilecek veri yokken. Üst çubukta ince (2px) belirsiz ilerleme çizgisi. |
| K2 | GPS ilk fix | `startMonitoring` kayıtlı GPS konumunun koordinatını referans alır; 5 km / 30 dk kuralı ilk fix'ten itibaren işler. |
| K3 | Önbellek geçersizleştirme | Önce çek sonra değiştir. Konum değişiminde önbellek silinmez; yeni veri başarıyla gelince aynı günlerin üzerine yazılır, ağ yoksa eski veri kalır. |
| K4 | Soğuk açılış ağ çağrısı | Tek aralık çağrısı. Ayrı "bugün" isteği kaldırılır. |

### Ölçülen mevcut davranış (düzeltmeden önce)

- `location_monitor_service.dart:124` — `if (_lastPosition == null) return true;`. `_lastPosition` yalnızca bellekte; her açılışta `null`. `_lastUpdateTime` de `null` olduğu için 30 dakika kapısı da atlanır. Sonuç: **ilk fix her zaman "önemli değişim".**
- `location_monitor_service.dart:109` — `clearPrayerTimeCache(saved.id)` yeni veri çekilmeden çağrılır. O anda ağ yoksa kullanıcının elinde hiçbir şey kalmaz.
- `home_screen.dart:105` — `if (widget.isLoading) return const LoadingState();`. `_loadInitialData` her çağrıldığında `setLoading(true)` yaptığı için ekrandaki vakitler silinir.
- `data_loader_service.dart:42` + `home_page.dart:233` — soğuk açılışta `getDailyPrayerTime` (tek gün ucu) ve ardından `getPrayerTimes` (13 gün takvim ucu): iki ayrı ağ turu, ikincisi zaten birincisini kapsıyor.

---

## Dosya Yapısı

**Değiştirilecek:**

| Dosya | Değişiklik |
|---|---|
| `lib/features/location/domain/location_monitor_service.dart` | Koordinat referansını tohumla; erken önbellek silmeyi kaldır. |
| `lib/presentation/services/data_loader_service.dart` | `loadInitialData` + `loadBackgroundData` → tek `loadPrayerData`. |
| `lib/presentation/pages/home_page.dart` | Tek yükleme çağrısı; `forceRefresh` parametresi; iki aşamalı akışın kaldırılması; SnackBar renkleri. |
| `lib/core/providers/app_state.dart` | `isRefreshing` ayrımı. |
| `lib/presentation/screens/home_screen.dart` | Tam ekran yükleme koşulu; `isRefreshing` aktarımı. |
| `lib/presentation/widgets/home/home_top_bar.dart` | 2px belirsiz ilerleme çizgisi (layout kaydırmadan, `Stack` ile). |
| `lib/presentation/pages/app_root.dart` | İlk kontrol spinner'ı temalı zeminde. |

**Test:**

| Dosya | Kapsam |
|---|---|
| `test/location/location_monitor_service_test.dart` (yeni) | İlk fix'in tohumlanmış referansa göre değerlendirilmesi. |
| `test/widgets/screens/home_screen_loading_test.dart` (yeni) | Veri varken yenileme ekranı boşaltmıyor; veri yokken tam ekran yükleme. |
| `test/acceptance/mvp_acceptance_test.dart` | Konum değişiminde önbelleğin korunduğu senaryo eklenir. |

---

## Task 1: GPS ilk fix'i kayıtlı koordinatla karşılaştır

**Files:**
- Modify: `lib/features/location/domain/location_monitor_service.dart`
- Test: `test/location/location_monitor_service_test.dart` (yeni)

**Interfaces:**
- Consumes: `LocationRepository.getGpsLocation()` → `Location?` (`latitude`/`longitude` alanları `double?`).
- Produces: `LocationMonitorService.debugShouldUpdate(...)` gibi yeni public API **yok**; test, servisi `startMonitoring` üzerinden değil, saf karar fonksiyonu üzerinden sürer (aşağıya bak).

**Yaklaşım.** `_lastPosition` bir `Position` nesnesi tutuyor ama yalnızca `latitude`/`longitude` alanları kullanılıyor. Kayıtlı konumdan sahte bir `Position` üretmek yerine alan iki `double?`'a indirilir; böylece hem tohumlama kolaylaşır hem de karar mantığı `geolocator`'dan bağımsız, saf ve test edilebilir bir fonksiyona çıkar.

- [ ] **Step 1: Saf karar fonksiyonu için başarısız test yaz**

`test/location/location_monitor_service_test.dart`:

```dart
import 'package:ezanvakti/features/location/domain/location_monitor_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uygulama her acildiginda GPS akisindan ilk fix gelir. Referans koordinat
/// kayitli konumdan tohumlandigi icin, kullanici gercekten tasinmadikca bu fix
/// "onemli degisim" sayilmamalidir.
void main() {
  const istanbul = (latitude: 41.008, longitude: 28.978);
  final now = DateTime(2026, 8, 3, 12);

  test('Referans yokken ilk fix onemli sayilir', () {
    expect(
      isSignificantLocationChange(
        previous: null,
        current: istanbul,
        lastUpdate: null,
        now: now,
      ),
      isTrue,
    );
  });

  test('Ayni yerdeki ilk fix onemli sayilmaz', () {
    // 50 metre sapma: GPS gurultusu, tasinma degil.
    const nearby = (latitude: 41.0084, longitude: 28.9785);

    expect(
      isSignificantLocationChange(
        previous: istanbul,
        current: nearby,
        lastUpdate: null,
        now: now,
      ),
      isFalse,
    );
  });

  test('Bes kilometreden uzak fix onemli sayilir', () {
    // ~11 km kuzey.
    const faraway = (latitude: 41.108, longitude: 28.978);

    expect(
      isSignificantLocationChange(
        previous: istanbul,
        current: faraway,
        lastUpdate: null,
        now: now,
      ),
      isTrue,
    );
  });

  test('Son guncellemeden bu yana 30 dakika gecmediyse onemli sayilmaz', () {
    const faraway = (latitude: 41.108, longitude: 28.978);

    expect(
      isSignificantLocationChange(
        previous: istanbul,
        current: faraway,
        lastUpdate: now.subtract(const Duration(minutes: 5)),
        now: now,
      ),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Testi çalıştır, kırmızıyı gör**

```bash
flutter test test/location/location_monitor_service_test.dart
```

Beklenen: derleme hatası — `isSignificantLocationChange` tanımlı değil.

- [ ] **Step 3: Karar fonksiyonunu ve tohumlamayı yaz**

`lib/features/location/domain/location_monitor_service.dart`:

Dosyanın üstüne (sınıfın dışına) tip takma adı ve saf fonksiyon:

```dart
/// GPS karsilastirmasi icin gereken tek sey koordinat; `Position`'in kalan
/// alanlari kullanilmadigi icin karar mantigi geolocator'dan bagimsiz tutulur.
typedef Coordinates = ({double latitude, double longitude});

/// Kullanici gercekten tasindi mi?
///
/// [previous] `null` ise karsilastiracak referans yok demektir — yalnizca hic
/// GPS konumu kaydedilmemisken olur, o zaman ilk fix kabul edilir. Uygulama
/// acilisinda referans kayitli konumdan tohumlandigi icin sıradan bir acilis
/// bu yoldan gecmez.
bool isSignificantLocationChange({
  required Coordinates? previous,
  required Coordinates current,
  required DateTime? lastUpdate,
  required DateTime now,
}) {
  if (previous == null) return true;

  if (lastUpdate != null &&
      now.difference(lastUpdate) < kMinLocationUpdateInterval) {
    return false;
  }

  final distance = Geolocator.distanceBetween(
    previous.latitude,
    previous.longitude,
    current.latitude,
    current.longitude,
  );
  return distance >= kSignificantDistanceMeters;
}

/// Bu mesafeden kisa hareketler sehir degisimi sayilmaz.
const double kSignificantDistanceMeters = 5000;

/// Ard arda gelen fix'lerde en fazla bu sıklıkta guncelleme yapilir.
const Duration kMinLocationUpdateInterval = Duration(minutes: 30);
```

Sınıf içinde `_lastPosition`/`_significantDistanceMeters`/`_minUpdateInterval` yerine:

```dart
  Coordinates? _lastCoordinates;
  DateTime? _lastUpdateTime;
```

`startMonitoring` içinde, `gpsLocation` alındıktan hemen sonra (mevcut `if (gpsLocation == null) return;` kontrolünün altına):

```dart
      // Referansi kayitli konumdan tohumla. Aksi halde acilistaki ilk fix
      // karsilastiracak bir sey bulamayip her zaman "onemli degisim" sayilir;
      // kullanici yerinden kimildamasa bile onbellek yenilenir ve ekran
      // yeniden yuklenir.
      final latitude = gpsLocation.latitude;
      final longitude = gpsLocation.longitude;
      if (latitude != null && longitude != null) {
        _lastCoordinates = (latitude: latitude, longitude: longitude);
      }
```

`_shouldUpdate` metodu silinir; `_onPositionChanged` içindeki çağrı şuna dönüşür:

```dart
      final current = (
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!isSignificantLocationChange(
        previous: _lastCoordinates,
        current: current,
        lastUpdate: _lastUpdateTime,
        now: DateTime.now(),
      )) {
        return;
      }
```

`_lastPosition = position;` atamalarının hepsi `_lastCoordinates = current;` olur (iki yerde: etiket değişmediğinde erken dönüşte ve güncelleme sonrasında).

- [ ] **Step 4: Testler geçiyor mu**

```bash
flutter test test/location/location_monitor_service_test.dart
flutter analyze
```

Beklenen: 4 test geçer, analiz temiz. `Geolocator` import'u zaten dosyada var.

- [ ] **Step 5: Mevcut monitor testleri hâlâ geçiyor mu**

```bash
flutter test test/location/
```

Beklenen: `location_monitor_controller_test.dart` dahil hepsi yeşil.

- [ ] **Step 6: Commit**

```bash
git add lib/features/location/domain/location_monitor_service.dart \
  test/location/location_monitor_service_test.dart
git commit -m "fix: acilistaki ilk GPS fix'i konum degisimi saymasin"
```

---

## Task 2: Önbelleği yeni veri gelmeden silme

**Files:**
- Modify: `lib/features/location/domain/location_monitor_service.dart`
- Test: `test/acceptance/mvp_acceptance_test.dart`

**Interfaces:**
- Consumes: `PrayerTimesRepository.getPrayerTimes(..., forceRefresh: true)` — ağ başarısız olursa önbelleğe düşer (`prayer_times_repository.dart:61-77`), başarılıysa aynı günlerin üzerine yazar.
- Produces: Yeni API yok. `LocationMonitorService` artık önbelleğe dokunmaz.

**Neden silmek yanlış.** `clearPrayerTimeCache` yeni veri çekilmeden çağrılıyor. Ardından gelen yükleme ağ hatası alırsa repository'nin fallback'i boş önbellek bulur ve hatayı yukarı fırlatır — kullanıcı elindeki (biraz eski, biraz yanlış konumlu) vakitleri de kaybeder. `forceRefresh: true` ile çekmek aynı işi güvenli sırayla yapar: başarılıysa üzerine yazılır, başarısızsa eski veri yerinde kalır.

**Kabul edilen ödün.** Yeni pencerenin (bugün−2 … bugün+10) dışındaki günler eski konumun verisiyle kalır. Pencere zaten bildirim planlama ufkunu (7 gün) kapsıyor; sonraki yenilemelerde kayan pencere bu günleri de tazeler.

- [ ] **Step 1: Kabul testine senaryo ekle (başarısız olacak)**

`test/acceptance/mvp_acceptance_test.dart` içindeki `'MVP kabul — konum degisimi'` grubuna:

```dart
    test('Ag yokken konum degisimi eldeki vakitleri silmiyor', () async {
      final stack = buildStack();
      await stack.storage.init();
      await stack.storage.saveActiveLocation(istanbul);

      final today = _atMidnight(DateTime.now());
      final end = today.add(const Duration(days: 6));

      await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: end,
      );

      // Konum degisti ama ag yok: yeni veri gelmedigi icin eskisi kalmali.
      stack.provider.failWith = NetworkException('Baglanti yok');
      final afterChange = await stack.prayerTimes.getPrayerTimes(
        location: istanbul,
        startDate: today,
        endDate: end,
        forceRefresh: true,
      );

      expect(
        afterChange,
        hasLength(7),
        reason: 'Onbellek yeni veri gelmeden silinmemeli',
      );
    });
```

- [ ] **Step 2: Testi çalıştır**

```bash
flutter test test/acceptance/mvp_acceptance_test.dart
```

Beklenen: **geçer** — repository'nin fallback'i zaten doğru çalışıyor. Bu test, Step 3'teki değişikliğin regresyona uğramasını engelleyen kapıdır; kırmızı görmek beklenmez. Geçmezse dur ve raporla: varsayım yanlış demektir.

- [ ] **Step 3: Erken önbellek silmeyi kaldır**

`lib/features/location/domain/location_monitor_service.dart` içinde şu blok silinir:

```dart
        // Konum değişti: eski koordinata ait önbellek vakitleri artık geçersiz.
        // Temizlenir ki dinleyen taraf yeniden yüklerken yeni koordinatla taze
        // veri çeksin (cache location_id ile anahtarlı, koordinatla değil).
        await locationRepository.clearPrayerTimeCache(saved.id);
```

Yerine, `_locationChangeController.add(saved);` satırının üstüne açıklama:

```dart
        // Onbellek burada SILINMEZ. Dinleyen taraf (HomePage) yuklemeyi
        // forceRefresh ile yapar: yeni veri basariyla gelirse ayni gunlerin
        // uzerine yazilir, ag yoksa eski veri yerinde kalir. Once silmek,
        // ag hatasinda kullaniciyi verisiz birakiyordu.
```

- [ ] **Step 4: Doğrula**

```bash
flutter test
flutter analyze
```

Beklenen: hepsi yeşil. `clearPrayerTimeCache` başka çağıranları (konum düzenleme, hesaplama ayarı) olduğu için metot silinmez.

- [ ] **Step 5: Commit**

```bash
git add lib/features/location/domain/location_monitor_service.dart \
  test/acceptance/mvp_acceptance_test.dart
git commit -m "fix: konum degisiminde onbellegi yeni veri gelmeden silme"
```

---

## Task 3: Tek aralık çağrısı

**Files:**
- Modify: `lib/presentation/services/data_loader_service.dart`
- Modify: `lib/presentation/pages/home_page.dart`

**Interfaces:**
- Produces: `DataLoaderService.loadPrayerData(Location location, {bool forceRefresh = false})` → `PrayerData` kaydı:
  ```dart
  typedef PrayerData = ({
    PrayerTime? today,
    PrayerTime? tomorrow,
    List<PrayerTime> all,
    DateTime? lastUpdate,
    bool hasPermission,
    List<NotificationSetting> settings,
  });
  ```
  `loadInitialData` ve `loadBackgroundData` kaldırılır; `HomePage` yalnızca bu metodu çağırır.

**Korunacak davranış.** `tomorrow`, **yalnızca şu an Yatsı'dan sonraysa** doldurulur. Aksi halde `HomeScreen`'deki `TomorrowStrip` gün boyu görünür ve tasarım değişir.

- [ ] **Step 1: `DataLoaderService`'i yeniden yaz**

`lib/presentation/services/data_loader_service.dart` içeriği:

```dart
import '../../core/interfaces/notification_service.dart';
import '../../core/models/location.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../core/utils/app_logger.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../features/prayer_times/domain/prayer_times_repository.dart';

/// Ana ekranin ihtiyac duydugu her sey tek yuklemede.
typedef PrayerData = ({
  PrayerTime? today,
  PrayerTime? tomorrow,
  List<PrayerTime> all,
  DateTime? lastUpdate,
  bool hasPermission,
  List<NotificationSetting> settings,
});

class DataLoaderService {
  /// Bugunden once cekilen gun sayisi. Gece yarisi/timezone kenar durumlari
  /// ve "dunun vakitleri" icin kucuk bir tampon.
  static const int _daysBefore = 2;

  /// Bugunden sonra cekilen gun sayisi. Bildirim planlama penceresini
  /// (NotificationScheduler.scheduleDaysAhead = 7 gun) tamponuyla kapsamali;
  /// aksi halde ileri tarihli bildirimler icin veri bulunamaz.
  static const int _daysAfter = 10;

  final PrayerTimesRepository _prayerTimesRepository;
  final NotificationService _notificationService;
  final NotificationSettingsManager _settingsManager;
  final AppLogger _logger;

  DataLoaderService({
    required PrayerTimesRepository prayerTimesRepository,
    required NotificationService notificationService,
    required NotificationSettingsManager settingsManager,
    required AppLogger logger,
  }) : _prayerTimesRepository = prayerTimesRepository,
       _notificationService = notificationService,
       _settingsManager = settingsManager,
       _logger = logger;

  /// Tek aralik cagrisiyla pencerenin tamamini ceker ve bugun/yarin'i bu
  /// listeden turetir. Ayri bir "bugun" istegi atilmaz: aralik cagrisi zaten
  /// bugunu de kapsiyor ve iki tur ag trafigi rate-limit baskisini artiriyordu.
  Future<PrayerData> loadPrayerData(
    Location location, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    final all = await _prayerTimesRepository.getPrayerTimes(
      location: location,
      startDate: todayDate.subtract(const Duration(days: _daysBefore)),
      endDate: todayDate.add(const Duration(days: _daysAfter)),
      forceRefresh: forceRefresh,
    );
    _logger.debug('Prayer window loaded: ${all.length} days');

    final today = _dayAt(all, todayDate);

    // Yarin yalnizca Yatsi'dan sonra gosterilir; gun icinde doldurmak ana
    // ekrandaki "YARIN" seridini surekli gorunur yapardi.
    final tomorrow = today != null && now.isAfter(today.isha)
        ? _dayAt(all, todayDate.add(const Duration(days: 1)))
        : null;

    final lastUpdate = await _prayerTimesRepository.getLastUpdateTime();
    final hasPermission = await _notificationService.isPermissionGranted();

    // Varsayilan bildirimler yalnizca ilk acilista (bir kez) olusturulur.
    await _settingsManager.ensureDefaultsSeeded();
    final settings = await _settingsManager.getSettings();

    return (
      today: today,
      tomorrow: tomorrow,
      all: all,
      lastUpdate: lastUpdate,
      hasPermission: hasPermission,
      settings: settings,
    );
  }

  PrayerTime? _dayAt(List<PrayerTime> times, DateTime date) {
    for (final time in times) {
      if (time.date.year == date.year &&
          time.date.month == date.month &&
          time.date.day == date.day) {
        return time;
      }
    }
    return null;
  }
}
```

- [ ] **Step 2: `HomePage`'i tek çağrıya geçir**

`lib/presentation/pages/home_page.dart` içinde `_loadInitialData` ve `_loadMoreDataInBackground` yerine tek metot:

```dart
  Future<void> _loadPrayerData({bool forceRefresh = false}) async {
    final logger = AppLogger();
    final appState = context.read<AppState>();
    final location = appState.activeLocation;

    if (location == null) {
      logger.warning('No active location found, skipping data load');
      return;
    }

    appState.setRefreshing(true);
    appState.clearError();

    try {
      final data = await _dataLoaderService.loadPrayerData(
        location,
        forceRefresh: forceRefresh,
      );

      appState.setTodaysPrayerTime(data.today);
      appState.setTomorrowsPrayerTime(data.tomorrow);
      appState.setPrayerTimes(data.all);
      appState.setLastUpdateTime(data.lastUpdate);
      appState.setNotificationPermission(data.hasPermission);
      appState.setNotificationSettings(data.settings);
      appState.setRefreshing(false);

      if (data.all.isEmpty) return;

      // Bildirim ve alarmlar yalnizca veri varken planlanir.
      final scheduler = ServiceLocator().get<NotificationScheduler>();
      await scheduler.scheduleNotifications(
        location: location,
        prayerTimes: data.all,
      );
      await ServiceLocator().get<AlarmScheduler>().scheduleAlarms(
        prayerTimes: data.all,
      );
    } catch (e) {
      logger.error('Failed to load prayer data', e);
      appState.setError('Veri yüklenirken hata oluştu: $e');
      appState.setRefreshing(false);
    }
  }
```

Çağıran yerler güncellenir:

| Satır | Eski | Yeni |
|---|---|---|
| `initState` postFrame | `_loadInitialData()` | `_loadPrayerData()` |
| `_startLocationMonitoring` → `onLocationChanged` | `await _loadInitialData()` | `await _loadPrayerData(forceRefresh: true)` |
| `_manualGpsRefresh` | `await _loadInitialData()` | `await _loadPrayerData(forceRefresh: true)` |
| `_refreshData` | `repository.refreshPrayerTimes(location)` + `_loadInitialData()` | yalnızca `await _loadPrayerData(forceRefresh: true)` |
| `_applyGlobalCalculationChange` | `_loadInitialData()` | `await _loadPrayerData(forceRefresh: true)` |
| `_switchLocation` | `_loadInitialData()` | `await _loadPrayerData(forceRefresh: true)` |

`_refreshData` artık `PrayerTimesRepository`'yi doğrudan çağırmadığından `refreshPrayerTimes` import'u kullanılmıyorsa temizlenir; `PrayerTimesRepository` import'u `_applyGlobalCalculationChange`'deki `clearAllCache` için kalır.

- [ ] **Step 3: Derleme ve testler**

```bash
flutter analyze
flutter test
```

Beklenen: analiz temiz, testler yeşil. `data_loader_service`'e dokunan mevcut bir test varsa yeni imzaya uyarlanır.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/services/data_loader_service.dart \
  lib/presentation/pages/home_page.dart
git commit -m "refactor: vakit yuklemesini tek aralik cagrisina indir"
```

---

## Task 4: Yenileme ekranı boşaltmasın

**Files:**
- Modify: `lib/core/providers/app_state.dart`
- Modify: `lib/presentation/screens/home_screen.dart`
- Modify: `lib/presentation/widgets/home/home_top_bar.dart`
- Test: `test/widgets/screens/home_screen_loading_test.dart` (yeni)

**Interfaces:**
- Consumes: `AppState.setRefreshing(bool)` (Task 3'te kullanıldı, burada tanımlanıyor).
- Produces: `AppState.isRefreshing` (bir yükleme uçuşta) ve `AppState.isLoading` (uçuşta **ve** gösterilecek veri yok). `HomeScreen` `isRefreshing` alanını da alır ve `HomeTopBar`'a geçirir.

**Neden iki ayrı bayrak.** Bugün tek bir `isLoading` var ve `HomeScreen` onu görünce ekranı komple `LoadingState` ile değiştiriyor. "Yükleme uçuşta" ile "gösterecek bir şey yok" farklı sorular; ayrılınca stale-while-revalidate kendiliğinden çıkıyor.

- [ ] **Step 1: Widget testini yaz (başarısız olacak)**

`test/widgets/screens/home_screen_loading_test.dart`:

```dart
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/screens/home_screen.dart';
import 'package:ezanvakti/presentation/widgets/common/state_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

/// Yenileme sirasinda ekrandaki vakitler yerinde kalmali; tam ekran yukleme
/// yalnizca gosterilecek hicbir veri yokken cikmali.
void main() {
  const location = Location(
    id: '1',
    province: 'İstanbul',
    district: 'Kadıköy',
  );

  final today = PrayerTime(
    date: DateTime(2026, 8, 3),
    fajr: DateTime(2026, 8, 3, 4, 11),
    sunrise: DateTime(2026, 8, 3, 5, 55),
    dhuhr: DateTime(2026, 8, 3, 13, 15),
    asr: DateTime(2026, 8, 3, 17, 9),
    maghrib: DateTime(2026, 8, 3, 20, 25),
    isha: DateTime(2026, 8, 3, 22, 1),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    PrayerTime? todaysPrayerTime,
    bool isLoading = false,
    bool isRefreshing = false,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        HomeScreen(
          location: location,
          todaysPrayerTime: todaysPrayerTime,
          isLoading: isLoading,
          isRefreshing: isRefreshing,
          onRefresh: () async {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Veri yokken tam ekran yukleme cikar', (tester) async {
    await pumpScreen(tester, isLoading: true, isRefreshing: true);

    expect(find.byType(LoadingState), findsOneWidget);
  });

  testWidgets('Veri varken yenileme ekrani bosaltmaz', (tester) async {
    await pumpScreen(
      tester,
      todaysPrayerTime: today,
      isLoading: false,
      isRefreshing: true,
    );

    expect(find.byType(LoadingState), findsNothing);
    expect(find.text('13:15'), findsOneWidget, reason: 'Ogle vakti ekranda');
  });

  testWidgets('Yenileme surerken ince gosterge cizilir', (tester) async {
    await pumpScreen(
      tester,
      todaysPrayerTime: today,
      isRefreshing: true,
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('Yenileme bitince gosterge kaybolur', (tester) async {
    await pumpScreen(tester, todaysPrayerTime: today, isRefreshing: false);

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
```

- [ ] **Step 2: Testi çalıştır, kırmızıyı gör**

```bash
flutter test test/widgets/screens/home_screen_loading_test.dart
```

Beklenen: derleme hatası — `HomeScreen` `isRefreshing` parametresini tanımıyor.

- [ ] **Step 3: `AppState`'e ayrımı ekle**

`lib/core/providers/app_state.dart`:

```dart
  bool _isRefreshing = false;
```

`_isLoading` alanı ve `setLoading` kaldırılır; yerine:

```dart
  /// Bir veri yuklemesi ucusta mi.
  bool get isRefreshing => _isRefreshing;

  /// Ekranda gosterilecek hicbir sey yokken suren yukleme. Yalnizca bu durumda
  /// tam ekran yukleme gosterilir; veri varken yenileme ekrani bosaltmaz.
  bool get isLoading => _isRefreshing && _todaysPrayerTime == null;

  void setRefreshing(bool refreshing) {
    _isRefreshing = refreshing;
    notifyListeners();
  }
```

- [ ] **Step 4: `HomeScreen`'i güncelle**

`lib/presentation/screens/home_screen.dart`:

Alan ve constructor parametresi eklenir (`isLoading`'in hemen altına):

```dart
  final bool isRefreshing;
```
```dart
    this.isRefreshing = false,
```

`HomeTopBar` çağrısına aktarılır:

```dart
              HomeTopBar(
                locationName: widget.location.displayName,
                onLocationTap: widget.onLocationTap,
                onMenuTap: _openMenu,
                isRefreshing: widget.isRefreshing,
              ),
```

`_buildBody()`'nin ilk satırı (`home_screen.dart:105`) — `isLoading` artık zaten "veri yok" anlamını taşıdığı için koşul aynı kalır; ikinci `LoadingState` dönüşü (`:117`) gereksizleşir ama zararsızdır, yerinde bırakılır. Değişiklik gerekmiyorsa bu adımda yalnızca yukarıdaki iki ekleme yapılır.

- [ ] **Step 5: `HomeTopBar`'a göstergeyi ekle**

`lib/presentation/widgets/home/home_top_bar.dart`:

Alan ve parametre:

```dart
  /// Arka planda vakit yenilemesi surerken ince bir gosterge cizilir.
  final bool isRefreshing;
```
```dart
    this.isRefreshing = false,
```

`build`'deki `SizedBox(height: 56, child: Row(...))` bir `Stack` ile sarılır — çizgi `Positioned` olduğu için **satır yüksekliği degismez**, ekran 2px kaymaz:

```dart
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          Row(
            // ... mevcut icerik aynen
          ),
          if (isRefreshing)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: tokens.accent,
                ),
              ),
            ),
        ],
      ),
    );
```

- [ ] **Step 6: `HomePage`'de `isRefreshing`'i geçir**

`lib/presentation/pages/home_page.dart`'taki `HomeScreen(...)` çağrısına:

```dart
                isRefreshing: appState.isRefreshing,
```

- [ ] **Step 7: Testler geçiyor mu**

```bash
flutter test test/widgets/screens/home_screen_loading_test.dart
flutter test
flutter analyze
```

Beklenen: 4 yeni test geçer, tüm süit yeşil, analiz temiz.

- [ ] **Step 8: Commit**

```bash
git add lib/core/providers/app_state.dart \
  lib/presentation/screens/home_screen.dart \
  lib/presentation/widgets/home/home_top_bar.dart \
  lib/presentation/pages/home_page.dart \
  test/widgets/screens/home_screen_loading_test.dart
git commit -m "fix: yenileme sirasinda ekrandaki vakitler yerinde kalsin"
```

---

## Task 5: Kalan token tutarsızlıkları

**Files:**
- Modify: `lib/presentation/pages/home_page.dart`
- Modify: `lib/presentation/pages/app_root.dart`

**Interfaces:** Yeni API yok.

**Kapsam.** 0.3.0 turundan artakalan iki yer: GPS yenileme SnackBar'ları `Colors.green`/`Colors.red` kullanıyor ve `AppRoot`'un ilk kontrol spinner'ı temasız `Scaffold` içinde.

- [ ] **Step 1: SnackBar renklerini token'lara taşı**

`_manualGpsRefresh` içindeki başarı SnackBar'ından `backgroundColor: Colors.green` **kaldırılır** (tema varsayılanı kullanılır). Hata SnackBar'ı, kod tabanının geri kalanıyla aynı kalıba geçer (`location_edit_screen.dart:133` ile aynı):

```dart
              backgroundColor: Theme.of(context).colorScheme.error,
```

- [ ] **Step 2: `AppRoot` spinner'ını temalı yap**

`lib/presentation/pages/app_root.dart:52`:

```dart
    if (_isChecking) {
      return Scaffold(
        backgroundColor: context.tokens.backgroundStops.last,
        body: Center(
          child: CircularProgressIndicator(color: context.tokens.accent),
        ),
      );
    }
```

`import '../../core/theme/tokens_context.dart';` eklenir.

- [ ] **Step 3: Doğrula**

```bash
flutter analyze
flutter test
grep -rn 'Colors\.green\|Colors\.red' lib
```

Beklenen: analiz temiz, testler yeşil, `grep` çıktısı boş.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/pages/home_page.dart lib/presentation/pages/app_root.dart
git commit -m "chore: kalan sabit renkleri token'lara tasi"
```

---

## Task 6: Uçtan uca doğrulama

**Files:** Değişiklik yok; yalnızca doğrulama.

- [ ] **Step 1: Tam süit ve analiz**

```bash
flutter test
flutter analyze
```

Beklenen: hepsi yeşil (446 + yeni testler), `No issues found!`.

- [ ] **Step 2: Ekran görüntüleri — regresyon kapısı**

```bash
SIM=86EB40FD-7B75-4BCC-91CA-DCBED258902C
xcrun simctl shutdown "$SIM" || true
xcrun simctl boot "$SIM"
sleep 15
rm -rf screenshots
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  -d "$SIM"
ls screenshots/*.png | wc -l
shasum screenshots/*.png | awk '{print $1}' | sort -u | wc -l
```

Beklenen: `exit=0`, iki sayı da **27**, taşma uyarısı yok. Ana ekran kareleri 0.3.0'daki hâlleriyle aynı düzende olmalı — bu tur davranış değişikliği, görsel değişiklik değil.

- [ ] **Step 3: GPS akışını simülatörde gözle doğrula**

```bash
SIM=86EB40FD-7B75-4BCC-91CA-DCBED258902C
flutter run -d "$SIM"
```

Simülatörde **Features → Location → Custom Location** ile bir koordinat ayarla, uygulamayı GPS konumuyla kur, sonra uygulamayı kapat/aç.

Kontrol listesi:
- Açılıştan sonra vakitler ekrana gelir ve **spinner'a dönmez**.
- Konum satırı kendiliğinden değişmez.
- Simülatörde konum 5 km'den uzağa alınınca güncelleme tetiklenir; bu sırada vakitler ekranda kalır, üst çubukta ince çizgi görünür ve veri gelince sessizce değişir.

- [ ] **Step 4: Çalışma ağacı temiz mi**

```bash
git status --short
git log --oneline refactor/konum-ve-veri-yukleme -6
```

Beklenen: `git status` boş, 5 commit.

---

## Öz-inceleme notları

**Karar kapsaması.** K1 → Task 4. K2 → Task 1. K3 → Task 2. K4 → Task 3. Araştırmada bulunan iki ufak tutarsızlık → Task 5.

**Kapsam dışı.** Önbelleğin koordinatla anahtarlanması (araştırmadaki B seçeneği) alınmadı; depolama şeması değişikliği gerektiriyor ve K3 ile sorun pratikte kapanıyor. `getPositionStream` yerine tek seferlik `getCurrentPosition` de alınmadı — uygulama açıkken şehir değişimini yakalama yeteneği korunuyor.

**Bilinen ödün (Task 2).** Konum değişiminde yeni pencerenin dışındaki günler eski konumun verisiyle kalır. Pencere bildirim ufkunu kapsadığı için kullanıcıya yansımaz; kayan pencere sonraki yenilemelerde tazeler.

**Risk.** Task 3 `HomePage`'in altı çağrı noktasına dokunuyor. Hepsi aynı metoda indiği için kaçırılan bir çağrı derleme hatası verir, sessiz kalmaz.
