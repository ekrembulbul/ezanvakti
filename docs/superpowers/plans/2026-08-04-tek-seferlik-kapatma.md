# Tek Seferlik Kapatma — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ana ekrandaki SIRADAKİ kartında gösterilen bildirimin ve alarmın, yalnızca o örnek için atlanabilmesi.

**Architecture:** Atlama kaydı `(kind, reference, fireAt)` üçlüsü. Saf kurallar (`skip_rules.dart`) → depo (`LocalStorage` + `settings` tablosunda JSON) → yönetim (`SkipManager`) → planlayıcılar → UI. Kart ve planlayıcı aynı kimliği aynı vakit verisinden türetir; bu yüzden ekrandaki anahtar ile gerçekte olacak şey ayrışamaz.

**Tech Stack:** Flutter, sqflite, `provider`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-04-tek-seferlik-kapatma-design.md`.
- **D1** — atlama yalnızca **tek örneği** kapsar; ertesi gün normal çalar.
- **D2** — atlandıktan sonra kart **bir sonrakine geçmez**, satır yerinde kalır.
- **D3** — kapalıyken alt metin: `Yalnızca bu sefer atlanacak · <saat>`.
- **D4** — kalan süre alt metne taşınır; sağda yalnızca anahtar kalır.
- **D5** — saklama `settings` tablosunda tek anahtar (`skipped_occurrences`), JSON liste. **Şema migration yok.**
- **D6** — süresi geçen kayıtlar yüklemede temizlenir.
- **Değişmez kural — anahtar yalan söylemez.** Kart ve planlayıcı atlanmışlığı aynı kimlikle sorar; kayıt eşleşmiyorsa alarm çalar **ve** anahtar açık görünür.
- **Ayrım:** `scheduleAlarms` skip'leri geçirir, `resolveNextAlarm` **geçirmez** (D2 bunun üzerine kurulu).
- Bildirimler/Alarmlar ekranlarındaki anahtarlar **kalıcı** kapatmaya devam eder; o dosyalara dokunulmaz.
- Kullanıcı metinleri tam Türkçe karakterle. Kod içi yorumlar mevcut dosyaların stilini izler.
- Her task sonunda `flutter analyze` temiz ve `flutter test` yeşil olmadan commit yok.
- Simülatör koşumu yalnızca Task 8'de; öncesinde gerek yok.

---

## Dosya Yapısı

**Oluşturulacak:**

| Dosya | Sorumluluk |
|---|---|
| `lib/core/models/skipped_occurrence.dart` | Model + JSON serileştirme. Tek sorumluluk: bir atlama kaydını temsil etmek. |
| `lib/features/notifications/domain/skip_rules.dart` | Saf kurallar: eşleşme ve süre dolumu. Depoya ve widget'a bağımlı değil, bu yüzden ayrı. |
| `lib/features/notifications/domain/skip_manager.dart` | Depo ile kurallar arasındaki ince katman. |
| `test/notifications/skip_rules_test.dart` | Saf kural testleri. |
| `test/notifications/skip_manager_test.dart` | Yükle/yaz/temizle turu. |

**Değiştirilecek:**

| Dosya | Değişiklik |
|---|---|
| `lib/core/interfaces/local_storage.dart` | İki metot eklenir. |
| `lib/features/prayer_times/data/sqlite_storage.dart` | `settings` tablosunda JSON okuma/yazma. |
| `test/support/fakes.dart` + 10 test dosyası | Sahte `LocalStorage`'lara iki metot. |
| `lib/features/alarms/domain/alarm_scheduler.dart` | `computeNextFire` ve `scheduleAlarms` skip alır. |
| `lib/features/notifications/domain/notification_scheduler.dart` | Aday listesi süzülür. |
| `lib/core/di/service_locator.dart` | `SkipManager` kaydı. |
| `lib/core/providers/app_state.dart` | `skips` alanı. |
| `lib/presentation/services/data_loader_service.dart` | `PrayerData`'ya `skips`. |
| `lib/presentation/services/upcoming_resolver.dart` | `UpcomingNotification`'a `prayerDate`. |
| `lib/presentation/pages/home_page.dart` | Yükleme + `_toggleSkip`. |
| `lib/presentation/screens/home_screen.dart` | `skips` ve `onSkipChanged` aktarımı. |
| `lib/presentation/widgets/home/upcoming_card.dart` | İki satırda anahtar, alt metinler. |
| `test/widgets/home/upcoming_card_test.dart` | Yeni davranış testleri. |

---

## Task 1: Model

**Files:**
- Create: `lib/core/models/skipped_occurrence.dart`
- Test: `test/notifications/skip_rules_test.dart` (bu task'ta yalnızca serileştirme kısmı)

**Interfaces:**
- Produces: `enum SkipKind { notification, alarm }`; `class SkippedOccurrence` — alanlar `SkipKind kind`, `String reference`, `DateTime fireAt`; `Map<String, dynamic> toJson()`; `factory SkippedOccurrence.fromJson(Map<String, dynamic>)`; değer eşitliği (`==`/`hashCode`).

- [ ] **Step 1: Testi yaz**

`test/notifications/skip_rules_test.dart`:

```dart
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final occurrence = SkippedOccurrence(
    kind: SkipKind.alarm,
    reference: 'sahur',
    fireAt: DateTime(2026, 8, 5, 3, 43),
  );

  group('SkippedOccurrence', () {
    test('JSON turu degeri korur', () {
      final restored = SkippedOccurrence.fromJson(occurrence.toJson());

      expect(restored, occurrence);
    });

    test('Ayni ucluye sahip iki kayit esit', () {
      final other = SkippedOccurrence(
        kind: SkipKind.alarm,
        reference: 'sahur',
        fireAt: DateTime(2026, 8, 5, 3, 43),
      );

      expect(other, occurrence);
      expect(other.hashCode, occurrence.hashCode);
    });

    test('Farkli fireAt farkli kayit', () {
      // Ayni alarmin farkli gunleri ayri kayitlardir (spec D1).
      final nextDay = SkippedOccurrence(
        kind: SkipKind.alarm,
        reference: 'sahur',
        fireAt: DateTime(2026, 8, 6, 3, 43),
      );

      expect(nextDay, isNot(occurrence));
    });

    test('Farkli tur farkli kayit', () {
      final asNotification = SkippedOccurrence(
        kind: SkipKind.notification,
        reference: 'sahur',
        fireAt: DateTime(2026, 8, 5, 3, 43),
      );

      expect(asNotification, isNot(occurrence));
    });
  });
}
```

- [ ] **Step 2: Testi çalıştır, kırmızıyı gör**

```bash
flutter test test/notifications/skip_rules_test.dart
```

Beklenen: derleme hatası — `skipped_occurrence.dart` yok.

- [ ] **Step 3: Modeli yaz**

`lib/core/models/skipped_occurrence.dart`:

```dart
/// Atlanan örneğin türü.
enum SkipKind { notification, alarm }

/// Tek bir bildirim/alarm örneğinin "yalnızca bu sefer" atlanması.
///
/// [reference] bildirim için `NotificationScheduler`'ın ürettiği kimlik
/// (gün · vakit · offset), alarm için alarmın kendi id'si. [fireAt] ile
/// birlikte tek bir örneği işaret eder: aynı alarmın farklı günleri ayrı
/// kayıtlardır.
class SkippedOccurrence {
  final SkipKind kind;
  final String reference;
  final DateTime fireAt;

