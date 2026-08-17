# Görev Tabanlı Kapatma — Altyapı + Matematik Görevi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOS'ta bir alarmın ancak matematik görevi tamamlandıktan sonra kapanması; görev yapılmazsa alarmın geri dönmesi.

**Architecture:** Kullanıcı alarmı sistemin kaydırmalı durdurmasıyla susturunca `stopIntent` çalışır, uygulamayı görev ekranında açar ve bir nöbetçi alarm kurar. Görev tamamlanana kadar nöbetçi zinciri devam eder; tamamlanınca zincirdeki tüm alarmlar iptal edilir. Karar değerleri (son tarih, tekrar tavanı) Dart'ta hesaplanır ve UserDefaults'a yazılır; Swift yalnızca iki karşılaştırma yapıp alarmı yeniden kurar — mantık tek yerde kalsın diye.

**Tech Stack:** Flutter, `sqflite`, `provider`, `flutter_test`, Swift + AlarmKit + AppIntents. **Yeni Dart paketi eklenmez** (matematik görevi hiçbir bağımlılık istemez; sensör ve kamera paketleri sallama/QR planlarına bırakıldı).

**Spec:** `docs/superpowers/specs/2026-08-17-gorev-tabanli-kapatma-design.md`

## Global Constraints

- Kod/dosya/sınıf/fonksiyon adları **İngilizce**; kullanıcıya görünen metin ve yorumlar **Türkçe**.
- **Renk sabiti yazılmaz.** Renk `context.tokens`, tipografi `AppTypography`.
- Font boyutu için çıplak sayı yok; ölçek `11 · 12 · 13 · 14 · 16 · 17 · 20 · 24 · 44 · 62`.
- Kontrol animasyonları **220 ms `Curves.easeOutCubic`**.
- **iOS 26.1+** gerekli: `AlarmPresentation.Alert(title:secondaryButton:secondaryButtonBehavior:)` init'i o sürümde geldi, `stopButton`'lu init deprecated.
- **Görev kapalıysa (`AlarmMission.none`) bugünkü davranış birebir korunur**: `.countdown` erteleme, `stopIntent` yok, zincir yok (spec D6). Her task bunu bozmadığını göstermek zorunda.
- Zincirin kurduğu **her** alarm id'si deftere yazılır; kaydedilmeyen alarm kurulmaz (spec D10).
- Acil çıkışın **tavanı vardır** ve her zaman erişilebilir (spec D9/D18). Bunu kaldıran hiçbir değişiklik kabul edilmez.
- Her task sonunda `flutter analyze` temiz ve `flutter test` yeşil.
- Commit'ler `feat/gorev-tabanli-kapatma` branch'ine.

### Simülatör uyarısı

App Intents simülatörde **çalışmaz** (spec M3: `linkd` ad-hoc imzalı build'i reddeder). `stopIntent`'e dokunan hiçbir davranış simülatörde doğrulanamaz. Task 1–7 ve 9–13 simülatör/masaüstü testleriyle tamamlanır; Task 8 ve 14 **fiziksel cihaz** gerektirir.

### Dosya haritası

| Dosya | Sorumluluk |
|---|---|
| `lib/core/config/mission_tuning.dart` | Kalibrasyon sabitleri, görev süreleri (yeni) |
| `lib/core/models/alarm_mission.dart` | `AlarmMission` enum (yeni) |
| `lib/core/models/mission_session.dart` | Çalışan görev oturumu (yeni) |
| `lib/core/models/abort_state.dart` | Global acil çıkış kademesi (yeni) |
| `lib/features/alarms/domain/mission_chain.dart` | Zincir kararları, nöbetçi id/tarih hesabı (yeni) |
| `lib/features/alarms/domain/math_challenge.dart` | Matematik soru üretimi/doğrulaması (yeni) |
| `lib/features/alarms/domain/abort_gate.dart` | Kademe kuralları, cümle doğrulama (yeni) |
| `lib/presentation/screens/mission_screen.dart` | Görev ekranı kabuğu: geri sayım, erteleme, acil çıkış (yeni) |
| `lib/presentation/widgets/missions/math_mission.dart` | Matematik görev gövdesi (yeni) |
| `lib/presentation/widgets/missions/abort_dialog.dart` | Kademeli acil çıkış akışı (yeni) |
| `lib/core/models/alarm.dart` | `mission`, `missionLevel`, `maxSnoozes` alanları |
| `lib/core/interfaces/alarm_service.dart` | Kontrat: görev alanları + 4 yeni method |
| `lib/core/interfaces/local_storage.dart` | Oturum + abort state kalıcılığı |
| `lib/features/alarms/data/native_alarm_service.dart` | Channel çağrıları |
| `lib/features/prayer_times/data/sqlite_storage.dart` | Migration v7, yeni kalıcılık |
| `lib/features/alarms/domain/alarm_scheduler.dart` | Görev alanlarını ve zincir yapılandırmasını geçirir |
| `lib/presentation/screens/alarm_edit_screen.dart` | Görev seçimi + erteleme sayısı |
| `ios/Runner/AppDelegate.swift` | `stopIntent`, zincir, 4 yeni channel method |

---

### Task 1: Kalibrasyon sabitleri ve `AlarmMission`

**Files:**
- Create: `lib/core/config/mission_tuning.dart`
- Create: `lib/core/models/alarm_mission.dart`
- Test: `test/alarms/mission_tuning_test.dart`

**Interfaces:**
- Consumes: yok (ilk task)
- Produces: `enum AlarmMission { none, math, shake, qr }`, `AlarmMission.requiresGate → bool`, `MissionTuning.graceSeconds/ladderStepMinutes/ladderCount/maxRearms/chainDeadlineMinutes/abortDecayDays/abortMaxLevel → int`, `MissionTuning.timeoutSecondsFor(AlarmMission) → int`

- [ ] **Step 1: Failing test yaz**

`test/alarms/mission_tuning_test.dart`:

```dart
import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlarmMission', () {
    test('none disinda hepsi kapi ister', () {
      expect(AlarmMission.none.requiresGate, isFalse);
      expect(AlarmMission.math.requiresGate, isTrue);
      expect(AlarmMission.shake.requiresGate, isTrue);
      expect(AlarmMission.qr.requiresGate, isTrue);
    });
  });

  group('MissionTuning', () {
    test('QR suresi matematikten uzun', () {
      // Kodun bulundugu yere yurumek gerekiyor; spec D13.
      expect(
        MissionTuning.timeoutSecondsFor(AlarmMission.qr),
        greaterThan(MissionTuning.timeoutSecondsFor(AlarmMission.math)),
      );
    });

    test('Her gorev tipi icin pozitif sure tanimli', () {
      for (final m in AlarmMission.values.where((m) => m.requiresGate)) {
        expect(MissionTuning.timeoutSecondsFor(m), greaterThan(0));
      }
    });

    test('none icin sure sorulmaz, sifir doner', () {
      expect(MissionTuning.timeoutSecondsFor(AlarmMission.none), 0);
    });

    test('Acil cikis tavani en az bir kademe birakir', () {
      expect(MissionTuning.abortMaxLevel, greaterThanOrEqualTo(1));
    });
  });
}
```

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/alarms/mission_tuning_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:ezanvakti/core/config/mission_tuning.dart'`

- [ ] **Step 3: `AlarmMission` yaz**

`lib/core/models/alarm_mission.dart`:

```dart
/// Alarmın kapatılabilmesi için tamamlanması gereken görev.
///
/// [none] bugünkü davranıştır: alarm kaydırılarak doğrudan kapanır. Diğerleri
/// kapatmayı bir göreve bağlar (spec D2: kapı yalnızca kapatmada).
enum AlarmMission { none, math, shake, qr }

extension AlarmMissionX on AlarmMission {
  /// Bu görev, kapatmanın önüne bir kapı koyuyor mu?
  bool get requiresGate => this != AlarmMission.none;
}
```

- [ ] **Step 4: `MissionTuning` yaz**

`lib/core/config/mission_tuning.dart`:

```dart
import '../models/alarm_mission.dart';

/// Görev zincirinin kalibrasyon sabitleri.
///
/// Bunlar **kullanıcı ayarı değildir** (spec D14): Ayarlar ekranında görünmez,
/// ölçümle kalibre edilmek için tek yerde toplanmıştır. Başlangıç değerleri
/// tahmindir; cihazda ölçülüp güncellenecek.
class MissionTuning {
  const MissionTuning._();

  /// Alarm durduruldu ama görev ekranı hiç açılmadı; alarmın dönmesi için
  /// beklenen süre. Durdurup uykuya dönen kullanıcı tam görev süresini
  /// beklemeden yakalanmalı.
  static const int graceSeconds = 20;

  /// Sağlama merdiveni: `stopIntent` hiç çalışmazsa devreye giren, alarm
  /// kurulurken önden dizilen yedekler (spec §5.2).
  static const int ladderStepMinutes = 5;
  static const int ladderCount = 3;

  /// Zincirin sert tavanları. İkisinden hangisi önce dolarsa zincir durur —
  /// bir hata sonsuz alarma dönüşmesin (spec D8).
  static const int maxRearms = 40;
  static const int chainDeadlineMinutes = 60;

  /// Acil çıkış kademesi: tavan ve gerileme (spec D18).
  static const int abortMaxLevel = 3;
  static const int abortDecayDays = 7;

  /// Görev süresi, tipe göre. Görev ekranı açıldığı anda işlemeye başlar.
  static const Map<AlarmMission, int> _timeouts = {
    AlarmMission.none: 0,
    AlarmMission.math: 90,
    AlarmMission.shake: 60,
    AlarmMission.qr: 180,
  };

  /// [mission] için görev süresi (sn). [AlarmMission.none] için 0.
  static int timeoutSecondsFor(AlarmMission mission) => _timeouts[mission] ?? 0;
}
```

- [ ] **Step 5: Test'i çalıştır, geçtiğini gör**

Run: `flutter test test/alarms/mission_tuning_test.dart`
Expected: PASS (5 test)

- [ ] **Step 6: Commit**

```bash
git add lib/core/config/mission_tuning.dart lib/core/models/alarm_mission.dart test/alarms/mission_tuning_test.dart
git commit -m "feat: gorev tipi ve kalibrasyon sabitleri"
```

---

### Task 2: `Alarm` modeline görev alanları ve migration v7

**Files:**
- Modify: `lib/core/models/alarm.dart`
- Modify: `lib/features/prayer_times/data/sqlite_storage.dart:31` (version), `:96` (`_createAlarmsTable`), `:183` (migration zinciri sonu)
- Test: `test/alarms/alarm_mission_fields_test.dart`

**Interfaces:**
- Consumes: `AlarmMission` (Task 1)
- Produces: `Alarm.mission → AlarmMission`, `Alarm.missionLevel → int`, `Alarm.maxSnoozes → int?`; `toMap()` anahtarları `mission`, `mission_level`, `max_snoozes`

- [ ] **Step 1: Failing test yaz**

`test/alarms/alarm_mission_fields_test.dart`:

```dart
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Alarm gorev alanlari', () {
    test('Varsayilan gorevsiz ve sinirsiz erteleme', () {
      const a = Alarm(id: 'a', kind: AlarmKind.fixed);
      expect(a.mission, AlarmMission.none);
      expect(a.missionLevel, 1);
      expect(a.maxSnoozes, isNull);
    });

    test('toMap/fromMap gorev alanlarini korur', () {
      const a = Alarm(
        id: 'a',
        kind: AlarmKind.fixed,
        mission: AlarmMission.math,
        missionLevel: 3,
        maxSnoozes: 2,
      );
      final round = Alarm.fromMap(a.toMap());
      expect(round.mission, AlarmMission.math);
      expect(round.missionLevel, 3);
      expect(round.maxSnoozes, 2);
      expect(round, a);
    });

    test('Eski kayit (gorev kolonlari yok) gorevsiz okunur', () {
      // v6 semasindan gelen satir: yeni kolonlar hic yok.
      final map = <String, dynamic>{
        'id': 'eski',
        'kind': 'fixed',
        'label': '',
        'is_active': 1,
        'hour': 5,
        'minute': 0,
        'anchor': 'fajr',
        'offset_minutes': 0,
        'weekdays': '',
        'sound_id': 'adhan',
        'vibrate': 1,
        'snooze_enabled': 1,
        'snooze_minutes': 5,
      };
      final a = Alarm.fromMap(map);
      expect(a.mission, AlarmMission.none);
      expect(a.missionLevel, 1);
      expect(a.maxSnoozes, isNull);
    });

    test('Bilinmeyen gorev adi gorevsize duser', () {
      const a = Alarm(id: 'a', kind: AlarmKind.fixed);
      final map = a.toMap()..['mission'] = 'telekinezi';
      expect(Alarm.fromMap(map).mission, AlarmMission.none);
    });

    test('copyWith maxSnoozes null verirse mevcut deger korunur', () {
      // Dart'ta null "degistirme" ile "temizle" ayirt edilemez; dokumante
      // edilmis davranis: null = dokunma.
      const a = Alarm(id: 'a', kind: AlarmKind.fixed, maxSnoozes: 3);
      expect(a.copyWith().maxSnoozes, 3);
      expect(a.copyWith(maxSnoozes: 1).maxSnoozes, 1);
    });
  });
}
```

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/alarms/alarm_mission_fields_test.dart`
Expected: FAIL — `No named parameter with the name 'mission'`

- [ ] **Step 3: `Alarm` modelini genişlet**

`lib/core/models/alarm.dart` — import ekle, üç alan ekle, `toMap`/`fromMap`/`copyWith`/`==`/`hashCode`'a işle:

```dart
import 'alarm_mission.dart';
```

Alan bildirimleri (`snoozeMinutes`'ten sonra):

```dart
  /// Alarmı kapatmak için gereken görev. [AlarmMission.none] ise alarm
  /// bugünkü gibi doğrudan kapanır (spec D6).
  final AlarmMission mission;

  /// Görev zorluğu (1–3). Yükseldikçe süre değil **iş miktarı** artar.
  final int missionLevel;

  /// Uygulama içi erteleme üst sınırı. `null` = sınırsız. Görev açıkken
  /// `null` bırakılamaz (bkz. Task 12).
  final int? maxSnoozes;
```

Constructor'a:

```dart
    this.mission = AlarmMission.none,
    this.missionLevel = 1,
    this.maxSnoozes,
```

`toMap()` içine:

```dart
      'mission': mission.name,
      'mission_level': missionLevel,
      'max_snoozes': maxSnoozes,
```

`fromMap()` içine:

```dart
      mission: AlarmMission.values.firstWhere(
        (e) => e.name == map['mission'],
        orElse: () => AlarmMission.none,
      ),
      missionLevel: map['mission_level'] as int? ?? 1,
      maxSnoozes: map['max_snoozes'] as int?,
```

`copyWith` imzasına `AlarmMission? mission, int? missionLevel, int? maxSnoozes` ekle ve gövdede `mission ?? this.mission` biçiminde geçir. `==` karşılaştırmasına ve `hashCode`'a üç alanı da ekle.

- [ ] **Step 4: Test'i çalıştır, geçtiğini gör**

Run: `flutter test test/alarms/alarm_mission_fields_test.dart`
Expected: PASS (5 test)

- [ ] **Step 5: Migration v7 yaz**

`lib/features/prayer_times/data/sqlite_storage.dart`:

`version: 6` → `version: 7`.

`_createAlarmsTable` içindeki `CREATE TABLE alarms` gövdesine, `snooze_minutes` satırından sonra virgülle:

```sql
        mission TEXT NOT NULL DEFAULT 'none',
        mission_level INTEGER NOT NULL DEFAULT 1,
        max_snoozes INTEGER
```

`_onUpgrade` sonuna, `if (oldVersion < 6)` bloğundan sonra:

```dart
    if (oldVersion < 7) {
      // Mevcut alarmlar gorevsiz kalir: acilis davranisi degismemeli.
      await db.execute(
        "ALTER TABLE alarms ADD COLUMN mission TEXT NOT NULL DEFAULT 'none'",
      );
      await db.execute(
        'ALTER TABLE alarms ADD COLUMN mission_level INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute('ALTER TABLE alarms ADD COLUMN max_snoozes INTEGER');
    }
```

- [ ] **Step 6: Tüm testleri çalıştır**

Run: `flutter test && flutter analyze`
Expected: Tüm testler PASS, analyze temiz. `Alarm` eşitliğine dokunulduğu için mevcut alarm testleri de yeşil kalmalı.

- [ ] **Step 7: Commit**

```bash
git add lib/core/models/alarm.dart lib/features/prayer_times/data/sqlite_storage.dart test/alarms/alarm_mission_fields_test.dart
git commit -m "feat: Alarm modeline gorev alanlari ve migration v7"
```

---

### Task 3: `MissionChain` — zincir kararları

**Files:**
- Create: `lib/features/alarms/domain/mission_chain.dart`
- Test: `test/alarms/mission_chain_test.dart`

**Interfaces:**
- Consumes: `MissionTuning`, `AlarmMission` (Task 1)
- Produces: `ChainState({int rearmCount, DateTime chainDeadline, DateTime deadline})`, `enum ChainDecision { rearm, stop }`, `MissionChain.decide({ChainState state, DateTime now}) → ChainDecision`, `MissionChain.deadlineAfterStop(DateTime now) → DateTime`, `MissionChain.deadlineAfterBegin({DateTime now, AlarmMission mission}) → DateTime`, `MissionChain.chainDeadline(DateTime firedAt) → DateTime`, `MissionChain.ladder(DateTime firedAt) → List<DateTime>`, `MissionChain.watchdogId(String alarmId, int index) → String`

- [ ] **Step 1: Failing test yaz**

`test/alarms/mission_chain_test.dart`:

```dart
import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/features/alarms/domain/mission_chain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fired = DateTime(2026, 8, 17, 5, 0);

  ChainState state({int rearmCount = 0, Duration? deadlineIn}) => ChainState(
    rearmCount: rearmCount,
    chainDeadline: MissionChain.chainDeadline(fired),
    deadline: fired.add(deadlineIn ?? const Duration(seconds: 20)),
  );

  group('MissionChain.decide', () {
    test('Sinirlar dolmadiysa yeniden kurar', () {
      expect(
        MissionChain.decide(state: state(), now: fired),
        ChainDecision.rearm,
      );
    });

    test('Tekrar tavani dolduysa durur', () {
      expect(
        MissionChain.decide(
          state: state(rearmCount: MissionTuning.maxRearms),
          now: fired,
        ),
        ChainDecision.stop,
      );
    });

    test('Sure tavani dolduysa durur', () {
      final late = fired.add(
        const Duration(minutes: MissionTuning.chainDeadlineMinutes + 1),
      );
      expect(
        MissionChain.decide(state: state(), now: late),
        ChainDecision.stop,
      );
    });

    test('Sure tavani tam sinirda durur', () {
      final exactly = MissionChain.chainDeadline(fired);
      expect(
        MissionChain.decide(state: state(), now: exactly),
        ChainDecision.stop,
      );
    });
  });

  group('Son tarih hesabi', () {
    test('Durdurma sonrasi grace kadar', () {
      expect(
        MissionChain.deadlineAfterStop(fired),
        fired.add(Duration(seconds: MissionTuning.graceSeconds)),
      );
    });

    test('Gorev ekrani acilinca gorev suresi kadar', () {
      expect(
        MissionChain.deadlineAfterBegin(
          now: fired,
          mission: AlarmMission.math,
        ),
        fired.add(
          Duration(
            seconds: MissionTuning.timeoutSecondsFor(AlarmMission.math),
          ),
        ),
      );
    });

    test('QR suresi matematikten uzun oldugu icin son tarih de uzak', () {
      final math = MissionChain.deadlineAfterBegin(
        now: fired,
        mission: AlarmMission.math,
      );
      final qr = MissionChain.deadlineAfterBegin(
        now: fired,
        mission: AlarmMission.qr,
      );
      expect(qr.isAfter(math), isTrue);
    });
  });

  group('Saglama merdiveni', () {
    test('Basamak sayisi ve araliklar sabitlerden gelir', () {
      final steps = MissionChain.ladder(fired);
      expect(steps, hasLength(MissionTuning.ladderCount));
      expect(
        steps.first,
        fired.add(Duration(minutes: MissionTuning.ladderStepMinutes)),
      );
      expect(
        steps.last,
        fired.add(
          Duration(
            minutes:
                MissionTuning.ladderStepMinutes * MissionTuning.ladderCount,
          ),
        ),
      );
    });

    test('Basamaklar artan sirada', () {
      final steps = MissionChain.ladder(fired);
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i].isAfter(steps[i - 1]), isTrue);
      }
    });
  });

  group('watchdogId', () {
    test('Ana id ile cakismaz ve indeksle ayrisir', () {
      expect(MissionChain.watchdogId('sahur', 1), 'sahur#w1');
      expect(MissionChain.watchdogId('sahur', 2), isNot('sahur#w1'));
      expect(MissionChain.watchdogId('sahur', 1), isNot('sahur'));
    });
  });
}
```

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/alarms/mission_chain_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../mission_chain.dart'`

