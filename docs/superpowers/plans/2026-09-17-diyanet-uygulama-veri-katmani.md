# Diyanet Uygulama — Veri Katmanı (Plan B1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Bu projede kullanıcı tercihi **inline yürütme**dir.

**Goal:** Uygulamanın veri katmanını Diyanet il/ilçe modeline taşımak: konum ilçe kimliği taşır, vakitler `vakit-api`'den yıllık dosya olarak Hicri ile gelir, Hicri tarih hesaplanmaz veriden okunur, mevcut kayıtlar için migrasyon servisi hazır olur. Ekranlar bu planda değişmez (Plan B2); uygulama derlenir ve mevcut davranış korunur (Aladhan hâlâ kayıtlı sağlayıcı).

**Architecture:** `Location` ve `PrayerTime` modelleri genişler (nullable yeni alanlar; eski sütunlar kalır), SQLite şema 15 olur. Yeni `PlacesApi` (arama/çözümleme) ve `DiyanetProvider` (yıllık vakit + ETag) `vakit-api`'nin `/v1` sözleşmesini tüketir; depo, sağlayıcının döndürdüğü tüm günleri önbelleğe yazıp istenen pencereyi döner. Hicri tüketicileri (`HijriFormatter`, `RamadanMode`, `ReligiousDays`, üst bar, widget, bildirim) `PrayerTime.hijri`'den beslenir; `hijri` paketi kalkar. `LocationMigrationService` kayıtlı konumları sunucuda eşler; ekranı B2'de.

**Tech Stack:** Flutter/Dart (mevcut sürüm), `http` (+ `package:http/testing.dart` `MockClient` testlerde), `sqflite` + `sqflite_common_ffi` (migration testleri), mevcut `AppLogger`, `ApiException`, `ParseException`.

