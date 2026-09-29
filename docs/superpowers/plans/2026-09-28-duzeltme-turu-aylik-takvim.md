# Düzeltme Turu ve Aylık Vakit Takvimi — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** "Yalnızca bu sefer" sonrası sıralama hatası ve widget'taki siyah kerahat ikonu düzelir; ana ekrandaki Sıradaki kartı kalkar; dört listede kaydırarak silme yerini düzenleme ekranındaki Sil düğmesine ve basılı tutma menüsüne bırakır; Vakit Takvimi ay ay gezilir.

**Architecture:** Sıralama anahtarı atlamalı saf çözücülerden gelir, satırlar atlamasız örneği göstermeye devam eder. Silme iki ortak parça üzerine kurulur (`showRowActionsSheet`, `DeleteActionButton`); düzenleme ekranları isteğe bağlı `onDelete` alır, dönüş türleri değişmez. Takvim, imsakiyenin yükleyici + controller + paylaşım tablosu kalıbını izler ve vakti yalnız `PrayerTimesRepository` üzerinden okur (ADR 0004); planlama pencereleri değişmez.

**Tech Stack:** Flutter/Dart, Provider, intl; SwiftUI/WidgetKit (RunnerTests).

**Spec:** `docs/superpowers/specs/2026-09-28-duzeltme-turu-aylik-takvim-design.md`

## Global Constraints

- Kullanıcıya görünen metin Dart'a sabit yazılmaz; kaynak `lib/l10n/app_tr.arb`, karşılıkları `app_en.arb` ve `app_ar.arb`; ARB değişikliğinden sonra `flutter gen-l10n`. Üretilen `app_localizations*.dart` elle düzenlenmez.
- Renk ve tipografi `lib/core/theme/` token'ları ve `AppTypography` üzerinden; silme rengi `Theme.of(context).colorScheme.error`.
- Kod ve identifier İngilizce; kod yorumları Türkçe (mevcut dosyaların dili).
- `dart format` yalnız değiştirilen dosyalara (formatter dokunulmamış 47 dosyayı değiştiriyor).
- Silmede onay sorulmaz; geri alma "Geri al" çubuğuyla (proje standardı).
- Bildirim/alarm planlaması, widget snapshot'ı ve `AppState.prayerTimes` penceresi (30 gün) değişmez; takvim yalnız okur.
- Takvim aralığı: bu yılın Ocak'ı – gelecek yılın Aralık'ı.
- Commit'ler `dev` üzerinde, Türkçe Conventional Commit, sonunda `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; push yok.
- Her task kendi testleriyle kapanır; son task'ta `flutter analyze`, tam `flutter test`, `flutter build apk --debug`, `FLUTTER_XCODE_ARCHS=arm64 flutter build ios --simulator --debug`, `RunnerTests`.

## Review Focus

- **Art arda iki dokunuş:** Menüdeki "Sil"e ya da düzenleme ekranındaki sil düğmesine hızlıca iki kez basmak alttaki listeyi de kapatmamalı, silme bir kez çalışmalı → Task 4 (menü) ve Task 5–8 (düzenleme ekranları, sessiz aralık paneli) testlerinde ikinci dokunuş.
- **Ay sonunda açılış:** Bugün ayın son günlerindeyken takvim içerik sonuna kısıtlanmış konumda ve geri yaylanmadan açılmalı → Task 12 "ay sonuna yakın bugün" testi (iOS varyantı).
- **Yıl sınırı:** Aralık'tan ileri gidince gelecek yılın Ocak'ı yüklenmeli; bu yılın Ocak'ında geri, gelecek yılın Aralık'ında ileri ok pasif olmalı → Task 11 ve Task 14 sınır testleri.
- **Takvim açıkken kaynak değişimi:** Konum ya da vakit düzeltmesi değişince eski konumun/düzeltmenin tablosu görünmemeli; hızlı ok basışlarında yalnız son ayın yanıtı uygulanmalı → Task 11 "kaynak değişimi" ve "hızlı geçiş" testleri.
- **Dar ekran, büyük metin, RTL:** Arapça, %200 metin ve 320 pt genişlikte ay çubuğu taşmamalı, "önceki ay" sağda durmalı → Task 14 RTL testi.

---

## Dosya haritası (özet; ayrıntı her fazın başında)

| Faz | Dosyalar |
|---|---|
| 1 | `presentation/services/upcoming_resolver.dart`, `presentation/screens/reminders_screen.dart` (sıralama), `presentation/screens/home_screen.dart`, `presentation/pages/home_page.dart` (kart bağlaması), `presentation/widgets/home/upcoming_card.dart` (silinir), `ios/EzanVaktiWidget/Views/KerahatRibbon.swift`, ARB (`upcoming*` silinir) |
| 2 | `widgets/common/row_actions_sheet.dart` (yeni), `widgets/common/delete_action_button.dart` (yeni), `widgets/common/grouped_list.dart`, `widgets/reminders/alarms_section.dart`, `screens/alarm_edit_screen.dart`, `widgets/reminders/notifications_section.dart`, `widgets/notifications/notification_tile.dart`, `screens/notification_edit_screen.dart`, `screens/reminders_screen.dart` (düzenleme ekranı bağlaması), `screens/location_list_screen.dart`, `screens/location_edit_screen.dart`, `screens/quiet_windows_screen.dart`, `widgets/common/swipe_to_delete.dart` (silinir), ARB |
| 3 | `features/prayer_times/domain/calendar_month_repository.dart` (yeni), `presentation/controllers/calendar_month_controller.dart` (yeni), `widgets/calendar/calendar_table.dart`, `widgets/calendar/calendar_month_share_table.dart` (yeni), `screens/calendar_screen.dart`, `pages/home_page.dart` (takvim bağlaması), `services/calendar_share_service.dart`, ARB |
| 4 | `docs/adr/0003-platform-alarm-models.md`, `docs/ROADMAP.md` |

