# iOS Widget (Ana Ekran + Kilit Ekranı) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sıradaki namaz vaktini ve geri sayımı, uygulamayı açmadan iPhone ana ekranında ve kilit ekranında göstermek.

**Architecture:** Flutter tarafı her veri yüklemesinden sonra 7 günlük bir vakit "snapshot"ını App Group'a tek bir JSON string olarak yazar. Ayrı bir process'te çalışan WidgetKit extension'ı bu JSON'ı okur, sıradaki vakti ve gün dilimini kendisi hesaplar, 48 saatlik bir timeline üretir. Geri sayım SwiftUI'ın kendiliğinden güncellenen `Text(date, style: .timer)` metniyle çizilir; saniyelik timeline girişi üretilmez.

**Tech Stack:** Flutter/Dart, `home_widget` paketi, Swift + SwiftUI + WidgetKit, XCTest, fastlane.

**Spec:** `docs/superpowers/specs/2026-08-25-ios-widget-design.md`

## Global Constraints

- iOS deployment target **17.0** (spec D2). Runner ve widget extension aynı hedefi kullanır.
- App Group kimliği: `group.com.ekrembulbul.ezanvakti` (spec §5).
- App Group key: `ezanvakti_snapshot` (spec §5).
- WidgetKit `kind`: `EzanVaktiWidget`. Dart tarafındaki `HomeWidget.updateWidget(iOSName:)` değeriyle **birebir aynı** olmalı.
- Payload `schemaVersion`: **1** (spec D9).
- Saatler `"HH:mm"`, tarihler `"yyyy-MM-dd"`, ikisi de sıfır dolgulu. **Offset'li ISO timestamp yasak** (spec D7/M2).
- Payload penceresi en fazla **7 gün** (spec D8).
- Desteklenen aileler: `systemSmall`, `systemMedium`, `accessoryRectangular`, `accessoryInline` (spec D3). `systemLarge` ve `accessoryCircular` kapsam dışı.
- Kullanıcıya görünen tüm metinler **Türkçe sabit**; lokalizasyon altyapısı kurulmaz (spec D18).
- Vakit adları uygulamayla aynı: `İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı` (`lib/core/utils/prayer_utils.dart:8`).
- Widget yayınlama hatası kullanıcı akışını **kesmez**; yakalanır ve `logger.warning` ile loglanır (spec D11).
- Commit mesajları ASCII (repo konvansiyonu, bkz. `git log`).

---

### Task 1: `WidgetSnapshot` modeli ve JSON serileştirmesi

Payload'ın Dart tarafındaki tipli karşılığı. Saf model — hiçbir platform bağımlılığı yok.

**Files:**
- Create: `lib/features/home_widget/domain/widget_snapshot.dart`
- Test: `test/home_widget/widget_snapshot_test.dart`

**Interfaces:**
- Consumes: (yok — ilk task)
- Produces: `WidgetSnapshot({required String locationLabel, required DateTime generatedAt, required List<WidgetSnapshotDay> days})`, `WidgetSnapshot.schemaVersion` (`int`, değeri `1`), `WidgetSnapshot.toJson() → Map<String, dynamic>`, `WidgetSnapshotDay({required DateTime date, required WidgetDayTimes times})`, `WidgetDayTimes({required DateTime fajr, sunrise, dhuhr, asr, maghrib, isha})`

- [ ] **Step 1: Write the failing test**

`test/home_widget/widget_snapshot_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot.dart';

void main() {
  group('WidgetSnapshot.toJson', () {
    final snapshot = WidgetSnapshot(
      locationLabel: 'Kadıköy, İstanbul',
      generatedAt: DateTime(2026, 8, 25, 14, 3),
      days: [
        WidgetSnapshotDay(
          date: DateTime(2026, 8, 25),
          times: WidgetDayTimes(
            fajr: DateTime(2026, 8, 25, 4, 12),
            sunrise: DateTime(2026, 8, 25, 5, 52),
            dhuhr: DateTime(2026, 8, 25, 13, 15),
            asr: DateTime(2026, 8, 25, 16, 58),
            maghrib: DateTime(2026, 8, 25, 20, 26),
            isha: DateTime(2026, 8, 25, 21, 58),
          ),
        ),
      ],
    );

    test('schemaVersion 1 yazilir', () {
      expect(snapshot.toJson()['schemaVersion'], 1);
    });

    test('saatler sifir dolgulu HH:mm bicimindedir', () {
      final times =
          (snapshot.toJson()['days'] as List).first['times']
              as Map<String, dynamic>;
      expect(times, {
        'fajr': '04:12',
        'sunrise': '05:52',
        'dhuhr': '13:15',
        'asr': '16:58',
        'maghrib': '20:26',
        'isha': '21:58',
      });
    });

    test('tarih yyyy-MM-dd bicimindedir', () {
      final day = (snapshot.toJson()['days'] as List).first;
      expect(day['date'], '2026-08-25');
    });

    test('generatedAt offset tasimayan yerel damgadir', () {
      expect(snapshot.toJson()['generatedAt'], '2026-08-25T14:03:00');
    });

    test('locationLabel oldugu gibi tasinir', () {
      expect(snapshot.toJson()['locationLabel'], 'Kadıköy, İstanbul');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home_widget/widget_snapshot_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../widget_snapshot.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/features/home_widget/domain/widget_snapshot.dart`:

```dart
/// Widget'a gonderilen payload'in tipli karsiligi.
///
/// Saatler `"HH:mm"`, tarihler `"yyyy-MM-dd"` olarak serilestirilir; offset'li
/// ISO timestamp **bilerek** kullanilmaz. Uygulama vakitleri timezone
/// tasimayan cihaz-yerel wall-clock olarak uretiyor
/// (`awqat_salah_provider.dart:407`); offset yazmak widget'a uygulamada
/// olmayan bir timezone semantigi uydurmak olurdu.
class WidgetDayTimes {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  const WidgetDayTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  Map<String, String> toJson() => {
    'fajr': _hhmm(fajr),
    'sunrise': _hhmm(sunrise),
    'dhuhr': _hhmm(dhuhr),
    'asr': _hhmm(asr),
    'maghrib': _hhmm(maghrib),
    'isha': _hhmm(isha),
  };
}

class WidgetSnapshotDay {
  final DateTime date;
  final WidgetDayTimes times;

  const WidgetSnapshotDay({required this.date, required this.times});

  Map<String, dynamic> toJson() => {
    'date': _yyyyMMdd(date),
    'times': times.toJson(),
  };
}

class WidgetSnapshot {
  /// Swift tarafi bilmedigi bir surum gorurse "uygulamayi guncelleyin"
  /// durumuna duser. Payload'in sekli degisirse bu artirilmali.
  static const int schemaVersion = 1;

  final String locationLabel;

  /// Yalnizca teshis icin. Bayatlik karari buna degil, [days]'in son gunune
  /// bakilarak verilir.
  final DateTime generatedAt;

  final List<WidgetSnapshotDay> days;

  const WidgetSnapshot({
    required this.locationLabel,
    required this.generatedAt,
    required this.days,
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'locationLabel': locationLabel,
    'generatedAt':
        '${_yyyyMMdd(generatedAt)}T${_hhmm(generatedAt)}:'
        '${_two(generatedAt.second)}',
    'days': days.map((day) => day.toJson()).toList(),
  };
}

String _two(int value) => value.toString().padLeft(2, '0');

String _hhmm(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

String _yyyyMMdd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-'
    '${_two(date.day)}';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/home_widget/widget_snapshot_test.dart`
Expected: PASS (5 test)

- [ ] **Step 5: Commit**

```bash
git add lib/features/home_widget/domain/widget_snapshot.dart test/home_widget/widget_snapshot_test.dart
git commit -m "feat: widget payload modeli ve JSON serilestirmesi"
```

---

### Task 2: `WidgetSnapshotBuilder` — saf dönüşüm

Vakit listesini widget penceresine çeviren saf fonksiyon. Testin asıl hedefi burası.

**Files:**
- Create: `lib/features/home_widget/domain/widget_snapshot_builder.dart`
- Test: `test/home_widget/widget_snapshot_builder_test.dart`

**Interfaces:**
- Consumes: `WidgetSnapshot`, `WidgetSnapshotDay`, `WidgetDayTimes` (Task 1); `PrayerTime` (`lib/core/models/prayer_time.dart`); `Location` (`lib/core/models/location.dart`)
- Produces: `WidgetSnapshotBuilder.build({required Location location, required List<PrayerTime> prayerTimes, required DateTime now}) → WidgetSnapshot`, `WidgetSnapshotBuilder.maxDays` (`int`, değeri `7`)

- [ ] **Step 1: Write the failing test**

`test/home_widget/widget_snapshot_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot_builder.dart';

PrayerTime _day(DateTime date) => PrayerTime(
  date: date,
  fajr: DateTime(date.year, date.month, date.day, 4, 12),
  sunrise: DateTime(date.year, date.month, date.day, 5, 52),
  dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
  asr: DateTime(date.year, date.month, date.day, 16, 58),
  maghrib: DateTime(date.year, date.month, date.day, 20, 26),
  isha: DateTime(date.year, date.month, date.day, 21, 58),
);

List<PrayerTime> _range(DateTime start, int count) =>
    List.generate(count, (i) => _day(start.add(Duration(days: i))));

const _location = Location(
  id: 'loc-1',
  province: 'İstanbul',
  district: 'Kadıköy',
);

void main() {
  final today = DateTime(2026, 8, 25);

  group('WidgetSnapshotBuilder.build', () {
    test('bugunden onceki gunler elenir, bugun dahil edilir', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: _range(today.subtract(const Duration(days: 2)), 4),
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.days.first.date, today);
      expect(snapshot.days.length, 2);
    });

    test('gece yarisindan sonra bugunun gunu hala dahil edilir', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: _range(today, 3),
        now: DateTime(2026, 8, 25, 2, 0),
      );

      expect(snapshot.days.first.date, today);
    });

    test('pencere en fazla 7 gundur', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: _range(today, 30),
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.days.length, WidgetSnapshotBuilder.maxDays);
    });

    test('onbellekte daha az gun varsa pencere kisalir', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: _range(today, 3),
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.days.length, 3);
    });

    test('bos vakit listesi bos days uretir', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: const [],
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.days, isEmpty);
    });

    test('gunler tarihe gore sirali doner', () {
      final shuffled = [
        _day(today.add(const Duration(days: 2))),
        _day(today),
        _day(today.add(const Duration(days: 1))),
      ];

      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: shuffled,
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.days.map((day) => day.date).toList(), [
        today,
        today.add(const Duration(days: 1)),
        today.add(const Duration(days: 2)),
      ]);
    });

    test('locationLabel Location.displayName ile aynidir', () {
      final snapshot = WidgetSnapshotBuilder.build(
        location: _location,
        prayerTimes: _range(today, 1),
        now: DateTime(2026, 8, 25, 14, 0),
      );

      expect(snapshot.locationLabel, _location.displayName);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home_widget/widget_snapshot_builder_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../widget_snapshot_builder.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/features/home_widget/domain/widget_snapshot_builder.dart`:

```dart
import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import 'widget_snapshot.dart';

/// Vakit listesini widget penceresine ceviren saf donusum.
///
/// Platform bagimliligi yoktur; testin asil hedefi burasidir.
class WidgetSnapshotBuilder {
  const WidgetSnapshotBuilder._();

  /// Payload'a yazilan en fazla gun sayisi. Onbellek 30 gun ileriyi tuttugu
  /// icin (`prayer_times_repository.dart:11`) bu pencere bedavadir ve
  /// uygulama bir hafta acilmasa bile widget'i dogru tutar.
  static const int maxDays = 7;

  static WidgetSnapshot build({
    required Location location,
    required List<PrayerTime> prayerTimes,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);

    final upcoming =
        prayerTimes
            .where((time) => !_dayOf(time.date).isBefore(today))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final window = upcoming.take(maxDays).map(_toDay).toList();

    return WidgetSnapshot(
      locationLabel: location.displayName,
      generatedAt: now,
      days: window,
    );
  }

  static DateTime _dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static WidgetSnapshotDay _toDay(PrayerTime time) => WidgetSnapshotDay(
    date: _dayOf(time.date),
    times: WidgetDayTimes(
      fajr: time.fajr,
      sunrise: time.sunrise,
      dhuhr: time.dhuhr,
      asr: time.asr,
      maghrib: time.maghrib,
      isha: time.isha,
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/home_widget/`
Expected: PASS (12 test — Task 1'in 5'i + bu task'in 7'si)

- [ ] **Step 5: Commit**

```bash
git add lib/features/home_widget/domain/widget_snapshot_builder.dart test/home_widget/widget_snapshot_builder_test.dart
git commit -m "feat: vakit listesini widget penceresine ceviren snapshot builder"
```

---

### Task 3: iOS deployment target 13.0 → 17.0

Kilit ekranı aileleri iOS 16+, `containerBackground` 17+ ister. Bu, widget'tan bağımsız bir ürün kararıdır: iOS 13–16 kullanıcıları artık güncelleme alamaz.

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (3 yer: satır 468, 603, 656 civarı)
- Modify: `ios/Podfile` (platform satırı)
- Modify: `docs/ROADMAP.md` (13.0/iOS 26 tutarsızlığı)

**Interfaces:**
- Consumes: (yok)
- Produces: iOS 17 tabanı — Task 4'ten itibaren tüm iOS işleri buna dayanır

- [ ] **Step 1: pbxproj'daki üç hedefi güncelle**

```bash
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/IPHONEOS_DEPLOYMENT_TARGET = 17.0;/g' ios/Runner.xcodeproj/project.pbxproj
grep -n "IPHONEOS_DEPLOYMENT_TARGET" ios/Runner.xcodeproj/project.pbxproj
```

Expected: üç satırın üçü de `17.0`.

- [ ] **Step 2: Podfile'da platformu aç**

`ios/Podfile` ilk iki satırı şununla değiştir:

```ruby
platform :ios, '17.0'
```

- [ ] **Step 3: Pod'ları yeniden çöz**

Run: `cd ios && pod install && cd ..`
Expected: hata yok. `Podfile.lock` güncellenir.

- [ ] **Step 4: Tam build doğrulaması**

Run: `flutter build ios --no-codesign`
Expected: `Xcode build done.` Bir plugin iOS 17'yi desteklemiyorsa burada patlar — patlarsa dur ve raporla, plugin sürümünü zorlama.

- [ ] **Step 5: ROADMAP tutarsızlığını düzelt**

`docs/ROADMAP.md` içinde "Uygulama iOS 26'ya geçti" ifadesini gerçek durumla değiştir:

```markdown
- **iOS 26+** 🟡 — Apple **AlarmKit** (WWDC 2025) ile 3. parti uygulamalar sessiz mod/Focus'u delen gerçek sistem alarmı kurabiliyor. Uygulamanın hedefi widget çalışmasıyla iOS 17'ye çıktı; AlarmKit için 26 gerekir, o yüzden `#available(iOS 26, *)` dallanmasıyla ele alınmalı. Native (platform-channel) entegrasyon gerekir, olgun hazır plugin beklenmemeli.
```

- [ ] **Step 6: Commit**

```bash
git add ios/Runner.xcodeproj/project.pbxproj ios/Podfile ios/Podfile.lock docs/ROADMAP.md
git commit -m "chore: iOS deployment target 17.0'a cikarildi

Kilit ekrani widget aileleri iOS 16+, containerBackground 17+ istiyor. 17
secilerek #available dallanmasi sifirlandi. Bedeli: iOS 13-16 kullanicilari
artik guncelleme alamaz."
```

---

### Task 4: `WidgetPublisher` arayüzü ve `home_widget` implementasyonu

Yayınlamayı arayüz arkasına alıyoruz ki testlerde fake ile değiştirilebilsin ve iOS dışı platformlarda no-op olsun.

**Files:**
- Create: `lib/core/interfaces/widget_publisher.dart`
- Create: `lib/features/home_widget/data/home_widget_publisher.dart`
- Modify: `pubspec.yaml` (bağımlılık)
- Modify: `lib/core/di/service_locator.dart:143` civarı (kayıt)
- Test: `test/home_widget/home_widget_publisher_test.dart`

**Interfaces:**
- Consumes: `WidgetSnapshot` (Task 1)
- Produces: `abstract class WidgetPublisher { Future<void> publish(WidgetSnapshot snapshot); }`, `HomeWidgetPublisher({required AppLogger logger})`, `HomeWidgetPublisher.appGroupId` (`String`, `'group.com.ekrembulbul.ezanvakti'`), `HomeWidgetPublisher.snapshotKey` (`String`, `'ezanvakti_snapshot'`), `HomeWidgetPublisher.widgetKind` (`String`, `'EzanVaktiWidget'`)

- [ ] **Step 1: Bağımlılığı ekle**

Run: `flutter pub add home_widget`
Expected: `pubspec.yaml`'a `home_widget` eklenir, `pub get` çalışır. Sürümü elle yazma — pub çözsün.

- [ ] **Step 2: Write the failing test**

`test/home_widget/home_widget_publisher_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/utils/app_logger.dart';
import 'package:ezanvakti/features/home_widget/data/home_widget_publisher.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final snapshot = WidgetSnapshot(
    locationLabel: 'Kadıköy, İstanbul',
    generatedAt: DateTime(2026, 8, 25, 14, 3),
    days: const [],
  );

  test('publish snapshot key\'ine tek JSON string yazar', () async {
    await HomeWidgetPublisher(logger: AppLogger()).publish(snapshot);

    final save = calls.firstWhere((call) => call.method == 'saveWidgetData');
    expect(save.arguments['id'], HomeWidgetPublisher.snapshotKey);
    expect(save.arguments['data'], contains('"schemaVersion":1'));
  });

  test('publish widget kind ile guncelleme tetikler', () async {
    await HomeWidgetPublisher(logger: AppLogger()).publish(snapshot);

    final update = calls.firstWhere((call) => call.method == 'updateWidget');
    expect(update.arguments['iOSName'], HomeWidgetPublisher.widgetKind);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/home_widget/home_widget_publisher_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../home_widget_publisher.dart'`

- [ ] **Step 4: Arayüzü yaz**

`lib/core/interfaces/widget_publisher.dart`:

```dart
import '../../features/home_widget/domain/widget_snapshot.dart';

/// Widget'a snapshot yayinlamanin soyutlamasi.
///
/// Testlerde fake ile degistirilir; iOS disi platformlarda no-op bir
/// implementasyon kullanilir.
abstract class WidgetPublisher {
  Future<void> publish(WidgetSnapshot snapshot);
}
```

- [ ] **Step 5: Implementasyonu yaz**

`lib/features/home_widget/data/home_widget_publisher.dart`:

Platform ayrımı **bilerek buraya konmuyor**: `HomeWidgetPublisher` guard'sız kalır, iOS dışı seçim DI'da yapılır (Step 7). Guard sınıfın içinde olsaydı test host'u macOS'ta koştuğu için `publish` hiçbir kanal çağrısı yapmaz ve testler boşa çalışırdı.

```dart
import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../../../core/interfaces/widget_publisher.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/widget_snapshot.dart';

/// Snapshot'i App Group'a yazip WidgetKit'e reload tetikleyen ince kabuk.
///
/// Payload **tek key altinda tek JSON string** olarak yazilir: cok sayida duz
/// key, kismi yazimda widget'a tutarsiz veri gosterirdi.
class HomeWidgetPublisher implements WidgetPublisher {
  static const String appGroupId = 'group.com.ekrembulbul.ezanvakti';
  static const String snapshotKey = 'ezanvakti_snapshot';

  /// Swift tarafindaki `kind` ile birebir ayni olmali; aksi halde reload
  /// sessizce hicbir widget'a ulasmaz.
  static const String widgetKind = 'EzanVaktiWidget';

  final AppLogger _logger;

  HomeWidgetPublisher({required AppLogger logger}) : _logger = logger;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    await HomeWidget.setAppGroupId(appGroupId);
    await HomeWidget.saveWidgetData<String>(
      snapshotKey,
      jsonEncode(snapshot.toJson()),
    );
    await HomeWidget.updateWidget(iOSName: widgetKind);

    _logger.debug('Widget snapshot published: ${snapshot.days.length} days');
  }
}

/// iOS disi platformlarda kullanilir. Widget yalnizca iOS'ta var; diger
/// platformlarda yayinlama sessizce atlanir.
class NoopWidgetPublisher implements WidgetPublisher {
  const NoopWidgetPublisher();

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {}
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/home_widget/home_widget_publisher_test.dart`
Expected: PASS (2 test)

- [ ] **Step 7: DI kaydını ekle**

`lib/core/di/service_locator.dart`, `register<SkipManager>(...)` satırının hemen üstüne:

```dart
    register<WidgetPublisher>(
      Platform.isIOS
          ? HomeWidgetPublisher(logger: logger)
          : const NoopWidgetPublisher(),
    );
```

Dosyanın başına gerekli importları ekle: `dart:io`, `../interfaces/widget_publisher.dart`, `../../features/home_widget/data/home_widget_publisher.dart`.

- [ ] **Step 8: Testleri ve analizi çalıştır**

Run: `flutter analyze && flutter test test/home_widget/`
Expected: analiz temiz, 14 test PASS.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/interfaces/widget_publisher.dart lib/features/home_widget/data/home_widget_publisher.dart lib/core/di/service_locator.dart test/home_widget/home_widget_publisher_test.dart
git commit -m "feat: widget snapshot yayinlayicisi ve DI kaydi"
```

---

### Task 5: `_loadPrayerData` entegrasyonu

Senkronun tek kancası. Tüm yükleme yolları (pull-to-refresh, konum değişimi, GPS, gece yarısı yenilemesi, resume, hesaplama ayarı) buradan geçtiği için başka kanca gerekmiyor.

**Files:**
- Modify: `lib/presentation/pages/home_page.dart:288-292` (rescheduler çağrısının hemen ardı)
- Test: `test/home_widget/widget_publish_isolation_test.dart`

**Interfaces:**
- Consumes: `WidgetPublisher` (Task 4), `WidgetSnapshotBuilder` (Task 2)
- Produces: (yok — entegrasyon task'i)

- [ ] **Step 1: Write the failing test**

Bu test, D11'in özünü koruyor: yayınlama patlarsa vakit yükleme akışı **kesilmemeli**. Doğrudan `HomePage` widget'ını sürmek yerine, izolasyonu sağlayan yardımcıyı test ediyoruz.

`test/home_widget/widget_publish_isolation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/interfaces/widget_publisher.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/utils/app_logger.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot_publish.dart';

class _ThrowingPublisher implements WidgetPublisher {
  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    throw StateError('App Group yazilamadi');
  }
}

class _RecordingPublisher implements WidgetPublisher {
  WidgetSnapshot? published;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    published = snapshot;
  }
}