**Spec:** `docs/superpowers/specs/2026-09-17-diyanet-uygulama-design.md` (UYG.1, UYG.4, UYG.5, UYG.7'nin servis kısmı, B8). Sunucu sözleşmesi: `docs/superpowers/specs/2026-09-15-vakit-api-sunucu-design.md` VAK.1.

## Global Constraints

- Kod ve tanımlayıcılar İngilizce, yorumlar/commit'ler Türkçe; kullanıcıya görünen metin Dart'a yazılmaz (bu planda yeni metin yok).
- Her task sonunda: `dart format lib test`, `flutter analyze` temiz, ilgili testler ve sonunda `flutter test` tüm suite yeşil. Commit mesajları Türkçe Conventional Commits + `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`. Branch `feature/vakit-api`.
- Sunucu sözleşmesi (VAK.1): `GET /v1/prayer-times/{cityId}/{year}` → `{schemaVersion, source, complete, days:[{date:"YYYY-MM-DD", hijri:{day,month,year,monthName}, fajr..isha:"HH:MM", ...}]}`; `GET /v1/places/search?q=&limit=` → `{query, results:[{id,name,stateName,displayName,stateId,countryId,isCentre,latitude,longitude,qiblaAngle,qiblaAngleMagnetic,distanceToKaaba,matchedAlias?}]}`; `GET /v1/places/resolve?lat=&lon=` → `{city:{...}, distanceKm}`; hata zarfı `{error:{code,message}}`; 404 `NOT_FOUND` (yıl yayınlanmamış) / `NO_COVERAGE`, 503 `NOT_READY`, ETag + `If-None-Match` → 304.
- ADR 0004: önbellek **ham** veri tutar; ± düzeltme ve türetilmiş vakitler yalnız okuma anında (`PrayerTimesRepository._tuned`). Yeni sağlayıcı bu kapıyı değiştirmez.
- Hicri: veri yoksa tahmin yok (B5). `hijri` paketi bu planın sonunda `pubspec`'ten çıkar.
- Sunucu adresi `--dart-define=VAKIT_API_BASE_URL=...`; varsayılan yerel geliştirme `http://127.0.0.1:8080` (üretim adresi kurulum sonrası; sürüm derlemesi define geçer — DEVELOPMENT.md notu Task 8).
- Eski `method/school/latitude_adjustment` sütunları ve model alanları bu planda **kalır** (B2 kaldırır); yeni kod bunları okumaz.
- Migration blokları `if (oldVersion < N)` artan sırada (test kilitliyor).

---

## Dosya yapısı

```
lib/core/models/hijri_date.dart                 HijriDate (gün/ay/yıl), JSON
lib/core/models/prayer_time.dart                + hijri alanı
lib/core/models/location.dart                   + cityId/stateId/countryId/displayLabel, isMapped
lib/core/config/vakit_api_config.dart           sunucu adresi (dart-define)
lib/core/utils/turkish_fold.dart                foldTR (küçük harf + ASCII katlama; migrasyon güveni)
lib/features/prayer_times/data/sqlite_storage.dart      şema 15, hijri sütunları, konum sütunları
lib/features/prayer_times/data/diyanet_provider.dart    /v1/prayer-times istemcisi (ETag, 304, 404, retry)
lib/features/prayer_times/domain/prayer_times_repository.dart  tüm günleri yaz, pencereyi dön
lib/features/location/data/places_api.dart      PlaceMatch, search, resolve, hata sınıfları
lib/features/location/domain/location_migration_service.dart   kayıtlı konumları eşleme
lib/core/utils/hijri_formatter.dart             formatHijri(HijriDate)
lib/features/ramadan/domain/ramadan_mode.dart   isActiveFor/dayOfRamadanFor(HijriDate?)
lib/core/data/religious_days.dart               fromDays(Iterable<PrayerTime>)
lib/presentation/widgets/home/home_top_bar.dart HomeDateLine(hijri:)
lib/presentation/screens/home_screen.dart       hijri prop'u geçir
lib/features/home_widget/domain/widget_snapshot{,_builder}.dart  hijri String? / PrayerTime.hijri
lib/features/notifications/domain/notification_scheduler.dart   ReligiousDays.fromDays
lib/presentation/pages/home_page.dart           Ramazan modu ve prompt yılı veriden
lib/presentation/screens/prayer_tracking_screen.dart            Ramazan bayrağı veriden
test/...                                        her task kendi testlerini listeler
```

---

### Task 1: `HijriDate` modeli ve `PrayerTime.hijri`

**Files:**
- Create: `lib/core/models/hijri_date.dart`, `test/models/hijri_date_test.dart`
- Modify: `lib/core/models/prayer_time.dart`
- Test: `test/models/prayer_time_hijri_test.dart`

**Interfaces:**
- Produces: `class HijriDate { final int day, month, year; const HijriDate({required day, required month, required year}); toJson(); factory fromJson(Map); ==; hashCode; toString → "d/m/yyyy" }`; `PrayerTime.hijri` (`HijriDate?`), `PrayerTime.toJson()` içinde `'hijri': hijri?.toJson()`, `PrayerTime.fromJson` hem iç içe `hijri` nesnesini hem düz `hijri_day/hijri_month/hijri_year` sütunlarını okur (SQLite satırı), `copyWith(hijri:)`.

- [ ] **Step 1: Failing tests**

`test/models/hijri_date_test.dart`:
```dart
import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON gidis-donus', () {
    const h = HijriDate(day: 4, month: 4, year: 1448);
    expect(HijriDate.fromJson(h.toJson()), h);
    expect(h.toJson(), {'day': 4, 'month': 4, 'year': 1448});
  });

  test('gecersiz ay/gun FormatException', () {
    expect(() => HijriDate.fromJson({'day': 31, 'month': 4, 'year': 1448}), throwsFormatException);
    expect(() => HijriDate.fromJson({'day': 1, 'month': 13, 'year': 1448}), throwsFormatException);
    expect(() => HijriDate.fromJson({'day': 1, 'month': 1}), throwsFormatException);
  });

  test('esitlik ve hash', () {
    expect(const HijriDate(day: 1, month: 9, year: 1447), const HijriDate(day: 1, month: 9, year: 1447));
    expect(const HijriDate(day: 1, month: 9, year: 1447).hashCode, const HijriDate(day: 1, month: 9, year: 1447).hashCode);
    expect(const HijriDate(day: 1, month: 9, year: 1447), isNot(const HijriDate(day: 2, month: 9, year: 1447)));
  });
}
```

`test/models/prayer_time_hijri_test.dart`:
```dart
import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:flutter_test/flutter_test.dart';

PrayerTime sample({HijriDate? hijri}) => PrayerTime(
  fajr: DateTime(2026, 9, 15, 5, 11),
  sunrise: DateTime(2026, 9, 15, 6, 37),
  dhuhr: DateTime(2026, 9, 15, 13, 4),
  asr: DateTime(2026, 9, 15, 16, 35),
  maghrib: DateTime(2026, 9, 15, 19, 22),
  isha: DateTime(2026, 9, 15, 20, 43),
  date: DateTime(2026, 9, 15),
  hijri: hijri,
);

void main() {
  test('hijri JSON gidis-donus (ic ice nesne)', () {
    final t = sample(hijri: const HijriDate(day: 4, month: 4, year: 1448));
    final json = t.toJson();
    expect(json['hijri'], {'day': 4, 'month': 4, 'year': 1448});
    expect(PrayerTime.fromJson(json), t);
  });

  test('hijri olmadan JSON null yazar ve okur', () {
    final t = sample();
    expect(t.toJson()['hijri'], isNull);
    expect(PrayerTime.fromJson(t.toJson()).hijri, isNull);
  });

  test('SQLite satirindaki duz sutunlardan hijri okunur', () {
    final row = sample().toJson()
      ..remove('hijri')
      ..addAll({'hijri_day': 4, 'hijri_month': 4, 'hijri_year': 1448});
    expect(PrayerTime.fromJson(row).hijri, const HijriDate(day: 4, month: 4, year: 1448));
    final partial = sample().toJson()
      ..remove('hijri')
      ..addAll({'hijri_day': null, 'hijri_month': null, 'hijri_year': null});
    expect(PrayerTime.fromJson(partial).hijri, isNull);
  });

  test('copyWith hijri tasir ve esitlige girer', () {
    final a = sample();
    final b = a.copyWith(hijri: const HijriDate(day: 1, month: 1, year: 1448));
    expect(b.hijri, isNotNull);
    expect(a, isNot(b));
  });
}
```

- [ ] **Step 2: Run, fail**

Run: `flutter test test/models/hijri_date_test.dart test/models/prayer_time_hijri_test.dart`
Expected: derleme hatası (`hijri_date.dart` yok, `hijri` parametresi yok)

- [ ] **Step 3: Implement**

`lib/core/models/hijri_date.dart`:
```dart
/// Diyanet takvimindeki Hicri tarih (gün 1–30, ay 1–12).
///
/// Hesaplanmaz; sunucudan gelen vakit satırıyla birlikte saklanır. Ay adı
/// çeviriden gelir (`HijriFormatter`), model ad taşımaz.
class HijriDate {
  final int day;
  final int month;
  final int year;

  const HijriDate({required this.day, required this.month, required this.year});

  Map<String, dynamic> toJson() => {'day': day, 'month': month, 'year': year};

  factory HijriDate.fromJson(Map<String, dynamic> json) {
    final day = json['day'];
    final month = json['month'];
    final year = json['year'];
    if (day is! int || month is! int || year is! int) {
      throw const FormatException('hijri date requires int day/month/year');
    }
    if (day < 1 || day > 30 || month < 1 || month > 12) {
      throw FormatException('hijri date out of range: $day/$month/$year');
    }
    return HijriDate(day: day, month: month, year: year);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HijriDate &&
          runtimeType == other.runtimeType &&
          day == other.day &&
          month == other.month &&
          year == other.year;

  @override
  int get hashCode => Object.hash(day, month, year);

  @override
  String toString() => '$day/$month/$year';
}
```

`lib/core/models/prayer_time.dart` — alan, kurucu, JSON, copyWith, eşitlik:
```dart
import 'hijri_date.dart';

class PrayerTime {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime date;

  /// Günün Diyanet Hicri tarihi; eski önbellek satırlarında ve Hicri
  /// vermeyen kaynaklarda `null` (arayüz Hicri satırını gizler).
  final HijriDate? hijri;

  const PrayerTime({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
    this.hijri,
  });

  Map<String, dynamic> toJson() {
    return {
      'fajr': fajr.toIso8601String(),
      'sunrise': sunrise.toIso8601String(),
      'dhuhr': dhuhr.toIso8601String(),
      'asr': asr.toIso8601String(),
      'maghrib': maghrib.toIso8601String(),
      'isha': isha.toIso8601String(),
      'date': date.toIso8601String(),
      'hijri': hijri?.toJson(),
    };
  }

  factory PrayerTime.fromJson(Map<String, dynamic> json) {
    return PrayerTime(
      fajr: DateTime.parse(json['fajr'] as String),
      sunrise: DateTime.parse(json['sunrise'] as String),
      dhuhr: DateTime.parse(json['dhuhr'] as String),
      asr: DateTime.parse(json['asr'] as String),
      maghrib: DateTime.parse(json['maghrib'] as String),
      isha: DateTime.parse(json['isha'] as String),
      date: DateTime.parse(json['date'] as String),
      hijri: _hijriFrom(json),
    );
  }

  /// Hem JSON'daki iç içe `hijri` nesnesini hem SQLite satırındaki düz
  /// `hijri_day/hijri_month/hijri_year` sütunlarını kabul eder.
  static HijriDate? _hijriFrom(Map<String, dynamic> json) {
    final nested = json['hijri'];
    if (nested is Map<String, dynamic>) return HijriDate.fromJson(nested);
    final day = json['hijri_day'];
    final month = json['hijri_month'];
    final year = json['hijri_year'];
    if (day is int && month is int && year is int) {
      return HijriDate(day: day, month: month, year: year);
    }
    return null;
  }

  PrayerTime copyWith({
    DateTime? fajr,
    DateTime? sunrise,
    DateTime? dhuhr,
    DateTime? asr,
    DateTime? maghrib,
    DateTime? isha,
    DateTime? date,
    HijriDate? hijri,
  }) {
    return PrayerTime(
      fajr: fajr ?? this.fajr,
      sunrise: sunrise ?? this.sunrise,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
      date: date ?? this.date,
      hijri: hijri ?? this.hijri,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerTime &&
          runtimeType == other.runtimeType &&
          fajr == other.fajr &&
          sunrise == other.sunrise &&
          dhuhr == other.dhuhr &&
          asr == other.asr &&
          maghrib == other.maghrib &&
          isha == other.isha &&
          date == other.date &&
          hijri == other.hijri;

  @override
  int get hashCode =>
      Object.hash(fajr, sunrise, dhuhr, asr, maghrib, isha, date, hijri);
}
```

- [ ] **Step 4: Run, pass**

Run: `dart format lib/core/models test/models && flutter analyze && flutter test test/models/`
Expected: PASS (mevcut `models_test.dart` de geçer — `hijri` opsiyonel)

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/hijri_date.dart lib/core/models/prayer_time.dart test/models/hijri_date_test.dart test/models/prayer_time_hijri_test.dart
git commit -m "feat(model): PrayerTime Diyanet Hicri tarihini taşır (HijriDate)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: `Location` — Diyanet ilçe kimliği alanları

**Files:**
- Modify: `lib/core/models/location.dart`
- Test: `test/models/location_diyanet_test.dart`

**Interfaces:**
- Produces: `Location.cityId/stateId/countryId` (`int?`), `Location.displayLabel` (`String?`), `bool get isMapped => cityId != null`; JSON anahtarları `cityId, stateId, countryId, displayLabel`; `displayName` sırası: `customName` → `displayLabel` → mevcut "ilçe, il" kuralı; `copyWith` yeni alanları alır; eşitlik/hash yeni alanları kapsar. Eski alanlar (`method/school/latitudeAdjustmentMethod`) bu planda **dokunulmaz**.

- [ ] **Step 1: Failing tests**

`test/models/location_diyanet_test.dart`:
```dart
import 'package:ezanvakti/core/models/location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapped = Location(
    id: 'diyanet-9547',
    province: 'İstanbul',
    district: 'Şile',
    latitude: 41.1758,
    longitude: 29.6127,
    cityId: 9547,
    stateId: 539,
    countryId: 2,
    displayLabel: 'Şile, İstanbul',
  );

  test('isMapped yalniz cityId varsa', () {
    expect(mapped.isMapped, isTrue);
    expect(const Location(id: 'x', province: 'A', district: 'B').isMapped, isFalse);
  });

  test('displayName: customName > displayLabel > ilce, il', () {
    expect(mapped.displayName, 'Şile, İstanbul');
    expect(mapped.copyWith(customName: 'Ev').displayName, 'Ev');
    expect(const Location(id: 'x', province: 'İstanbul', district: 'Kadıköy').displayName, 'Kadıköy, İstanbul');
    expect(const Location(id: 'c', province: 'İstanbul', district: 'İstanbul', displayLabel: 'İstanbul (Merkez)').displayName, 'İstanbul (Merkez)');
  });

  test('JSON gidis-donus yeni alanlari korur, eski JSON okunur', () {
    expect(Location.fromJson(mapped.toJson()), mapped);
    final legacy = Location.fromJson({
      'id': 'gps', 'province': 'İstanbul', 'district': 'Şile',
      'latitude': 41.1, 'longitude': 29.6, 'type': 'gps', 'customName': null,
      'method': 13, 'school': 0, 'latitudeAdjustmentMethod': null,
    });
    expect(legacy.isMapped, isFalse);
    expect(legacy.cityId, isNull);
    expect(legacy.displayLabel, isNull);
  });

  test('copyWith ve esitlik yeni alanlari kapsar', () {
    final changed = mapped.copyWith(cityId: 9541, displayLabel: 'İstanbul (Merkez)');
    expect(changed.cityId, 9541);
    expect(changed, isNot(mapped));
    expect(mapped.copyWith(), mapped);
  });
}
```

- [ ] **Step 2: Run, fail**

Run: `flutter test test/models/location_diyanet_test.dart`
Expected: derleme hatası (`cityId` yok)

- [ ] **Step 3: Implement** — `lib/core/models/location.dart` içinde:

Alanlar (mevcut `latitudeAdjustmentMethod` alanından sonra):
```dart
  /// Diyanet ilçe kimliği (`vakit-api` `cityId`). `null` = henüz eşlenmemiş
  /// (eski kayıt); vakit çekilemez, migrasyon bekler.
  final int? cityId;

  /// Diyanet il kimliği.
  final int? stateId;

  /// Diyanet ülke kimliği (Türkiye = 2).
  final int? countryId;

  /// Sunucunun ürettiği görünen ad ("Şile, İstanbul" / "İstanbul (Merkez)").
  final String? displayLabel;
```
Kurucuya `this.cityId, this.stateId, this.countryId, this.displayLabel` eklenir.

```dart
  /// Konum bir Diyanet ilçesine bağlı mı?
  bool get isMapped => cityId != null;
```

`displayName` başına (customName kontrolünden sonra):
```dart
    if (displayLabel != null && displayLabel!.isNotEmpty) {
      return displayLabel!;
    }
```

`toJson` sonuna: `'cityId': cityId, 'stateId': stateId, 'countryId': countryId, 'displayLabel': displayLabel,`
`fromJson` sonuna: `cityId: json['cityId'] as int?, stateId: json['stateId'] as int?, countryId: json['countryId'] as int?, displayLabel: json['displayLabel'] as String?,`
`copyWith` parametreleri `int? cityId, int? stateId, int? countryId, String? displayLabel` ve gövdede `cityId: cityId ?? this.cityId` vb.
`==` ve `hashCode` listelerine dört alan eklenir.

- [ ] **Step 4: Run, pass**

Run: `dart format lib/core/models test/models && flutter analyze && flutter test test/models/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/location.dart test/models/location_diyanet_test.dart
git commit -m "feat(model): Location Diyanet il/ilçe kimliği ve görünen ad taşır

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: SQLite şema 15 — Hicri sütunları ve konum kimlikleri

**Files:**
- Modify: `lib/features/prayer_times/data/sqlite_storage.dart` (`version: 15`, `_onCreate`, `onUpgrade`, `savePrayerTimes`, `getSavedLocations`, `saveLocation`, `updateLocation`)
- Modify: `test/storage/schema_migration_test.dart` (`createV8Schema`'ya `prayer_times`, `upgradeFrom` → 15, yeni testler)

**Interfaces:**
- Produces: `prayer_times` tablosunda `hijri_day INTEGER, hijri_month INTEGER, hijri_year INTEGER`; `locations` tablosunda `city_id INTEGER, state_id INTEGER, country_id INTEGER, display_label TEXT`. Okuma `PrayerTime.fromJson(row)` düz sütunları çözer (Task 1).

- [ ] **Step 1: Failing tests** — `test/storage/schema_migration_test.dart`

`createV8Schema` içine (locations'tan önce) v1 `prayer_times` tablosunu ekle:
```dart
    await db.execute('''
      CREATE TABLE prayer_times (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location_id TEXT NOT NULL,
        date TEXT NOT NULL,
        fajr TEXT NOT NULL,
        sunrise TEXT NOT NULL,
        dhuhr TEXT NOT NULL,
        asr TEXT NOT NULL,
        maghrib TEXT NOT NULL,
        isha TEXT NOT NULL,
        UNIQUE(location_id, date)
      )
    ''');
```
`upgradeFrom` içinde `await storage.onUpgrade(db, oldVersion, 14);` → `15`. Yeni testler:
```dart
  test('v15: vakit satiri hicri sutunlarini, konum ilce kimligini tasir', () async {
    final db = await upgradeFrom(8);
    addTearDown(db.close);

    final prayerColumns = (await db.rawQuery("PRAGMA table_info('prayer_times')"))
        .map((c) => c['name'])
        .toSet();
    expect(prayerColumns, containsAll(<String>['hijri_day', 'hijri_month', 'hijri_year']));

    final locationColumns = (await db.rawQuery("PRAGMA table_info('locations')"))
        .map((c) => c['name'])
        .toSet();
    expect(locationColumns, containsAll(<String>['city_id', 'state_id', 'country_id', 'display_label']));
  });

  test('v15 yukseltmesi eski konumu cityId null ile korur', () async {
    final storage = SqliteStorage();
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(db.close);
    await createV8Schema(db);
    await db.insert('locations', {
      'id': 'gps', 'province': 'İstanbul', 'district': 'Şile', 'latitude': 41.1,
      'longitude': 29.6, 'type': 'gps', 'created_at': DateTime(2026).toIso8601String(),
    });
    await storage.onUpgrade(db, 8, 15);
    final row = (await db.query('locations')).single;
    expect(row['city_id'], isNull);
    expect(row['display_label'], isNull);
    expect(row['district'], 'Şile');
  });
```

- [ ] **Step 2: Run, fail**

Run: `flutter test test/storage/schema_migration_test.dart`
Expected: FAIL — `hijri_day` sütunu yok

- [ ] **Step 3: Implement** — `sqlite_storage.dart`

`_initDatabase`: `version: 15`.

`_onCreate` `prayer_times`: `isha TEXT NOT NULL,` satırından sonra
```
        hijri_day INTEGER,
        hijri_month INTEGER,
        hijri_year INTEGER,
```
`_onCreate` `locations`: `latitude_adjustment INTEGER` satırından sonra `,` ekleyip
```
        city_id INTEGER,
        state_id INTEGER,
        country_id INTEGER,
        display_label TEXT
```

`onUpgrade` sonuna (v14 bloğundan sonra):
```dart
    if (oldVersion < 15) {
      // Diyanet il/ilçe modeli: konum ilçe kimliği, vakit satırı Hicri tarih
      // taşır. Eski kayıtlar NULL kalır; migrasyon servisi eşler, Hicri
      // yeniden çekimle dolar.
      await db.execute('ALTER TABLE locations ADD COLUMN city_id INTEGER');
      await db.execute('ALTER TABLE locations ADD COLUMN state_id INTEGER');
      await db.execute('ALTER TABLE locations ADD COLUMN country_id INTEGER');
      await db.execute('ALTER TABLE locations ADD COLUMN display_label TEXT');
      await db.execute('ALTER TABLE prayer_times ADD COLUMN hijri_day INTEGER');
      await db.execute('ALTER TABLE prayer_times ADD COLUMN hijri_month INTEGER');
      await db.execute('ALTER TABLE prayer_times ADD COLUMN hijri_year INTEGER');
    }
```

`savePrayerTimes` batch insert map'ine:
```dart
        'hijri_day': prayerTime.hijri?.day,
        'hijri_month': prayerTime.hijri?.month,
        'hijri_year': prayerTime.hijri?.year,
```

`getSavedLocations` map'ine (`latitudeAdjustmentMethod` satırından sonra):
```dart
        cityId: row['city_id'] as int?,
        stateId: row['state_id'] as int?,
        countryId: row['country_id'] as int?,
        displayLabel: row['display_label'] as String?,
```
`saveLocation` ve `updateLocation` map'lerine:
```dart
      'city_id': location.cityId,
      'state_id': location.stateId,
      'country_id': location.countryId,
      'display_label': location.displayLabel,
```

- [ ] **Step 4: Run, pass**

Run: `dart format lib test && flutter analyze && flutter test test/storage/ test/prayer_times/prayer_times_data_layer_test.dart test/location/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/prayer_times/data/sqlite_storage.dart test/storage/schema_migration_test.dart
git commit -m "feat(storage): şema 15 — vakitlerde Hicri sütunları, konumlarda Diyanet kimlikleri

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Sunucu adresi, Türkçe katlama ve `PlacesApi` (arama / GPS çözümleme)

**Files:**
- Create: `lib/core/config/vakit_api_config.dart`, `lib/core/utils/turkish_fold.dart`, `lib/features/location/data/places_api.dart`
- Test: `test/core/turkish_fold_test.dart`, `test/location/places_api_test.dart`

**Interfaces:**
- Produces:
  - `VakitApiConfig.baseUrl` (`String`, `String.fromEnvironment('VAKIT_API_BASE_URL', defaultValue: 'http://127.0.0.1:8080')`).
  - `String foldTR(String s)` — Türkçe küçük harf (İ→i, I→ı) + ASCII katlama (ç→c, ğ→g, ı→i, ö→o, ş→s, ü→u, â/î/û) + harf/rakam dışını atar.
  - `class PlaceMatch { int id; String name; String stateName; String displayName; int stateId; int countryId; bool isCentre; double? latitude; double? longitude; double? qiblaAngle; String? matchedAlias; factory fromJson(Map); Location toLocation({required LocationType type, String? id, double? latitude, double? longitude}) }` — `toLocation`: manuel için `id = 'diyanet-<cityId>'`, koordinat = ilçe merkezi; GPS için `id = 'gps'`, koordinat = verilen cihaz koordinatı; `province = stateName`, `district = name`, `displayLabel = displayName`, `cityId/stateId/countryId` dolu.
  - `class ResolveResult { PlaceMatch city; double distanceKm; }`
  - `class PlacesApi { PlacesApi({required http.Client client, String baseUrl = VakitApiConfig.baseUrl}); Future<List<PlaceMatch>> search(String query, {int limit = 10}); Future<ResolveResult> resolve({required double latitude, required double longitude}); }`
  - Hatalar: `class NoCoverageException implements Exception` (404 `NO_COVERAGE`), `class PlacesNotReadyException implements Exception` (503), diğer 200-dışı → mevcut `ApiException(statusCode, context:)`; bozuk gövde → mevcut `ParseException`. Zaman aşımı 15 s. Sorgu `Uri.encodeQueryComponent` ile.

- [ ] **Step 1: Failing tests**

`test/core/turkish_fold_test.dart`:
```dart
import 'package:ezanvakti/core/utils/turkish_fold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Turkce kucuk harf ve ASCII katlama', () {
    expect(foldTR('İSTANBUL'), 'istanbul');
    expect(foldTR('IĞDIR'), 'igdir');
    expect(foldTR('Şile'), 'sile');
    expect(foldTR('CUBUK'), foldTR('Çubuk'));
    expect(foldTR('Elâzığ'), foldTR('ELAZIĞ'));
    expect(foldTR('Büyük Orhan'), 'buyukorhan');
    expect(foldTR('Kemer (B)'), 'kemerb');
  });
}
```

`test/location/places_api_test.dart`:
```dart
import 'dart:convert';

import 'package:ezanvakti/core/exceptions/api_exception.dart';
import 'package:ezanvakti/core/exceptions/parse_exception.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const sileJson = {
  'id': 9547, 'name': 'Şile', 'stateName': 'İstanbul', 'displayName': 'Şile, İstanbul',
  'stateId': 539, 'countryId': 2, 'isCentre': false, 'latitude': 41.1758, 'longitude': 29.6127,
  'qiblaAngle': 151.0, 'qiblaAngleMagnetic': 146.0, 'distanceToKaaba': 2400.0,
};

PlacesApi apiWith(Future<http.Response> Function(http.Request) handler) =>
    PlacesApi(client: MockClient(handler), baseUrl: 'https://api.test');

void main() {
  test('search: sorguyu kodlar, sonuclari PlaceMatch yapar', () async {
    late http.Request seen;
    final api = apiWith((req) async {
      seen = req;
      return http.Response(jsonEncode({'query': 'şile', 'results': [sileJson, {...sileJson, 'id': 9541, 'name': 'İstanbul', 'displayName': 'İstanbul (Merkez)', 'isCentre': true, 'matchedAlias': 'Kadıköy'}]}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final results = await api.search('şile', limit: 5);
    expect(seen.url.toString(), 'https://api.test/v1/places/search?q=%C5%9File&limit=5');
    expect(results, hasLength(2));
    expect(results.first.id, 9547);
    expect(results.first.displayName, 'Şile, İstanbul');
    expect(results.last.matchedAlias, 'Kadıköy');
    expect(results.last.isCentre, isTrue);
  });

  test('search: 503 NOT_READY ozel hata, 500 ApiException, bozuk govde ParseException', () async {
    final notReady = apiWith((_) async => http.Response('{"error":{"code":"NOT_READY","message":"x"}}', 503));
    expect(() => notReady.search('a'), throwsA(isA<PlacesNotReadyException>()));
    final server = apiWith((_) async => http.Response('boom', 500));
    expect(() => server.search('a'), throwsA(isA<ApiException>()));
    final broken = apiWith((_) async => http.Response('not json', 200));
    expect(() => broken.search('a'), throwsA(isA<ParseException>()));
  });

  test('resolve: en yakin ilce ve mesafe', () async {
    late http.Request seen;
    final api = apiWith((req) async {
      seen = req;
      return http.Response(jsonEncode({'city': sileJson, 'distanceKm': 1.2}), 200);
    });
    final r = await api.resolve(latitude: 41.17, longitude: 29.6);
    expect(seen.url.queryParameters, {'lat': '41.17', 'lon': '29.6'});
    expect(r.city.id, 9547);
    expect(r.distanceKm, 1.2);
  });

  test('resolve: 404 NO_COVERAGE ozel hata', () async {
    final api = apiWith((_) async => http.Response('{"error":{"code":"NO_COVERAGE","message":"x"}}', 404));
    expect(() => api.resolve(latitude: 48.85, longitude: 2.35), throwsA(isA<NoCoverageException>()));
  });

  test('toLocation: manuel ilce merkezi koordinati, GPS cihaz koordinati', () {
    final match = PlaceMatch.fromJson(sileJson);
    final manual = match.toLocation(type: LocationType.manual);
    expect(manual.id, 'diyanet-9547');
    expect(manual.cityId, 9547);
    expect(manual.stateId, 539);
    expect(manual.countryId, 2);
    expect(manual.province, 'İstanbul');
    expect(manual.district, 'Şile');
    expect(manual.displayLabel, 'Şile, İstanbul');
    expect(manual.latitude, 41.1758);
    final gps = match.toLocation(type: LocationType.gps, id: 'gps', latitude: 41.2, longitude: 29.7);
    expect(gps.id, 'gps');
    expect(gps.type, LocationType.gps);
    expect(gps.latitude, 41.2);
    expect(gps.cityId, 9547);
  });
}
```

- [ ] **Step 2: Run, fail**

Run: `flutter test test/core/turkish_fold_test.dart test/location/places_api_test.dart`
Expected: derleme hatası

- [ ] **Step 3: Implement**

`lib/core/config/vakit_api_config.dart`:
```dart
/// vakit-api sunucu adresi.
///
/// Derleme zamanında verilir: `--dart-define=VAKIT_API_BASE_URL=https://api.<domain>`.
/// Varsayılan yerel geliştirme sunucusudur (Android emülatöründe host için
/// `http://10.0.2.2:8080` geç). Sürüm derlemeleri bu değeri mutlaka geçer.
class VakitApiConfig {
  const VakitApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'VAKIT_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );
}
```

`lib/core/utils/turkish_fold.dart`:
```dart
/// Türkçe adları karşılaştırma anahtarına indirir: İ→i, I→ı kurallarıyla küçük
/// harf, sonra ASCII katlama (ç→c, ğ→g, ı→i, ö→o, ş→s, ü→u, şapkalar) ve
/// harf/rakam dışı her şey atılır. Sunucunun arama anahtarıyla aynı kural;
/// migrasyonda "kayıtlı ad" ile "sunucu adı" böyle karşılaştırılır.
String foldTR(String input) {
  var s = input.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  const map = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
    'â': 'a', 'î': 'i', 'û': 'u',
  };
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    final mapped = map[ch] ?? ch;
    final code = mapped.codeUnitAt(0);
    final isAlnum = (code >= 0x61 && code <= 0x7a) || (code >= 0x30 && code <= 0x39);
    if (isAlnum) buffer.write(mapped);
  }
  return buffer.toString();
}
```

`lib/features/location/data/places_api.dart`:
```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/vakit_api_config.dart';
import '../../../core/exceptions/api_exception.dart';
import '../../../core/exceptions/parse_exception.dart';
import '../../../core/models/location.dart';
import '../../../core/utils/app_logger.dart';