- [ ] **Step 3: `MissionChain` yaz**

`lib/features/alarms/domain/mission_chain.dart`:

```dart
import '../../../core/config/mission_tuning.dart';
import '../../../core/models/alarm_mission.dart';

/// Zincirin o anki durumu. Native taraf bu üç değeri UserDefaults'tan okur;
/// hesabı burada, tek yerde yapılır (spec D11 sınırı: Swift yalnızca iki
/// karşılaştırma yapar, mantığı taşımaz).
class ChainState {
  final int rearmCount;

  /// Zincirin sert süre tavanı. Alarmın çaldığı andan itibaren işler.
  final DateTime chainDeadline;

  /// Yürürlükteki sayacın bitişi: `grace` ya da görev süresi.
  final DateTime deadline;

  const ChainState({
    required this.rearmCount,
    required this.chainDeadline,
    required this.deadline,
  });
}

enum ChainDecision { rearm, stop }

/// Nöbetçi zincirinin kararlarını ve tarihlerini hesaplar. Saf fonksiyonlar;
/// zamanı dışarıdan alır, `DateTime.now()` çağırmaz.
class MissionChain {
  const MissionChain._();

  /// Zincir devam etmeli mi? Tavanlardan biri dolduysa durur (spec D8).
  static ChainDecision decide({
    required ChainState state,
    required DateTime now,
  }) {
    if (state.rearmCount >= MissionTuning.maxRearms) return ChainDecision.stop;
    if (!now.isBefore(state.chainDeadline)) return ChainDecision.stop;
    return ChainDecision.rearm;
  }

  /// Alarm durduruldu, görev ekranı henüz açılmadı.
  static DateTime deadlineAfterStop(DateTime now) =>
      now.add(const Duration(seconds: MissionTuning.graceSeconds));

  /// Görev ekranı açıldı; sayaç görev süresine geçer.
  static DateTime deadlineAfterBegin({
    required DateTime now,
    required AlarmMission mission,
  }) => now.add(Duration(seconds: MissionTuning.timeoutSecondsFor(mission)));

  static DateTime chainDeadline(DateTime firedAt) => firedAt.add(
    const Duration(minutes: MissionTuning.chainDeadlineMinutes),
  );

  /// `stopIntent` hiç çalışmazsa devreye giren, önden kurulan yedekler.
  static List<DateTime> ladder(DateTime firedAt) => [
    for (var i = 1; i <= MissionTuning.ladderCount; i++)
      firedAt.add(Duration(minutes: MissionTuning.ladderStepMinutes * i)),
  ];

  /// Nöbetçi alarmın id'si. Ana alarmla çakışmaması şart: defter bu id
  /// üzerinden iptal ediyor (spec D10).
  static String watchdogId(String alarmId, int index) => '$alarmId#w$index';
}
```

- [ ] **Step 4: Test'i çalıştır, geçtiğini gör**

Run: `flutter test test/alarms/mission_chain_test.dart`
Expected: PASS (9 test)

- [ ] **Step 5: Commit**

```bash
git add lib/features/alarms/domain/mission_chain.dart test/alarms/mission_chain_test.dart
git commit -m "feat: gorev zinciri karar mantigi"
```

---

### Task 4: Matematik görevi

**Files:**
- Create: `lib/features/alarms/domain/math_challenge.dart`
- Test: `test/alarms/math_challenge_test.dart`

**Interfaces:**
- Consumes: yok
- Produces: `MathQuestion({int a, int b, MathOp op})` + `MathQuestion.answer → int` + `MathQuestion.text → String`, `enum MathOp { add, subtract, multiply }`, `MathChallenge.questionCount(int level) → int`, `MathChallenge.generate({required int level, required Random random}) → List<MathQuestion>`

- [ ] **Step 1: Failing test yaz**

`test/alarms/math_challenge_test.dart`:

```dart
import 'dart:math';

import 'package:ezanvakti/features/alarms/domain/math_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MathQuestion', () {
    test('Dort islem dogru hesaplanir', () {
      expect(const MathQuestion(a: 7, b: 5, op: MathOp.add).answer, 12);
      expect(const MathQuestion(a: 7, b: 5, op: MathOp.subtract).answer, 2);
      expect(const MathQuestion(a: 7, b: 5, op: MathOp.multiply).answer, 35);
    });

    test('Metin ekranda okunacak bicimde', () {
      expect(const MathQuestion(a: 12, b: 3, op: MathOp.multiply).text, '12 × 3');
      expect(const MathQuestion(a: 12, b: 3, op: MathOp.subtract).text, '12 − 3');
    });
  });

  group('MathChallenge.questionCount', () {
    test('Seviye yukseldikce is miktari artar', () {
      expect(
        MathChallenge.questionCount(2),
        greaterThan(MathChallenge.questionCount(1)),
      );
      expect(
        MathChallenge.questionCount(3),
        greaterThan(MathChallenge.questionCount(2)),
      );
    });

    test('Aralik disi seviye en yakin uca kirpilir', () {
      expect(MathChallenge.questionCount(0), MathChallenge.questionCount(1));
      expect(MathChallenge.questionCount(9), MathChallenge.questionCount(3));
    });
  });

  group('MathChallenge.generate', () {
    test('Seviyeye gore soru sayisi uretir', () {
      for (final level in [1, 2, 3]) {
        final qs = MathChallenge.generate(level: level, random: Random(1));
        expect(qs, hasLength(MathChallenge.questionCount(level)));
      }
    });

    test('Ayni seed ayni sorulari verir (deterministik)', () {
      final a = MathChallenge.generate(level: 2, random: Random(42));
      final b = MathChallenge.generate(level: 2, random: Random(42));
      expect([for (final q in a) q.text], [for (final q in b) q.text]);
    });

    test('Cikarmada sonuc negatif olmaz', () {
      // Uykulu kullaniciya negatif sayi sordurmak gereksiz zorluk.
      for (var seed = 0; seed < 200; seed++) {
        for (final level in [1, 2, 3]) {
          final qs = MathChallenge.generate(level: level, random: Random(seed));
          for (final q in qs) {
            expect(q.answer, greaterThanOrEqualTo(0), reason: q.text);
          }
        }
      }
    });

    test('Seviye 1 carpma icermez', () {
      for (var seed = 0; seed < 100; seed++) {
        final qs = MathChallenge.generate(level: 1, random: Random(seed));
        expect(qs.every((q) => q.op != MathOp.multiply), isTrue);
      }
    });

    test('Islemler tek haneli-asikar olmaz: en az bir operand > 9', () {
      for (var seed = 0; seed < 100; seed++) {
        final qs = MathChallenge.generate(level: 3, random: Random(seed));
        for (final q in qs) {
          expect(q.a > 9 || q.b > 9, isTrue, reason: q.text);
        }
      }
    });
  });
}
```

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/alarms/math_challenge_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../math_challenge.dart'`