Yürütme sırası: Task 1 → 16. Fazlar arasında ortak dosyalar (`reminders_screen.dart`, `home_page.dart`, `upcoming_resolver.dart`, ARB'ler) farklı bölgelerden düzenlenir; satır numaraları önceki task'lardan sonra kayar, düzenleme yerini alıntılanan koda göre bul.

---

## Faz 1 — Hata düzeltmeleri ve kaldırma

### Task 1: "Sıradaki çalışa göre" sıralama atlamayı hesaba katar

**Files:**
- Modify: `lib/presentation/services/upcoming_resolver.dart:66-106` (`resolveNextOccurrencePerNotification`), dosya sonuna yeni fonksiyon
- Modify: `lib/presentation/screens/reminders_screen.dart:912-948` (`_buildBody` içindeki iki `sortReminderItems` çağrısı)
- Test: `test/presentation/upcoming_resolver_test.dart` (iki yeni grup)
- Test: `test/widgets/screens/reminders_screen_test.dart` (hatanın yeniden üretimi)

**Interfaces:**
- Produces:
  - `Map<String, UpcomingNotification> resolveNextOccurrencePerNotification({required List<NotificationSetting> settings, required List<PrayerTime> prayerTimes, required DateTime now, Set<SkippedOccurrence> skips = const {}})` — `skips` boşsa davranış aynen; doluysa atlanmış örnek geçilir.
  - `Map<String, DateTime> resolveEffectiveNextFirePerAlarm({required List<Alarm> alarms, required List<PrayerTime> prayerTimes, required DateTime now, List<MissionSession> missionSessions = const [], Set<SkippedOccurrence> skips = const {}})` — yalnız açık alarmlar; ertelenmişte erteleme bitişi, değilse atlama uygulanmış `AlarmScheduler.computeNextFire`.
- Consumes: `AlarmScheduler.computeNextFire(..., skips:)` (`alarm_scheduler.dart:310`), `isSkipped` (`features/notifications/domain/skip_rules.dart`), `NotificationScheduler.notificationIdFor` / `pointIndexOf`.

- [ ] **Step 1: Resolver testlerini yaz (önce kırmızı)**

`test/presentation/upcoming_resolver_test.dart` import listesine ekle:

```dart
import 'package:ezanvakti/core/models/mission_session.dart';
```

`main()` içinde, `group('notificationOccurrence', ...)` bloğundan hemen önce şu iki grubu ekle:

```dart
  group('resolveNextOccurrencePerNotification — atlama', () {
    const maghrib = NotificationSetting(
      prayerType: PrayerType.maghrib,
      isActive: true,
    );
    final now = DateTime(2026, 8, 3, 18);

    test('atlama verilmezse atlanmamış örnek döner', () {
      final next = resolveNextOccurrencePerNotification(
        settings: const [maghrib],
        prayerTimes: _window,
        now: now,
      )[notificationKey(maghrib)];

      expect(next?.time, DateTime(2026, 8, 3, 20, 25));
    });

    test('atlanan örnek geçilir, sıradaki gün gelir', () {
      final first = resolveNextOccurrencePerNotification(
        settings: const [maghrib],
        prayerTimes: _window,
        now: now,
      )[notificationKey(maghrib)]!;

      final next = resolveNextOccurrencePerNotification(
        settings: const [maghrib],
        prayerTimes: _window,
        now: now,
        skips: {notificationOccurrence(first)},
      )[notificationKey(maghrib)];

      expect(next?.time, DateTime(2026, 8, 4, 20, 25));
      expect(next?.prayerDate, DateTime(2026, 8, 4));
    });
  });

  group('resolveEffectiveNextFirePerAlarm', () {
    const fixed = Alarm(
      id: 'fixed',
      kind: AlarmKind.fixed,
      label: 'Sabah',
      hour: 6,
      minute: 30,
    );
    const anchored = Alarm(
      id: 'anchored',
      kind: AlarmKind.anchored,
      label: 'Sahur',
      anchor: PrayerType.fajr,
      offsetMinutes: -30,
    );

    test('her açık alarmın sıradaki çalışı', () {
      final result = resolveEffectiveNextFirePerAlarm(
        alarms: const [fixed, anchored],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 23),
      );

      // Sahur: 4 Ağustos İmsak 04:11 − 30 dk = 03:41.
      expect(result, {
        'fixed': DateTime(2026, 8, 4, 6, 30),
        'anchored': DateTime(2026, 8, 4, 3, 41),
      });
    });

    test('atlanan çalış geçilir', () {
      final result = resolveEffectiveNextFirePerAlarm(
        alarms: const [fixed],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 23),
        skips: {
          SkippedOccurrence(
            kind: SkipKind.alarm,
            reference: 'fixed',
            fireAt: DateTime(2026, 8, 4, 6, 30),
          ),
        },
      );

      expect(result['fixed'], DateTime(2026, 8, 5, 6, 30));
    });

    test('ertelenmiş alarm erteleme bitişini alır', () {
      final result = resolveEffectiveNextFirePerAlarm(
        alarms: const [fixed],
        prayerTimes: _window,
        now: DateTime(2026, 8, 4, 6, 32),
        missionSessions: [
          MissionSession(
            alarmId: 'fixed',
            firedAt: DateTime(2026, 8, 4, 6, 30),
            snoozedUntil: DateTime(2026, 8, 4, 6, 40),
          ),
        ],
      );

      expect(result['fixed'], DateTime(2026, 8, 4, 6, 40));
    });

    test('kapalı alarmın anahtarı yok', () {
      final result = resolveEffectiveNextFirePerAlarm(
        alarms: const [
          fixed,
          Alarm(id: 'off', kind: AlarmKind.fixed, isActive: false),
        ],
        prayerTimes: _window,
        now: DateTime(2026, 8, 3, 23),
      );

      expect(result.keys, ['fixed']);
    });
  });
```

- [ ] **Step 2: Koş, kırmızıyı gör**

Run: `flutter test test/presentation/upcoming_resolver_test.dart`
Expected: FAIL — derleme hatası: `No named parameter with the name 'skips'` ve `resolveEffectiveNextFirePerAlarm` tanımsız.

- [ ] **Step 3: Resolver'ı uygula**

`lib/presentation/services/upcoming_resolver.dart` import listesine ekle:

```dart
import '../../features/notifications/domain/skip_rules.dart';
```

`resolveNextOccurrencePerNotification`'ın doc yorumunu ve imzasını şununla değiştir (gövdenin başı aynı kalır):

```dart
/// Her aktif ayarın sıradaki örneği, kaynak vakit günüyle birlikte.
///
/// Gün filtresi ve türetilmiş vakit hesabı planlayıcıyla aynıdır. Kaynak gün,
/// gece noktalarında ve önceki güne taşan sapmalarda atlama kimliğini korur.
/// [skips] boşken atlanmış örnek de döner: satır ve "Yalnızca bu sefer" tam
/// o örneği gösterir. Sıralama anahtarı için [skips] verilir; atlanan örnek
/// planlayıcıyla aynı kimlikle (`notificationIdFor`) geçilir.
Map<String, UpcomingNotification> resolveNextOccurrencePerNotification({
  required List<NotificationSetting> settings,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
  Set<SkippedOccurrence> skips = const {},
}) {
```

Aynı fonksiyonun döngüsünde `if (!fireAt.isAfter(now)) continue;` satırının hemen altına ekle:

```dart
      if (skips.isNotEmpty &&
          isSkipped(
            skips,
            kind: SkipKind.notification,
            reference: NotificationScheduler.notificationIdFor(
              date: day.date,
              pointIndex: NotificationScheduler.pointIndexOf(setting),
              minutesBefore: setting.minutesBefore,
            ),
            fireAt: fireAt,
          )) {
        continue;
      }
```

Dosyanın sonuna ekle:

```dart
/// Her açık alarmın **gerçekten** çalacağı sıradaki an: atlanan çalış geçilir,
/// ertelenmiş alarm erteleme bitişini alır.
///
/// Yalnız "Sıradaki çalışa göre" sıralamanın anahtarıdır. Satırın gösterdiği
/// ve atlamanın uygulandığı örnek atlama uygulanmadan hesaplanır; kullanıcı
/// tam da o örneği atlıyor ya da geri alıyor. Kapalı alarmın anahtarı yoktur,
/// liste sonuna düşer.
Map<String, DateTime> resolveEffectiveNextFirePerAlarm({
  required List<Alarm> alarms,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
  List<MissionSession> missionSessions = const [],
  Set<SkippedOccurrence> skips = const {},
}) {
  final byDate = <DateTime, PrayerTime>{
    for (final day in prayerTimes)
      DateTime(day.date.year, day.date.month, day.date.day): day,
  };
  final result = <String, DateTime>{};
  for (final alarm in alarms) {
    if (!alarm.isActive) continue;
    final snoozedUntil = MissionSession.pendingForAlarm(
      missionSessions,
      alarm.id,
    )?.snoozedUntil;
    final fire = snoozedUntil?.isAfter(now) == true
        ? snoozedUntil
        : AlarmScheduler.computeNextFire(
            alarm: alarm,
            now: now,
            prayerTimesByDate: byDate,
            skips: skips,
          );
    if (fire != null) result[alarm.id] = fire;
  }
  return result;
}
```

- [ ] **Step 4: Koş, yeşili gör**

Run: `flutter test test/presentation/upcoming_resolver_test.dart`
Expected: PASS (mevcut testler dahil).

- [ ] **Step 5: Ekran testini yaz (hatanın yeniden üretimi, önce kırmızı)**

`test/widgets/screens/reminders_screen_test.dart` içinde `testWidgets('Alarm kapatilinca "Yalnizca bu sefer" teklif edilir', ...)` testinin hemen altına ekle (`reminder_list_preferences.dart` zaten import'lu):

```dart
  testWidgets(
    '"Sıradaki çalışa göre" sıralamada "Yalnızca bu sefer" alarmı en üste taşımaz',
    (tester) async {
      // Saatler şimdiden türetilir: alfa her zaman betadan önce çalar ve
      // alfanın bir sonraki gerçek çalışı (ertesi gün) betadan sonraya düşer.
      final now = DateTime.now();
      final alfaAt = now.add(const Duration(hours: 2));
      final betaAt = now.add(const Duration(hours: 3));
      final alfa = Alarm(
        id: 'alfa',
        kind: AlarmKind.fixed,
        label: 'Alfa',
        hour: alfaAt.hour,
        minute: alfaAt.minute,
      );
      final beta = Alarm(
        id: 'beta',
        kind: AlarmKind.fixed,
        label: 'Beta',
        hour: betaAt.hour,
        minute: betaAt.minute,
      );
      await storage.saveAlarm(alfa);
      await storage.saveAlarm(beta);
      appState.setAlarms([alfa, beta]);
      await ReminderListPreferencesStore(storage: storage).save(
        ReminderListKind.alarms,
        const ReminderListPreferences(sortMode: ReminderSortMode.nextFire),
      );
      await pump(tester);

      double top(String label) => tester.getTopLeft(find.text(label)).dy;
      expect(top('Alfa'), lessThan(top('Beta')), reason: 'önce alfa çalar');

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yalnızca bu sefer'));
      await tester.pumpAndSettle();

      expect(appState.skips, hasLength(1));
      expect(
        top('Beta'),
        lessThan(top('Alfa')),
        reason: 'alfanın sıradaki gerçek çalışı ertesi gün; beta önce çalar',
      );
    },
  );
```

- [ ] **Step 6: Koş, kırmızıyı gör**

Run: `flutter test test/widgets/screens/reminders_screen_test.dart --plain-name 'Yalnızca bu sefer" alarmı en üste taşımaz'`
Expected: FAIL — son `expect`: alfa yine betanın üstünde (sıralama atlanan çalışa bakıyor).

- [ ] **Step 7: Ekranın sıralama anahtarlarını değiştir**

`lib/presentation/screens/reminders_screen.dart` `_buildBody` içinde `final nextAlarmTimes = _nextFireByAlarm(appState, now: now);` satırının altına ekle:

```dart
        // Sıralama bir sonraki *gerçek* çalışa göre: atlanan örnek geçilir.
        // Satırlar ve atlama arayüzü atlamasız örneği göstermeye devam eder.
        final sortFireByAlarm = resolveEffectiveNextFirePerAlarm(
          alarms: appState.alarms,
          prayerTimes: appState.prayerTimes,
          now: now,
          missionSessions: appState.missionSessions,
          skips: appState.skips,
        );
        final sortOccurrences = resolveNextOccurrencePerNotification(
          settings: appState.notificationSettings,
          prayerTimes: appState.prayerTimes,
          now: now,
          skips: appState.skips,
        );
```

Alarm sıralamasındaki

```dart
          nextFireOf: (alarm) =>
              alarm.isActive ? nextAlarmTimes[alarm.id] : null,
```

bloğunu şununla değiştir:

```dart
          nextFireOf: (alarm) => sortFireByAlarm[alarm.id],
```

Bildirim sıralamasındaki

```dart
          nextFireOf: (setting) => occurrences[notificationKey(setting)]?.time,
```

satırını şununla değiştir:

```dart
          nextFireOf: (setting) =>
              sortOccurrences[notificationKey(setting)]?.time,
```

- [ ] **Step 8: Koş, yeşili gör**

Run: `flutter test test/widgets/screens/reminders_screen_test.dart test/presentation/upcoming_resolver_test.dart test/presentation/reminder_list_preferences_test.dart`
Expected: PASS.

- [ ] **Step 9: Biçimle ve commit'le**

```bash
dart format lib/presentation/services/upcoming_resolver.dart lib/presentation/screens/reminders_screen.dart test/presentation/upcoming_resolver_test.dart test/widgets/screens/reminders_screen_test.dart
git add lib/presentation/services/upcoming_resolver.dart lib/presentation/screens/reminders_screen.dart test/presentation/upcoming_resolver_test.dart test/widgets/screens/reminders_screen_test.dart
git commit -m "$(cat <<'EOF'
fix: tek seferlik atlanan hatırlatıcı sıralamada en üste çıkmasın

"Sıradaki çalışa göre" sıralama atlamayı yok sayıyordu: kapatılıp
"Yalnızca bu sefer" ile yeniden açılan alarm, atlanacak çalışının
anına göre en üste diziliyordu. Sıralama anahtarı artık atlanan
örneği geçiyor; satır ve atlama arayüzü atlamasız örneği göstermeye
devam ediyor. Bildirimlerde de aynı düzeltme.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Ana ekrandan "Sıradaki" kartını kaldır

Bu task davranış kaldırıyor; kırmızı adımı yok. Doğrulama: derleme, güncellenen testler ve `flutter analyze`.

**Files:**
- Delete: `lib/presentation/widgets/home/upcoming_card.dart`, `test/widgets/home/upcoming_card_test.dart`
- Modify: `lib/presentation/screens/home_screen.dart:1-99,225-255`
- Modify: `lib/presentation/pages/home_page.dart:18,490-515,670-693`
- Modify: `lib/presentation/services/upcoming_resolver.dart:11-64,126-174`
- Modify: `lib/l10n/app_tr.arb`, `app_en.arb`, `app_ar.arb` (`upcomingTitle`, `upcomingAll`, `upcomingEmpty` silinir)
- Test: `test/presentation/upcoming_resolver_test.dart`, `test/widgets/home/home_screen_test.dart:260-281`, `test/widgets/home/home_scroll_test.dart`

**Interfaces:**
- Consumes: Task 1'in `resolveEffectiveNextFirePerAlarm` fonksiyonu (dosyadaki `Alarm`, `MissionSession`, `AlarmScheduler` import'ları onun için kalır).
- Produces: `HomeScreen` kurucusu artık şu özellikleri almaz: `missionSessions`, `prayerTimes`, `notificationSettings`, `alarms`, `alarmsSupported`, `skips`, `onSkipChanged`, `onSnoozedTap`, `onSeeReminders`. `upcoming_resolver.dart`'ta `resolveNextNotification`, `resolveNextFirePerNotification`, `UpcomingAlarm`, `resolveNextAlarm` yok; `UpcomingNotification`, `resolveNextOccurrencePerNotification`, `notificationKey`, `notificationOccurrence`, `resolveEffectiveNextFirePerAlarm` kalır.

- [ ] **Step 1: Resolver testlerini kalan API'ye çevir**

`test/presentation/upcoming_resolver_test.dart` içinde `final _window = ...` satırının altına şu yardımcıyı ekle:

```dart
/// Ana ekran kartı kalktı; en yakın örneği testte seçiyoruz ki satır başına
/// örnek hesabının kuralları (gün filtresi, Cuma önceliği, türetilmiş
/// vakitler) sınanmaya devam etsin. Eşitlikte ilk gelen kazanır — sonuç
/// haritası gün kısıtlı satırları önce ekliyor.
UpcomingNotification? _earliest({
  required List<NotificationSetting> settings,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
}) {
  UpcomingNotification? earliest;
  for (final occurrence in resolveNextOccurrencePerNotification(
    settings: settings,
    prayerTimes: prayerTimes,
    now: now,
  ).values) {
    if (earliest == null || occurrence.time.isBefore(earliest.time)) {
      earliest = occurrence;
    }
  }
  return earliest;
}

Map<String, DateTime> _fireTimes({
  required List<NotificationSetting> settings,
  required List<PrayerTime> prayerTimes,
  required DateTime now,
}) => resolveNextOccurrencePerNotification(
  settings: settings,
  prayerTimes: prayerTimes,
  now: now,
).map((key, occurrence) => MapEntry(key, occurrence.time));
```

Sonra:
- `group('resolveNextNotification', () {` satırını `group('resolveNextOccurrencePerNotification — en yakın örnek', () {` yap ve grup içindeki her `resolveNextNotification(` çağrısını `_earliest(` ile değiştir (argümanlar aynı).
- `group('resolveNextFirePerNotification', () {` satırını `group('resolveNextOccurrencePerNotification — satır başına an', () {` yap ve grup içindeki her `resolveNextFirePerNotification(` çağrısını `_fireTimes(` ile değiştir.
- `group('resolveNextAlarm', ...)` ve `group('resolveNextAlarm — platform destegi', ...)` gruplarını tamamen sil (Task 1'deki `resolveEffectiveNextFirePerAlarm` grubu alarm hesabını sınıyor; platform desteği yalnız kartın kuralıydı).

- [ ] **Step 2: Ana ekran testlerini kartsız hâle getir**

`test/widgets/home/home_screen_test.dart` içindeki son testi (`'Alarm destegi yoksa Siradaki karti alarm gostermez'`) tamamen sil. Dosyada `Alarm` artık kullanılmıyorsa `package:ezanvakti/core/models/alarm.dart` import'unu da sil.

`test/widgets/home/home_scroll_test.dart` içinde:
- `import 'package:ezanvakti/presentation/widgets/home/upcoming_card.dart';` satırını `import 'package:ezanvakti/presentation/widgets/home/prayer_grid.dart';` ile değiştir; `alarm.dart` ve `notification_setting.dart` import'larını sil.
- `_pumpHome`'dan `bool hasReminders = false,` parametresini ve `HomeScreen(...)` çağrısındaki `prayerTimes:`, `alarms:`, `notificationSettings:` argümanlarını sil.
- `'taşan içerik yukarı kayar, ...'` testinde `_pumpHome(tester, size: const Size(360, 520), hasReminders: true)` çağrısını `_pumpHome(tester, size: const Size(360, 420))` yap (kart kalkınca 520 pt yükseklik taşmayabilir) ve iki `find.byType(UpcomingCard)` ifadesini `find.byType(PrayerGrid)` yap.
- `'... dar ekranda yüzde 200 metinle tüm içeriğe kaydırılır'` testinde `hasReminders: true,` argümanını sil ve iki `find.text(...hazırlığı).hitTestable()` beklentisini şununla değiştir:

```dart
        expect(find.byType(PrayerGrid).hitTestable(), findsOneWidget);
```

- [ ] **Step 3: Kartı ve bağlamasını kaldır**

`lib/presentation/screens/home_screen.dart`:
- `import '../widgets/home/upcoming_card.dart';`, `import '../services/upcoming_resolver.dart';`, `import '../../core/models/mission_session.dart';`, `import '../../core/models/alarm.dart';`, `import '../../core/models/skipped_occurrence.dart';` satırlarını sil. `notification_setting.dart` import'unu yalnız analiz kullanılmıyor derse sil.
- Sınıftan şu alanları doc yorumlarıyla birlikte sil: `onSeeReminders`, `prayerTimes`, `notificationSettings`, `alarms`, `alarmsSupported`, `skips`, `missionSessions`, `onSkipChanged`, `onSnoozedTap`; kurucudan karşılıkları: `this.missionSessions = const [],`, `this.onSeeReminders,`, `this.prayerTimes = const [],`, `this.notificationSettings = const [],`, `this.alarms = const [],`, `this.alarmsSupported = true,`, `this.skips = const {},`, `this.onSkipChanged,`, `this.onSnoozedTap,`.
- `_buildBody` sonundaki

```dart
          const SizedBox(height: 24),
          UpcomingCard(
            ...
          ),
          const SizedBox(height: 20),
```

bloğunu (UpcomingCard'ın tamamı ve öncesindeki 24'lük boşluk) şununla değiştir:

```dart
          const SizedBox(height: 20),
```

`lib/presentation/pages/home_page.dart`:
- `HomeScreen(` çağrısından şu argümanları sil: `missionSessions:`, `prayerTimes:`, `notificationSettings:`, `alarms:`, `alarmsSupported:`, `skips:`, `onSkipChanged: _toggleSkip,`, `onSnoozedTap: ...`, `onSeeReminders: ...`.
- `/// "SIRADAKİ" kartındaki tek seferlik kapatma.` ile başlayan doc yorumu ve `_toggleSkip` metodunu tamamen sil.
- `import '../../core/models/skipped_occurrence.dart';` satırını sil. `mission_launcher.dart` ve `reminder_rescheduler.dart` import'larını yalnız `flutter analyze` kullanılmıyor derse sil.

`lib/presentation/services/upcoming_resolver.dart`:
- `UpcomingNotification` typedef'inin doc yorumunu şununla değiştir:

```dart
/// Bir bildirim ayarının sıradaki örneği.
///
/// [prayerDate] vaktin günü — [time] ise tetiklenme anı. Sapmalı bildirimde
/// ikisi farklı güne düşebilir; atlama kimliği **vaktin gününden** üretildiği
/// için (planlayıcıyla aynı kural) ayrıca taşınır.
```

- `UpcomingAlarm` typedef'ini ve doc yorumunu, `resolveNextNotification` ve `resolveNextFirePerNotification` fonksiyonlarını doc yorumlarıyla, `resolveNextAlarm` fonksiyonunu doc yorumuyla sil.

`lib/presentation/widgets/home/upcoming_card.dart` ve `test/widgets/home/upcoming_card_test.dart` dosyalarını sil:

```bash
git rm lib/presentation/widgets/home/upcoming_card.dart test/widgets/home/upcoming_card_test.dart
```

- [ ] **Step 4: Kartın metinlerini ARB'den sil**

`lib/l10n/app_tr.arb`: `"upcomingTitle"`, `"upcomingAll"`, `"upcomingEmpty"` anahtarlarını ve `"@upcomingTitle"`, `"@upcomingAll"`, `"@upcomingEmpty"` bloklarını sil. `app_en.arb` ve `app_ar.arb`: üç anahtar satırını (296-298) sil. Önce başka kullanım olmadığını doğrula:

Run: `grep -rn "upcomingTitle\|upcomingAll\|upcomingEmpty" lib test | grep -v "lib/l10n/"`
Expected: çıktı yok.

Run: `flutter gen-l10n`
Expected: hatasız.

- [ ] **Step 5: Analiz ve testler**

Run: `flutter analyze`
Expected: `No issues found!` (kullanılmayan import uyarısı çıkarsa o import'u sil ve tekrar koş).

Run: `flutter test test/presentation/upcoming_resolver_test.dart test/widgets/home test/widgets/screens/home_page_nav_test.dart`
Expected: PASS.

- [ ] **Step 6: Biçimle ve commit'le**

```bash
dart format lib/presentation/screens/home_screen.dart lib/presentation/pages/home_page.dart lib/presentation/services/upcoming_resolver.dart test/presentation/upcoming_resolver_test.dart test/widgets/home/home_screen_test.dart test/widgets/home/home_scroll_test.dart
git add -A lib/presentation/screens/home_screen.dart lib/presentation/pages/home_page.dart lib/presentation/services/upcoming_resolver.dart lib/presentation/widgets/home/upcoming_card.dart lib/l10n test/presentation/upcoming_resolver_test.dart test/widgets/home
git commit -m "$(cat <<'EOF'
feat(ana-ekran): Sıradaki kartını kaldır

Ana ekrandaki yaklaşan bildirim ve alarm kartı, atlama anahtarı ve
erteleme rozetiyle birlikte kalktı; sayfa vakit ızgarasıyla bitiyor.
Tek seferlik atlama ve erteleme Hatırlatıcılar ekranında aynen sürüyor.
Kartın kullandığı çözücüler ve metinler silindi; satır başına örnek
hesabının testleri korunarak kalan API'ye taşındı.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Widget kerahat şeridinde ikon rengi

Görünüm değişikliği; XCTest widget çizimini doğrulayamıyor. Doğrulama: iOS derlemesi, `RunnerTests` ve cihaz (Ekrem).

**Files:**
- Modify: `ios/EzanVaktiWidget/Views/KerahatRibbon.swift:21-49`

**Interfaces:**
- Consumes: `KerahatRibbonLabel.text(labels:status:)`, `KerahatRibbonLabel.countdownTarget(status:)` (değişmez).
- Produces: yok (yalnız görünüm).

- [ ] **Step 1: Şeridi yeniden düzenle**

`KerahatRibbon` içindeki `private var countdown: Text { ... }` ve `var body: some View { ... }` bloklarını şununla değiştir (`height`, `fontSize`, `entry`, `status`, `palette`, `isActive`, `foreground` aynen kalır):

```swift
    /// Pencere 30 dk, aralıklar 45 dk altı: sayaç hep dk:sn. Sistem sayacı
    /// sunulan genişliği doldurup içeriğini sola yaslıyor (2026-09-15 cihaz
    /// gözlemi); en geniş hâlin ("00:00") görünmez kalıbı genişliği sabitler,
    /// sayaç onun üstünde ortalı durur ve üç parça birlikte ortalanır.
    private var countdown: some View {
        let target = KerahatRibbonLabel.countdownTarget(status: status)
        let font = Font.system(size: Self.fontSize, weight: .bold).monospacedDigit()
        return Text(verbatim: "00:00")
            .font(font)
            .hidden()
            .overlay {
                Text(timerInterval: min(entry.date, target)...target, countsDown: true)
                    .font(font)
                    .multilineTextAlignment(.center)
            }
    }

    var body: some View {
        // İkon ayrı çizilir ve rengi açıkça verilir: canlı sayaçla aynı `Text`
        // birleşimindeyken widget sembolü yazı rengine boyamıyor, ikon siyah
        // kalıyordu (0.23.0–0.27.1; 2026-09-28 cihaz gözlemi).
        HStack(spacing: 4) {
            Image(systemName: "sun.horizon")
                .font(.system(size: Self.fontSize, weight: .semibold))
                .foregroundStyle(foreground)
            Text(verbatim: KerahatRibbonLabel.text(labels: entry.labels, status: status))
                .font(.system(size: Self.fontSize, weight: .semibold))
            countdown
        }
        .foregroundStyle(foreground)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(isActive ? palette.kerahatLine : palette.kerahatSoonSurface)
        .overlay(alignment: .top) {
            if !isActive {
                palette.kerahatSoonLine.frame(height: 1)
            }
        }
    }
```

Dosyanın başındaki tip doc yorumundaki "ikon · kelime · sistem sayacı" cümlesi geçerli kalır; "Tek `Text`" açıklaması yoksa ekleme.

- [ ] **Step 2: iOS simülatör derlemesi**

Run: `FLUTTER_XCODE_ARCHS=arm64 flutter build ios --simulator --debug`
Expected: `✓ Built build/ios/iphonesimulator/Runner.app`.

- [ ] **Step 3: Native testler**

Run: `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RunnerTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ios/EzanVaktiWidget/Views/KerahatRibbon.swift
git commit -m "$(cat <<'EOF'
fix(widget): kerahat şeridindeki ikon koyu zeminde görünsün

İkon, ortalama için canlı sayaçla aynı metne alındığından beri widget
sembolü boyamıyor, ikon siyah kalıyordu. İkon yeniden ayrı çiziliyor
ve rengi açıkça veriliyor (yaklaşırken turuncu, kerahatte beyaz);
sayacın genişliği görünmez "00:00" kalıbıyla sabitlendiği için şerit
ortalı kalıyor.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

## Faz 2 — Silme (K4): kaydırma yerine basılı tutma menüsü ve düzenleme ekranında Sil

Spec: §2 B5–B7, §3.3, §4, §5, §8. Yürütme Faz 1'den sonra, takvim task'larından önce. Task'lar sırayla uygulanır (Task 4 → Task 9): Task 5–Task 8 aynı ARB dosyalarına ve Task 5/Task 6 aynı `reminders_screen.dart` / `reminders_screen_test.dart` dosyalarına dokunur. Her task tek başına yeşil kapanır ve ayrı commit'lenir.

Faz 1 `reminders_screen.dart` içinde `_buildBody`'deki sıralama bölgesini değiştirir; bu bölümün düzenlemeleri `_addOrEditAlarm` ve `_openNotificationEditor` fonksiyonlarındadır. Satır numaraları Faz 1'den sonra kayar: düzenleme yerini fonksiyon adına ve alıntılanan eski koda göre bul.

### Bölüme özgü kurallar

- Silme onay sormaz; geri alma listedeki "… silindi · Geri al" çubuğuyla (mevcut `_deleteAlarm`, `_deleteNotification`, `_deleteLocation` zaten böyle; sessiz aralık bu bölümde eklenir).
- Düzenleme ekranındaki düğme: **önce** `Navigator.pop` (sonuçsuz), **sonra** `onDelete()`. Çağıranların "sonuç yoksa çık" dalları buna uyar (doğrulandı: `_addOrEditAlarm` `if (result == null) return;`, `_openNotificationEditor` `if (draft == null || !mounted) return;`, `_editLocation` `if (!mounted || updated == null) return;`, sessiz aralık paneli `await showModalBottomSheet<void>` sonrası iş yapmıyor).
- Sıralama (reorder) kipinde basılı tutma kapalı; alarm satırı bugün böyle, bildirim satırı da uyar. Konum ve sessiz aralık listelerinde reorder kipi yok.
- Unit/widget testleri basılı tutmanın ve silmenin gerçek cihazda nasıl hissettirdiğini kanıtlamaz; cihaz kontrolü Ekrem'de (spec §8).

### Dosya haritası

| Dosya | Sorumluluk | Değişiklik |
|---|---|---|
| `lib/presentation/widgets/common/row_actions_sheet.dart` (yeni, Task 4) | basılı tutma alt sayfası | `showRowActionsSheet` |
| `lib/presentation/widgets/common/delete_action_button.dart` (yeni, Task 4) | düzenleme ekranı silme düğmesi | `DeleteActionButton` |
| `lib/presentation/widgets/common/grouped_list.dart` (Task 4) | liste satırı | `GroupedRow.onLongPress` |
| `lib/presentation/widgets/reminders/alarms_section.dart` (Task 5) | alarm listesi | `SwipeToDelete` kalkar; `_showRowMenu` ortak sayfaya; ipucu anahtarı |
| `lib/presentation/screens/alarm_edit_screen.dart` (Task 5) | alarm formu | `onDelete` + "Alarmı sil" |
| `lib/presentation/widgets/reminders/notifications_section.dart` (Task 6) | bildirim listesi | `SwipeToDelete` kalkar; silme tile'a iner; ipucu anahtarı |
| `lib/presentation/widgets/notifications/notification_tile.dart` (Task 6) | bildirim satırı | kullanılmayan `onDelete` alanı basılı tutma menüsüne bağlanır |
| `lib/presentation/screens/notification_edit_screen.dart` (Task 6) | bildirim formu | `onDelete` + "Bildirimi sil" |
| `lib/presentation/screens/reminders_screen.dart` (Task 5, Task 6) | bağlama | `_addOrEditAlarm` yalnız kayıtlı alarmda, `_openNotificationEditor` yalnız mevcut kayıtta `onDelete` geçirir |
| `lib/presentation/screens/location_list_screen.dart` (Task 7) | konum listesi | `SwipeToDelete` kalkar; aktif olmayan satırda menü; `_editLocation` `onDelete` geçirir; ipucu; `_loadLocations` initState düzeltmesi |
| `lib/presentation/screens/location_edit_screen.dart` (Task 7) | konum formu | `onDelete` + kartsız "Konumu sil" |
| `lib/presentation/screens/quiet_windows_screen.dart` (Task 8) | sessiz aralıklar | `SwipeToDelete` kalkar; özel satırda menü; panelde "Aralığı sil"; "Geri al" |
| `lib/presentation/widgets/common/swipe_to_delete.dart` (Task 9) | kaydırarak silme | silinir |
| `lib/l10n/app_{tr,en,ar}.arb` + `app_localizations*.dart` (Task 5–Task 8) | metinler | 3 anahtar yeniden adlandırılır, 5 anahtar eklenir |
| `test/widgets/common/row_actions_sheet_test.dart`, `test/widgets/common/delete_action_button_test.dart` (yeni, Task 4) | ortak parça testleri | — |
| `test/widgets/grouped_list_test.dart` (Task 4) | `GroupedRow` | basılı tutma testi |
| `test/widgets/notifications/alarms_section_test.dart` (Task 5), `test/widgets/screens/alarm_edit_screen_test.dart` (Task 5) | alarm | menü, reorder, düğme, pop sırası |
| `test/widgets/notifications/notifications_section_test.dart` (Task 6), `test/widgets/notifications/notification_edit_screen_test.dart` (Task 6) | bildirim | menü, reorder, düğme, pop sırası |
| `test/widgets/screens/reminders_screen_test.dart` (Task 5, Task 6) | ekran akışı | kaydırma testleri basılı tutmaya çevrilir; düzenleme ekranından silme + geri al |
| `test/widgets/screens/location_list_screen_test.dart`, `test/widgets/screens/location_edit_screen_test.dart` (Task 7) | konum | ekran testleri |
| `test/widgets/screens/quiet_windows_screen_test.dart` (yeni, Task 8) | sessiz aralık | menü, panelde sil, geri al |
| `test/widgets/screens/home_page_nav_test.dart` (Task 9) | sekme kaydırması | "satır swipe siler" testi yerine "satır üstünde yatay hareket sekmeyi değiştirir, silmez" |

### l10n anahtarları (bu bölüm)

| Anahtar | TR | EN | AR | Task |
|---|---|---|---|---|
| `alarmDeleteAction` | Alarmı sil | Delete alarm | حذف المنبه | Task 5 (yeni) |
| `alarmsLongPressHint` | Kopyalamak ya da silmek için satıra basılı tut. Silinen alarmı "Geri al" ile geri getirebilirsin. | Touch and hold a row to duplicate or delete it. Use "Undo" to restore a deleted alarm. | اضغط مطولاً على الصف لنسخ المنبه أو حذفه. استخدم «تراجع» لاستعادة المنبه المحذوف. | Task 5 (`alarmsSwipeHint` yerine) |
| `notificationDeleteAction` | Bildirimi sil | Delete notification | حذف التنبيه | Task 6 (yeni) |
| `remindersLongPressHint` | Silmek için satıra basılı tut. | Touch and hold a row to delete it. | اضغط مطولاً على الصف لحذفه. | Task 6 (`remindersSwipeToDelete` yerine) |
| `locationDeleteAction` | Konumu sil | Delete location | حذف الموقع | Task 7 (yeni) |
| `locationsLongPressHint` | Aktif olmayan konumu silmek için satıra basılı tut. | Touch and hold a row to delete a location that is not active. | اضغط مطولاً على الصف لحذف موقع غير نشط. | Task 7 (`locationsSwipeHint` yerine) |
| `quietWindowDeleteAction` | Aralığı sil | Delete window | حذف الفترة | Task 8 (yeni) |
| `quietWindowDeleted` | Sessiz aralık silindi | Quiet window deleted | تم حذف فترة الصمت | Task 8 (yeni) |

Menüdeki "Sil" ve "Kopyala" mevcut `actionDelete` ("Sil") ve `alarmDuplicate` ("Kopyala") anahtarlarını kullanır; "Geri al" mevcut `snackUndo`. `app_en.arb` ve `app_ar.arb` dosyalarında `@` açıklama blokları yok; yalnız `app_tr.arb`'ye yazılır.

---

### Task 4: Ortak parçalar — satır eylem sayfası, silme düğmesi, `GroupedRow.onLongPress`

**Files:**
- Create: `lib/presentation/widgets/common/row_actions_sheet.dart`
- Create: `lib/presentation/widgets/common/delete_action_button.dart`
- Modify: `lib/presentation/widgets/common/grouped_list.dart:62-181` (`GroupedRow` alanı, kurucusu, `build` sonu)
- Test: `test/widgets/common/row_actions_sheet_test.dart` (yeni)
- Test: `test/widgets/common/delete_action_button_test.dart` (yeni)
- Test: `test/widgets/grouped_list_test.dart` (`group('GroupedRow', ...)` içine bir test)

**Interfaces:**
- Consumes: `SectionLabel` (`section_label.dart`, metni kendisi `toTurkishUpperCase` ile büyütür), `AppTypography.rowTitle`, `context.tokens` (`surface`, `border`, `textPrimary`, `textSecondary`), `context.l10n.actionDelete`, `context.l10n.alarmDuplicate`, `Theme.of(context).colorScheme.error`.
- Produces:
  - `Future<void> showRowActionsSheet(BuildContext context, {String? title, VoidCallback? onDuplicate, required VoidCallback onDelete})` — başlık bölüm etiketi olarak büyük harfle; "Kopyala" yalnız `onDuplicate` ile; "Sil" hata renginde + `Icons.delete_outline_rounded`; her eylemde önce sayfa kapanır, sonra geri çağırım çalışır; art arda dokunuşta eylem bir kez çalışır.
  - `class DeleteActionButton extends StatelessWidget { const DeleteActionButton(String label, VoidCallback onPressed, {Key? key, bool framed = true}); final String label; final VoidCallback onPressed; final bool framed; }` — en az 52 pt, ortalı, hata renginde yazı + çöp kutusu; `framed` iken `tokens.surface` + `tokens.border` + radius 16 kartında. Pop yapmaz; pop'u çağıran ekran yapar.
  - `GroupedRow({..., VoidCallback? onLongPress, ...})` — `onTap` ve `onLongPress` ikisi de `null` ise satır eskisi gibi dokunmasız çizilir.

- [ ] **Step 1: Testleri yaz (önce kırmızı)**

`test/widgets/common/row_actions_sheet_test.dart`:

```dart
import 'package:ezanvakti/presentation/widgets/common/row_actions_sheet.dart';
import 'package:ezanvakti/presentation/widgets/common/section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  /// Sayfayı gerçek bir dokunuşla açar.
  Future<void> openSheet(
    WidgetTester tester, {
    String? title,
    VoidCallback? onDuplicate,
    VoidCallback? onDelete,
  }) async {
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showRowActionsSheet(
              context,
              title: title,
              onDuplicate: onDuplicate,
              onDelete: onDelete ?? () {},
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('Başlık bölüm etiketi olarak Türkçe büyük harfle yazılır', (
    tester,
  ) async {
    await openSheet(tester, title: 'İkindi · 10 dk önce');

    expect(find.byType(SectionLabel), findsOneWidget);
    expect(find.text('İKİNDİ · 10 DK ÖNCE'), findsOneWidget);
  });

  testWidgets('Başlık verilmezse başlık satırı çizilmez', (tester) async {
    await openSheet(tester);

    expect(find.byType(SectionLabel), findsNothing);
    expect(find.text('Sil'), findsOneWidget);
  });

  testWidgets('onDuplicate yoksa Kopyala görünmez', (tester) async {
    await openSheet(tester);

    expect(find.text('Kopyala'), findsNothing);
  });

  testWidgets('Sil hata renginde ve çöp kutusu ikonuyla çizilir', (
    tester,
  ) async {
    await openSheet(tester);
    final error = Theme.of(tester.element(find.text('Sil'))).colorScheme.error;

    expect(tester.widget<Text>(find.text('Sil')).style!.color, error);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.delete_outline_rounded)).color,
      error,
    );
  });

  testWidgets('Sil önce sayfayı kapatır, sonra onDelete çağrılır', (
    tester,
  ) async {
    late Route<dynamic> sheetRoute;
    bool? sheetActiveAtDelete;
    await openSheet(
      tester,
      onDelete: () => sheetActiveAtDelete = sheetRoute.isActive,
    );
    sheetRoute = ModalRoute.of(tester.element(find.text('Sil')))!;

    await tester.tap(find.text('Sil'));
    // İkinci dokunuş aynı karede gelir; alttaki ekran kapanmamalı.
    await tester.tap(find.text('Sil'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(sheetActiveAtDelete, isFalse, reason: 'önce pop, sonra eylem');
    expect(find.text('Sil'), findsNothing);
    expect(find.text('aç'), findsOneWidget, reason: 'alttaki ekran kapanmaz');
  });

  testWidgets('Kopyala önce sayfayı kapatır, sonra onDuplicate çağrılır', (
    tester,
  ) async {
    late Route<dynamic> sheetRoute;
    bool? sheetActiveAtDuplicate;
    await openSheet(
      tester,
      onDuplicate: () => sheetActiveAtDuplicate = sheetRoute.isActive,
    );
    sheetRoute = ModalRoute.of(tester.element(find.text('Kopyala')))!;

    await tester.tap(find.text('Kopyala'));
    await tester.pumpAndSettle();

    expect(sheetActiveAtDuplicate, isFalse);
    expect(find.text('Kopyala'), findsNothing);
  });
}
```

`test/widgets/common/delete_action_button_test.dart`:

```dart
import 'package:ezanvakti/presentation/widgets/common/delete_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  /// Kart: kenarlıklı `BoxDecoration` taşıyan `Container`.
  Finder frame() => find.descendant(
    of: find.byType(DeleteActionButton),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).border != null,
    ),
  );

  testWidgets('Yazı ve çöp kutusu hata renginde, en az 52 pt', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(DeleteActionButton('Alarmı sil', () {})),
    );
    final label = find.text('Alarmı sil');
    final error = Theme.of(tester.element(label)).colorScheme.error;

    expect(DefaultTextStyle.of(tester.element(label)).style.color, error);
    expect(
      IconTheme.of(
        tester.element(find.byIcon(Icons.delete_outline_rounded)),
      ).color,
      error,
    );
    expect(
      tester.getSize(find.byType(TextButton)).height,
      greaterThanOrEqualTo(52),
    );
  });

  testWidgets('Basınca onPressed çağrılır', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      wrapWithTheme(DeleteActionButton('Alarmı sil', () => pressed++)),
    );

    await tester.tap(find.text('Alarmı sil'));

    expect(pressed, 1);
  });

  testWidgets('framed iken yüzey kartında durur', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(DeleteActionButton('Alarmı sil', () {})),
    );
    final tokens = tokensFor();
    final decoration =
        tester.widget<Container>(frame()).decoration! as BoxDecoration;

    expect(decoration.color, tokens.surface);
    expect(decoration.border, Border.all(color: tokens.border));
    expect(decoration.borderRadius, BorderRadius.circular(16));
  });

  testWidgets('framed: false iken kartsız çizilir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(DeleteActionButton('Konumu sil', () {}, framed: false)),
    );

    expect(frame(), findsNothing);
    expect(find.text('Konumu sil'), findsOneWidget);
  });
}
```

`test/widgets/grouped_list_test.dart` — `group('GroupedRow', ...)` içinde `testWidgets('onTap verilince dokunma tetiklenir', ...)` testinin hemen altına:

```dart
    testWidgets('onLongPress onTap olmadan da basili tutmayi yakalar', (
      tester,
    ) async {
      var pressed = false;

      await tester.pumpWidget(
        wrapWithTheme(
          GroupedList(
            children: [
              GroupedRow(
                title: const Text('Üsküdar'),
                onLongPress: () => pressed = true,
              ),
            ],
          ),
        ),
      );

      await tester.longPress(find.text('Üsküdar'));
      expect(pressed, isTrue);
    });
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/common/row_actions_sheet_test.dart test/widgets/common/delete_action_button_test.dart test/widgets/grouped_list_test.dart`
Expected: FAIL — derleme hatası: `row_actions_sheet.dart` ve `delete_action_button.dart` yok; `GroupedRow`'da `onLongPress` parametresi yok.

- [ ] **Step 3: `showRowActionsSheet`'i yaz**

Create `lib/presentation/widgets/common/row_actions_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../l10n/l10n_extensions.dart';
import 'section_label.dart';

/// Satıra basılı tutunca açılan eylem sayfası (spec 2026-09-28 §3.3).
///
/// [title] kaydı tanıtır; bölüm etiketi gibi Türkçe kurala göre büyük harfle
/// yazılır. "Kopyala" yalnız [onDuplicate] verilince görünür. "Sil" onay
/// sormaz: geri alma çağıranın "Geri al" çubuğuyla verilir (proje standardı).
/// Her eylemde önce sayfa kapanır, sonra geri çağırım çalışır; böylece çubuk
/// listenin üstünde çıkar.
Future<void> showRowActionsSheet(
  BuildContext context, {
  String? title,
  VoidCallback? onDuplicate,
  required VoidCallback onDelete,
}) {
  // Art arda iki dokunuş eylemi iki kez çalıştırıp alttaki ekranı da
  // kapatmasın; bayrak sayfa yeniden çizilse de korunur.
  var handled = false;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final tokens = sheetContext.tokens;
      final l10n = sheetContext.l10n;
      final error = Theme.of(sheetContext).colorScheme.error;
      final heading = title?.trim();
      final duplicate = onDuplicate;

      void run(VoidCallback action) {
        if (handled) return;
        handled = true;
        Navigator.pop(sheetContext);
        action();
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heading != null && heading.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
                child: SectionLabel(heading),
              ),
            if (duplicate != null)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(Icons.copy_rounded, color: tokens.textSecondary),
                title: Text(
                  l10n.alarmDuplicate,
                  style: AppTypography.rowTitle.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
                onTap: () => run(duplicate),
              ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(Icons.delete_outline_rounded, color: error),
              title: Text(
                l10n.actionDelete,
                style: AppTypography.rowTitle.copyWith(color: error),
              ),
              onTap: () => run(onDelete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
```

Not: arka plan ve köşe yarıçapı (28) Material 3 alt sayfa varsayılanından gelir; mockup (`tur_mock/silme.html`) tutamaçlı, 28 yarıçaplı sayfa gösteriyor. Mevcut alarm menüsü de tema varsayılanını kullanıyordu.

- [ ] **Step 4: `DeleteActionButton`'ı yaz**

Create `lib/presentation/widgets/common/delete_action_button.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Düzenleme ekranlarının altındaki silme düğmesi (spec 2026-09-28 §3.3).
///
/// Hata renginde, ortalı yazı ve çöp kutusu ikonu; en az 52 pt. Büyük metinde
/// yükseklik büyür, kırpılmaz. Onay sormaz ve kendisi pop yapmaz: çağıran
/// ekran önce kendini kapatır, sonra siler; "Geri al" çubuğu listede çıkar.
class DeleteActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  /// Formlarda ayrı bir yüzey kartında durur; konum ekranında "Kaydet"in
  /// altında kartsız çizilir.
  final bool framed;

  const DeleteActionButton(
    this.label,
    this.onPressed, {
    super.key,
    this.framed = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final error = Theme.of(context).colorScheme.error;
    final button = TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline_rounded, size: 20),
      label: Text(label, textAlign: TextAlign.center),
      style: TextButton.styleFrom(
        foregroundColor: error,
        iconColor: error,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: AppTypography.rowTitle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    if (!framed) return button;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: button,
    );
  }
}
```

- [ ] **Step 5: `GroupedRow`'a `onLongPress` ekle**

`lib/presentation/widgets/common/grouped_list.dart`, `GroupedRow` içinde:

`final VoidCallback? onTap;` satırının altına:

```dart

  /// Basılı tutma; satır eylem menüsünü açar. Verilmezse satır basılı
  /// tutmaya tepki vermez (ör. aktif konum).
  final VoidCallback? onLongPress;
```

Kurucuda `this.onTap,` satırının altına:

```dart
    this.onLongPress,
```

`build` sonundaki şu bloğu:

```dart
    if (onTap == null) return content;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: content),
    );
```

şununla değiştir:

```dart
    if (onTap == null && onLongPress == null) return content;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
    );
```

- [ ] **Step 6: Yeşili gör**

Run: `flutter test test/widgets/common/row_actions_sheet_test.dart test/widgets/common/delete_action_button_test.dart test/widgets/grouped_list_test.dart test/widgets/screens/location_list_screen_test.dart`
Expected: PASS.

- [ ] **Step 7: Biçimlendir ve commit'le**

```bash
dart format lib/presentation/widgets/common/row_actions_sheet.dart lib/presentation/widgets/common/delete_action_button.dart lib/presentation/widgets/common/grouped_list.dart test/widgets/common/row_actions_sheet_test.dart test/widgets/common/delete_action_button_test.dart test/widgets/grouped_list_test.dart
git add lib/presentation/widgets/common/row_actions_sheet.dart lib/presentation/widgets/common/delete_action_button.dart lib/presentation/widgets/common/grouped_list.dart test/widgets/common/row_actions_sheet_test.dart test/widgets/common/delete_action_button_test.dart test/widgets/grouped_list_test.dart
git commit -m "feat(ui): ortak satır eylem sayfası, silme düğmesi ve GroupedRow basılı tutma" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Alarmlar — kaydırma kalkar, menü ortak sayfaya taşınır, "Alarmı sil"

**Files:**
- Modify: `lib/presentation/widgets/reminders/alarms_section.dart:23` (import), `:269-308` (`_alarmRow` dönüşü, `_showRowMenu`), `:325` (ipucu)
- Modify: `lib/presentation/screens/alarm_edit_screen.dart:34-44` (alan + kurucu), `:116-157` (`_save` altına `_delete`), `:251-269` (liste sonu), import
- Modify: `lib/presentation/screens/reminders_screen.dart` `_addOrEditAlarm` (Faz 1 öncesi `:629-638`)
- Modify: `lib/l10n/app_tr.arb` (`@alarmDuplicate` bloğundan sonra; `alarmsSwipeHint` bloğu), `app_en.arb:187,368`, `app_ar.arb:187,368`
- Test: `test/widgets/notifications/alarms_section_test.dart` (iki test), `test/widgets/screens/alarm_edit_screen_test.dart` (`pumpEdit` + yeni grup), `test/widgets/screens/reminders_screen_test.dart` (yardımcı, 4 kaydırma testi, kopya testi, yeni test)

**Interfaces:**
- Consumes: `showRowActionsSheet`, `DeleteActionButton` (Task 4); `alarmTimeLabel(alarm, l10n:, formatHourMinute:)` (`utils/alarm_labels.dart`); mevcut `_deleteAlarm(Alarm)` (onaysız siler, "Geri al" gösterir).
- Produces:
  - `AlarmEditScreen({Key? key, Alarm? alarm, VoidCallback? onDelete, bool? fadeInSupported})`; `final VoidCallback? onDelete;` — verilince formun en altında, 28 pt boşluktan sonra kartlı "Alarmı sil". Dönüş türü (`Alarm?`) değişmez; silmede `null`.
  - `l10n.alarmDeleteAction`, `l10n.alarmsLongPressHint` (`alarmsSwipeHint` kalkar).
  - `_addOrEditAlarm` yalnız `appState.alarms` içinde aynı id'li kayıt varken `onDelete` verir. Kopya (`_duplicateAlarm`) de `existing` ile açıldığı için yalnız `existing != null` kontrolü yetmez.

- [ ] **Step 1: Testleri yaz (önce kırmızı)**

`test/widgets/notifications/alarms_section_test.dart` — `main` sonuna (son `testWidgets`'tan sonra):

```dart
  testWidgets('Kaydırarak silme yok; basılı tutma menüsü alarmı tanıtır ve siler', (
    tester,
  ) async {
    final deleted = <Alarm>[];
    await tester.pumpWidget(
      wrapWithTheme(
        AlarmsSection(
          alarms: const [sahur],
          isSupported: true,
          isPermissionGranted: true,
          onRequestPermission: () {},
          onToggle: (_, _) {},
          onEdit: (_) {},
          onDelete: (alarm) async => deleted.add(alarm),
          onDuplicate: (_) {},
        ),
      ),
    );

    expect(find.byType(Dismissible), findsNothing);
    expect(find.textContaining('satıra basılı tut'), findsOneWidget);

    await tester.longPress(find.text('06:30'));
    await tester.pumpAndSettle();
    expect(find.text('06:30 · SAHUR'), findsOneWidget);
    expect(find.text('Kopyala'), findsOneWidget);

    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(deleted, [sahur]);
    expect(find.text('Sil'), findsNothing);
  });

  testWidgets('Sıralama kipinde basılı tutma menü açmaz', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        AlarmsSection(
          alarms: const [sahur],
          isSupported: true,
          isPermissionGranted: true,
          onRequestPermission: () {},
          onToggle: (_, _) {},
          onEdit: (_) {},
          onDelete: (_) async {},
          isReordering: true,
          onReorder: (_, _) {},
        ),
      ),
    );

    await tester.longPress(find.text('06:30'));
    await tester.pumpAndSettle();
    expect(find.text('Sil'), findsNothing);
  });
```

`test/widgets/screens/alarm_edit_screen_test.dart`:

Import listesine ekle:

```dart
import 'package:ezanvakti/presentation/widgets/common/delete_action_button.dart';
```

`pumpEdit`'i `onDelete` alacak şekilde değiştir (yalnız imza ve kurucu çağrısı değişir):

```dart
  Future<void> pumpEdit(
    WidgetTester tester, {
    Alarm? alarm,
    bool fadeInSupported = false,
    VoidCallback? onDelete,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        AlarmEditScreen(
          alarm: alarm,
          fadeInSupported: fadeInSupported,
          onDelete: onDelete,
        ),
      ),
    );
    await tester.pump();
  }
```

Dosyanın sonundaki `main` kapanışından (`}`) hemen önce:

```dart
  group('Silme düğmesi', () {
    const saved = Alarm(id: '1', kind: AlarmKind.fixed, hour: 6, minute: 30);

    Finder form() => find
        .descendant(
          of: find.byType(AlarmEditScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    /// Liste tembel kuruluyor; en alttaki öğe ancak sona inince var olur.
    Future<void> scrollToEnd(WidgetTester tester) async {
      final position = tester.state<ScrollableState>(form()).position;
      for (
        var i = 0;
        i < 10 && position.pixels < position.maxScrollExtent;
        i++
      ) {
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('onDelete verilmezse düğme çizilmez', (tester) async {
      await pumpEdit(tester, alarm: saved);
      await scrollToEnd(tester);

      expect(find.byType(DeleteActionButton), findsNothing);
    });

    testWidgets('onDelete verilince en altta kartlı "Alarmı sil" çizilir', (
      tester,
    ) async {
      await pumpEdit(tester, alarm: saved, onDelete: () {});
      await scrollToEnd(tester);

      final button = tester.widget<DeleteActionButton>(
        find.byType(DeleteActionButton),
      );
      expect(button.label, 'Alarmı sil');
      expect(button.framed, isTrue);
    });

    testWidgets('Basınca önce ekran kapanır, sonra onDelete; sonuç dönmez', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      late MaterialPageRoute<Alarm> route;
      bool? routeActiveAtDelete;
      var returned = false;
      Alarm? result = saved;
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                route = MaterialPageRoute<Alarm>(
                  builder: (_) => AlarmEditScreen(
                    alarm: saved,
                    fadeInSupported: false,
                    onDelete: () => routeActiveAtDelete = route.isActive,
                  ),
                );
                result = await Navigator.of(context).push(route);
                returned = true;
              },
              child: const Text('aç'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Alarmı sil'),
        300,
        scrollable: form(),
      );
      await tester.tap(find.text('Alarmı sil'));
      // İkinci dokunuş aynı karede gelir; alttaki ekran kapanmamalı.
      await tester.tap(find.text('Alarmı sil'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(routeActiveAtDelete, isFalse, reason: 'önce pop, sonra silme');
      expect(find.text('aç'), findsOneWidget, reason: 'alttaki ekran kapanmaz');
      expect(returned, isTrue);
      expect(result, isNull, reason: 'silmede sonuç dönmez');
      expect(find.byType(AlarmEditScreen), findsNothing);
    });
  });
```

`test/widgets/screens/reminders_screen_test.dart`:

(a) `pumpNotifications` fonksiyonunun hemen altına yardımcı:

```dart

  /// Satıra basılı tutup açılan menüden "Sil"e basar; kaydırarak silme
  /// kaldırıldı (spec 2026-09-28 §3.3).
  Future<void> deleteByLongPress(WidgetTester tester, Finder row) async {
    await tester.longPress(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
  }
```

(b) `testWidgets('Alarm silinince AppState tazelenir', ...)` içindeki:

```dart
    // Alarm satirinda onay sorulmuyor; kaydirmak dogrudan siliyor.
    await tester.drag(find.textContaining('06:30'), const Offset(-400, 0));
    await tester.pumpAndSettle();
```

bloğunu şununla değiştir:

```dart
    // Onay sorulmuyor; menüdeki "Sil" doğrudan siliyor.
    await deleteByLongPress(tester, find.textContaining('06:30'));
```

(c) Dosyada kalan üç yerde (`'Native deletion failure stays recoverable through retry'`, `'Silinen alarm "Geri al" ile geri gelir'`, `'"Geri al" planlamayi beklemeden hemen gorunur'`) şu iki satırı:

```dart
    await tester.drag(find.textContaining('06:30'), const Offset(-400, 0));
    await tester.pumpAndSettle();
```

şununla değiştir (hepsini):

```dart
    await deleteByLongPress(tester, find.textContaining('06:30'));
```

Sonra `grep -n "Offset(-400, 0)" test/widgets/screens/reminders_screen_test.dart` yalnız bildirim testindeki satırı (`'Öğle · Tam vaktinde'`) göstermeli; o Task 6'te değişir.

(d) `testWidgets('Uzun basma kopyayı düzenlemeye açar, kaydetmeden kayıt oluşmaz', ...)` içinde `expect(draft.id, isNot(sahur.id));` satırının altına:

```dart
      expect(
        tester.widget<AlarmEditScreen>(find.byType(AlarmEditScreen)).onDelete,
        isNull,
        reason: 'kopya henüz kayıtlı değil; silme düğmesi çizilmez',
      );
```

(e) `testWidgets('Silinen alarm "Geri al" ile geri gelir', ...)` testinin hemen altına:

```dart
  testWidgets(
    'Kayıtlı alarmın "Alarmı sil" düğmesi ekranı kapatır, "Geri al" geri getirir',
    (tester) async {
      await storage.saveAlarm(sahur);
      appState.setAlarms(const [sahur]);
      await pump(tester);
      await tester.tap(find.text('Alarmlar'));
      await tester.pumpAndSettle();

      // Yeni alarmda silinecek kayıt yok.
      await tester.tap(find.byKey(const Key('add_reminder_button')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AlarmEditScreen>(find.byType(AlarmEditScreen)).onDelete,
        isNull,
      );
      Navigator.of(tester.element(find.byType(AlarmEditScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('06:30'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Alarmı sil'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(AlarmEditScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Alarmı sil'));
      await tester.pumpAndSettle();

      expect(find.byType(AlarmEditScreen), findsNothing);
      expect(appState.alarms, isEmpty);
      expect(await storage.getAlarms(), isEmpty);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(appState.alarms.map((a) => a.id), [sahur.id]);
    },
  );
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/notifications/alarms_section_test.dart test/widgets/screens/alarm_edit_screen_test.dart test/widgets/screens/reminders_screen_test.dart`
Expected: FAIL — `alarm_edit_screen_test.dart` ve `reminders_screen_test.dart` derlenmez (`AlarmEditScreen`'de `onDelete` yok); `alarms_section_test.dart` yeni testte `Dismissible` bulunur, "06:30 · SAHUR" başlığı ve "satıra basılı tut" ipucu yok.

- [ ] **Step 3: ARB anahtarları**

`lib/l10n/app_tr.arb` — `@alarmDuplicate` bloğundan hemen sonra (`"errorGeneric"` satırından önce):

```json
  "alarmDeleteAction": "Alarmı sil",
  "@alarmDeleteAction": {
    "description": "Alarm düzenleme ekranının en altındaki silme düğmesi; onay sormaz, listede \"Geri al\" çıkar."
  },
```

Aynı dosyada şu bloğu:

```json
  "alarmsSwipeHint": "Kopyalamak için basılı tut; silmek için sola kaydır. Silinen alarmı \"Geri al\" ile geri getirebilirsin.",
  "@alarmsSwipeHint": {
    "description": "İpucu"
  },
```

şununla değiştir:

```json
  "alarmsLongPressHint": "Kopyalamak ya da silmek için satıra basılı tut. Silinen alarmı \"Geri al\" ile geri getirebilirsin.",
  "@alarmsLongPressHint": {
    "description": "Alarm listesinin altındaki ipucu: basılı tutma menüsü (Kopyala / Sil)."
  },
```

`lib/l10n/app_en.arb` — `"alarmDuplicate": "Duplicate",` satırının altına:

```json
  "alarmDeleteAction": "Delete alarm",
```

ve `"alarmsSwipeHint": ...` satırını şununla değiştir:

```json
  "alarmsLongPressHint": "Touch and hold a row to duplicate or delete it. Use \"Undo\" to restore a deleted alarm.",
```

`lib/l10n/app_ar.arb` — `"alarmDuplicate": "نسخ",` satırının altına:

```json
  "alarmDeleteAction": "حذف المنبه",
```

ve `"alarmsSwipeHint": ...` satırını şununla değiştir:

```json
  "alarmsLongPressHint": "اضغط مطولاً على الصف لنسخ المنبه أو حذفه. استخدم «تراجع» لاستعادة المنبه المحذوف.",
```

Run: `flutter gen-l10n`

- [ ] **Step 4: `AlarmsSection`**

`lib/presentation/widgets/reminders/alarms_section.dart`:

Import'ta `import '../common/swipe_to_delete.dart';` satırını şununla değiştir:

```dart
import '../common/row_actions_sheet.dart';
```

`_alarmRow` sonundaki:

```dart
    return isReordering
        ? row
        : SwipeToDelete(
            itemKey: ValueKey(alarm.id),
            onDelete: () => onDelete(alarm),
            child: row,
          );
  }
```

bloğunu şununla değiştir:

```dart
    return row;
  }
```

`_showRowMenu`'yü (doc yorumu dahil) şununla değiştir:

```dart
  /// Basılı tutma menüsü: Kopyala / Sil. Başlık alarmı tanıtır: saat
  /// etiketi ve varsa adı (spec 2026-09-28 §3.3).
  void _showRowMenu(BuildContext context, Alarm alarm) {
    final time = alarmTimeLabel(
      alarm,
      l10n: context.l10n,
      formatHourMinute: context.formatHourMinute,
    );
    final label = alarm.label.trim();
    showRowActionsSheet(
      context,
      title: label.isEmpty ? time : '$time · $label',
      onDuplicate: onDuplicate == null ? null : () => onDuplicate!(alarm),
      onDelete: () => onDelete(alarm),
    );
  }
```

`_list` içindeki `: context.l10n.alarmsSwipeHint,` satırını şununla değiştir:

```dart
              : context.l10n.alarmsLongPressHint,
```

(`onLongPress: isReordering ? null : () => _showRowMenu(context, alarm),` satırı aynen kalır: sıralama kipinde menü kapalı.)

- [ ] **Step 5: `AlarmEditScreen`**

`lib/presentation/screens/alarm_edit_screen.dart`:

Import listesine (`'../widgets/common/app_surface.dart'` satırının altına):

```dart
import '../widgets/common/delete_action_button.dart';
```

Alan ve kurucu — şu bloğu:

```dart
  final bool fadeInSupported;

  AlarmEditScreen({super.key, this.alarm, bool? fadeInSupported})
    : fadeInSupported = fadeInSupported ?? Platform.isAndroid;
```

şununla değiştir:

```dart
  final bool fadeInSupported;

  /// Verilirse formun en altında "Alarmı sil" çizilir; yalnız kayıtlı
  /// alarmda verilir (yeni alarm ve kopya için `null`).
  final VoidCallback? onDelete;

  AlarmEditScreen({
    super.key,
    this.alarm,
    this.onDelete,
    bool? fadeInSupported,
  }) : fadeInSupported = fadeInSupported ?? Platform.isAndroid;
```

`_save` metodunun hemen altına:

```dart

  /// Önce ekran kapanır, sonra silinir: "Geri al" çubuğu listenin üstünde
  /// çıkar. Sonuç dönmez; çağıranın "sonuç yoksa çık" dalı buna uyar.
  void _delete() {
    // Art arda iki dokunuş alttaki listeyi de kapatmasın.
    if (_deleting) return;
    _deleting = true;
    Navigator.of(context).pop();
    widget.onDelete!();
  }

  bool _deleting = false;
```

`build` içindeki `ListView` çocuklarının sonundaki QR bloğunu kapatan satırlardan sonra — şu bloğu:

```dart
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _openSavedCodes,
                  icon: const Icon(Icons.bookmarks_outlined, size: 18),
                  label: Text(context.l10n.alarmPickSavedCode),
                ),
              ),
            ],
          ],
```

şununla değiştir:

```dart
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _openSavedCodes,
                  icon: const Icon(Icons.bookmarks_outlined, size: 18),
                  label: Text(context.l10n.alarmPickSavedCode),
                ),
              ),
            ],
            if (widget.onDelete != null) ...[
              const SizedBox(height: 28),
              DeleteActionButton(context.l10n.alarmDeleteAction, _delete),
            ],
          ],
```

- [ ] **Step 6: `_addOrEditAlarm` yalnız kayıtlı alarmda `onDelete` geçirir**

`lib/presentation/screens/reminders_screen.dart` — şu bloğu:

```dart
  Future<void> _addOrEditAlarm([Alarm? existing]) async {
    final appState = context.read<AppState>();
    final result = await Navigator.of(context).push<Alarm>(
      MaterialPageRoute(builder: (_) => AlarmEditScreen(alarm: existing)),
    );
    if (result == null) return;
```

şununla değiştir:

```dart
  Future<void> _addOrEditAlarm([Alarm? existing]) async {
    final appState = context.read<AppState>();
    // Kopya da `existing` ile açılır ama henüz kayıtlı değildir; silme
    // düğmesi yalnız listede duran alarm için çizilir.
    final saved = existing == null
        ? null
        : appState.alarms.where((alarm) => alarm.id == existing.id).firstOrNull;
    final result = await Navigator.of(context).push<Alarm>(
      MaterialPageRoute(
        builder: (_) => AlarmEditScreen(
          alarm: existing,
          onDelete: saved == null ? null : () => _deleteAlarm(saved),
        ),
      ),
    );
    if (result == null) return;
```

- [ ] **Step 7: Yeşili gör**

Run: `flutter test test/widgets/notifications/alarms_section_test.dart test/widgets/screens/alarm_edit_screen_test.dart test/widgets/screens/alarm_edit_mission_test.dart test/widgets/screens/reminders_screen_test.dart test/widgets/reminders test/l10n/arb_consistency_test.dart`
Expected: PASS. `grep -rn alarmsSwipeHint lib test` boş dönmeli.

- [ ] **Step 8: Biçimlendir ve commit'le**

```bash
dart format lib/presentation/widgets/reminders/alarms_section.dart lib/presentation/screens/alarm_edit_screen.dart lib/presentation/screens/reminders_screen.dart test/widgets/notifications/alarms_section_test.dart test/widgets/screens/alarm_edit_screen_test.dart test/widgets/screens/reminders_screen_test.dart
git add lib/l10n/app_tr.arb lib/l10n/app_en.arb lib/l10n/app_ar.arb lib/l10n/app_localizations*.dart lib/presentation/widgets/reminders/alarms_section.dart lib/presentation/screens/alarm_edit_screen.dart lib/presentation/screens/reminders_screen.dart test/widgets/notifications/alarms_section_test.dart test/widgets/screens/alarm_edit_screen_test.dart test/widgets/screens/reminders_screen_test.dart
git commit -m "feat(ui): alarmda kaydırarak silme yerine basılı tutma menüsü ve Alarmı sil düğmesi" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Bildirimler — basılı tutma menüsü (yalnız Sil), "Bildirimi sil"

**Files:**
- Modify: `lib/presentation/widgets/notifications/notification_tile.dart:1-15` (import, doc), `:87-100` (`build` dönüşü)
- Modify: `lib/presentation/widgets/reminders/notifications_section.dart:15` (import), `:147` (ipucu), `:194-215` (`_row`)
- Modify: `lib/presentation/screens/notification_edit_screen.dart:33-48` (alan + kurucu), `:137-162` (`_save` altına `_delete`), `:200-213` (liste sonu), import
- Modify: `lib/presentation/screens/reminders_screen.dart` `_openNotificationEditor` (Faz 1 öncesi `:789-798`)
- Modify: `lib/l10n/app_tr.arb` (`@snackNotificationDeleted` bloğundan sonra; `remindersSwipeToDelete` bloğu), `app_en.arb:201,366`, `app_ar.arb:201,366`
- Test: `test/widgets/notifications/notifications_section_test.dart`, `test/widgets/notifications/notification_edit_screen_test.dart`, `test/widgets/screens/reminders_screen_test.dart`

**Interfaces:**
- Consumes: `showRowActionsSheet`, `DeleteActionButton` (Task 4); `notificationRuleLabel`, `notificationCustomLabel` (`utils/reminder_labels.dart`); `deleteByLongPress` test yardımcısı (Task 5); mevcut `_deleteNotification(NotificationSetting)`.
- Produces:
  - `NotificationTile.onDelete` (mevcut `Future<void> Function()?`) artık basılı tutma menüsünü açar; `null` ya da `isReordering` iken menü yok. Menü başlığı: kural etiketi + varsa kullanıcı adı ("Öğle · Tam vaktinde", "Öğle · 45 dk önce · Cuma namazı"); menüde yalnız Sil.
  - `NotificationEditScreen({Key? key, NotificationSetting? initial, required List<PrayerTime> prayerTimes, DateTime Function()? clock, VoidCallback? onDelete})`; `final VoidCallback? onDelete;` — verilince formun en altında, 28 pt boşluktan sonra kartlı "Bildirimi sil". Dönüş türü (`NotificationDraft?`) değişmez.
  - `l10n.notificationDeleteAction`, `l10n.remindersLongPressHint` (`remindersSwipeToDelete` kalkar).
- Karar: tile'daki kullanılmayan `onDelete` alanı **kullanılır**, kaldırılmaz. Menü başlığı tile'ın zaten kullandığı etiket yardımcılarından türüyor ve `isReordering` bilgisi tile'da; `NotificationsSection` yalnız `onDelete: () => onDelete(setting)` geçirir, satıra `onLongPress` taşıyan ikinci bir yol açılmaz.

- [ ] **Step 1: Testleri yaz (önce kırmızı)**

`test/widgets/notifications/notifications_section_test.dart` — `main` sonuna:

```dart
  testWidgets('Kaydırarak silme yok; basılı tutma menüsünde yalnız Sil var', (
    tester,
  ) async {
    final deleted = <NotificationSetting>[];
    await tester.pumpWidget(
      wrapWithTheme(
        NotificationsSection(
          settings: const [dhuhr],
          hasPermission: true,
          exactAlarmAllowed: true,
          onPermissionChanged: (_) {},
          onOpenExactAlarmSettings: () {},
          onToggle: (_) {},
          onEdit: (_) {},
          onDelete: (setting) async => deleted.add(setting),
        ),
      ),
    );

    expect(find.byType(Dismissible), findsNothing);
    expect(find.text('Silmek için satıra basılı tut.'), findsOneWidget);

    await tester.longPress(find.text('Öğle · Tam vaktinde'));
    await tester.pumpAndSettle();
    expect(find.text('ÖĞLE · TAM VAKTİNDE'), findsOneWidget);
    expect(find.text('Kopyala'), findsNothing);

    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(deleted, [dhuhr]);
  });

  testWidgets('Menü başlığı kullanıcının verdiği adı da yazar', (tester) async {
    const friday = NotificationSetting(
      prayerType: PrayerType.dhuhr,
      isActive: true,
      minutesBefore: 45,
      weekdays: {5},
      label: 'Cuma namazı',
    );
    await tester.pumpWidget(build(settings: const [friday]));

    await tester.longPress(find.text('Öğle · 45 dk önce'));
    await tester.pumpAndSettle();

    expect(find.text('ÖĞLE · 45 DK ÖNCE · CUMA NAMAZI'), findsOneWidget);
  });

  testWidgets('Sıralama kipinde basılı tutma menü açmaz', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        NotificationsSection(
          settings: const [dhuhr, fajr],
          hasPermission: true,
          exactAlarmAllowed: true,
          onPermissionChanged: (_) {},
          onOpenExactAlarmSettings: () {},
          onToggle: (_) {},
          onEdit: (_) {},
          onDelete: (_) async {},
          isReordering: true,
          onReorder: (_, _) {},
        ),
      ),
    );

    await tester.longPress(find.text('Öğle · Tam vaktinde'));
    await tester.pumpAndSettle();
    expect(find.text('Sil'), findsNothing);
  });
```

`test/widgets/notifications/notification_edit_screen_test.dart`:

Import listesine ekle:

```dart
import 'package:ezanvakti/presentation/widgets/common/delete_action_button.dart';
```

Dosyanın sonundaki `main` kapanışından (`}`) hemen önce:

```dart
  group('Silme düğmesi', () {
    const saved = NotificationSetting(
      prayerType: PrayerType.dhuhr,
      isActive: true,
    );

    Finder form() => find
        .descendant(
          of: find.byType(NotificationEditScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    Future<void> scrollToEnd(WidgetTester tester) async {
      final position = tester.state<ScrollableState>(form()).position;
      for (
        var i = 0;
        i < 10 && position.pixels < position.maxScrollExtent;
        i++
      ) {
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('onDelete verilmezse düğme çizilmez', (tester) async {
      await open(tester, initial: saved);
      await scrollToEnd(tester);

      expect(find.byType(DeleteActionButton), findsNothing);
    });

    testWidgets('Basınca önce ekran kapanır, sonra onDelete; taslak dönmez', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      late MaterialPageRoute<NotificationDraft> route;
      bool? routeActiveAtDelete;
      var returned = false;
      NotificationDraft? draft;
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                route = MaterialPageRoute<NotificationDraft>(
                  builder: (_) => NotificationEditScreen(
                    initial: saved,
                    prayerTimes: prayerTimes,
                    clock: () => now,
                    onDelete: () => routeActiveAtDelete = route.isActive,
                  ),
                );
                draft = await Navigator.of(context).push(route);
                returned = true;
              },
              child: const Text('aç'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Bildirimi sil'),
        300,
        scrollable: form(),
      );
      expect(
        tester
            .widget<DeleteActionButton>(find.byType(DeleteActionButton))
            .framed,
        isTrue,
      );
      await tester.tap(find.text('Bildirimi sil'));
      // İkinci dokunuş aynı karede gelir; alttaki ekran kapanmamalı.
      await tester.tap(find.text('Bildirimi sil'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(routeActiveAtDelete, isFalse, reason: 'önce pop, sonra silme');
      expect(find.text('aç'), findsOneWidget, reason: 'alttaki ekran kapanmaz');
      expect(returned, isTrue);
      expect(draft, isNull);
      expect(find.byType(NotificationEditScreen), findsNothing);
    });
  });
```

`test/widgets/screens/reminders_screen_test.dart`:

Import listesine ekle:

```dart
import 'package:ezanvakti/presentation/screens/notification_edit_screen.dart';
```

`testWidgets('Bildirim silinince AppState tazelenir', ...)` içindeki:

```dart
    // Onay sorulmuyor; kaydirmak dogrudan siliyor.
    await tester.drag(find.text('Öğle · Tam vaktinde'), const Offset(-400, 0));
    await tester.pumpAndSettle();
```

bloğunu şununla değiştir:

```dart
    // Onay sorulmuyor; menüdeki "Sil" doğrudan siliyor.
    await deleteByLongPress(tester, find.text('Öğle · Tam vaktinde'));
```

Aynı testin hemen altına:

```dart
  testWidgets(
    'Mevcut bildirimin "Bildirimi sil" düğmesi ekranı kapatır, "Geri al" geri getirir',
    (tester) async {
      const dhuhr = NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 0,
      );
      await storage.saveNotificationSettings(const [dhuhr]);
      appState.setNotificationSettings(const [dhuhr]);
      await pumpNotifications(tester);

      // Yeni bildirimde silinecek kayıt yok.
      await tester.tap(find.byKey(const Key('add_reminder_button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NotificationEditScreen>(find.byType(NotificationEditScreen))
            .onDelete,
        isNull,
      );
      Navigator.of(tester.element(find.byType(NotificationEditScreen))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Öğle · Tam vaktinde'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Bildirimi sil'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(NotificationEditScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Bildirimi sil'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationEditScreen), findsNothing);
      expect(appState.notificationSettings, isEmpty);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(appState.notificationSettings.map((s) => s.prayerType), [
        PrayerType.dhuhr,
      ]);
    },
  );
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/notifications/notifications_section_test.dart test/widgets/notifications/notification_edit_screen_test.dart test/widgets/screens/reminders_screen_test.dart`
Expected: FAIL — `notification_edit_screen_test.dart` ve `reminders_screen_test.dart` derlenmez (`NotificationEditScreen`'de `onDelete` yok); `notifications_section_test.dart`'ta `Dismissible` bulunur, ipucu ve menü başlığı yok (basılı tutma bir şey açmaz).

- [ ] **Step 3: ARB anahtarları**

`lib/l10n/app_tr.arb` — `@snackNotificationDeleted` bloğundan hemen sonra (`"snackNotificationExists"` satırından önce):

```json
  "notificationDeleteAction": "Bildirimi sil",
  "@notificationDeleteAction": {
    "description": "Bildirim düzenleme ekranının en altındaki silme düğmesi; onay sormaz, listede \"Geri al\" çıkar."
  },
```

Aynı dosyada şu bloğu:

```json
  "remindersSwipeToDelete": "Silmek için satırı sola kaydırın.",
  "@remindersSwipeToDelete": {
    "description": "İpucu"
  },
```

şununla değiştir:

```json
  "remindersLongPressHint": "Silmek için satıra basılı tut.",
  "@remindersLongPressHint": {
    "description": "Bildirim listesinin altındaki ipucu: basılı tutma menüsü (Sil)."
  },
```

`lib/l10n/app_en.arb` — `"snackNotificationDeleted": "Notification deleted",` satırının altına:

```json
  "notificationDeleteAction": "Delete notification",
```

ve `"remindersSwipeToDelete": "Swipe a row to delete it.",` satırını şununla değiştir:

```json
  "remindersLongPressHint": "Touch and hold a row to delete it.",
```

`lib/l10n/app_ar.arb` — `"snackNotificationDeleted": "تم حذف التنبيه",` satırının altına:

```json
  "notificationDeleteAction": "حذف التنبيه",
```

ve `"remindersSwipeToDelete": "اسحب الصف لحذفه.",` satırını şununla değiştir:

```json
  "remindersLongPressHint": "اضغط مطولاً على الصف لحذفه.",
```

Run: `flutter gen-l10n`

- [ ] **Step 4: `NotificationTile` menüyü açar**

`lib/presentation/widgets/notifications/notification_tile.dart`:

Import listesine (`'../reminders/reminder_row.dart'` satırının üstüne):

```dart
import '../common/row_actions_sheet.dart';
```

Sınıf doc yorumunu şununla değiştir:

```dart
/// Bildirim listesindeki tek satır.
///
/// Kendi kartını çizmez; grup içindeki bir [ReminderRow] olarak gelir. Silme,
/// satıra basılı tutunca açılan menüden ya da düzenleme ekranındaki düğmeden
/// yapılır; ayrı bir çöp kutusu düğmesi yoktur.
```

`build` içinde `final l10n = context.l10n;` satırının altına:

```dart
    final delete = onDelete;
```

`return ReminderRow(` bloğunda `onTap: isReordering ? null : onTap,` satırının altına:

```dart
      // Sıralama kipinde menü kapalı; başlık kural etiketi ve varsa ad.
      onLongPress: isReordering || delete == null
          ? null
          : () => showRowActionsSheet(
              context,
              title: [
                notificationRuleLabel(setting, l10n),
                ?notificationCustomLabel(setting),
              ].join(' · '),
              onDelete: delete,
            ),
```

- [ ] **Step 5: `NotificationsSection`**

`lib/presentation/widgets/reminders/notifications_section.dart`:

`import '../common/swipe_to_delete.dart';` satırını sil.

`: context.l10n.remindersSwipeToDelete,` satırını şununla değiştir:

```dart
              : context.l10n.remindersLongPressHint,
```

`_row` metodunu şununla değiştir:

```dart
  Widget _row(NotificationSetting setting) {
    return NotificationTile(
      setting: setting,
      hasPermission: hasPermission,
      now: now,
      isReordering: isReordering,
      nextFireAt: nextFireByNotification[notificationKey(setting)],
      isSkipped: _isSkipped(setting),
      onSkipToggle: onSkipChanged == null
          ? null
          : () => onSkipChanged!(_occurrence(setting), !_isSkipped(setting)),
      onToggle: () => onToggle(setting),
      onTap: () => onEdit(setting),
      onDelete: () => onDelete(setting),
    );
  }
```

- [ ] **Step 6: `NotificationEditScreen`**

`lib/presentation/screens/notification_edit_screen.dart`:

Import listesine (`'../widgets/common/app_surface.dart'` satırının altına):

```dart
import '../widgets/common/delete_action_button.dart';
```

Alan ve kurucu — şu bloğu:

```dart
  /// Testler sabitler; varsayılan cihaz saati.
  final DateTime Function()? clock;

  const NotificationEditScreen({
    super.key,
    this.initial,
    required this.prayerTimes,
    this.clock,
  });
```

şununla değiştir:

```dart
  /// Testler sabitler; varsayılan cihaz saati.
  final DateTime Function()? clock;

  /// Verilirse formun en altında "Bildirimi sil" çizilir; yalnız mevcut
  /// kayıtta verilir.
  final VoidCallback? onDelete;

  const NotificationEditScreen({
    super.key,
    this.initial,
    required this.prayerTimes,
    this.clock,
    this.onDelete,
  });
```

`_save` metodunun hemen altına:

```dart

  /// Önce ekran kapanır, sonra silinir: "Geri al" çubuğu listenin üstünde
  /// çıkar. Taslak dönmez; çağıranın "sonuç yoksa çık" dalı buna uyar.
  void _delete() {
    // Art arda iki dokunuş alttaki listeyi de kapatmasın.
    if (_deleting) return;
    _deleting = true;
    Navigator.of(context).pop();
    widget.onDelete!();
  }

  bool _deleting = false;
```

`build` içindeki `ListView` çocuklarının sonunu — şu bloğu:

```dart
            const SizedBox(height: 16),
            _section(l10n.remindersLabelSection, _labelField(l10n)),
          ],
```

şununla değiştir:

```dart
            const SizedBox(height: 16),
            _section(l10n.remindersLabelSection, _labelField(l10n)),
            if (widget.onDelete != null) ...[
              const SizedBox(height: 28),
              DeleteActionButton(l10n.notificationDeleteAction, _delete),
            ],
          ],
```

- [ ] **Step 7: `_openNotificationEditor` mevcut kayıtta `onDelete` geçirir**

`lib/presentation/screens/reminders_screen.dart` — şu bloğu:

```dart
        builder: (_) => NotificationEditScreen(
          initial: initial,
          prayerTimes: appState.prayerTimes,
        ),
```

şununla değiştir:

```dart
        builder: (_) => NotificationEditScreen(
          initial: initial,
          prayerTimes: appState.prayerTimes,
          onDelete: initial == null
              ? null
              : () => _deleteNotification(initial),
        ),
```

- [ ] **Step 8: Yeşili gör**

Run: `flutter test test/widgets/notifications test/widgets/screens/notification_screen_test.dart test/widgets/screens/reminders_screen_test.dart test/l10n/arb_consistency_test.dart`
Expected: PASS. `grep -rn remindersSwipeToDelete lib test` ve `grep -n "Offset(-400, 0)" test/widgets/screens/reminders_screen_test.dart` boş dönmeli.

- [ ] **Step 9: Biçimlendir ve commit'le**

```bash
dart format lib/presentation/widgets/notifications/notification_tile.dart lib/presentation/widgets/reminders/notifications_section.dart lib/presentation/screens/notification_edit_screen.dart lib/presentation/screens/reminders_screen.dart test/widgets/notifications/notifications_section_test.dart test/widgets/notifications/notification_edit_screen_test.dart test/widgets/screens/reminders_screen_test.dart
git add lib/l10n/app_tr.arb lib/l10n/app_en.arb lib/l10n/app_ar.arb lib/l10n/app_localizations*.dart lib/presentation/widgets/notifications/notification_tile.dart lib/presentation/widgets/reminders/notifications_section.dart lib/presentation/screens/notification_edit_screen.dart lib/presentation/screens/reminders_screen.dart test/widgets/notifications/notifications_section_test.dart test/widgets/notifications/notification_edit_screen_test.dart test/widgets/screens/reminders_screen_test.dart
git commit -m "feat(ui): bildirimde basılı tutma menüsü ve Bildirimi sil düğmesi" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Konumlar — aktif olmayan satırda menü, kartsız "Konumu sil"

İki commit: önce ekranın testte açılmasını engelleyen mevcut hata (düzeltme), sonra özellik.

**Files:**
- Modify: `lib/presentation/screens/location_list_screen.dart:14` (import), `:48-61` (`_loadLocations`), `:84-105` (`_editLocation`), `:220-226` (ipucu), `:230-264` (`_tile`)
- Modify: `lib/presentation/screens/location_edit_screen.dart:20-30` (alan + kurucu), `:75-107` (`_save` altına `_delete`), `:137-164` (`_buildForm`), import
- Modify: `lib/l10n/app_tr.arb` (`@locationDeleted` bloğundan sonra; `locationsSwipeHint` bloğu), `app_en.arb:229,412`, `app_ar.arb:229,412`
- Test: `test/widgets/screens/location_list_screen_test.dart` (yeni grup), `test/widgets/screens/location_edit_screen_test.dart` (iki test)

**Interfaces:**
- Consumes: `showRowActionsSheet`, `DeleteActionButton`, `GroupedRow.onLongPress` (Task 4); mevcut `_deleteLocation(Location)` (onaysız siler, "Geri al" aynı id ile geri yazar); `LocationRepository(storage:)`, `PlacesApi(client:, baseUrl:)`, `GpsLocationService(api:)`, `FakeStorage` (`test/support/fakes.dart`).
- Produces:
  - `LocationEditScreen({Key? key, required LocationRepository locationRepository, required PlacesApi placesApi, required Location location, VoidCallback? onDelete})`; `final VoidCallback? onDelete;` — verilince "Kaydet"in hemen altında kartsız (`framed: false`) "Konumu sil"; ilçe seçici açıkken çizilmez. Dönüş türü (`Location?`) değişmez.
  - Liste: aktif olmayan satırda `onLongPress` → menü (başlık `location.displayName`, yalnız Sil); aktif satırda `onLongPress` ve `onDelete` verilmez.
  - `l10n.locationDeleteAction`, `l10n.locationsLongPressHint` (`locationsSwipeHint` kalkar).

- [ ] **Step 1: Ekran testi yaz (önce kırmızı)**

`test/widgets/screens/location_list_screen_test.dart` — import listesini şununla değiştir:

```dart
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/features/location/data/gps_location_service.dart';
import 'package:ezanvakti/features/location/data/places_api.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/presentation/screens/location_edit_screen.dart';
import 'package:ezanvakti/presentation/screens/location_list_screen.dart';
import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ezanvakti/l10n/l10n_extensions.dart';

import '../../support/fakes.dart';
import '../../support/l10n_helper.dart';
import '../theme_harness.dart';
```

`main` sonuna (son `testWidgets`'tan sonra):

```dart
  group('Ekran', () {
    const active = Location(
      id: 'kadikoy',
      province: 'İstanbul',
      district: 'Kadıköy',
    );
    const other = Location(
      id: 'uskudar',
      province: 'İstanbul',
      district: 'Üsküdar',
    );
    late FakeStorage storage;
    late PlacesApi placesApi;

    setUp(() async {
      storage = FakeStorage();
      await storage.saveLocation(active);
      await storage.saveLocation(other);
      placesApi = PlacesApi(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'https://t',
      );
    });

    Future<void> pumpList(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          LocationListScreen(
            locationRepository: LocationRepository(storage: storage),
            placesApi: placesApi,
            gpsService: GpsLocationService(api: placesApi),
            currentLocation: active,
            onLocationSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<List<String>> savedIds() async => [
      for (final location in await storage.getSavedLocations()) location.id,
    ];

    testWidgets('Kayitli konumlar listelenir', (tester) async {
      await pumpList(tester);

      expect(find.text('Kadıköy, İstanbul'), findsOneWidget);
      expect(find.text('Üsküdar, İstanbul'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/screens/location_list_screen_test.dart`
Expected: FAIL — `dependOnInheritedWidgetOfExactType<_LocalizationsScope>() ... was called before _LocationListScreenState.initState() completed`: `_loadLocations` initState içinden çağrılıyor ve ilk satırında `context.l10n` okuyor. Hata async fonksiyonun Future'ına düşer, liste hiç yüklenmez. (Release derlemede assert olmadığı için cihazda görünmüyordu; ekranın bugüne kadar widget testi yoktu.) Bu hata görünmezse Step 3 yine uygulanır, zararsızdır; kırmızıyı Step 5'teki testler verir.

- [ ] **Step 3: `_loadLocations` çeviriyi ilk await'ten sonra okur**

`lib/presentation/screens/location_list_screen.dart` — `_loadLocations`'ı şununla değiştir:

```dart
  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    try {
      final locations = await widget.locationRepository.getSavedLocations();
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // initState'ten çağrılıyor: çeviri ancak ilk await'ten sonra okunur.
      _showSnackBar(context.l10n.locationsLoadFailed(e), isError: true);
    }
  }
```

Run: `flutter test test/widgets/screens/location_list_screen_test.dart`
Expected: PASS.

```bash
dart format lib/presentation/screens/location_list_screen.dart test/widgets/screens/location_list_screen_test.dart
git add lib/presentation/screens/location_list_screen.dart test/widgets/screens/location_list_screen_test.dart
git commit -m "fix(ui): konum listesi çeviriyi initState içinde okumaz" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4: Silme testlerini yaz (önce kırmızı)**

`test/widgets/screens/location_list_screen_test.dart` — `group('Ekran', ...)` içinde `testWidgets('Kayitli konumlar listelenir', ...)` testinin altına:

```dart
    testWidgets(
      'Kaydırma yok; aktif olmayan konumda menü siler, Geri al geri getirir',
      (tester) async {
        await pumpList(tester);
        expect(find.byType(Dismissible), findsNothing);
        expect(
          find.text('Aktif olmayan konumu silmek için satıra basılı tut.'),
          findsOneWidget,
        );

        await tester.longPress(find.text('Üsküdar, İstanbul'));
        await tester.pumpAndSettle();
        expect(find.text('ÜSKÜDAR, İSTANBUL'), findsOneWidget);
        expect(find.text('Kopyala'), findsNothing);
        await tester.tap(find.text('Sil'));
        await tester.pumpAndSettle();

        expect(await savedIds(), ['kadikoy']);
        expect(find.text('Üsküdar, İstanbul'), findsNothing);

        await tester.tap(find.text('Geri al'));
        await tester.pumpAndSettle();
        expect(await savedIds(), containsAll(['kadikoy', 'uskudar']));
        expect(find.text('Üsküdar, İstanbul'), findsOneWidget);
      },
    );

    testWidgets('Aktif konumda basılı tutma menü açmaz', (tester) async {
      await pumpList(tester);

      await tester.longPress(find.text('Kadıköy, İstanbul'));
      await tester.pumpAndSettle();

      expect(find.text('Sil'), findsNothing);
    });

    testWidgets(
      '"Konumu sil" yalnız aktif olmayan konumda; ekranı kapatıp siler',
      (tester) async {
        await pumpList(tester);
        Finder editIconOf(String name) => find.descendant(
          of: find.widgetWithText(GroupedRow, name),
          matching: find.byIcon(Icons.edit_outlined),
        );

        await tester.tap(editIconOf('Kadıköy, İstanbul'));
        await tester.pumpAndSettle();
        expect(find.byType(LocationEditScreen), findsOneWidget);
        expect(find.text('Konumu sil'), findsNothing);
        Navigator.of(tester.element(find.byType(LocationEditScreen))).pop();
        await tester.pumpAndSettle();

        await tester.tap(editIconOf('Üsküdar, İstanbul'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Konumu sil'));
        await tester.pumpAndSettle();

        expect(find.byType(LocationEditScreen), findsNothing);
        expect(await savedIds(), ['kadikoy']);
        expect(find.text('Geri al'), findsOneWidget);
      },
    );
```

`test/widgets/screens/location_edit_screen_test.dart`:

Import listesine ekle:

```dart
import 'package:ezanvakti/presentation/widgets/common/delete_action_button.dart';
```

`main` sonuna (son `testWidgets`'tan sonra):

```dart
  testWidgets('onDelete verilmezse "Konumu sil" çizilmez', (tester) async {
    await openScreen(tester);

    expect(find.byType(DeleteActionButton), findsNothing);
  });

  testWidgets(
    '"Konumu sil" Kaydet altında kartsız; önce ekranı kapatır, sonra onDelete',
    (tester) async {
      late MaterialPageRoute<Location> route;
      bool? routeActiveAtDelete;
      var returned = false;
      Location? result = _sile;
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                route = MaterialPageRoute<Location>(
                  builder: (_) => LocationEditScreen(
                    locationRepository: LocationRepository(storage: storage),
                    placesApi: PlacesApi(
                      client: MockClient((req) async => _silivri(req)),
                      baseUrl: 'https://t',
                    ),
                    location: _sile,
                    onDelete: () => routeActiveAtDelete = route.isActive,
                  ),
                );
                result = await Navigator.of(context).push(route);
                returned = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<DeleteActionButton>(find.byType(DeleteActionButton)).framed,
        isFalse,
      );
      expect(
        tester.getTopLeft(find.text('Konumu sil')).dy,
        greaterThan(tester.getTopLeft(find.text('Kaydet')).dy),
      );

      await tester.tap(find.text('Konumu sil'));
      // İkinci dokunuş aynı karede gelir; alttaki ekran kapanmamalı.
      await tester.tap(find.text('Konumu sil'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(routeActiveAtDelete, isFalse, reason: 'önce pop, sonra silme');
      expect(find.text('open'), findsOneWidget, reason: 'alttaki ekran kapanmaz');
      expect(returned, isTrue);
      expect(result, isNull);
      expect(find.byType(LocationEditScreen), findsNothing);
      expect(
        await storage.getSavedLocations(),
        hasLength(1),
        reason: 'silmeyi ekran değil çağıran yapar',
      );
    },
  );
```

- [ ] **Step 5: Kırmızıyı gör**

Run: `flutter test test/widgets/screens/location_list_screen_test.dart test/widgets/screens/location_edit_screen_test.dart`
Expected: FAIL — `location_edit_screen_test.dart` derlenmez (`LocationEditScreen`'de `onDelete` yok); listede `Dismissible` bulunur, ipucu eski metin, basılı tutma menü açmaz, "Konumu sil" yok.

- [ ] **Step 6: ARB anahtarları**

`lib/l10n/app_tr.arb` — `@locationDeleted` bloğundan hemen sonra (`"androidChannelName"` satırından önce):

```json
  "locationDeleteAction": "Konumu sil",
  "@locationDeleteAction": {
    "description": "Konum düzenleme ekranında Kaydet'in altındaki silme düğmesi; aktif konumda görünmez."
  },
```

Aynı dosyada şu bloğu:

```json
  "locationsSwipeHint": "Aktif olmayan konumu silmek için satırı sola kaydırın.",
  "@locationsSwipeHint": {
    "description": "İpucu"
  },
```

şununla değiştir:

```json
  "locationsLongPressHint": "Aktif olmayan konumu silmek için satıra basılı tut.",
  "@locationsLongPressHint": {
    "description": "Konum listesinin altındaki ipucu: basılı tutma menüsü (Sil)."
  },
```

`lib/l10n/app_en.arb` — `"locationDeleted": "{location} deleted",` satırının altına:

```json
  "locationDeleteAction": "Delete location",
```

ve `"locationsSwipeHint": ...` satırını şununla değiştir:

```json
  "locationsLongPressHint": "Touch and hold a row to delete a location that is not active.",
```

`lib/l10n/app_ar.arb` — `"locationDeleted": "تم حذف {location}",` satırının altına:

```json
  "locationDeleteAction": "حذف الموقع",
```

ve `"locationsSwipeHint": ...` satırını şununla değiştir:

```json
  "locationsLongPressHint": "اضغط مطولاً على الصف لحذف موقع غير نشط.",
```

Run: `flutter gen-l10n`

- [ ] **Step 7: `LocationEditScreen`**

`lib/presentation/screens/location_edit_screen.dart`:

Import listesine (`'../widgets/common/app_surface.dart'` satırının altına):

```dart
import '../widgets/common/delete_action_button.dart';
```

Alan ve kurucu — şu bloğu:

```dart
  final Location location;

  const LocationEditScreen({
    super.key,
    required this.locationRepository,
    required this.placesApi,
    required this.location,
  });
```

şununla değiştir:

```dart
  final Location location;

  /// Verilirse "Kaydet"in altında "Konumu sil" çizilir. Aktif konum
  /// silinemez; liste o konum için bunu vermez.
  final VoidCallback? onDelete;

  const LocationEditScreen({
    super.key,
    required this.locationRepository,
    required this.placesApi,
    required this.location,
    this.onDelete,
  });
```

`_withoutCustomName` statik metodunun hemen üstüne:

```dart
  /// Önce ekran kapanır, sonra silinir: "Geri al" çubuğu listenin üstünde
  /// çıkar. Konum dönmez; çağıranın "sonuç yoksa çık" dalı buna uyar.
  void _delete() {
    // Art arda iki dokunuş alttaki listeyi de kapatmasın.
    if (_deleting) return;
    _deleting = true;
    Navigator.of(context).pop();
    widget.onDelete!();
  }

  bool _deleting = false;

```

`_buildForm` sonundaki:

```dart
        const SizedBox(height: 12),
        _buildSaveButton(),
      ],
    );
  }
```

bloğunu şununla değiştir:

```dart
        const SizedBox(height: 12),
        _buildSaveButton(),
        if (widget.onDelete != null) ...[
          const SizedBox(height: 6),
          DeleteActionButton(
            context.l10n.locationDeleteAction,
            _delete,
            framed: false,
          ),
        ],
      ],
    );
  }
```

- [ ] **Step 8: Liste — menü, `onDelete`, ipucu**

`lib/presentation/screens/location_list_screen.dart`:

`import '../widgets/common/swipe_to_delete.dart';` satırını şununla değiştir:

```dart
import '../widgets/common/row_actions_sheet.dart';
```

`_editLocation` başını — şu bloğu:

```dart
  Future<void> _editLocation(Location location) async {
    final updated = await Navigator.push<Location>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationEditScreen(
          locationRepository: widget.locationRepository,
          placesApi: widget.placesApi,
          location: location,
        ),
      ),
    );
```

şununla değiştir:

```dart
  Future<void> _editLocation(Location location) async {
    final isActive = widget.currentLocation?.id == location.id;
    final updated = await Navigator.push<Location>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationEditScreen(
          locationRepository: widget.locationRepository,
          placesApi: widget.placesApi,
          location: location,
          // Aktif konum silinemez; düğme de çizilmez.
          onDelete: isActive ? null : () => _deleteLocation(location),
        ),
      ),
    );
```

`_buildBody` içindeki `context.l10n.locationsSwipeHint,` satırını şununla değiştir:

```dart
          context.l10n.locationsLongPressHint,
```

`_tile`'ı (doc yorumu dahil) şununla değiştir:

```dart
  /// Aktif konum silinemez: basılı tutma menüsü açılmaz, sağında AKTİF rozeti
  /// durur. Sağdaki düzenleme ikonu her satırda düzenlemeyi açar.
  Widget _tile(Location location) {
    final isActive = widget.currentLocation?.id == location.id;
    return GroupedRow(
      icon: location.type == LocationType.gps
          ? Icons.my_location_rounded
          : Icons.location_on_rounded,
      title: Text(location.displayName),
      subtitle: Text(context.l10n.locationTypeLabel(location.type)),
      onTap: isActive
          ? null
          : () {
              widget.onLocationSelected(location);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
      onLongPress: isActive
          ? null
          : () => showRowActionsSheet(
              context,
              title: location.displayName,
              onDelete: () => _deleteLocation(location),
            ),
      // Aktif konum da duzenlenebilmeli (ozel ad); rozet duzenleme ikonunun
      // yerini almaz, yanina gelir.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[_activeBadge(), const SizedBox(width: 8)],
          _editButton(location),
        ],
      ),
    );
  }
```

- [ ] **Step 9: Yeşili gör**

Run: `flutter test test/widgets/screens/location_list_screen_test.dart test/widgets/screens/location_edit_screen_test.dart test/widgets/location_edit_switch_test.dart test/widgets/grouped_list_test.dart test/l10n/arb_consistency_test.dart`
Expected: PASS. `grep -rn locationsSwipeHint lib test` boş dönmeli.

- [ ] **Step 10: Biçimlendir ve commit'le**

```bash
dart format lib/presentation/screens/location_list_screen.dart lib/presentation/screens/location_edit_screen.dart test/widgets/screens/location_list_screen_test.dart test/widgets/screens/location_edit_screen_test.dart
git add lib/l10n/app_tr.arb lib/l10n/app_en.arb lib/l10n/app_ar.arb lib/l10n/app_localizations*.dart lib/presentation/screens/location_list_screen.dart lib/presentation/screens/location_edit_screen.dart test/widgets/screens/location_list_screen_test.dart test/widgets/screens/location_edit_screen_test.dart
git commit -m "feat(ui): konumda basılı tutma menüsü ve Konumu sil düğmesi" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Sessiz aralıklar — özel satırda menü, panelde "Aralığı sil", "Geri al"

**Files:**
- Modify: `lib/presentation/screens/quiet_windows_screen.dart:15` (import), `:54-58` (`_persist`), `:97-99` (`_delete`, yeni `_restore`, `_showUndo`), `:211-235` (`_customRow`), `:237-284` (`_editCustom` panel sonu)
- Modify: `lib/l10n/app_tr.arb` (`@quietWindowDurationSummary` bloğundan sonra), `app_en.arb:468`, `app_ar.arb:468`
- Test: `test/widgets/screens/quiet_windows_screen_test.dart` (yeni; ekranın bugüne kadar testi yok)

**Interfaces:**
- Consumes: `showRowActionsSheet`, `DeleteActionButton`, `GroupedRow.onLongPress` (Task 4); `LocalStorage.getQuietWindows/saveQuietWindows` (`ServiceLocator` üzerinden); `FakeStorage` (`test/support/fakes.dart`).
- Produces:
  - `_delete(QuietWindow)` onaysız siler ve "Sessiz aralık silindi · Geri al" gösterir; `_restore(QuietWindow, int index)` kaydı aynı id ile, silindiği sıraya (`_windows` içindeki index, Cuma kaydı dahil) geri yazar. Güncel liste depodan okunur: çubuk ekran kapandıktan sonra da dokunulabilir (ScaffoldMessenger çubuğu alttaki ekranda tutar).
  - `_persist` ekran kapalıyken `setState` çağırmaz; kayıt ve `onChanged` (yeniden planlama) yine yapılır.
  - Menü başlığı: vakit adı + süre özeti ("Öğle · 10 dk önce – 30 dk sonra"); yalnız Sil. Cuma kartında menü yok.
  - `l10n.quietWindowDeleteAction`, `l10n.quietWindowDeleted`.

- [ ] **Step 1: Testleri yaz (önce kırmızı)**

Create `test/widgets/screens/quiet_windows_screen_test.dart`:

```dart
import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/notification_setting.dart'
    show PrayerType;
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/presentation/screens/quiet_windows_screen.dart';
import 'package:ezanvakti/presentation/widgets/common/delete_action_button.dart';
import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

void main() {
  const dhuhr = QuietWindow(
    id: 'q1',
    trigger: QuietTrigger.prayer,
    prayerType: PrayerType.dhuhr,
    minutesBefore: 10,
    minutesAfter: 30,
  );
  const asr = QuietWindow(
    id: 'q2',
    trigger: QuietTrigger.prayer,
    prayerType: PrayerType.asr,
    minutesBefore: 5,
    minutesAfter: 20,
  );

  late FakeStorage storage;
  late int changes;

  setUp(() async {
    storage = FakeStorage();
    await storage.init();
    changes = 0;
    ServiceLocator().register<LocalStorage>(storage);
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    List<QuietWindow> windows,
  ) async {
    await storage.saveQuietWindows(windows);
    await tester.pumpWidget(
      wrapWithTheme(QuietWindowsScreen(onChanged: () async => changes++)),
    );
    await tester.pumpAndSettle();
  }

  Future<List<String>> savedIds() async => [
    for (final window in await storage.getQuietWindows()) window.id,
  ];

  testWidgets(
    'Kaydırma yok; menü vakit ve süreyi yazar, Sil siler, Geri al eski sırasına koyar',
    (tester) async {
      await pumpScreen(tester, [QuietWindow.fridayDefault(), dhuhr, asr]);
      expect(find.byType(Dismissible), findsNothing);

      await tester.longPress(find.widgetWithText(GroupedRow, 'Öğle'));
      await tester.pumpAndSettle();
      expect(find.text('ÖĞLE · 10 DK ÖNCE – 30 DK SONRA'), findsOneWidget);
      expect(find.text('Kopyala'), findsNothing);
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(await savedIds(), ['friday', 'q2']);
      expect(find.widgetWithText(GroupedRow, 'Öğle'), findsNothing);
      expect(find.text('Sessiz aralık silindi'), findsOneWidget);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(await savedIds(), ['friday', 'q1', 'q2']);
      expect(find.widgetWithText(GroupedRow, 'Öğle'), findsOneWidget);
      expect(changes, 2, reason: 'silme ve geri alma ikisi de yeniden planlar');
    },
  );

  testWidgets('Cuma kartında basılı tutma menü açmaz', (tester) async {
    await pumpScreen(tester, [QuietWindow.fridayDefault(), dhuhr]);

    await tester.longPress(find.text('Cuma vaktinde sessiz'));
    await tester.pumpAndSettle();

    expect(find.text('Sil'), findsNothing);
  });

  testWidgets(
    'Paneldeki "Aralığı sil" paneli kapatır ve siler; Geri al geri getirir',
    (tester) async {
      await pumpScreen(tester, [dhuhr, asr]);

      await tester.tap(find.text('İkindi'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DeleteActionButton>(find.byType(DeleteActionButton))
            .framed,
        isTrue,
      );
      await tester.tap(find.text('Aralığı sil'));
      // İkinci dokunuş aynı karede gelir; ekran kapanmamalı.
      await tester.tap(find.text('Aralığı sil'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(QuietWindowsScreen), findsOneWidget);
      expect(await savedIds(), ['q1']);
      expect(find.text('Sessiz aralık silindi'), findsOneWidget);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(await savedIds(), ['q1', 'q2']);
    },
  );
}
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/screens/quiet_windows_screen_test.dart`
Expected: FAIL — `Dismissible` bulunur; basılı tutma menü açmaz; panelde "Aralığı sil" (`DeleteActionButton`) yok; "Sessiz aralık silindi" çubuğu yok.

- [ ] **Step 3: ARB anahtarları**

`lib/l10n/app_tr.arb` — `@quietWindowDurationSummary` bloğundan hemen sonra (`"durationAgo"` satırından önce):

```json
  "quietWindowDeleteAction": "Aralığı sil",
  "@quietWindowDeleteAction": {
    "description": "Sessiz aralık düzenleme panelinin en altındaki silme düğmesi."
  },
  "quietWindowDeleted": "Sessiz aralık silindi",
  "@quietWindowDeleted": {
    "description": "Sessiz aralık silinince çıkan çubuk; yanında \"Geri al\" durur."
  },
```

`lib/l10n/app_en.arb` — `"quietWindowDurationSummary": "{before} before – {after} after",` satırının altına:

```json
  "quietWindowDeleteAction": "Delete window",
  "quietWindowDeleted": "Quiet window deleted",
```

`lib/l10n/app_ar.arb` — `"quietWindowDurationSummary": "قبل {before} – بعد {after}",` satırının altına:

```json
  "quietWindowDeleteAction": "حذف الفترة",
  "quietWindowDeleted": "تم حذف فترة الصمت",
```

Run: `flutter gen-l10n`

- [ ] **Step 4: Silme, geri alma ve çubuk**

`lib/presentation/screens/quiet_windows_screen.dart`:

`import '../widgets/common/swipe_to_delete.dart';` satırını şununla değiştir:

```dart
import '../widgets/common/delete_action_button.dart';
import '../widgets/common/row_actions_sheet.dart';
```

`_persist`'i şununla değiştir:

```dart
  Future<void> _persist(List<QuietWindow> next) async {
    // "Geri al" ekran kapandıktan sonra da gelebilir: çubuk alttaki ekranda
    // kalır. Kayıt ve yeniden planlama yine yapılır.
    if (mounted) {
      setState(() => _windows = next);
    } else {
      _windows = next;
    }
    await _storage.saveQuietWindows(next);
    await widget.onChanged?.call();
  }
```

`_delete`'i şununla değiştir ve altına iki metot ekle:

```dart
  /// Onay sormadan siler; "Geri al" kaydı eski sırasına geri koyar
  /// (spec 2026-09-28 §3.3).
  Future<void> _delete(QuietWindow window) async {
    final l10n = context.l10n;
    final index = _windows.indexWhere((w) => w.id == window.id);
    if (index < 0) return;
    await _persist([..._windows]..removeAt(index));
    _showUndo(l10n.quietWindowDeleted, () => _restore(window, index));
  }

  /// Silinen aralığı aynı kimlikle, silindiği sıraya geri yazar. Güncel liste
  /// depodan okunur: çubuğa ekran kapandıktan sonra da dokunulabilir.
  Future<void> _restore(QuietWindow window, int index) async {
    final current = await _storage.getQuietWindows();
    if (current.any((w) => w.id == window.id)) return;
    final next = [...current];
    next.insert(index > next.length ? next.length : index, window);
    await _persist(next);
  }

  void _showUndo(String message, VoidCallback onUndo) {
    if (!mounted) return;
    // Onceki cubugu hemen kaldir; yeni mesaj beklemeden gorunsun.
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: context.l10n.snackUndo,
          textColor: Colors.white,
          onPressed: onUndo,
        ),
        backgroundColor: context.tokens.accent,
        // Eylemli snackbar varsayilan olarak kalici (`persist = action !=
        // null`); sure dolunca kendiliginden kalksin.
        persist: false,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        actionOverflowThreshold: 0.5,
      ),
    );
  }
```

- [ ] **Step 5: Özel satırda menü**

`_customRow`'u şununla değiştir:

```dart
  Widget _customRow(QuietWindow window) {
    final tokens = context.tokens;
    final name = context.l10n.prayerName(window.prayerType ?? PrayerType.dhuhr);
    final duration = context.l10n.quietWindowDurationSummary(
      formatCompactMinutes(window.minutesBefore, context.l10n),
      formatCompactMinutes(window.minutesAfter, context.l10n),
    );

    return GroupedRow(
      // Silinince anahtarlar komşu satıra kaymasın.
      key: ValueKey(window.id),
      icon: Icons.notifications_off_rounded,
      title: Text(name),
      subtitle: Text(
        '$duration · '
        '${window.mode == QuietMode.skip ? context.l10n.quietModeSkip : context.l10n.quietModeSilent}',
      ),
      dimmed: !window.isActive,
      onTap: () => _editCustom(window),
      // Cuma kartında menü yok; yalnız özel aralıklar silinir.
      onLongPress: () => showRowActionsSheet(
        context,
        title: '$name · $duration',
        onDelete: () => _delete(window),
      ),
      trailing: Switch(
        value: window.isActive,
        activeThumbColor: tokens.accent,
        onChanged: (value) =>
            _updateWindow(window, window.copyWith(isActive: value)),
      ),
    );
  }
```

- [ ] **Step 6: Panelin altında "Aralığı sil"**

`_editCustom`'ın ilk satırına (`await showModalBottomSheet<void>(` çağrısından önce) ekle; bayrak panel yeniden çizilse de korunur:

```dart
    var deleting = false;
```

Sonra `_editCustom` içindeki panel sütununun sonunu — şu bloğu:

```dart
                  _rangeRow(current, onChanged: () => setSheetState(() {})),
                  _modeRow(current, onChanged: () => setSheetState(() {})),
                ],
```

şununla değiştir:

```dart
                  _rangeRow(current, onChanged: () => setSheetState(() {})),
                  _modeRow(current, onChanged: () => setSheetState(() {})),
                  const SizedBox(height: 20),
                  DeleteActionButton(
                    context.l10n.quietWindowDeleteAction,
                    () {
                      // Önce panel kapanır, sonra silinir: "Geri al" çubuğu
                      // listenin üstünde çıkar. Art arda iki dokunuş alttaki
                      // ekranı da kapatmasın.
                      if (deleting) return;
                      deleting = true;
                      Navigator.pop(sheetContext);
                      _delete(current);
                    },
                  ),
                ],
```

- [ ] **Step 7: Yeşili gör**

Run: `flutter test test/widgets/screens/quiet_windows_screen_test.dart test/l10n/arb_consistency_test.dart test/l10n/no_hardcoded_turkish_test.dart`
Expected: PASS.

- [ ] **Step 8: Biçimlendir ve commit'le**

```bash
dart format lib/presentation/screens/quiet_windows_screen.dart test/widgets/screens/quiet_windows_screen_test.dart
git add lib/l10n/app_tr.arb lib/l10n/app_en.arb lib/l10n/app_ar.arb lib/l10n/app_localizations*.dart lib/presentation/screens/quiet_windows_screen.dart test/widgets/screens/quiet_windows_screen_test.dart
git commit -m "feat(ui): sessiz aralıkta basılı tutma menüsü, panelde silme ve geri al" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: `SwipeToDelete` silinir; satır üstünde yatay hareket sekmeye kalır

**Files:**
- Delete: `lib/presentation/widgets/common/swipe_to_delete.dart`
- Modify: `test/widgets/screens/home_page_nav_test.dart:3` (import), `:118-132` (`_ReminderTab` satırları), `:248-257` (test)

**Interfaces:**
- Consumes: `MainTabScaffold`, `ReminderList` (değişmez).
- Produces: `SwipeToDelete` sınıfı kalkar; `lib` ve `test` içinde referansı kalmaz. Test kabuğundaki satırlar gerçek satırlar gibi dokunma + basılı tutma dinler.

Not (Faz 1): bu test dosyası `HomeScreen`'i kurmuyor, yalnız `MainTabScaffold` + `ReminderList`; Faz 1'in `HomeScreen` / `UpcomingCard` değişiklikleri bu dosyayı etkilemez.

- [ ] **Step 1: Testi değiştir (önce kırmızı)**

`test/widgets/screens/home_page_nav_test.dart` — şu testi:

```dart
  testWidgets('Satır swipe siler ve ana sekmeyi değiştirmez', (tester) async {
    await tester.pumpWidget(reminderShell());

    await tester.drag(find.text('satır-1'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 2);
    expect(find.text('satır-1'), findsNothing);
    expect(find.text('satır-2').hitTestable(), findsOneWidget);
  });
```

şununla değiştir:

```dart
  testWidgets('Satır üstündeki yatay hareket sekme değiştirir, satırı silmez', (
    tester,
  ) async {
    await tester.pumpWidget(reminderShell());
    expect(find.byType(Dismissible), findsNothing);

    await tester.drag(find.text('satır-1'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 3);

    await tester.tap(find.text('Hatırlatıcılar'));
    await tester.pumpAndSettle();
    expect(find.text('satır-1').hitTestable(), findsOneWidget);
  });
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/screens/home_page_nav_test.dart`
Expected: FAIL — test kabuğu satırları hâlâ `SwipeToDelete` ile sarıyor: `Dismissible` bulunur; sürükleme satırı siler ve sekme 2'de kalır.

- [ ] **Step 3: Kabuk satırları gerçek satırlar gibi olsun**

Aynı dosyada `import 'package:ezanvakti/presentation/widgets/common/swipe_to_delete.dart';` satırını sil.

`_ReminderTabState.build` içindeki `else` dalını — şu bloğu:

```dart
          else
            SwipeToDelete(
              itemKey: ValueKey(row),
              onDelete: () => setState(() => _rows.remove(row)),
              child: SizedBox(height: 80, child: Center(child: Text(row))),
            ),
```

şununla değiştir:

```dart
          else
            // Gerçek satırlar gibi dokunma ve basılı tutma dinler; yatay
            // hareket yine de sekme geçişine kalmalı.
            Material(
              key: ValueKey(row),
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () {},
                onLongPress: () {},
                child: SizedBox(height: 80, child: Center(child: Text(row))),
              ),
            ),
```

Run: `flutter test test/widgets/screens/home_page_nav_test.dart`
Expected: PASS (dosyadaki tüm testler).

- [ ] **Step 4: `SwipeToDelete`'i sil ve referans kalmadığını doğrula**

```bash
git rm lib/presentation/widgets/common/swipe_to_delete.dart
grep -rn "SwipeToDelete\|swipe_to_delete\|SwipeHint" lib test
```

Expected: `grep` boş döner. Üretilen `lib/l10n/app_localizations*.dart` dosyaları da dahil: eski ipucu anahtarları Task 5–Task 7'te yeniden adlandırıldı.

- [ ] **Step 5: Tam doğrulama**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: tüm suite PASS (ortak davranış değişti: dört liste, üç düzenleme ekranı).

- [ ] **Step 6: Biçimlendir ve commit'le**

```bash
dart format test/widgets/screens/home_page_nav_test.dart
# Dosya silinmesi Step 4'teki `git rm` ile zaten sahnede.
git add test/widgets/screens/home_page_nav_test.dart
git commit -m "refactor(ui): SwipeToDelete kaldırıldı; satır üstündeki yatay hareket sekmeye kalır" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Silme bölümü — spec §8 karşılığı

| Spec §8 maddesi | Test |
|---|---|
| Dört listede `Dismissible` yok | Task 5 `alarms_section_test`, Task 6 `notifications_section_test`, Task 7 `location_list_screen_test`, Task 8 `quiet_windows_screen_test`, Task 9 `home_page_nav_test` |
| Basılı tutma menüsü açılır, Sil siler, "Geri al" geri getirir | Task 5/Task 6 `reminders_screen_test` (`deleteByLongPress` + `'Silinen alarm "Geri al" ile geri gelir'`, `'Bildirim silinince AppState tazelenir'`), Task 7 liste, Task 8 sessiz aralık (sıra korunur) |
| Düzenleme ekranında düğme yalnız `onDelete` ile; basınca ekran kapanır ve `onDelete` çağrılır (önce pop) | Task 5 `alarm_edit_screen_test`, Task 6 `notification_edit_screen_test`, Task 7 `location_edit_screen_test` (`route.isActive` onDelete anında `false`), Task 8 panel |
| Aktif konumda menü ve düğme yok | Task 7 `'Aktif konumda basılı tutma menü açmaz'`, `'"Konumu sil" yalnız aktif olmayan konumda'` |
| Reorder kipinde basılı tutma kapalı | Task 5, Task 6 section testleri |
| "Satır swipe siler" testi kalkar, satır üstünde sekme kaydırması testi gelir | Task 9 |

Test edilmeyen: basılı tutma süresi ve titreşim hissi, alt sayfanın açık/koyu temadaki görünüşü, büyük metin ve RTL'de menü/düğme yerleşimi (§5), "Geri al" çubuğunun ekran kapandıktan sonra alttaki ekranda kalması. Bunlar cihazda Ekrem'in kontrolünde.

---

## Faz 3 — Aylık Vakit Takvimi (K6)

Yürütme sırası: Faz 1 ve Faz 2'den **sonra**. Task 10–Task 13 birbirinden bağımsız derlenir ve commit'lenir; Task 14 ekranın kurucusunu değiştirdiği için bütün çağıranları aynı task'ta günceller; Task 15, Task 14'in kullanılmaz bıraktığı ekran yakalamalı paylaşımı kaldırır.

### Dosya haritası

| Dosya | Sorumluluk | Değişiklik |
|---|---|---|
| `lib/features/prayer_times/domain/calendar_month_repository.dart` (yeni) | ay yükleyici | `CalendarMonthLoader` typedef, `CalendarMonthRepository.load` (ayın 1'i–son günü, sıralı, tekrarsız) |
| `lib/presentation/controllers/calendar_month_controller.dart` (yeni) | ay durumu | seçili ay, aralık (bu yıl Ocak – gelecek yıl Aralık), nesil sayacı, yükleniyor / yayımlanmadı / hata |
| `lib/presentation/widgets/calendar/calendar_table.dart` | ekran tablosu | `StatefulWidget`; geçmiş gün 0.5 opak; bugüne göre kısıtlı başlangıç konumu; `_CalendarRow` → public `CalendarDayRow` |
| `lib/presentation/widgets/calendar/calendar_month_share_table.dart` (yeni) | ay paylaşım görüntüsü | `CalendarMonthShareTable`, `calendarMonthLabel`, `kCalendarShareLogicalWidth` |
| `lib/presentation/screens/calendar_screen.dart` | ekran | yükleyici + controller; ay çubuğu; durumlar; ay paylaşımı; `prayerTimes`/`onRefresh`/`isLoading`/`errorMessage` kalkar |
| `lib/presentation/pages/home_page.dart` | bağlama | `_calendarMonthLoader`; `_openCalendar` yeni özellikleri geçirir |
| `lib/l10n/app_{tr,en,ar}.arb` + üretilen `app_localizations*.dart` | metinler | `calendarPreviousMonth`, `calendarNextMonth`, `calendarMonthUnavailable` |
| `lib/presentation/services/calendar_share_service.dart` | paylaşım | Task 15: kullanılmayan `shareTable` kalkar |
| `test/prayer_times/calendar_month_repository_test.dart` (yeni) | depo testi | aralık, `forceRefresh`, sıralama/tekrar, düzeltme, boş sonuç |
| `test/presentation/calendar_month_controller_test.dart` (yeni) | controller testi | aralık, sınırlar, eski yanıt, boş, hata, kaynak değişimi, dispose |
| `test/widgets/calendar/calendar_table_test.dart` | tablo testi | soluk geçmiş, başlangıç konumu (iOS kısıtlama dahil) |
| `test/widgets/calendar/calendar_month_share_table_test.dart` (yeni) | paylaşım tablosu testi | tüm satırlar, PNG son satır, 10000 px sınırı |
| `test/widgets/calendar/calendar_screen_test.dart` (yeni) | ekran testi | oklar, sınır, alt başlık, yükleniyor/boş/hata, RTL + büyük metin |
| `test/widgets/calendar/imsakiye_view_test.dart` | mevcut ekran testleri | `CalendarScreen(...)` çağrıları `monthLoader` alır |
| `test/presentation/calendar_share_service_test.dart` | servis testi | Task 15: `shareTable` testi kalkar |

### Tasarım kararları (bu bölüme özgü)

1. **Depo sıralar ve tekrarı eler.** Önce gün anahtarıyla tekrar elenir (ilk gelen kalır), sonra sıralanır: Dart'ın `List.sort`'u kararlı değildir, önce sıralamak hangi kopyanın kalacağını belirsiz bırakırdı. Eksik ay doğrulanmaz (imsakiyeden farklı): depo çevrimdışı yedekte kısmi önbellek dönerse eldeki günler gösterilir.
2. **Ay değişirken eski günler kalır.** Controller `days`'i yeni ay gelene kadar tutar; hangi aya ait oldukları `loadedMonth`'tadır. Konum ya da düzeltme değişince ve yükleme başarısız olunca `days` temizlenir; başka ayın ya da eski düzeltmenin tablosu yanlış etiketle görünmesin.
3. **Hata metni mevcut anahtardan.** Spec §4 hata için yeni anahtar tanımlamıyor; ağ yok + önbellek yok durumuna birebir uyan mevcut `offlineFetchFailed` ("Veri alınamadı. Lütfen internet bağlantınızı kontrol edin.") kullanılır.
4. **Tablo, gösterdiği günlerin ayıyla anahtarlanır** (`ValueKey(DateTime(days.first.date.year, days.first.date.month))`), seçili ayla değil. Seçili ayla anahtarlansaydı ok basılır basılmaz eski tablo yeni durumla kurulup başa atlardı. Yeni ay gelince yeni durum kurulur, başlangıç konumu yeniden hesaplanır (bugünü içeren ayda bugün, diğerlerinde en üst).
5. **Başlangıç konumu** `ScrollController(initialScrollOffset: ..., keepScrollOffset: false)` ile, ilk yerleşimde `LayoutBuilder` yüksekliğinden hesaplanıp `maxScrollExtent`'e kısıtlanır. Flutter 3.44.1 kaynağında doğrulandı: ilk yerleşimde konum düzeltilmez; boşta etkinlik `goBallistic(0)` çağırır, kaydırma alanını aşan konum iOS'ta (Bouncing) ve Android'de (Clamping) görünür bir geri yaylanmaya dönüşürdü. `keepScrollOffset: false`, rotanın `PageStorage`'ından eski konumun `initialScrollOffset`'i ezmesini engeller.
6. **Ay okları `Icons.chevron_left_rounded` / `chevron_right_rounded` ile, `directional_icons` değiştirmesi olmadan.** Bu iki ikon `matchTextDirection: true` taşır; `Icon` RTL'de kendini aynalar ve `Row` "önceki"yi sağa koyar. `directional_icons`'taki gibi ayrıca ikon değiştirmek yönü iki kez çevirirdi (bkz. rapor "şüphe": mevcut `forwardChevron`/`backArrow` bu yüzden RTL'de ters olabilir).
7. **Paylaşım görüntüsü:** satırlar ekrandaki `CalendarDayRow`; `now: null` verilir, yani bugün rozeti ve soluk geçmiş günler yok (paylaşılan çizelge bir aylık başvuru tablosudur, alıcı onu başka bir gün açar). Tablo 400 mantıksal genişlikte yerleşir ve `FittedBox` ile renderer'ın 1000 px genişliğine 2.5 kat büyütülür; eski ekran yakalamasının `pixelRatio: 2.5` okunurluğu korunur. 31 satır ≈ 1906 × 2.5 ≈ 4765 px, 10000 px sınırının altında (Task 13 testi sınar).
8. **Task 15 temizliktir.** Task 14'ten sonra `CalendarShareService.shareTable` hiçbir yerden çağrılmaz; bu turun bıraktığı ölü kod ayrı commit'le kaldırılır. Task 14 ona bağlı değildir.

---

### Task 10: `CalendarMonthLoader` ve `CalendarMonthRepository`

**Files:**
- Create: `lib/features/prayer_times/domain/calendar_month_repository.dart`
- Test: `test/prayer_times/calendar_month_repository_test.dart` (yeni)

**Interfaces:**
- Consumes: `PrayerTimesRepository.getPrayerTimes({required Location location, required DateTime startDate, required DateTime endDate, bool forceRefresh = false})` (önbellek, gerektiğinde yıllık indirme, okuma anında düzeltme; 404'te sağlayıcı boş liste döner).
- Produces:
  - `typedef CalendarMonthLoader = Future<List<PrayerTime>> Function({required Location location, required DateTime month, bool forceRefresh});`
  - `class CalendarMonthRepository { CalendarMonthRepository(PrayerTimesRepository prayerTimes); Future<List<PrayerTime>> load({required Location location, required DateTime month, bool forceRefresh = false}); }` — `month` ayın herhangi bir günü olabilir; `startDate = DateTime(y, m, 1)`, `endDate = DateTime(y, m + 1, 0)`; sonuç tarihe göre sıralı, gün başına tek kayıt, değiştirilemez liste.

- [ ] **Step 1: Başarısız testi yaz**

`test/prayer_times/calendar_month_repository_test.dart`:

```dart
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/prayer_tune_settings.dart';
import 'package:ezanvakti/features/prayer_times/domain/calendar_month_repository.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

const location = Location(id: 'test', province: 'İstanbul', district: 'Fatih');

/// Istenen araligi takvim gunleriyle doner ve her istegi kaydeder.
class RecordingProvider extends FakeProvider {
  final requests = <({DateTime start, DateTime end})>[];

  /// Verilirse aralik yerine bu liste doner (sira ve tekrar testleri, 404).
  List<PrayerTime>? response;

  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    fetchCount++;
    requests.add((start: startDate, end: endDate));
    final failure = failWith;
    if (failure != null) throw failure;
    final fixed = response;
    if (fixed != null) return fixed;
    return [
      for (
        var day = DateTime(startDate.year, startDate.month, startDate.day);
        !day.isAfter(endDate);
        day = DateTime(day.year, day.month, day.day + 1)
      )
        prayerTimeFor(day),
    ];
  }
}

void main() {
  late FakeStorage storage;
  late RecordingProvider provider;
  late CalendarMonthRepository repository;

  setUp(() {
    storage = FakeStorage();
    provider = RecordingProvider();
    repository = CalendarMonthRepository(
      PrayerTimesRepository(provider: provider, storage: storage),
    );
  });

  test('ayin 1i ile son gununu ister; ay icindeki herhangi bir gun yeter', () async {
    final february = await repository.load(
      location: location,
      month: DateTime(2026, 2, 17),
    );
    expect(provider.requests.single, (
      start: DateTime(2026, 2, 1),
      end: DateTime(2026, 2, 28),
    ));
    expect(february.map((t) => t.date).toList(), [
      for (var day = 1; day <= 28; day++) DateTime(2026, 2, day),
    ]);

    final december = await repository.load(
      location: location,
      month: DateTime(2026, 12),
    );
    expect(provider.requests.last, (
      start: DateTime(2026, 12, 1),
      end: DateTime(2026, 12, 31),
    ));
    expect(december, hasLength(31));
  });

  test('forceRefresh onbellegi atlayip saglayiciya gider', () async {
    await repository.load(location: location, month: DateTime(2026, 9));
    await Future<void>.delayed(Duration.zero); // onbellek yazimi kuyrukta
    await repository.load(location: location, month: DateTime(2026, 9));
    expect(provider.fetchCount, 1, reason: 'ikinci okuma onbellekten');

    await repository.load(
      location: location,
      month: DateTime(2026, 9),
      forceRefresh: true,
    );
    expect(provider.fetchCount, 2);
  });

  test('sonuc tarihe gore siralanir, ayni gunun tekrari elenir (ilk gelen kalir)', () async {
    final first = prayerTimeFor(DateTime(2026, 9, 1));
    final duplicate = first.copyWith(
      fajr: first.fajr.add(const Duration(minutes: 9)),
    );
    provider.response = [
      prayerTimeFor(DateTime(2026, 9, 3)),
      first,
      prayerTimeFor(DateTime(2026, 9, 2)),
      duplicate,
    ];

    final days = await repository.load(
      location: location,
      month: DateTime(2026, 9),
    );

    expect(days.map((t) => t.date).toList(), [
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 2),
      DateTime(2026, 9, 3),
    ]);
    expect(days.first.fajr, first.fajr);
  });

  test('kullanici duzeltmesi okuma aninda uygulanir (ADR 0004)', () async {
    await storage.savePrayerTuneSettings(
      const PrayerTuneSettings(tune: {PrayerType.fajr: 3}),
    );
    final days = await repository.load(
      location: location,
      month: DateTime(2026, 9),
    );
    expect(days.first.fajr, DateTime(2026, 9, 1, 4, 14));
  });

  test('sunucu yili yayimlamamissa (404) bos liste doner, hata firlatmaz', () async {
    provider.response = const [];
    expect(
      await repository.load(location: location, month: DateTime(2027, 3)),
      isEmpty,
    );
  });
}
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/prayer_times/calendar_month_repository_test.dart`
Expected: FAIL — derleme hatası: `lib/features/prayer_times/domain/calendar_month_repository.dart` bulunamıyor (`CalendarMonthRepository` tanımlı değil).

- [ ] **Step 3: Uygula**

`lib/features/prayer_times/domain/calendar_month_repository.dart`:

```dart
import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import 'prayer_times_repository.dart';

/// Vakit Takvimi'nin bir ayını yükler. [month] ayın herhangi bir günü
/// olabilir.
typedef CalendarMonthLoader =
    Future<List<PrayerTime>> Function({
      required Location location,
      required DateTime month,
      bool forceRefresh,
    });

/// Takvimin ay ay okuması. Ayrı hesap yapmaz: önbellek, gerektiğinde yıllık
/// indirme ve kullanıcı düzeltmesi uygulamanın geri kalanıyla aynı kapıdan
/// geçer (ADR 0004). Bildirim/alarm penceresine dokunmaz; yalnız okur.
class CalendarMonthRepository {
  final PrayerTimesRepository _prayerTimes;
  CalendarMonthRepository(this._prayerTimes);

  /// Ayın 1'i ile son günü istenir. Sunucu o yılı henüz yayımlamamışsa
  /// (404) sağlayıcı boş liste döner; bu hata değil, "yayımlanmadı" durumudur.
  Future<List<PrayerTime>> load({
    required Location location,
    required DateTime month,
    bool forceRefresh = false,
  }) async {
    final times = await _prayerTimes.getPrayerTimes(
      location: location,
      startDate: DateTime(month.year, month.month, 1),
      endDate: DateTime(month.year, month.month + 1, 0),
      forceRefresh: forceRefresh,
    );
    return _normalized(times);
  }

  /// Tarihe göre sıralar, aynı günün tekrarını eler. Önce eleme yapılır
  /// (ilk gelen kalır): `List.sort` kararlı değil, önce sıralamak hangi
  /// kopyanın kalacağını belirsiz bırakırdı.
  static List<PrayerTime> _normalized(List<PrayerTime> times) {
    final byDay = <DateTime, PrayerTime>{};
    for (final time in times) {
      byDay.putIfAbsent(
        DateTime(time.date.year, time.date.month, time.date.day),
        () => time,
      );
    }
    final days = byDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(days);
  }
}
```

- [ ] **Step 4: Yeşili gör**

Run: `flutter test test/prayer_times/calendar_month_repository_test.dart`
Expected: PASS (5 test).

- [ ] **Step 5: Biçimlendir ve analiz et**

Run: `dart format lib/features/prayer_times/domain/calendar_month_repository.dart test/prayer_times/calendar_month_repository_test.dart && flutter analyze`
Expected: `No issues found!` (başlangıç temizse; yeni dosyalardan uyarı gelmemeli).

- [ ] **Step 6: Commit**

```bash
git add lib/features/prayer_times/domain/calendar_month_repository.dart test/prayer_times/calendar_month_repository_test.dart
git commit -m "$(cat <<'EOF'
feat(calendar): ay ay vakit okuyan CalendarMonthRepository

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: `CalendarMonthController`

**Files:**
- Create: `lib/presentation/controllers/calendar_month_controller.dart`
- Test: `test/presentation/calendar_month_controller_test.dart` (yeni)

**Interfaces:**
- Consumes: `CalendarMonthLoader` (Task 10), `AppLogger().warning(String, [Object?, StackTrace?])`.
- Produces:
  - `CalendarMonthController({required CalendarMonthLoader loader, required DateTime now})` — `month = DateTime(now.year, now.month)`, `firstMonth = DateTime(now.year)` (Ocak), `lastMonth = DateTime(now.year + 1, 12)`.
  - Alanlar: `final CalendarMonthLoader loader; final DateTime firstMonth; final DateTime lastMonth; List<PrayerTime> days; Object? error; bool isLoading;` (imsakiye kalıbı: public alan).
  - Getter'lar: `DateTime get month`, `DateTime? get loadedMonth`, `bool get canGoPrevious`, `bool get canGoNext`, `bool get canShare` (`!isLoading && loadedMonth == month && days.isNotEmpty`), `bool get isUnavailable` (`!isLoading && error == null && loadedMonth == month && days.isEmpty`).
  - Metotlar: `Future<void> updateSource(Location location, Object revision)`, `Future<void> selectMonth(DateTime month)` (ay başına normalize; aralık dışı ve aynı ay no-op), `Future<void> previous()`, `Future<void> next()`, `Future<void> refresh()` (`forceRefresh: true`).

- [ ] **Step 1: Başarısız testi yaz**

`test/presentation/calendar_month_controller_test.dart`:

```dart
import 'dart:async';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/controllers/calendar_month_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

const location = Location(id: 'test', province: 'İstanbul', district: 'Fatih');

List<PrayerTime> monthDays(DateTime month) => [
  for (var day = 1; day <= DateTime(month.year, month.month + 1, 0).day; day++)
    prayerTimeFor(DateTime(month.year, month.month, day)),
];

void main() {
  test('acilista bu ay yuklenir; aralik bu yilin Ocagi ile gelecek yilin Araligi', () async {
    final requests = <({DateTime month, bool force})>[];
    final controller = CalendarMonthController(
      loader: ({required location, required month, forceRefresh = false}) async {
        requests.add((month: month, force: forceRefresh));
        return monthDays(month);
      },
      now: DateTime(2026, 9, 15, 23, 30),
    );

    expect(controller.month, DateTime(2026, 9));
    expect(controller.firstMonth, DateTime(2026, 1));
    expect(controller.lastMonth, DateTime(2027, 12));
    expect(controller.isUnavailable, isFalse, reason: 'henuz yuklenmedi');

    await controller.updateSource(location, 0);

    expect(requests, [(month: DateTime(2026, 9), force: false)]);
    expect(controller.days, hasLength(30));
    expect(controller.loadedMonth, DateTime(2026, 9));
    expect(controller.canShare, isTrue);
    controller.dispose();
  });

  test('sinirda gecis yok: Ocak geri, gelecek yilin Araligi ileri', () async {
    final requested = <DateTime>[];
    final controller = CalendarMonthController(
      loader: ({required location, required month, forceRefresh = false}) async {
        requested.add(month);
        return monthDays(month);
      },
      now: DateTime(2026, 1, 20),
    );
    await controller.updateSource(location, 0);

    expect(controller.canGoPrevious, isFalse);
    expect(controller.canGoNext, isTrue);
    await controller.previous();
    expect(controller.month, DateTime(2026, 1));

    await controller.selectMonth(DateTime(2027, 12, 15));
    expect(controller.month, DateTime(2027, 12));
    expect(controller.canGoNext, isFalse);
    expect(controller.canGoPrevious, isTrue);

    await controller.next();
    await controller.selectMonth(DateTime(2028, 1));
    await controller.selectMonth(DateTime(2025, 12));
    expect(controller.month, DateTime(2027, 12));
    expect(requested, [DateTime(2026, 1), DateTime(2027, 12)]);
    controller.dispose();
  });

  test('Araliktan ileri gelecek yilin Ocagina gecer', () async {
    final controller = CalendarMonthController(
      loader: ({required location, required month, forceRefresh = false}) async =>
          monthDays(month),
      now: DateTime(2026, 12, 3),
    );
    await controller.updateSource(location, 0);
    await controller.next();
    expect(controller.month, DateTime(2027, 1));
    expect(controller.days.first.date, DateTime(2027, 1, 1));
    controller.dispose();
  });

  test('hizli geciste yalniz son ayin yaniti uygulanir; eski gunler yuklenirken kalir', () async {
    final requests =
        <({DateTime month, Completer<List<PrayerTime>> response})>[];
    final controller = CalendarMonthController(
      loader: ({required location, required month, forceRefresh = false}) {
        final response = Completer<List<PrayerTime>>();
        requests.add((month: month, response: response));
        return response.future;
      },
      now: DateTime(2026, 9, 15),
    );
    final first = controller.updateSource(location, 0);
    requests[0].response.complete(monthDays(DateTime(2026, 9)));
    await first;

    final october = controller.next();
    final november = controller.next();
    expect(controller.month, DateTime(2026, 11));
    expect(controller.isLoading, isTrue);
    expect(
      controller.days.first.date.month,
      9,
      reason: 'onceki ayin tablosu yeni ay gelene kadar kalir',
    );
    expect(controller.canShare, isFalse);

    requests[2].response.complete(monthDays(DateTime(2026, 11)));
    await november;
    requests[1].response.complete(monthDays(DateTime(2026, 10)));
    await october;

    expect(requests.map((r) => r.month).toList(), [
      DateTime(2026, 9),
      DateTime(2026, 10),
      DateTime(2026, 11),
    ]);
    expect(controller.loadedMonth, DateTime(2026, 11));
    expect(controller.days.first.date, DateTime(2026, 11, 1));
    expect(controller.days, hasLength(30));
    expect(controller.isLoading, isFalse);
    controller.dispose();
  });

  test('bos sonuc "yayimlanmadi" durumudur, hata degildir', () async {
    final controller = CalendarMonthController(
      loader: ({required location, required month, forceRefresh = false}) async =>
          const [],
      now: DateTime(2026, 9, 15),
    );
    final load = controller.updateSource(location, 0);
    expect(controller.isUnavailable, isFalse, reason: 'yukleniyor');
    await load;

    expect(controller.isUnavailable, isTrue);
    expect(controller.error, isNull);
    expect(controller.canShare, isFalse);
    controller.dispose();
  });

  test('hata: gunler temizlenir, refresh ayi zorla yeniden yukler', () async {
    final calls = <({DateTime month, bool force})>[];
    var failOctober = true;
    final controller = CalendarMonthController(
      loader: ({required location, required month, forceRefresh = false}) async {
        calls.add((month: month, force: forceRefresh));
        if (month == DateTime(2026, 10) && failOctober) {
          throw Exception('offline');
        }
        return monthDays(month);
      },
      now: DateTime(2026, 9, 15),
    );
    await controller.updateSource(location, 0);
    await controller.next();

    expect(controller.error, isNotNull);
    expect(
      controller.days,
      isEmpty,
      reason: 'eylul tablosu ekim etiketiyle kalmamali',
    );
    expect(controller.isUnavailable, isFalse);
    expect(controller.canShare, isFalse);

    failOctober = false;
    await controller.refresh();

    expect(calls.last, (month: DateTime(2026, 10), force: true));
    expect(controller.error, isNull);
    expect(controller.days, hasLength(31));
    controller.dispose();
  });

  test('ayni kaynak yeniden yuklemez; konum ya da duzeltme degisince ayni ay yeniden yuklenir', () async {
    final requested = <DateTime>[];
    final controller = CalendarMonthController(
      loader: ({required location, required month, forceRefresh = false}) async {
        requested.add(month);
        return monthDays(month);
      },
      now: DateTime(2026, 9, 15),
    );
    await controller.updateSource(location, 0);
    await controller.updateSource(location, 0);
    expect(requested, [DateTime(2026, 9)]);

    await controller.next();
    final reload = controller.updateSource(location, 1);
    expect(
      controller.days,
      isEmpty,
      reason: 'eski duzeltmeyle okunmus gunler gosterilmez',
    );
    await reload;
    expect(requested, [
      DateTime(2026, 9),
      DateTime(2026, 10),
      DateTime(2026, 10),
    ]);

    await controller.updateSource(location.copyWith(latitude: 42), 1);
    expect(requested, hasLength(4));
    controller.dispose();
  });

  test('dispose sonrasi gelen yanit bildirim uretmez', () async {
    final pending = Completer<List<PrayerTime>>();
    final controller = CalendarMonthController(
      loader: ({required location, required month, forceRefresh = false}) =>
          pending.future,
      now: DateTime(2026, 9, 15),
    );
    var notified = 0;
    controller.addListener(() => notified++);
    final load = controller.updateSource(location, 0);
    expect(notified, 1);

    controller.dispose();
    pending.complete(monthDays(DateTime(2026, 9)));
    await load;
    expect(notified, 1);
  });
}
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/presentation/calendar_month_controller_test.dart`
Expected: FAIL — derleme hatası: `lib/presentation/controllers/calendar_month_controller.dart` bulunamıyor.

- [ ] **Step 3: Uygula**

`lib/presentation/controllers/calendar_month_controller.dart`:

```dart
import 'package:flutter/foundation.dart';
import '../../core/models/location.dart';
import '../../core/models/prayer_time.dart';
import '../../core/utils/app_logger.dart';
import '../../features/prayer_times/domain/calendar_month_repository.dart';

/// Vakit Takvimi'nin ay ay gezinmesi (spec 2026-09-28 §3.5).
///
/// `ImsakiyeController` kalıbındadır: nesil sayacı, hızlı ok basışlarında
/// yalnız son ayın yanıtını uygular. Ay değişirken önceki ayın [days]'i yeni
/// ay gelene kadar kalır (ekranda eski tablo + ince ilerleme çizgisi); hangi
/// aya ait oldukları [loadedMonth]'tadır. Konum/düzeltme değişince ya da
/// yükleme başarısız olunca günler temizlenir: başka ayın ya da eski
/// düzeltmenin tablosu yanlış etiketle görünmesin.
class CalendarMonthController extends ChangeNotifier {
  final CalendarMonthLoader loader;

  /// Gezinme aralığı: bu yılın Ocak'ı … gelecek yılın Aralık'ı.
  final DateTime firstMonth;
  final DateTime lastMonth;

  DateTime _month;
  DateTime? _loadedMonth;
  Location? _location;
  Object? _revision;
  List<PrayerTime> days = const [];
  Object? error;
  bool isLoading = false;
  bool _disposed = false;
  int _generation = 0;

  CalendarMonthController({required this.loader, required DateTime now})
    : _month = DateTime(now.year, now.month),
      firstMonth = DateTime(now.year),
      lastMonth = DateTime(now.year + 1, 12);

  /// Seçili ay (ayın 1'i, yerel saat).
  DateTime get month => _month;

  /// [days]'in ait olduğu ay; henüz sonuç yoksa ya da temizlendiyse `null`.
  DateTime? get loadedMonth => _loadedMonth;

  bool get canGoPrevious => _month.isAfter(firstMonth);
  bool get canGoNext => _month.isBefore(lastMonth);

  /// Paylaşım yalnız seçili ayın günleri yüklüyken ve yükleme yokken.
  bool get canShare => !isLoading && _loadedMonth == _month && days.isNotEmpty;

  /// Sunucu o yılı henüz yayımlamamış (boş sonuç): hata değil, bilgi.
  bool get isUnavailable =>
      !isLoading && error == null && _loadedMonth == _month && days.isEmpty;

  Future<void> updateSource(Location location, Object revision) {
    if (_location == location && _revision == revision) return Future.value();
    _location = location;
    _revision = revision;
    // Konum ya da düzeltme değişti: eldeki günler artık geçersiz.
    days = const [];
    _loadedMonth = null;
    return _load();
  }

  Future<void> selectMonth(DateTime selected) {
    final normalized = DateTime(selected.year, selected.month);
    if (normalized == _month ||
        normalized.isBefore(firstMonth) ||
        normalized.isAfter(lastMonth)) {
      return Future.value();
    }
    _month = normalized;
    // Önceki ayın günleri yeni ay gelene kadar ekranda kalır.
    return _load();
  }

  Future<void> previous() =>
      selectMonth(DateTime(_month.year, _month.month - 1));

  Future<void> next() => selectMonth(DateTime(_month.year, _month.month + 1));

  Future<void> refresh() => _load(forceRefresh: true);

  Future<void> _load({bool forceRefresh = false}) async {
    final location = _location;
    if (location == null || _disposed) return;
    final generation = ++_generation;
    final selected = _month;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await loader(
        location: location,
        month: selected,
        forceRefresh: forceRefresh,
      );
      if (_disposed || generation != _generation) return;
      days = result;
      _loadedMonth = selected;
    } catch (failure, stack) {
      if (_disposed || generation != _generation) return;
      AppLogger().warning('Calendar month load failed', failure, stack);
      error = failure;
      days = const [];
      _loadedMonth = null;
    } finally {
      if (!_disposed && generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
```

- [ ] **Step 4: Yeşili gör**

Run: `flutter test test/presentation/calendar_month_controller_test.dart`
Expected: PASS (8 test).

- [ ] **Step 5: Biçimlendir ve analiz et**

Run: `dart format lib/presentation/controllers/calendar_month_controller.dart test/presentation/calendar_month_controller_test.dart && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/controllers/calendar_month_controller.dart test/presentation/calendar_month_controller_test.dart
git commit -m "$(cat <<'EOF'
feat(calendar): CalendarMonthController — ay seçimi, aralık ve nesil sayacı

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: Takvim tablosu — soluk geçmiş günler ve bugünden açılış

**Files:**
- Modify: `lib/presentation/widgets/calendar/calendar_table.dart` (tamamı; sabitler `:13-22`, `CalendarTable` `:63-108`, `_CalendarRow` `:111-217`)
- Test: `test/widgets/calendar/calendar_table_test.dart` (import `:1-8`, `pumpTable` `:27-49`, dosya sonuna iki grup)

**Interfaces:**
- Consumes: `DateUtils.isSameDay`, `DateUtils.dateOnly` (Flutter material), `ScrollController({double initialScrollOffset, bool keepScrollOffset})`.
- Produces:
  - `class CalendarTable extends StatefulWidget { const CalendarTable({Key? key, required List<PrayerTime> days, required DateTime now}); static double initialScrollOffset({required List<PrayerTime> days, required DateTime now, required double rowHeight, required double viewportHeight}); }` — kurucu imzası değişmez (mevcut `CalendarScreen` derlenmeye devam eder).
  - `class CalendarDayRow extends StatelessWidget { const CalendarDayRow({Key? key, required PrayerTime day, DateTime? now}); }` — `now == null`: vurgusuz, tam opak (paylaşım, Task 13). Satır kökü `Opacity(key: Key('calendar_row'))` (anahtar `Container`'dan buraya taşındı; satır sayan mevcut testler aynı kalır).

- [ ] **Step 1: Başarısız testleri yaz**

`test/widgets/calendar/calendar_table_test.dart`:

(a) Import bloğuna ekle:

```dart
import '../../support/fakes.dart';
```

(b) `pumpTable` imzasına `DateTime? now,` ekle ve `CalendarTable`'a geçir:

```dart
  Future<void> pumpTable(
    WidgetTester tester, {
    List<PrayerTime>? days,
    DateTime? now,
    Locale locale = const Locale('tr'),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: CalendarTable(
            days: days ?? [_day(2), _day(3), _day(4)],
            now: now ?? DateTime(2026, 8, 3, 17, 34),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pump();
  }

  List<double> rowOpacities(WidgetTester tester) => tester
      .widgetList<Opacity>(find.byKey(const Key('calendar_row')))
      .map((row) => row.opacity)
      .toList();

  ScrollPosition verticalPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .position;
```

(c) `main` gövdesinin sonuna (son `testWidgets`'tan sonra) ekle:

```dart
  group('gecmis gunler', () {
    testWidgets('bugunden onceki gun soluk, bugun ve sonrasi tam opak', (
      tester,
    ) async {
      await pumpTable(tester);
      expect(rowOpacities(tester), [0.5, 1.0, 1.0]);
    });

    testWidgets('gecmis ayin butun gunleri soluk, gelecek ay tam opak', (
      tester,
    ) async {
      await pumpTable(tester, now: DateTime(2026, 9, 15));
      expect(rowOpacities(tester), [0.5, 0.5, 0.5]);

      await pumpTable(tester, now: DateTime(2026, 7, 20));
      expect(rowOpacities(tester), [1.0, 1.0, 1.0]);
    });
  });

  group('baslangic konumu', () {
    final september = [
      for (var day = 1; day <= 30; day++) prayerTimeFor(DateTime(2026, 9, day)),
    ];
    const tableHeight = 400.0;

    Future<ScrollPosition> pumpSeptember(
      WidgetTester tester,
      DateTime now,
    ) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapWithTheme(
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: tableHeight,
              child: CalendarTable(days: september, now: now),
            ),
          ),
        ),
      );
      await tester.pump();
      return verticalPosition(tester);
    }

    testWidgets('bugunun bir ust satiri en ustte acilir', (tester) async {
      final position = await pumpSeptember(tester, DateTime(2026, 9, 15, 9));
      // 15 Eylul 0 tabanli 14. satir; bir ustu (13.) en ustte.
      expect(position.pixels, 13 * kCalendarRowHeight);
      expect(find.text('BUGÜN').hitTestable(), findsOneWidget);
    });

    testWidgets(
      'ay sonuna yakin bugun icerik sonuna kisitlanir, acilista kayma olmaz',
      (tester) async {
        final position = await pumpSeptember(
          tester,
          DateTime(2026, 9, 29, 9),
        );
        // 30 satir + 24 alt bosluk; gorunen alan = tablo - baslik satiri.
        const maxExtent =
            30 * kCalendarRowHeight + 24 - (tableHeight - kCalendarRowHeight);
        expect(position.maxScrollExtent, maxExtent);
        expect(
          position.pixels,
          maxExtent,
          reason: 'istenen 27 * 56 = 1512 kaydirilabilir alani asar',
        );
        await tester.pumpAndSettle();
        expect(
          position.pixels,
          maxExtent,
          reason: 'iOS yaylanmasi konumu geri cekmemeli',
        );
        expect(find.text('BUGÜN').hitTestable(), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('bugunu icermeyen ay en ustten baslar', (tester) async {
      final position = await pumpSeptember(tester, DateTime(2026, 10, 2));
      expect(position.pixels, 0);
    });

    test('bugun ilk gunse ya da liste bossa konum sifir', () {
      expect(
        CalendarTable.initialScrollOffset(
          days: september,
          now: DateTime(2026, 9, 1, 8),
          rowHeight: kCalendarRowHeight,
          viewportHeight: 300,
        ),
        0,
      );
      expect(
        CalendarTable.initialScrollOffset(
          days: const [],
          now: DateTime(2026, 9, 1),
          rowHeight: kCalendarRowHeight,
          viewportHeight: 300,
        ),
        0,
      );
    });
  });
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/calendar/calendar_table_test.dart`
Expected: FAIL — derleme hatası: `CalendarTable.initialScrollOffset` tanımlı değil (dosyadaki bütün testler yüklenemez).

- [ ] **Step 3: Uygula**

`lib/presentation/widgets/calendar/calendar_table.dart` dosyasını şununla değiştir (`CalendarHeaderRow` ve satır görünümü aynen korunur; değişenler: iki sabit, `CalendarTable` durumlu oldu, satır public ve `Opacity` ile sarıldı):

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../l10n/l10n_extensions.dart';
import 'package:intl/intl.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../core/utils/prayer_utils.dart';

/// İmsakiyeyle aynı kompakt satır yüksekliği; büyük metinde ölçeklenir.
const double kCalendarRowHeight = 56;

/// İmsakiyedeki 1.5:1 tarih/vakit sütunu oranı.
const int _kDayColumnFlex = 3;
const int _kPrayerColumnFlex = 2;
const double _kMinimumTableWidth = 280;

/// Dar sütunlarda saatler küçültülse de komşu değerler arasında boşluk kalır.
const double _kColumnGap = 3;

/// Listenin altındaki boşluk. Başlangıç konumu içerik sonuna göre
/// kısıtlanırken de aynı değer hesaba katılır.
const double _kListBottomPadding = 24;

/// Bugünden önceki günler, hangi ay açık olursa olsun, soluk çizilir.
const double _kPastDayOpacity = 0.5;

/// Takvimin sabit başlık satırı: vakit adları.
class CalendarHeaderRow extends StatelessWidget {
  const CalendarHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      constraints: const BoxConstraints(minHeight: kCalendarRowHeight),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.divider)),
      ),
      child: Row(
        children: [
          const Expanded(flex: _kDayColumnFlex, child: SizedBox()),
          for (final type in PrayerType.values)
            Expanded(
              flex: _kPrayerColumnFlex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kColumnGap),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    context.l10n.prayerName(type),
                    style: AppTypography.rowSubtitle.copyWith(
                      color: tokens.textValue,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Günleri satır, vakitleri kolon olarak gösteren takvim tablosu.
///
/// Genişleyen kart listesinin yerini alır: bütün günlerin bütün vakitleri
/// tek bakışta karşılaştırılabilir. Bugünü içeren ayda liste, bugünün bir
/// üst satırı en üstte olacak konumda açılır; başka ayda en üstten başlar.
/// Ekran tabloyu gösterdiği ayla anahtarlar: ay değişince yeni durum kurulur
/// ve başlangıç konumu yeniden hesaplanır.
class CalendarTable extends StatefulWidget {
  final List<PrayerTime> days;
  final DateTime now;

  const CalendarTable({super.key, required this.days, required this.now});

  /// Listenin ilk kaydırma konumu. Bugün listede değilse ya da ilk günse
  /// sıfır. İçerik sonuna göre kısıtlanır: ayın son günlerinde istenen konum
  /// kaydırılabilir alanı aşar; aşan konum açılışta geri yaylanan bir kayma
  /// olarak görünürdü (iOS'ta belirgin).
  static double initialScrollOffset({
    required List<PrayerTime> days,
    required DateTime now,
    required double rowHeight,
    required double viewportHeight,
  }) {
    final todayIndex = days.indexWhere(
      (day) => DateUtils.isSameDay(day.date, now),
    );
    if (todayIndex <= 0) return 0;
    final contentHeight = days.length * rowHeight + _kListBottomPadding;
    final maxOffset = math.max(0.0, contentHeight - viewportHeight);
    return math.min((todayIndex - 1) * rowHeight, maxOffset);
  }

  @override
  State<CalendarTable> createState() => _CalendarTableState();
}

class _CalendarTableState extends State<CalendarTable> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = AppTypography.rowSubtitle.fontSize!;
    final textScale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(fontSize) / fontSize,
    );
    final rowHeight = kCalendarRowHeight * textScale;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Konum yalnız ilk yerleşimde hesaplanır ve animasyonsuz verilir;
        // sonraki yerleşimler kullanıcının kaydırdığı yere dokunmaz.
        // keepScrollOffset kapalı: rotanın PageStorage'ı eski bir konumla
        // başlangıç konumunu ezmesin.
        _scroll ??= ScrollController(
          initialScrollOffset: CalendarTable.initialScrollOffset(
            days: widget.days,
            now: widget.now,
            rowHeight: rowHeight,
            viewportHeight: constraints.maxHeight - rowHeight,
          ),
          keepScrollOffset: false,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(
              _kMinimumTableWidth * textScale,
              constraints.maxWidth,
            ),
            height: constraints.maxHeight,
            child: Column(
              children: [
                SizedBox(height: rowHeight, child: const CalendarHeaderRow()),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(
                      bottom: _kListBottomPadding,
                    ),
                    itemCount: widget.days.length,
                    itemExtent: rowHeight,
                    itemBuilder: (context, index) => CalendarDayRow(
                      day: widget.days[index],
                      now: widget.now,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Takvimin bir gün satırı. Ekrandaki tablo ve ay paylaşım görüntüsü aynı
/// satırı kullanır; paylaşılan tablo ekrandakiyle aynı görünür.
class CalendarDayRow extends StatelessWidget {
  final PrayerTime day;

  /// Bugün vurgusu ve geçmiş günlerin soluklaştırılması bu ana göre yapılır.
  /// Paylaşım görüntüsünde `null`: satırlar vurgusuz ve tam opak çizilir.
  final DateTime? now;

  const CalendarDayRow({super.key, required this.day, this.now});

  bool get _isToday {
    final now = this.now;
    return now != null && DateUtils.isSameDay(day.date, now);
  }

  bool get _isPast {
    final now = this.now;
    return now != null &&
        DateUtils.dateOnly(day.date).isBefore(DateUtils.dateOnly(now));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Opacity(
      key: const Key('calendar_row'),
      opacity: _isPast ? _kPastDayOpacity : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _isToday ? tokens.secondarySurface : null,
          border: Border(bottom: BorderSide(color: tokens.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: _kDayColumnFlex,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kColumnGap),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _dayLabel(context),
                ),
              ),
            ),
            for (final type in PrayerType.values)
              Expanded(
                flex: _kPrayerColumnFlex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _kColumnGap),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DateFormat(
                        'HH:mm',
                      ).format(PrayerUtils.getPrayerTime(day, type)),
                      style:
                          (_isToday
                                  ? AppTypography.upcomingRemaining
                                  : AppTypography.rowSubtitle)
                              .copyWith(
                                color: _isToday
                                    ? tokens.accent
                                    : tokens.textValue,
                              ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dayLabel(BuildContext context) {
    final tokens = context.tokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dayNumber = DateFormat('d MMM', locale).format(day.date);
    final weekday = DateFormat('EEEE', locale).format(day.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dayNumber,
          style: AppTypography.hint.copyWith(
            color: _isToday ? tokens.accent : tokens.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        if (_isToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              context.l10n.today,
              style: AppTypography.sectionLabel.copyWith(
                color: tokens.backgroundStops.last,
                letterSpacing: 0.5,
              ),
            ),
          )
        else
          Text(
            weekday,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.hint.copyWith(color: tokens.textTertiary),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Yeşili gör**

Run: `flutter test test/widgets/calendar/calendar_table_test.dart test/widgets/calendar/imsakiye_view_test.dart`
Expected: PASS — yeni 6 test + mevcut 7 tablo testi (satır sayımı, BUGÜN rozeti, 2x metin, RTL, boş liste) + imsakiye ekran testleri (ekran henüz eski kurucuyla `CalendarTable` kullanıyor).

- [ ] **Step 5: Biçimlendir ve analiz et**

Run: `dart format lib/presentation/widgets/calendar/calendar_table.dart test/widgets/calendar/calendar_table_test.dart && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/calendar/calendar_table.dart test/widgets/calendar/calendar_table_test.dart
git commit -m "$(cat <<'EOF'
feat(calendar): geçmiş günler soluk, liste bugünden açılır

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: `CalendarMonthShareTable` — ayın bütün günleri

**Files:**
- Create: `lib/presentation/widgets/calendar/calendar_month_share_table.dart`
- Test: `test/widgets/calendar/calendar_month_share_table_test.dart` (yeni)

**Interfaces:**
- Consumes: `CalendarDayRow`, `CalendarHeaderRow`, `kCalendarRowHeight` (Task 12); `WidgetImageRenderer.render({required BuildContext context, required Widget child})` (1000 × 10000 mantıksal tuval, `TextScaler.noScaling`); `context.l10n.calendarTitle`; `DateFormat.yMMMM(String locale)`.
- Produces:
  - `const double kCalendarShareLogicalWidth = 400;`
  - `String calendarMonthLabel(BuildContext context, DateTime month)` — `DateFormat.yMMMM(localeTag)` ("Eylül 2026"); ekran (Task 14) alt başlıkta ve ay çubuğunda kullanır.
  - `class CalendarMonthShareTable extends StatelessWidget { const CalendarMonthShareTable({Key? key, required Location location, required DateTime month, required List<PrayerTime> days}); }` — başlık, konum, ay adı, başlık satırı ve tembel olmayan bütün satırlar; 400 genişlikte yerleşip `FittedBox(fit: BoxFit.fitWidth)` ile büyür.

- [ ] **Step 1: Başarısız testi yaz**

`test/widgets/calendar/calendar_month_share_table_test.dart`:

```dart
import 'dart:ui' as ui;

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/services/widget_image_renderer.dart';
import 'package:ezanvakti/presentation/widgets/calendar/calendar_month_share_table.dart';
import 'package:ezanvakti/presentation/widgets/calendar/calendar_table.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';
import '../../support/fakes.dart';

const location = Location(id: 'test', province: 'İstanbul', district: 'Fatih');

List<PrayerTime> monthDays(DateTime month) => [
  for (var day = 1; day <= DateTime(month.year, month.month + 1, 0).day; day++)
    prayerTimeFor(DateTime(month.year, month.month, day)),
];

void main() {
  final october = DateTime(2026, 10);

  testWidgets('ayin butun gunleri tembel olmadan cizilir, bugun vurgusu yok', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        SingleChildScrollView(
          child: CalendarMonthShareTable(
            location: location,
            month: october,
            days: monthDays(october),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('calendar_row')), findsNWidgets(31));
    expect(find.text('Vakit Takvimi'), findsOneWidget);
    expect(find.text(location.displayName), findsOneWidget);
    expect(find.text('Ekim 2026'), findsOneWidget);
    expect(find.text('31 Eki'), findsOneWidget);
    // Paylaşılan çizelge aylık başvuru tablosu: bugün rozeti ve soluk
    // geçmiş günler yalnız ekranda.
    expect(find.text('BUGÜN'), findsNothing);
    expect(
      tester
          .widgetList<Opacity>(find.byKey(const Key('calendar_row')))
          .map((row) => row.opacity)
          .toSet(),
      {1.0},
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PNG son satiri da boyar ve 10000 px sinirina sigar', (
    tester,
  ) async {
    // Test fontu (Ahem) rakamlari ayni kutuyla cizer; son satir degisikligi
    // PNG'ye yansisin diye gercek font yuklenir.
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'));
    await tester.runAsync(() async {
      await font.load();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    late BuildContext renderContext;
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) {
            renderContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final days = monthDays(october);
    final bytes = await tester.runAsync(
      () => WidgetImageRenderer.render(
        context: renderContext,
        child: CalendarMonthShareTable(
          location: location,
          month: october,
          days: days,
        ),
      ),
    );
    final changed = List<PrayerTime>.of(days);
    changed[30] = changed[30].copyWith(
      maghrib: changed[30].maghrib.add(const Duration(minutes: 7)),
    );
    final changedBytes = await tester.runAsync(
      () => WidgetImageRenderer.render(
        context: renderContext,
        child: CalendarMonthShareTable(
          location: location,
          month: october,
          days: changed,
        ),
      ),
    );

    expect(bytes, isNotEmpty);
    expect(
      listEquals(bytes, changedBytes),
      isFalse,
      reason: 'Yalniz son satirin degismesi PNG\'yi degistirmeli',
    );
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1000);
      expect(
        frame.image.height,
        greaterThan(
          (31 * kCalendarRowHeight * 1000 / kCalendarShareLogicalWidth)
              .round(),
        ),
      );
      expect(
        frame.image.height,
        lessThan(10000),
        reason: 'renderer tuvali 10000 px; 31 gun kesilmeden sigmali',
      );
      frame.image.dispose();
      codec.dispose();
    });
  });
}
```

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/calendar/calendar_month_share_table_test.dart`
Expected: FAIL — derleme hatası: `calendar_month_share_table.dart` bulunamıyor.

- [ ] **Step 3: Uygula**

`lib/presentation/widgets/calendar/calendar_month_share_table.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../../l10n/l10n_extensions.dart';
import 'calendar_table.dart';

/// Paylaşım görüntüsünün mantıksal genişliği. Renderer 1000 px genişlikte
/// çizer; tablo telefon genişliğinde yerleşip 2.5 kat büyür. Eski ekran
/// yakalamasının (pixelRatio 2.5) okunurluğu korunur.
const double kCalendarShareLogicalWidth = 400;

/// "Eylül 2026": ekranın alt başlığı, ay çubuğu ve paylaşım görüntüsü aynı
/// biçimi kullanır.
String calendarMonthLabel(BuildContext context, DateTime month) =>
    DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(month);

/// Ayın bütün günlerini tembel olmadan çizer; ekran dışındaki satırlar da
/// boyanır (ay paylaşımı). Satırlar ekrandaki tabloyla aynı widget'tır.
class CalendarMonthShareTable extends StatelessWidget {
  final Location location;
  final DateTime month;
  final List<PrayerTime> days;

  const CalendarMonthShareTable({
    super.key,
    required this.location,
    required this.month,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ColoredBox(
      color: tokens.backgroundStops.last,
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: kCalendarShareLogicalWidth,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.calendarTitle,
                  style: AppTypography.screenTitle.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  location.displayName,
                  style: AppTypography.rowTitle.copyWith(
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  calendarMonthLabel(context, month),
                  style: AppTypography.hint.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  height: kCalendarRowHeight,
                  child: CalendarHeaderRow(),
                ),
                // `now` verilmez: paylaşılan çizelgede bugün vurgusu ve
                // soluk geçmiş günler yok.
                for (final day in days)
                  SizedBox(
                    height: kCalendarRowHeight,
                    child: CalendarDayRow(day: day),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Yeşili gör**

Run: `flutter test test/widgets/calendar/calendar_month_share_table_test.dart`
Expected: PASS (2 test).

- [ ] **Step 5: Biçimlendir ve analiz et**

Run: `dart format lib/presentation/widgets/calendar/calendar_month_share_table.dart test/widgets/calendar/calendar_month_share_table_test.dart && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/calendar/calendar_month_share_table.dart test/widgets/calendar/calendar_month_share_table_test.dart
git commit -m "$(cat <<'EOF'
feat(calendar): ayın bütün günlerini çizen paylaşım tablosu

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: Ekran — ay çubuğu, durumlar, ay paylaşımı; l10n ve HomePage bağlama

Ekranın kurucusu değiştiği için bütün çağıranlar (HomePage, imsakiye ekran testleri) bu task'ta güncellenir; ara commit derlenmeyen durum bırakmaz.

**Files:**
- Modify: `lib/l10n/app_tr.arb` (`@calendarDayCount` bloğundan hemen sonra, ~`:837-845`), `lib/l10n/app_en.arb` (`"calendarDayCount"` satırından sonra, ~`:194`), `lib/l10n/app_ar.arb` (aynı, ~`:194`); üretilen `lib/l10n/app_localizations*.dart` (`flutter gen-l10n`)
- Modify: `lib/presentation/screens/calendar_screen.dart` (tamamı, `:1-321`)
- Modify: `lib/presentation/pages/home_page.dart` — yalnız üç bölge, içerikle tarif: import listesi (`imsakiye_repository.dart` import'unun yanı), alanlar (`late final ImsakiyeLoader _imsakiyeLoader;` satırının yanı), `_initializeServices` başı, `_openCalendar` gövdesi. Faz 1'in `HomeScreen(...)` çağrısına ve `_toggleSkip`'e dokunma; satır numaraları Faz 1'den sonra kaymış olacak.
- Modify: `test/widgets/calendar/imsakiye_view_test.dart` (`CalendarScreen(...)` çağrıları `:24-33`, `:55-67`, `:181-190`; import bloğu)
- Test: `test/widgets/calendar/calendar_screen_test.dart` (yeni)

**Interfaces:**
- Consumes: `CalendarMonthLoader`, `CalendarMonthRepository` (Task 10); `CalendarMonthController` (Task 11); `CalendarTable` (Task 12); `CalendarMonthShareTable`, `calendarMonthLabel` (Task 13); `CalendarShareService().sharePng({required Uint8List bytes, required Location location, required DateTime date, required String caption, Rect? originRect})`, `CalendarShareService.captionFor(Location, DateTime, {required String Function(String, String) format})`; `LoadingState`, `ErrorState(message:, onRetry:)`, `EmptyState(icon:, message:)`; `l10n.offlineFetchFailed`, `l10n.calendarLoading`, `l10n.shareCaption`.
- Produces:
  - `CalendarScreen({Key? key, required Location location, required CalendarMonthLoader monthLoader, ImsakiyeLoader? imsakiyeLoader, int calculationRevision = 0, DateTime Function()? clock})` — **kalkan:** `prayerTimes`, `onRefresh`, `isLoading`, `errorMessage`.
  - Test anahtarları: `Key('calendar-previous-month')`, `Key('calendar-next-month')` (ikisi `IconButton` üzerinde), `Key('calendar-month-label')`.
  - l10n: `String get calendarPreviousMonth`, `String get calendarNextMonth`, `String get calendarMonthUnavailable`.
  - `HomePage`: `late final CalendarMonthLoader _calendarMonthLoader;`

- [ ] **Step 1: Ekran testlerini yaz (önce kırmızı)**

`test/widgets/calendar/calendar_screen_test.dart`:

```dart
import 'dart:async';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/prayer_times/domain/calendar_month_repository.dart';
import 'package:ezanvakti/presentation/screens/calendar_screen.dart';
import 'package:ezanvakti/presentation/widgets/calendar/calendar_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';
import '../../support/fakes.dart';

const location = Location(id: 'test', province: 'İstanbul', district: 'Fatih');
const previousKey = Key('calendar-previous-month');
const nextKey = Key('calendar-next-month');
const shareTooltip = 'Takvimi paylaş';

List<PrayerTime> monthDays(DateTime month) => [
  for (var day = 1; day <= DateTime(month.year, month.month + 1, 0).day; day++)
    prayerTimeFor(DateTime(month.year, month.month, day)),
];

Future<List<PrayerTime>> fullMonth({
  required Location location,
  required DateTime month,
  bool forceRefresh = false,
}) async => monthDays(month);

ScrollPosition verticalPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    )
    .position;

IconButton arrow(WidgetTester tester, Key key) =>
    tester.widget<IconButton>(find.byKey(key));

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    CalendarMonthLoader loader = fullMonth,
    DateTime? now,
    Locale locale = const Locale('tr'),
    Size size = const Size(402, 874),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixedNow = now ?? DateTime(2026, 9, 15, 10);
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: CalendarScreen(
              location: location,
              monthLoader: loader,
              clock: () => fixedNow,
            ),
          ),
        ),
        locale: locale,
      ),
    );
  }

  testWidgets('alt baslik ve ay cubugu acik ayi yazar; liste bugunden acilir', (
    tester,
  ) async {
    final requested = <DateTime>[];
    await pumpScreen(
      tester,
      loader: ({required location, required month, forceRefresh = false}) async {
        requested.add(month);
        return monthDays(month);
      },
    );
    await tester.pumpAndSettle();

    expect(requested, [DateTime(2026, 9)]);
    expect(find.text('${location.displayName} · Eylül 2026'), findsOneWidget);
    expect(find.byKey(const Key('calendar-month-label')), findsOneWidget);
    expect(find.text('Eylül 2026'), findsOneWidget);
    expect(find.byTooltip('Önceki ay'), findsOneWidget);
    expect(find.byTooltip('Sonraki ay'), findsOneWidget);
    expect(verticalPosition(tester).pixels, 13 * kCalendarRowHeight);
    expect(find.text('BUGÜN').hitTestable(), findsOneWidget);
    expect(find.byTooltip(shareTooltip), findsOneWidget);
  });

  testWidgets('oklar ayi degistirir; baska ay en ustten, bu ay yine bugunden', (
    tester,
  ) async {
    final requested = <DateTime>[];
    await pumpScreen(
      tester,
      loader: ({required location, required month, forceRefresh = false}) async {
        requested.add(month);
        return monthDays(month);
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(nextKey));
    await tester.pumpAndSettle();
    expect(requested.last, DateTime(2026, 10));
    expect(find.text('Ekim 2026'), findsOneWidget);
    expect(find.text('${location.displayName} · Ekim 2026'), findsOneWidget);
    expect(verticalPosition(tester).pixels, 0);

    await tester.tap(find.byKey(previousKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(previousKey));
    await tester.pumpAndSettle();
    expect(find.text('Ağustos 2026'), findsOneWidget);
    expect(requested, [
      DateTime(2026, 9),
      DateTime(2026, 10),
      DateTime(2026, 9),
      DateTime(2026, 8),
    ]);

    await tester.tap(find.byKey(nextKey));
    await tester.pumpAndSettle();
    expect(verticalPosition(tester).pixels, 13 * kCalendarRowHeight);
  });

  testWidgets('Ocak ayinda onceki ay oku pasif', (tester) async {
    await pumpScreen(tester, now: DateTime(2026, 1, 10));
    await tester.pumpAndSettle();

    expect(find.text('Ocak 2026'), findsOneWidget);
    expect(arrow(tester, previousKey).onPressed, isNull);
    expect(arrow(tester, nextKey).onPressed, isNotNull);
  });

  testWidgets('gelecek yilin Araliginda sonraki ay oku pasif', (tester) async {
    await pumpScreen(tester, now: DateTime(2026, 12, 3));
    await tester.pumpAndSettle();

    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byKey(nextKey));
      await tester.pumpAndSettle();
    }
    expect(find.text('Aralık 2027'), findsOneWidget);
    expect(arrow(tester, nextKey).onPressed, isNull);
    expect(arrow(tester, previousKey).onPressed, isNotNull);
  });

  testWidgets(
    'yuklenirken paylas gizli; ay gecisinde eski tablo ve ince cizgi kalir',
    (tester) async {
      final responses = <DateTime, Completer<List<PrayerTime>>>{};
      await pumpScreen(
        tester,
        loader: ({required location, required month, forceRefresh = false}) =>
            (responses[month] = Completer<List<PrayerTime>>()).future,
      );
      await tester.pump();
      expect(find.text('Takvim yükleniyor...'), findsOneWidget);
      expect(find.byTooltip(shareTooltip), findsNothing);

      responses[DateTime(2026, 9)]!.complete(monthDays(DateTime(2026, 9)));
      await tester.pump();
      expect(find.byType(CalendarTable), findsOneWidget);
      expect(find.byTooltip(shareTooltip), findsOneWidget);

      await tester.tap(find.byKey(nextKey));
      await tester.pump();
      expect(find.text('Ekim 2026'), findsOneWidget);
      expect(
        find.text('15 Eyl'),
        findsOneWidget,
        reason: 'onceki ayin tablosu yeni ay gelene kadar kalir',
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byTooltip(shareTooltip), findsNothing);

      responses[DateTime(2026, 10)]!.complete(monthDays(DateTime(2026, 10)));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('1 Eki'), findsOneWidget);
      expect(find.byTooltip(shareTooltip), findsOneWidget);
    },
  );

  testWidgets('sunucu ayi yayimlamamissa bilgi metni gorunur, paylas gizli', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      loader: ({required location, required month, forceRefresh = false}) async =>
          const <PrayerTime>[],
    );
    await tester.pumpAndSettle();

    expect(find.text('Bu ayın vakitleri henüz yayımlanmadı.'), findsOneWidget);
    expect(find.byType(CalendarTable), findsNothing);
    expect(find.byTooltip(shareTooltip), findsNothing);
    expect(
      arrow(tester, nextKey).onPressed,
      isNotNull,
      reason: 'kullanici baska aya gecebilmeli',
    );
  });

  testWidgets('hata durumunda Yeniden Dene ayi zorla yeniden yukler', (
    tester,
  ) async {
    final forced = <bool>[];
    var fail = true;
    await pumpScreen(
      tester,
      loader: ({required location, required month, forceRefresh = false}) async {
        forced.add(forceRefresh);
        if (fail) throw Exception('offline');
        return monthDays(month);
      },
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Veri alınamadı. Lütfen internet bağlantınızı kontrol edin.'),
      findsOneWidget,
    );
    expect(find.byTooltip(shareTooltip), findsNothing);

    fail = false;
    await tester.tap(find.text('Yeniden Dene'));
    await tester.pumpAndSettle();

    expect(forced, [false, true]);
    expect(find.byType(CalendarTable), findsOneWidget);
    expect(find.byTooltip(shareTooltip), findsOneWidget);
  });

  testWidgets(
    'dar RTL ekranda buyuk metinle ay cubugu tasmaz, oklar yon degistirir',
    (tester) async {
      await pumpScreen(
        tester,
        locale: const Locale('ar'),
        size: const Size(320, 640),
        textScale: 2,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.byKey(previousKey)).dx,
        greaterThan(tester.getCenter(find.byKey(nextKey)).dx),
        reason: 'RTL: onceki ay sagda',
      );
      // Chevron ikonları matchTextDirection taşır; Icon RTL'de kendini aynalar.
      expect(
        find.descendant(
          of: find.byIcon(Icons.chevron_left_rounded),
          matching: find.byType(Transform),
        ),
        findsOneWidget,
      );
    },
  );
}
```

`test/widgets/calendar/imsakiye_view_test.dart`:

(a) Import bloğuna ekle:

```dart
import 'package:ezanvakti/core/models/prayer_time.dart';
```

(b) `const location = ...` satırının altına ekle:

```dart
Future<List<PrayerTime>> _fullMonth({
  required Location location,
  required DateTime month,
  bool forceRefresh = false,
}) async => [
  for (var day = 1; day <= DateTime(month.year, month.month + 1, 0).day; day++)
    prayerTimeFor(DateTime(month.year, month.month, day)),
];
```

(c) Üç `CalendarScreen(` çağrısında:
- `prayerTimes: const [],` (iki yerde: "phone shows Imsak and Iftar…" ve "calendar controls fit narrow RTL…") → `monthLoader: _fullMonth,`
- `prayerTimes: [prayerTimeFor(DateTime(2026, 9, 6))],` ("full month is accessible year round…") → `monthLoader: _fullMonth,`

- [ ] **Step 2: Kırmızıyı gör**

Run: `flutter test test/widgets/calendar/calendar_screen_test.dart test/widgets/calendar/imsakiye_view_test.dart`
Expected: FAIL — derleme hatası: `CalendarScreen`'de `monthLoader` ve `clock` adlı parametre yok.

- [ ] **Step 3: l10n anahtarlarını ekle ve üret**

`lib/l10n/app_tr.arb` — `"@calendarDayCount": { … }` bloğunun kapanışından (`  },`) hemen sonra:

```json
  "calendarPreviousMonth": "Önceki ay",
  "@calendarPreviousMonth": {
    "description": "Vakit Takvimi ay çubuğundaki geri oku; ipucu ve erişilebilirlik etiketi."
  },
  "calendarNextMonth": "Sonraki ay",
  "@calendarNextMonth": {
    "description": "Vakit Takvimi ay çubuğundaki ileri oku; ipucu ve erişilebilirlik etiketi."
  },
  "calendarMonthUnavailable": "Bu ayın vakitleri henüz yayımlanmadı.",
  "@calendarMonthUnavailable": {
    "description": "Sunucu seçili ayın yılını henüz yayımlamamışken (boş sonuç) tablo yerine gösterilir."
  },
```

`lib/l10n/app_en.arb` — `"calendarDayCount": "{count} days",` satırından sonra:

```json
  "calendarPreviousMonth": "Previous month",
  "calendarNextMonth": "Next month",
  "calendarMonthUnavailable": "Prayer times for this month have not been published yet.",
```

`lib/l10n/app_ar.arb` — `"calendarDayCount": "{count} أيام",` satırından sonra:

```json
  "calendarPreviousMonth": "الشهر السابق",
  "calendarNextMonth": "الشهر التالي",
  "calendarMonthUnavailable": "لم تُنشر أوقات هذا الشهر بعد.",
```

Run: `flutter gen-l10n && flutter test test/l10n/arb_consistency_test.dart`
Expected: üretim hatasız; PASS (üç dil aynı anahtar kümesi, boş çeviri yok). `calendarDayCount` imsakiyede kullanılmaya devam ediyor; silinmez.

- [ ] **Step 4: `CalendarScreen`'i yeniden yaz**

`lib/presentation/screens/calendar_screen.dart` dosyasını şununla değiştir (imsakiye kipi, segment ve imsakiye paylaşımı aynen kalır; `package:flutter/rendering.dart` ve `prayer_time.dart` import'ları artık gereksiz, `RenderBox` material üzerinden gelir):

```dart
import 'package:flutter/material.dart';
import '../../l10n/l10n_extensions.dart';

import '../utils/directional_icons.dart';

import '../../core/data/ramadan_periods.dart';
import '../../features/prayer_times/domain/calendar_month_repository.dart';
import '../../features/ramadan/domain/imsakiye_repository.dart';
import '../controllers/calendar_month_controller.dart';
import '../controllers/imsakiye_controller.dart';
import '../widgets/calendar/calendar_month_share_table.dart';
import '../widgets/calendar/imsakiye_view.dart';
import '../widgets/calendar/imsakiye_share_table.dart';
import '../services/widget_image_renderer.dart';
import '../services/calendar_share_service.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/models/location.dart';
import '../widgets/calendar/calendar_table.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/state_widgets.dart';

class CalendarScreen extends StatefulWidget {
  final Location location;

  /// Vakit Takvimi ayları bu yükleyiciyle okur. Vakitler depodan, düzeltme
  /// okuma anında uygulanmış gelir (ADR 0004); ekran ayrı hesap yapmaz.
  final CalendarMonthLoader monthLoader;
  final ImsakiyeLoader? imsakiyeLoader;
  final int calculationRevision;

  /// Testler sabitler; varsayılan cihaz saati.
  final DateTime Function()? clock;

  const CalendarScreen({
    super.key,
    required this.location,
    required this.monthLoader,
    this.imsakiyeLoader,
    this.calculationRevision = 0,
    this.clock,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late CalendarMonthController _month;
  ImsakiyeController? _imsakiye;
  bool _showImsakiye = false;
  bool _sharing = false;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _month = _createMonthController();
  }

  /// Dinleyici yükleme başladıktan sonra eklenir: ilk "yükleniyor" bildirimi
  /// initState ya da didUpdateWidget içinde setState'e dönüşmesin. Build
  /// durumu doğrudan controller'dan okur.
  CalendarMonthController _createMonthController() {
    final controller = CalendarMonthController(
      loader: widget.monthLoader,
      now: _now(),
    );
    controller.updateSource(widget.location, widget.calculationRevision);
    controller.addListener(_changed);
    return controller;
  }

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monthLoader != widget.monthLoader) {
      _month.removeListener(_changed);
      _month.dispose();
      _month = _createMonthController();
    } else {
      // Konum ya da düzeltme değiştiyse aynı ay yeniden yüklenir.
      // didUpdateWidget zaten build planlıyor; iç içe setState'ten kaçın.
      _month.removeListener(_changed);
      _month.updateSource(widget.location, widget.calculationRevision);
      _month.addListener(_changed);
    }
    if (oldWidget.imsakiyeLoader != widget.imsakiyeLoader) {
      _imsakiye?.removeListener(_changed);
      _imsakiye?.dispose();
      _imsakiye = null;
    }
    if (_showImsakiye) _ensureImsakiye();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _ensureImsakiye() {
    final loader = widget.imsakiyeLoader;
    if (loader == null) return;
    if (_imsakiye == null) {
      _imsakiye = ImsakiyeController(
        loader: loader,
        period: defaultRamadanPeriod(DateTime.now()),
      );
      _imsakiye!.updateSource(widget.location, widget.calculationRevision);
      _imsakiye!.addListener(_changed);
    } else {
      // didUpdateWidget already schedules a build; avoid a nested setState.
      _imsakiye!.removeListener(_changed);
      _imsakiye!.updateSource(widget.location, widget.calculationRevision);
      _imsakiye!.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _month.removeListener(_changed);
    _month.dispose();
    _imsakiye?.removeListener(_changed);
    _imsakiye?.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    var ok = false;
    try {
      if (_showImsakiye) {
        final controller = _imsakiye;
        if (controller == null || !controller.canShare) return;
        final period = controller.period;
        final location = widget.location;
        final caption =
            '${context.l10n.imsakiyeTitle} · ${period.hijriYear} · ${location.displayName} · ${imsakiyeDateRange(context, period)}';
        final bytes = await WidgetImageRenderer.render(
          context: context,
          child: ImsakiyeShareTable(
            location: location,
            period: period,
            days: controller.days,
          ),
        );
        ok = await CalendarShareService().sharePng(
          bytes: bytes,
          location: location,
          date: period.start,
          caption: caption,
          originRect: origin,
        );
      } else {
        final controller = _month;
        if (!controller.canShare) return;
        final month = controller.month;
        final location = widget.location;
        final caption = CalendarShareService.captionFor(
          location,
          month,
          format: context.l10n.shareCaption,
        );
        // Görünen ayın bütün günleri ekran dışında çizilir; ekrandaki
        // satırlarla sınırlı değil (spec 2026-09-28 §3.5).
        final bytes = await WidgetImageRenderer.render(
          context: context,
          child: CalendarMonthShareTable(
            location: location,
            month: month,
            days: controller.days,
          ),
        );
        ok = await CalendarShareService().sharePng(
          bytes: bytes,
          location: location,
          date: month,
          caption: caption,
          originRect: origin,
        );
      }
    } catch (error, stack) {
      CalendarShareService.logRenderFailure(error, stack);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.calendarShareFailed)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final month = _month;
    final canShare = _showImsakiye
        ? (_imsakiye?.canShare ?? false)
        : month.canShare;
    final monthLabel = calendarMonthLabel(context, month.month);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _CalendarAppBar(
        title: _showImsakiye ? l10n.imsakiyeTitle : l10n.calendarTitle,
        subtitle: _showImsakiye
            ? '${widget.location.displayName} · ${l10n.calendarDayCount(_imsakiye?.days.length ?? 0)}'
            : '${widget.location.displayName} · $monthLabel',
        // Yüklenirken ya da ay boşken paylaş düğmesi çizilmez.
        onShare: _sharing || !canShare ? null : _share,
      ),
      body: AppSurface(
        child: Padding(
          // Takvim altı saat kolonu yan yana taşıyor; sayfa payı diğer
          // ekranlardan dar tutuluyor ki kolonlara nefes kalsın.
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.calendarTitle)),
                  ButtonSegment(value: true, label: Text(l10n.imsakiyeTitle)),
                ],
                selected: {_showImsakiye},
                onSelectionChanged: (selection) {
                  setState(() {
                    _showImsakiye = selection.single;
                    if (_showImsakiye) _ensureImsakiye();
                  });
                },
              ),
              const SizedBox(height: 8),
              if (!_showImsakiye) ...[
                _MonthBar(
                  label: monthLabel,
                  onPrevious: month.canGoPrevious ? month.previous : null,
                  onNext: month.canGoNext ? month.next : null,
                ),
                // Ay geçişinde eski tablo kalır; ince çizgi yeni ayın
                // yüklendiğini gösterir. Yer hep ayrılır ki tablo zıplamasın.
                SizedBox(
                  height: 2,
                  child: month.isLoading && month.days.isNotEmpty
                      ? LinearProgressIndicator(
                          minHeight: 2,
                          color: context.tokens.accent,
                          backgroundColor: Colors.transparent,
                        )
                      : null,
                ),
              ],
              Expanded(
                child: _showImsakiye
                    ? (_imsakiye == null
                          ? ErrorState(message: l10n.imsakiyeLoadFailed)
                          : ImsakiyeView(controller: _imsakiye!))
                    : _buildMonthBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthBody() {
    final month = _month;
    final l10n = context.l10n;
    final days = month.days;
    if (days.isNotEmpty) {
      // Tablo gösterdiği günlerin ayıyla anahtarlanır, seçili ayla değil:
      // ay değişirken eski tablo yükleme boyunca yerinde durur (başa
      // atlamaz); yeni ay gelince yeni tablo kurulur ve başlangıç konumu
      // (bugün ya da en üst) yeniden hesaplanır.
      final shownMonth = DateTime(days.first.date.year, days.first.date.month);
      return CalendarTable(key: ValueKey(shownMonth), days: days, now: _now());
    }
    if (month.error != null && !month.isLoading) {
      return ErrorState(
        message: l10n.offlineFetchFailed,
        onRetry: month.refresh,
      );
    }
    if (month.isUnavailable) {
      return EmptyState(
        icon: Icons.calendar_month_outlined,
        message: l10n.calendarMonthUnavailable,
      );
    }
    return LoadingState(message: l10n.calendarLoading);
  }
}

/// Takvimde segmentin altındaki ay çubuğu: önceki ay · ay adı · sonraki ay.
class _MonthBar extends StatelessWidget {
  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _MonthBar({required this.label, this.onPrevious, this.onNext});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        // Chevron ikonları matchTextDirection taşır: Icon RTL'de kendini
        // aynalar ve Row "önceki"yi sağa koyar. directional_icons'taki gibi
        // ayrıca ikon değiştirmek yönü iki kez çevirirdi.
        _arrow(
          context,
          key: const Key('calendar-previous-month'),
          icon: Icons.chevron_left_rounded,
          tooltip: context.l10n.calendarPreviousMonth,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Center(
            // Dar ekran ve büyük metinde ay adı küçülür; oklar sabit kalır.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                key: const Key('calendar-month-label'),
                maxLines: 1,
                style: AppTypography.rowTitle.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ),
        ),
        _arrow(
          context,
          key: const Key('calendar-next-month'),
          icon: Icons.chevron_right_rounded,
          tooltip: context.l10n.calendarNextMonth,
          onPressed: onNext,
        ),
      ],
    );
  }

  /// Geri düğmesiyle aynı 34 pt yüzey kutusu (8 + 18 + 8); sınırda pasif.
  Widget _arrow(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    final tokens = context.tokens;
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onPressed == null ? tokens.textTertiary : tokens.textPrimary,
        ),
      ),
    );
  }
}

class _CalendarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;

  /// Veri yokken null; düğme o zaman çizilmez.
  final VoidCallback? onShare;

  const _CalendarAppBar({
    required this.title,
    required this.subtitle,
    this.onShare,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      // Vakitler ve Araçlar'dan push ile açılır; geri oku diğer sayfalarla
      // aynı biçimde (SimpleAppBar).
      leading: Navigator.of(context).canPop()
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  context.backArrow,
                  size: 18,
                  color: tokens.textPrimary,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTypography.screenTitle.copyWith(
                color: tokens.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.hint.copyWith(color: tokens.textTertiary),
            ),
          ],
        ),
      ),
      centerTitle: true,
      actions: [
        if (onShare != null)
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded),
            color: tokens.textSecondary,
            tooltip: context.l10n.calendarShare,
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: `HomePage`'i bağla**

`lib/presentation/pages/home_page.dart` (yalnız aşağıdaki üç bölge):

(a) `import '../../features/ramadan/domain/imsakiye_repository.dart';` satırının altına:

```dart
import '../../features/prayer_times/domain/calendar_month_repository.dart';
```

(b) `late final ImsakiyeLoader _imsakiyeLoader;` satırının altına:

```dart
  late final CalendarMonthLoader _calendarMonthLoader;
```

(c) `_initializeServices` içinde `_imsakiyeLoader = ImsakiyeRepository(...).load;` ifadesinin hemen altına:

```dart
    _calendarMonthLoader = CalendarMonthRepository(
      ServiceLocator().get<PrayerTimesRepository>(),
    ).load;
```

(d) `_openCalendar` (doc yorumu dahil) şununla değiştirilir:

```dart
  /// Takvim sekme değil, Vakitler ekranından ve Araçlar'dan açılan bir
  /// sayfadır; ayları depodan kendisi okur (ADR 0004). Consumer etkin konum
  /// değişince ekranı yeni konumla yeniden kurar, ekran aynı ayı yeniden yükler.
  void _openCalendar() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Consumer<AppState>(
          builder: (context, appState, child) => CalendarScreen(
            monthLoader: _calendarMonthLoader,
            imsakiyeLoader: _imsakiyeLoader,
            calculationRevision: _calendarRevision,
            location: appState.activeLocation!,
          ),
        ),
      ),
    );
  }
```

`_refreshData` `HomeScreen(onRefresh: ...)` için kullanılmaya devam ettiğinden silinmez (Task 14 sonrası `grep -n "_refreshData" lib/presentation/pages/home_page.dart` en az bir çağrı göstermeli).

(e) Eski ekranın boş durumu için kullanılan `calendarEmpty` artık kullanılmıyor; üç ARB'den sil (`app_tr.arb`'de anahtar ve `@calendarEmpty` bloğu, `app_en.arb` ve `app_ar.arb`'de tek satır) ve yeniden üret:

Run: `grep -rn "calendarEmpty" lib test | grep -v "lib/l10n/"`
Expected: çıktı yok.

Run: `flutter gen-l10n`
Expected: hatasız.

- [ ] **Step 6: Yeşili gör**

Run: `flutter test test/widgets/calendar/ test/l10n/ test/presentation/calendar_share_service_test.dart`
Expected: PASS — yeni 8 ekran testi, güncellenen 4 imsakiye ekran testi, Task 12/Task 13 testleri, ARB tutarlılığı ve sabit Türkçe metin taraması.

Run: `grep -rn "prayerTimes:" test/widgets/calendar/ ; grep -n "CalendarScreen(" -A6 lib/presentation/pages/home_page.dart`
Expected: ilk komut boş; ikincisi yalnız `monthLoader`, `imsakiyeLoader`, `calculationRevision`, `location` gösterir.

- [ ] **Step 7: Biçimlendir ve analiz et**

Run: `dart format lib/presentation/screens/calendar_screen.dart lib/presentation/pages/home_page.dart test/widgets/calendar/calendar_screen_test.dart test/widgets/calendar/imsakiye_view_test.dart && flutter analyze`
Expected: `No issues found!` (özellikle `calendar_screen.dart`'ta kullanılmayan import uyarısı olmamalı).

- [ ] **Step 8: Commit**

```bash
git add lib/l10n/app_tr.arb lib/l10n/app_en.arb lib/l10n/app_ar.arb lib/l10n/app_localizations*.dart lib/presentation/screens/calendar_screen.dart lib/presentation/pages/home_page.dart test/widgets/calendar/calendar_screen_test.dart test/widgets/calendar/imsakiye_view_test.dart
git commit -m "$(cat <<'EOF'
feat(calendar): Vakit Takvimi ay ay gezilir, ayın tamamı paylaşılır

Takvim artık AppState'in 30 günlük penceresini değil, seçili ayı depodan
okur (ADR 0004). Aralık bu yılın Ocak'ı ile gelecek yılın Aralık'ı;
bildirim/alarm planlaması ve widget penceresi değişmez.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 15: Kullanılmayan ekran yakalamalı paylaşımı kaldır

**Files:**
- Modify: `lib/presentation/services/calendar_share_service.dart` (import `:3`, sınıf yorumu `:12-16`, `shareTable` `:103-141`)
- Modify: `test/presentation/calendar_share_service_test.dart:33-41`

**Interfaces:**
- Removes: `Future<bool> CalendarShareService.shareTable({required RenderRepaintBoundary? boundary, required Location location, required DateTime date, Rect? originRect, required String Function(String, String) captionFormat})` — Task 14'ten sonra çağıranı yok. `sharePng`, `fileNameFor`, `captionFor`, `logRenderFailure` aynen kalır.

- [ ] **Step 1: Çağıran kalmadığını doğrula**

Run: `grep -rn "shareTable" lib test integration_test`
Expected: yalnız `calendar_share_service.dart` (tanım) ve `calendar_share_service_test.dart` ("cizim alani yoksa sessizce basarisiz olmaz") görünür.

- [ ] **Step 2: Testi kaldır**

`test/presentation/calendar_share_service_test.dart` içinden `test('cizim alani yoksa sessizce basarisiz olmaz', ...)` bloğunu (tamamını) sil.

- [ ] **Step 3: Metodu kaldır**

`lib/presentation/services/calendar_share_service.dart`:
- `import 'dart:ui' as ui;` satırını sil (yalnız `shareTable` kullanıyordu). `package:flutter/rendering.dart` kalır: `sharePng`'deki `Rect` oradan gelir.
- Sınıf yorumunu şununla değiştir:

```dart
/// Takvim ve imsakiye görüntüsünü paylaşır.
///
/// Görüntü çağırandan PNG olarak gelir (ekran dışı çizim,
/// `WidgetImageRenderer`); dosya adı ve paylaşım metni saf yardımcılarda
/// tutuluyor ki test edilebilsinler.
```

- `/// [boundaryKey] ile işaretli alanı PNG'ye çevirip paylaşım sayfasını açar.` yorumuyla başlayan `shareTable` metodunu kapanış süslü parantezi dahil sil.

- [ ] **Step 4: Yeşili ve tam suite'i gör**

Run: `grep -rn "shareTable\|RenderRepaintBoundary" lib/presentation/services/calendar_share_service.dart test/presentation/calendar_share_service_test.dart`
Expected: boş.

Run: `flutter analyze && flutter test test/presentation/calendar_share_service_test.dart test/widgets/calendar`
Expected: `No issues found!`; PASS. (Tam suite Faz 4'te koşulur.)

- [ ] **Step 5: Biçimlendir ve commit**

Run: `dart format lib/presentation/services/calendar_share_service.dart test/presentation/calendar_share_service_test.dart`

```bash
git add lib/presentation/services/calendar_share_service.dart test/presentation/calendar_share_service_test.dart
git commit -m "$(cat <<'EOF'
refactor(calendar): ekran yakalamalı takvim paylaşımı kaldırıldı

Ay paylaşımı artık ayın bütün günlerini ekran dışında çiziyor; görünen
satırları yakalayan yol kullanılmıyordu.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Takvim bölümü için birleştirme notları

- **Sıra:** Task 10 → Task 11 → Task 12 → Task 13 → Task 14 → Task 15. Task 10–Task 13 birbirinden bağımsız (Task 13 yalnız Task 12'ün `CalendarDayRow`/`CalendarHeaderRow`'una bağlı). Task 14, Task 10–Task 13'ün hepsine bağlı.
- **Ortak dosyalar:** `home_page.dart`'ta Task 14 yalnız import, alan, `_initializeServices` ve `_openCalendar` bölgelerine dokunur; Faz 1'in `HomeScreen(...)` düzenlemesiyle çakışmaz ama satır numaraları kayar (düzenleme içerikle tarif edildi). ARB'lerde Task 14 yalnız `calendarDayCount` komşuluğuna üç anahtar ekler; başka task'lar aynı dosyaları sırayla düzenler, çakışma çıkarsa elle birleştirilir ve `flutter gen-l10n` yeniden koşulur.
- **Test edilmeyenler (cihazda Ekrem):** açılışta konumun gerçek iOS/Android cihazda kaymadan gelmesi (widget testi yalnız `pixels == maxScrollExtent` ve settle sonrası değişmediğini kanıtlar); ay paylaşımının paylaşım sayfasında görünmesi ve görüntünün okunurluğu; geçmiş bir aya bakınca yılın yeniden inmesi (spec §7, 90 gün önbellek temizliği) ve çevrimdışıyken hata durumu.
- **Doküman (spec §9):** `docs/ROADMAP.md:9` "30 günlük takvim" → "aylık vakit takvimi (bu yıl ve gelecek yıl)" bu bölümün task'larında yok; ana oturumun doküman task'ına aittir.

---

## Faz 4 — Doküman ve teslim doğrulaması

### Task 16: ADR ve yol haritası, tam doğrulama

**Files:**
- Modify: `docs/adr/0003-platform-alarm-models.md:52`
- Modify: `docs/ROADMAP.md:9`

**Interfaces:** yok.

- [ ] **Step 1: ADR 0003'ü güncelle**

`docs/adr/0003-platform-alarm-models.md` 52. satırdaki

```
Alarmlar sekmesi yalnız bilgi kartı gösterir, ana ekranın Sıradaki kartı alarm listelemez, `AlarmScheduler` köprüye hiç gitmez
```

parçasını şununla değiştir:

```
Alarmlar sekmesi yalnız bilgi kartı gösterir (ana ekranda alarm gösterimi 2026-09-28'de tamamen kalktı), `AlarmScheduler` köprüye hiç gitmez
```

- [ ] **Step 2: Yol haritasını güncelle**

`docs/ROADMAP.md` 9. satırı şununla değiştir:

```
- ✅ Günün vakitleri + geri sayım, aylık vakit takvimi (bu yıl ve gelecek yıl)
```

Run: `git diff --check`
Expected: çıktı yok.

- [ ] **Step 3: Tam doğrulama**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test > /tmp/ezanvakti-test.log 2>&1; echo "exit=$?"; tail -3 /tmp/ezanvakti-test.log`
Expected: `exit=0` ve `All tests passed!` (çıkış kodu ayrıca yakalanır; `| tail` kodu yutar).

Run: `flutter build apk --debug`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`.

Run: `FLUTTER_XCODE_ARCHS=arm64 flutter build ios --simulator --debug`
Expected: `✓ Built build/ios/iphonesimulator/Runner.app`.

Run: `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RunnerTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add docs/adr/0003-platform-alarm-models.md docs/ROADMAP.md
git commit -m "$(cat <<'EOF'
docs: ana ekran kartının kalkması ve aylık takvim

ADR 0003'teki "ana ekranın Sıradaki kartı alarm listelemez" ifadesi
kaldırıldı; yol haritasında 30 günlük takvim yerine aylık takvim.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

## Teslim

- Cihazda denenecekler (önem sırasıyla): (1) widget kerahat şeridinde ikonun rengi, açık ve koyu temada, yaklaşırken ve kerahatte; (2) Vakit Takvimi'nde açılış konumu (bugün görünür), ay geçişi, sınır aylarında pasif ok, ay paylaşımı; (3) dört listede basılı tutma menüsü ve düzenleme ekranından silme + "Geri al"; (4) "Sıradaki çalışa göre" sıralamada kapat → "Yalnızca bu sefer" sonrası alarmın yeri; (5) ana ekranın kartsız görünümü.
- Otomatik testler alarmın gerçek cihazda zamanında çaldığını ve widget'ın çizimini kanıtlamaz; bu turda alarm planlaması değişmedi.
- Sürüm, kullanıcı isterse `inline-execution-and-release-loop` adımlarıyla (CHANGELOG ayrı commit, `release_tag.sh X.Y.Z --ios`).