/// Sunucu koordinatın yakınında Diyanet ilçesi bulamadı (Türkiye dışı).
class NoCoverageException implements Exception {
  @override
  String toString() => 'NoCoverageException: no Diyanet district near coordinates';
}

/// Sunucu ilçe listesini henüz senkronlamadı (503 NOT_READY); kısa süre sonra dene.
class PlacesNotReadyException implements Exception {
  @override
  String toString() => 'PlacesNotReadyException: place list not ready';
}

/// `/v1/places/*` sonuç satırı; adlar ekranda gösterilecek yazımdadır.
class PlaceMatch {
  final int id;
  final String name;
  final String stateName;
  final String displayName;
  final int stateId;
  final int countryId;
  final bool isCentre;
  final double? latitude;
  final double? longitude;
  final double? qiblaAngle;
  final String? matchedAlias;

  const PlaceMatch({
    required this.id,
    required this.name,
    required this.stateName,
    required this.displayName,
    required this.stateId,
    required this.countryId,
    required this.isCentre,
    this.latitude,
    this.longitude,
    this.qiblaAngle,
    this.matchedAlias,
  });

  factory PlaceMatch.fromJson(Map<String, dynamic> json) {
    return PlaceMatch(
      id: json['id'] as int,
      name: json['name'] as String,
      stateName: json['stateName'] as String,
      displayName: json['displayName'] as String,
      stateId: json['stateId'] as int,
      countryId: json['countryId'] as int,
      isCentre: json['isCentre'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      qiblaAngle: (json['qiblaAngle'] as num?)?.toDouble(),
      matchedAlias: json['matchedAlias'] as String?,
    );
  }

  /// Manuel seçimde koordinat ilçe merkezidir; GPS'te çağıran cihaz
  /// koordinatını ve sabit `gps` kimliğini verir.
  Location toLocation({
    required LocationType type,
    String? id,
    double? latitude,
    double? longitude,
  }) {
    final cityId = this.id; // parametre `id` alanı gölgeliyor
    return Location(
      id: id ?? 'diyanet-$cityId',
      province: stateName,
      district: name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type,
      cityId: cityId,
      stateId: stateId,
      countryId: countryId,
      displayLabel: displayName,
    );
  }
}

class ResolveResult {
  final PlaceMatch city;
  final double distanceKm;
  const ResolveResult({required this.city, required this.distanceKm});
}

class PlacesApi {
  final http.Client client;
  final String baseUrl;
  static const Duration _timeout = Duration(seconds: 15);