- [ ] **Step 3: `MathChallenge` yaz**

`lib/features/alarms/domain/math_challenge.dart`:

```dart
import 'dart:math';

enum MathOp { add, subtract, multiply }

/// Tek bir matematik sorusu. Değişmez; ekranda [text], doğrulamada [answer].
class MathQuestion {
  final int a;
  final int b;
  final MathOp op;

  const MathQuestion({required this.a, required this.b, required this.op});

  int get answer => switch (op) {
    MathOp.add => a + b,
    MathOp.subtract => a - b,
    MathOp.multiply => a * b,
  };

  /// Ekranda gösterilecek metin. Eksi işareti için U+2212 kullanılır; kısa
  /// tire rakamların yanında tire gibi okunuyor.
  String get text => switch (op) {
    MathOp.add => '$a + $b',
    MathOp.subtract => '$a − $b',
    MathOp.multiply => '$a × $b',
  };
}

/// Matematik görevinin soru üretimi ve zorluk kademeleri.
///
/// Zorluk **soru sayısı ve sayı büyüklüğüyle** artar, süreyle değil: görev
/// süresi tipe göre sabittir (spec D13).
class MathChallenge {
  const MathChallenge._();

  static const Map<int, int> _counts = {1: 2, 2: 3, 3: 5};

  static int _clampLevel(int level) => level.clamp(1, 3);

  static int questionCount(int level) => _counts[_clampLevel(level)]!;

  /// [level] için soru üretir. [random] dışarıdan verilir ki testler
  /// deterministik olsun.
  static List<MathQuestion> generate({
    required int level,
    required Random random,
  }) {
    final l = _clampLevel(level);
    return [
      for (var i = 0; i < questionCount(l); i++) _one(l, random),
    ];
  }

  static MathQuestion _one(int level, Random random) {
    switch (level) {
      case 1:
        // Iki haneli toplama/cikarma.
        final op = random.nextBool() ? MathOp.add : MathOp.subtract;
        final x = 10 + random.nextInt(90);
        final y = 10 + random.nextInt(90);
        return op == MathOp.subtract
            ? MathQuestion(a: max(x, y), b: min(x, y), op: op)
            : MathQuestion(a: x, b: y, op: op);
      case 2:
        // Iki haneli x tek haneli.
        return MathQuestion(
          a: 10 + random.nextInt(90),
          b: 2 + random.nextInt(8),
          op: MathOp.multiply,
        );
      default:
        // Iki haneli x iki haneli.
        return MathQuestion(
          a: 11 + random.nextInt(89),
          b: 11 + random.nextInt(89),
          op: MathOp.multiply,
        );
    }
  }
}
```

- [ ] **Step 4: Test'i çalıştır, geçtiğini gör**

Run: `flutter test test/alarms/math_challenge_test.dart`
Expected: PASS (9 test)

- [ ] **Step 5: Commit**

```bash
git add lib/features/alarms/domain/math_challenge.dart test/alarms/math_challenge_test.dart
git commit -m "feat: matematik gorevi soru uretimi"
```

---

### Task 5: Acil çıkış kademesi

**Files:**
- Create: `lib/core/models/abort_state.dart`
- Create: `lib/features/alarms/domain/abort_gate.dart`
- Test: `test/alarms/abort_gate_test.dart`

**Interfaces:**
- Consumes: `MissionTuning` (Task 1)
- Produces: `AbortState({int level, DateTime? lastUsedAt})` + `toJson()/fromJson()`, `AbortGate.effectiveLevel({AbortState state, DateTime now}) → int`, `AbortGate.escalate({AbortState state, DateTime now}) → AbortState`, `AbortRequirement({bool requiresPhrase, String phrase, int countdownSeconds})`, `AbortGate.requirementFor(int level) → AbortRequirement`, `AbortGate.phraseMatches({String expected, String typed}) → bool`, `AbortGate.isAtCeiling(int level) → bool`

- [ ] **Step 1: Failing test yaz**

`test/alarms/abort_gate_test.dart`:

```dart
import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/core/models/abort_state.dart';
import 'package:ezanvakti/features/alarms/domain/abort_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 17, 5, 0);

  group('Kademe yukselmesi', () {
    test('Her kullanimda bir artar', () {
      var s = const AbortState();
      s = AbortGate.escalate(state: s, now: now);
      expect(s.level, 1);
      s = AbortGate.escalate(state: s, now: now);
      expect(s.level, 2);
    });

    test('Tavanda durur', () {
      var s = AbortState(level: MissionTuning.abortMaxLevel, lastUsedAt: now);
      s = AbortGate.escalate(state: s, now: now);
      expect(s.level, MissionTuning.abortMaxLevel);
    });

    test('Kullanim zamani kaydedilir', () {
      final s = AbortGate.escalate(state: const AbortState(), now: now);
      expect(s.lastUsedAt, now);
    });
  });

  group('Gerileme', () {
    test('Decay suresi gecmeden gerilemez', () {
      final s = AbortState(level: 2, lastUsedAt: now);
      final soon = now.add(
        Duration(days: MissionTuning.abortDecayDays - 1),
      );
      expect(AbortGate.effectiveLevel(state: s, now: soon), 2);
    });

    test('Her decay periyodunda bir kademe iner', () {
      final s = AbortState(level: 3, lastUsedAt: now);
      final oneStep = now.add(Duration(days: MissionTuning.abortDecayDays));
      final twoSteps = now.add(
        Duration(days: MissionTuning.abortDecayDays * 2),
      );
      expect(AbortGate.effectiveLevel(state: s, now: oneStep), 2);
      expect(AbortGate.effectiveLevel(state: s, now: twoSteps), 1);
    });

    test('Sifirin altina inmez', () {
      final s = AbortState(level: 1, lastUsedAt: now);
      final muchLater = now.add(
        Duration(days: MissionTuning.abortDecayDays * 20),
      );
      expect(AbortGate.effectiveLevel(state: s, now: muchLater), 0);
    });

    test('Hic kullanilmamissa kademe sifir', () {
      expect(
        AbortGate.effectiveLevel(state: const AbortState(), now: now),
        0,
      );
    });
  });

  group('Kademe gereksinimleri', () {
    test('Seviye 0 yalnizca basili tutma ister', () {
      final r = AbortGate.requirementFor(0);
      expect(r.requiresPhrase, isFalse);
      expect(r.countdownSeconds, 0);
    });

    test('Seviye 1 cumle ister, geri sayim istemez', () {
      final r = AbortGate.requirementFor(1);
      expect(r.requiresPhrase, isTrue);
      expect(r.phrase, isNotEmpty);
      expect(r.countdownSeconds, 0);
    });

    test('Seviye 2 cumlesi seviye 1 den uzun', () {
      expect(
        AbortGate.requirementFor(2).phrase.length,
        greaterThan(AbortGate.requirementFor(1).phrase.length),
      );
    });

    test('Tavan seviyesi geri sayim ekler', () {
      final r = AbortGate.requirementFor(MissionTuning.abortMaxLevel);
      expect(r.requiresPhrase, isTrue);
      expect(r.countdownSeconds, greaterThan(0));
    });

    test('Tavan ustu seviye tavana kirpilir, cikis kapanmaz', () {
      final r = AbortGate.requirementFor(MissionTuning.abortMaxLevel + 5);
      expect(r, AbortGate.requirementFor(MissionTuning.abortMaxLevel));
    });

    test('isAtCeiling tavanda dogru', () {
      expect(AbortGate.isAtCeiling(MissionTuning.abortMaxLevel), isTrue);
      expect(AbortGate.isAtCeiling(0), isFalse);
    });
  });

  group('Cumle dogrulama', () {
    test('Birebir yazim gecer', () {
      expect(
        AbortGate.phraseMatches(expected: 'alarmı kapatıyorum', typed: 'alarmı kapatıyorum'),
        isTrue,
      );
    });

    test('Bastaki/sondaki bosluk ve fazla bosluk affedilir', () {
      expect(
        AbortGate.phraseMatches(
          expected: 'alarmı kapatıyorum',
          typed: '  alarmı   kapatıyorum ',
        ),
        isTrue,
      );
    });

    test('Turkce buyuk harf dogru kucultulur', () {
      // Dart'in toLowerCase'i 'I' -> 'i' yapar; Turkce'de 'I' -> 'ı'.
      expect(
        AbortGate.phraseMatches(
          expected: 'alarmı kapatıyorum',
          typed: 'ALARMI KAPATIYORUM',
        ),
        isTrue,
      );
    });

    test('Yanlis metin gecmez', () {
      expect(
        AbortGate.phraseMatches(expected: 'alarmı kapatıyorum', typed: 'alarm'),
        isFalse,
      );
    });
  });

  group('AbortState serilestirme', () {
    test('toJson/fromJson degerleri korur', () {
      final s = AbortState(level: 2, lastUsedAt: now);
      final round = AbortState.fromJson(s.toJson());
      expect(round.level, 2);
      expect(round.lastUsedAt, now);
    });

    test('Bozuk kayit varsayilana duser', () {
      final s = AbortState.fromJson({'level': 'abc', 'last_used_at': 'xyz'});
      expect(s.level, 0);
      expect(s.lastUsedAt, isNull);
    });
  });
}
```

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/alarms/abort_gate_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../abort_state.dart'`

- [ ] **Step 3: `AbortState` yaz**

`lib/core/models/abort_state.dart`:

```dart
/// Acil çıkışın **global** kademesi (spec D19): tek sayaç, tüm alarmlar ortak.
/// Cezalandırılan davranış "görevden kaçmak", hangi alarmdan kaçıldığı değil.
class AbortState {
  final int level;
  final DateTime? lastUsedAt;

  const AbortState({this.level = 0, this.lastUsedAt});

  Map<String, dynamic> toJson() => {
    'level': level,
    'last_used_at': lastUsedAt?.toIso8601String(),
  };

  /// Bozuk kayıt uygulamayı açılmaz hale getirmemeli; en güvenli değere
  /// (kademe yok) düşer.
  factory AbortState.fromJson(Map<String, dynamic> json) {
    final rawLevel = json['level'];
    final rawDate = json['last_used_at'];
    return AbortState(
      level: rawLevel is int && rawLevel >= 0 ? rawLevel : 0,
      lastUsedAt: rawDate is String ? DateTime.tryParse(rawDate) : null,
    );
  }
}
```

- [ ] **Step 4: `AbortGate` yaz**

`lib/features/alarms/domain/abort_gate.dart`:

```dart
import '../../../core/config/mission_tuning.dart';
import '../../../core/models/abort_state.dart';

/// Belirli bir kademede acil çıkış için istenenler.
class AbortRequirement {
  final bool requiresPhrase;

  /// Birebir yazılması istenen cümle. [requiresPhrase] false ise boş.
  final String phrase;

  /// Atlanamayan bekleme. 0 = yok.
  final int countdownSeconds;

  const AbortRequirement({
    required this.requiresPhrase,
    required this.phrase,
    required this.countdownSeconds,
  });

  @override
  bool operator ==(Object other) =>
      other is AbortRequirement &&
      requiresPhrase == other.requiresPhrase &&
      phrase == other.phrase &&
      countdownSeconds == other.countdownSeconds;

  @override
  int get hashCode => Object.hash(requiresPhrase, phrase, countdownSeconds);
}

/// Acil çıkışın kademe kuralları.
///
/// Çıkış **her zaman** mümkün olmalı (spec D9) ama alışkanlığa dönüşmemeli
/// (D17). Bu yüzden zorluk artar, tavanla sınırlıdır ve kullanılmayınca
/// geriler (D18).
class AbortGate {
  const AbortGate._();

  /// Cümleler kalibrasyona açık (spec §11): uykulu birini uğraştıracak kadar
  /// uzun, uyanık birini bunaltmayacak kadar kısa olmalı.
  static const String _phraseShort = 'alarmı kapatıyorum';
  static const String _phraseLong =
      'görevi yapmadan alarmı kapatıyorum';
  static const int _ceilingCountdownSeconds = 15;

  static int _clamp(int level) => level.clamp(0, MissionTuning.abortMaxLevel);

  static bool isAtCeiling(int level) => level >= MissionTuning.abortMaxLevel;

  /// Gerileme uygulanmış güncel kademe. Saklanan kademe ham değerdir; ekranda
  /// ve kararlarda bu fonksiyonun sonucu kullanılır.
  static int effectiveLevel({
    required AbortState state,
    required DateTime now,
  }) {
    final last = state.lastUsedAt;
    if (last == null) return 0;
    final elapsedDays = now.difference(last).inDays;
    if (elapsedDays < 0) return _clamp(state.level);
    final steps = elapsedDays ~/ MissionTuning.abortDecayDays;
    return _clamp(state.level - steps).clamp(0, MissionTuning.abortMaxLevel);
  }

  /// Çıkış kullanıldı: kademeyi bir artır, tavanı geçme.
  static AbortState escalate({
    required AbortState state,
    required DateTime now,
  }) {
    final current = effectiveLevel(state: state, now: now);
    return AbortState(level: _clamp(current + 1), lastUsedAt: now);
  }

  static AbortRequirement requirementFor(int level) {
    switch (_clamp(level)) {
      case 0:
        return const AbortRequirement(
          requiresPhrase: false,
          phrase: '',
          countdownSeconds: 0,
        );
      case 1:
        return const AbortRequirement(
          requiresPhrase: true,
          phrase: _phraseShort,
          countdownSeconds: 0,
        );
      case 2:
        return const AbortRequirement(
          requiresPhrase: true,
          phrase: _phraseLong,
          countdownSeconds: 0,
        );
      default:
        return const AbortRequirement(
          requiresPhrase: true,
          phrase: _phraseLong,
          countdownSeconds: _ceilingCountdownSeconds,
        );
    }
  }

  /// Yazılan metin beklenen cümleyle eşleşiyor mu?
  ///
  /// Baştaki/sondaki ve fazla boşluklar affedilir, büyük/küçük harf göz ardı
  /// edilir. Türkçe'de `I → ı` ve `İ → i` olduğu için Dart'ın
  /// locale-bağımsız `toLowerCase`'i tek başına yetmez.
  static bool phraseMatches({required String expected, required String typed}) =>
      _normalize(expected) == _normalize(typed);

  static String _normalize(String value) => value
      .replaceAll('I', 'ı')
      .replaceAll('İ', 'i')
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
```