const _location = Location(
  id: 'loc-1',
  province: 'İstanbul',
  district: 'Kadıköy',
);

PrayerTime _day(DateTime date) => PrayerTime(
  date: date,
  fajr: DateTime(date.year, date.month, date.day, 4, 12),
  sunrise: DateTime(date.year, date.month, date.day, 5, 52),
  dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
  asr: DateTime(date.year, date.month, date.day, 16, 58),
  maghrib: DateTime(date.year, date.month, date.day, 20, 26),
  isha: DateTime(date.year, date.month, date.day, 21, 58),
);

void main() {
  final today = DateTime(2026, 8, 25);

  test('yayinlama basarili oldugunda snapshot iletilir', () async {
    final publisher = _RecordingPublisher();

    await publishWidgetSnapshot(
      publisher: publisher,
      logger: AppLogger(),
      location: _location,
      prayerTimes: [_day(today)],
      now: DateTime(2026, 8, 25, 14, 0),
    );

    expect(publisher.published?.days.length, 1);
  });

  test('yayinlama patlarsa hata yukari sizmaz', () async {
    await expectLater(
      publishWidgetSnapshot(
        publisher: _ThrowingPublisher(),
        logger: AppLogger(),
        location: _location,
        prayerTimes: [_day(today)],
        now: DateTime(2026, 8, 25, 14, 0),
      ),
      completes,
    );
  });

  test('konum yoksa yayinlama yapilmaz', () async {
    final publisher = _RecordingPublisher();

    await publishWidgetSnapshot(
      publisher: publisher,
      logger: AppLogger(),
      location: null,
      prayerTimes: [_day(today)],
      now: DateTime(2026, 8, 25, 14, 0),
    );

    expect(publisher.published, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/home_widget/widget_publish_isolation_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../widget_snapshot_publish.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/features/home_widget/domain/widget_snapshot_publish.dart`:

```dart
import '../../../core/interfaces/widget_publisher.dart';
import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/utils/app_logger.dart';
import 'widget_snapshot_builder.dart';

/// Snapshot uretip yayinlar; hata cikarsa **yutmaz ama yukari da sizdirmaz**.
///
/// Vakit gosterimi widget yuzunden bozulmamali: yayinlama patlarsa widget bir
/// onceki snapshot'iyla calismaya devam eder, kullanici akisi kesilmez.
Future<void> publishWidgetSnapshot({
  required WidgetPublisher publisher,
  required AppLogger logger,
  required Location? location,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
}) async {
  if (location == null) return;

  try {
    await publisher.publish(
      WidgetSnapshotBuilder.build(
        location: location,
        prayerTimes: prayerTimes,
        now: now,
      ),
    );
  } catch (e, stackTrace) {
    logger.warning('Widget snapshot publish failed: $e', stackTrace);
  }
}
```

⚠️ `AppLogger.warning`'in imzasını `lib/core/utils/app_logger.dart` içinden doğrula; ikinci parametre kabul etmiyorsa yalnızca mesajı geçir.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/home_widget/widget_publish_isolation_test.dart`
Expected: PASS (3 test)

- [ ] **Step 5: `_loadPrayerData`'ya bağla**

`lib/presentation/pages/home_page.dart`, `ReminderRescheduler` çağrısının hemen ardına:

```dart
      await publishWidgetSnapshot(
        publisher: ServiceLocator().get<WidgetPublisher>(),
        logger: logger,
        location: location,
        prayerTimes: data.all,
        now: DateTime.now(),
      );
```

Dosyanın başına importları ekle: `../../core/interfaces/widget_publisher.dart`, `../../features/home_widget/domain/widget_snapshot_publish.dart`.

- [ ] **Step 6: Tüm test paketini çalıştır**

Run: `flutter analyze && flutter test`
Expected: analiz temiz, tüm testler PASS. Kırmızı çıkan varsa `ServiceLocator`'da `WidgetPublisher` kaydı eksik olan test setup'larıdır — `test/setup/` altındaki ortak kuruluma `NoopWidgetPublisher` ekle.

- [ ] **Step 7: Commit**

```bash
git add lib/features/home_widget/domain/widget_snapshot_publish.dart lib/presentation/pages/home_page.dart test/home_widget/widget_publish_isolation_test.dart test/setup
git commit -m "feat: vakit yuklemesinden sonra widget snapshot yayinla

Yayinlama hatasi yukari sizmaz; vakit gosterimi widget yuzunden bozulmamali."
```

---

### Task 6: Widget extension target'ı ve App Group

Xcode'da elle yapılan adımlar. Bu task kod üretmez, altyapı kurar.

**Files:**
- Create: `ios/EzanVaktiWidget/` (Xcode şablonu üretir)
- Create: `ios/EzanVaktiWidget/EzanVaktiWidget.entitlements`
- Create: `ios/Runner/Runner.entitlements`
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (Xcode üretir)

**Interfaces:**
- Consumes: iOS 17 tabanı (Task 3)
- Produces: `EzanVaktiWidgetExtension` target'ı, `group.com.ekrembulbul.ezanvakti` App Group'u her iki target'ta

- [ ] **Step 1: Apple Developer portalında hazırlık (elle)**

1. Yeni App ID: `com.ekrembulbul.ezanvakti.EzanVaktiWidget`
2. App Group oluştur: `group.com.ekrembulbul.ezanvakti`
3. App Group'u **her iki** App ID'ye (`com.ekrembulbul.ezanvakti` ve widget'ınki) ekle
4. Widget App ID'si için App Store dağıtım profili üret; adı `com.ekrembulbul.ezanvakti.EzanVaktiWidget AppStore` olsun (Task 14 bu adı bekliyor)

Bu adımlar kodla halledilemez; portalda elle yapılır.

- [ ] **Step 2: Xcode'da extension target'ı ekle**

Run: `open ios/Runner.xcworkspace`

File → New → Target → **Widget Extension**:
- Product Name: `EzanVaktiWidget`
- Team: `MW25H55RX4`
- **Include Live Activity: KAPALI** (kapsam dışı, spec §8)
- **Include Configuration App Intent: KAPALI** (spec D4 — StaticConfiguration kullanıyoruz)
- "Activate scheme?" sorusuna **Cancel** (Runner scheme'i aktif kalsın)

- [ ] **Step 3: Bundle ID ve deployment target'ı doğrula**

Xcode → `EzanVaktiWidgetExtension` target → Build Settings:
- `PRODUCT_BUNDLE_IDENTIFIER` = `com.ekrembulbul.ezanvakti.EzanVaktiWidget`
- `IPHONEOS_DEPLOYMENT_TARGET` = `17.0`

⚠️ Xcode varsayılan olarak bundle ID'ye `Extension` ekleyebilir; portalda üretilen App ID ile birebir aynı olmalı.

- [ ] **Step 4: App Group capability'sini iki target'a da ekle**

Her iki target için (Runner ve EzanVaktiWidgetExtension) Signing & Capabilities → + Capability → App Groups → `group.com.ekrembulbul.ezanvakti` işaretle.

Bu, `ios/Runner/Runner.entitlements` ve `ios/EzanVaktiWidget/EzanVaktiWidget.entitlements` dosyalarını üretir.

- [ ] **Step 5: Doğrula**

```bash
cat ios/Runner/Runner.entitlements
cat ios/EzanVaktiWidget/EzanVaktiWidget.entitlements
```

Expected: her ikisinde de `com.apple.security.application-groups` altında `group.com.ekrembulbul.ezanvakti`.

- [ ] **Step 6: Build doğrulaması**

Run: `flutter build ios --no-codesign`
Expected: `Xcode build done.`

- [ ] **Step 7: Commit**

```bash
git add ios/
git commit -m "chore: widget extension target'i ve App Group entitlement'lari"
```

---

### Task 7: Swift — snapshot decode ve App Group okuma

**Files:**
- Create: `ios/EzanVaktiWidget/Snapshot/WidgetSnapshot.swift`
- Create: `ios/EzanVaktiWidget/Snapshot/SnapshotStore.swift`
- Create: `ios/RunnerTests/WidgetSnapshotTests.swift`

**Interfaces:**
- Consumes: Task 1'in JSON şeması
- Produces: `struct WidgetSnapshot: Decodable { let schemaVersion: Int; let locationLabel: String; let days: [SnapshotDay] }`, `struct SnapshotDay: Decodable { let date: String; let times: SnapshotTimes }`, `struct SnapshotTimes: Decodable { let fajr, sunrise, dhuhr, asr, maghrib, isha: String }`, `enum SnapshotLoadError: Error { case unsupportedSchema, malformed }`, `WidgetSnapshot.decode(_ json: Data) throws -> WidgetSnapshot`, `SnapshotStore.load() -> Result<WidgetSnapshot, SnapshotLoadError>?`

- [ ] **Step 1: Write the failing test**

`ios/RunnerTests/WidgetSnapshotTests.swift`:

```swift
import XCTest

final class WidgetSnapshotTests: XCTestCase {
    private func json(schemaVersion: Int) -> Data {
        """
        {
          "schemaVersion": \(schemaVersion),
          "locationLabel": "Kadıköy, İstanbul",
          "generatedAt": "2026-08-25T14:03:00",
          "days": [
            { "date": "2026-08-25",
              "times": { "fajr": "04:12", "sunrise": "05:52", "dhuhr": "13:15",
                         "asr": "16:58", "maghrib": "20:26", "isha": "21:58" } }
          ]
        }
        """.data(using: .utf8)!
    }

    func testDecodesValidPayload() throws {
        let snapshot = try WidgetSnapshot.decode(json(schemaVersion: 1))
        XCTAssertEqual(snapshot.locationLabel, "Kadıköy, İstanbul")
        XCTAssertEqual(snapshot.days.count, 1)
        XCTAssertEqual(snapshot.days[0].times.asr, "16:58")
    }

    func testRejectsUnknownSchemaVersion() {
        XCTAssertThrowsError(try WidgetSnapshot.decode(json(schemaVersion: 99))) { error in
            XCTAssertEqual(error as? SnapshotLoadError, .unsupportedSchema)
        }
    }

    func testRejectsMalformedPayload() {
        let broken = "{ not json".data(using: .utf8)!
        XCTAssertThrowsError(try WidgetSnapshot.decode(broken)) { error in
            XCTAssertEqual(error as? SnapshotLoadError, .malformed)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:RunnerTests/WidgetSnapshotTests 2>&1 | tail -20
```
Expected: FAIL — `cannot find 'WidgetSnapshot' in scope`

- [ ] **Step 3: Write minimal implementation**

`ios/EzanVaktiWidget/Snapshot/WidgetSnapshot.swift`:

```swift
import Foundation

enum SnapshotLoadError: Error, Equatable {
    case unsupportedSchema
    case malformed
}

struct SnapshotTimes: Decodable, Equatable {
    let fajr: String
    let sunrise: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String
}

struct SnapshotDay: Decodable, Equatable {
    /// `"yyyy-MM-dd"`. Offset tasimaz; cihaz-yerel wall-clock olarak yorumlanir.
    let date: String
    let times: SnapshotTimes
}

struct WidgetSnapshot: Decodable, Equatable {
    /// Uygulamanin yazdigi surum. Bilinmeyen surum reddedilir; cop cizmek
    /// yerine kullaniciya "uygulamayi guncelleyin" gosterilir.
    static let supportedSchemaVersion = 1

    let schemaVersion: Int
    let locationLabel: String
    let days: [SnapshotDay]

    static func decode(_ json: Data) throws -> WidgetSnapshot {
        let snapshot: WidgetSnapshot
        do {
            snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: json)
        } catch {
            throw SnapshotLoadError.malformed
        }

        guard snapshot.schemaVersion == supportedSchemaVersion else {
            throw SnapshotLoadError.unsupportedSchema
        }
        return snapshot
    }
}
```

`ios/EzanVaktiWidget/Snapshot/SnapshotStore.swift`:

```swift
import Foundation

/// App Group'taki payload'i okur. Uygulama hic acilmadiysa `nil` doner.
enum SnapshotStore {
    static let appGroupId = "group.com.ekrembulbul.ezanvakti"
    static let snapshotKey = "ezanvakti_snapshot"

    static func load() -> Result<WidgetSnapshot, SnapshotLoadError>? {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let raw = defaults.string(forKey: snapshotKey),
            let data = raw.data(using: .utf8)
        else { return nil }

        do {
            return .success(try WidgetSnapshot.decode(data))
        } catch let error as SnapshotLoadError {
            return .failure(error)
        } catch {
            return .failure(.malformed)
        }
    }
}
```

- [ ] **Step 4: Dosyaları RunnerTests target'ına da üye yap**

Xcode'da `WidgetSnapshot.swift`'i seç → File Inspector → Target Membership → `EzanVaktiWidgetExtension` **ve** `RunnerTests` işaretli olsun. (`SnapshotStore.swift` yalnızca extension'da kalsın — `UserDefaults` suite'i test host'unda yok.)

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:RunnerTests/WidgetSnapshotTests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`, 3 test.

- [ ] **Step 6: Commit**

```bash
git add ios/EzanVaktiWidget/Snapshot ios/RunnerTests/WidgetSnapshotTests.swift ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: widget tarafinda snapshot decode ve App Group okuma"
```

---

### Task 8: Swift — sıradaki vakit ve gün dilimi

Yorumlama mantığının tamamı. Saf tipler; WidgetKit'e dokunmaz.

**Files:**
- Create: `ios/EzanVaktiWidget/Timeline/NextPrayer.swift`
- Create: `ios/EzanVaktiWidget/Theme/DayPhase.swift`
- Create: `ios/RunnerTests/NextPrayerTests.swift`
- Create: `ios/RunnerTests/DayPhaseTests.swift`

**Interfaces:**
- Consumes: `SnapshotDay`, `SnapshotTimes`, `WidgetSnapshot` (Task 7)
- Produces: `struct PrayerSlot: Equatable { let name: String; let date: Date }`, `enum NextPrayer { static func slots(days: [SnapshotDay], calendar: Calendar) -> [PrayerSlot]; static func resolve(days: [SnapshotDay], now: Date, calendar: Calendar) -> PrayerSlot? }`, `enum DayPhase { case morning, afternoon, evening, night; static let fallback: DayPhase; static func resolve(slots: [PrayerSlot], now: Date) -> DayPhase }`

- [ ] **Step 1: Write the failing tests**

`ios/RunnerTests/NextPrayerTests.swift`:

```swift
import XCTest

final class NextPrayerTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ date: String) -> SnapshotDay {
        SnapshotDay(
            date: date,
            times: SnapshotTimes(
                fajr: "04:12", sunrise: "05:52", dhuhr: "13:15",
                asr: "16:58", maghrib: "20:26", isha: "21:58"
            )
        )
    }

    private func at(_ year: Int, _ month: Int, _ day: Int,
                    _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    func testResolvesNextPrayerWithinDay() {
        let slot = NextPrayer.resolve(
            days: [day("2026-08-25")],
            now: at(2026, 8, 25, 14, 0),
            calendar: calendar
        )
        XCTAssertEqual(slot?.name, "İkindi")
        XCTAssertEqual(slot?.date, at(2026, 8, 25, 16, 58))
    }

    func testAfterIshaRollsToNextDayFajr() {
        let slot = NextPrayer.resolve(
            days: [day("2026-08-25"), day("2026-08-26")],
            now: at(2026, 8, 25, 22, 30),
            calendar: calendar
        )
        XCTAssertEqual(slot?.name, "İmsak")
        XCTAssertEqual(slot?.date, at(2026, 8, 26, 4, 12))
    }

    func testBeforeFajrResolvesToSameDayFajr() {
        let slot = NextPrayer.resolve(
            days: [day("2026-08-25")],
            now: at(2026, 8, 25, 2, 0),
            calendar: calendar
        )
        XCTAssertEqual(slot?.name, "İmsak")
    }

    func testReturnsNilWhenWindowExhausted() {
        let slot = NextPrayer.resolve(
            days: [day("2026-08-25")],
            now: at(2026, 8, 25, 23, 59),
            calendar: calendar
        )
        XCTAssertNil(slot)
    }

    func testSlotsAreSortedAndNamedLikeTheApp() {
        let slots = NextPrayer.slots(days: [day("2026-08-25")], calendar: calendar)
        XCTAssertEqual(
            slots.map(\.name),
            ["İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı"]
        )
    }
}
```

`ios/RunnerTests/DayPhaseTests.swift`:

```swift
import XCTest

final class DayPhaseTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private var slots: [PrayerSlot] {
        NextPrayer.slots(
            days: [SnapshotDay(
                date: "2026-08-25",
                times: SnapshotTimes(
                    fajr: "04:12", sunrise: "05:52", dhuhr: "13:15",
                    asr: "16:58", maghrib: "20:26", isha: "21:58"
                )
            )],
            calendar: calendar
        )
    }

    private func at(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 25, hour: hour, minute: minute
        ))!
    }

    func testBeforeFajrIsNight() {
        XCTAssertEqual(DayPhase.resolve(slots: slots, now: at(2, 0)), .night)
    }

    func testBetweenFajrAndDhuhrIsMorning() {
        XCTAssertEqual(DayPhase.resolve(slots: slots, now: at(6, 0)), .morning)
    }

    func testBetweenDhuhrAndAsrIsAfternoon() {
        XCTAssertEqual(DayPhase.resolve(slots: slots, now: at(15, 0)), .afternoon)
    }

    /// Gece Aksam'da degil Yatsi'da baslar (day_phase.dart:4-8).
    func testBetweenMaghribAndIshaIsStillEvening() {
        XCTAssertEqual(DayPhase.resolve(slots: slots, now: at(21, 0)), .evening)
    }

    func testAfterIshaIsNight() {
        XCTAssertEqual(DayPhase.resolve(slots: slots, now: at(22, 0)), .night)
    }

    /// Sinir ani bir SONRAKI dilime aittir (day_phase.dart:20-21).
    func testBoundaryBelongsToNextPhase() {
        XCTAssertEqual(DayPhase.resolve(slots: slots, now: at(13, 15)), .afternoon)
    }

    func testFallsBackToEveningWithoutData() {
        XCTAssertEqual(DayPhase.resolve(slots: [], now: at(13, 0)), DayPhase.fallback)
        XCTAssertEqual(DayPhase.fallback, .evening)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:RunnerTests/NextPrayerTests \
  -only-testing:RunnerTests/DayPhaseTests 2>&1 | tail -20
```
Expected: FAIL — `cannot find 'NextPrayer' in scope`

- [ ] **Step 3: Write minimal implementation**

`ios/EzanVaktiWidget/Timeline/NextPrayer.swift`:

```swift
import Foundation

struct PrayerSlot: Equatable {
    /// Uygulamadaki adla ayni (`prayer_utils.dart:8`).
    let name: String
    let date: Date
}

enum NextPrayer {
    /// Payload'daki `"HH:mm"` degerlerini cihaz-yerel `Date`e cevirir.
    ///
    /// Takvim cagirandan gelir; boylece test sabit bir takvimle kosar,
    /// uretimde `Calendar.current` kullanilir.
    static func slots(days: [SnapshotDay], calendar: Calendar) -> [PrayerSlot] {
        days.flatMap { day -> [PrayerSlot] in
            let named: [(String, String)] = [
                ("İmsak", day.times.fajr),
                ("Güneş", day.times.sunrise),
                ("Öğle", day.times.dhuhr),
                ("İkindi", day.times.asr),
                ("Akşam", day.times.maghrib),
                ("Yatsı", day.times.isha),
            ]
            return named.compactMap { name, time in
                guard let date = combine(day: day.date, time: time, calendar: calendar)
                else { return nil }
                return PrayerSlot(name: name, date: date)
            }
        }
        .sorted { $0.date < $1.date }
    }

    static func resolve(days: [SnapshotDay], now: Date, calendar: Calendar) -> PrayerSlot? {
        slots(days: days, calendar: calendar).first { $0.date > now }
    }

    private static func combine(day: String, time: String, calendar: Calendar) -> Date? {
        let dayParts = day.split(separator: "-").compactMap { Int($0) }
        let timeParts = time.split(separator: ":").compactMap { Int($0) }
        guard dayParts.count == 3, timeParts.count == 2 else { return nil }

        return calendar.date(from: DateComponents(
            year: dayParts[0], month: dayParts[1], day: dayParts[2],
            hour: timeParts[0], minute: timeParts[1]
        ))
    }
}
```

`ios/EzanVaktiWidget/Theme/DayPhase.swift`:

```swift
import Foundation

/// Gunun, palet degisimini belirleyen dort dilimi.
///
/// `lib/core/theme/day_phase.dart` portu. Iki kural aynen korunur:
/// gece **Aksam'da degil Yatsi'da** baslar, ve sinir ani bir SONRAKI
/// dilime aittir.
enum DayPhase: Equatable {
    case morning, afternoon, evening, night

    /// Vakit verisi yokken kullanilan dilim; uygulama ikonu da bu ailedendir.
    static let fallback: DayPhase = .evening

    static func resolve(slots: [PrayerSlot], now: Date) -> DayPhase {
        guard
            let fajr = time(of: "İmsak", in: slots, on: now),
            let dhuhr = time(of: "Öğle", in: slots, on: now),
            let asr = time(of: "İkindi", in: slots, on: now),
            let isha = time(of: "Yatsı", in: slots, on: now)
        else { return fallback }

        if now < fajr { return .night }
        if now < dhuhr { return .morning }
        if now < asr { return .afternoon }
        if now < isha { return .evening }
        return .night
    }

    /// `now` ile ayni takvim gunundeki vakti bulur.
    private static func time(of name: String, in slots: [PrayerSlot], on now: Date) -> Date? {
        let calendar = Calendar.current
        return slots.first {
            $0.name == name && calendar.isDate($0.date, inSameDayAs: now)
        }?.date
    }
}
```

- [ ] **Step 4: Target membership'leri ayarla**

Her iki dosya için Target Membership: `EzanVaktiWidgetExtension` **ve** `RunnerTests`.

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:RunnerTests/NextPrayerTests \
  -only-testing:RunnerTests/DayPhaseTests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`, 12 test.

⚠️ `DayPhase.resolve` içindeki `Calendar.current`, testte sabit takvimle kurulan tarihlerle çakışabilir (timezone farkı). Testler kırmızı çıkarsa `resolve`'a `calendar: Calendar = .current` parametresi ekle ve testlerden sabit takvimi geçir.

- [ ] **Step 6: Commit**

```bash
git add ios/EzanVaktiWidget/Timeline ios/EzanVaktiWidget/Theme ios/RunnerTests ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: widget tarafinda siradaki vakit ve gun dilimi mantigi"
```

---

### Task 9: Swift — palet portu

Uygulamanın sekiz paleti ve radial gradyan geometrisi.

**Files:**
- Create: `ios/EzanVaktiWidget/Theme/Palette.swift`

**Interfaces:**
- Consumes: `DayPhase` (Task 8)
- Produces: `struct Palette { let accent: Color; let textPrimary: Color; let textSecondary: Color; let backgroundStops: [Color] }`, `Palette.forPhase(_ phase: DayPhase, colorScheme: ColorScheme) -> Palette`, `Palette.backgroundGradient(in size: CGSize) -> RadialGradient`

- [ ] **Step 1: Paleti yaz**

`ios/EzanVaktiWidget/Theme/Palette.swift`:

```swift
import SwiftUI

/// `lib/core/theme/palettes.dart` portu. Degerler oradan birebir alinmistir;
/// palet degisirse iki taraf birlikte guncellenmelidir.
struct Palette {
    let accent: Color
    let textPrimary: Color
    let textSecondary: Color
    let backgroundStops: [Color]

    /// Zemin gradyani. Geometri her palette ayni, yalnizca renkler degisir.
    ///
    /// Flutter karsiligi: `RadialGradient(center: Alignment(0.40, -1.08),
    /// radius: 1.25, stops: [0, 0.44, 1])` (`app_tokens.dart:82-87`).
    /// Alignment -> UnitPoint donusumu: x = (0.40 + 1) / 2 = 0.70,
    /// y = (-1.08 + 1) / 2 = -0.04. Yaricap kisa kenarin 1.25 kati.
    func backgroundGradient(in size: CGSize) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: backgroundStops[0], location: 0.0),
                .init(color: backgroundStops[1], location: 0.44),
                .init(color: backgroundStops[2], location: 1.0),
            ]),
            center: UnitPoint(x: 0.70, y: -0.04),
            startRadius: 0,
            endRadius: min(size.width, size.height) * 1.25
        )
    }

    static func forPhase(_ phase: DayPhase, colorScheme: ColorScheme) -> Palette {
        colorScheme == .dark ? dark(phase) : light(phase)
    }

    private static func dark(_ phase: DayPhase) -> Palette {
        switch phase {
        case .morning:   // GÖKKUŞAĞI — İmsak → Öğle
            return Palette(
                accent: Color(hex: 0x93C4E8),
                textPrimary: Color(hex: 0xE8F0F8),
                textSecondary: Color(hex: 0xA5BDD2),
                backgroundStops: [Color(hex: 0x2C5279), Color(hex: 0x143049), Color(hex: 0x08141F)]
            )
        case .afternoon:
            return Palette(
                accent: Color(hex: 0xD8E8EE),
                textPrimary: Color(hex: 0xF0F5F7),
                textSecondary: Color(hex: 0xAFC3CB),
                backgroundStops: [Color(hex: 0x40525C), Color(hex: 0x202C33), Color(hex: 0x10171B)]
            )
        case .evening:   // ERGUVAN
            return Palette(
                accent: Color(hex: 0xE09FB8),
                textPrimary: Color(hex: 0xF3EEF4),
                textSecondary: Color(hex: 0xB5A8C1),
                backgroundStops: [Color(hex: 0x4A2144), Color(hex: 0x241634), Color(hex: 0x120E1B)]
            )
        case .night:
            return Palette(
                accent: Color(hex: 0xCDA6E4),
                textPrimary: Color(hex: 0xF2ECF6),
                textSecondary: Color(hex: 0xB3A5C1),
                backgroundStops: [Color(hex: 0x2A2038), Color(hex: 0x17111F), Color(hex: 0x0A080E)]
            )
        }
    }

    private static func light(_ phase: DayPhase) -> Palette {
        switch phase {
        case .morning:   // NİLÜFER
            return Palette(
                accent: Color(hex: 0x265F8E),
                textPrimary: Color(hex: 0x0E1D2C),
                textSecondary: Color(hex: 0x43596D),
                backgroundStops: [Color(hex: 0xDCE9F7), Color(hex: 0xEDF3FA), Color(hex: 0xF8FBFD)]
            )
        case .afternoon: // SEDEF
            return Palette(
                accent: Color(hex: 0x2A5B68),
                textPrimary: Color(hex: 0x0F1C21),
                textSecondary: Color(hex: 0x435A62),
                backgroundStops: [Color(hex: 0xE2ECF0), Color(hex: 0xF1F6F8), Color(hex: 0xF9FCFC)]
            )
        case .evening:   // GÜLKURUSU
            return Palette(
                accent: Color(hex: 0x983F62),
                textPrimary: Color(hex: 0x201A1E),
                textSecondary: Color(hex: 0x5A4A50),
                backgroundStops: [Color(hex: 0xF7E7EB), Color(hex: 0xFAF2F4), Color(hex: 0xFDFAFA)]
            )
        case .night:     // LEYLAK
            return Palette(
                accent: Color(hex: 0x5E3A80),
                textPrimary: Color(hex: 0x1A1424),
                textSecondary: Color(hex: 0x4F4260),
                backgroundStops: [Color(hex: 0xEBE4F1), Color(hex: 0xF7F4F9), Color(hex: 0xFCFBFD)]
            )
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
```

- [ ] **Step 2: Derlemeyi doğrula**

Run: `flutter build ios --no-codesign`
Expected: `Xcode build done.`

- [ ] **Step 3: Commit**

```bash
git add ios/EzanVaktiWidget/Theme/Palette.swift ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: uygulama paletlerinin widget tarafina portu"
```

---

### Task 10: Swift — timeline üretimi

**Files:**
- Create: `ios/EzanVaktiWidget/Timeline/PrayerTimelineProvider.swift`
- Create: `ios/RunnerTests/PrayerTimelineTests.swift`

**Interfaces:**
- Consumes: `WidgetSnapshot`, `SnapshotDay` (Task 7); `NextPrayer`, `PrayerSlot`, `DayPhase` (Task 8)
- Produces: `enum WidgetContent: Equatable { case ready(next: PrayerSlot, day: SnapshotDay, phase: DayPhase, locationLabel: String, isStale: Bool); case noData; case needsUpdate }`, `struct PrayerEntry: TimelineEntry { let date: Date; let content: WidgetContent }`, `enum PrayerTimeline { static let horizonHours: Int; static let maxEntries: Int; static func entries(for result: Result<WidgetSnapshot, SnapshotLoadError>?, now: Date, calendar: Calendar) -> [PrayerEntry] }`

- [ ] **Step 1: Write the failing test**

`ios/RunnerTests/PrayerTimelineTests.swift`:

```swift
import XCTest

final class PrayerTimelineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func snapshot(days: [String]) -> WidgetSnapshot {
        WidgetSnapshot(
            schemaVersion: 1,
            locationLabel: "Kadıköy, İstanbul",
            days: days.map {
                SnapshotDay(
                    date: $0,
                    times: SnapshotTimes(
                        fajr: "04:12", sunrise: "05:52", dhuhr: "13:15",
                        asr: "16:58", maghrib: "20:26", isha: "21:58"
                    )
                )
            }
        )
    }

    private func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 8, day: day, hour: hour, minute: minute
        ))!
    }

    func testNoSnapshotProducesSingleNoDataEntry() {
        let entries = PrayerTimeline.entries(for: nil, now: at(25, 14, 0), calendar: calendar)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].content, .noData)
    }

    func testUnsupportedSchemaProducesNeedsUpdateEntry() {
        let entries = PrayerTimeline.entries(
            for: .failure(.unsupportedSchema), now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertEqual(entries[0].content, .needsUpdate)
    }

    func testFirstEntryStartsAtNow() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-25", "2026-08-26"])),
            now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertEqual(entries.first?.date, at(25, 14, 0))
    }

    func testEntriesLandOnPrayerBoundaries() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-25", "2026-08-26"])),
            now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertEqual(entries[1].date, at(25, 16, 58))  // İkindi
        XCTAssertEqual(entries[2].date, at(25, 20, 26))  // Akşam
    }

    func testHorizonIsCapped() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: [
                "2026-08-25", "2026-08-26", "2026-08-27", "2026-08-28",
            ])),
            now: at(25, 14, 0), calendar: calendar
        )
        XCTAssertLessThanOrEqual(entries.count, PrayerTimeline.maxEntries)
        let horizon = at(25, 14, 0).addingTimeInterval(
            TimeInterval(PrayerTimeline.horizonHours * 3600)
        )
        XCTAssertTrue(entries.allSatisfy { $0.date <= horizon })
    }

    func testStaleSnapshotIsMarked() {
        let entries = PrayerTimeline.entries(
            for: .success(snapshot(days: ["2026-08-20"])),
            now: at(25, 14, 0), calendar: calendar
        )
        guard case let .ready(_, _, _, _, isStale) = entries[0].content else {
            return XCTFail("ready bekleniyordu, gelen: \(entries[0].content)")
        }
        XCTAssertTrue(isStale)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:RunnerTests/PrayerTimelineTests 2>&1 | tail -20
```
Expected: FAIL — `cannot find 'PrayerTimeline' in scope`

- [ ] **Step 3: Write minimal implementation**

`ios/EzanVaktiWidget/Timeline/PrayerTimelineProvider.swift`:

```swift
import WidgetKit

enum WidgetContent: Equatable {
    case ready(
        next: PrayerSlot,
        day: SnapshotDay,
        phase: DayPhase,
        locationLabel: String,
        isStale: Bool
    )
    /// Widget kurulmus ama uygulama hic acilmamis.
    case noData
    /// Payload'in semasi widget'in bildiginden yeni.
    case needsUpdate
}

struct PrayerEntry: TimelineEntry {
    let date: Date
    let content: WidgetContent
}

enum PrayerTimeline {
    /// Timeline'in ilerisini gorme mesafesi. Payload 7 gun tasisa da her
    /// reload'da yalnizca bu kadari uretilir; gerisi bir sonraki reload'da
    /// tazelenir.
    static let horizonHours = 48

    static let maxEntries = 14

    /// Geri sayim icin giris uretilmez — `Text(date, style: .timer)` sistem
    /// tarafindan reload'suz cizilir. Giris yalnizca **icerik degistiginde**,
    /// yani her vakit gecisinde uretilir; vakit gecisi ayni zamanda gun dilimi
    /// sinirdir, dolayisiyla tek liste hem siradaki vakti hem gradyani tasir.
    static func entries(
        for result: Result<WidgetSnapshot, SnapshotLoadError>?,
        now: Date,
        calendar: Calendar
    ) -> [PrayerEntry] {
        guard let result else {
            return [PrayerEntry(date: now, content: .noData)]
        }

        switch result {
        case .failure(.unsupportedSchema):
            return [PrayerEntry(date: now, content: .needsUpdate)]
        case .failure(.malformed):
            return [PrayerEntry(date: now, content: .noData)]
        case .success(let snapshot):
            return entries(for: snapshot, now: now, calendar: calendar)
        }
    }

    private static func entries(
        for snapshot: WidgetSnapshot,
        now: Date,
        calendar: Calendar
    ) -> [PrayerEntry] {
        let slots = NextPrayer.slots(days: snapshot.days, calendar: calendar)
        let horizon = now.addingTimeInterval(TimeInterval(horizonHours * 3600))

        var moments = [now]
        moments.append(contentsOf: slots.map(\.date).filter { $0 > now && $0 <= horizon })
        moments = Array(moments.prefix(maxEntries))

        return moments.compactMap { moment in
            content(for: snapshot, slots: slots, at: moment, calendar: calendar)
                .map { PrayerEntry(date: moment, content: $0) }
        }
    }

    private static func content(
        for snapshot: WidgetSnapshot,
        slots: [PrayerSlot],
        at moment: Date,
        calendar: Calendar
    ) -> WidgetContent? {
        guard let next = slots.first(where: { $0.date > moment }) else {
            // Pencere tukendi: son bilinen gunu bayat olarak goster.
            guard let last = snapshot.days.last, let lastSlot = slots.last else { return nil }
            return .ready(
                next: lastSlot,
                day: last,
                phase: DayPhase.fallback,
                locationLabel: snapshot.locationLabel,
                isStale: true
            )
        }

        guard let day = snapshot.days.first(where: { dayDate in
            guard let parsed = NextPrayer.slots(days: [dayDate], calendar: calendar).first
            else { return false }
            return calendar.isDate(parsed.date, inSameDayAs: moment)
        }) ?? snapshot.days.last else { return nil }

        let isStale = !slots.contains { calendar.isDate($0.date, inSameDayAs: moment) }

        return .ready(
            next: next,
            day: day,
            phase: DayPhase.resolve(slots: slots, now: moment),
            locationLabel: snapshot.locationLabel,
            isStale: isStale
        )
    }
}
```

- [ ] **Step 4: Target membership'i ayarla**

`PrayerTimelineProvider.swift` → Target Membership: `EzanVaktiWidgetExtension` **ve** `RunnerTests`.

⚠️ Bu dosya `import WidgetKit` içeriyor; `RunnerTests` (uygulama test host'u) WidgetKit'e link edebilir, `TimelineEntry` protokolü orada da mevcuttur. Link hatası çıkarsa `PrayerEntry`'nin `TimelineEntry` uyumunu ayrı bir dosyaya (`PrayerEntry+TimelineEntry.swift`, yalnızca extension üyeliği) taşı ve bu dosyadan `import WidgetKit`'i kaldır.

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:RunnerTests/PrayerTimelineTests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`, 6 test.

- [ ] **Step 6: Commit**

```bash
git add ios/EzanVaktiWidget/Timeline/PrayerTimelineProvider.swift ios/RunnerTests/PrayerTimelineTests.swift ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: widget timeline uretimi

Geri sayim icin giris uretilmiyor; girisler yalnizca vakit gecislerinde."
```

---

### Task 11: Swift — durum görünümleri ve ortak zemin

Boş/bayat durumlar ve gradyan zemin. Görünümler bunun üstüne kurulacağı için önce bu.

**Files:**
- Create: `ios/EzanVaktiWidget/Views/PhaseBackground.swift`
- Create: `ios/EzanVaktiWidget/Views/MessageView.swift`

**Interfaces:**
- Consumes: `Palette` (Task 9), `DayPhase` (Task 8)
- Produces: `struct PhaseBackground: View { init(phase: DayPhase) }`, `struct MessageView: View { init(text: String, phase: DayPhase) }`

- [ ] **Step 1: Zemin görünümünü yaz**

`ios/EzanVaktiWidget/Views/PhaseBackground.swift`:

```swift
import SwiftUI

/// Ana ekran ailelerinin ortak zemini.
///
/// Gradyan `GeometryReader` icinde cizilir cunku yaricap kisa kenara baglidir
/// (`Palette.backgroundGradient(in:)`).
struct PhaseBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let phase: DayPhase

    var body: some View {
        GeometryReader { geometry in
            Palette.forPhase(phase, colorScheme: colorScheme)
                .backgroundGradient(in: geometry.size)
        }
    }
}
```

- [ ] **Step 2: Mesaj görünümünü yaz**

`ios/EzanVaktiWidget/Views/MessageView.swift`:

```swift
import SwiftUI

/// Veri olmadiginda cizilen gorunum. Bos kutu birakmiyoruz: kullanici ne
/// yapmasi gerektigini okuyabilmeli.
struct MessageView: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    let phase: DayPhase

    var body: some View {
        let palette = Palette.forPhase(phase, colorScheme: colorScheme)

        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(palette.textSecondary)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 3: Derlemeyi doğrula**

Run: `flutter build ios --no-codesign`
Expected: `Xcode build done.`

- [ ] **Step 4: Commit**

```bash
git add ios/EzanVaktiWidget/Views ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: widget zemin ve mesaj gorunumleri"
```

---

### Task 12: Swift — ana ekran görünümleri (small + medium)

**Files:**
- Create: `ios/EzanVaktiWidget/Views/SmallView.swift`
- Create: `ios/EzanVaktiWidget/Views/MediumView.swift`

**Interfaces:**
- Consumes: `WidgetContent`, `PrayerEntry` (Task 10); `Palette` (Task 9); `PhaseBackground`, `MessageView` (Task 11); `NextPrayer` (Task 8)
- Produces: `struct SmallView: View { init(entry: PrayerEntry) }`, `struct MediumView: View { init(entry: PrayerEntry) }`

- [ ] **Step 1: Small görünümünü yaz**

`ios/EzanVaktiWidget/Views/SmallView.swift`:

```swift
import SwiftUI

struct SmallView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: PrayerEntry

    var body: some View {
        switch entry.content {
        case .noData:
            MessageView(text: "Vakitler için uygulamayı aç", phase: .fallback)
        case .needsUpdate:
            MessageView(text: "Uygulamayı güncelleyin", phase: .fallback)
        case let .ready(next, _, phase, locationLabel, isStale):
            ready(next: next, phase: phase, locationLabel: locationLabel, isStale: isStale)
        }
    }

    private func ready(
        next: PrayerSlot, phase: DayPhase, locationLabel: String, isStale: Bool
    ) -> some View {
        let palette = Palette.forPhase(phase, colorScheme: colorScheme)

        return VStack(alignment: .leading, spacing: 2) {
            Text(next.name.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.accent)

            Text(next.date, format: .dateTime.hour().minute())
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.textPrimary)

            // Sistem bu metni reload'suz, saniye saniye kendisi ciziyor.
            Text(next.date, style: .timer)
                .font(.system(size: 26, weight: .light).monospacedDigit())
                .foregroundStyle(palette.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(isStale ? "Güncel değil" : locationLabel)
                .font(.system(size: 10))
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isStale ? 0.55 : 1)
        .padding(2)
    }
}
```

- [ ] **Step 2: Medium görünümünü yaz**

`ios/EzanVaktiWidget/Views/MediumView.swift`:

```swift
import SwiftUI