  PlacesApi({required this.client, this.baseUrl = VakitApiConfig.baseUrl});

  Future<List<PlaceMatch>> search(String query, {int limit = 10}) async {
    final uri = Uri.parse('$baseUrl/v1/places/search').replace(
      queryParameters: {'q': query, 'limit': '$limit'},
    );
    final body = await _get(uri);
    final results = body['results'];
    if (results is! List) {
      throw ParseException(message: 'search response has no results list', context: 'PlacesApi.search');
    }
    return results
        .map((e) => PlaceMatch.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ResolveResult> resolve({required double latitude, required double longitude}) async {
    final uri = Uri.parse('$baseUrl/v1/places/resolve').replace(
      queryParameters: {'lat': '$latitude', 'lon': '$longitude'},
    );
    final body = await _get(uri);
    final city = body['city'];
    if (city is! Map<String, dynamic>) {
      throw ParseException(message: 'resolve response has no city', context: 'PlacesApi.resolve');
    }
    return ResolveResult(
      city: PlaceMatch.fromJson(city),
      distanceKm: (body['distanceKm'] as num?)?.toDouble() ?? 0,
    );
  }

  /// 200 → JSON nesnesi. 404 NO_COVERAGE ve 503 ayrı hatalar; diğer durumlar
  /// [ApiException]. Gövde JSON değilse [ParseException].
  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await client.get(uri).timeout(_timeout);
    if (response.statusCode == 503) throw PlacesNotReadyException();
    if (response.statusCode == 404 && _errorCode(response.body) == 'NO_COVERAGE') {
      throw NoCoverageException();
    }
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, context: 'GET ${uri.path}');
    }
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException('not an object');
      return decoded;
    } on FormatException catch (e, stackTrace) {
      AppLogger().parseError(
        context: 'PlacesApi._get',
        error: e,
        stackTrace: stackTrace,
        additionalData: {'path': uri.path},
      );
      throw ParseException(message: 'places response is not JSON', originalError: e, stackTrace: stackTrace, context: 'PlacesApi._get');
    }
  }

  static String? _errorCode(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded['error'] is Map) {
        return (decoded['error'] as Map)['code'] as String?;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
```
- [ ] **Step 4: Run, pass**

Run: `dart format lib test && flutter analyze && flutter test test/core/turkish_fold_test.dart test/location/places_api_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/config lib/core/utils/turkish_fold.dart lib/features/location/data/places_api.dart test/core/turkish_fold_test.dart test/location/places_api_test.dart
git commit -m "feat(location): vakit-api yer arama ve GPS çözümleme istemcisi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: `DiyanetProvider` ve depo uyumu (yılı yaz, pencereyi dön)

**Files:**
- Create: `lib/features/prayer_times/data/diyanet_provider.dart`, `test/prayer_times/diyanet_provider_test.dart`
- Modify: `lib/features/prayer_times/domain/prayer_times_repository.dart` (`getPrayerTimes`: tümünü yaz, pencereyi dön)
- Test: `test/prayer_times/repository_window_test.dart`

**Interfaces:**
- Consumes: `PrayerTimeProvider` arayüzü (değişmez), `LocalStorage.getSetting/setSetting` (ETag), `Location.cityId`, `HijriDate`.
- Produces: `class DiyanetProvider implements PrayerTimeProvider { DiyanetProvider({required http.Client client, required LocalStorage storage, String baseUrl = VakitApiConfig.baseUrl}); }` — `fetchPrayerTimes` istenen aralığın yıllarını (en fazla 2) çeker, **o yılların tüm günlerini** döner; 304'te o yılın günleri önbellekten okunur (`storage.getPrayerTimes(locationId: location.id, ...)`); 404 → o yıl boş; 429/5xx → 3 deneme (1 s, 2 s, 4 s); `location.cityId == null` → `LocationNotMappedException`. `fetchDailyPrayerTime` yılı çekip günü döner. `class LocationNotMappedException implements Exception { final String locationId; }`. ETag anahtarı `etag:<cityId>:<year>`.
- Depo: `getPrayerTimes` uzak sonucun **tamamını** önbelleğe yazar, çağırana **[startDate, endDate]** içindekileri döner (Aladhan zaten pencereyi döndürdüğü için davranışı değişmez).

- [ ] **Step 1: Failing tests**

`test/prayer_times/diyanet_provider_test.dart`:
```dart
import 'dart:convert';

import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/prayer_times/data/diyanet_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

const sile = Location(id: 'diyanet-9547', province: 'İstanbul', district: 'Şile', cityId: 9547, stateId: 539, countryId: 2);

Map<String, dynamic> day(String date, int hDay, int hMonth, int hYear) => {
  'date': date,
  'hijri': {'day': hDay, 'month': hMonth, 'year': hYear, 'monthName': 'x'},
  'fajr': '05:11', 'sunrise': '06:37', 'dhuhr': '13:04', 'asr': '16:35', 'maghrib': '19:22', 'isha': '20:43',
  'astronomicalSunrise': null, 'astronomicalSunset': null, 'qiblaTime': null, 'gmtOffset': 3,
};

String yearBody(int year, List<Map<String, dynamic>> days) => jsonEncode({
  'schemaVersion': 1, 'source': 'diyanet', 'generatedAt': '2026-09-17T00:00:00Z',
  'cityId': 9547, 'year': year, 'complete': days.length >= 365, 'days': days,
});

void main() {
  late FakeStorage storage;
  setUp(() => storage = FakeStorage());

  DiyanetProvider provider(Future<http.Response> Function(http.Request) handler) =>
      DiyanetProvider(client: MockClient(handler), storage: storage, baseUrl: 'https://api.test');

  test('yilin gunlerini HH:MM ve Hicri ile PrayerTime yapar, ETag saklar', () async {
    final requests = <http.Request>[];
    final p = provider((req) async {
      requests.add(req);
      return http.Response(yearBody(2026, [day('2026-09-15', 4, 4, 1448), day('2026-09-16', 5, 4, 1448)]), 200,
          headers: {'etag': '"abc"', 'content-type': 'application/json; charset=utf-8'});
    });
    final times = await p.fetchPrayerTimes(location: sile, startDate: DateTime(2026, 9, 15), endDate: DateTime(2026, 9, 15));
    expect(requests.single.url.toString(), 'https://api.test/v1/prayer-times/9547/2026');
    expect(times, hasLength(2), reason: 'saglayici yilin tamamini doner; pencereyi depo keser');
    expect(times.first.date, DateTime(2026, 9, 15));
    expect(times.first.maghrib, DateTime(2026, 9, 15, 19, 22));
    expect(times.first.hijri, const HijriDate(day: 4, month: 4, year: 1448));
    expect(await storage.getSetting('etag:9547:2026'), '"abc"');
  });

  test('If-None-Match gonderir; 304te onbellekteki yili doner', () async {
    await storage.setSetting('etag:9547:2026', '"abc"');
    await storage.savePrayerTimes([prayerTimeFor(DateTime(2026, 9, 15))], sile.id);
    late http.Request seen;
    final p = provider((req) async {
      seen = req;
      return http.Response('', 304);
    });
    final times = await p.fetchPrayerTimes(location: sile, startDate: DateTime(2026, 9, 15), endDate: DateTime(2026, 9, 15));
    expect(seen.headers['If-None-Match'] ?? seen.headers['if-none-match'], '"abc"');
    expect(times, hasLength(1));
  });

  test('pencere iki yila yayilirsa iki istek', () async {
    final years = <String>[];
    final p = provider((req) async {
      years.add(req.url.pathSegments.last);
      final y = int.parse(req.url.pathSegments.last);
      return http.Response(yearBody(y, [day('$y-01-01', 1, 1, 1448)]), 200);
    });
    await p.fetchPrayerTimes(location: sile, startDate: DateTime(2026, 12, 28), endDate: DateTime(2027, 1, 5));
    expect(years, ['2026', '2027']);
  });

  test('404: yil yayinlanmamis → bos liste', () async {
    final p = provider((_) async => http.Response('{"error":{"code":"NOT_FOUND","message":"x"}}', 404));
    expect(await p.fetchPrayerTimes(location: sile, startDate: DateTime(2028, 1, 1), endDate: DateTime(2028, 1, 2)), isEmpty);
  });

  test('cityId olmayan konum LocationNotMappedException', () async {
    final p = provider((_) async => http.Response('', 200));
    expect(
      () => p.fetchPrayerTimes(location: const Location(id: 'x', province: 'a', district: 'b'), startDate: DateTime(2026), endDate: DateTime(2026)),
      throwsA(isA<LocationNotMappedException>()),
    );
  });

  test('5xx uc denemeden sonra ApiException; araya 200 girerse basarir', () async {
    var calls = 0;
    final p = provider((_) async {
      calls++;
      if (calls < 3) return http.Response('boom', 503);
      return http.Response(yearBody(2026, [day('2026-09-15', 4, 4, 1448)]), 200);
    });
    final times = await p.fetchPrayerTimes(location: sile, startDate: DateTime(2026, 9, 15), endDate: DateTime(2026, 9, 15));
    expect(times, hasLength(1));
    expect(calls, 3);
  });

  test('fetchDailyPrayerTime gunu doner, yoksa null', () async {
    final p = provider((_) async => http.Response(yearBody(2026, [day('2026-09-15', 4, 4, 1448)]), 200));
    final t = await p.fetchDailyPrayerTime(location: sile, date: DateTime(2026, 9, 15, 10));
    expect(t?.date, DateTime(2026, 9, 15));
    expect(await p.fetchDailyPrayerTime(location: sile, date: DateTime(2026, 9, 16)), isNull);
  });
}
```

`test/prayer_times/repository_window_test.dart`:
```dart
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// Yilin tamamini donen saglayici (DiyanetProvider gibi).
class YearProvider extends FakeProvider {
  @override
  Future<List<PrayerTime>> fetchPrayerTimes({required Location location, required DateTime startDate, required DateTime endDate}) async {
    fetchCount++;
    return List.generate(365, (i) => prayerTimeFor(DateTime(2026, 1, 1 + i)));
  }
}

void main() {
  test('depo saglayicinin tum gunlerini onbellege yazar, yalniz pencereyi doner', () async {
    final storage = FakeStorage();
    final repo = PrayerTimesRepository(provider: YearProvider(), storage: storage);
    const loc = Location(id: 'diyanet-9547', province: 'İstanbul', district: 'Şile', cityId: 9547);
    final result = await repo.getPrayerTimes(location: loc, startDate: DateTime(2026, 9, 15), endDate: DateTime(2026, 9, 17));
    expect(result.map((t) => t.date), [DateTime(2026, 9, 15), DateTime(2026, 9, 16), DateTime(2026, 9, 17)]);
    await Future<void>.delayed(Duration.zero); // onbellek yazimi kuyrukta
    final cached = await storage.getPrayerTimes(locationId: loc.id, startDate: DateTime(2026, 1, 1), endDate: DateTime(2026, 12, 31));
    expect(cached, hasLength(365));
  });
}
```

- [ ] **Step 2: Run, fail**

Run: `flutter test test/prayer_times/diyanet_provider_test.dart test/prayer_times/repository_window_test.dart`
Expected: ilk dosya derlenmez; ikinci: `result` 365 eleman (pencere kesilmiyor)

- [ ] **Step 3: Implement sağlayıcı** — `lib/features/prayer_times/data/diyanet_provider.dart`:
```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/vakit_api_config.dart';
import '../../../core/exceptions/api_exception.dart';
import '../../../core/exceptions/parse_exception.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/interfaces/prayer_time_provider.dart';
import '../../../core/models/hijri_date.dart';
import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/utils/app_logger.dart';

/// Konum henüz bir Diyanet ilçesine bağlanmadı (eski kayıt, migrasyon bekliyor).
class LocationNotMappedException implements Exception {
  final String locationId;
  LocationNotMappedException(this.locationId);
  @override
  String toString() => 'LocationNotMappedException: $locationId has no cityId';
}

/// vakit-api `/v1/prayer-times/{cityId}/{year}` sağlayıcısı.
///
/// Yılın tamamını döner; depo hepsini önbelleğe yazıp istenen pencereyi
/// keser. ETag saklanır; 304'te yıl önbellekten okunur, ağdan gövde inmez.
/// Vakitler yerel duvar saati olarak cihaz saat diliminde kurulur (Türkiye
/// tek dilim; `gmtOffset` şimdilik kullanılmaz).
class DiyanetProvider implements PrayerTimeProvider {
  final http.Client client;
  final LocalStorage storage;
  final String baseUrl;

  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxAttempts = 3;
  static const Duration _baseBackoff = Duration(seconds: 1);

  DiyanetProvider({
    required this.client,
    required this.storage,
    this.baseUrl = VakitApiConfig.baseUrl,
  });

  @override
  String get providerName => 'Diyanet (vakit-api)';

  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final cityId = location.cityId;
    if (cityId == null) throw LocationNotMappedException(location.id);
    final result = <PrayerTime>[];
    for (var year = startDate.year; year <= endDate.year; year++) {
      result.addAll(await _fetchYear(location, cityId, year));
    }
    return result;
  }

  @override
  Future<PrayerTime?> fetchDailyPrayerTime({
    required Location location,
    required DateTime date,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final times = await fetchPrayerTimes(location: location, startDate: day, endDate: day);
    for (final t in times) {
      if (t.date.year == day.year && t.date.month == day.month && t.date.day == day.day) {
        return t;
      }
    }
    return null;
  }

  Future<List<PrayerTime>> _fetchYear(Location location, int cityId, int year) async {
    final logger = AppLogger();
    final uri = Uri.parse('$baseUrl/v1/prayer-times/$cityId/$year');
    final etagKey = 'etag:$cityId:$year';
    final headers = <String, String>{'Accept': 'application/json'};
    final etag = await storage.getSetting(etagKey);
    if (etag != null) headers['If-None-Match'] = etag;

    http.Response response;
    for (var attempt = 1; ; attempt++) {
      response = await client.get(uri, headers: headers).timeout(_timeout);
      final transient = response.statusCode == 429 || response.statusCode >= 500;
      if (!transient || attempt >= _maxAttempts) break;
      final wait = _baseBackoff * (1 << (attempt - 1));
      logger.warning('vakit-api HTTP ${response.statusCode}; retry $attempt in ${wait.inSeconds}s');
      await Future<void>.delayed(wait);
    }

    switch (response.statusCode) {
      case 200:
        final days = _parseYear(response, year);
        final newEtag = response.headers['etag'];
        if (newEtag != null && newEtag.isNotEmpty) await storage.setSetting(etagKey, newEtag);
        return days;
      case 304:
        logger.debug('vakit-api $cityId/$year unchanged; using cache');
        return storage.getPrayerTimes(
          locationId: location.id,
          startDate: DateTime(year, 1, 1),
          endDate: DateTime(year, 12, 31),
        );
      case 404:
        logger.info('vakit-api $cityId/$year not published yet');
        return const [];
      default:
        throw ApiException(response.statusCode, context: 'GET ${uri.path}');
    }
  }

  List<PrayerTime> _parseYear(http.Response response, int year) {
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException('not an object');
      final days = decoded['days'];
      if (days is! List) throw const FormatException('days missing');
      return days.map((raw) => _parseDay(raw as Map<String, dynamic>)).toList(growable: false);
    } on FormatException catch (e, stackTrace) {
      AppLogger().parseError(context: 'DiyanetProvider._parseYear', error: e, stackTrace: stackTrace, additionalData: {'year': year});
      throw ParseException(message: 'vakit-api year payload is malformed', originalError: e, stackTrace: stackTrace, context: 'DiyanetProvider._parseYear');
    } on TypeError catch (e, stackTrace) {
      AppLogger().parseError(context: 'DiyanetProvider._parseYear', error: e, stackTrace: stackTrace, additionalData: {'year': year});
      throw ParseException(message: 'vakit-api year payload has unexpected types', originalError: e, stackTrace: stackTrace, context: 'DiyanetProvider._parseYear');
    }
  }

  static PrayerTime _parseDay(Map<String, dynamic> raw) {
    final dateParts = (raw['date'] as String).split('-');
    if (dateParts.length != 3) throw FormatException('bad date ${raw['date']}');
    final date = DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
    DateTime clock(String key) {
      final parts = (raw[key] as String).split(':');
      if (parts.length < 2) throw FormatException('bad clock $key=${raw[key]}');
      return DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
    }
    final hijriRaw = raw['hijri'];
    return PrayerTime(
      date: date,
      fajr: clock('fajr'),
      sunrise: clock('sunrise'),
      dhuhr: clock('dhuhr'),
      asr: clock('asr'),
      maghrib: clock('maghrib'),
      isha: clock('isha'),
      hijri: hijriRaw is Map<String, dynamic> ? HijriDate.fromJson(hijriRaw) : null,
    );
  }
}
```

- [ ] **Step 4: Implement depo** — `prayer_times_repository.dart` `getPrayerTimes` içinde uzak çekim bloğu:
```dart
      if (remoteTimes.isNotEmpty) {
        // Önbelleğe **ham** veri yazılır; düzeltme okurken uygulanır. Sağlayıcı
        // yılın tamamını verebilir (Diyanet): hepsi yazılır, pencere kesilir.
        logger.debug('Saving ${remoteTimes.length} days to cache');
        await _saveCache(remoteTimes, location.id, generation);
      }

      return await _tuned(_withinWindow(remoteTimes, startDate, endDate));
```
ve sınıfa yardımcı:
```dart
  static List<PrayerTime> _withinWindow(List<PrayerTime> times, DateTime start, DateTime end) {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day);
    return times.where((t) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      return !day.isBefore(from) && !day.isAfter(to);
    }).toList(growable: false);
  }
```

- [ ] **Step 5: Run, pass**

Run: `dart format lib test && flutter analyze && flutter test test/prayer_times/ test/presentation/data_loader_service_test.dart test/offline/`
Expected: PASS (Aladhan pencereyi zaten döndüğü için mevcut testler etkilenmez)

- [ ] **Step 6: Commit**

```bash
git add lib/features/prayer_times/data/diyanet_provider.dart lib/features/prayer_times/domain/prayer_times_repository.dart test/prayer_times/diyanet_provider_test.dart test/prayer_times/repository_window_test.dart
git commit -m "feat(vakit): Diyanet sağlayıcısı — yıllık dosya, ETag/304, Hicri; depo pencereyi keser

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Hicri tüketicileri veriden beslenir; `hijri` paketi kalkar

**Files:**
- Modify: `lib/core/utils/hijri_formatter.dart`, `lib/features/ramadan/domain/ramadan_mode.dart`, `lib/core/data/religious_days.dart`, `lib/presentation/widgets/home/home_top_bar.dart` (`HomeDateLine`), `lib/presentation/screens/home_screen.dart:206`, `lib/features/home_widget/domain/widget_snapshot.dart` (`hijri` → `String?`), `lib/features/home_widget/domain/widget_snapshot_builder.dart`, `lib/features/notifications/domain/notification_scheduler.dart:289`, `lib/presentation/pages/home_page.dart` (`_refreshRamadanMode`, `_maybeOfferRamadanReminders`), `lib/presentation/screens/prayer_tracking_screen.dart` (`_ramadan`), `pubspec.yaml` (`hijri` çıkar)
- Test: `test/core/hijri_formatter_test.dart`, `test/ramadan/ramadan_mode_test.dart`, `test/prayer_times/religious_days_test.dart`, `test/home_widget/widget_snapshot_builder_test.dart`, `test/notifications/derived_notification_test.dart`, yeni `test/support/hijri_fixtures.dart`

**Interfaces:**
- Produces: `HijriFormatter.formatHijri(HijriDate hijri, [AppLocalizations? l10n]) → String` ("4 Rebiülahir 1448"); `RamadanMode.isActiveFor(HijriDate? hijri) → bool`, `RamadanMode.dayOfRamadanFor(HijriDate? hijri) → int?`; `ReligiousDays.fromDays(Iterable<PrayerTime> days) → List<ReligiousDay>` (Hicri'si olmayan gün yok sayılır); `HomeDateLine({required DateTime date, HijriDate? hijri})`; `WidgetSnapshotDay.hijri` → `String?`; test yardımcısı `List<PrayerTime> withSequentialHijri(List<PrayerTime> days, HijriDate first)` (30 günlük aylar, ay/yıl devri).
- Kaldırılır: `HijriFormatter.format(DateTime)`, `RamadanMode.isActive/dayOfRamadan(DateTime)`, `ReligiousDays.forRange(DateTime, DateTime)`, tüm `HijriCalendar` import'ları, `hijri` bağımlılığı.

- [ ] **Step 1: Test yardımcısı ve failing tests**

`test/support/hijri_fixtures.dart`:
```dart
import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';

/// Ardışık günlere ardışık Hicri tarih verir (30 günlük aylar, 12 ayda yıl devri).
/// Gerçek takvim 29/30 gün karışıktır; testler yalnız ay/gün eşleşmesine bakar.
List<PrayerTime> withSequentialHijri(List<PrayerTime> days, HijriDate first) {
  var day = first.day, month = first.month, year = first.year;
  final out = <PrayerTime>[];
  for (final d in days) {
    out.add(d.copyWith(hijri: HijriDate(day: day, month: month, year: year)));
    day++;
    if (day > 30) {
      day = 1;
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
  }
  return out;
}
```

`test/core/hijri_formatter_test.dart` (tamamı):
```dart
import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/core/utils/hijri_formatter.dart';
import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hijri = HijriDate(day: 4, month: 4, year: 1448);

  test('ay adı verilen çeviriden gelir', () {
    expect(HijriFormatter.formatHijri(hijri, lookupAppLocalizations(const Locale('tr'))), '4 Rebiülahir 1448');
    expect(HijriFormatter.formatHijri(hijri, lookupAppLocalizations(const Locale('en'))), '4 Rabi al-Thani 1448');
  });

  test('çeviri verilmezse kaynak dil Türkçe kullanılır, İngilizce değil', () {
    expect(HijriFormatter.formatHijri(hijri), '4 Rebiülahir 1448');
  });
}
```

`test/ramadan/ramadan_mode_test.dart` (tamamı):
```dart
import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/features/ramadan/domain/ramadan_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ramazan ayinda aktif, disinda pasif, veri yoksa pasif', () {
    expect(RamadanMode.isActiveFor(const HijriDate(day: 1, month: 9, year: 1448)), isTrue);
    expect(RamadanMode.isActiveFor(const HijriDate(day: 30, month: 9, year: 1448)), isTrue);
    expect(RamadanMode.isActiveFor(const HijriDate(day: 1, month: 10, year: 1448)), isFalse);
    expect(RamadanMode.isActiveFor(null), isFalse);
  });

  test('Ramazan gunu numarasi', () {
    expect(RamadanMode.dayOfRamadanFor(const HijriDate(day: 17, month: 9, year: 1448)), 17);
    expect(RamadanMode.dayOfRamadanFor(const HijriDate(day: 17, month: 8, year: 1448)), isNull);
    expect(RamadanMode.dayOfRamadanFor(null), isNull);
  });
}
```

`test/prayer_times/religious_days_test.dart` (tamamı):
```dart
import 'package:ezanvakti/core/data/religious_days.dart';
import 'package:ezanvakti/core/models/hijri_date.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/religious_day.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/hijri_fixtures.dart';