- [ ] **Step 5: Test'i çalıştır, geçtiğini gör**

Run: `flutter test test/alarms/abort_gate_test.dart`
Expected: PASS (16 test)

- [ ] **Step 6: Commit**

```bash
git add lib/core/models/abort_state.dart lib/features/alarms/domain/abort_gate.dart test/alarms/abort_gate_test.dart
git commit -m "feat: acil cikis kademe mantigi"
```

---

### Task 6: Görev oturumu ve kalıcılık

**Files:**
- Create: `lib/core/models/mission_session.dart`
- Modify: `lib/core/interfaces/local_storage.dart` (dosya sonu, `deleteAlarm`'dan sonra)
- Modify: `lib/features/prayer_times/data/sqlite_storage.dart` (`saveSkippedOccurrences`'ten sonra)
- Test: `test/alarms/mission_session_test.dart`

**Interfaces:**
- Consumes: `AbortState` (Task 5)
- Produces: `MissionSession({String alarmId, DateTime firedAt, int snoozeUsed, int rearmCount, DateTime? completedAt})` + `toJson()/fromJson()/copyWith()`; `LocalStorage.getMissionSession() → Future<MissionSession?>`, `LocalStorage.saveMissionSession(MissionSession?) → Future<void>`, `LocalStorage.getAbortState() → Future<AbortState>`, `LocalStorage.saveAbortState(AbortState) → Future<void>`

- [ ] **Step 1: Failing test yaz**

`test/alarms/mission_session_test.dart`:

```dart
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final firedAt = DateTime(2026, 8, 17, 5, 0);

  group('MissionSession', () {
    test('Varsayilan sayaclar sifir', () {
      final s = MissionSession(alarmId: 'a', firedAt: firedAt);
      expect(s.snoozeUsed, 0);
      expect(s.rearmCount, 0);
      expect(s.completedAt, isNull);
      expect(s.isPending, isTrue);
    });

    test('completedAt dolunca beklemede degil', () {
      final s = MissionSession(
        alarmId: 'a',
        firedAt: firedAt,
        completedAt: firedAt,
      );
      expect(s.isPending, isFalse);
    });

    test('toJson/fromJson degerleri korur', () {
      final s = MissionSession(
        alarmId: 'sahur',
        firedAt: firedAt,
        snoozeUsed: 2,
        rearmCount: 7,
        completedAt: firedAt.add(const Duration(minutes: 3)),
      );
      final round = MissionSession.fromJson(s.toJson());
      expect(round.alarmId, 'sahur');
      expect(round.firedAt, firedAt);
      expect(round.snoozeUsed, 2);
      expect(round.rearmCount, 7);
      expect(round.completedAt, firedAt.add(const Duration(minutes: 3)));
    });

    test('copyWith yalnizca verileni degistirir', () {
      final s = MissionSession(alarmId: 'a', firedAt: firedAt, snoozeUsed: 1);
      final n = s.copyWith(snoozeUsed: 2);
      expect(n.snoozeUsed, 2);
      expect(n.alarmId, 'a');
      expect(n.firedAt, firedAt);
    });
  });
}
```

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/alarms/mission_session_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../mission_session.dart'`

- [ ] **Step 3: `MissionSession` yaz**

`lib/core/models/mission_session.dart`:

```dart
/// Çalan bir alarmın görev oturumu. `Alarm` kullanıcı tercihidir, bu geçici
/// durumdur — bu yüzden ayrı saklanır (spec §6).
///
/// Aynı anda en fazla bir aktif oturum olur.
class MissionSession {
  final String alarmId;
  final DateTime firedAt;
  final int snoozeUsed;
  final int rearmCount;
  final DateTime? completedAt;

  const MissionSession({
    required this.alarmId,
    required this.firedAt,
    this.snoozeUsed = 0,
    this.rearmCount = 0,
    this.completedAt,
  });

  bool get isPending => completedAt == null;

  Map<String, dynamic> toJson() => {
    'alarm_id': alarmId,
    'fired_at': firedAt.toIso8601String(),
    'snooze_used': snoozeUsed,
    'rearm_count': rearmCount,
    'completed_at': completedAt?.toIso8601String(),
  };

  factory MissionSession.fromJson(Map<String, dynamic> json) => MissionSession(
    alarmId: json['alarm_id'] as String,
    firedAt: DateTime.parse(json['fired_at'] as String),
    snoozeUsed: json['snooze_used'] as int? ?? 0,
    rearmCount: json['rearm_count'] as int? ?? 0,
    completedAt: switch (json['completed_at']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
  );

  MissionSession copyWith({
    int? snoozeUsed,
    int? rearmCount,
    DateTime? completedAt,
  }) => MissionSession(
    alarmId: alarmId,
    firedAt: firedAt,
    snoozeUsed: snoozeUsed ?? this.snoozeUsed,
    rearmCount: rearmCount ?? this.rearmCount,
    completedAt: completedAt ?? this.completedAt,
  );
}
```

- [ ] **Step 4: Test'i çalıştır, geçtiğini gör**

Run: `flutter test test/alarms/mission_session_test.dart`
Expected: PASS (4 test)

- [ ] **Step 5: `LocalStorage` kontratını genişlet**

`lib/core/interfaces/local_storage.dart` — importlara ekle:

```dart
import '../models/abort_state.dart';
import '../models/mission_session.dart';
```

`deleteAlarm` bildiriminden sonra, sınıfın içine:

```dart
  /// Çalan alarmın görev oturumu. Aynı anda en fazla bir tane olduğu için
  /// `settings` tablosunda tek anahtarda JSON olarak tutulur.
  Future<MissionSession?> getMissionSession();

  /// Oturumu yazar; `null` verilirse kaydı siler.
  Future<void> saveMissionSession(MissionSession? session);

  /// Acil çıkışın global kademesi. Kayıt yoksa sıfır kademe döner.
  Future<AbortState> getAbortState();

  Future<void> saveAbortState(AbortState state);
```

- [ ] **Step 6: `SqliteStorage`'a uygulamayı yaz**

`lib/features/prayer_times/data/sqlite_storage.dart` — importlara `abort_state.dart` ve `mission_session.dart` ekle. `saveSkippedOccurrences`'ten sonra:

```dart
  static const String _missionSessionKey = 'mission_session';
  static const String _abortStateKey = 'mission_abort_state';

  @override
  Future<MissionSession?> getMissionSession() async {
    final raw = await _readSetting(_missionSessionKey);
    if (raw == null) return null;
    // Bozuk kayit alarmi kilitlemesin; oturum yok kabul edilir.
    try {
      return MissionSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      AppLogger().warning('Gorev oturumu okunamadi, yok kabul edildi', e);
      return null;
    }
  }

  @override
  Future<void> saveMissionSession(MissionSession? session) async {
    final db = await database;
    if (session == null) {
      await db.delete(
        'settings',
        where: 'key = ?',
        whereArgs: [_missionSessionKey],
      );
      return;
    }
    await db.insert('settings', {
      'key': _missionSessionKey,
      'value': jsonEncode(session.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<AbortState> getAbortState() async {
    final raw = await _readSetting(_abortStateKey);
    if (raw == null) return const AbortState();
    try {
      return AbortState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      AppLogger().warning('Acil cikis kademesi okunamadi, sifirlandi', e);
      return const AbortState();
    }
  }

  @override
  Future<void> saveAbortState(AbortState state) async {
    final db = await database;
    await db.insert('settings', {
      'key': _abortStateKey,
      'value': jsonEncode(state.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// `settings` tablosundan tek değer okur; yoksa null.
  Future<String?> _readSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }
```

- [ ] **Step 7: Tüm testleri çalıştır**

Run: `flutter test && flutter analyze`
Expected: PASS. `LocalStorage`'ı implement eden test fake'leri varsa yeni method'lar eklenmeli — analyze bunu söyleyecek, eksikleri `UnimplementedError` yerine anlamlı varsayılanlarla (`null`, `const AbortState()`) doldur.

- [ ] **Step 8: Commit**

```bash
git add lib/core/models/mission_session.dart lib/core/interfaces/local_storage.dart lib/features/prayer_times/data/sqlite_storage.dart test/alarms/mission_session_test.dart
git commit -m "feat: gorev oturumu ve acil cikis kademesi kaliciligi"
```

---

### Task 7: `AlarmService` kontratı ve Dart channel katmanı

**Files:**
- Create: `lib/core/models/mission_stop_event.dart`
- Modify: `lib/core/interfaces/alarm_service.dart`
- Modify: `lib/features/alarms/data/native_alarm_service.dart`
- Modify: `lib/features/alarms/domain/alarm_scheduler.dart:65-74` (`scheduleAlarm` çağrısı)
- Test: `test/alarms/native_alarm_service_mission_test.dart`

**Interfaces:**
- Consumes: `AlarmMission` (T1), `MissionChain` (T3)
- Produces: `MissionStopEvent({String alarmId, DateTime stoppedAt})`; `AlarmService.scheduleAlarm` ek parametreleri `required AlarmMission mission, required int missionLevel, required Map<String, dynamic> chainConfig`; `AlarmService.consumeMissionEvents() → Future<List<MissionStopEvent>>`, `beginMission(String alarmId) → Future<void>`, `completeMission(String alarmId) → Future<void>`, `abortMission(String alarmId) → Future<void>`

- [ ] **Step 1: Failing test yaz**

`test/alarms/native_alarm_service_mission_test.dart`:

```dart
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/alarm_theme.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/features/alarms/data/native_alarm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.ekrembulbul.ezanvakti/alarm');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'consumeMissionEvents') {
        return [
          {'alarmId': 'sahur', 'stoppedAt': 1786883326000},
        ];
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final theme = AlarmTheme.forPalette(DayPhase.night, Brightness.dark);

  test('scheduleAlarm gorev alanlarini ve zincir yapilandirmasini gecirir', () async {
    await NativeAlarmService().scheduleAlarm(
      id: 'sahur',
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(1786883326000),
      label: 'Sahur',
      soundId: 'adhan',
      vibrate: true,
      snoozeEnabled: true,
      snoozeMinutes: 5,
      theme: theme,
      mission: AlarmMission.math,
      missionLevel: 2,
      chainConfig: const {'graceSeconds': 20},
    );

    final args = calls.single.arguments as Map;
    expect(calls.single.method, 'scheduleAlarm');
    expect(args['mission'], 'math');
    expect(args['missionLevel'], 2);
    expect(args['missionEnabled'], isTrue);
    expect((args['chainConfig'] as Map)['graceSeconds'], 20);
  });

  test('Gorevsiz alarmda missionEnabled false', () async {
    await NativeAlarmService().scheduleAlarm(
      id: 'ogle',
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(1786883326000),
      label: '',
      soundId: 'adhan',
      vibrate: true,
      snoozeEnabled: true,
      snoozeMinutes: 5,
      theme: theme,
      mission: AlarmMission.none,
      missionLevel: 1,
      chainConfig: const {},
    );

    final args = calls.single.arguments as Map;
    expect(args['missionEnabled'], isFalse);
  });

  test('consumeMissionEvents olaylari cozer', () async {
    final events = await NativeAlarmService().consumeMissionEvents();
    expect(events, hasLength(1));
    expect(events.single.alarmId, 'sahur');
    expect(
      events.single.stoppedAt,
      DateTime.fromMillisecondsSinceEpoch(1786883326000),
    );
  });

  test('Gorev yasam dongusu method adlari', () async {
    final s = NativeAlarmService();
    await s.beginMission('sahur');
    await s.completeMission('sahur');
    await s.abortMission('sahur');
    expect(
      calls.map((c) => c.method),
      ['beginMission', 'completeMission', 'abortMission'],
    );
    expect((calls.first.arguments as Map)['id'], 'sahur');
  });
}
```

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/alarms/native_alarm_service_mission_test.dart`
Expected: FAIL — `No named parameter with the name 'mission'`

- [ ] **Step 3: `MissionStopEvent` yaz**

`lib/core/models/mission_stop_event.dart`:

```dart
/// `stopIntent` tarafından kuyruğa yazılan "alarm durduruldu" olayı.
///
/// Intent, Flutter engine ayakta olmadan da çalışabildiği için olay native
/// tarafta biriktirilir; uygulama öne gelince tüketilir (spec D12).
class MissionStopEvent {
  final String alarmId;
  final DateTime stoppedAt;

  const MissionStopEvent({required this.alarmId, required this.stoppedAt});

  factory MissionStopEvent.fromMap(Map<Object?, Object?> map) =>
      MissionStopEvent(
        alarmId: map['alarmId'] as String,
        stoppedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['stoppedAt'] as num).toInt(),
        ),
      );
}
```

- [ ] **Step 4: `AlarmService` kontratını genişlet**

`lib/core/interfaces/alarm_service.dart` — importlara `alarm_mission.dart` ve `mission_stop_event.dart` ekle. `scheduleAlarm` imzasına:

```dart
    required AlarmMission mission,
    required int missionLevel,
    required Map<String, dynamic> chainConfig,