  const SkippedOccurrence({
    required this.kind,
    required this.reference,
    required this.fireAt,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'reference': reference,
    'fireAt': fireAt.toIso8601String(),
  };

  /// Tanınmayan tür kaydı atlamak yerine bildirim sayılmaz; çağıran taraf
  /// (`SkipManager`) bozuk kayıtları eler.
  factory SkippedOccurrence.fromJson(Map<String, dynamic> json) {
    return SkippedOccurrence(
      kind: SkipKind.values.byName(json['kind'] as String),
      reference: json['reference'] as String,
      fireAt: DateTime.parse(json['fireAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SkippedOccurrence &&
      other.kind == kind &&
      other.reference == reference &&
      other.fireAt == fireAt;

  @override
  int get hashCode => Object.hash(kind, reference, fireAt);

  @override
  String toString() =>
      'SkippedOccurrence(${kind.name}, $reference, $fireAt)';
}
```

- [ ] **Step 4: Testi çalıştır**

```bash
flutter test test/notifications/skip_rules_test.dart
flutter analyze
```

Beklenen: 4 test geçer, analiz temiz.

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/skipped_occurrence.dart test/notifications/skip_rules_test.dart
git commit -m "feat: atlama kaydi modeli"
```

---

## Task 2: Saf kurallar

**Files:**
- Create: `lib/features/notifications/domain/skip_rules.dart`
- Modify: `test/notifications/skip_rules_test.dart`

**Interfaces:**
- Consumes: `SkippedOccurrence`, `SkipKind` (Task 1).
- Produces:
  - `bool isSkipped(Set<SkippedOccurrence> skips, {required SkipKind kind, required String reference, required DateTime fireAt})`
  - `Set<SkippedOccurrence> withoutExpired(Iterable<SkippedOccurrence> skips, DateTime now)`

- [ ] **Step 1: Testi yaz**

`test/notifications/skip_rules_test.dart` dosyasının sonuna, `SkippedOccurrence` grubunun ardına:

```dart
  group('isSkipped', () {
    final skips = {
      SkippedOccurrence(
        kind: SkipKind.alarm,
        reference: 'sahur',
        fireAt: DateTime(2026, 8, 5, 3, 43),
      ),
    };

    test('Ucu de eslesince atlanmis', () {
      expect(
        isSkipped(
          skips,
          kind: SkipKind.alarm,
          reference: 'sahur',
          fireAt: DateTime(2026, 8, 5, 3, 43),
        ),
        isTrue,
      );
    });

    test('Saat kayarsa eslesmez', () {
      // Spec: vakit verisi guncellenip saat kayarsa alarm CALAR ve anahtar
      // acik gorunur. Ikisi de bu ayni sorgudan turedigi icin ayrisamaz.
      expect(
        isSkipped(
          skips,
          kind: SkipKind.alarm,
          reference: 'sahur',
          fireAt: DateTime(2026, 8, 5, 3, 45),
        ),
        isFalse,
      );
    });

    test('Farkli referans eslesmez', () {
      expect(
        isSkipped(
          skips,
          kind: SkipKind.alarm,
          reference: 'isyerine-cikis',
          fireAt: DateTime(2026, 8, 5, 3, 43),
        ),
        isFalse,
      );
    });

    test('Bos kumede hicbir sey atlanmis degil', () {
      expect(
        isSkipped(
          const {},
          kind: SkipKind.alarm,
          reference: 'sahur',
          fireAt: DateTime(2026, 8, 5, 3, 43),
        ),
        isFalse,
      );
    });
  });

  group('withoutExpired', () {
    SkippedOccurrence at(DateTime fireAt) => SkippedOccurrence(
      kind: SkipKind.notification,
      reference: 'x',
      fireAt: fireAt,
    );

    test('Zamani gecmis kayit elenir', () {
      final now = DateTime(2026, 8, 5, 12);
      final kept = at(DateTime(2026, 8, 5, 13));

      final result = withoutExpired([at(DateTime(2026, 8, 5, 11)), kept], now);

      expect(result, {kept});
    });

    test('Tam su anda tetiklenecek kayit korunur', () {
      final now = DateTime(2026, 8, 5, 12);
      final borderline = at(now);

      expect(withoutExpired([borderline], now), {borderline});
    });

    test('Hepsi gecmisse bos kume', () {
      final now = DateTime(2026, 8, 5, 12);

      expect(withoutExpired([at(DateTime(2026, 8, 4))], now), isEmpty);
    });
  });
```

Dosyanın başına import ekle:

```dart
import 'package:ezanvakti/features/notifications/domain/skip_rules.dart';
```

- [ ] **Step 2: Testi çalıştır, kırmızıyı gör**

```bash
flutter test test/notifications/skip_rules_test.dart
```

Beklenen: derleme hatası — `isSkipped` ve `withoutExpired` tanımlı değil.

- [ ] **Step 3: Kuralları yaz**

`lib/features/notifications/domain/skip_rules.dart`:

```dart
import '../../../core/models/skipped_occurrence.dart';

/// Verilen örnek atlanmış mı?
///
/// **Kart ve planlayıcı bu tek sorgu üzerinden ilerler.** Aynı kimliği aynı
/// vakit verisinden türettikleri için ikisi ayrışamaz: kayıt eşleşiyorsa alarm
/// çalmaz ve anahtar kapalı görünür, eşleşmiyorsa alarm çalar ve anahtar açık
/// görünür.
bool isSkipped(
  Set<SkippedOccurrence> skips, {
  required SkipKind kind,
  required String reference,
  required DateTime fireAt,
}) {
  return skips.contains(
    SkippedOccurrence(kind: kind, reference: reference, fireAt: fireAt),
  );
}

/// Tetiklenme anı geçmiş kayıtları eler.
///
/// Kullanıcının ayrıca "geri aç" demesi gerekmez; örnek geçince atlama
/// kendiliğinden ölür ve ertesi gün normal çalar.
Set<SkippedOccurrence> withoutExpired(
  Iterable<SkippedOccurrence> skips,
  DateTime now,
) {
  return skips.where((skip) => !skip.fireAt.isBefore(now)).toSet();
}
```

- [ ] **Step 4: Testi çalıştır**

```bash
flutter test test/notifications/skip_rules_test.dart
flutter analyze
```

Beklenen: 11 test geçer, analiz temiz.

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/skip_rules.dart test/notifications/skip_rules_test.dart
git commit -m "feat: atlama kurallarini saf fonksiyonlara ayir"
```

---

## Task 3: Depo

**Files:**
- Modify: `lib/core/interfaces/local_storage.dart`
- Modify: `lib/features/prayer_times/data/sqlite_storage.dart`
- Modify: `test/support/fakes.dart` ve `implements LocalStorage` içeren 10 test dosyası

**Interfaces:**
- Consumes: `SkippedOccurrence` (Task 1).
- Produces: `LocalStorage.getSkippedOccurrences() → Future<List<SkippedOccurrence>>`, `LocalStorage.saveSkippedOccurrences(List<SkippedOccurrence>) → Future<void>`.

**Not.** `LocalStorage`'ı 11 sınıf uyguluyor. Hepsini bulmak için:

```bash
grep -rl "implements LocalStorage" lib/ test/
```

Derleyici de eksik olanları tek tek gösterir; listeyi ondan doğrula.

- [ ] **Step 1: Arayüze metotları ekle**

`lib/core/interfaces/local_storage.dart` — `getAlarms()` bildiriminin hemen üstüne:

```dart
  /// "Yalnızca bu sefer" atlanmış bildirim/alarm örnekleri.
  ///
  /// `settings` tablosunda tek anahtarda JSON liste olarak tutulur; aynı anda
  /// en fazla birkaç kayıt olduğu için ayrı tablo açılmadı.
  Future<List<SkippedOccurrence>> getSkippedOccurrences();

  /// Atlama listesinin tamamını değiştirir.
  Future<void> saveSkippedOccurrences(List<SkippedOccurrence> occurrences);
```

Dosyanın import bloğuna:

```dart
import '../models/skipped_occurrence.dart';
```

- [ ] **Step 2: Analiz ile eksik uygulayanları listele**

```bash
flutter analyze 2>&1 | grep "missing_concrete_member\|Missing concrete"
```

Beklenen: 11 sınıf için hata. Bu liste Step 4'ün yapılacaklar listesidir.

- [ ] **Step 3: `SqliteStorage`'a uygula**

`lib/features/prayer_times/data/sqlite_storage.dart` — `saveAppearanceSettings` metodunun hemen ardına:

```dart
  /// Atlama listesi `settings` tablosunda tek satırda, JSON dizi olarak durur.
  static const String _skippedOccurrencesKey = 'skipped_occurrences';

  @override
  Future<List<SkippedOccurrence>> getSkippedOccurrences() async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_skippedOccurrencesKey],
    );
    if (rows.isEmpty) return [];

    // Bozuk kayıt uygulamayı açılmaz hale getirmemeli; atlamasız devam edilir.
    try {
      final decoded = jsonDecode(rows.first['value'] as String) as List;
      return decoded
          .map((e) => SkippedOccurrence.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger().warning('Atlama listesi okunamadi, bos kabul edildi', e);
      return [];
    }
  }

  @override
  Future<void> saveSkippedOccurrences(
    List<SkippedOccurrence> occurrences,
  ) async {
    final db = await database;
    await db.insert('settings', {
      'key': _skippedOccurrencesKey,
      'value': jsonEncode([for (final o in occurrences) o.toJson()]),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
```

Import bloğuna (yoksa) ekle:

```dart
import 'dart:convert';
import '../../../core/models/skipped_occurrence.dart';
```

- [ ] **Step 4: Sahte depolara uygula**

Step 2'de listelenen her test sınıfına şunu ekle (hepsi bellekte tutar):

```dart
  List<SkippedOccurrence> _skippedOccurrences = [];

  @override
  Future<List<SkippedOccurrence>> getSkippedOccurrences() async =>
      List.of(_skippedOccurrences);

  @override
  Future<void> saveSkippedOccurrences(
    List<SkippedOccurrence> occurrences,
  ) async {
    _skippedOccurrences = List.of(occurrences);
  }
```

Her dosyaya import:

```dart
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
```

- [ ] **Step 5: Doğrula**

```bash
flutter analyze
flutter test
```

Beklenen: analiz temiz, tüm testler yeşil (davranış değişmedi).

- [ ] **Step 6: Commit**

```bash
git add lib/core/interfaces/local_storage.dart \
  lib/features/prayer_times/data/sqlite_storage.dart test/
git commit -m "feat: atlama listesini depoya bagla"
```

---

## Task 4: SkipManager

**Files:**
- Create: `lib/features/notifications/domain/skip_manager.dart`
- Create: `test/notifications/skip_manager_test.dart`
- Modify: `lib/core/di/service_locator.dart`

**Interfaces:**
- Consumes: `LocalStorage.getSkippedOccurrences/saveSkippedOccurrences` (Task 3), `withoutExpired` (Task 2).
- Produces: `SkipManager({required LocalStorage storage, DateTime Function()? clock})`; `Future<Set<SkippedOccurrence>> load()`; `Future<Set<SkippedOccurrence>> skip(SkippedOccurrence)`; `Future<Set<SkippedOccurrence>> unskip(SkippedOccurrence)`. Üçü de **güncel küme** döner ki çağıran ayrıca `load()` yapmasın.

- [ ] **Step 1: Testi yaz**

`test/notifications/skip_manager_test.dart`:

```dart
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/notifications/domain/skip_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  final now = DateTime(2026, 8, 5, 12);
  final future = SkippedOccurrence(
    kind: SkipKind.alarm,
    reference: 'sahur',
    fireAt: DateTime(2026, 8, 5, 13),
  );
  final past = SkippedOccurrence(
    kind: SkipKind.notification,
    reference: 'eski',
    fireAt: DateTime(2026, 8, 5, 11),
  );

  SkipManager build(FakeStorage storage) =>
      SkipManager(storage: storage, clock: () => now);

  test('skip yazar, load geri getirir', () async {
    final storage = FakeStorage();
    final manager = build(storage);

    final afterSkip = await manager.skip(future);

    expect(afterSkip, {future});
    expect(await manager.load(), {future});
  });

  test('unskip kaydi siler', () async {
    final storage = FakeStorage();
    final manager = build(storage);
    await manager.skip(future);

    final afterUnskip = await manager.unskip(future);

    expect(afterUnskip, isEmpty);
    expect(await manager.load(), isEmpty);
  });

  test('load suresi gecmis kaydi eler ve depoyu temizler', () async {
    final storage = FakeStorage();
    await storage.saveSkippedOccurrences([past, future]);
    final manager = build(storage);

    expect(await manager.load(), {future});
    // Temizlik depoya da yazilir; yoksa liste zamanla sismeye devam eder.
    expect(await storage.getSkippedOccurrences(), [future]);
  });

  test('Ayni kayit iki kez atlanirsa tek kayit kalir', () async {
    final storage = FakeStorage();
    final manager = build(storage);

    await manager.skip(future);
    final result = await manager.skip(future);

    expect(result, hasLength(1));
  });
}
```

- [ ] **Step 2: Testi çalıştır, kırmızıyı gör**

```bash
flutter test test/notifications/skip_manager_test.dart
```

Beklenen: derleme hatası — `skip_manager.dart` yok.

- [ ] **Step 3: `SkipManager`'ı yaz**

`lib/features/notifications/domain/skip_manager.dart`:

```dart
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/skipped_occurrence.dart';
import 'skip_rules.dart';

/// "Yalnızca bu sefer" atlamalarını yükler, yazar ve süresi geçenleri temizler.
///
/// Üç metot da güncel kümeyi döner: çağıran taraf ayrıca [load] yapmadan
/// durumu tazeleyebilsin.
class SkipManager {
  final LocalStorage _storage;
  final DateTime Function() _clock;

  SkipManager({required LocalStorage storage, DateTime Function()? clock})
    : _storage = storage,
      _clock = clock ?? DateTime.now;

  /// Kayıtları okur, süresi geçenleri eler ve elemeyi depoya da yansıtır.
  Future<Set<SkippedOccurrence>> load() async {
    final stored = await _storage.getSkippedOccurrences();
    final live = withoutExpired(stored, _clock());

    // Liste zamanla şişmesin diye temizlik kalıcı yazılır.
    if (live.length != stored.length) {
      await _storage.saveSkippedOccurrences(live.toList());
    }
    return live;
  }

  Future<Set<SkippedOccurrence>> skip(SkippedOccurrence occurrence) async {
    final live = await load();
    return _persist({...live, occurrence});
  }

  Future<Set<SkippedOccurrence>> unskip(SkippedOccurrence occurrence) async {
    final live = await load();
    return _persist({...live}..remove(occurrence));
  }

  Future<Set<SkippedOccurrence>> _persist(Set<SkippedOccurrence> next) async {
    await _storage.saveSkippedOccurrences(next.toList());
    return next;
  }
}
```

- [ ] **Step 4: Testi çalıştır**

```bash
flutter test test/notifications/skip_manager_test.dart
```

Beklenen: 4 test geçer.

- [ ] **Step 5: `ServiceLocator`'a kaydet**

`lib/core/di/service_locator.dart` — `register<AlarmsManager>(...)` satırının hemen ardına:

```dart
    register<SkipManager>(SkipManager(storage: localStorage));
```

Import ekle:

```dart
import '../../features/notifications/domain/skip_manager.dart';
```

- [ ] **Step 6: Doğrula ve commit**

```bash
flutter analyze
flutter test
git add lib/features/notifications/domain/skip_manager.dart \
  lib/core/di/service_locator.dart test/notifications/skip_manager_test.dart
git commit -m "feat: SkipManager ve DI kaydi"
```

---

## Task 5: Alarm planlaması

**Files:**
- Modify: `lib/features/alarms/domain/alarm_scheduler.dart`
- Test: `test/alarms/alarm_test.dart`

**Interfaces:**
- Consumes: `isSkipped` (Task 2), `SkippedOccurrence`/`SkipKind` (Task 1).
- Produces:
  - `static DateTime? AlarmScheduler.computeNextFire({required Alarm alarm, required DateTime now, required Map<DateTime, PrayerTime> prayerTimesByDate, int searchDays = 8, Set<SkippedOccurrence> skips = const {}})`
  - `Future<void> scheduleAlarms({required List<PrayerTime> prayerTimes, Set<SkippedOccurrence> skips = const {}})`

**Kritik.** Varsayılan boş küme şart: `resolveNextAlarm` bu fonksiyonu **skip'siz** çağırmaya devam edecek (D2). Skip'i oraya da geçirmek kartın atlanan alarmı atlayıp bir sonrakini göstermesine yol açar ve geri açma yolu kalmaz.

- [ ] **Step 1: Testi yaz**

`test/alarms/alarm_test.dart` içindeki `AlarmScheduler.computeNextFire — anchored` grubunun ardına yeni bir grup:

```dart
  group('AlarmScheduler.computeNextFire — atlama', () {
    const alarm = Alarm(
      id: 'sahur',
      kind: AlarmKind.fixed,
      label: 'Sahur',
      hour: 6,
      minute: 30,
    );

    test('Atlanan calma ani gecilir, bir sonraki dondurulur', () {
      final now = DateTime(2026, 8, 5, 7);
      final skipped = DateTime(2026, 8, 6, 6, 30);

      final fire = AlarmScheduler.computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: const {},
        skips: {
          SkippedOccurrence(
            kind: SkipKind.alarm,
            reference: alarm.id,
            fireAt: skipped,
          ),
        },
      );

      expect(fire, DateTime(2026, 8, 7, 6, 30));
    });

    test('Art arda iki atlama ucuncuyu bulur', () {
      final now = DateTime(2026, 8, 5, 7);

      final fire = AlarmScheduler.computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: const {},
        skips: {
          SkippedOccurrence(
            kind: SkipKind.alarm,
            reference: alarm.id,
            fireAt: DateTime(2026, 8, 6, 6, 30),
          ),
          SkippedOccurrence(
            kind: SkipKind.alarm,
            reference: alarm.id,
            fireAt: DateTime(2026, 8, 7, 6, 30),
          ),
        },
      );

      expect(fire, DateTime(2026, 8, 8, 6, 30));
    });

    test('Baska alarmin atlamasi etkilemez', () {
      final now = DateTime(2026, 8, 5, 7);

      final fire = AlarmScheduler.computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: const {},
        skips: {
          SkippedOccurrence(
            kind: SkipKind.alarm,
            reference: 'baska-alarm',
            fireAt: DateTime(2026, 8, 6, 6, 30),
          ),
        },
      );

      expect(fire, DateTime(2026, 8, 6, 6, 30));
    });

    test('Skip verilmezse davranis degismez', () {
      final now = DateTime(2026, 8, 5, 7);

      final fire = AlarmScheduler.computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: const {},
      );

      expect(fire, DateTime(2026, 8, 6, 6, 30));
    });
  });
```

Dosyanın import bloğuna:

```dart
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
```

- [ ] **Step 2: Testi çalıştır, kırmızıyı gör**

```bash
flutter test test/alarms/alarm_test.dart
```

Beklenen: `skips` adlı parametre tanımlı değil.

- [ ] **Step 3: `computeNextFire`'ı genişlet**

`lib/features/alarms/domain/alarm_scheduler.dart`:

```dart
  static DateTime? computeNextFire({
    required Alarm alarm,
    required DateTime now,
    required Map<DateTime, PrayerTime> prayerTimesByDate,
    int searchDays = 8,
    Set<SkippedOccurrence> skips = const {},
  }) {
```

Döngü içinde, `if (candidate.isAfter(now)) return candidate;` satırını şununla değiştir:

```dart
      if (!candidate.isAfter(now)) continue;

      // "Yalnızca bu sefer" atlanan çalma anı geçilir; alarm bir sonraki
      // uygun günde normal çalar.
      final skipped = isSkipped(
        skips,
        kind: SkipKind.alarm,
        reference: alarm.id,
        fireAt: candidate,
      );
      if (skipped) continue;

      return candidate;
```

Import bloğuna:

```dart
import '../../../core/models/skipped_occurrence.dart';
import '../../notifications/domain/skip_rules.dart';
```

- [ ] **Step 4: `scheduleAlarms`'a skip'i geçir**

Aynı dosyada:

```dart
  Future<void> scheduleAlarms({
    required List<PrayerTime> prayerTimes,
    Set<SkippedOccurrence> skips = const {},
  }) async {
```

ve içindeki çağrıyı:

```dart
      final fire = computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: byDate,
        skips: skips,
      );
```

- [ ] **Step 5: Testleri çalıştır**

```bash
flutter test test/alarms/
flutter analyze
```

Beklenen: yeni 4 test dahil hepsi geçer; mevcut çağrılar varsayılan boş kümeyle bozulmadı.

- [ ] **Step 6: `resolveNextAlarm`'ın skip almadığını doğrula**

```bash
grep -n "skips" lib/presentation/services/upcoming_resolver.dart
```

Beklenen: **çıktı yok.** Bu dosya bilinçli olarak skip geçirmez (D2). Bu ayrım Task 7'de testle korunacak.

- [ ] **Step 7: Commit**

```bash
git add lib/features/alarms/domain/alarm_scheduler.dart test/alarms/alarm_test.dart
git commit -m "feat: alarm planlamasi atlanan calma anini gecsin"
```

---

## Task 6: Bildirim planlaması

**Files:**
- Modify: `lib/features/notifications/domain/notification_scheduler.dart`
- Test: `test/notifications/notifications_test.dart`

**Interfaces:**
- Consumes: `isSkipped` (Task 2).
- Produces: `Future<void> scheduleNotifications({required Location location, required List<PrayerTime> prayerTimes, Set<SkippedOccurrence> skips = const {}})`. `rescheduleNotifications` de aynı parametreyi alıp iletir.

- [ ] **Step 1: Testi yaz**

`test/notifications/notifications_test.dart` — `Notification Scheduler - Basic Scheduling` grubunun sonuna:

```dart
    test('Atlanan bildirim planlanmaz, diger gunler etkilenmez', () async {
      // Bu testte kullanilan storage/notification sahteleri grubun setUp'inda
      // kuruluyor; ayni desende ilerle.
      final today = DateTime.now();
      final todayNormalized = DateTime(today.year, today.month, today.day);

      await storage.saveNotificationSettings(const [
        NotificationSetting(prayerType: PrayerType.dhuhr, isActive: true),
      ]);

      // Once atlamasiz planla, uretilen kimlikleri ve sayiyi ogren.
      await scheduler.scheduleNotifications(
        location: location,
        prayerTimes: prayerTimes,
      );
      final baseline = notificationService.scheduledNotifications.length;
      expect(baseline, greaterThan(1), reason: 'Birden fazla gun planlanmali');

      final firstFire = notificationService.scheduledNotifications
          .map((n) => n.scheduledTime)
          .reduce((a, b) => a.isBefore(b) ? a : b);

      await scheduler.scheduleNotifications(
        location: location,
        prayerTimes: prayerTimes,
        skips: {
          SkippedOccurrence(
            kind: SkipKind.notification,
            reference: NotificationScheduler.notificationIdFor(
              date: todayNormalized,
              prayerType: PrayerType.dhuhr,
              minutesBefore: 0,
            ),
            fireAt: firstFire,
          ),
        },
      );

      expect(
        notificationService.scheduledNotifications.length,
        baseline - 1,
        reason: 'Yalnizca atlanan ornek dusmeli',
      );
      expect(
        notificationService.scheduledNotifications
            .any((n) => n.scheduledTime == firstFire),
        isFalse,
      );
    });
```

Import ekle:

```dart
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
```

**Not.** Test, atlanan kimliğin bugüne ait olduğunu varsayar. Grubun `setUp`'ında kurulan `prayerTimes` bugünden başlıyorsa `firstFire` bugünün Öğle bildirimidir. Değilse `firstFire`'a karşılık gelen günü kullan — kimlik üretimi tarihe bağlı.

- [ ] **Step 2: Testi çalıştır, kırmızıyı gör**

```bash
flutter test test/notifications/notifications_test.dart
```

Beklenen: `skips` parametresi ve `notificationIdFor` tanımlı değil.

- [ ] **Step 3: Kimlik üretimini dışa aç**

`lib/features/notifications/domain/notification_scheduler.dart` — mevcut `_generateNotificationId` özel metodunu statik ve public bir metoda çevir; içeriği aynı kalır:

```dart
  /// Bir bildirim örneğinin kimliği: gün · vakit · offset.
  ///
  /// Atlama kayıtları da bu kimliği `reference` olarak kullanır; kart ve
  /// planlayıcı aynı değeri üretmek zorunda.
  static String notificationIdFor({
    required DateTime date,
    required PrayerType prayerType,
    required int minutesBefore,
  }) {
    final dayOrdinal =
        DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final id = dayOrdinal * 10000 + prayerType.index * 1000 + minutesBefore;
    return id.toString();
  }
```

Eski `_generateNotificationId(...)` çağrısını `notificationIdFor(date: ..., prayerType: ..., minutesBefore: ...)` ile değiştir ve özel metodu sil.

- [ ] **Step 4: Aday listesini süz**

Aynı dosyada imzayı genişlet:

```dart
  Future<void> scheduleNotifications({
    required Location location,
    required List<PrayerTime> prayerTimes,
    Set<SkippedOccurrence> skips = const {},
  }) async {
```

`if (!seenIds.add(id)) continue;` satırının hemen ardına:

```dart
        // "Yalnızca bu sefer" atlanan örnek planlanmaz; aynı bildirimin
        // diğer günleri etkilenmez.
        if (isSkipped(
          skips,
          kind: SkipKind.notification,
          reference: id,
          fireAt: notificationTime,
        )) {
          continue;
        }
```

`rescheduleNotifications`'ı da güncelle:

```dart
  Future<void> rescheduleNotifications({
    required Location location,
    required List<PrayerTime> prayerTimes,
    Set<SkippedOccurrence> skips = const {},
  }) async {
    await scheduleNotifications(
      location: location,
      prayerTimes: prayerTimes,
      skips: skips,
    );
  }
```

Import bloğuna:

```dart
import '../../../core/models/skipped_occurrence.dart';
import 'skip_rules.dart';
```

- [ ] **Step 5: Testleri çalıştır**

```bash
flutter test test/notifications/
flutter analyze
```

Beklenen: yeni test dahil hepsi geçer.

- [ ] **Step 6: Commit**

```bash
git add lib/features/notifications/domain/notification_scheduler.dart \
  test/notifications/notifications_test.dart
git commit -m "feat: atlanan bildirimi planlama"
```

---

## Task 7: Kart

**Files:**
- Modify: `lib/presentation/services/upcoming_resolver.dart`
- Modify: `lib/presentation/widgets/home/upcoming_card.dart`
- Test: `test/widgets/home/upcoming_card_test.dart`
- Test: `test/presentation/upcoming_resolver_test.dart`

**Interfaces:**
- Consumes: `isSkipped` (Task 2), `NotificationScheduler.notificationIdFor` (Task 6).
- Produces:
  - `UpcomingNotification` kaydı bir alan kazanır: `({NotificationSetting setting, DateTime prayerDate, DateTime time})`.
  - `UpcomingCard`'ın yeni parametreleri — `Set<SkippedOccurrence> skips` (varsayılan `const {}`) ve `void Function(SkippedOccurrence occurrence, bool skipped)? onSkipChanged`. `onAlarmToggled` **kaldırılır**: kartın anahtarı artık kalıcı değil, tek seferlik.

**Neden `prayerDate` ekleniyor.** Planlayıcı kimliği `prayerTime.date` ile
üretiyor (`notification_scheduler.dart:76`), yani **vaktin günü** ile. Kartın
elinde ise yalnızca tetiklenme anı (`time`) var ve sapmalı bildirimde bu iki
tarih ayrışabilir. Aynı kimliği üretmezlerse "anahtar yalan söylemez" kuralı
kırılır: kullanıcı kapalı görür ama bildirim gelir. Tahmine dayanmak yerine
vaktin günü kayda taşınıyor.

- [ ] **Step 1: `UpcomingNotification`'a `prayerDate` ekle**

`lib/presentation/services/upcoming_resolver.dart`:

```dart
/// Ana ekrandaki "SIRADAKİ" kartının bir satırı: bildirim.
///
/// [prayerDate] vaktin günü — [time] ise tetiklenme anı. Sapmalı bildirimde
/// ikisi farklı güne düşebilir; atlama kimliği **vaktin gününden** üretildiği
/// için (planlayıcıyla aynı kural) ayrıca taşınır.
typedef UpcomingNotification = ({
  NotificationSetting setting,
  DateTime prayerDate,
  DateTime time,
});
```

`resolveNextNotification` içindeki atamayı güncelle:

```dart
      if (earliest == null || fireAt.isBefore(earliest.time)) {
        earliest = (setting: setting, prayerDate: day.date, time: fireAt);
      }
```

`test/presentation/upcoming_resolver_test.dart` içindeki beklentilere
`prayerDate` eklenmesi gerekmez (alan okunmuyor), ama derleme için yeni bir
doğrulama ekle:

```dart
    test('prayerDate vaktin gunu', () {
      final next = resolveNextNotification(
        settings: const [
          NotificationSetting(
            prayerType: PrayerType.fajr,
            isActive: true,
            minutesBefore: 30,
          ),
        ],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 23),
      );

      // Tetiklenme 4 Agustos 03:41; vaktin gunu de 4 Agustos.
      expect(next?.time, DateTime(2026, 8, 4, 3, 41));
      expect(next?.prayerDate, DateTime(2026, 8, 4));
    });
```

- [ ] **Step 2: Kart testlerini yaz**

`test/widgets/home/upcoming_card_test.dart` içindeki `UpcomingCard` grubunun `pumpCard` yardımcısını genişlet ve testleri ekle. Önce yardımcıyı şu hâle getir:

```dart
    Future<void> pumpCard(
      WidgetTester tester, {
      UpcomingNotification? notification,
      UpcomingAlarm? alarm,
      VoidCallback? onSeeAll,
      Set<SkippedOccurrence> skips = const {},
      void Function(SkippedOccurrence, bool)? onSkipChanged,
    }) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 360,
            child: UpcomingCard(
              now: now,
              notification: notification,
              alarm: alarm,
              skips: skips,
              onSkipChanged: onSkipChanged,
              onSeeAll: onSeeAll ?? () {},
            ),
          ),
        ),
      );
    }