void main() {
  /// [start]'tan itibaren [count] gün, ilk günün Hicri'si [first].
  List<PrayerTime> days(DateTime start, int count, HijriDate first) => withSequentialHijri(
    List.generate(count, (i) => prayerTimeFor(DateTime(start.year, start.month, start.day + i))),
    first,
  );

  test('Ramazan baslangici ve Kadir Gecesi Diyanet Hicrisinden bulunur', () {
    // 8 Şubat 2027 = 1 Ramazan; 6 Mart = 27 Ramazan (30 günlük sahte ay).
    final list = ReligiousDays.fromDays(days(DateTime(2027, 2, 6), 40, const HijriDate(day: 29, month: 8, year: 1448)));
    final ramadan = list.where((d) => d.kind == ReligiousDayKind.ramadanStart).single;
    expect(ramadan.date, DateTime(2027, 2, 8));
    final qadr = list.where((d) => d.id == ReligiousDayId.qadr).single;
    expect(qadr.date, DateTime(2027, 3, 6));
    final eid = list.where((d) => d.kind == ReligiousDayKind.bayram).single;
    expect(eid.date, DateTime(2027, 3, 10)); // 30 günlük sahte Ramazan → 1 Şevval
  });

  test('Regaib: Recep ayinin ilk Persembesi', () {
    // 1 Recep = 9 Ocak 2027 (Cumartesi); ilk Perşembe 14 Ocak.
    final list = ReligiousDays.fromDays(days(DateTime(2027, 1, 9), 10, const HijriDate(day: 1, month: 7, year: 1448)));
    final regaib = list.where((d) => d.id == ReligiousDayId.regaib).single;
    expect(regaib.date, DateTime(2027, 1, 14));
    expect(list.where((d) => d.id == ReligiousDayId.regaib), hasLength(1));
  });

  test('Hicrisi olmayan gunler yok sayilir; sonuc sirali ve tekrarsiz', () {
    final base = List.generate(5, (i) => prayerTimeFor(DateTime(2027, 2, 6 + i)));
    expect(ReligiousDays.fromDays(base), isEmpty);
    final list = ReligiousDays.fromDays(days(DateTime(2026, 1, 1), 400, const HijriDate(day: 12, month: 7, year: 1447)));
    for (var i = 1; i < list.length; i++) {
      expect(list[i].date.isBefore(list[i - 1].date), isFalse);
    }
    expect(list.map((d) => '${d.date}-${d.id.name}').toSet(), hasLength(list.length));
  });
}
```

`test/home_widget/widget_snapshot_builder_test.dart` içindeki "hicri tarih" testi (satır 118–126) şu hâle gelir:
```dart
    test('hicri tarih gunun Diyanet Hicrisinden formatlanir; yoksa null', () {
      final withHijri = todayTime.copyWith(hijri: const HijriDate(day: 4, month: 4, year: 1448));
      final snapshot = WidgetSnapshotBuilder.build(location: location, prayerTimes: [withHijri], now: today);
      expect(snapshot.days.first.hijri, '4 Rebiülahir 1448');
      final without = WidgetSnapshotBuilder.build(location: location, prayerTimes: [todayTime], now: today);
      expect(without.days.first.hijri, isNull);
    });