```

Sınıf sonuna:

```dart
  /// `stopIntent` tarafından biriktirilen olayları okur ve kuyruğu boşaltır.
  Future<List<MissionStopEvent>> consumeMissionEvents();

  /// Görev ekranı açıldı: nöbetçinin son tarihi `grace`ten görev süresine
  /// taşınır (spec D13).
  Future<void> beginMission(String alarmId);

  /// Görev tamamlandı: zincirdeki tüm alarmlar iptal edilir, oturum kapanır.
  Future<void> completeMission(String alarmId);

  /// Acil çıkış: [completeMission] ile aynı temizlik, ayrı raporlanır.
  Future<void> abortMission(String alarmId);
```

- [ ] **Step 5: `NativeAlarmService`'i güncelle**

`scheduleAlarm` gövdesindeki `invokeMethod` haritasına:

```dart
      'mission': mission.name,
      'missionLevel': missionLevel,
      'missionEnabled': mission.requiresGate,
      'chainConfig': chainConfig,
```

Sınıf sonuna:

```dart
  @override
  Future<List<MissionStopEvent>> consumeMissionEvents() async {
    if (!_hasNative) return const [];
    final raw = await _channel.invokeMethod<List<Object?>>(
      'consumeMissionEvents',
    );
    if (raw == null) return const [];
    return [
      for (final e in raw)
        MissionStopEvent.fromMap(e as Map<Object?, Object?>),
    ];
  }

  @override
  Future<void> beginMission(String alarmId) async {
    if (!_hasNative) return;
    await _channel.invokeMethod('beginMission', {'id': alarmId});
  }

  @override
  Future<void> completeMission(String alarmId) async {
    if (!_hasNative) return;
    await _channel.invokeMethod('completeMission', {'id': alarmId});
  }

  @override
  Future<void> abortMission(String alarmId) async {
    if (!_hasNative) return;
    await _channel.invokeMethod('abortMission', {'id': alarmId});
  }
```

- [ ] **Step 6: `AlarmScheduler`'ı güncelle**

`lib/features/alarms/domain/alarm_scheduler.dart` içindeki `alarmService.scheduleAlarm(...)` çağrısına ekle:

```dart
          mission: alarm.mission,
          missionLevel: alarm.missionLevel,
          chainConfig: {
            'graceSeconds': MissionTuning.graceSeconds,
            'maxRearms': MissionTuning.maxRearms,
            'chainDeadlineMillis':
                MissionChain.chainDeadline(fire).millisecondsSinceEpoch,
            'missionTimeoutSeconds':
                MissionTuning.timeoutSecondsFor(alarm.mission),
            'ladderMillis': [
              for (final t in MissionChain.ladder(fire))
                t.millisecondsSinceEpoch,
            ],
          },
```

Gerekli importları ekle (`mission_tuning.dart`, `mission_chain.dart`).

- [ ] **Step 7: Testleri çalıştır**

Run: `flutter test && flutter analyze`
Expected: PASS. `AlarmService`'i implement eden test fake'lerine yeni method'lar eklenecek; `scheduleAlarm` çağıran mevcut testler yeni zorunlu parametreleri geçmek zorunda.

- [ ] **Step 8: Commit**

```bash
git add lib/core/models/mission_stop_event.dart lib/core/interfaces/alarm_service.dart lib/features/alarms/data/native_alarm_service.dart lib/features/alarms/domain/alarm_scheduler.dart test/alarms/native_alarm_service_mission_test.dart
git commit -m "feat: gorev alanlari icin native alarm kontrati"
```

---

### Task 8: Swift — `stopIntent`, zincir ve yeni channel method'ları

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`
- Test: fiziksel cihaz (Task 14 kontrol listesi)

**Interfaces:**
- Consumes: Task 7'nin channel sözleşmesi (`missionEnabled`, `chainConfig`, `beginMission`, `completeMission`, `abortMission`, `consumeMissionEvents`)
- Produces: UserDefaults anahtarları `ezanvakti_mission_session`, `ezanvakti_mission_events`; mevcut `ezanvakti_alarm_uuid_map` defterine `<alarmId>#w<k>` kayıtları

**Neden burada TDD yok:** Projede Swift birim test altyapısı bu katmanı kapsamıyor ve App Intents simülatörde hiç çalışmıyor (spec M3). Bu yüzden Swift tarafı **kasten aptal** tutuluyor: karar değerlerini Dart hesaplayıp `chainConfig` ile veriyor, Swift yalnızca iki karşılaştırma yapıp alarmı yeniden kuruyor. Mantığın testi Task 3'te (`MissionChain`), doğrulaması Task 14'te.

- [ ] **Step 1: `import AppIntents` ekle ve `stopIntent` yaz**

`ios/Runner/AppDelegate.swift` — dosya başındaki importlara `import AppIntents`. `AlarmKitHandler` sınıfından **önce**:

```swift
/// Kullanıcı alarmı sistemin durdurma jestiyle susturduğunda çalışır.
///
/// Alarmın durmasını engellemez — durdu bilgisini alır. İki iş yapar: zinciri
/// bir adım ileri kurar ve olayı kuyruğa yazar. Uygulamayı da açar, böylece
/// kullanıcı görev ekranına düşer.
@available(iOS 26.1, *)
struct MissionStopIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Alarmı durdur"
  static let openAppWhenRun: Bool = true

  init() {}

  func perform() async throws -> some IntentResult {
    MissionChainStore.handleStop()
    return .result()
  }
}

/// Zincirin native tarafındaki durumu. Karar **değerleri** Dart'ta hesaplanır
/// (bkz. MissionChain); burada yalnızca iki karşılaştırma yapılır.
@available(iOS 26.1, *)
enum MissionChainStore {
  static let sessionKey = "ezanvakti_mission_session"
  static let eventsKey = "ezanvakti_mission_events"

  static func session() -> [String: Any]? {
    UserDefaults.standard.dictionary(forKey: sessionKey)
  }

  static func save(_ session: [String: Any]) {
    UserDefaults.standard.set(session, forKey: sessionKey)
  }

  static func clear() {
    UserDefaults.standard.removeObject(forKey: sessionKey)
  }

  /// Kullanıcı alarmı durdurdu: olayı kuyruğa yaz, sınır dolmadıysa nöbetçiyi
  /// kur.
  static func handleStop() {
    guard var s = session(), s["pending"] as? Bool == true,
      let alarmId = s["alarmId"] as? String
    else { return }

    enqueueStopEvent(alarmId: alarmId)

    let rearmCount = s["rearmCount"] as? Int ?? 0
    let maxRearms = s["maxRearms"] as? Int ?? 40
    let chainDeadline = s["chainDeadlineMillis"] as? Double ?? 0
    let nowMillis = Date().timeIntervalSince1970 * 1000

    // Cift ust sinir: bug varsa zincir kendini durdurmali.
    guard rearmCount < maxRearms, nowMillis < chainDeadline else {
      s["pending"] = false
      save(s)
      NSLog("mission|chain|stopped|bounds|id=\(alarmId)")
      return
    }

    let grace = s["graceSeconds"] as? Int ?? 20
    s["rearmCount"] = rearmCount + 1
    s["deadlineMillis"] = nowMillis + Double(grace * 1000)
    save(s)

    AlarmKitHandler.scheduleWatchdog(
      alarmId: alarmId,
      index: rearmCount + 1,
      fireDate: Date().addingTimeInterval(TimeInterval(grace)),
      session: s)
  }

  static func enqueueStopEvent(alarmId: String) {
    var queue = UserDefaults.standard.array(forKey: eventsKey) as? [[String: Any]] ?? []
    queue.append([
      "alarmId": alarmId,
      "stoppedAt": Date().timeIntervalSince1970 * 1000,
    ])
    UserDefaults.standard.set(queue, forKey: eventsKey)
  }

  static func drainEvents() -> [[String: Any]] {
    let queue = UserDefaults.standard.array(forKey: eventsKey) as? [[String: Any]] ?? []
    UserDefaults.standard.removeObject(forKey: eventsKey)
    return queue
  }
}
```

- [ ] **Step 2: `scheduleAlarm`'ı görev moduna göre ayır**

`scheduleAlarm` içindeki `guard #available(iOS 26.0, *)` → `iOS 26.1`. Argümanları oku:

```swift
    let missionEnabled = (args["missionEnabled"] as? NSNumber)?.boolValue ?? false
    let chainConfig = args["chainConfig"] as? [String: Any] ?? [:]
```

Uyarı kurulumunu iki kola ayır. **Görevsiz kol bugünkü kodun aynısıdır** (Global Constraints):

```swift
    let alert: AlarmPresentation.Alert
    var countdownPresentation: AlarmPresentation.Countdown?
    var countdownDuration: Alarm.CountdownDuration?
    var stopIntent: (any LiveActivityIntent)?

    if missionEnabled {
      // Gorev acik: erteleme sistem uyarisindan kaldirilir (spec D3), zincirin
      // calisabilmesi icin stopIntent baglanir.
      alert = AlarmPresentation.Alert(title: title)
      stopIntent = MissionStopIntent()
    } else if snoozeEnabled {
      alert = AlarmPresentation.Alert(
        title: title,
        secondaryButton: AlarmButton(
          text: "Ertele", textColor: .white, systemImageName: "zzz"),
        secondaryButtonBehavior: .countdown)
      countdownPresentation = AlarmPresentation.Countdown(title: "Erteleme")
      countdownDuration = Alarm.CountdownDuration(
        preAlert: nil, postAlert: Double(snoozeMinutes * 60))
    } else {
      alert = AlarmPresentation.Alert(title: title)
    }
```

`AlarmManager.AlarmConfiguration` çağrısına `stopIntent: stopIntent` ekle.

- [ ] **Step 3: Oturumu ve merdiveni kur**

`scheduleAlarm`'ın `Task { ... }` bloğu içinde, ana alarm başarıyla kurulduktan sonra:

```swift
        if missionEnabled {
          var session: [String: Any] = chainConfig
          session["alarmId"] = idStr
          session["pending"] = true
          session["rearmCount"] = 0
          session["label"] = label
          MissionChainStore.save(session)

          // Saglama merdiveni: stopIntent hic calismazsa kapi yine kapali
          // kalsin (spec §5.2).
          if let ladder = chainConfig["ladderMillis"] as? [Double] {
            for (i, millis) in ladder.enumerated() {
              Self.scheduleWatchdog(
                alarmId: idStr,
                index: 1000 + i,  // merdiven, hizli zincirle id cakismasin
                fireDate: Date(timeIntervalSince1970: millis / 1000),
                session: session)
            }
          }
        }
```

- [ ] **Step 4: `scheduleWatchdog` yaz**

`AlarmKitHandler` içine, `cancelAll`'dan önce:

```swift
  /// Nöbetçi alarm kurar. Id'si `<alarmId>#w<index>` — mevcut defter
  /// (`uuidFor`) üzerinden kaydedilir, böylece `cancelAll` hepsini yakalar
  /// (spec D10).
  @available(iOS 26.1, *)
  static func scheduleWatchdog(
    alarmId: String, index: Int, fireDate: Date, session: [String: Any]
  ) {
    let handler = AlarmKitHandler()
    let watchdogId = "\(alarmId)#w\(index)"
    let uuid = handler.uuidFor(watchdogId)
    let label = session["label"] as? String ?? ""
    let title: LocalizedStringResource =
      label.isEmpty ? "Ezan Vakti & Alarm" : LocalizedStringResource(stringLiteral: label)
    let alert = AlarmPresentation.Alert(title: title)
    let attributes = AlarmAttributes<EzanAlarmMetadata>(
      presentation: AlarmPresentation(alert: alert),
      metadata: EzanAlarmMetadata(),
      tintColor: color(fromHex: session["tintHex"] as? String) ?? fallbackTint)
    let config = AlarmManager.AlarmConfiguration(
      schedule: .fixed(fireDate),
      attributes: attributes,
      stopIntent: MissionStopIntent(),
      sound: .default)
    Task {
      do {
        _ = try await AlarmManager.shared.schedule(id: uuid, configuration: config)
        NSLog("mission|watchdog|scheduled|id=\(watchdogId)")
      } catch {
        NSLog("mission|watchdog|failed|id=\(watchdogId)|\(error)")
      }
    }
  }
```

`uuidFor`, `color(fromHex:)` ve `fallbackTint`'in bu çağrılardan erişilebilir olması için görünürlüklerini gerektiği kadar aç (`private` → dosya içi `fileprivate`/`static`).

- [ ] **Step 5: Dört channel method'unu bağla**

`handle(_:result:)` içindeki `switch`'e:

```swift
    case "consumeMissionEvents":
      if #available(iOS 26.1, *) {
        result(MissionChainStore.drainEvents())
      } else {
        result([])
      }
    case "beginMission":
      beginMission(call.arguments, result)
    case "completeMission", "abortMission":
      endMission(call.arguments, result)