```

`onAlarmToggled` kullanan mevcut testi ("Alarm anahtari callback tetikler") sil; yerine aşağıdakiler gelir.

Grubun başına ortak veriler:

```dart
    final maghribAt = DateTime(2026, 8, 3, 20, 25);
    final notification = (
      setting: const NotificationSetting(
        prayerType: PrayerType.maghrib,
        isActive: true,
        minutesBefore: 10,
      ),
      prayerDate: DateTime(2026, 8, 3),
      time: DateTime(2026, 8, 3, 20, 15),
    );
    const sahur = Alarm(
      id: 'sahur',
      kind: AlarmKind.anchored,
      label: 'Sahur',
      anchor: PrayerType.fajr,
      offsetMinutes: -30,
    );
    final alarmAt = DateTime(2026, 8, 4, 3, 41);
```

(`maghribAt` yalnızca okunabilirlik içindir; testlerde `notification.time` kullanılır.)

Testler:

```dart
    testWidgets('Bildirim satiri kalan sureyi alt metinde yazar', (
      tester,
    ) async {
      await pumpCard(tester, notification: notification);

      // Sag taraf tek islevli kaldi: kalan sure alt metne tasindi.
      expect(find.text('10 dk önce · 20:15 · 2s 33dk'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('Atlanmis bildirim satiri yerinde kalir ve aciklanir', (
      tester,
    ) async {
      await pumpCard(
        tester,
        notification: notification,
        skips: {
          SkippedOccurrence(
            kind: SkipKind.notification,
            reference: NotificationScheduler.notificationIdFor(
              date: DateTime(2026, 8, 3),
              prayerType: PrayerType.maghrib,
              minutesBefore: 10,
            ),
            fireAt: notification.time,
          ),
        },
      );

      expect(find.text('Akşam bildirimi'), findsOneWidget);
      expect(find.text('Yalnızca bu sefer atlanacak · 20:15'), findsOneWidget);

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isFalse);
    });

    testWidgets('Atlanmis alarm satiri yerinde kalir ve aciklanir', (
      tester,
    ) async {
      await pumpCard(
        tester,
        alarm: (alarm: sahur, time: alarmAt),
        skips: {
          SkippedOccurrence(
            kind: SkipKind.alarm,
            reference: 'sahur',
            fireAt: alarmAt,
          ),
        },
      );

      expect(find.text('Sahur'), findsOneWidget);
      expect(
        find.text('Yalnızca bu sefer atlanacak · yarın 03:41'),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('Anahtari kapatmak dogru kayitla callback tetikler', (
      tester,
    ) async {
      SkippedOccurrence? received;
      bool? skipped;

      await pumpCard(
        tester,
        alarm: (alarm: sahur, time: alarmAt),
        onSkipChanged: (occurrence, value) {
          received = occurrence;
          skipped = value;
        },
      );

      await tester.tap(find.byType(Switch));

      expect(skipped, isTrue);
      expect(
        received,
        SkippedOccurrence(
          kind: SkipKind.alarm,
          reference: 'sahur',
          fireAt: alarmAt,
        ),
      );
    });

    testWidgets('Atlanmis satirda anahtari acmak geri alir', (tester) async {
      bool? skipped;

      await pumpCard(
        tester,
        alarm: (alarm: sahur, time: alarmAt),
        skips: {
          SkippedOccurrence(
            kind: SkipKind.alarm,
            reference: 'sahur',
            fireAt: alarmAt,
          ),
        },
        onSkipChanged: (_, value) => skipped = value,
      );

      await tester.tap(find.byType(Switch));

      expect(skipped, isFalse);
    });
```

Import ekle:

```dart
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
```

- [ ] **Step 3: Testleri çalıştır, kırmızıyı gör**

```bash
flutter test test/widgets/home/upcoming_card_test.dart
```

Beklenen: `skips`/`onSkipChanged` tanımlı değil.

- [ ] **Step 4: Kartı güncelle**

`lib/presentation/widgets/home/upcoming_card.dart` — alanlar ve constructor:

```dart
  /// Atlanmış örnekler. Satır **dışlanmaz**; yalnızca kapalı çizilir ki
  /// kullanıcı fikrini değiştirip geri açabilsin.
  final Set<SkippedOccurrence> skips;

  /// Anahtar değişince çağrılır. `skipped` true ise atlanacak.
  final void Function(SkippedOccurrence occurrence, bool skipped)?
  onSkipChanged;
```

```dart
  const UpcomingCard({
    super.key,
    required this.now,
    required this.onSeeAll,
    this.notification,
    this.alarm,
    this.skips = const {},
    this.onSkipChanged,
  });
```

`onAlarmToggled` alanını ve constructor parametresini sil.

Ortak anahtar yardımcısı:

```dart
  Widget _skipSwitch(SkippedOccurrence occurrence, bool isSkippedNow) {
    return Switch(
      value: !isSkippedNow,
      onChanged: onSkipChanged == null
          ? null
          : (value) => onSkipChanged!(occurrence, !value),
    );
  }
```

Bildirim satırı:

```dart
  Widget _notificationRow(BuildContext context) {
    final item = notification!;
    final prayerName = PrayerUtils.getPrayerName(item.setting.prayerType);
    final offset = item.setting.minutesBefore == 0
        ? 'Tam vaktinde'
        : '${item.setting.minutesBefore} dk önce';

    final occurrence = SkippedOccurrence(
      kind: SkipKind.notification,
      reference: NotificationScheduler.notificationIdFor(
        // Planlayıcı da kimliği vaktin gününden üretir; ikisi aynı olmak
        // zorunda, yoksa anahtar kapalı görünürken bildirim gelir.
        date: item.prayerDate,
        prayerType: item.setting.prayerType,
        minutesBefore: item.setting.minutesBefore,
      ),
      fireAt: item.time,
    );
    final skipped = isSkipped(
      skips,
      kind: SkipKind.notification,
      reference: occurrence.reference,
      fireAt: item.time,
    );

    return GroupedRow(
      height: _kRowHeight,
      icon: Icons.notifications_rounded,
      title: Text(
        '$prayerName bildirimi',
        style: AppTypography.upcomingRowTitle,
      ),
      subtitle: Text(
        skipped
            ? 'Yalnızca bu sefer atlanacak · ${_clock(item.time)}'
            : '$offset · ${_clock(item.time)} · '
                  '${formatRemaining(item.time.difference(now))}',
      ),
      trailing: _skipSwitch(occurrence, skipped),
    );
  }
```

Alarm satırı:

```dart
  Widget _alarmRow(BuildContext context) {
    final tokens = context.tokens;
    final item = alarm!;
    final label = alarmTimeLabel(item.alarm);
    final title = item.alarm.label.isNotEmpty ? item.alarm.label : label;

    final occurrence = SkippedOccurrence(
      kind: SkipKind.alarm,
      reference: item.alarm.id,
      fireAt: item.time,
    );
    final skipped = isSkipped(
      skips,
      kind: SkipKind.alarm,
      reference: item.alarm.id,
      fireAt: item.time,
    );

    return GroupedRow(
      height: _kRowHeight,
      icon: Icons.alarm_rounded,
      iconColor: tokens.accent,
      title: Text(title, style: AppTypography.upcomingRowTitle),
      subtitle: Text(
        skipped
            ? 'Yalnızca bu sefer atlanacak · '
                  '${_relativeDay(item.time)} ${_clock(item.time)}'
            : '$label · ${_relativeDay(item.time)} ${_clock(item.time)}',
      ),
      trailing: _skipSwitch(occurrence, skipped),
    );
  }
```

Import bloğuna:

```dart
import '../../../core/models/skipped_occurrence.dart';
import '../../../features/notifications/domain/notification_scheduler.dart';
import '../../../features/notifications/domain/skip_rules.dart';
```

- [ ] **Step 5: Kimlik eşleşmesini doğrulayan testi yaz**

`test/notifications/skip_rules_test.dart` sonuna:

```dart
  group('Kimlik uretimi tek noktadan', () {
    test('Karttaki ve planlayicidaki kimlik ayni', () {
      // "Anahtar yalan soylemez" kuralinin temeli: iki taraf da ayni
      // fonksiyondan ayni argumanlarla kimlik uretmeli.
      final fromCard = NotificationScheduler.notificationIdFor(
        date: DateTime(2026, 8, 3),
        prayerType: PrayerType.maghrib,
        minutesBefore: 10,
      );
      final fromScheduler = NotificationScheduler.notificationIdFor(
        date: DateTime(2026, 8, 3, 23, 59),
        prayerType: PrayerType.maghrib,
        minutesBefore: 10,
      );

      // Gun ici saat kimligi degistirmemeli.
      expect(fromCard, fromScheduler);
    });
  });
```

Import ekle:

```dart
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
```

- [ ] **Step 6: Testleri çalıştır**

```bash
flutter test test/widgets/home/upcoming_card_test.dart
flutter test test/presentation/upcoming_resolver_test.dart
flutter test test/notifications/
flutter analyze
```

Beklenen: hepsi geçer. `home_screen.dart` henüz `onAlarmToggled` geçiyorsa analiz hata verir — Task 8'de düzeltilecek; bu task'ta yalnızca kart ve testleri derlenebilir olmalı. Analiz hata veriyorsa Task 8'e geç, sonra ikisini birlikte commit et.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/services/upcoming_resolver.dart \
  lib/presentation/widgets/home/upcoming_card.dart \
  test/widgets/home/upcoming_card_test.dart \
  test/presentation/upcoming_resolver_test.dart \
  test/notifications/skip_rules_test.dart
git commit -m "feat: kart satirlarina tek seferlik kapatma anahtari"
```

---

## Task 8: Bağlantı ve uçtan uca doğrulama

**Files:**
- Modify: `lib/core/providers/app_state.dart`
- Modify: `lib/presentation/services/data_loader_service.dart`
- Modify: `lib/presentation/pages/home_page.dart`
- Modify: `lib/presentation/screens/home_screen.dart`
- Test: `test/presentation/data_loader_service_test.dart`

**Interfaces:**
- Consumes: `SkipManager` (Task 4), `UpcomingCard.skips/onSkipChanged` (Task 7), genişletilmiş planlayıcılar (Task 5, 6).
- Produces: `AppState.skips` / `AppState.setSkips`; `PrayerData.skips`; `HomeScreen.skips` / `HomeScreen.onSkipChanged`.

- [ ] **Step 1: `AppState`'e alanı ekle**

`lib/core/providers/app_state.dart`:

```dart
  Set<SkippedOccurrence> _skips = const {};
```

```dart
  /// "Yalnızca bu sefer" atlanmış örnekler.
  Set<SkippedOccurrence> get skips => _skips;
```

```dart
  void setSkips(Set<SkippedOccurrence> skips) {
    _skips = skips;
    notifyListeners();
  }
```

Import: `import '../models/skipped_occurrence.dart';`

- [ ] **Step 2: `PrayerData`'ya alanı ekle ve testi güncelle**

`lib/presentation/services/data_loader_service.dart` — `PrayerData` kaydına:

```dart
  /// "Yalnızca bu sefer" atlanmış örnekler; süresi geçenler elenmiş hâlde.
  Set<SkippedOccurrence> skips,
```

Constructor'a `SkipManager` ekle:

```dart
  final SkipManager _skipManager;
```

```dart
    required SkipManager skipManager,
```

```dart
       _skipManager = skipManager,
```

`loadPrayerData` içinde, `settings` okunduktan sonra:

```dart
    final skips = await _skipManager.load();
```

ve dönüşe `skips: skips,` ekle.

Import: `import '../../core/models/skipped_occurrence.dart';` ve
`import '../../features/notifications/domain/skip_manager.dart';`

`test/presentation/data_loader_service_test.dart` içindeki `buildLoader` yardımcısına:

```dart
      skipManager: SkipManager(storage: storage),
```

Ve yeni bir test:

```dart
  test('Suresi gecmis atlama kaydi yuklemede elenir', () async {
    final storage = FakeStorage();
    await storage.init();
    await storage.saveSkippedOccurrences([
      SkippedOccurrence(
        kind: SkipKind.alarm,
        reference: 'eski',
        fireAt: DateTime(2020, 1, 1),
      ),
    ]);
    final loader = buildLoader(storage, FakeProvider());

    final data = await loader.loadPrayerData(location);

    expect(data.skips, isEmpty);
  });
```

- [ ] **Step 3: `HomePage`'i bağla**

`lib/presentation/pages/home_page.dart`:

`_initializeServices` içinde `DataLoaderService(...)` çağrısına:

```dart
      skipManager: ServiceLocator().get<SkipManager>(),
```

`_loadPrayerData` içinde, `appState.setAlarms(...)` satırının ardına:

```dart
      appState.setSkips(data.skips);
```

Planlayıcı çağrılarına skip'i geçir (aynı metotta):

```dart
      final scheduler = ServiceLocator().get<NotificationScheduler>();
      await scheduler.scheduleNotifications(
        location: location,
        prayerTimes: data.all,
        skips: data.skips,
      );
      await ServiceLocator().get<AlarmScheduler>().scheduleAlarms(
        prayerTimes: data.all,
        skips: data.skips,
      );
```

`_toggleAlarm` metodunu **sil** ve yerine:

```dart
  /// "SIRADAKİ" kartındaki tek seferlik kapatma.
  ///
  /// Kalıcı kapatma Bildirimler/Alarmlar ekranlarında kalır; buradaki anahtar
  /// yalnızca gösterilen örneği atlar.
  Future<void> _toggleSkip(SkippedOccurrence occurrence, bool skipped) async {
    final appState = context.read<AppState>();
    final manager = ServiceLocator().get<SkipManager>();

    final next = skipped
        ? await manager.skip(occurrence)
        : await manager.unskip(occurrence);
    appState.setSkips(next);

    final location = appState.activeLocation;
    final prayerTimes = appState.prayerTimes;
    if (location == null || prayerTimes.isEmpty) return;

    try {
      await ServiceLocator().get<NotificationScheduler>().scheduleNotifications(
        location: location,
        prayerTimes: prayerTimes,
        skips: next,
      );
      await ServiceLocator().get<AlarmScheduler>().scheduleAlarms(
        prayerTimes: prayerTimes,
        skips: next,
      );
    } catch (e) {
      AppLogger().warning('Atlama sonrasi yeniden planlama basarisiz', e);
    }
  }
```

`_rescheduleOnResume` içindeki iki planlayıcı çağrısına da `skips: appState.skips,` ekle.

`HomeScreen(...)` çağrısında `onAlarmToggled: _toggleAlarm,` satırını şununla değiştir:

```dart
                skips: appState.skips,
                onSkipChanged: _toggleSkip,
```

Import: `import '../../core/models/skipped_occurrence.dart';` ve
`import '../../features/notifications/domain/skip_manager.dart';`

- [ ] **Step 4: `HomeScreen`'i güncelle**

`lib/presentation/screens/home_screen.dart` — `alarms` alanının altındaki
`onAlarmToggled` alanını şununla değiştir:

```dart
  final Set<SkippedOccurrence> skips;
  final void Function(SkippedOccurrence occurrence, bool skipped)?
  onSkipChanged;
```

Constructor'da `this.onAlarmToggled,` yerine:

```dart
    this.skips = const {},
    this.onSkipChanged,
```

`UpcomingCard(...)` çağrısında `onAlarmToggled: widget.onAlarmToggled,` yerine:

```dart
          skips: widget.skips,
          onSkipChanged: widget.onSkipChanged,
```

Import: `import '../../core/models/skipped_occurrence.dart';`
Kullanılmıyorsa `import '../../core/models/alarm.dart';` satırını **silme** —
`alarms` alanı hâlâ `Alarm` kullanıyor.

- [ ] **Step 5: Doğrula**

```bash
flutter analyze
flutter test
```

Beklenen: analiz temiz, tüm testler yeşil.

- [ ] **Step 6: "Anahtar yalan söylemez" testini yaz**

`test/notifications/skip_manager_test.dart` sonuna:

```dart
  test('Saat kayarsa alarm planlanir VE anahtar acik gorunur', () async {
    // Spec degismez kurali: kart ve planlayici ayni sorguyu kullandigi icin
    // ayrisamazlar. Ikisi tek testte birlikte kontrol edilir ki ileride biri
    // degisirse digeri de dussun.
    const alarm = Alarm(
      id: 'sahur',
      kind: AlarmKind.fixed,
      label: 'Sahur',
      hour: 6,
      minute: 30,
    );
    final staleSkip = SkippedOccurrence(
      kind: SkipKind.alarm,
      reference: 'sahur',
      fireAt: DateTime(2026, 8, 6, 6, 25), // eski saat
    );
    final actualFire = DateTime(2026, 8, 6, 6, 30); // vakit kaydi

    // Planlayici: kayit eslesmedigi icin alarmi planlar.
    final fire = AlarmScheduler.computeNextFire(
      alarm: alarm,
      now: DateTime(2026, 8, 5, 7),
      prayerTimesByDate: const {},
      skips: {staleSkip},
    );
    expect(fire, actualFire);

    // Kart: ayni sorgu atlanmis demiyor, yani anahtar acik cizilir.
    expect(
      isSkipped(
        {staleSkip},
        kind: SkipKind.alarm,
        reference: 'sahur',
        fireAt: actualFire,
      ),
      isFalse,
    );
  });
```

Import ekle:

```dart
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:ezanvakti/features/notifications/domain/skip_rules.dart';
```

- [ ] **Step 7: `resolveNextAlarm` ayrımını koruyan testi yaz**

`test/presentation/upcoming_resolver_test.dart` içindeki `resolveNextAlarm`
grubuna:

```dart
    test('Atlanmis alarmi yine de dondurur', () {
      // D2: kart bir sonrakine gecmez, satir yerinde kalir ki kullanici geri
      // acabilsin. Bu yuzden resolveNextAlarm skip kumesi ALMAZ.
      final next = resolveNextAlarm(
        alarms: const [fixed],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 23),
      );

      expect(next?.alarm.id, 'fixed');
      expect(next?.time, DateTime(2026, 8, 4, 6, 30));
    });
```

Ayrıca imza kontrolü:

```bash
grep -c "skips" lib/presentation/services/upcoming_resolver.dart
```

Beklenen: `0`.

- [ ] **Step 8: Testleri çalıştır**

```bash
flutter test
flutter analyze
```

Beklenen: hepsi yeşil, analiz temiz.

- [ ] **Step 9: Simülatörde uçtan uca doğrula**

```bash
SIM=86EB40FD-7B75-4BCC-91CA-DCBED258902C
flutter build ios --simulator --debug
xcrun simctl install "$SIM" build/ios/iphonesimulator/Runner.app
xcrun simctl terminate "$SIM" com.ekrembulbul.ezanvakti || true
xcrun simctl launch "$SIM" com.ekrembulbul.ezanvakti
```

Kontrol listesi:
- SIRADAKİ kartında bildirim satırının sağında anahtar var; alt metinde
  `<sapma> · <saat> · <kalan süre>` yazıyor.
- Anahtarı kapat → satır **yerinde kalıyor**, alt metin
  `Yalnızca bu sefer atlanacak · <saat>` oluyor.
- Uygulamayı öldürüp yeniden aç → satır hâlâ kapalı (kayıt kalıcı).
- Anahtarı geri aç → alt metin eskiye dönüyor.

- [ ] **Step 10: Commit**

```bash
git add lib/ test/
git commit -m "feat: tek seferlik kapatmayi uctan uca bagla"
```

---

## Task 9: Kapanış

**Files:** Değişiklik yok; yalnızca doğrulama.

- [ ] **Step 1: Tam süit ve analiz**

```bash
flutter test
flutter analyze
```

Beklenen: hepsi yeşil, `No issues found!`.

- [ ] **Step 2: Ölü kod taraması**

```bash
grep -rn "onAlarmToggled" lib/ test/
```

Beklenen: **çıktı yok.** Kartın kalıcı kapatma yolu tamamen kaldırıldı.

- [ ] **Step 3: CHANGELOG**

`CHANGELOG.md` — `## [0.3.0]` bölümünün `### Eklendi` listesine:

```markdown
- Ana ekrandaki **SIRADAKİ** kartından bildirimi veya alarmı **yalnızca o seferliğine** kapatma. Kalıcı kapatma Bildirimler ve Alarmlar ekranlarında kalır; karttaki anahtar kapalıyken satır "Yalnızca bu sefer atlanacak" yazar ve örnek geçince kendiliğinden normale döner.
```

- [ ] **Step 4: Çalışma ağacı temiz mi**

```bash
git add CHANGELOG.md
git commit -m "docs: tek seferlik kapatmayi CHANGELOG'a ekle"
git status --short
```

Beklenen: `git status` boş.

---

## Öz-inceleme notları

**Spec kapsaması.** D1 → Task 1 (fireAt kimliğin parçası) + Task 5/6 (yalnızca o örnek elenir). D2 → Task 7 (satır dışlanmaz) + Task 8 Step 7 (resolveNextAlarm skip almaz). D3 → Task 7 alt metinleri. D4 → Task 7 bildirim satırı. D5 → Task 3. D6 → Task 2 `withoutExpired` + Task 4 `load`. Değişmez kural → Task 8 Step 6. §7'deki tüm test kalemleri ilgili task'lara dağıtıldı.

**Kapatılan risk — kimlik tarihi.** Planlayıcı kimliği `prayerTime.date` ile üretiyor; kartın elinde yalnızca tetiklenme anı vardı ve sapmalı bildirimde ikisi ayrışabilirdi. Bu, "anahtar yalan söylemez" kuralını sessizce kırardı. Uyarı yazmak yerine `UpcomingNotification`'a `prayerDate` eklendi (Task 7 Step 1): iki taraf artık aynı alanı kullanıyor, ayrışma yapısal olarak imkânsız.

**Kapsam dışı.** Kartta ikiden fazla satır, "bugünü sustur", sessiz saatler. Bildirimler/Alarmlar ekranlarının kalıcı kapatma davranışı değişmiyor.