```
(`todayTime`, `location`, `today` adları o test dosyasındaki mevcut yardımcılara göre uyarlanır; `HijriDate` import'u eklenir, `hijri_formatter` import'u kaldırılır.)

`test/notifications/derived_notification_test.dart` setUp'ı (satır 183–190) ve `window()` (satır 193–202): Hicri artık günlerden geldiği için hedef, sahte Hicri ile kurulur:
```dart
    /// Pencere bugünden başlar; 7. gün Miraç (27 Recep) olacak şekilde sahte Hicri verilir.
    late ReligiousDay target;
    late List<PrayerTime> windowDays;

    setUp(() {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      windowDays = withSequentialHijri(
        [for (var i = 0; i < 9; i++) dayAt(DateTime(start.year, start.month, start.day + i))],
        const HijriDate(day: 20, month: 7, year: 1448),
      );
      target = ReligiousDays.fromDays(windowDays).first;
      expect(target.id, ReligiousDayId.miraj);
    });

    List<PrayerTime> window() => windowDays;
```
(dosyaya `hijri_fixtures.dart` ve `HijriDate` import'u eklenir; `window()`'un eski gövdesi silinir.)

- [ ] **Step 2: Run, fail**

Run: `flutter test test/core/hijri_formatter_test.dart test/ramadan/ramadan_mode_test.dart test/prayer_times/religious_days_test.dart`
Expected: derleme hatası (`formatHijri`, `isActiveFor`, `fromDays` yok)

- [ ] **Step 3: Implement**

`lib/core/utils/hijri_formatter.dart` — `hijri` import'u kalkar, `HijriDate` gelir:
```dart
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../models/hijri_date.dart';

/// Diyanet Hicri tarihini biçimlendirir.
///
/// Ay adları çeviriden gelir; [l10n] verilmezse kaynak dil (Türkçe)
/// kullanılır (widget snapshot'ı çeviriye erişemez). Tarih hesaplanmaz:
/// değer, sunucudan gelen vakit satırıyla birlikte saklanan Hicri'dir.
class HijriFormatter {
  const HijriFormatter._();

  static final AppLocalizations _sourceLanguage = lookupAppLocalizations(const Locale('tr'));

  static String formatHijri(HijriDate hijri, [AppLocalizations? l10n]) {
    final month = _monthName(hijri.month, l10n ?? _sourceLanguage) ?? '${hijri.month}';
    return '${hijri.day} $month ${hijri.year}';
  }

  static String? _monthName(int month, AppLocalizations l10n) => switch (month) {
    1 => l10n.hijriMuharram,
    2 => l10n.hijriSafar,
    3 => l10n.hijriRabiAwwal,
    4 => l10n.hijriRabiThani,
    5 => l10n.hijriJumadaAwwal,
    6 => l10n.hijriJumadaThani,
    7 => l10n.hijriRajab,
    8 => l10n.hijriShaban,
    9 => l10n.hijriRamadan,
    10 => l10n.hijriShawwal,
    11 => l10n.hijriDhulQadah,
    12 => l10n.hijriDhulHijjah,
    _ => null,
  };
}
```

`lib/features/ramadan/domain/ramadan_mode.dart`:
```dart
import '../../../core/models/hijri_date.dart';

/// Ramazan ayının tespiti — günün Diyanet Hicri tarihinden.
///
/// Veri yoksa (eski önbellek, henüz çekilmemiş gün) Ramazan **kabul edilmez**;
/// tahmin yapılmaz.
class RamadanMode {
  const RamadanMode._();

  static const int ramadanMonth = 9;

  static bool isActiveFor(HijriDate? hijri) => hijri?.month == ramadanMonth;

  /// Ramazan'ın kaçıncı günü (1–30); Ramazan dışında ya da veri yoksa `null`.
  static int? dayOfRamadanFor(HijriDate? hijri) =>
      hijri != null && hijri.month == ramadanMonth ? hijri.day : null;
}
```

`lib/core/data/religious_days.dart` — sınıf başlığı ve `forRange` yerine:
```dart
import '../models/prayer_time.dart';
import '../models/religious_day.dart';