```

Sınıfa:

```swift
  /// Görev ekranı açıldı: son tarih `grace`ten görev süresine taşınır ve
  /// nöbetçi o tarihe yeniden kurulur (spec D13).
  private func beginMission(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard #available(iOS 26.1, *),
      let args = arguments as? [String: Any],
      let idStr = args["id"] as? String,
      var session = MissionChainStore.session(),
      session["alarmId"] as? String == idStr
    else {
      result(nil)
      return
    }
    let timeout = session["missionTimeoutSeconds"] as? Int ?? 90
    let fireDate = Date().addingTimeInterval(TimeInterval(timeout))
    session["deadlineMillis"] = fireDate.timeIntervalSince1970 * 1000
    MissionChainStore.save(session)
    let index = (session["rearmCount"] as? Int ?? 0)
    Self.scheduleWatchdog(
      alarmId: idStr, index: index, fireDate: fireDate, session: session)
    result(nil)
  }

  /// Görev tamamlandı ya da acil çıkış kullanıldı: zincirdeki tüm alarmlar
  /// iptal edilir, oturum kapanır.
  private func endMission(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard #available(iOS 26.1, *) else {
      result(nil)
      return
    }
    cancelAll()
    MissionChainStore.clear()
    UserDefaults.standard.removeObject(forKey: MissionChainStore.eventsKey)
    result(nil)
  }
```

- [ ] **Step 6: Derle**

Run: `flutter build ios --simulator --debug`
Expected: `Xcode build done`, hata yok. (Davranış simülatörde doğrulanamaz — Task 14.)

- [ ] **Step 7: Görevsiz alarmın bozulmadığını simülatörde doğrula**

Simülatörde görevsiz bir alarm kur (varsayılan), çalmasını bekle: erteleme düğmesi görünmeli ve çalışmalı. Bu, Global Constraints'teki D6 kuralının kanıtı.

- [ ] **Step 8: Commit**

```bash
git add ios/Runner/AppDelegate.swift
git commit -m "feat: iOS gorev zinciri ve stopIntent"
```

---

### Task 9: `MissionScreen` kabuğu

**Files:**
- Create: `lib/presentation/screens/mission_screen.dart`
- Test: `test/widgets/missions/mission_screen_test.dart`

**Interfaces:**
- Consumes: `AlarmMission` (T1), `MissionTuning` (T1), `AbortGate`/`AbortRequirement` (T5)
- Produces: `MissionScreen({required Alarm alarm, required int remainingSeconds, required Widget child, required VoidCallback onCompleted, required VoidCallback onAbortRequested, VoidCallback? onSnooze, int snoozeRemaining = 0})`

- [ ] **Step 1: Failing test yaz**

`test/widgets/missions/mission_screen_test.dart`:

```dart
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/presentation/screens/mission_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const alarm = Alarm(
    id: 'sahur',
    kind: AlarmKind.fixed,
    label: 'Sahur',
    mission: AlarmMission.math,
  );

  Widget build({
    int remainingSeconds = 90,
    int snoozeRemaining = 0,
    VoidCallback? onSnooze,
    VoidCallback? onAbort,
  }) => MaterialApp(
    home: MissionScreen(
      alarm: alarm,
      remainingSeconds: remainingSeconds,
      snoozeRemaining: snoozeRemaining,
      onCompleted: () {},
      onAbortRequested: onAbort ?? () {},
      onSnooze: onSnooze,
      child: const Text('gorev govdesi'),
    ),
  );

  testWidgets('Etiket, gorev govdesi ve geri sayim cizilir', (tester) async {
    await tester.pumpWidget(build(remainingSeconds: 75));
    expect(find.text('Sahur'), findsOneWidget);
    expect(find.text('gorev govdesi'), findsOneWidget);
    // Kalan sure gorunur olmali: alarm surpriz olmamali (spec §5.1).
    expect(find.textContaining('1:15'), findsOneWidget);
  });

  testWidgets('Acil cikis her zaman gorunur', (tester) async {
    await tester.pumpWidget(build());
    expect(find.byKey(kMissionAbortKey), findsOneWidget);
  });

  testWidgets('Acil cikisa dokunmak istegi yukari bildirir', (tester) async {
    var asked = false;
    await tester.pumpWidget(build(onAbort: () => asked = true));
    await tester.tap(find.byKey(kMissionAbortKey));
    await tester.pump();
    expect(asked, isTrue);
  });

  testWidgets('Erteleme hakki varsa dugme ve kalan sayi gorunur', (tester) async {
    await tester.pumpWidget(build(snoozeRemaining: 2, onSnooze: () {}));
    expect(find.byKey(kMissionSnoozeKey), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);
  });

  testWidgets('Erteleme hakki bittiyse dugme hic cizilmez', (tester) async {
    await tester.pumpWidget(build(snoozeRemaining: 0, onSnooze: () {}));
    expect(find.byKey(kMissionSnoozeKey), findsNothing);
  });

  testWidgets('onSnooze verilmezse dugme cizilmez', (tester) async {
    await tester.pumpWidget(build(snoozeRemaining: 3));
    expect(find.byKey(kMissionSnoozeKey), findsNothing);
  });
}
```

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/widgets/missions/mission_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../mission_screen.dart'`

- [ ] **Step 3: `MissionScreen` yaz**

`lib/presentation/screens/mission_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/models/alarm.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';

const Key kMissionAbortKey = Key('mission_abort');
const Key kMissionSnoozeKey = Key('mission_snooze');

/// Görev ekranının kabuğu: başlık, kalan süre, görev gövdesi, erteleme ve
/// acil çıkış. Görev tipini bilmez — gövdeyi [child] olarak alır.
class MissionScreen extends StatelessWidget {
  final Alarm alarm;

  /// Görev süresinden kalan saniye. Ekranda görünür olmalı: alarmın geri
  /// dönmesi sürpriz olmamalı (spec §5.1).
  final int remainingSeconds;

  /// Kalan erteleme hakkı. 0 ise erteleme düğmesi hiç çizilmez (spec D4).
  final int snoozeRemaining;

  final Widget child;
  final VoidCallback onCompleted;
  final VoidCallback onAbortRequested;
  final VoidCallback? onSnooze;

  const MissionScreen({
    super.key,
    required this.alarm,
    required this.remainingSeconds,
    required this.child,
    required this.onCompleted,
    required this.onAbortRequested,
    this.onSnooze,
    this.snoozeRemaining = 0,
  });

  String get _countdown {
    final s = remainingSeconds < 0 ? 0 : remainingSeconds;
    final minutes = s ~/ 60;
    final seconds = (s % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final title = alarm.label.isEmpty ? 'Alarm' : alarm.label;
    final showSnooze = onSnooze != null && snoozeRemaining > 0;

    return Scaffold(
      backgroundColor: tokens.backgroundStops.last,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.screenTitle.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kalan süre $_countdown',
                textAlign: TextAlign.center,
                style: AppTypography.tabLabel.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: child),
              if (showSnooze)
                TextButton(
                  key: kMissionSnoozeKey,
                  onPressed: onSnooze,
                  child: Text('Ertele ($snoozeRemaining hakkın kaldı)'),
                ),
              TextButton(
                key: kMissionAbortKey,
                onPressed: onAbortRequested,
                child: Text(
                  'Alarmı tamamen kapat',
                  style: TextStyle(color: tokens.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Test'i çalıştır, geçtiğini gör**

Run: `flutter test test/widgets/missions/mission_screen_test.dart`
Expected: PASS (6 test)

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/mission_screen.dart test/widgets/missions/mission_screen_test.dart
git commit -m "feat: gorev ekrani kabugu"
```

---

### Task 10: Matematik görev widget'ı

**Files:**
- Create: `lib/presentation/widgets/missions/math_mission.dart`
- Test: `test/widgets/missions/math_mission_test.dart`

**Interfaces:**
- Consumes: `MathChallenge`, `MathQuestion` (T4)
- Produces: `MathMission({required int level, required Random random, required VoidCallback onCompleted})`

- [ ] **Step 1: Failing test yaz**

`test/widgets/missions/math_mission_test.dart`:

```dart
import 'dart:math';

import 'package:ezanvakti/features/alarms/domain/math_challenge.dart';
import 'package:ezanvakti/presentation/widgets/missions/math_mission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> answerAll(WidgetTester tester, List<MathQuestion> questions) async {
    for (final q in questions) {
      await tester.enterText(find.byType(TextField), '${q.answer}');
      await tester.tap(find.byKey(kMathSubmitKey));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('Tum sorular dogru cevaplanirsa tamamlanir', (tester) async {
    var done = false;
    final questions = MathChallenge.generate(level: 1, random: Random(7));

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: MathMission(
            level: 1,
            random: Random(7),
            onCompleted: () => done = true,
          ),
        ),
      ),
    );

    await answerAll(tester, questions);
    expect(done, isTrue);
  });

  testWidgets('Yanlis cevap ilerletmez ve uyari gosterir', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: MathMission(
            level: 1,
            random: Random(7),
            onCompleted: () => done = true,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '999999');
    await tester.tap(find.byKey(kMathSubmitKey));
    await tester.pumpAndSettle();

    expect(done, isFalse);
    expect(find.textContaining('Yanlış'), findsOneWidget);
  });

  testWidgets('Ilerleme gostergesi kacinci soruda oldugunu soyler', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: MathMission(
            level: 3,
            random: Random(7),
            onCompleted: () {},
          ),
        ),
      ),
    );
    final total = MathChallenge.questionCount(3);
    expect(find.textContaining('1 / $total'), findsOneWidget);
  });

  testWidgets('Bos cevap gonderilemez', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: MathMission(
            level: 1,
            random: Random(7),
            onCompleted: () => done = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(kMathSubmitKey));
    await tester.pumpAndSettle();
    expect(done, isFalse);
  });
}
```

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/widgets/missions/math_mission_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../math_mission.dart'`

- [ ] **Step 3: `MathMission` yaz**

`lib/presentation/widgets/missions/math_mission.dart`:

```dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/alarms/domain/math_challenge.dart';

const Key kMathSubmitKey = Key('math_submit');

/// Matematik görevi: sorular sırayla sorulur, hepsi doğru cevaplanınca
/// [onCompleted] çağrılır. Yanlış cevap ilerletmez.
class MathMission extends StatefulWidget {
  final int level;
  final Random random;
  final VoidCallback onCompleted;

  const MathMission({
    super.key,
    required this.level,
    required this.random,
    required this.onCompleted,
  });

  @override
  State<MathMission> createState() => _MathMissionState();
}

class _MathMissionState extends State<MathMission> {
  late final List<MathQuestion> _questions;
  final _controller = TextEditingController();
  int _index = 0;
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _questions = MathChallenge.generate(
      level: widget.level,
      random: widget.random,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final typed = int.tryParse(_controller.text.trim());
    if (typed == null) {
      setState(() => _wrong = true);
      return;
    }
    if (typed != _questions[_index].answer) {
      setState(() => _wrong = true);
      return;
    }
    _controller.clear();
    if (_index + 1 >= _questions.length) {
      widget.onCompleted();
      return;
    }
    setState(() {
      _index++;
      _wrong = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final question = _questions[_index];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${_index + 1} / ${_questions.length}',
          style: AppTypography.tabLabel.copyWith(color: tokens.textTertiary),
        ),
        const SizedBox(height: 16),
        Text(
          question.text,
          style: AppTypography.counter.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(hintText: 'Cevap'),
        ),
        if (_wrong) ...[
          const SizedBox(height: 8),
          Text(
            'Yanlış, tekrar dene.',
            style: AppTypography.tabLabel.copyWith(color: tokens.textSecondary),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: kMathSubmitKey,
          onPressed: _submit,
          child: const Text('Onayla'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Test'i çalıştır, geçtiğini gör**

Run: `flutter test test/widgets/missions/math_mission_test.dart`
Expected: PASS (4 test)

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/missions/math_mission.dart test/widgets/missions/math_mission_test.dart
git commit -m "feat: matematik gorev ekrani"
```

---

### Task 11: Kademeli acil çıkış akışı

**Files:**
- Create: `lib/presentation/widgets/missions/abort_dialog.dart`
- Test: `test/widgets/missions/abort_dialog_test.dart`

**Interfaces:**
- Consumes: `AbortGate`, `AbortRequirement` (T5)
- Produces: `AbortDialog({required int level, required VoidCallback onConfirmed})`, `showAbortDialog({required BuildContext context, required int level}) → Future<bool>`

- [ ] **Step 1: Failing test yaz**

`test/widgets/missions/abort_dialog_test.dart`:

```dart
import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/features/alarms/domain/abort_gate.dart';
import 'package:ezanvakti/presentation/widgets/missions/abort_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget build(int level, {required void Function() onConfirmed}) => MaterialApp(
    home: Material(
      child: AbortDialog(level: level, onConfirmed: onConfirmed),
    ),
  );

  testWidgets('Seviye 0: basili tutma yeter, cumle istenmez', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(build(0, onConfirmed: () => confirmed = true));

    expect(find.byType(TextField), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(kAbortHoldKey)),
    );
    await tester.pump(const Duration(seconds: 4));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });

  testWidgets('Basili tutma suresi dolmadan biraksa onaylanmaz', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(build(0, onConfirmed: () => confirmed = true));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(kAbortHoldKey)),
    );
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
  });

  testWidgets('Seviye 1: cumle alani cizilir ve metin gosterilir', (tester) async {
    await tester.pumpWidget(build(1, onConfirmed: () {}));
    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.textContaining(AbortGate.requirementFor(1).phrase),
      findsWidgets,
    );
  });

  testWidgets('Yanlis cumleyle onaylanmaz', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(build(1, onConfirmed: () => confirmed = true));

    await tester.enterText(find.byType(TextField), 'yanlis');
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(kAbortHoldKey)),
    );
    await tester.pump(const Duration(seconds: 4));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
  });

  testWidgets('Dogru cumle + basili tutma onaylar', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(build(1, onConfirmed: () => confirmed = true));

    await tester.enterText(
      find.byType(TextField),
      AbortGate.requirementFor(1).phrase,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(kAbortHoldKey)),
    );
    await tester.pump(const Duration(seconds: 4));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });

  testWidgets('Uyari metni bir dahaki seferi haber verir', (tester) async {
    await tester.pumpWidget(build(0, onConfirmed: () {}));
    expect(find.textContaining('daha zor'), findsOneWidget);
  });

  testWidgets('Tavanda metin artik zorlasmayacagini soyler', (tester) async {
    await tester.pumpWidget(
      build(MissionTuning.abortMaxLevel, onConfirmed: () {}),
    );
    expect(find.textContaining('daha zor'), findsNothing);
    expect(find.textContaining('en zor'), findsOneWidget);
  });

  testWidgets('Tavanda geri sayim dolmadan onaylanmaz', (tester) async {
    var confirmed = false;
    final req = AbortGate.requirementFor(MissionTuning.abortMaxLevel);
    await tester.pumpWidget(
      build(MissionTuning.abortMaxLevel, onConfirmed: () => confirmed = true),
    );

    await tester.enterText(find.byType(TextField), req.phrase);
    final early = await tester.startGesture(
      tester.getCenter(find.byKey(kAbortHoldKey)),
    );
    await tester.pump(const Duration(seconds: 4));
    await early.up();
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);

    await tester.pump(Duration(seconds: req.countdownSeconds));
    final late = await tester.startGesture(
      tester.getCenter(find.byKey(kAbortHoldKey)),
    );
    await tester.pump(const Duration(seconds: 4));
    await late.up();
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });
}
```

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/widgets/missions/abort_dialog_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../abort_dialog.dart'`

- [ ] **Step 3: `AbortDialog` yaz**

`lib/presentation/widgets/missions/abort_dialog.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../features/alarms/domain/abort_gate.dart';

const Key kAbortHoldKey = Key('abort_hold');
const Duration kAbortHoldDuration = Duration(seconds: 3);

/// Acil çıkış akışı. Kademeye göre basılı tutma, cümle yazma ve geri sayım
/// ister (spec §7.1). Çıkış her zaman mümkündür — yalnızca zorlaşır.
class AbortDialog extends StatefulWidget {
  final int level;
  final VoidCallback onConfirmed;

  const AbortDialog({
    super.key,
    required this.level,
    required this.onConfirmed,
  });

  @override
  State<AbortDialog> createState() => _AbortDialogState();
}

class _AbortDialogState extends State<AbortDialog> {
  late final AbortRequirement _req;
  final _controller = TextEditingController();
  Timer? _holdTimer;
  Timer? _countdownTimer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _req = AbortGate.requirementFor(widget.level);
    _remaining = _req.countdownSeconds;
    if (_remaining > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _remaining--);
        if (_remaining <= 0) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _phraseOk =>
      !_req.requiresPhrase ||
      AbortGate.phraseMatches(
        expected: _req.phrase,
        typed: _controller.text,
      );

  bool get _countdownOk => _remaining <= 0;

  void _holdStart() {
    _holdTimer = Timer(kAbortHoldDuration, () {
      if (_phraseOk && _countdownOk) widget.onConfirmed();
    });
  }

  void _holdEnd() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final atCeiling = AbortGate.isAtCeiling(widget.level);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Alarmı görevi yapmadan kapatıyorsun.',
            style: AppTypography.tabLabel.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            atCeiling
                ? 'Çıkış artık en zor kademede; daha da zorlaşmayacak.'
                : 'Bir dahaki sefere çıkış daha zor olacak.',
            style: AppTypography.tabLabel.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          if (_req.requiresPhrase) ...[
            const SizedBox(height: 16),
            Text(
              'Şunu birebir yaz: “${_req.phrase}”',
              style: AppTypography.tabLabel.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              // Kopyala-yapistir kapali: cumleyi gercekten yazmasi gerekiyor.
              enableInteractiveSelection: false,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Cümleyi yaz'),
            ),
          ],
          if (_remaining > 0) ...[
            const SizedBox(height: 16),
            Text(
              'Bekle: $_remaining sn',
              style: AppTypography.tabLabel.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          GestureDetector(
            key: kAbortHoldKey,
            onLongPressStart: (_) => _holdStart(),
            onLongPressEnd: (_) => _holdEnd(),
            onLongPressCancel: _holdEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.backgroundStops.first,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Kapatmak için 3 saniye basılı tut',
                style: AppTypography.tabLabel.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acil çıkışı bir alt sayfada gösterir. Kullanıcı tamamlarsa `true` döner.
Future<bool> showAbortDialog({
  required BuildContext context,
  required int level,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    builder: (context) => AbortDialog(
      level: level,
      onConfirmed: () => Navigator.of(context).pop(true),
    ),
  );
  return result ?? false;
}
```

`onLongPressStart` yalnızca varsayılan uzun-basma eşiğinden sonra tetiklenir; testteki 4 saniyelik bekleme bunu kapsar. Eşiği düşürmek gerekiyorsa `GestureDetector` yerine `Listener` + kendi `Timer`'ını kullan ve testi buna göre güncelle.

- [ ] **Step 4: Test'i çalıştır, geçtiğini gör**

Run: `flutter test test/widgets/missions/abort_dialog_test.dart`
Expected: PASS (8 test)

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/missions/abort_dialog.dart test/widgets/missions/abort_dialog_test.dart
git commit -m "feat: kademeli acil cikis akisi"
```

---

### Task 12: Alarm düzenleme ekranı — görev seçimi ve erteleme sayısı

**Files:**
- Modify: `lib/presentation/screens/alarm_edit_screen.dart:36-59` (state), `:150` (bölüm sırası), `:566-579` (erteleme seçicisi)
- Test: `test/widgets/screens/alarm_edit_mission_test.dart`

**Interfaces:**
- Consumes: `AlarmMission` (T1), `Alarm` (T2)
- Produces: kaydedilen `Alarm` nesnesinde `mission`, `missionLevel`, `maxSnoozes` dolu

- [ ] **Step 1: Failing test yaz**

`test/widgets/screens/alarm_edit_mission_test.dart`:

```dart
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Gorev ve erteleme kurallari', () {
    test('Gorev acikken sinirsiz erteleme kaydedilemez', () {
      // Spec D15: gorev acikken Sinirsiz listelenmez; kayitta da en buyuk
      // sonlu secenege duser.
      const a = Alarm(
        id: 'a',
        kind: AlarmKind.fixed,
        mission: AlarmMission.math,
        maxSnoozes: null,
      );
      final normalized = normalizeAlarmSnoozeLimit(a);
      expect(normalized.maxSnoozes, kMaxSnoozeOptions.last);
    });

    test('Gorev kapaliyken sinirsiz korunur', () {
      const a = Alarm(id: 'a', kind: AlarmKind.fixed, maxSnoozes: null);
      expect(normalizeAlarmSnoozeLimit(a).maxSnoozes, isNull);
    });

    test('Erteleme kapaliysa limit yok sayilir', () {
      const a = Alarm(
        id: 'a',
        kind: AlarmKind.fixed,
        mission: AlarmMission.math,
        snoozeEnabled: false,
      );
      expect(normalizeAlarmSnoozeLimit(a).maxSnoozes, isNull);
    });

    test('Secenek listeleri kapali ve artan', () {
      expect(kSnoozeMinuteOptions, [5, 10, 15, 20]);
      expect(kMaxSnoozeOptions, [1, 2, 3, 5]);
    });
  });
}
```

Testin ilk satırlarına şu importu ekle — seçenekler ve normalleştirme
`alarm_edit_screen.dart` içine değil buraya konuyor ki test widget kurmadan
çalışsın:

```dart
import 'package:ezanvakti/features/alarms/domain/snooze_options.dart';
```

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/widgets/screens/alarm_edit_mission_test.dart`
Expected: FAIL — `Undefined name 'normalizeAlarmSnoozeLimit'`

- [ ] **Step 3: Seçenekleri ve normalleştirmeyi yaz**

`lib/features/alarms/domain/snooze_options.dart`:

```dart
import '../../../core/models/alarm.dart';
import '../../../core/models/alarm_mission.dart';

/// Kullanıcıya sunulan erteleme süreleri (dk). Kapalı liste (spec D15).
const List<int> kSnoozeMinuteOptions = [5, 10, 15, 20];

/// Kullanıcıya sunulan erteleme sayıları. Görev kapalıysa listeye ayrıca
/// "Sınırsız" (`null`) eklenir.
const List<int> kMaxSnoozeOptions = [1, 2, 3, 5];

/// Erteleme limitini kurallara uydurur.
///
/// - Erteleme kapalıysa limit anlamsız: `null`.
/// - Görev açıksa sınırsız erteleme kapıyı işlevsiz bırakır; en büyük sonlu
///   seçeneğe düşürülür (spec D15).
Alarm normalizeAlarmSnoozeLimit(Alarm alarm) {
  if (!alarm.snoozeEnabled) {
    return alarm.maxSnoozes == null
        ? alarm
        : Alarm(
            id: alarm.id,
            kind: alarm.kind,
            label: alarm.label,
            isActive: alarm.isActive,
            hour: alarm.hour,
            minute: alarm.minute,
            anchor: alarm.anchor,
            offsetMinutes: alarm.offsetMinutes,
            weekdays: alarm.weekdays,
            soundId: alarm.soundId,
            vibrate: alarm.vibrate,
            snoozeEnabled: alarm.snoozeEnabled,
            snoozeMinutes: alarm.snoozeMinutes,
            mission: alarm.mission,
            missionLevel: alarm.missionLevel,
          );
  }
  if (alarm.mission.requiresGate && alarm.maxSnoozes == null) {
    return alarm.copyWith(maxSnoozes: kMaxSnoozeOptions.last);
  }
  return alarm;
}
```

`copyWith` `null`'ı "dokunma" saydığı için limiti **temizlemek** gerektiğinde constructor doğrudan çağrılıyor; bu Task 2'deki dokümante davranışın sonucu.

- [ ] **Step 4: Test'i çalıştır, geçtiğini gör**

Run: `flutter test test/widgets/screens/alarm_edit_mission_test.dart`
Expected: PASS (4 test)

- [ ] **Step 5: Ekrana görev bölümünü ekle**

`lib/presentation/screens/alarm_edit_screen.dart`:

State alanları ekle (`_snoozeMinutes` yanına):

```dart
  late AlarmMission _mission;
  late int _missionLevel;
  int? _maxSnoozes;
```

`initState` içinde:

```dart
    _mission = a?.mission ?? AlarmMission.none;
    _missionLevel = a?.missionLevel ?? 1;
    _maxSnoozes = a?.maxSnoozes;
```

Kaydetme çağrısında (`snoozeMinutes: _snoozeMinutes,` satırının yanına):

```dart
      mission: _mission,
      missionLevel: _missionLevel,
      maxSnoozes: _maxSnoozes,
```

ve oluşturulan `Alarm`'ı kaydetmeden önce `normalizeAlarmSnoozeLimit(...)`'ten geçir.

`_snoozeMinutesSelector`'daki `const [5, 10, 15, 20]` yerine `kSnoozeMinuteOptions` kullan. `if (_snoozeEnabled) _snoozeMinutesSelector(),` satırından sonra iki seçici daha ekle: görev tipi (bu turda yalnızca `Yok` ve `Matematik`; `shake`/`qr` sonraki planlarda açılır) ve erteleme sayısı. Her ikisi de mevcut `_switchRow` + `DropdownButton` desenini izler.

- [ ] **Step 6: Tüm testleri çalıştır**

Run: `flutter test && flutter analyze`
Expected: PASS, temiz.

- [ ] **Step 7: Commit**

```bash
git add lib/features/alarms/domain/snooze_options.dart lib/presentation/screens/alarm_edit_screen.dart test/widgets/screens/alarm_edit_mission_test.dart
git commit -m "feat: alarm ekranina gorev ve erteleme limiti secimi"
```

---

### Task 13: Görev akışını bağla

**Files:**
- Create: `lib/features/alarms/domain/mission_coordinator.dart`
- Test: `test/alarms/mission_coordinator_test.dart`

**Interfaces:**
- Consumes: `AlarmService` (T7), `LocalStorage` (T6), `MissionChain` (T3), `AbortGate` (T5)
- Produces: `MissionCoordinator({required AlarmService alarmService, required LocalStorage storage})` ile `Future<MissionSession?> resume()`, `Future<void> begin(String alarmId)`, `Future<bool> snooze(Alarm alarm)`, `Future<void> complete(String alarmId)`, `Future<void> abort(String alarmId, DateTime now)`

- [ ] **Step 1: Failing test yaz**

`test/alarms/mission_coordinator_test.dart`:

```dart
import 'package:ezanvakti/core/models/abort_state.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/core/models/mission_stop_event.dart';
import 'package:ezanvakti/features/alarms/domain/mission_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_alarm_service.dart';
import 'fakes/fake_storage.dart';

void main() {
  late FakeAlarmService service;
  late FakeStorage storage;
  late MissionCoordinator coordinator;

  setUp(() {
    service = FakeAlarmService();
    storage = FakeStorage();
    coordinator = MissionCoordinator(
      alarmService: service,
      storage: storage,
    );
  });

  final firedAt = DateTime(2026, 8, 17, 5, 0);

  test('resume: kuyruktaki durdurma olayi oturum acar', () async {
    service.pendingEvents = [
      MissionStopEvent(alarmId: 'sahur', stoppedAt: firedAt),
    ];
    final session = await coordinator.resume();
    expect(session, isNotNull);
    expect(session!.alarmId, 'sahur');
    expect(await storage.getMissionSession(), isNotNull);
  });

  test('resume: olay yoksa mevcut oturum korunur', () async {
    await storage.saveMissionSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    final session = await coordinator.resume();
    expect(session!.alarmId, 'sahur');
  });

  test('begin native tarafa haber verir', () async {
    await coordinator.begin('sahur');
    expect(service.begun, ['sahur']);
  });

  test('complete oturumu silip native temizler', () async {
    await storage.saveMissionSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    await coordinator.complete('sahur');
    expect(service.completed, ['sahur']);
    expect(await storage.getMissionSession(), isNull);
  });

  test('snooze limiti asilmadikca sayaci artirir', () async {
    await storage.saveMissionSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    const alarm = Alarm(
      id: 'sahur',
      kind: AlarmKind.fixed,
      mission: AlarmMission.math,
      maxSnoozes: 2,
    );
    expect(await coordinator.snooze(alarm), isTrue);
    expect((await storage.getMissionSession())!.snoozeUsed, 1);
    expect(await coordinator.snooze(alarm), isTrue);
    expect(await coordinator.snooze(alarm), isFalse);
    expect((await storage.getMissionSession())!.snoozeUsed, 2);
  });

  test('abort kademeyi yukseltir ve zinciri temizler', () async {
    await storage.saveMissionSession(
      MissionSession(alarmId: 'sahur', firedAt: firedAt),
    );
    await coordinator.abort('sahur', firedAt);
    expect(service.aborted, ['sahur']);
    expect(await storage.getMissionSession(), isNull);
    final state = await storage.getAbortState();
    expect(state.level, 1);
    expect(state.lastUsedAt, firedAt);
  });
}
```

Fake'leri de bu task'ta yaz.

`test/alarms/fakes/fake_alarm_service.dart`:

```dart
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/alarm_theme.dart';
import 'package:ezanvakti/core/models/mission_stop_event.dart';

/// Cagrilari kaydeden bellek-ici [AlarmService].
class FakeAlarmService implements AlarmService {
  List<MissionStopEvent> pendingEvents = [];
  final List<String> begun = [];
  final List<String> completed = [];
  final List<String> aborted = [];

  @override
  Future<List<MissionStopEvent>> consumeMissionEvents() async {
    final events = pendingEvents;
    pendingEvents = [];
    return events;
  }

  @override
  Future<void> beginMission(String alarmId) async => begun.add(alarmId);

  @override
  Future<void> completeMission(String alarmId) async => completed.add(alarmId);

  @override
  Future<void> abortMission(String alarmId) async => aborted.add(alarmId);

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<void> scheduleAlarm({
    required String id,
    required DateTime scheduledTime,
    required String label,
    required String soundId,
    required bool vibrate,
    required bool snoozeEnabled,
    required int snoozeMinutes,
    required AlarmTheme theme,
    required AlarmMission mission,
    required int missionLevel,
    required Map<String, dynamic> chainConfig,
  }) async {}

  @override
  Future<void> cancelAlarm(String id) async {}

  @override
  Future<void> cancelAllAlarms() async {}

  @override
  Future<String?> importCustomSound(String sourcePath) async => null;
}
```

`test/alarms/fakes/fake_storage.dart`:

```dart
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/abort_state.dart';
import 'package:ezanvakti/core/models/mission_session.dart';

/// Yalnizca gorev oturumu ve acil cikis kademesini tutan [LocalStorage].
/// Kalan method'lar bu testlerde cagrilmiyor; cagrilirsa test kirilsin diye
/// [UnimplementedError] firlatiyorlar.
class FakeStorage implements LocalStorage {
  MissionSession? _session;
  AbortState _abort = const AbortState();

  @override
  Future<MissionSession?> getMissionSession() async => _session;

  @override
  Future<void> saveMissionSession(MissionSession? session) async {
    _session = session;
  }

  @override
  Future<AbortState> getAbortState() async => _abort;

  @override
  Future<void> saveAbortState(AbortState state) async {
    _abort = state;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeStorage.${invocation.memberName}');
}
```

`noSuchMethod` kullanmak icin sinifin basina `// ignore: subtype_of_sealed_class`
gerekmez ama `LocalStorage` soyut oldugu icin `implements` + `noSuchMethod`
birlikte calisir; analyzer eksik method uyarisi verirse `@override` isaretli
stub'lari elle ekle.

- [ ] **Step 2: Test'i çalıştır, kırıldığını gör**

Run: `flutter test test/alarms/mission_coordinator_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../mission_coordinator.dart'`

- [ ] **Step 3: `MissionCoordinator` yaz**

`lib/features/alarms/domain/mission_coordinator.dart`:

```dart
import '../../../core/interfaces/alarm_service.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/alarm.dart';
import '../../../core/models/mission_session.dart';
import 'abort_gate.dart';

/// Görev oturumunun yaşam döngüsünü yürütür: native olayları tüketir,
/// oturumu saklar, erteleme sayacını tutar, tamamlama ve acil çıkışta
/// zincirin temizlenmesini tetikler.
class MissionCoordinator {
  final AlarmService alarmService;
  final LocalStorage storage;

  MissionCoordinator({required this.alarmService, required this.storage});

  /// Uygulama öne geldiğinde çağrılır. Native kuyruğunda durdurma olayı varsa
  /// oturumu açar/yeniler, yoksa kayıtlı oturumu döner.
  Future<MissionSession?> resume() async {
    final events = await alarmService.consumeMissionEvents();
    if (events.isEmpty) return storage.getMissionSession();

    final latest = events.last;
    final existing = await storage.getMissionSession();
    final session = existing != null && existing.alarmId == latest.alarmId
        ? existing.copyWith(rearmCount: existing.rearmCount + 1)
        : MissionSession(
            alarmId: latest.alarmId,
            firedAt: latest.stoppedAt,
          );
    await storage.saveMissionSession(session);
    return session;
  }

  /// Görev ekranı açıldı.
  Future<void> begin(String alarmId) => alarmService.beginMission(alarmId);

  /// Erteleme denemesi. Hak kalmadıysa `false` döner ve hiçbir şey değişmez.
  Future<bool> snooze(Alarm alarm) async {
    final session = await storage.getMissionSession();
    if (session == null) return false;
    final limit = alarm.maxSnoozes;
    if (limit != null && session.snoozeUsed >= limit) return false;
    await storage.saveMissionSession(
      session.copyWith(snoozeUsed: session.snoozeUsed + 1),
    );
    return true;
  }

  /// Görev tamamlandı: zincir tamamen susar.
  Future<void> complete(String alarmId) async {
    await alarmService.completeMission(alarmId);
    await storage.saveMissionSession(null);
  }

  /// Acil çıkış kullanıldı: zincir susar ve kademe bir yükselir (spec D17).
  Future<void> abort(String alarmId, DateTime now) async {
    await alarmService.abortMission(alarmId);
    await storage.saveMissionSession(null);
    final current = await storage.getAbortState();
    await storage.saveAbortState(
      AbortGate.escalate(state: current, now: now),
    );
  }
}
```

- [ ] **Step 4: Test'i çalıştır, geçtiğini gör**

Run: `flutter test test/alarms/mission_coordinator_test.dart`
Expected: PASS (6 test)

- [ ] **Step 5: `ServiceLocator`'a kaydet ve uygulama açılışına bağla**

`lib/core/di/service_locator.dart` içinde `AlarmScheduler` kaydından sonra `MissionCoordinator`'ı kaydet. Uygulama öne geldiğinde (`main.dart`'ta mevcut `refresh` akışının yanında) `resume()` çağrılıp dönen oturum `null` değilse `MissionScreen`'e yönlendir.

- [ ] **Step 6: Tüm testleri çalıştır**

Run: `flutter test && flutter analyze`
Expected: PASS, temiz.

- [ ] **Step 7: Commit**

```bash
git add lib/features/alarms/domain/mission_coordinator.dart lib/core/di/service_locator.dart lib/main.dart test/alarms/mission_coordinator_test.dart test/alarms/fakes/
git commit -m "feat: gorev oturumu koordinatoru"
```

---

### Task 14: Cihaz doğrulaması

**Files:**
- Create: `docs/superpowers/plans/2026-08-17-gorev-tabanli-kapatma-cihaz-kontrol.md`
- Test: manuel, fiziksel cihaz

**Interfaces:**
- Consumes: Task 1–13'ün tamamı
- Produces: doldurulmuş kontrol listesi

**Neden gerekli:** App Intents simülatörde çalışmaz (spec M3). `stopIntent`'e dokunan hiçbir davranış bu ana kadar doğrulanmadı.

- [ ] **Step 1: İmzalı build'i cihaza kur**

```bash
flutter devices          # cihaz kablolu gorunmeli, "(wireless)" etiketi olmadan
flutter run -d <device-id> --debug
```

Kablosuz bağlantı iOS 26'da kurulumu asıyor; **USB kablo kullan**.

- [ ] **Step 2: Kontrol listesini çalıştır ve sonuçları dosyaya yaz**

Her satır için gözlemi ve varsa log kanıtını kaydet:

| # | Senaryo | Beklenen |
|---|---|---|
| 1 | Görevsiz alarm kur, çal, ertele | Erteleme düğmesi var ve çalışıyor; bugünkü davranış aynı (D6) |
| 2 | Görevli alarm kur, çal | Sistem uyarısında **erteleme düğmesi yok**, yalnızca kaydırmalı durdurma |
| 3 | Kaydırıp durdur | Uygulama görev ekranında açılıyor; log'da `mission\|watchdog\|scheduled` |
| 4 | Görevi tamamla | Zincir tamamen susuyor, `grace` sonrası alarm gelmiyor |
| 5 | Durdur, uygulamayı hiç açma | `grace` (20 sn) sonra alarm dönüyor |
| 6 | Görev ekranını aç, süreyi doldur | Görev süresi (90 sn) sonunda alarm dönüyor |
| 7 | Görev ekranı açıkken uygulamayı force-quit et | Alarm yine dönüyor |
| 8 | Alarm kilitsiz ekranda çalarken banner'ı yukarı kaydır | `stopIntent` çalışmasa bile sağlama merdiveni 5 dk sonra çalıyor |
| 9 | Acil çıkışı kullan (seviye 0) | 3 sn basılı tutma + onay ile zincir susuyor |
| 10 | Acil çıkışı tekrar kullan | Bu sefer cümle yazma istiyor |
| 11 | Erteleme limitini doldur | Erteleme düğmesi kayboluyor, yalnızca görev kalıyor |
| 12 | Zinciri `maxRearms`'a kadar sürdür (sabiti geçici düşürerek) | Zincir kendiliğinden duruyor, telefon susuyor |

- [ ] **Step 3: Kalibrasyon değerlerini güncelle**

Gözlemlere göre `MissionTuning`'deki `graceSeconds` ve görev sürelerini düzelt. Özellikle: kullanıcı alarmı durdurduktan sonra uygulamanın açılması ne kadar sürüyor? `graceSeconds` bundan belirgin büyük olmalı, yoksa alarm uygulama açılmadan döner.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/2026-08-17-gorev-tabanli-kapatma-cihaz-kontrol.md lib/core/config/mission_tuning.dart
git commit -m "test: cihaz dogrulamasi ve kalibrasyon"
```

---

## Bilerek ertelenenler

Spec'te tanımlı ama bu planda **kasten** yok:

- **`MissionChallenge` soyutlaması (spec §5.5).** Tek görev tipi varken ortak
  arayüz zamansız soyutlama olur. Sallama planı ikinci tipi eklerken arayüz
  `MathMission` ve yeni widget'tan çıkarılır — o an gerçek iki örnek elde olur.
- **`Alarm.qrPayload` (spec §6).** QR planına bırakıldı; kullanılmayan kolon
  eklemek yerine o turda ikinci bir migration yazılır.
- **`shake` ve `qr` görev seçeneklerinin arayüzde listelenmesi.** `AlarmMission`
  enum'ı dört değeri de taşıyor (kalıcılık ileriye dönük uyumlu olsun diye) ama
  Task 12 yalnızca `Yok` ve `Matematik` gösteriyor.

## Sonraki planlar

Bu plan bittiğinde çalışan bir dilim var: matematik göreviyle korunan alarm. Kalanlar spec §10 sırasına göre kendi planlarını alır.

- **Sallama görevi** — sensör paketi değerlendirmesi, `MathMission` ile aynı sözleşmeye oturur
- **QR görevi** — kamera izni (`NSCameraUsageDescription`), kod kaydetme akışı
- **Android** — `AlarmRingActivity` tarafı; çalma süresi sınırı (spec D1) yalnızca orada mümkün

## Kapsam dışı kalan, spec §12'deki hatalar

Bu plan bunlara dokunmuyor; ayrı iş olarak alınmalı:

- `AppDelegate.swift` içindeki ölü `stopButton` kodu ve deprecated init (bu plan Task 8'de görevli kolu yeni init'e taşıyor, görevsiz kol dokunulmamış kalıyor)
- Repoda hiç ses dosyası olmaması — "Ezan" seçimi her iki platformda sistem sesine düşüyor
- `theme_controller.dart:85` build sırasında `notifyListeners()` assertion'ı
- Saat seçici Material dialog'unun İngilizce kalması