struct MediumView: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: PrayerEntry

    var body: some View {
        switch entry.content {
        case .noData:
            MessageView(text: "Vakitler için uygulamayı aç", phase: .fallback)
        case .needsUpdate:
            MessageView(text: "Uygulamayı güncelleyin", phase: .fallback)
        case let .ready(next, day, phase, locationLabel, isStale):
            ready(next: next, day: day, phase: phase,
                  locationLabel: locationLabel, isStale: isStale)
        }
    }

    private func ready(
        next: PrayerSlot, day: SnapshotDay, phase: DayPhase,
        locationLabel: String, isStale: Bool
    ) -> some View {
        let palette = Palette.forPhase(phase, colorScheme: colorScheme)
        let slots = NextPrayer.slots(days: [day], calendar: .current)

        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(next.name.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.accent)

                Text(next.date, format: .dateTime.hour().minute())
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)

                Text(next.date, style: .timer)
                    .font(.system(size: 22, weight: .light).monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(isStale ? "Güncel değil" : locationLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 3) {
                ForEach(slots, id: \.name) { slot in
                    HStack {
                        Text(slot.name)
                            .font(.system(size: 11, weight: slot == next ? .semibold : .regular))
                        Spacer(minLength: 6)
                        Text(slot.date, format: .dateTime.hour().minute())
                            .font(.system(size: 11, weight: slot == next ? .semibold : .regular)
                                .monospacedDigit())
                    }
                    .foregroundStyle(
                        slot == next ? palette.accent
                            : (slot.date < entry.date ? palette.textSecondary.opacity(0.5)
                                                      : palette.textPrimary)
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .opacity(isStale ? 0.55 : 1)
        .padding(2)
    }
}
```

- [ ] **Step 3: Derlemeyi doğrula**

Run: `flutter build ios --no-codesign`
Expected: `Xcode build done.`

- [ ] **Step 4: Commit**

```bash
git add ios/EzanVaktiWidget/Views ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: ana ekran widget gorunumleri (small + medium)"
```

---

### Task 13: Swift — kilit ekranı görünümleri ve widget kaydı

Widget'ı çalışır hale getiren task. Bittiğinde cihazda kurulabilir.

**Files:**
- Create: `ios/EzanVaktiWidget/Views/RectangularView.swift`
- Create: `ios/EzanVaktiWidget/Views/InlineView.swift`
- Modify: `ios/EzanVaktiWidget/EzanVaktiWidget.swift` (Xcode şablonunun ürettiği dosya — tamamen değiştirilir)
- Modify: `ios/EzanVaktiWidget/EzanVaktiWidgetBundle.swift` (şablon üretti)

**Interfaces:**
- Consumes: Task 10, 11, 12'nin tamamı
- Produces: `struct EzanVaktiWidget: Widget` (`kind = "EzanVaktiWidget"`), `struct Provider: TimelineProvider`

- [ ] **Step 1: Rectangular görünümünü yaz**

`ios/EzanVaktiWidget/Views/RectangularView.swift`:

```swift
import SwiftUI

/// Kilit ekrani ailelerinde sistem tek renge indirger; gradyan denenmez.
struct RectangularView: View {
    let entry: PrayerEntry

    var body: some View {
        switch entry.content {
        case .noData:
            Text("Vakitler için uygulamayı aç").font(.system(size: 12))
        case .needsUpdate:
            Text("Uygulamayı güncelleyin").font(.system(size: 12))
        case let .ready(next, _, _, _, isStale):
            VStack(alignment: .leading, spacing: 1) {
                Text(isStale ? "GÜNCEL DEĞİL" : "SIRADAKİ")
                    .font(.system(size: 10, weight: .semibold))
                    .widgetAccentable()

                HStack(spacing: 4) {
                    Text(next.name)
                    Text(next.date, format: .dateTime.hour().minute())
                        .monospacedDigit()
                }
                .font(.system(size: 15, weight: .semibold))

                Text(next.date, style: .timer)
                    .font(.system(size: 13).monospacedDigit())
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 2: Inline görünümünü yaz**

`ios/EzanVaktiWidget/Views/InlineView.swift`:

```swift
import SwiftUI

/// Saatin ustundeki tek satir. Sistem tek renk ve tek satirla sinirlar.
struct InlineView: View {
    let entry: PrayerEntry

    var body: some View {
        switch entry.content {
        case .noData:
            Text("Ezan Vakti · uygulamayı aç")
        case .needsUpdate:
            Text("Ezan Vakti · güncelle")
        case let .ready(next, _, _, _, _):
            ViewThatFits {
                HStack(spacing: 4) {
                    Text(next.name)
                    Text(next.date, format: .dateTime.hour().minute())
                    Text("·")
                    Text(next.date, style: .timer)
                }
                HStack(spacing: 4) {
                    Text(next.name)
                    Text(next.date, format: .dateTime.hour().minute())
                }
            }
        }
    }
}
```

- [ ] **Step 3: Widget'ı ve provider'ı yaz**

`ios/EzanVaktiWidget/EzanVaktiWidget.swift` (şablonun içeriğini tamamen sil, bunu yaz):

```swift
import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    private func placeholderEntry() -> PrayerEntry {
        PrayerEntry(date: Date(), content: .noData)
    }

    func placeholder(in context: Context) -> PrayerEntry {
        placeholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        let entries = PrayerTimeline.entries(
            for: SnapshotStore.load(), now: Date(), calendar: .current
        )
        completion(entries.first ?? placeholderEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now = Date()
        let entries = PrayerTimeline.entries(
            for: SnapshotStore.load(), now: now, calendar: .current
        )

        // Timeline tukendiginde WidgetKit yeniden sorar; snapshot 7 gun
        // tasidigi icin uygulama hic acilmasa bile taze 48 saat uretilir.
        let refreshAt = entries.last?.date
            ?? now.addingTimeInterval(60 * 60)

        completion(Timeline(
            entries: entries.isEmpty ? [placeholderEntry()] : entries,
            policy: .after(refreshAt)
        ))
    }
}

struct EzanVaktiWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    private var phase: DayPhase {
        if case let .ready(_, _, phase, _, _) = entry.content { return phase }
        return .fallback
    }

    var body: some View {
        content
            .widgetURL(URL(string: "ezanvakti://home"))
            .containerBackground(for: .widget) {
                switch family {
                case .systemSmall, .systemMedium:
                    PhaseBackground(phase: phase)
                default:
                    AccessoryWidgetBackground()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall:          SmallView(entry: entry)
        case .systemMedium:         MediumView(entry: entry)
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryInline:      InlineView(entry: entry)
        default:                    SmallView(entry: entry)
        }
    }
}

struct EzanVaktiWidget: Widget {
    /// Dart tarafindaki `HomeWidgetPublisher.widgetKind` ile birebir ayni
    /// olmali; aksi halde reload hicbir widget'a ulasmaz.
    let kind = "EzanVaktiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            EzanVaktiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Ezan Vakti")
        .description("Sıradaki vakit ve geri sayım.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline,
        ])
    }
}
```

- [ ] **Step 4: Bundle'ı doğrula**

`ios/EzanVaktiWidget/EzanVaktiWidgetBundle.swift` şunu içermeli (şablon Live Activity eklediyse sil):

```swift
import SwiftUI
import WidgetKit

@main
struct EzanVaktiWidgetBundle: WidgetBundle {
    var body: some Widget {
        EzanVaktiWidget()
    }
}
```

- [ ] **Step 5: Derleme ve tüm Swift testleri**

Run:
```bash
flutter build ios --no-codesign && \
xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20
```
Expected: `Xcode build done.` ve `** TEST SUCCEEDED **`.

- [ ] **Step 6: Cihazda elle doğrula**

Ekrem gerçek iPhone'a kurup şunları kontrol eder:
1. Ana ekrana small ve medium widget eklenebiliyor mu
2. Kilit ekranına rectangular ve inline eklenebiliyor mu
3. Geri sayım kilit ekranında da ilerliyor mu (spec §9 R2 — asıl ölçüm bu)
4. Vakit geçtiğinde widget sıradaki vakte atlıyor mu
5. Gün dilimi değişince gradyan değişiyor mu
6. Widget'a dokunmak uygulamayı açıyor mu

R2 olumsuz çıkarsa: `InlineView`'daki `Text(next.date, style: .timer)` kaldırılır, yalnızca vakit adı + saat kalır.

- [ ] **Step 7: Commit**

```bash
git add ios/EzanVaktiWidget ios/Runner.xcodeproj/project.pbxproj
git commit -m "feat: kilit ekrani gorunumleri ve widget kaydi

Dort aile: systemSmall, systemMedium, accessoryRectangular, accessoryInline."
```

---

### Task 14: Fastlane imzalama güncellemesi

Bu atlanırsa CI yeşil görünür, TestFlight yükleme aşamasında patlar.

**Files:**
- Modify: `ios/fastlane/Fastfile:6-7,37-59`

**Interfaces:**
- Consumes: Task 6'daki portal profilleri
- Produces: (yok — build altyapısı)

- [ ] **Step 1: Widget sabitlerini ekle**

`ios/fastlane/Fastfile`, `APP_BUNDLE_ID` satırının altına:

```ruby
  WIDGET_BUNDLE_ID = "com.ekrembulbul.ezanvakti.EzanVaktiWidget"
  WIDGET_PROFILE_NAME = "com.ekrembulbul.ezanvakti.EzanVaktiWidget AppStore"
  WIDGET_TARGET = "EzanVaktiWidgetExtension"
```

- [ ] **Step 2: Widget target'ı için ikinci imza çağrısı ekle**

Mevcut `update_code_signing_settings` bloğunun **hemen ardına**:

```ruby
    # Widget extension ayri bir bundle ID; Runner'in profili gecmez. Global
    # xcargs yerine yine hedefe ozel ayar veriliyor ki Pod framework'leri
    # profil dayatmasindan etkilenmesin.
    update_code_signing_settings(
      use_automatic_signing: false,
      path: "Runner.xcodeproj",
      team_id: ENV["APPLE_TEAM_ID"],
      code_sign_identity: "Apple Distribution",
      bundle_identifier: WIDGET_BUNDLE_ID,
      profile_name: WIDGET_PROFILE_NAME,
      targets: [WIDGET_TARGET],
    )
```

- [ ] **Step 3: Export map'ine widget'ı ekle**

`build_app` içindeki `provisioningProfiles` haritasını şununla değiştir:

```ruby
        provisioningProfiles: {
          APP_BUNDLE_ID => APPSTORE_PROFILE_NAME,
          WIDGET_BUNDLE_ID => WIDGET_PROFILE_NAME,
        },
```

- [ ] **Step 4: Sözdizimini doğrula**

Run: `cd ios && bundle exec fastlane lanes && cd ..`
Expected: `beta` lane'i listelenir, sözdizimi hatası yok.

⚠️ Gerçek imzalama yalnızca CI'da (`macos-15`, gerçek secret'larla) doğrulanabilir. Yerelde sözdizimi kontrolü yeterli; ilk `ios-v*` tag'inde workflow izlenmeli.

- [ ] **Step 5: Commit**

```bash
git add ios/fastlane/Fastfile
git commit -m "chore: fastlane imzasina widget extension eklendi

Widget ayri bir bundle ID; Runner'in profili gecmiyor. Ikinci profil hem imza
ayarina hem export map'ine eklendi."
```

---

### Task 15: Dokümantasyon

**Files:**
- Modify: `docs/ROADMAP.md` (widget maddesini tamamlandıya taşı)
- Modify: `docs/ARCHITECTURE.md` (yeni feature ve veri akışı)
- Modify: `CHANGELOG.md`
- Modify: `pubspec.yaml` (sürüm)

**Interfaces:**
- Consumes: (yok)
- Produces: (yok)

- [ ] **Step 1: ARCHITECTURE.md'ye feature'ı ekle**

`lib/features` tablosuna satır ekle:

```markdown
| `home_widget` | `home_widget_publisher` (App Group'a yazma) | `widget_snapshot`, `widget_snapshot_builder`, `widget_snapshot_publish` |
```

"Veri akışı" bölümüne yeni bir alt başlık ekle:

```markdown
## Veri akışı — iOS widget

```
_loadPrayerData (home_page.dart)
        │  basarili yukleme sonrasi
        ▼
WidgetSnapshotBuilder (saf) ──▶ WidgetPublisher ──▶ App Group (tek JSON)
                                                            │
                                            WidgetKit extension (ayri process)
```

- Payload 7 gun tasir; widget uygulama acilmadan da dogru kalir.
- Saatler `"HH:mm"` olarak yazilir, offset'li ISO degil — uygulama vakitleri
  timezone tasimayan cihaz-yerel wall-clock olarak uretiyor.
- Yayinlama hatasi yukari sizmaz; vakit gosterimi widget yuzunden bozulmaz.
- Siradaki vakit ve gun dilimi **Swift tarafinda** hesaplanir; boylece widget
  uygulama gunlerce acilmasa da ilerler.
```

- [ ] **Step 2: ROADMAP.md'de widget maddesini taşı**

"🧩 Ana ekran widget'ı" bölümünü "Planlanan özellikler"den çıkar, tamamlananlar bölümüne şu özetle taşı:

```markdown
### 🧩 iOS widget — tamamlandı
Ana ekran (small/medium) ve kilit ekranı (rectangular/inline) widget'ları.
Veri App Group'a tek JSON snapshot olarak yazılıyor; sıradaki vakit ve gün
dilimi Swift tarafında hesaplanıyor. Tasarım:
[spec](superpowers/specs/2026-08-25-ios-widget-design.md).
Android widget'ı hâlâ planlı — aynı snapshot şemasından beslenecek.
```

- [ ] **Step 3: CHANGELOG ve sürüm**

`pubspec.yaml`'da `version: 0.4.1+25` → `version: 0.5.0+26`.

`CHANGELOG.md` başına:

```markdown
## 0.5.0

### Eklendi
- iOS ana ekran widget'ı (küçük ve orta boy): sıradaki vakit, geri sayım ve
  günün vakit şeridi.
- iOS kilit ekranı widget'ı (dikdörtgen ve satır içi).
- Widget, uygulamanın gün dilimi paletini kullanıyor; vakit geçtikçe zemin
  değişiyor.

### Değişti
- iOS minimum sürümü 13.0'dan 17.0'a yükseldi. Kilit ekranı widget'ları için
  gerekli; iOS 13–16 çalıştıran cihazlar bu sürümden itibaren güncelleme
  alamayacak.
```

- [ ] **Step 4: Son doğrulama**

Run: `flutter analyze && flutter test && flutter build ios --no-codesign`
Expected: üçü de temiz.

- [ ] **Step 5: Commit**

```bash
git add docs/ CHANGELOG.md pubspec.yaml
git commit -m "docs: iOS widget icin dokumantasyon ve 0.5.0 surumu"
```

---

## Notlar

**Sıra bağımlılıkları:** Task 1–2 saf Dart, herhangi bir zamanda yapılabilir. Task 3 (deployment target) Task 4'ten önce gelmeli çünkü `home_widget` paketi iOS sürüm tabanına bakar. Task 6 (Xcode target'ı) Task 7–13'ün tamamının ön koşulu. Task 14 yalnızca Task 6 tamamlandıktan sonra anlamlı.

**Elle yapılacak işler (kodla halledilemez):** Task 6 Step 1 (Apple portalı), Task 6 Step 2–4 (Xcode target sihirbazı), Task 13 Step 6 (cihaz testi).

**Bilinen belirsizlikler:** Task 8 Step 5 (`Calendar.current` / test takvimi çakışması), Task 10 Step 4 (`WidgetKit` import'unun test target'ında linklenmesi), Task 13 Step 6 (`.timer`'ın kilit ekranındaki davranışı). Üçü de adımın içinde alternatifiyle birlikte yazılı.