/// Günlerin Diyanet Hicri tarihinden dini günleri üretir.
///
/// Hicri hesaplanmaz; her gün sunucudan gelen Hicri'yi taşır. Kandil/bayram
/// günleri Hicri ay-gün sabitlerinden, Regaib Recep'in ilk Perşembesinden
/// türetilir. Hicri'si olmayan günler yok sayılır. Kayıtlar `isEstimated`
/// bayrağını korur: resmi liste (`/v1/religious-days`) gelince kaynak değişir.
class ReligiousDays {
  const ReligiousDays._();
  // _fixed tablosu aynen kalır.

  /// [days] içindeki dini günler, tarihe göre sıralı, tekrarsız.
  static List<ReligiousDay> fromDays(Iterable<PrayerTime> days) {
    final result = <ReligiousDay>[];
    final seen = <String>{};
    for (final time in days) {
      final hijri = time.hijri;
      if (hijri == null) continue;
      final day = _dayStart(time.date);
      for (final entry in _fixed) {
        if (hijri.month != entry.month || hijri.day != entry.day) continue;
        _add(result, seen, day, entry.id, entry.kind);
      }
      // Regaib: Recep ayının ilk Perşembesi (Perşembeyi Cumaya bağlayan gece).
      if (hijri.month == 7 && day.weekday == DateTime.thursday && hijri.day <= 7) {
        _add(result, seen, day, ReligiousDayId.regaib, ReligiousDayKind.kandil);
      }
    }
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }
  // _add ve _dayStart aynen; _nextDay silinir.
}
```

`home_top_bar.dart` `HomeDateLine`:
```dart
class HomeDateLine extends StatelessWidget {
  final DateTime date;

  /// Günün Diyanet Hicri tarihi; `null` ise Hicri gösterilmez (tahmin yok).
  final HijriDate? hijri;

  const HomeDateLine({super.key, required this.date, this.hijri});
  ...
          children: [
            TextSpan(text: gregorian),
            if (hijri != null) ...[
              TextSpan(text: '  ·  ', style: TextStyle(color: tokens.textTertiary)),
              TextSpan(
                text: HijriFormatter.formatHijri(hijri!, context.l10n),
                style: TextStyle(color: tokens.accent),
              ),
            ],
          ],
```
(`import '../../../core/models/hijri_date.dart';` eklenir.) `home_screen.dart:206`: `HomeDateLine(date: today.date, hijri: today.hijri),`.

`widget_snapshot.dart`: `final String? hijri;` (kurucuda `this.hijri` zorunlu kalır ama null geçilebilir → `required this.hijri` yerine `this.hijri`); doc yorumu: "Diyanet Hicri tarihi (`HijriFormatter.formatHijri`); veri yoksa null — Swift tarafı zaten opsiyonel okur." `toJson` aynı (`null` yazar).
`widget_snapshot_builder.dart` `_toDay`: `hijri: time.hijri == null ? null : HijriFormatter.formatHijri(time.hijri!, l10n),`.

`notification_scheduler.dart:289`: `final religiousDays = ReligiousDays.fromDays(byDate.values);` (`days` yerel listesi artık gereksizse kaldır).

`home_page.dart`:
```dart
  Future<void> _refreshRamadanMode() async {
    final settings = await ServiceLocator().get<LocalStorage>().getGeneralSettings();
    if (!mounted) return;
    final todayHijri = context.read<AppState>().todaysPrayerTime?.hijri;
    final active = settings.ramadanMode && RamadanMode.isActiveFor(todayHijri);
    setState(() => _ramadanActive = active);
    if (active) await _maybeOfferRamadanReminders();
  }

