# Android Turu 1 Uygulama Planı

> **For agentic workers:** Bu plan CLAUDE.md'deki orchestrator düzeniyle yürütülür (seri `subagent-driven-development` kullanılmaz). Alt-agent'lar build/test/codegen/commit koşmaz; adımlardaki "çalıştır" satırları ana oturumun Task 12'de koşacağı doğrulamadır. Adımlar `- [ ]` ile işaretlenir.

**Goal:** Android'i mağaza öncesi iOS düzeyine getirmek: pusula, bildirim kanalları, tam ekran izni; alarm ses seviyesi, çalma süresi sınırı, Rahatsız Etme ile telefonu susturma, pil uyarısı, saat dilimi/izin değişiminde yeniden kurma, sistem dili, temalı ikon, Android 16 geri hareketi.

**Architecture:** Kararlar Dart'ta saf sınıflarda (planlayıcı, kanal seçimi, pil kararı), uygulama noktaları Kotlin'de (sensör, AutomaticZenRule, AudioManager, AlarmManager). Yeni `com.ekrembulbul.ezanvakti/device` MethodChannel cihaz ayarlarını taşır; heading EventChannel'ın Android tarafı yazılır. Alarm motorunun durum makinesi (AlarmMissions) değişmez; süre dolunca mevcut erteleme/durdurma geçişleri kullanılır.

**Tech Stack:** Flutter/Dart (sqflite, flutter_local_notifications 17.2.4), Kotlin (Android SDK 36, minSdk 24), JUnit 4 + org.json.

**Spec:** `docs/superpowers/specs/2026-10-08-android-tur1-design.md`

## Global Constraints

- iOS davranışı değişmez; yeni native anahtarları iOS yok sayar.
- Yeni Flutter paketi eklenmez.
- Kullanıcıya görünen metin Dart'ta sabit yazılmaz: `lib/l10n/app_tr.arb` kaynak, `app_en.arb` / `app_ar.arb` karşılıkları; `flutter gen-l10n` yalnız Task 1'de ve Task 12'de ana oturumca koşulur.
- Renk/tipografi `context.tokens` ve `AppTypography`.
- Hatalar `AppLogger` ile loglanır, sessizce yutulmaz; secret/koordinat loglanmaz.
- Kanal kimlikleri: `ezan_vakti_channel` (sistem, mevcut kimlik), `ezan_vakti_beep`, `ezan_vakti_silent`, `ezan_vakti_alarm_missed`.
- MethodChannel adı: `com.ekrembulbul.ezanvakti/device`; heading EventChannel: `com.ekrembulbul.ezanvakti/heading`.
- Telefon susturma yalnız API 29+ (`Build.VERSION_CODES.Q`).
- Çalma süresi seçenekleri `[5, 10, 15, 30, 0]` (0 = sınırsız), varsayılan 10. Ses seviyesi %10–100, 10'luk adım; null = telefonun seviyesi.
- DB şeması v16: `alarms.volume INTEGER` (nullable).
- Kod/identifier İngilizce, yorumlar Türkçe (mevcut dosyaların üslubu).

## Review Focus

1. Sessiz pencere aralığı gece yarısını aşarsa (yatsı + 180 dk) ya da iki pencere çakışırsa tek kesintisiz aralık beklenir — Task 6 planlayıcı testi.
2. Kullanıcı pencere içinde Rahatsız Etme'yi elle kapatıp uygulamayı açarsa mod yeniden açılmamalı — Task 7 `QuietSchedule.decide` testi (uygulanan durum = istenen durum → yazma yok).
3. Görevli alarmda süre dolup erteleme hakkı yoksa zincir sürmeli, "Kaçırılan alarm" çıkmamalı; görevsizde çıkmalı — Task 10 `RingTimeout.missedNotice` testi.
4. Saat dilimi değişiminde vakte bağlı ve nöbetçi kayıtlar kaymamalı, sabit saatliler duvar saatini korumalı — Task 11 `AlarmTimeShiftTest`.
5. Eski (v15) veritabanındaki alarm yükseltmeden sonra kaybolmamalı, `volume` null gelmeli — Task 2 migration testi.

## Yürütme düzeni

| Faz | Task | Kim |
|---|---|---|
| 0 (sıralı) | 1 Ortak kaynaklar · 2 Alarm ses modeli + DB v16 · 3 Device köprüsü (Dart) + kayıtlar | Ana oturum |
| 1 (paralel) | 4 Bildirim kanalları + 5 Kıble pusulası | Agent A — `opus-medium-worker` |
| | 6 Sessiz pencere planı ve ekranı (Dart) | Agent B — `opus-medium-worker` |
| | 7 Telefonu susturma native + device kanalı (Kotlin) | Agent C — `opus-high-worker` |
| | 8 Ses seviyesi UI + çalma süresi ayarı + 9 İzin uyarıları (Dart) | Agent D — `opus-medium-worker` |
| | 10 Alarm servisi: ses kilidi, süre sınırı, kaçırılan alarm, tuşlar, geri · 11 Saat dilimi/izin yeniden kurma | Ana oturum |
| 2 | 12 Entegrasyon: gen-l10n, format, analyze, testler, gradle unit test, APK, emülatör, ADR, commit'ler | Ana oturum |

Dosya kümeleri ayrıktır; `pubspec`, manifest, ARB, `service_locator.dart`, `MainActivity.kt`, `sqlite_storage.dart` yalnız faz 0'da ana oturumca değişir.

---

### Task 1: Ortak kaynaklar (ARB, Android kaynakları, manifest, ikon, ses)

**Files:**
- Modify: `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`
- Generated: `lib/l10n/app_localizations*.dart` (`flutter gen-l10n`)
- Modify: `android/app/src/main/res/values/strings.xml`, `values-tr/strings.xml`, `values-ar/strings.xml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/res/xml/locales_config.xml`
- Modify: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- Create: `android/app/src/main/res/raw/beep.wav`

**Interfaces — Produces:** aşağıdaki ARB anahtarları (Task 4–9 kullanır) ve Android string kaynakları (Task 7, 10).