  Future<void> _maybeOfferRamadanReminders() async {
    final storage = ServiceLocator().get<LocalStorage>();
    final year = context.read<AppState>().todaysPrayerTime?.hijri?.year;
    if (year == null) return; // Hicri verisi yok: sormayı erteliyoruz
    final hijriYear = year.toString();
    ...
```
`HijriCalendar` import'u kalkar. `_loadPrayerData` başarı yolunun sonunda (bugünün vakti `AppState`'e yazıldıktan sonra) `await _refreshRamadanMode();` çağrısı eklenir — açılıştaki ilk çağrı veri gelmeden çalışıyor.

`prayer_tracking_screen.dart`: `bool get _ramadan => RamadanMode.isActive(_today);` yerine alan `bool _ramadan = false;`; `_load()` içine, `fastingQada` satırından sonra:
```dart
    final active = await _storage.getActiveLocation();
    final todayTime = active == null
        ? null
        : await _storage.getDailyPrayerTime(locationId: active.id, date: _today);
    final ramadan = RamadanMode.isActiveFor(todayTime?.hijri);
```
ve `setState` içinde `_ramadan = ramadan;`.

`pubspec.yaml`: `hijri: ^3.0.0` satırı silinir; `flutter pub get`.

- [ ] **Step 4: Kalan referansları tara**

Run: `grep -rn "HijriCalendar\|hijri_calendar\|HijriFormatter.format(\|RamadanMode.isActive(\|ReligiousDays.forRange" lib test`
Expected: çıktı yok. Varsa aynı kurala göre dönüştür.

- [ ] **Step 5: Run, pass**

Run: `dart format lib test && flutter analyze && flutter test`
Expected: tüm suite PASS (özellikle `test/home_widget/`, `test/notifications/`, `test/ramadan/`, `test/widgets/screens/`)

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib test
git commit -m "feat(hicri): Hicri tarih Diyanet verisinden okunur; hijri paketi kaldırıldı

Üst bar, widget, Ramazan modu ve dinî gün türetimi günün saklı Hicri
değerini kullanır; veri yoksa tahmin yapılmaz.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: `LocationMigrationService` — kayıtlı konumları Diyanet ilçesine eşleme

**Files:**
- Create: `lib/features/location/domain/location_migration_service.dart`, `test/location/location_migration_service_test.dart`

**Interfaces:**
- Consumes: `PlacesApi.search/resolve`, `NoCoverageException`, `PlaceMatch.toLocation`, `LocalStorage.getSavedLocations/updateLocation/getActiveLocation/saveActiveLocation`, `foldTR`.
- Produces:
```dart
enum MigrationDecision { mapped, ambiguous, unsupported }
class MigrationItem { final Location location; final MigrationDecision decision; final List<PlaceMatch> suggestions; }
class MigrationReport { final List<MigrationItem> items; bool get needsUserInput; int get mappedCount; }
class LocationMigrationService {
  LocationMigrationService({required LocalStorage storage, required PlacesApi api, required Future<void> Function(String locationId) clearPrayerCache});
  Future<MigrationReport> run();
  static bool isConfident(PlaceMatch match, Location location);
}
```
- Kurallar (UYG.7): `isMapped` olanlar atlanır (rapora girmez). GPS + koordinat → `resolve` → eşlenir (cihaz koordinatı ve `gps` kimliği korunur); `NoCoverageException` → `unsupported`. Manuel → `search("<district> <province>", limit: 5)`: boş → `unsupported`; ilk sonuç `isConfident` ise eşlenir (koordinat ilçe merkezi, kimlik korunur, `customName` korunur); değilse `ambiguous` + öneriler. Eşlenen konum `updateLocation` ile yazılır, önbelleği temizlenir, aktif konumsa aktif kayıt da güncellenir. Ağ/sunucu hatası (`ApiException`, `PlacesNotReadyException`, `SocketException`, `TimeoutException`) o konumu **atlar** ve raporda `ambiguous` olarak işaretlemez — hata fırlatır; çağıran (B2) sessizce erteler.
- `isConfident`: `foldTR(match.name) == foldTR(location.district)` **ve** `foldTR(match.stateName) == foldTR(location.province)`; ya da il merkezi durumunda `match.isCentre && foldTR(match.stateName) == foldTR(location.province) && foldTR(location.district) == foldTR(location.province)`; ya da `match.matchedAlias != null && foldTR(match.matchedAlias!) == foldTR(location.district) && foldTR(match.stateName) == foldTR(location.province)` (Kadıköy → İstanbul).

- [ ] **Step 1: Failing tests**

`test/location/location_migration_service_test.dart`:
```dart
import 'dart:convert';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/features/location/domain/location_migration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

Map<String, dynamic> match(int id, String name, String state, {bool centre = false, String? alias, double lat = 41.0, double lon = 29.0}) => {
  'id': id, 'name': name, 'stateName': state, 'displayName': centre ? '$name (Merkez)' : '$name, $state',
  'stateId': 539, 'countryId': 2, 'isCentre': centre, 'latitude': lat, 'longitude': lon, 'qiblaAngle': 150.0,
  if (alias != null) 'matchedAlias': alias,
};

void main() {
  late FakeStorage storage;
  late List<String> cleared;

  setUp(() {
    storage = FakeStorage();
    cleared = [];
  });

  LocationMigrationService service(Future<http.Response> Function(http.Request) handler) => LocationMigrationService(
    storage: storage,
    api: PlacesApi(client: MockClient(handler), baseUrl: 'https://api.test'),
    clearPrayerCache: (id) async => cleared.add(id),
  );

  http.Response searchResponse(List<Map<String, dynamic>> results) =>
      http.Response(jsonEncode({'query': '', 'results': results}), 200);

  test('eslenmis konum atlanir, guvenli eslesme otomatik baglanir', () async {
    await storage.saveLocation(const Location(id: 'diyanet-9547', province: 'İstanbul', district: 'Şile', cityId: 9547));
    await storage.saveLocation(const Location(id: 'photon-1', province: 'İstanbul', district: 'Silivri', latitude: 41.07, longitude: 28.24, customName: 'Yazlık'));
    await storage.saveActiveLocation(const Location(id: 'photon-1', province: 'İstanbul', district: 'Silivri', latitude: 41.07, longitude: 28.24, customName: 'Yazlık'));
    var calls = 0;
    final report = await service((req) async {
      calls++;
      expect(req.url.queryParameters['q'], 'Silivri İstanbul');
      return searchResponse([match(9548, 'Silivri', 'İstanbul', lat: 41.0733, lon: 28.2467)]);
    }).run();
    expect(calls, 1);
    expect(report.items, hasLength(1));
    expect(report.items.single.decision, MigrationDecision.mapped);
    final saved = (await storage.getSavedLocations()).firstWhere((l) => l.id == 'photon-1');
    expect(saved.cityId, 9548);
    expect(saved.customName, 'Yazlık');
    expect(saved.latitude, 41.0733, reason: 'manuel konumda ilce merkezi koordinati');
    expect((await storage.getActiveLocation())?.cityId, 9548);
    expect(cleared, ['photon-1']);
    expect(report.needsUserInput, isFalse);
  });

  test('alias eslesmesi (Kadikoy → Istanbul merkez) guvenli sayilir', () async {
    await storage.saveLocation(const Location(id: 'p2', province: 'İstanbul', district: 'Kadıköy'));
    final report = await service((_) async => searchResponse([match(9541, 'İstanbul', 'İstanbul', centre: true, alias: 'Kadıköy')])).run();
    expect(report.items.single.decision, MigrationDecision.mapped);
    expect((await storage.getSavedLocations()).single.cityId, 9541);
  });

  test('belirsiz sonuc: oneriler raporlanir, konum degismez', () async {
    await storage.saveLocation(const Location(id: 'p3', province: 'Antalya', district: 'Kemer'));
    final report = await service((_) async => searchResponse([match(1, 'Kemer', 'Burdur'), match(2, 'Kemer', 'Antalya')])).run();
    // ilk sonuç ili tutmuyor → belirsiz (sunucu sırasına güvenilmez)
    expect(report.items.single.decision, MigrationDecision.ambiguous);
    expect(report.items.single.suggestions, hasLength(2));
    expect((await storage.getSavedLocations()).single.cityId, isNull);
    expect(report.needsUserInput, isTrue);
  });

  test('sonuc yok → desteklenmiyor', () async {
    await storage.saveLocation(const Location(id: 'p4', province: 'Berlin', district: 'Mitte'));
    final report = await service((_) async => searchResponse([])).run();
    expect(report.items.single.decision, MigrationDecision.unsupported);
  });

  test('GPS konumu koordinattan cozulur; cihaz koordinati ve gps kimligi korunur', () async {
    await storage.saveLocation(const Location(id: 'gps', province: 'İstanbul', district: 'Şile', latitude: 41.2, longitude: 29.7, type: LocationType.gps));
    final report = await service((req) async {
      expect(req.url.path, '/v1/places/resolve');
      return http.Response(jsonEncode({'city': match(9547, 'Şile', 'İstanbul', lat: 41.1758, lon: 29.6127), 'distanceKm': 3.1}), 200);
    }).run();
    expect(report.items.single.decision, MigrationDecision.mapped);
    final gps = (await storage.getSavedLocations()).single;
    expect(gps.id, 'gps');
    expect(gps.type, LocationType.gps);
    expect(gps.cityId, 9547);
    expect(gps.latitude, 41.2);
  });

  test('GPS Turkiye disi → desteklenmiyor', () async {
    await storage.saveLocation(const Location(id: 'gps', province: 'Paris', district: 'Paris', latitude: 48.85, longitude: 2.35, type: LocationType.gps));
    final report = await service((_) async => http.Response('{"error":{"code":"NO_COVERAGE","message":"x"}}', 404)).run();
    expect(report.items.single.decision, MigrationDecision.unsupported);
  });

  test('sunucu hatasi run() ile disari cikar, konumlar degismez', () async {
    await storage.saveLocation(const Location(id: 'p5', province: 'İstanbul', district: 'Şile'));
    expect(() => service((_) async => http.Response('boom', 500)).run(), throwsA(isA<Exception>()));
    expect((await storage.getSavedLocations()).single.cityId, isNull);
  });

  test('isConfident kurallari', () {
    final sile = PlaceMatch.fromJson(match(9547, 'Şile', 'İstanbul'));
    expect(LocationMigrationService.isConfident(sile, const Location(id: 'a', province: 'ISTANBUL', district: 'SILE')), isTrue);
    expect(LocationMigrationService.isConfident(sile, const Location(id: 'a', province: 'Ankara', district: 'Şile')), isFalse);
    final centre = PlaceMatch.fromJson(match(9206, 'Ankara', 'Ankara', centre: true));
    expect(LocationMigrationService.isConfident(centre, const Location(id: 'a', province: 'Ankara', district: 'Ankara')), isTrue);
    expect(LocationMigrationService.isConfident(centre, const Location(id: 'a', province: 'Ankara', district: 'Çankaya')), isFalse);
  });
}
```

- [ ] **Step 2: Run, fail**

Run: `flutter test test/location/location_migration_service_test.dart`
Expected: derleme hatası

- [ ] **Step 3: Implement** — `lib/features/location/domain/location_migration_service.dart`:
```dart
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/location.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/turkish_fold.dart';
import '../data/places_api.dart';

enum MigrationDecision { mapped, ambiguous, unsupported }

class MigrationItem {
  final Location location;
  final MigrationDecision decision;
  final List<PlaceMatch> suggestions;
  const MigrationItem({required this.location, required this.decision, this.suggestions = const []});
}

class MigrationReport {
  final List<MigrationItem> items;
  const MigrationReport(this.items);
  bool get needsUserInput => items.any((i) => i.decision != MigrationDecision.mapped);
  int get mappedCount => items.where((i) => i.decision == MigrationDecision.mapped).length;
}

/// Eski (koordinat tabanlı) konum kayıtlarını Diyanet ilçesine bağlar.
///
/// Güncelleme sonrası ilk açılışta çalışır. Güvenli eşleşmeler sessizce
/// yazılır; belirsiz ve desteklenmeyenler ekrana bırakılır (Plan B2).
/// Ağ/sunucu hatası dışarı çıkar: çağıran bir sonraki açılışa erteler.
class LocationMigrationService {
  final LocalStorage storage;
  final PlacesApi api;
  final Future<void> Function(String locationId) clearPrayerCache;

  static const int _suggestionLimit = 5;

  LocationMigrationService({required this.storage, required this.api, required this.clearPrayerCache});

  Future<MigrationReport> run() async {
    final logger = AppLogger();
    final locations = await storage.getSavedLocations();
    final active = await storage.getActiveLocation();
    final items = <MigrationItem>[];
    for (final location in locations) {
      if (location.isMapped) continue;
      final item = await _migrate(location);
      items.add(item);
      if (item.decision == MigrationDecision.mapped) {
        await storage.updateLocation(item.location);
        await clearPrayerCache(item.location.id);
        if (active != null && active.id == item.location.id) {
          await storage.saveActiveLocation(item.location);
        }
        logger.info('Location migrated: ${item.location.id} -> cityId ${item.location.cityId}');
      }
    }
    return MigrationReport(items);
  }

  Future<MigrationItem> _migrate(Location location) async {
    if (location.type == LocationType.gps && location.latitude != null && location.longitude != null) {
      try {
        final result = await api.resolve(latitude: location.latitude!, longitude: location.longitude!);
        final mapped = result.city.toLocation(
          type: LocationType.gps,
          id: location.id,
          latitude: location.latitude,
          longitude: location.longitude,
        ).copyWith(customName: location.customName);
        return MigrationItem(location: mapped, decision: MigrationDecision.mapped);
      } on NoCoverageException {
        return MigrationItem(location: location, decision: MigrationDecision.unsupported);
      }
    }
    final results = await api.search('${location.district} ${location.province}', limit: _suggestionLimit);
    if (results.isEmpty) {
      return MigrationItem(location: location, decision: MigrationDecision.unsupported);
    }
    final first = results.first;
    if (isConfident(first, location)) {
      final mapped = first.toLocation(type: LocationType.manual, id: location.id).copyWith(customName: location.customName);
      return MigrationItem(location: mapped, decision: MigrationDecision.mapped);
    }
    return MigrationItem(location: location, decision: MigrationDecision.ambiguous, suggestions: results);
  }

  /// İlçe ve il adı aynı anahtara katlanıyorsa; il merkezinde ilçe = il;
  /// eşanlamda (Kadıköy → İstanbul) alias + il tutuyorsa güvenli.
  static bool isConfident(PlaceMatch match, Location location) {
    final district = foldTR(location.district);
    final province = foldTR(location.province);
    if (foldTR(match.stateName) != province) return false;
    if (foldTR(match.name) == district) return true;
    if (match.isCentre && district == province) return true;
    final alias = match.matchedAlias;
    return alias != null && foldTR(alias) == district;
  }
}
```
Not: `Location.copyWith(customName:)` `??` semantiğiyle `null`'u koruyamaz — burada `customName` eskiden `null` ise `toLocation` da `null` verir, sorun yok.

- [ ] **Step 4: Run, pass**

Run: `dart format lib test && flutter analyze && flutter test test/location/`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/location/domain/location_migration_service.dart test/location/location_migration_service_test.dart
git commit -m "feat(location): kayıtlı konumları Diyanet ilçesine eşleyen migrasyon servisi

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Belgeler ve son doğrulama

**Files:**
- Modify: `docs/DEVELOPMENT.md` (sunucu adresi define'ı), `docs/superpowers/specs/2026-09-17-diyanet-uygulama-design.md` (B8 varsayılan adres notu), `CHANGELOG.md` (Unreleased)

- [ ] **Step 1: DEVELOPMENT.md** — "Sunucu (`server/`)" bölümünün altına:
```markdown
### Uygulamayı yerel sunucuya bağlamak

Uygulama vakit ve yer verisini `vakit-api`'den alır. Adres derleme zamanında verilir; varsayılan
`http://127.0.0.1:8080` (iOS simülatörü). Android emülatöründe host makine için:

    flutter run --dart-define=VAKIT_API_BASE_URL=http://10.0.2.2:8080

Sürüm derlemeleri üretim adresini geçer: `--dart-define=VAKIT_API_BASE_URL=https://api.<domain>`
(`scripts/release_tag.sh` bu değeri Plan B2'de alacak).
```

- [ ] **Step 2: Spec B8 satırı** — "varsayılan üretim adresi" → "varsayılan yerel geliştirme adresi `http://127.0.0.1:8080`; üretim adresi sürüm derlemesinde define ile geçilir (domain kurulum sonrası)".

- [ ] **Step 3: CHANGELOG** — `## [Unreleased]` altına (yoksa başlık aç):
```markdown
### Değişti
- Vakit veri katmanı Diyanet il/ilçe modeline hazırlandı: konumlar Diyanet ilçe kimliği taşır, vakitler `vakit-api`'den yıllık dosya olarak Hicri tarihle birlikte önbelleğe alınır (şema 15). Hicri tarih artık hesaplanmaz, Diyanet verisinden gösterilir; veri yoksa gösterilmez.
### Kaldırıldı
- `hijri` paketi (tabular Hicri hesabı; Diyanet'ten bir gün sapabiliyordu).
```

- [ ] **Step 4: Tam doğrulama**

Run: `dart format --set-exit-if-changed lib test && flutter analyze && flutter test && flutter build apk --debug`
Expected: hepsi geçer (`flutter build ios --simulator --debug` platform kodu değişmediği için isteğe bağlı).

- [ ] **Step 5: Commit**

```bash
git add docs/DEVELOPMENT.md docs/superpowers/specs/2026-09-17-diyanet-uygulama-design.md CHANGELOG.md
git commit -m "docs: yerel vakit-api adresi, veri katmanı değişiklik notları

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Plan sonu — teslim kontrolü

- Spec kapsamı (B1): UYG.1 model + şema (Task 1–3), UYG.4 sağlayıcı + depo + ETag (Task 5), UYG.5 Hicri/Ramazan/dinî günler veriden + paket kaldırma (Task 6), UYG.7 servis kısmı (Task 7), B8 adres (Task 4, 8). UYG.2/UYG.3/UYG.6 kıble değişmez, UYG.7 ekranı, UYG.8 temizlik/gizlilik/ADR, UYG.9 → **Plan B2**.
- Bu plan sonunda uygulama Aladhan ile çalışmaya devam eder (DI değişmedi); Diyanet yolu testlerle ve yerel sunucuyla doğrulanır, ekranlar B2'de bağlanır.
- Test edilmeyen: gerçek cihazda Hicri satırının boş görünmesi (eski önbellek, hijri null) — B2'de konum yeniden eşlenince dolar; kullanıcı cihaz testi.