- [ ] **Step 1: ARB anahtarlarını ekle** (TR dosyasında her anahtara `"@key": {"description": "..."}`; placeholder'lı anahtarda `placeholders`)

| Anahtar | tr | en | ar |
|---|---|---|---|
| `androidChannelBeepName` | Ezan Vakti Bildirimleri (kısa ton) | Ezan Vakti notifications (short tone) | تنبيهات Ezan Vakti (نغمة قصيرة) |
| `androidChannelSilentName` | Ezan Vakti Bildirimleri (sessiz) | Ezan Vakti notifications (silent) | تنبيهات Ezan Vakti (صامتة) |
| `quietIntro` (güncelle) | Bu aralıklarda Ezan Vakti bildirimleri sessiz gösterilir ya da hiç gösterilmez. "Telefonu da sustur" açıksa telefon aralık boyunca Rahatsız Etme moduna geçer, bitince eski haline döner. Alarmlar her durumda çalar. | During these windows Ezan Vakti notifications are shown silently or not at all. With "Silence the phone too" on, the phone switches to Do Not Disturb for the window and returns to normal when it ends. Alarms always ring. | خلال هذه الفترات تظهر تنبيهات التطبيق بصمت أو لا تظهر. عند تفعيل «إسكات الهاتف أيضًا» ينتقل الهاتف إلى وضع عدم الإزعاج طوال الفترة ويعود إلى حاله عند انتهائها. المنبهات ترن دائمًا. |
| `quietSilencePhone` | Telefonu da sustur | Silence the phone too | إسكات الهاتف أيضًا |
| `quietSilencePhoneHint` | Aralık boyunca Rahatsız Etme açılır | Do Not Disturb turns on for the window | يُفعَّل وضع عدم الإزعاج طوال الفترة |
| `quietSilencePhoneNoAccess` | Rahatsız Etme erişimi kapalı. Açmak için dokun. | Do Not Disturb access is off. Tap to allow. | الوصول إلى وضع عدم الإزعاج متوقف. اضغط للسماح. |
| `quietSilencePhoneSuffix` | Telefon susar | Phone silenced | يُسكَت الهاتف |
| `alarmUsePhoneVolume` | Telefonun alarm ses seviyesi | Phone's alarm volume | مستوى صوت المنبه في الهاتف |
| `alarmVolume` | Ses seviyesi | Volume | مستوى الصوت |
| `alarmVolumeValue` (placeholder `percent`: int) | %{percent} | {percent}% | {percent}٪ |
| `alarmVolumeHint` | Alarm çalarken ses tuşları sesi değiştirmez. | Volume buttons don't change the volume while the alarm rings. | لا تغيّر أزرار الصوت مستوى الصوت أثناء رنين المنبه. |
| `prefsAlarmRingLimit` | Alarm şu kadar sonra sussun | Silence alarm after | إسكات المنبه بعد |
| `prefsAlarmRingLimitHint` | Kapatılmayan alarm bu süre sonra ertelenir; erteleme hakkı yoksa susar. | An alarm that isn't dismissed snoozes after this time; with no snoozes left it stops. | يُؤجَّل المنبه غير المُطفأ بعد هذه المدة، وإن لم يتبقَّ تأجيل يتوقف. |
| `ringLimitUnlimited` | Sınırsız | Never | أبدًا |
| `fullScreenAlarmOff` | Tam ekran alarm izni kapalı. Alarm kilit ekranında açılmaz, yalnız bildirim olarak gelir. | Full-screen alarm permission is off. Alarms won't open on the lock screen, only as a notification. | إذن المنبه بملء الشاشة متوقف. لن يظهر المنبه على شاشة القفل، بل كتنبيه فقط. |
| `batteryOptimizationWarning` | Bu telefon uygulamayı arka planda uyutup alarmı geciktirebilir. Ezan Vakti'yi pil optimizasyonundan çıkar. | This phone may put the app to sleep and delay alarms. Exclude Ezan Vakti from battery optimization. | قد يُنيم هذا الهاتف التطبيق ويؤخر المنبه. استثنِ Ezan Vakti من تحسين البطارية. |
| `actionDontShowAgain` | Bir daha gösterme | Don't show again | لا تعرض مجددًا |
| `qiblaCompassUnavailable` | Bu telefonda pusula yok. Yukarıdaki açıyı kuzeye göre kullan. | This phone has no compass. Use the angle above, measured from north. | لا توجد بوصلة في هذا الهاتف. استخدم الزاوية أعلاه مقيسة من الشمال. |

- [ ] **Step 2: Android string kaynakları** — `values/strings.xml` (İngilizce taban), `values-tr`, `values-ar`:

```xml
<!-- values -->
<string name="alarm_missed_channel_name">Missed alarms</string>
<string name="alarm_missed_text">Missed alarm · %1$s</string>
<string name="quiet_rule_name">Prayer Times – quiet window</string>
<!-- values-tr -->
<string name="alarm_missed_channel_name">Kaçırılan alarmlar</string>
<string name="alarm_missed_text">Kaçırılan alarm · %1$s</string>
<string name="quiet_rule_name">Ezan Vakti – sessiz pencere</string>
<!-- values-ar -->
<string name="alarm_missed_channel_name">المنبهات الفائتة</string>
<string name="alarm_missed_text">منبه فائت · %1$s</string>
<string name="quiet_rule_name">أوقات الصلاة – فترة الهدوء</string>
```

- [ ] **Step 3: Manifest**

```xml
<!-- izinler bloğuna -->
<!-- Sessiz pencerede telefonu Rahatsız Etme'ye almak (kullanıcı sistem ayarından verir) -->
<uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY" />
<!-- <application ...> özniteliklerine -->
android:localeConfig="@xml/locales_config"
<!-- AlarmBootReceiver intent-filter'ına -->
<action android:name="android.intent.action.TIMEZONE_CHANGED"/>
<action android:name="android.intent.action.TIME_SET"/>
<action android:name="android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"/>
<!-- AlarmRingService'ten sonra -->
<!-- Sessiz pencere sınırlarında Rahatsız Etme kuralını açar/kapatır -->
<receiver android:name=".QuietModeReceiver" android:exported="false" />
```

- [ ] **Step 4: `res/xml/locales_config.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- Android 13+: Ayarlar > Uygulamalar > Dil. lib/l10n'daki dillerle aynı. -->
<locale-config xmlns:android="http://schemas.android.com/apk/res/android">
    <locale android:name="tr" />
    <locale android:name="en" />
    <locale android:name="ar" />
</locale-config>
```

- [ ] **Step 5: Temalı ikon** — `mipmap-anydpi-v26/ic_launcher.xml`:

```xml
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@drawable/ic_launcher_background"/>
  <foreground android:drawable="@drawable/ic_launcher_foreground"/>
  <!-- Android 13+ tek renk tema: ön plan saydam zeminde tek parça hilal,
       sistem yalnız alfa kanalını boyar. -->
  <monochrome android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
```

- [ ] **Step 6: Kısa ton**

Run: `mkdir -p android/app/src/main/res/raw && afconvert -f WAVE -d LEI16 ios/Runner/Sounds/beep.caf android/app/src/main/res/raw/beep.wav && file android/app/src/main/res/raw/beep.wav`
Expected: `RIFF (little-endian) data, WAVE audio, ... 16 bit`

- [ ] **Step 7: Kod üret ve doğrula**

Run: `flutter gen-l10n && flutter test test/l10n/arb_consistency_test.dart`
Expected: PASS

---

### Task 2: Alarm ses seviyesi modeli ve DB v16

**Files:**
- Modify: `lib/core/models/alarm.dart`
- Modify: `lib/features/prayer_times/data/sqlite_storage.dart` (şema v16, `getGeneralSettings` anahtar listesi)
- Test: `test/alarms/alarm_test.dart`, `test/storage/schema_migration_test.dart`

**Interfaces — Produces:** `Alarm.volume` (`int?`, 10–100, null = telefonun seviyesi); `Alarm.toMap()['volume']`; `GeneralSettings.alarmRingLimitKey` anahtarını depoda okur (sabit Task 8'de tanımlanır).

- [ ] **Step 1: Failing test** (`test/alarms/alarm_test.dart`)

```dart
test('volume map ile gidip gelir, aralik disi null olur', () {
  const alarm = Alarm(id: 'a', kind: AlarmKind.fixed, volume: 70);
  expect(Alarm.fromMap(alarm.toMap()).volume, 70);
  expect(Alarm.fromMap({...alarm.toMap(), 'volume': null}).volume, isNull);
  expect(Alarm.fromMap({...alarm.toMap(), 'volume': 5}).volume, isNull);
  expect(Alarm.fromMap({...alarm.toMap(), 'volume': 101}).volume, isNull);
});
```

- [ ] **Step 2: Model**

```dart
  /// Alarm çalarken telefonun alarm ses seviyesi (%10–100). `null` = telefonun
  /// o anki alarm seviyesi. **Yalnızca Android'de** etkili; iOS'ta AlarmKit
  /// seviye API'si vermiyor.
  final int? volume;
```
Kurucuya `this.volume`, `toMap`'e `'volume': volume`, `fromMap`'e `volume: _normalizeVolume(map['volume'])`, `copyWith`'e `int? volume` (`volume ?? this.volume`), `==` ve `hashCode`'a ekle. Dosya sonuna:

```dart
/// Bozuk ya da aralık dışı değer telefonun seviyesine düşer.
int? _normalizeVolume(Object? value) =>
    value is int && value >= 10 && value <= 100 ? value : null;
```

- [ ] **Step 3: Migration testi** (`test/storage/schema_migration_test.dart`, v14 testinin kalıbıyla)

```dart
test('v15 -> v16 alarms tablosuna volume kolonu ekler, kaydi korur', () async {
  final db = await openDatabase(inMemoryDatabasePath, version: 8, onCreate: (db, _) => createV8Schema(db));
  await SqliteStorage().onUpgrade(db, 8, 15);
  await db.insert('alarms', {'id': 'a1', 'kind': 'fixed'});
  await SqliteStorage().onUpgrade(db, 15, 16);
  final columns = await db.rawQuery('PRAGMA table_info(alarms)');
  expect(columns.map((c) => c['name']), contains('volume'));
  final row = (await db.query('alarms')).single;
  expect(row['id'], 'a1');
  expect(row['volume'], isNull);
  await db.close();
});
```

- [ ] **Step 4: Şema** — `version: 16`; `_createAlarmsTable` sütunlarının sonuna `volume INTEGER`; `onUpgrade` sonuna:

```dart
    if (oldVersion < 16) {
      // Alarm başına ses seviyesi (Android). Mevcut alarmlar NULL: telefonun
      // seviyesiyle çalmaya devam eder, davranış değişmez.
      await db.execute('ALTER TABLE alarms ADD COLUMN volume INTEGER');
    }
```
`getGeneralSettings` sorgusunda `IN (...)` listesine bir `?` ve `GeneralSettings.alarmRingLimitKey` ekle.

- [ ] **Step 5: Çalıştır** (Task 12'de, Task 8 ile birlikte derlenir): `flutter test test/alarms/alarm_test.dart test/storage/schema_migration_test.dart` → PASS

---

### Task 3: Device köprüsü (Dart), servis kayıtları, MainActivity kaydı

**Files:**
- Create: `lib/core/models/quiet_interval.dart`
- Create: `lib/core/services/device_settings_service.dart`
- Modify: `lib/core/di/service_locator.dart`
- Modify: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/MainActivity.kt`
- Test: `test/core/device_settings_service_test.dart`

**Interfaces — Produces:**
- `class QuietInterval { final DateTime start; final DateTime end; Map<String, int> toMap(); }` (`startMillis`, `endMillis`)
- `class BatteryStatus { final String manufacturer; final String brand; final bool ignoringOptimizations; }`
- `class DeviceSettingsService` — `canUseFullScreenIntent()`, `openFullScreenIntentSettings()`, `batteryStatus()`, `openBatteryOptimizationSettings()`, `isQuietModeSupported()`, `hasQuietModeAccess()`, `openQuietModeAccessSettings()`, `setQuietSchedule(List<QuietInterval>)`.
- Native yöntem adları (Task 7 uygular): `canUseFullScreenIntent`, `openFullScreenIntentSettings`, `batteryStatus` → `{manufacturer, brand, ignoringOptimizations}`, `openBatteryOptimizationSettings`, `isQuietModeSupported`, `hasQuietModeAccess`, `openQuietModeAccessSettings`, `setQuietSchedule` (`{intervals: [{startMillis, endMillis}]}`).
- Kayıtlar: `DeviceSettingsService`, `QuietPhoneScheduler` (Task 6'da yazılır; kurucu `QuietPhoneScheduler({required LocalStorage storage, required Future<void> Function(List<QuietInterval>) send, bool? enabled, DateTime Function()? clock})`), `ReminderRescheduler(quietPhoneScheduler: ...)`.
- MainActivity: `HeadingStreamHandler(this)` (Task 5) ve `DeviceChannel(this).register(flutterEngine)` (Task 7).

- [ ] **Step 1: Failing test** (`test/core/device_settings_service_test.dart`)

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.ekrembulbul.ezanvakti/device');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Android disinda native cagrilmaz, guvenli varsayilan doner', () async {
    final service = DeviceSettingsService(isAndroid: false);
    expect(await service.canUseFullScreenIntent(), isTrue);
    expect(await service.isQuietModeSupported(), isFalse);
    expect((await service.batteryStatus()).ignoringOptimizations, isTrue);
  });

  test('susturma plani milisaniye listesi olarak gider', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async { received = call; return null; });
    await DeviceSettingsService(isAndroid: true).setQuietSchedule([
      QuietInterval(DateTime.fromMillisecondsSinceEpoch(1000), DateTime.fromMillisecondsSinceEpoch(5000)),
    ]);
    expect(received!.method, 'setQuietSchedule');
    expect(received!.arguments, {'intervals': [{'startMillis': 1000, 'endMillis': 5000}]});
  });

  test('pil durumu okunur, native hata guvenli varsayilana duser', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => {'manufacturer': 'xiaomi', 'brand': 'redmi', 'ignoringOptimizations': false});
    final status = await DeviceSettingsService(isAndroid: true).batteryStatus();
    expect(status.manufacturer, 'xiaomi');
    expect(status.ignoringOptimizations, isFalse);
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'x'));
    expect((await DeviceSettingsService(isAndroid: true).batteryStatus()).ignoringOptimizations, isTrue);
  });
}
```

- [ ] **Step 2: `quiet_interval.dart`**

```dart
/// Telefonun Rahatsız Etme'de olacağı tek kesintisiz aralık.
class QuietInterval {
  final DateTime start;
  final DateTime end;

  const QuietInterval(this.start, this.end);

  Map<String, int> toMap() => {
    'startMillis': start.millisecondsSinceEpoch,
    'endMillis': end.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is QuietInterval && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'QuietInterval($start – $end)';
}
```

- [ ] **Step 3: `device_settings_service.dart`**

```dart
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/quiet_interval.dart';
import '../utils/app_logger.dart';

/// Pil optimizasyonu durumu; marka küçük harfle gelir.
class BatteryStatus {
  final String manufacturer;
  final String brand;
  final bool ignoringOptimizations;

  const BatteryStatus({
    required this.manufacturer,
    required this.brand,
    required this.ignoringOptimizations,
  });

  /// Bilinmeyen durumda uyarı gösterilmesin.
  static const BatteryStatus unknown = BatteryStatus(
    manufacturer: '',
    brand: '',
    ignoringOptimizations: true,
  );
}

/// Android cihaz ayarları ve izinleri: tam ekran alarm izni, pil
/// optimizasyonu, Rahatsız Etme erişimi ve sessiz pencere planı.
///
/// Android dışında ve native hata durumunda güvenli varsayılan döner:
/// uyarı göstermemek, kullanıcıyı yanlış uyarıyla rahatsız etmekten iyidir.
class DeviceSettingsService {
  static const MethodChannel _channel = MethodChannel(
    'com.ekrembulbul.ezanvakti/device',
  );

  final bool isAndroid;
  final AppLogger _logger;

  DeviceSettingsService({bool? isAndroid, AppLogger? logger})
    : isAndroid = isAndroid ?? Platform.isAndroid,
      _logger = logger ?? AppLogger();

  Future<bool> canUseFullScreenIntent() =>
      _bool('canUseFullScreenIntent', fallback: true);

  Future<void> openFullScreenIntentSettings() =>
      _call('openFullScreenIntentSettings');

  Future<BatteryStatus> batteryStatus() async {
    if (!isAndroid) return BatteryStatus.unknown;
    try {
      final map = await _channel.invokeMapMethod<String, Object?>(
        'batteryStatus',
      );
      if (map == null) return BatteryStatus.unknown;
      return BatteryStatus(
        manufacturer: (map['manufacturer'] as String? ?? '').toLowerCase(),
        brand: (map['brand'] as String? ?? '').toLowerCase(),
        ignoringOptimizations: map['ignoringOptimizations'] as bool? ?? true,
      );
    } on PlatformException catch (error) {
      _logger.warning('Battery status unavailable', error.code);
      return BatteryStatus.unknown;
    }
  }

  Future<void> openBatteryOptimizationSettings() =>
      _call('openBatteryOptimizationSettings');

  Future<bool> isQuietModeSupported() =>
      _bool('isQuietModeSupported', fallback: false);

  Future<bool> hasQuietModeAccess() =>
      _bool('hasQuietModeAccess', fallback: false);

  Future<void> openQuietModeAccessSettings() =>
      _call('openQuietModeAccessSettings');

  /// Hata çağırana gider: planlayıcı loglayıp sürdürür.
  Future<void> setQuietSchedule(List<QuietInterval> intervals) async {
    if (!isAndroid) return;
    await _channel.invokeMethod<void>('setQuietSchedule', {
      'intervals': [for (final interval in intervals) interval.toMap()],
    });
  }

  Future<bool> _bool(String method, {required bool fallback}) async {
    if (!isAndroid) return fallback;
    try {
      return await _channel.invokeMethod<bool>(method) ?? fallback;
    } on PlatformException catch (error) {
      _logger.warning('Device call failed ($method)', error.code);
      return fallback;
    }
  }

  Future<void> _call(String method) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (error) {
      _logger.warning('Device call failed ($method)', error.code);
    }
  }
}
```
(`isAndroid: false` için `fallback` true dönen `canUseFullScreenIntent` iOS'ta uyarı göstermez.)

- [ ] **Step 4: Servis kayıtları** (`service_locator.dart`, `ReminderRescheduler` kaydından önce)

```dart
    final deviceSettings = DeviceSettingsService();
    register<DeviceSettingsService>(deviceSettings);
    final quietPhoneScheduler = QuietPhoneScheduler(
      storage: localStorage,
      send: deviceSettings.setQuietSchedule,
    );
    register<QuietPhoneScheduler>(quietPhoneScheduler);

    register<ReminderRescheduler>(
      ReminderRescheduler(
        notificationScheduler: notificationScheduler,
        alarmScheduler: alarmScheduler,
        quietPhoneScheduler: quietPhoneScheduler,
      ),
    );
```

- [ ] **Step 5: MainActivity**

```kotlin
// configureFlutterEngine içinde, alarm kanalından sonra:
// Kıble pusulası: cihaz yönü (gerçek kuzey).
EventChannel(flutterEngine.dartExecutor.binaryMessenger, HeadingStreamHandler.CHANNEL)
    .setStreamHandler(HeadingStreamHandler(this))
// Cihaz ayarları: tam ekran izni, pil, Rahatsız Etme.
DeviceChannel(this).register(flutterEngine)
```
(`import io.flutter.plugin.common.EventChannel`)

---

### Task 4: Bildirim kanalları (Agent A)

**Files:**
- Modify: `lib/core/constants/notification_sounds.dart`
- Modify: `lib/features/notifications/data/flutter_local_notification_service.dart`
- Test: `test/notifications/notification_channel_test.dart` (yeni)

**Interfaces — Consumes:** ARB `androidChannelName`, `androidChannelDescription`, `androidChannelBeepName`, `androidChannelSilentName`; `res/raw/beep.wav` (Task 1). **Produces:** `NotificationSounds.androidChannelFor(String? soundId, {required bool silent})`.

- [ ] **Step 1: Failing test**

```dart
void main() {
  test('sessiz ses ya da sessiz pencere sessiz kanala gider', () {
    expect(NotificationSounds.androidChannelFor(NotificationSounds.silent, silent: false), NotificationSounds.androidSilentChannel);
    expect(NotificationSounds.androidChannelFor(NotificationSounds.beep, silent: true), NotificationSounds.androidSilentChannel);
  });
  test('kisa ton kendi kanalina, diger her sey sistem kanalina', () {
    expect(NotificationSounds.androidChannelFor(NotificationSounds.beep, silent: false), NotificationSounds.androidBeepChannel);
    expect(NotificationSounds.androidChannelFor(NotificationSounds.system, silent: false), 'ezan_vakti_channel');
    expect(NotificationSounds.androidChannelFor(null, silent: false), 'ezan_vakti_channel');
  });
}
```

- [ ] **Step 2: `NotificationSounds`**

```dart
  /// Android bildirim kanalları. Kanal sesi oluşturulduktan sonra
  /// değişmediği için ses başına ayrı kanal var. Sistem kanalı eski tek
  /// kanalın kimliğini korur: kullanıcının sistem ayarlarında yaptığı
  /// değişiklikler o kanalda.
  static const String androidSystemChannel = 'ezan_vakti_channel';
  static const String androidBeepChannel = 'ezan_vakti_beep';
  static const String androidSilentChannel = 'ezan_vakti_silent';

  /// `res/raw/beep.wav`.
  static const String androidBeepResource = 'beep';

  static String androidChannelFor(String? soundId, {required bool silent}) {
    if (silent || isSilent(soundId)) return androidSilentChannel;
    if (soundId == beep) return androidBeepChannel;
    return androidSystemChannel;
  }
```

- [ ] **Step 3: Servis** — `_androidChannelId` sabitini ve dosya başı yorumunu kaldır. `init` içinde tek kanal yerine:

```dart
      final l10n = await deviceLocalizations();
      final channels = [
        AndroidNotificationChannel(
          NotificationSounds.androidSystemChannel,
          l10n.androidChannelName,
          description: l10n.androidChannelDescription,
          importance: Importance.high,
        ),
        AndroidNotificationChannel(
          NotificationSounds.androidBeepChannel,
          l10n.androidChannelBeepName,
          description: l10n.androidChannelDescription,
          importance: Importance.high,
          sound: const RawResourceAndroidNotificationSound(
            NotificationSounds.androidBeepResource,
          ),
        ),
        AndroidNotificationChannel(
          NotificationSounds.androidSilentChannel,
          l10n.androidChannelSilentName,
          description: l10n.androidChannelDescription,
          importance: Importance.high,
          playSound: false,
          enableVibration: false,
        ),
      ];
      for (final channel in channels) {
        await androidPlugin.createNotificationChannel(channel);
      }
```
`scheduleNotification` içinde Android ayrıntısı (eski yorum bloğunu "kanal sese göre seçilir" diye güncelle):

```dart
    final channelId = NotificationSounds.androidChannelFor(
      soundId,
      silent: silent,
    );
    final isSilentChannel = channelId == NotificationSounds.androidSilentChannel;
    final androidDetails = AndroidNotificationDetails(
      channelId,
      switch (channelId) {
        NotificationSounds.androidBeepChannel => channelL10n.androidChannelBeepName,
        NotificationSounds.androidSilentChannel => channelL10n.androidChannelSilentName,
        _ => channelL10n.androidChannelName,
      },
      channelDescription: channelL10n.androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_notification',
      // Android 8 öncesinde kanal yok; ses bildirimin kendisinden okunur.
      playSound: !isSilentChannel,
      enableVibration: !isSilentChannel,
      sound: channelId == NotificationSounds.androidBeepChannel
          ? const RawResourceAndroidNotificationSound(
              NotificationSounds.androidBeepResource,
            )
          : null,
    );
```

- [ ] **Step 4: Çalıştır (Task 12):** `flutter test test/notifications/` → PASS

---

### Task 5: Kıble pusulası Android (Agent A)

**Files:**
- Create: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/HeadingMath.kt`
- Create: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/HeadingStreamHandler.kt`
- Create: `android/app/src/test/kotlin/com/ekrembulbul/ezanvakti/HeadingMathTest.kt`
- Modify: `lib/features/qibla/data/heading_service.dart`, `lib/presentation/screens/qibla_screen.dart`
- Test: `test/qibla/heading_service_test.dart`

**Interfaces — Consumes:** MainActivity kaydı `HeadingStreamHandler(this)` ve `HeadingStreamHandler.CHANNEL` (Task 3); ARB `qiblaCompassUnavailable`. **Produces:** olay `{"degrees": Double 0..360, "accuracy": Double}` (iOS ile aynı), hata kodu `heading_unavailable`; Dart `HeadingService.headingsAt({double? latitude, double? longitude})`.

- [ ] **Step 1: Failing Kotlin test**

```kotlin
package com.ekrembulbul.ezanvakti

import org.junit.Assert.*
import org.junit.Test

class HeadingMathTest {
    @Test fun normalizeWrapsIntoCircle() {
        assertEquals(350.0, HeadingMath.normalize(-10.0), 1e-9)
        assertEquals(10.0, HeadingMath.normalize(370.0), 1e-9)
        assertEquals(0.0, HeadingMath.normalize(360.0), 1e-9)
    }
    @Test fun trueHeadingAddsDeclination() {
        assertEquals(5.0, HeadingMath.trueHeading(355.0, 10.0), 1e-9)
        assertEquals(350.0, HeadingMath.trueHeading(5.0, -15.0), 1e-9)
    }
    @Test fun accuracyPrefersEstimateAndRejectsUnreliable() {
        assertEquals(Math.toDegrees(0.1), HeadingMath.accuracyDegrees(0.1f, HeadingMath.STATUS_HIGH), 1e-6)
        assertEquals(20.0, HeadingMath.accuracyDegrees(-1f, HeadingMath.STATUS_MEDIUM), 1e-9)
        assertEquals(40.0, HeadingMath.accuracyDegrees(null, HeadingMath.STATUS_LOW), 1e-9)
        assertEquals(-1.0, HeadingMath.accuracyDegrees(0.1f, HeadingMath.STATUS_UNRELIABLE), 1e-9)
    }
    @Test fun emitsOnlyForOneDegreeChangeAcrossNorth() {
        assertTrue(HeadingMath.shouldEmit(null, 10.0))
        assertFalse(HeadingMath.shouldEmit(359.6, 0.2))
        assertTrue(HeadingMath.shouldEmit(359.5, 0.6))
    }
}
```

- [ ] **Step 2: `HeadingMath.kt`**

```kotlin
package com.ekrembulbul.ezanvakti

import kotlin.math.abs

/** Pusula hesapları; sensörden bağımsız, birim testli. */
object HeadingMath {
    // SensorManager.SENSOR_STATUS_* ile aynı değerler; testte Android
    // sınıfı yüklemeden kullanılsın diye burada.
    const val STATUS_UNRELIABLE = 0
    const val STATUS_LOW = 1
    const val STATUS_MEDIUM = 2
    const val STATUS_HIGH = 3

    fun normalize(degrees: Double): Double {
        val r = degrees % 360.0
        return if (r < 0) r + 360.0 else r
    }

    /** Manyetik yön + manyetik sapma = gerçek (coğrafi) yön. */
    fun trueHeading(magnetic: Double, declination: Double) = normalize(magnetic + declination)

    /** Derece cinsinden sapma payı; -1 = güvenilmez (arayüz kalibrasyon ister). */
    fun accuracyDegrees(estimateRadians: Float?, status: Int): Double {
        if (status <= STATUS_UNRELIABLE) return -1.0
        if (estimateRadians != null && estimateRadians >= 0f) return Math.toDegrees(estimateRadians.toDouble())
        return when (status) {
            STATUS_HIGH -> 10.0
            STATUS_MEDIUM -> 20.0
            else -> 40.0
        }
    }

    /** 1°'den küçük değişim ibreyi titretiyor (iOS'taki headingFilter = 1). */
    fun shouldEmit(previous: Double?, next: Double, threshold: Double = 1.0): Boolean {
        if (previous == null) return true
        val diff = abs(normalize(next - previous + 180.0) - 180.0)
        return diff >= threshold
    }
}
```

- [ ] **Step 3: `HeadingStreamHandler.kt`**

```kotlin
package com.ekrembulbul.ezanvakti

import android.app.Activity
import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.view.Surface
import io.flutter.plugin.common.EventChannel

/** Cihazın pusula yönünü Flutter'a akıtır (iOS HeadingStreamHandler.swift'in
 *  karşılığı). Dart koordinat verirse manyetik sapma eklenir ve gerçek kuzey
 *  döner; vermezse manyetik kuzey. */
class HeadingStreamHandler(private val activity: Activity) : EventChannel.StreamHandler, SensorEventListener {
    companion object { const val CHANNEL = "com.ekrembulbul.ezanvakti/heading" }

    private val sensors = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null
    private var declination: Double? = null
    private var lastEmitted: Double? = null
    private val rotation = FloatArray(9)
    private val remapped = FloatArray(9)
    private val orientation = FloatArray(3)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: sensors.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
        if (sensor == null) {
            events.error("heading_unavailable", "No compass sensor", null)
            return
        }
        val args = arguments as? Map<*, *>
        val lat = (args?.get("latitude") as? Number)?.toFloat()
        val lon = (args?.get("longitude") as? Number)?.toFloat()
        declination = if (lat != null && lon != null) {
            GeomagneticField(lat, lon, 0f, System.currentTimeMillis()).declination.toDouble()
        } else null
        sink = events
        lastEmitted = null
        sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        sink = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onSensorChanged(event: SensorEvent) {
        val out = sink ?: return
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        // Ekran dönmüşse eksenler ekrana göre çevrilir: yön her zaman
        // ekranın üst kenarının baktığı yön olsun.
        val (axisX, axisY) = when (displayRotation()) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
        SensorManager.remapCoordinateSystem(rotation, axisX, axisY, remapped)
        SensorManager.getOrientation(remapped, orientation)
        val magnetic = HeadingMath.normalize(Math.toDegrees(orientation[0].toDouble()))
        val degrees = declination?.let { HeadingMath.trueHeading(magnetic, it) } ?: magnetic
        if (!HeadingMath.shouldEmit(lastEmitted, degrees)) return
        lastEmitted = degrees
        val estimate = if (event.values.size > 4) event.values[4] else null
        out.success(mapOf(
            "degrees" to degrees,
            "accuracy" to HeadingMath.accuracyDegrees(estimate, event.accuracy),
        ))
    }

    @Suppress("DEPRECATION")
    private fun displayRotation(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) activity.display?.rotation ?: Surface.ROTATION_0
        else activity.windowManager.defaultDisplay.rotation
}
```

- [ ] **Step 4: Dart failing test** (`test/qibla/heading_service_test.dart`'a)

```dart
  test('koordinat dinleme argumani olarak native e gider', () async {
    const channel = EventChannel(channelName);
    Object? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(channel, MockStreamHandler.inline(
          onListen: (arguments, sink) {
            received = arguments;
            sink.endOfStream();
          },
        ));
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(channel, null));

    await HeadingService().headingsAt(latitude: 41.0, longitude: 29.0).toList();
    expect(received, {'latitude': 41.0, 'longitude': 29.0});
  });
```

- [ ] **Step 5: `HeadingService`**

```dart
  /// Yön akışı; koordinatsız (manyetik kuzey, iOS'ta cihaz konumu).
  Stream<HeadingReading> get headings => headingsAt();

  /// [latitude]/[longitude] verilirse Android manyetik sapmayı ekleyip gerçek
  /// kuzeyi döner. iOS cihazın kendi konumunu kullanır, argümanı yok sayar.
  Stream<HeadingReading> headingsAt({double? latitude, double? longitude}) {
    if (!_hasNative) return const Stream<HeadingReading>.empty();
    final arguments = latitude != null && longitude != null
        ? {'latitude': latitude, 'longitude': longitude}
        : null;
    return _channel
        .receiveBroadcastStream(arguments)
        .map(HeadingReading.fromMap)
        .where((reading) => reading != null)
        .cast<HeadingReading>();
  }
```
(`headings` getter'ının eski gövdesini ve dokümanını bu ikisine taşı; "Bozuk olaylar sessizce atlanır" notu `headingsAt` üstünde kalsın.)

- [ ] **Step 6: `QiblaScreen`** — `initState`:

```dart
    final location = widget.location;
    final stream = widget.headings ??
        const HeadingService().headingsAt(
          latitude: location?.latitude,
          longitude: location?.longitude,
        );
    _subscription = stream.listen(
      (reading) {
        if (!mounted) return;
        setState(() {
          _reading = reading;
          _track(_delta);
        });
      },
      // Pusula sensörü yoksa native akış hata verir; ekran "bekleniyor"da
      // asılı kalmasın.
      onError: (Object error) {
        AppLogger().warning('Heading stream failed', error.runtimeType);
        if (mounted) setState(() => _compassUnavailable = true);
      },
    );
```
Alan: `bool _compassUnavailable = false;`. Durum metninde `if (reading == null)` dalından önce: `if (_compassUnavailable && reading == null) Text(context.l10n.qiblaCompassUnavailable, textAlign: TextAlign.center, style: AppTypography.rowSubtitle.copyWith(color: tokens.textSecondary))`, ardından `else if (reading == null) ...` (mevcut).

- [ ] **Step 7: Çalıştır (Task 12):** `flutter test test/qibla/` ve `./gradlew testDebugUnitTest --tests '*HeadingMathTest'` → PASS

---

### Task 6: Sessiz pencere planı ve ekranı (Agent B)

**Files:**
- Modify: `lib/core/models/quiet_window.dart`
- Create: `lib/features/notifications/domain/quiet_phone_planner.dart`
- Create: `lib/features/notifications/domain/quiet_phone_scheduler.dart`
- Modify: `lib/presentation/services/reminder_rescheduler.dart`
- Modify: `lib/presentation/screens/quiet_windows_screen.dart`
- Test: `test/notifications/quiet_phone_planner_test.dart` (yeni), `test/notifications/quiet_window_rules_test.dart` (JSON testi), `test/presentation/reminder_rescheduler_test.dart`

**Interfaces — Consumes:** `QuietInterval` (Task 3), `DeviceSettingsService` (Task 3; `isQuietModeSupported`, `hasQuietModeAccess`, `openQuietModeAccessSettings`), ARB `quietSilencePhone*` ve `quietIntro` (Task 1). **Produces:** `QuietWindow.silencePhone`; `QuietPhonePlanner.plan({required List<QuietWindow> windows, required List<PrayerTime> prayerTimes, required DateTime now}) → List<QuietInterval>`; `QuietPhoneScheduler` (Task 3'teki kurucu imzası); `ReminderRescheduler({..., QuietPhoneScheduler? quietPhoneScheduler})`.

- [ ] **Step 1: Failing testler** (`test/notifications/quiet_phone_planner_test.dart`; `prayerTimeFor` `test/support/fakes.dart`'tan: öğle 13:15, yatsı 22:01)

```dart
void main() {
  final friday = DateTime(2026, 10, 9); // Cuma
  final days = [for (var i = 0; i < 7; i++) prayerTimeFor(friday.add(Duration(days: i)))];

  QuietWindow window({bool silence = true, bool active = true}) => QuietWindow.fridayDefault()
      .copyWith(silencePhone: silence, isActive: active);

  test('Cuma penceresi yalniz Cuma ogle cevresinde aralik uretir', () {
    final plan = QuietPhonePlanner.plan(windows: [window()], prayerTimes: days, now: friday);
    expect(plan, [QuietInterval(DateTime(2026, 10, 9, 13, 0), DateTime(2026, 10, 9, 14, 15))]);
  });

  test('silencePhone kapali ya da pencere pasifse aralik yok', () {
    expect(QuietPhonePlanner.plan(windows: [window(silence: false)], prayerTimes: days, now: friday), isEmpty);
    expect(QuietPhonePlanner.plan(windows: [window(active: false)], prayerTimes: days, now: friday), isEmpty);
  });

  test('bitmis aralik atilir, suren aralik kalir', () {
    final during = DateTime(2026, 10, 9, 13, 30);
    expect(QuietPhonePlanner.plan(windows: [window()], prayerTimes: days, now: during).single.start, DateTime(2026, 10, 9, 13, 0));
    final after = DateTime(2026, 10, 9, 14, 15);
    expect(QuietPhonePlanner.plan(windows: [window()], prayerTimes: days, now: after), isEmpty);
  });

  test('cakisan ve gece yarisini asan pencereler birlesir', () {
    final isha = QuietWindow(id: 'i', trigger: QuietTrigger.prayer, prayerType: PrayerType.isha,
        minutesBefore: 0, minutesAfter: 180, silencePhone: true);
    final isha2 = QuietWindow(id: 'j', trigger: QuietTrigger.prayer, prayerType: PrayerType.isha,
        minutesBefore: 30, minutesAfter: 60, silencePhone: true);
    final plan = QuietPhonePlanner.plan(windows: [isha, isha2], prayerTimes: days.take(1).toList(), now: friday);
    expect(plan, [QuietInterval(DateTime(2026, 10, 9, 21, 31), DateTime(2026, 10, 10, 1, 1))]);
  });

  test('sifir uzunluklu pencere aralik uretmez', () {
    final zero = QuietWindow(id: 'z', trigger: QuietTrigger.prayer, prayerType: PrayerType.asr,
        minutesBefore: 0, minutesAfter: 0, silencePhone: true);
    expect(QuietPhonePlanner.plan(windows: [zero], prayerTimes: days, now: friday), isEmpty);
  });
}
```
`quiet_window_rules_test.dart`'a:

```dart
  test('silencePhone JSON ile gidip gelir, eski kayitta false', () {
    final w = QuietWindow.fridayDefault().copyWith(silencePhone: true);
    expect(QuietWindow.fromJson(w.toJson()).silencePhone, isTrue);
    final legacy = Map<String, dynamic>.of(w.toJson())..remove('silencePhone');
    expect(QuietWindow.fromJson(legacy).silencePhone, isFalse);
  });
```
`reminder_rescheduler_test.dart`'a (dosyadaki kurulum yardımcılarıyla):

```dart
  test('susturma plani vakit verisiyle gonderilir, veri yoksa dokunulmaz', () async {
    final sent = <List<QuietInterval>>[];
    final storage = FakeStorage();
    await storage.saveQuietWindows([QuietWindow.fridayDefault().copyWith(silencePhone: true)]);
    final scheduler = QuietPhoneScheduler(storage: storage, enabled: true,
        send: (intervals) async => sent.add(intervals), clock: () => DateTime(2026, 10, 9));
    final rescheduler = ReminderRescheduler(
      notificationScheduler: NotificationScheduler(notificationService: FakeNotificationService(), storage: storage, quietWindowsEnabled: true),
      alarmScheduler: AlarmScheduler(alarmService: FakeAlarmService(), storage: storage),
      quietPhoneScheduler: scheduler,
    );
    await rescheduler.reschedule(location: null, prayerTimes: const [], skips: const {});
    expect(sent, isEmpty);
    await rescheduler.reschedule(location: null, prayerTimes: [prayerTimeFor(DateTime(2026, 10, 9))], skips: const {});
    expect(sent.single, isNotEmpty);
  });

  test('susturma plani hatasi diger planlamayi bozmaz', () async {
    final storage = FakeStorage();
    await storage.saveQuietWindows([QuietWindow.fridayDefault().copyWith(silencePhone: true)]);
    final scheduler = QuietPhoneScheduler(storage: storage, enabled: true,
        send: (_) async => throw PlatformException(code: 'x'), clock: () => DateTime(2026, 10, 9));
    await expectLater(scheduler.schedule(prayerTimes: [prayerTimeFor(DateTime(2026, 10, 9))]), completes);
  });
```
(Dosyada `FakeAlarmService`/`FakeStorage` adları farklıysa dosyadaki mevcut yardımcıları kullan.)

- [ ] **Step 2: `QuietWindow.silencePhone`**

```dart
  /// Pencere boyunca telefon Rahatsız Etme'ye alınsın mı (Android 10+).
  /// Varsayılan kapalı: özel izin ister, kullanıcı kendisi açar.
  final bool silencePhone;
```
Kurucu `this.silencePhone = false`; `copyWith(bool? silencePhone)`; `toJson` `'silencePhone': silencePhone`; `fromJson` `silencePhone: json['silencePhone'] as bool? ?? false`. Sınıf dokümanındaki "telefonu sessize alamıyor/dokunmaz" cümlesini: "Alarmlara hiçbir platformda dokunmaz. `silencePhone` açıksa Android'de telefon pencere boyunca Rahatsız Etme'ye alınır (bkz. `QuietPhonePlanner`)." olarak güncelle.

- [ ] **Step 3: `quiet_phone_planner.dart`**

```dart
import '../../../core/models/notification_setting.dart' show PrayerType;
import '../../../core/models/prayer_time.dart';
import '../../../core/models/quiet_interval.dart';
import '../../../core/models/quiet_window.dart';

/// Sessiz pencerelerden telefonun Rahatsız Etme'de olacağı aralıkları çıkarır.
///
/// Saf: zaman ve veri dışarıdan gelir. Sonuç sıralı ve birleştirilmiştir —
/// çakışan ya da uç uca değen aralıklar tek aralık olur, böylece native taraf
/// arada modu kapatıp açmaz. Bitmiş aralıklar atılır, süren aralık kalır.
class QuietPhonePlanner {
  const QuietPhonePlanner._();

  static List<QuietInterval> plan({
    required List<QuietWindow> windows,
    required List<PrayerTime> prayerTimes,
    required DateTime now,
  }) {
    final raw = <QuietInterval>[];
    for (final window in windows) {
      if (!window.isActive || !window.silencePhone) continue;
      final type = window.trigger == QuietTrigger.fridayDhuhr
          ? PrayerType.dhuhr
          : window.prayerType;
      if (type == null) continue;
      for (final day in prayerTimes) {
        final prayerAt = _timeOf(day, type);
        if (!window.matchesPrayer(type, prayerAt)) continue;
        final start = prayerAt.subtract(Duration(minutes: window.minutesBefore));
        final end = prayerAt.add(Duration(minutes: window.minutesAfter));
        if (!end.isAfter(start) || !end.isAfter(now)) continue;
        raw.add(QuietInterval(start, end));
      }
    }
    raw.sort((a, b) => a.start.compareTo(b.start));
    final merged = <QuietInterval>[];
    for (final interval in raw) {
      final last = merged.isEmpty ? null : merged.last;
      if (last != null && !interval.start.isAfter(last.end)) {
        merged[merged.length - 1] = QuietInterval(
          last.start,
          interval.end.isAfter(last.end) ? interval.end : last.end,
        );
      } else {
        merged.add(interval);
      }
    }
    return merged;
  }

  static DateTime _timeOf(PrayerTime day, PrayerType type) => switch (type) {
    PrayerType.fajr => day.fajr,
    PrayerType.sunrise => day.sunrise,
    PrayerType.dhuhr => day.dhuhr,
    PrayerType.asr => day.asr,
    PrayerType.maghrib => day.maghrib,
    PrayerType.isha => day.isha,
  };
}
```

- [ ] **Step 4: `quiet_phone_scheduler.dart`**

```dart
import 'dart:io';

import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/quiet_interval.dart';
import '../../../core/utils/app_logger.dart';
import 'quiet_phone_planner.dart';

/// Sessiz pencerelerin telefon susturma planını native'e yollar (yalnız
/// Android). Vakit verisi yoksa hiçbir şey göndermez: geçici veri hatası
/// mevcut planı silmesin. Hata loglanır, çağırana gitmez — bildirim ve
/// alarm planlaması bundan etkilenmemeli.
class QuietPhoneScheduler {
  final LocalStorage storage;
  final Future<void> Function(List<QuietInterval> intervals) send;
  final bool enabled;
  final DateTime Function() clock;

  QuietPhoneScheduler({
    required this.storage,
    required this.send,
    bool? enabled,
    DateTime Function()? clock,
  }) : enabled = enabled ?? Platform.isAndroid,
       clock = clock ?? DateTime.now;

  Future<void> schedule({required List<PrayerTime> prayerTimes}) async {
    if (!enabled || prayerTimes.isEmpty) return;
    try {
      final windows = await storage.getQuietWindows();
      final intervals = QuietPhonePlanner.plan(
        windows: windows,
        prayerTimes: prayerTimes,
        now: clock(),
      );
      await send(intervals);
    } catch (error, stackTrace) {
      AppLogger().error('Quiet phone schedule failed', error, stackTrace);
    }
  }
}
```

- [ ] **Step 5: `ReminderRescheduler`** — alan `final QuietPhoneScheduler? quietPhoneScheduler;`, kurucuda `this.quietPhoneScheduler`; `Future.wait` listesine:

```dart
      if (quietPhoneScheduler != null)
        _runSchedule(
          'quiet_phone',
          () => quietPhoneScheduler!.schedule(prayerTimes: prayerTimes),
        ),
```
Sınıf dokümanına "Telefon susturma planı üçüncü bağımsız iştir; kendi hatasını loglar." ekle.

- [ ] **Step 6: `QuietWindowsScreen`** — `WidgetsBindingObserver` ekle; alanlar:

```dart
  bool _quietSupported = false;
  bool _quietAccess = false;

  /// İzin ekranına gidilen pencere; dönünce erişim verildiyse anahtar açılır.
  String? _pendingSilenceId;

  DeviceSettingsService get _device => ServiceLocator().get<DeviceSettingsService>();
```
`initState`'e `WidgetsBinding.instance.addObserver(this); _refreshQuietAccess();`, `dispose`'a `removeObserver`. Yöntemler:

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshQuietAccess();
  }

  Future<void> _refreshQuietAccess() async {
    final supported = await _device.isQuietModeSupported();
    final access = supported && await _device.hasQuietModeAccess();
    if (!mounted) return;
    setState(() {
      _quietSupported = supported;
      _quietAccess = access;
    });
    final pending = _pendingSilenceId;
    if (pending == null) return;
    _pendingSilenceId = null;
    final window = _windows.where((w) => w.id == pending).firstOrNull;
    if (access && window != null) {
      await _updateWindow(window, window.copyWith(silencePhone: true));
    }
  }

  Future<void> _setSilencePhone(QuietWindow window, bool value, {VoidCallback? onChanged}) async {
    if (value && !_quietAccess) {
      _pendingSilenceId = window.id;
      await _device.openQuietModeAccessSettings();
      return;
    }
    await _updateWindow(window, window.copyWith(silencePhone: value));
    onChanged?.call();
  }

  /// Android 9 ve öncesinde satır yok.
  Widget _silenceRow(QuietWindow window, {VoidCallback? onChanged}) {
    if (!_quietSupported) return const SizedBox.shrink();
    final tokens = context.tokens;
    final missingAccess = window.silencePhone && !_quietAccess;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        context.l10n.quietSilencePhone,
        style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
      ),
      subtitle: Text(
        missingAccess ? context.l10n.quietSilencePhoneNoAccess : context.l10n.quietSilencePhoneHint,
        style: AppTypography.hint.copyWith(
          color: missingAccess ? tokens.accent : tokens.textTertiary,
        ),
      ),
      value: window.silencePhone,
      activeThumbColor: tokens.accent,
      onChanged: (value) => _setSilencePhone(window, value, onChanged: onChanged),
    );
  }
```
`missingAccess` iken alt yazıya dokunmak izin ekranını açsın: `subtitle` metnini `GestureDetector(onTap: missingAccess ? _device.openQuietModeAccessSettings : null, child: Text(...))` ile sar. `_fridayCard()`'ta `_modeRow(friday)` sonrasına `_silenceRow(friday)`; `_editCustom` panelinde `_modeRow(current, ...)` sonrasına `_silenceRow(current, onChanged: () => setSheetState(() {}))`. `_customRow` alt yazısına `if (_quietSupported && window.silencePhone) ' · ${context.l10n.quietSilencePhoneSuffix}'` ekle. `_updateWindow` mevcut yöntemi (kayıt + yeniden planlama) kullanılır.

- [ ] **Step 7: Çalıştır (Task 12):** `flutter test test/notifications/ test/presentation/reminder_rescheduler_test.dart test/widgets/` → PASS

---

### Task 7: Telefonu susturma native + device kanalı (Agent C)

**Files:**
- Create: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/QuietSchedule.kt`
- Create: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/QuietModeController.kt`
- Create: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/QuietModeReceiver.kt`
- Create: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/DeviceChannel.kt`
- Create: `android/app/src/test/kotlin/com/ekrembulbul/ezanvakti/QuietScheduleTest.kt`

**Interfaces — Consumes:** manifest izni/alıcısı ve `R.string.quiet_rule_name` (Task 1), MainActivity kaydı `DeviceChannel(this).register(flutterEngine)` (Task 3), Dart yöntem adları ve argümanları (Task 3). **Produces:** `QuietModeController.reapply(context: Context)` (Task 11 boot alıcısı çağırır), `QuietModeController.isSupported()`, `QuietModeController.hasAccess(context)`, `QuietModeController.setSchedule(context, intervals)`.

- [ ] **Step 1: Failing test**

```kotlin
package com.ekrembulbul.ezanvakti

import org.junit.Assert.*
import org.junit.Test

class QuietScheduleTest {
    private val a = QuietInterval(1_000, 2_000)
    private val b = QuietInterval(5_000, 6_000)

    @Test fun parseDropsInvalidAndSorts() {
        val parsed = QuietSchedule.parse(listOf(
            mapOf("startMillis" to 5_000L, "endMillis" to 6_000L),
            mapOf("startMillis" to 2_000, "endMillis" to 1_000),
            mapOf("startMillis" to "x"),
            mapOf("startMillis" to 1_000, "endMillis" to 2_000),
        ))
        assertEquals(listOf(a, b), parsed)
    }
    @Test fun jsonRoundTrip() {
        assertEquals(listOf(a, b), QuietSchedule.decode(QuietSchedule.encode(listOf(a, b))))
        assertEquals(emptyList<QuietInterval>(), QuietSchedule.decode(null))
        assertEquals(emptyList<QuietInterval>(), QuietSchedule.decode("bozuk"))
    }
    @Test fun insideIsStartInclusiveEndExclusive() {
        assertTrue(QuietSchedule.isInside(listOf(a), 1_000))
        assertFalse(QuietSchedule.isInside(listOf(a), 2_000))
    }
    @Test fun nextBoundaryIsNearestFutureEdge() {
        assertEquals(1_000L, QuietSchedule.nextBoundary(listOf(a, b), 0))
        assertEquals(2_000L, QuietSchedule.nextBoundary(listOf(a, b), 1_500))
        assertEquals(5_000L, QuietSchedule.nextBoundary(listOf(a, b), 2_000))
        assertNull(QuietSchedule.nextBoundary(listOf(a, b), 6_000))
    }
    @Test fun pruneKeepsRunningInterval() {
        assertEquals(listOf(b), QuietSchedule.prune(listOf(a, b), 2_000))
        assertEquals(listOf(a, b), QuietSchedule.prune(listOf(a, b), 1_500))
    }
    @Test fun decideWritesOnlyOnChange() {
        // Kullanıcı pencere içinde DND'yi elle kapattıysa uygulanan durum hâlâ
        // "açık"tır; yeniden açma yazılmaz (D6).
        assertNull(QuietSchedule.decide(desired = true, applied = true))
        assertEquals(true, QuietSchedule.decide(desired = true, applied = false))
        assertEquals(false, QuietSchedule.decide(desired = false, applied = true))
        assertNull(QuietSchedule.decide(desired = false, applied = false))
    }
}
```

- [ ] **Step 2: `QuietSchedule.kt`**

```kotlin
package com.ekrembulbul.ezanvakti

import org.json.JSONArray
import org.json.JSONObject

/** Telefonun Rahatsız Etme'de olacağı aralık: başlangıç dahil, bitiş hariç. */
data class QuietInterval(val startMillis: Long, val endMillis: Long)

/** Sessiz pencere planının saf kuralları (Dart planı hesaplar, burası uygular). */
object QuietSchedule {
    fun parse(raw: List<*>): List<QuietInterval> = raw.mapNotNull { item ->
        val map = item as? Map<*, *> ?: return@mapNotNull null
        val start = (map["startMillis"] as? Number)?.toLong() ?: return@mapNotNull null
        val end = (map["endMillis"] as? Number)?.toLong() ?: return@mapNotNull null
        if (start <= 0 || end <= start) null else QuietInterval(start, end)
    }.sortedBy { it.startMillis }

    fun encode(intervals: List<QuietInterval>): String = JSONArray().apply {
        intervals.forEach { put(JSONObject().put("s", it.startMillis).put("e", it.endMillis)) }
    }.toString()

    fun decode(json: String?): List<QuietInterval> {
        if (json.isNullOrBlank()) return emptyList()
        return try {
            val array = JSONArray(json)
            (0 until array.length()).map {
                val o = array.getJSONObject(it)
                QuietInterval(o.getLong("s"), o.getLong("e"))
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun isInside(intervals: List<QuietInterval>, now: Long) =
        intervals.any { now >= it.startMillis && now < it.endMillis }

    fun nextBoundary(intervals: List<QuietInterval>, now: Long): Long? =
        intervals.flatMap { listOf(it.startMillis, it.endMillis) }.filter { it > now }.minOrNull()

    fun prune(intervals: List<QuietInterval>, now: Long) = intervals.filter { it.endMillis > now }

    /** Sisteme yazılacak durum; `null` = yazma. Yalnız istenen durum son
     *  uygulanandan farklıysa yazılır: kullanıcının elle kapattığı DND
     *  uygulama açılınca yeniden açılmaz. */
    fun decide(desired: Boolean, applied: Boolean): Boolean? = if (desired == applied) null else desired
}
```

- [ ] **Step 3: `QuietModeController.kt`**

```kotlin
package com.ekrembulbul.ezanvakti

import android.app.AlarmManager
import android.app.AutomaticZenRule
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.service.notification.Condition
import android.util.Log
import androidx.annotation.RequiresApi

/** Sessiz pencerelerde telefonu Rahatsız Etme'ye alan uygulama kuralı.
 *
 *  API 35+ hedefleyen uygulama genel DND'yi değiştiremez; sisteme kendi
 *  kuralını verir, sistem kuralları birleştirir. Bu yüzden "bitince eski
 *  haline dön" ve "kullanıcının kendi DND'sine dokunma" sistemden gelir.
 *  Plan Dart'tan gelir; burada yalnız sıradaki sınıra tek alarm kurulur. */
object QuietModeController {
    private const val PREFS = "ezanvakti_quiet"
    private const val KEY_INTERVALS = "intervals"
    private const val KEY_RULE_ID = "rule_id"
    private const val KEY_APPLIED = "applied_active"
    private const val REQUEST_CODE = 7301
    private val CONDITION_ID: Uri = Uri.parse("condition://com.ekrembulbul.ezanvakti/quiet")

    fun isSupported() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    fun hasAccess(context: Context): Boolean =
        context.getSystemService(NotificationManager::class.java)?.isNotificationPolicyAccessGranted ?: false

    fun setSchedule(context: Context, intervals: List<QuietInterval>) {
        prefs(context).edit().putString(KEY_INTERVALS, QuietSchedule.encode(intervals)).apply()
        reapply(context)
    }

    /** Planı şimdiye göre uygular ve sıradaki sınırı kurar. Sınır alarmı,
     *  açılış, saat dilimi ve izin değişiminde çağrılır; tekrar çağrılması
     *  zararsızdır. */
    fun reapply(context: Context) {
        if (!isSupported()) return
        val now = System.currentTimeMillis()
        val prefs = prefs(context)
        val intervals = QuietSchedule.prune(QuietSchedule.decode(prefs.getString(KEY_INTERVALS, null)), now)
        prefs.edit().putString(KEY_INTERVALS, QuietSchedule.encode(intervals)).apply()
        val applied = prefs.getBoolean(KEY_APPLIED, false)
        try {
            if (intervals.isEmpty()) {
                removeRule(context)
                prefs.edit().putBoolean(KEY_APPLIED, false).apply()
            } else {
                val desired = QuietSchedule.isInside(intervals, now)
                val write = QuietSchedule.decide(desired, applied)
                if (write != null) {
                    setState(context, ensureRule(context), write)
                    prefs.edit().putBoolean(KEY_APPLIED, write).apply()
                }
            }
        } catch (error: SecurityException) {
            // Erişim yok ya da geri alındı: durum değişmez, ekran uyarır.
            Log.w("EzanQuiet", "event=quiet_apply_denied")
        } catch (error: Exception) {
            Log.e("EzanQuiet", "event=quiet_apply_failed type=" + error.javaClass.simpleName)
        }
        scheduleNext(context, QuietSchedule.nextBoundary(intervals, now))
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    @Suppress("DEPRECATION")
    private fun ensureRule(context: Context): String {
        val nm = context.getSystemService(NotificationManager::class.java)
        val prefs = prefs(context)
        prefs.getString(KEY_RULE_ID, null)?.let { id ->
            if (nm.getAutomaticZenRule(id) != null) return id
        }
        // Kullanıcı kuralı sistemden silmişse yeniden kurulur; yeni kural
        // kapalı başlar.
        val rule = AutomaticZenRule(
            context.getString(R.string.quiet_rule_name),
            null,
            ComponentName(context, MainActivity::class.java),
            CONDITION_ID,
            null,
            NotificationManager.INTERRUPTION_FILTER_PRIORITY,
            true,
        )
        val id = nm.addAutomaticZenRule(rule)
        prefs.edit().putString(KEY_RULE_ID, id).putBoolean(KEY_APPLIED, false).apply()
        return id
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun setState(context: Context, ruleId: String, active: Boolean) {
        val nm = context.getSystemService(NotificationManager::class.java)
        val state = if (active) Condition.STATE_TRUE else Condition.STATE_FALSE
        nm.setAutomaticZenRuleState(ruleId, Condition(CONDITION_ID, context.getString(R.string.quiet_rule_name), state))
    }

    private fun removeRule(context: Context) {
        val prefs = prefs(context)
        val id = prefs.getString(KEY_RULE_ID, null) ?: return
        context.getSystemService(NotificationManager::class.java)?.removeAutomaticZenRule(id)
        prefs.edit().remove(KEY_RULE_ID).apply()
    }

    private fun scheduleNext(context: Context, at: Long?) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        val pi = PendingIntent.getBroadcast(
            context, REQUEST_CODE, Intent(context, QuietModeReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (at == null) {
            am.cancel(pi)
            return
        }
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
        if (exact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
```
(`removeRule` erişim yokken `SecurityException` atabilir; `reapply`'daki `catch` yakalar ve KEY_APPLIED dokunulmaz.)

- [ ] **Step 4: `QuietModeReceiver.kt`**

```kotlin
package com.ekrembulbul.ezanvakti

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Sessiz pencere sınırında (başlangıç ya da bitiş) planı yeniden uygular. */
class QuietModeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        QuietModeController.reapply(context)
    }
}
```

- [ ] **Step 5: `DeviceChannel.kt`**

```kotlin
package com.ekrembulbul.ezanvakti

import android.app.Activity
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Flutter <-> cihaz ayarları köprüsü: tam ekran alarm izni, pil
 *  optimizasyonu, Rahatsız Etme erişimi ve sessiz pencere planı. */
class DeviceChannel(private val activity: Activity) {
    companion object { const val CHANNEL = "com.ekrembulbul.ezanvakti/device" }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "canUseFullScreenIntent" -> result.success(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
                            activity.getSystemService(NotificationManager::class.java)?.canUseFullScreenIntent() ?: true
                        else true,
                    )
                    "openFullScreenIntentSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            open(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, withPackage = true)
                        }
                        result.success(null)
                    }
                    "batteryStatus" -> {
                        val power = activity.getSystemService(PowerManager::class.java)
                        result.success(mapOf(
                            "manufacturer" to Build.MANUFACTURER.lowercase(),
                            "brand" to Build.BRAND.lowercase(),
                            "ignoringOptimizations" to (power?.isIgnoringBatteryOptimizations(activity.packageName) ?: true),
                        ))
                    }
                    "openBatteryOptimizationSettings" -> {
                        // Liste ekranı: REQUEST_IGNORE_BATTERY_OPTIMIZATIONS izni
                        // Play politikasında kısıtlı, bu ekran izin istemez.
                        open(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        result.success(null)
                    }
                    "isQuietModeSupported" -> result.success(QuietModeController.isSupported())
                    "hasQuietModeAccess" -> result.success(QuietModeController.hasAccess(activity))
                    "openQuietModeAccessSettings" -> {
                        open(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        result.success(null)
                    }
                    "setQuietSchedule" -> {
                        val raw = call.argument<List<*>>("intervals") ?: emptyList<Any>()
                        QuietModeController.setSchedule(activity, QuietSchedule.parse(raw))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                Log.e("EzanDevice", "event=device_call_failed method=" + call.method + " type=" + error.javaClass.simpleName)
                result.error("device_operation_failed", "Device operation failed", mapOf("operation" to call.method))
            }
        }
    }

    /** Ayar ekranı bulunamazsa uygulama ayrıntıları açılır. */
    private fun open(action: String, withPackage: Boolean = false) {
        val packageUri = Uri.fromParts("package", activity.packageName, null)
        try {
            activity.startActivity(Intent(action).apply { if (withPackage) data = packageUri })
        } catch (_: ActivityNotFoundException) {
            activity.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri))
        }
    }
}
```

- [ ] **Step 6: Çalıştır (Task 12):** `cd android && ./gradlew testDebugUnitTest --tests '*QuietScheduleTest'` → PASS; `flutter build apk --debug` (lint NewApi uyarısı olmamalı)

---

### Task 8: Ses seviyesi arayüzü ve çalma süresi ayarı (Agent D)

**Files:**
- Modify: `lib/core/models/general_settings.dart`
- Modify: `lib/core/models/alarm_plan.dart`
- Modify: `lib/features/alarms/domain/alarm_scheduler.dart`
- Modify: `lib/presentation/screens/alarm_edit_screen.dart`
- Modify: `lib/presentation/widgets/settings/notification_prefs_section.dart`
- Test: `test/models/models_test.dart` (ya da general settings testi neredeyse orası), `test/alarms/alarm_plan_test.dart`, `test/alarms/alarm_scheduler_repeat_test.dart`, `test/widgets/` altındaki ilgili ekran testleri

**Interfaces — Consumes:** `Alarm.volume` (Task 2), ARB `alarmUsePhoneVolume`, `alarmVolume`, `alarmVolumeValue`, `alarmVolumeHint`, `prefsAlarmRingLimit`, `prefsAlarmRingLimitHint`, `ringLimitUnlimited` (Task 1). **Produces:** `GeneralSettings.alarmRingLimitKey = 'general_alarm_ring_limit'`, `GeneralSettings.alarmRingLimitMinutes` (int, 0 = sınırsız, varsayılan 10), `GeneralSettings.alarmRingLimitOptions = [5, 10, 15, 30, 0]`; plan girdisi anahtarları `volume` (int?) ve `ringLimitMinutes` (int?, sınırsızda null) — Task 10 native okur.

- [ ] **Step 1: Failing testler**

```dart
test('alarm calma suresi varsayilan 10, bozuk deger varsayilana duser', () {
  expect(const GeneralSettings().alarmRingLimitMinutes, 10);
  expect(GeneralSettings.fromMap({GeneralSettings.alarmRingLimitKey: '0'}).alarmRingLimitMinutes, 0);
  expect(GeneralSettings.fromMap({GeneralSettings.alarmRingLimitKey: '7'}).alarmRingLimitMinutes, 10);
  expect(GeneralSettings.fromMap(const GeneralSettings(alarmRingLimitMinutes: 30).toMap()).alarmRingLimitMinutes, 30);
});
```
`alarm_plan_test.dart`:

```dart
test('plan girdisi ses seviyesini ve calma suresini tasir', () {
  final entry = AlarmPlanEntry(
    id: 'a', alarm: const Alarm(id: 'a', kind: AlarmKind.fixed, volume: 60),
    scheduledTime: DateTime(2026, 10, 9, 6), theme: AlarmTheme.fallback,
    chainConfig: const {}, ringLimitMinutes: 10,
  );
  expect(entry.toMap()['volume'], 60);
  expect(entry.toMap()['ringLimitMinutes'], 10);
});
```
(`AlarmTheme.fallback` adı dosyada farklıysa mevcut test yardımcısını kullan.) `alarm_scheduler_repeat_test.dart`'taki kurulumla: genel ayar `alarmRingLimitMinutes: 0` iken plana giden kayıtların `toMap()['ringLimitMinutes']` değeri `null`, 15 iken `15` olmalı.

- [ ] **Step 2: `GeneralSettings`**

```dart
  static const String alarmRingLimitKey = 'general_alarm_ring_limit';

  /// Seçenekler (dakika); 0 = sınırsız.
  static const List<int> alarmRingLimitOptions = [5, 10, 15, 30, 0];

  /// Kapatılmayan alarm bu kadar dakika sonra ertelenir ya da susar
  /// (yalnız Android). 0 = sınırsız.
  final int alarmRingLimitMinutes;
```
Kurucuda `this.alarmRingLimitMinutes = 10`; `copyWith`, `toMap` (`alarmRingLimitKey: alarmRingLimitMinutes.toString()`), `fromMap`:

```dart
      alarmRingLimitMinutes: switch (int.tryParse(map[alarmRingLimitKey] ?? '')) {
        final value? when alarmRingLimitOptions.contains(value) => value,
        _ => defaults.alarmRingLimitMinutes,
      },
```
`==` ve `hashCode`'a ekle.

- [ ] **Step 3: `AlarmPlanEntry`** — `final int? ringLimitMinutes;` (kurucuda isteğe bağlı), `toMap`'e:

```dart
    // Yalnızca Android okur (iOS'ta AlarmKit; bkz. docs/adr/0003).
    'volume': alarm.volume,
    'ringLimitMinutes': ringLimitMinutes,
```

- [ ] **Step 4: `AlarmScheduler._scheduleAlarms`** — `alarms` okunduktan sonra:

```dart
    final general = await storage.getGeneralSettings();
    // 0 = sınırsız; native'e "yok" olarak gider.
    final ringLimit = general.alarmRingLimitMinutes > 0
        ? general.alarmRingLimitMinutes
        : null;
```
`AlarmPlanEntry(...)` çağrısına `ringLimitMinutes: ringLimit`.

- [ ] **Step 5: `AlarmEditScreen`** — kurucuya `bool? volumeSupported` (`volumeSupported ?? Platform.isAndroid`, `fadeInSupported` kalıbı), state `int? _volume` (`initState`: `_volume = a?.volume;`), kaydederken `volume: widget.volumeSupported ? _volume : widget.alarm?.volume`. `alarmSoundVolumeNote` notu yalnız `!widget.volumeSupported` iken çizilsin. Titreşim anahtarından önce (`widget.volumeSupported` iken):

```dart
              _switchTile(
                context.l10n.alarmUsePhoneVolume,
                _volume == null,
                (usePhone) => setState(() => _volume = usePhone ? null : 80),
              ),
              if (_volume != null) _dependentGroup([_volumeSlider()]),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  context.l10n.alarmVolumeHint,
                  style: AppTypography.hint.copyWith(color: tokens.textTertiary),
                ),
              ),
```
ve yöntem:

```dart
  Widget _volumeSlider() {
    final volume = _volume!;
    return Row(
      children: [
        Text(context.l10n.alarmVolume, style: TextStyle(color: tokens.textPrimary)),
        Expanded(
          child: Slider(
            value: volume.toDouble(),
            min: 10,
            max: 100,
            divisions: 9,
            label: context.l10n.alarmVolumeValue(volume),
            activeColor: tokens.accent,
            onChanged: (value) => setState(() => _volume = value.round()),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            context.l10n.alarmVolumeValue(volume),
            textAlign: TextAlign.end,
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 6: `NotificationPrefsSection`** — alan `final bool? showAlarmRingLimit;` (kurucuda isteğe bağlı); `build`'de `final showRingLimit = showAlarmRingLimit ?? Platform.isAndroid;`. Varsayılan ses `OptionRow`'undan sonra:

```dart
          if (showRingLimit) ...[
            Divider(height: 1, thickness: 1, color: tokens.divider),
            OptionRow<int>(
              label: context.l10n.prefsAlarmRingLimit,
              selected: settings.alarmRingLimitMinutes,
              valueLabel: (minutes) => minutes == 0
                  ? context.l10n.ringLimitUnlimited
                  : formatCompactMinutes(minutes, context.l10n),
              items: [
                for (final minutes in GeneralSettings.alarmRingLimitOptions)
                  OptionItem(
                    value: minutes,
                    label: minutes == 0
                        ? context.l10n.ringLimitUnlimited
                        : formatCompactMinutes(minutes, context.l10n),
                  ),
              ],
              onChanged: (value) => _update(
                context,
                settings.copyWith(alarmRingLimitMinutes: value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                context.l10n.prefsAlarmRingLimitHint,
                style: AppTypography.hint.copyWith(color: tokens.textTertiary, height: 1.4),
              ),
            ),
          ],
```
(`_update` hem depoya yazar hem `onChanged` ile alarmları yeniden uzlaştırır.)

- [ ] **Step 7: Widget testleri** — alarm düzenleme ekranı: `volumeSupported: false` iken ses notu var, "Telefonun alarm ses seviyesi" yok; `true` iken anahtar kapatılınca kaydırıcı görünür ve kaydedilen alarmda `volume` 80. Ayar bölümü: `showAlarmRingLimit: true` iken satır ve "10 dk" değeri görünür; `false` iken yok.

- [ ] **Step 8: Çalıştır (Task 12):** `flutter test test/alarms/ test/models/ test/widgets/` → PASS

---

### Task 9: Tam ekran ve pil uyarıları (Agent D)

**Files:**
- Create: `lib/features/alarms/domain/battery_advice.dart`
- Modify: `lib/presentation/widgets/reminders/alarms_section.dart`
- Modify: `lib/presentation/screens/reminders_screen.dart`
- Test: `test/alarms/battery_advice_test.dart` (yeni), `test/widgets/reminders/` altına bant testi

**Interfaces — Consumes:** `DeviceSettingsService`, `BatteryStatus` (Task 3); ARB `fullScreenAlarmOff`, `batteryOptimizationWarning`, `actionDontShowAgain`, `actionOpen`. **Produces:** `BatteryAdvice.shouldWarn({required BatteryStatus status, required bool dismissed, required bool hasActiveAlarm})`, `BatteryAdvice.dismissedKey`.

- [ ] **Step 1: Failing test**

```dart
void main() {
  BatteryStatus status({String m = 'xiaomi', String b = 'redmi', bool ignoring = false}) =>
      BatteryStatus(manufacturer: m, brand: b, ignoringOptimizations: ignoring);

  test('bilinen markada, optimizasyon aciksa ve alarm varsa uyarir', () {
    expect(BatteryAdvice.shouldWarn(status: status(), dismissed: false, hasActiveAlarm: true), isTrue);
    expect(BatteryAdvice.shouldWarn(status: status(m: 'google', b: 'redmi'), dismissed: false, hasActiveAlarm: true), isTrue);
  });
  test('muaf, kapatilmis, alarmsiz ya da bilinmeyen markada uyarmaz', () {
    expect(BatteryAdvice.shouldWarn(status: status(ignoring: true), dismissed: false, hasActiveAlarm: true), isFalse);
    expect(BatteryAdvice.shouldWarn(status: status(), dismissed: true, hasActiveAlarm: true), isFalse);
    expect(BatteryAdvice.shouldWarn(status: status(), dismissed: false, hasActiveAlarm: false), isFalse);
    expect(BatteryAdvice.shouldWarn(status: status(m: 'google', b: 'google'), dismissed: false, hasActiveAlarm: true), isFalse);
  });
}
```

- [ ] **Step 2: `battery_advice.dart`**

```dart
import '../../../core/services/device_settings_service.dart';

/// Pil optimizasyonu uyarısının kararı.
///
/// Android'in kendi pil tasarrufu alarm saatini (`setAlarmClock`)
/// geciktirmiyor; sorun bazı üreticilerin ek uyutma sistemlerinde. Uyarı
/// yalnız bu markalarda çıkar (dontkillmyapp.com'daki yaygın vakalar);
/// liste gerçek cihaz testinde güncellenir.
class BatteryAdvice {
  const BatteryAdvice._();

  static const String dismissedKey = 'battery_warning_dismissed';

  static const Set<String> aggressiveBrands = {
    'xiaomi', 'redmi', 'poco', 'samsung', 'huawei', 'honor', 'oneplus',
    'oppo', 'vivo', 'realme', 'meizu', 'asus', 'tecno', 'infinix',
  };

  static bool shouldWarn({
    required BatteryStatus status,
    required bool dismissed,
    required bool hasActiveAlarm,
  }) {
    if (dismissed || !hasActiveAlarm || status.ignoringOptimizations) {
      return false;
    }
    return aggressiveBrands.contains(status.manufacturer) ||
        aggressiveBrands.contains(status.brand);
  }
}
```

- [ ] **Step 3: `AlarmsSection`** — yeni alanlar (kurucuda isteğe bağlı): `bool fullScreenAllowed = true`, `VoidCallback? onOpenFullScreenSettings`, `bool showBatteryWarning = false`, `VoidCallback? onOpenBatterySettings`, `VoidCallback? onDismissBatteryWarning`. `build`'de `?_permissionBanner(context),` satırından sonra `?_fullScreenBanner(context), ?_batteryBanner(context),`:

```dart
  /// Android 14+: izin kapalıyken alarm kilit ekranında açılmaz.
  Widget? _fullScreenBanner(BuildContext context) {
    if (fullScreenAllowed || !alarms.any((alarm) => alarm.isActive)) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InfoBanner(
        icon: Icons.fullscreen_exit_rounded,
        text: context.l10n.fullScreenAlarmOff,
        action: TextButton(
          onPressed: onOpenFullScreenSettings,
          child: Text(context.l10n.actionOpen),
        ),
      ),
    );
  }

  Widget? _batteryBanner(BuildContext context) {
    if (!showBatteryWarning) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InfoBanner(
        icon: Icons.battery_alert_rounded,
        text: context.l10n.batteryOptimizationWarning,
        // Dar ekranda iki düğme metni sıkıştırmasın: alt alta.
        action: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextButton(onPressed: onOpenBatterySettings, child: Text(context.l10n.actionOpen)),
            TextButton(onPressed: onDismissBatteryWarning, child: Text(context.l10n.actionDontShowAgain)),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 4: `RemindersScreen`** — alanlar `bool _fullScreenAllowed = true; BatteryStatus _batteryStatus = BatteryStatus.unknown; bool _batteryDismissed = false;`, `DeviceSettingsService get _device => locator.get<DeviceSettingsService>();` (dosyadaki `locator` kalıbı). `_refreshPermissions()` içinde mevcut okumalarla birlikte:

```dart
    final fullScreen = await _device.canUseFullScreenIntent();
    final battery = await _device.batteryStatus();
    final dismissed = await _storage.getSetting(BatteryAdvice.dismissedKey) == 'true';
```
ve `setState`'e ata (dosyadaki depo alanının adını kullan). `AlarmsSection(...)` çağrısına:

```dart
              fullScreenAllowed: _fullScreenAllowed,
              onOpenFullScreenSettings: _device.openFullScreenIntentSettings,
              showBatteryWarning: BatteryAdvice.shouldWarn(
                status: _batteryStatus,
                dismissed: _batteryDismissed,
                hasActiveAlarm: alarms.any((alarm) => alarm.isActive),
              ),
              onOpenBatterySettings: _device.openBatteryOptimizationSettings,
              onDismissBatteryWarning: () async {
                setState(() => _batteryDismissed = true);
                await _storage.setSetting(BatteryAdvice.dismissedKey, 'true');
              },
```
(`alarms` değişkeninin bu kapsamdaki adı farklıysa onu kullan.) Ekran öne dönünce `_refreshPermissions` zaten çağrılıyor; ayardan dönünce bant kalkar.

- [ ] **Step 5: Widget testi** — `AlarmsSection` açık alarmla `fullScreenAllowed: false` → `fullScreenAlarmOff` metni; `true` → yok. `showBatteryWarning: true` → iki düğme; "Bir daha gösterme"ye basınca `onDismissBatteryWarning` çağrılır.

- [ ] **Step 6: Çalıştır (Task 12):** `flutter test test/alarms/battery_advice_test.dart test/widgets/reminders/` → PASS

---

### Task 10: Alarm servisi — ses kilidi, süre sınırı, kaçırılan alarm, tuşlar, geri (ana oturum)

**Files:**
- Modify: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmArgs.kt`
- Create: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmVolume.kt`
- Create: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/RingTimeout.kt`
- Modify: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmRingService.kt`
- Modify: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmRingActivity.kt`
- Test: `android/app/src/test/kotlin/com/ekrembulbul/ezanvakti/AlarmArgsTest.kt`, `AlarmVolumeTest.kt`, `RingTimeoutTest.kt`

**Interfaces — Consumes:** plan girdisi `volume`, `ringLimitMinutes` (Task 8); `R.string.alarm_missed_*` (Task 1). **Produces:** `AlarmArgs.volumePercent: Int?`, `AlarmArgs.ringLimitMinutes: Int?`.

- [ ] **Step 1: Failing testler**

```kotlin
class AlarmArgsTest {
    private val base = AlarmArgs("a", 1_000, "", "default", vibrate = true, snoozeEnabled = true, snoozeMinutes = 5)
    @Test fun newFieldsSurviveJsonAndMap() {
        val args = base.copy(volumePercent = 70, ringLimitMinutes = 10)
        assertEquals(args, AlarmArgs.fromJson(args.toJson()))
        val fromMap = AlarmArgs.fromMap(mapOf("id" to "a", "timeMillis" to 1_000L, "volume" to 70,
            "ringLimitMinutes" to 10, "snoozeMinutes" to 5))
        assertEquals(70, fromMap.volumePercent)
        assertEquals(10, fromMap.ringLimitMinutes)
        assertNull(AlarmArgs.fromJson(base.toJson())!!.volumePercent)
    }
    @Test fun outOfRangeValuesAreInvalid() {
        assertFalse(base.copy(volumePercent = 5).isValid)
        assertFalse(base.copy(ringLimitMinutes = 0).isValid)
        assertTrue(base.copy(volumePercent = 100, ringLimitMinutes = 120).isValid)
    }
}
class AlarmVolumeTest {
    @Test fun nullPercentKeepsCurrent() = assertEquals(4, AlarmVolume.targetIndex(null, current = 4, min = 1, max = 7))
    @Test fun percentScalesAndClamps() {
        assertEquals(7, AlarmVolume.targetIndex(100, current = 2, min = 1, max = 7))
        assertEquals(1, AlarmVolume.targetIndex(10, current = 5, min = 1, max = 7))
        assertEquals(4, AlarmVolume.targetIndex(50, current = 1, min = 0, max = 7))
    }
}
class RingTimeoutTest {
    @Test fun missedNoticeOnlyWhenNothingWillRingAgain() {
        assertTrue(RingTimeout.missedNotice(missionEnabled = false, chainContinues = false))
        assertFalse(RingTimeout.missedNotice(missionEnabled = true, chainContinues = true))
        assertTrue(RingTimeout.missedNotice(missionEnabled = true, chainContinues = false))
    }
    @Test fun delayInMillis() {
        assertEquals(600_000L, RingTimeout.delayMillis(10))
        assertNull(RingTimeout.delayMillis(null))
    }
}
```

- [ ] **Step 2: `AlarmArgs`** — alanlar `val volumePercent: Int? = null, val ringLimitMinutes: Int? = null`; `isValid`'e `&& (volumePercent == null || volumePercent in 10..100) && (ringLimitMinutes == null || ringLimitMinutes in 1..120)`; `toJson`'a `put("volumePercent", volumePercent ?: JSONObject.NULL)`, `put("ringLimitMinutes", ringLimitMinutes ?: JSONObject.NULL)`; `fromMap`'e `volumePercent = (values["volume"] as? Number)?.toInt(), ringLimitMinutes = (values["ringLimitMinutes"] as? Number)?.toInt()`; `fromJson`'a `if (o.isNull("volumePercent")) null else o.optInt("volumePercent")` (anahtar yoksa `isNull` true döner) ve aynısı `ringLimitMinutes` için.

- [ ] **Step 3: `AlarmVolume.kt` ve `RingTimeout.kt`**

```kotlin
/** Alarm akışının hedef seviye indeksi. */
object AlarmVolume {
    /** Yüzde verilmemişse mevcut seviye korunur; verilmişse akış aralığına sıkıştırılır
     *  (en az 1: sıfır yüzde alarmı sessiz bırakmasın). */
    fun targetIndex(percent: Int?, current: Int, min: Int, max: Int): Int {
        if (percent == null || max <= 0) return current
        return Math.round(max * percent / 100.0).toInt().coerceIn(maxOf(min, 1), max)
    }
}

/** Çalma süresi sınırının saf kuralları (spec D11). */
object RingTimeout {
    fun delayMillis(limitMinutes: Int?): Long? = limitMinutes?.let { it * 60_000L }

    /** Görevli alarmda zincir sürüyorsa alarm `graceSeconds` sonra yeniden
     *  çalar (ADR 0001); "kaçırıldı" demek yanlış olur. */
    fun missedNotice(missionEnabled: Boolean, chainContinues: Boolean) = !missionEnabled || !chainContinues
}
```

- [ ] **Step 4: `AlarmRingService`** — sabitler `MISSED_CHANNEL_ID = "ezan_vakti_alarm_missed"`, `MISSED_NOTIF_BASE = 9_920_000`, `VOLUME_GUARD_MILLIS = 500L`; alanlar `private var restoreVolumeIndex: Int? = null`, `private var lockedVolumeIndex: Int? = null`. `startRinging(args)` başında `lockVolume(args)`, sonunda `startRingTimeout(args)`. `stopRinging()` içinde `fadeHandler.removeCallbacksAndMessages(null)` sonrasına `unlockVolume()`.

```kotlin
    /** Alarm çalarken alarm akışı hedef seviyede sabit kalır: çalar ekranı
     *  önde değilken basılan ses tuşları da geri alınır. Bitince kullanıcının
     *  önceki seviyesi geri yüklenir. */
    private fun lockVolume(args: AlarmArgs) {
        val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        val stream = AudioManager.STREAM_ALARM
        val current = audio.getStreamVolume(stream)
        val min = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) audio.getStreamMinVolume(stream) else 0
        val target = AlarmVolume.targetIndex(args.volumePercent, current, min, audio.getStreamMaxVolume(stream))
        try {
            if (target != current) audio.setStreamVolume(stream, target, 0)
        } catch (error: SecurityException) {
            AlarmJournal(this).record("volume_lock", args, result = "failed", error = error)
            return
        }
        restoreVolumeIndex = current
        lockedVolumeIndex = target
        val guard = object : Runnable {
            override fun run() {
                val locked = lockedVolumeIndex ?: return
                try {
                    if (audio.getStreamVolume(stream) != locked) audio.setStreamVolume(stream, locked, 0)
                } catch (_: SecurityException) {
                    return
                }
                fadeHandler.postDelayed(this, VOLUME_GUARD_MILLIS)
            }
        }
        fadeHandler.postDelayed(guard, VOLUME_GUARD_MILLIS)
    }

    private fun unlockVolume() {
        val restore = restoreVolumeIndex
        lockedVolumeIndex = null
        restoreVolumeIndex = null
        if (restore == null) return
        val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        try {
            if (audio.getStreamVolume(AudioManager.STREAM_ALARM) != restore) {
                audio.setStreamVolume(AudioManager.STREAM_ALARM, restore, 0)
            }
        } catch (_: SecurityException) {
        }
    }

    private fun startRingTimeout(args: AlarmArgs) {
        val delay = RingTimeout.delayMillis(args.ringLimitMinutes) ?: return
        fadeHandler.postDelayed({
            val active = current
            if (active != null && active.id == args.id && active.timeMillis == args.timeMillis) onRingTimeout(active)
        }, delay)
    }

    /** Süre doldu: erteleme hakkı varsa mevcut erteleme geçişi, yoksa
     *  kaydırarak durdurmayla aynı yol (spec K5/D11). */
    private fun onRingTimeout(args: AlarmArgs) {
        val missions = AndroidMissionStore.missions(this)
        val previous = missions.session(args.alarmId)
        val snoozed = if (args.snoozeEnabled) missions.snooze(args.alarmId, args.snoozeMinutes, System.currentTimeMillis()) else null
        if (snoozed != null) {
            try {
                AlarmScheduling.rearm(this, snoozed, requireNotNull(snoozed.snoozedUntilMillis))
                AlarmJournal(this).record("ring_timeout_snooze", args)
                finishRinging()
                return
            } catch (error: Exception) {
                if (previous != null && missions.session(args.alarmId)?.timerScheduleId == previous.timerScheduleId) {
                    missions.restore(previous)
                }
                AlarmJournal(this).record("ring_timeout_snooze", args, result = "failed", error = error)
            }
        }
        if (!recordStop(args)) {
            // Durdurma reddedildi (görev zinciri kurulamadı): ses sürer,
            // kullanıcı görevi bitirene dek; zamanlayıcı yeniden kurulmaz.
            AlarmJournal(this).record("ring_timeout_stop", args, result = "failed")
            return
        }
        val chainContinues = missions.session(args.alarmId)?.deadlineMillis != null
        AlarmJournal(this).record("ring_timeout_stop", args)
        if (RingTimeout.missedNotice(args.missionEnabled, chainContinues)) postMissed(args)
        finishRinging()
    }

    private fun finishRinging() {
        stopRinging()
        current = null
        ringingAlarmId = null
        stopSelf()
    }

    private fun postMissed(args: AlarmArgs) {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager.getNotificationChannel(MISSED_CHANNEL_ID) == null) {
            manager.createNotificationChannel(NotificationChannel(
                MISSED_CHANNEL_ID, getString(R.string.alarm_missed_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                setSound(null, null)
                enableVibration(false)
            })
        }
        val open = PendingIntent.getActivity(
            this, ("missed" + args.alarmId).hashCode(),
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val firedAt = args.originalFireAtMillis ?: args.timeMillis
        val time = android.text.format.DateFormat.getTimeFormat(this).format(Date(firedAt))
        val notification = NotificationCompat.Builder(this, MISSED_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(args.label.ifBlank { getString(R.string.alarm_default_label) })
            .setContentText(getString(R.string.alarm_missed_text, time))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try {
            // Aynı alarmın yeni kaçırılışı eskisinin yerine geçer.
            manager.notify(MISSED_NOTIF_BASE + (args.alarmId.hashCode() and 0xFFFF), notification)
        } catch (_: SecurityException) {
        }
    }
```
(`import android.media.AudioManager`, `java.util.Date`.) `ACTION_STOP` ve `ACTION_CANCEL` dallarındaki "stopRinging + current = null + ringingAlarmId = null + stopSelf" üçlüsü `finishRinging()` olarak sadeleştirilebilir; davranış aynı kalmalı.

- [ ] **Step 5: `AlarmRingActivity`**

```kotlin
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 16 + API 36 hedefte onBackPressed çağrılmıyor; geri hareketi
        // çalar ekranını kapatmasın (spec D20).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            ) { /* yok say */ }
        }
        // ... mevcut gövde
    }

    /** Ses tuşları alarm sesini değiştirmez (K4); servis seviyeyi ayrıca korur. */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?) =
        if (isVolumeKey(keyCode)) true else super.onKeyDown(keyCode, event)

    override fun onKeyUp(keyCode: Int, event: KeyEvent?) =
        if (isVolumeKey(keyCode)) true else super.onKeyUp(keyCode, event)

    private fun isVolumeKey(keyCode: Int) = keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
        keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_MUTE
```
(`import android.view.KeyEvent`, `android.window.OnBackInvokedDispatcher`.)

- [ ] **Step 6: Çalıştır (Task 12):** `cd android && ./gradlew testDebugUnitTest` → PASS (mevcut AlarmMissions/Reconciler/Repeats testleri dahil)

---

### Task 11: Saat dilimi, saat ve kesin alarm izni değişiminde yeniden kurma (ana oturum)

**Files:**
- Create: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmTimeShift.kt`
- Modify: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmBootReceiver.kt`
- Modify: `android/app/src/main/kotlin/com/ekrembulbul/ezanvakti/AlarmScheduling.kt`
- Test: `android/app/src/test/kotlin/com/ekrembulbul/ezanvakti/AlarmTimeShiftTest.kt`

**Interfaces — Consumes:** `QuietModeController.reapply(context)` (Task 7). **Produces:** `AlarmScheduling.rememberZone(context, zone)`, `AlarmScheduling.rememberedZone(context): TimeZone?`.

- [ ] **Step 1: Failing test**

```kotlin
class AlarmTimeShiftTest {
    private val istanbul = TimeZone.getTimeZone("Europe/Istanbul")
    private val berlin = TimeZone.getTimeZone("Europe/Berlin")
    private fun at(zone: String, day: Int, hour: Int, minute: Int = 0) =
        ZonedDateTime.of(2026, 10, day, hour, minute, 0, 0, ZoneId.of(zone)).toInstant().toEpochMilli()
    private val now = at("Europe/Istanbul", 10, 12)
    private fun fixed(time: Long, weekdays: List<Int> = emptyList()) = AlarmArgs("f", time, "", "default",
        vibrate = true, snoozeEnabled = true, snoozeMinutes = 5, repeatWeekdays = weekdays, repeatHour = 6, repeatMinute = 0)

    @Test fun datedFixedKeepsWallClockInNewZone() {
        val moved = AlarmTimeShift.shift(fixed(at("Europe/Istanbul", 11, 6)), istanbul, berlin, now)!!
        assertEquals(at("Europe/Berlin", 11, 6), moved.timeMillis)
    }
    @Test fun weeklyFixedMovesToNextWallClockOccurrence() {
        val moved = AlarmTimeShift.shift(fixed(at("Europe/Istanbul", 11, 6), (1..7).toList()), istanbul, berlin, now)!!
        assertEquals(at("Europe/Berlin", 11, 6), moved.timeMillis)
    }
    @Test fun anchoredAndWatchdogAreUntouched() {
        val anchored = fixed(at("Europe/Istanbul", 11, 5, 12)).copy(repeatHour = null, repeatMinute = null)
        assertSame(anchored, AlarmTimeShift.shift(anchored, istanbul, berlin, now))
        val watchdog = fixed(at("Europe/Istanbul", 11, 6)).copy(originalFireAtMillis = at("Europe/Istanbul", 11, 5))
        assertSame(watchdog, AlarmTimeShift.shift(watchdog, istanbul, berlin, now))
    }
    @Test fun datedRecordThatFallsIntoPastIsDropped() {
        val soon = AlarmArgs("f", at("Europe/Istanbul", 10, 12, 30), "", "default", vibrate = true,
            snoozeEnabled = true, snoozeMinutes = 5, repeatHour = 12, repeatMinute = 30)
        // İstanbul 12:30 → Berlin'de 12:30, İstanbul saatiyle 13:30: gelecekte, kalır.
        assertNotNull(AlarmTimeShift.shift(soon, istanbul, berlin, now))
        // Ters yönde Berlin 12:30 → İstanbul 12:30 = Berlin 11:30: geçmişte, düşer.
        val berlinNow = at("Europe/Berlin", 10, 12)
        val berlinSoon = soon.copy(timeMillis = at("Europe/Berlin", 10, 12, 30))
        assertNull(AlarmTimeShift.shift(berlinSoon, berlin, istanbul, berlinNow))
    }
}
```

- [ ] **Step 2: `AlarmTimeShift.kt`**

```kotlin
package com.ekrembulbul.ezanvakti

import java.util.Calendar
import java.util.TimeZone

/** Saat dilimi değişince sabit saatli alarm kaydını yeni dilimde aynı duvar
 *  saatine taşır. Vakte bağlı kayıtlar ilçenin mutlak vaktine bağlıdır,
 *  nöbetçiler görev zincirine; ikisi de aynen döner. `null` = kayıt geçmişte
 *  kaldı, iptal edilmeli. */
object AlarmTimeShift {
    fun shift(args: AlarmArgs, from: TimeZone, to: TimeZone, now: Long): AlarmArgs? {
        val hour = args.repeatHour ?: return args
        if (args.isWatchdog || from.id == to.id) return args
        if (args.repeatWeekdays.isNotEmpty()) return AlarmRepeats.next(args, now, to) ?: args
        val old = Calendar.getInstance(from).apply { timeInMillis = args.timeMillis }
        val moved = Calendar.getInstance(to).apply {
            clear()
            set(old.get(Calendar.YEAR), old.get(Calendar.MONTH), old.get(Calendar.DAY_OF_MONTH),
                hour, args.repeatMinute ?: 0, 0)
        }
        return if (moved.timeInMillis > now) args.copy(timeMillis = moved.timeInMillis) else null
    }
}
```

- [ ] **Step 3: `AlarmScheduling`** — `PREFS` tercihine:

```kotlin
    private const val KEY_ZONE = "last_zone_id"

    /** Saat dilimi değişiminde eski dilimi bilmek için son görülen dilim. */
    fun rememberZone(context: Context, zone: TimeZone = TimeZone.getDefault()) {
        prefs(context).edit().putString(KEY_ZONE, zone.id).apply()
    }

    fun rememberedZone(context: Context): TimeZone? =
        prefs(context).getString(KEY_ZONE, null)?.let { TimeZone.getTimeZone(it) }
```
`reconcile(...)` sonunda `rememberZone(context)`.

- [ ] **Step 4: `AlarmBootReceiver`**

```kotlin
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            // İzin kapatılınca Android uygulamanın bütün kesin alarmlarını
            // siler; yeniden verilince açılıştaki gibi kurulur.
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
            -> {
                rescheduleFutureAlarms(context, recoverMissions = true)
                AlarmScheduling.rememberZone(context)
            }
            // Saat elle değişti: OS kayıtları duruyor; yalnız sıradaki anlar tazelenir.
            Intent.ACTION_TIME_CHANGED -> rescheduleFutureAlarms(context, recoverMissions = false)
            Intent.ACTION_TIMEZONE_CHANGED -> shiftForTimeZone(context, intent)
        }
        QuietModeController.reapply(context)
    }

    private fun shiftForTimeZone(context: Context, intent: Intent) {
        val to = intent.getStringExtra("time-zone")?.let { TimeZone.getTimeZone(it) } ?: TimeZone.getDefault()
        val from = AlarmScheduling.rememberedZone(context)
        AlarmScheduling.rememberZone(context, to)
        if (from == null || from.id == to.id) return
        val now = System.currentTimeMillis()
        for (args in AlarmScheduling.allArgs(context)) {
            try {
                val shifted = AlarmTimeShift.shift(args, from, to, now)
                when {
                    shifted == null -> AlarmScheduling.cancel(context, args.id)
                    shifted != args -> AlarmScheduling.schedule(context, shifted)
                }
            } catch (error: Exception) {
                AlarmJournal(context).record("timezone_shift", args, result = "failed", error = error)
            }
        }
    }
```
`rescheduleFutureAlarms(context: Context, recoverMissions: Boolean)`: mevcut gövde; ikinci `for (previous in missions.pendingSessions())` döngüsü yalnız `recoverMissions` iken çalışır (saat değişiminde OS nöbetçileri duruyor; kurtarma yeni kimlikle ikinci zamanlayıcı kurardı). Dosya dokümanını yeni yayınlarla güncelle. (`import android.app.AlarmManager`, `java.util.TimeZone`.)

- [ ] **Step 5: Çalıştır (Task 12):** `./gradlew testDebugUnitTest --tests '*AlarmTimeShiftTest'` → PASS

---

### Task 12: Entegrasyon, doğrulama, dokümanlar, commit'ler (ana oturum)

**Files:**
- Modify: `docs/adr/0003-platform-alarm-models.md`, `docs/adr/0005-notification-scheduling.md`
- Modify: `docs/superpowers/specs/2026-10-08-android-tur1-design.md` (pusula yok metni)

- [ ] **Step 1:** Agent raporlarını oku; `git status --short` dosyalarını dispatch kümeleriyle karşılaştır; Opus high parçasının (Task 7) dosyalarını tam oku.
- [ ] **Step 2:** `flutter gen-l10n && dart format lib test && flutter analyze` → "No issues found!"
- [ ] **Step 3:** `flutter test` → tümü PASS
- [ ] **Step 4:** `cd android && ./gradlew testDebugUnitTest` → PASS
- [ ] **Step 5:** `flutter build apk --debug` → başarılı; Kotlin uyarılarında `NewApi` yok
- [ ] **Step 6:** Emülatör (API 36): uygulama açılır; Ayarlar > Uygulamalar > Ezan Vakti > Bildirimler'de üç bildirim kanalı; Dil satırı (tr/en/ar); temalı ikon; kıble ekranı açılır ve yön ya da "pusula yok" metni gösterir; sekmede geri → ana sekme, ana sekmede geri → çıkış; `adb shell am start -n com.ekrembulbul.ezanvakti/.AlarmRingActivity` benzeri yolla değil, 1 dk sonraya kurulan alarmla çalar ekranı: geri hareketi kapatmaz, ses tuşları sesi değiştirmez, ekran sistem çubuklarının altına taşmaz; tablet profili (≥600dp) yatay düzen.
- [ ] **Step 7:** ADR 0003'e Android satırları (ses seviyesi kilidi, çalma süresi → erteleme/durdurma yolu, kaçırılan alarm bildirimi, dilim kaydırma) ve ADR 0005'e (ses başına kanal, telefon susturma planı ve sınırlı ufku) ekle; spec'teki "mevcut pusula kullanılamıyor durumu" cümlesini "yeni 'pusula yok' metni" olarak düzelt. `git diff --check`.
- [ ] **Step 8:** Mantıksal commit'ler (`dev`), sırayla: ortak kaynaklar + device köprüsü; bildirim kanalları; kıble pusulası; sessiz pencere/telefon susturma (Dart + Kotlin); alarm ses seviyesi + çalma süresi + kaçırılan alarm; izin uyarıları; saat dilimi yeniden kurma; dokümanlar. Her commit Türkçe Conventional Commit, sonunda `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
