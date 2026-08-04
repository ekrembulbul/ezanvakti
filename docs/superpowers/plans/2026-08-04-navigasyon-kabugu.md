# Navigasyon Kabuğu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Beş ekranı (Ana ekran, Takvim, Bildirimler, Alarmlar, Ayarlar) üç sekmelik tek bir gezinme kabuğunda toplamak; Bildirimler ile Alarmlar'ı tek "Hatırlatıcılar" ekranında birleştirmek.

**Architecture:** `HomePage` üç sekmelik `IndexedStack` + yeni `AppNavBar` taşır. Bildirim ve alarm listeleri yalnızca `AppState`'te tutulur; ekranlar veri okur, mutasyonu `RemindersScreen` sahiplenir. Bildirim/alarm yeniden planlaması `ReminderRescheduler` içinde tek noktada toplanır ve `skips`'i zorunlu parametre yapar.

**Tech Stack:** Flutter (Material), `provider` (`ChangeNotifier`), `ServiceLocator` (elle yazılmış DI), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-04-navigasyon-kabugu-design.md`

## Global Constraints

- Türkçe kullanıcı metinleri tam Türkçe karakterle (`ç ğ ı İ ö ş ü`). Kod, değişken adı ve log çıktısı İngilizce/ASCII kalır.
- Commit mesajları ASCII (mevcut geçmişle tutarlı).
- Token okuyan her widget `context.tokens` kullanır; sabit renk yazılmaz.
- Kontrol animasyonları **220 ms `Curves.easeOutCubic`** (spec §4.2, `SlidingSegment` ile ortak).
- Her yeniden planlama güncel `AppState.skips` kümesini geçirmek zorundadır (spec §6.3 değişmez kuralı).
- Her task sonunda `flutter analyze` temiz olmalı ve `flutter test` geçmeli.
- Otomatik commit'ler aktif branch'e (`redesign/0.3.0`) atılır — kullanıcı bu işi açıkça istedi.

---

### Task 1: Etiket yardımcılarını ekrandan çıkar

Alarm etiket fonksiyonları bugün `alarms_screen.dart`'ın içinde ve dışarıdan iki yer bunları import ediyor — bir widget, helper uğruna bir ekranı import ediyor. Ekran silinmeden önce bunlar ayrı bir util dosyasına taşınmalı.

**Files:**
- Create: `lib/presentation/utils/alarm_labels.dart`
- Modify: `lib/presentation/screens/alarms_screen.dart` (257-288 satırlarındaki üç fonksiyon silinir, import eklenir)
- Modify: `lib/presentation/widgets/home/upcoming_card.dart:11`
- Move: `test/widgets/screens/alarms_screen_test.dart` → `test/presentation/alarm_labels_test.dart`

**Interfaces:**
- Consumes: yok (ilk task)
- Produces: `alarmTimeLabel(Alarm) → String`, `alarmSubtitle(Alarm) → String`, `weekdaysLabel(Set<int>) → String` — `lib/presentation/utils/alarm_labels.dart` içinde. Task 5 ve `UpcomingCard` bunları kullanır.

- [ ] **Step 1: Testi yeni konumuna taşı**

```bash
git mv test/widgets/screens/alarms_screen_test.dart test/presentation/alarm_labels_test.dart
```

Sonra dosyanın 4. satırındaki import'u değiştir:

```dart
// Eski
import 'package:ezanvakti/presentation/screens/alarms_screen.dart';
// Yeni
import 'package:ezanvakti/presentation/utils/alarm_labels.dart';
```

- [ ] **Step 2: Testi çalıştır, kırmızı olduğunu gör**

Run: `flutter test test/presentation/alarm_labels_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:ezanvakti/presentation/utils/alarm_labels.dart'`

- [ ] **Step 3: `alarm_labels.dart` dosyasını oluştur**

`lib/presentation/utils/alarm_labels.dart`:

```dart
import '../../core/models/alarm.dart';
import 'prayer_name_helper.dart';

/// "07:30" (sabit) veya "İmsak −30 dk" (çıpalı).
String alarmTimeLabel(Alarm alarm) {
  if (alarm.kind == AlarmKind.fixed) {
    final h = alarm.hour.toString().padLeft(2, '0');
    final m = alarm.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  final name = PrayerNameHelper.getName(alarm.anchor);
  if (alarm.offsetMinutes == 0) return name;
  final sign = alarm.offsetMinutes < 0 ? '−' : '+';
  return '$name $sign${alarm.offsetMinutes.abs()} dk';
}

String alarmSubtitle(Alarm alarm) {
  final parts = <String>[];
  if (alarm.label.isNotEmpty) parts.add(alarm.label);
  parts.add(weekdaysLabel(alarm.weekdays));
  return parts.join(' · ');
}

String weekdaysLabel(Set<int> weekdays) {
  if (weekdays.isEmpty || weekdays.length == 7) return 'Her gün';
  if (weekdays.length == 5 && weekdays.containsAll(const {1, 2, 3, 4, 5})) {
    return 'Hafta içi';
  }
  if (weekdays.length == 2 && weekdays.containsAll(const {6, 7})) {
    return 'Hafta sonu';
  }
  const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  final sorted = weekdays.toList()..sort();
  return sorted.map((d) => names[d - 1]).join(', ');
}
```

- [ ] **Step 4: Eski kopyaları sil, import'ları bağla**

`lib/presentation/screens/alarms_screen.dart`: dosyanın sonundaki üç fonksiyonu (`alarmTimeLabel`, `alarmSubtitle`, `weekdaysLabel` — 257. satırdan sonuna kadar) sil. `../utils/prayer_name_helper.dart` import'unun yanına ekle:

```dart
import '../utils/alarm_labels.dart';
```

`prayer_name_helper.dart` import'u hâlâ gerekiyorsa bırak; analyzer kullanılmadığını söylerse kaldır.

`lib/presentation/widgets/home/upcoming_card.dart:11`:

```dart
// Eski
import '../../screens/alarms_screen.dart' show alarmTimeLabel;
// Yeni
import '../../utils/alarm_labels.dart' show alarmTimeLabel;
```

- [ ] **Step 5: Testleri çalıştır**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` ve tüm testler PASS (520)

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/utils/alarm_labels.dart \
        lib/presentation/screens/alarms_screen.dart \
        lib/presentation/widgets/home/upcoming_card.dart \
        test/presentation/alarm_labels_test.dart
git rm --cached test/widgets/screens/alarms_screen_test.dart 2>/dev/null || true
git commit -m "refactor: alarm etiket yardimcilarini utils'e tasi"
```

---

### Task 2: `AppNavBar` bileşeni

Alt gezinme `SlidingSegment`'ten ayrılır. Hatırlatıcılar sekmesinde ekran içi bir segment daha olacağı için iki özdeş pill üst üste gelmemeli (spec D4).

**Files:**
- Create: `lib/presentation/widgets/common/app_nav_bar.dart`
- Test: `test/widgets/app_nav_bar_test.dart`

**Interfaces:**
- Consumes: yok
- Produces: `AppNavBar({required List<NavItem> items, required int selected, required ValueChanged<int> onChanged})`, `NavItem({required String label, required IconData icon})`, `AppNavBar.height` (double, 58), `kNavIndicatorKey` (Key). Task 7 kullanır.

- [ ] **Step 1: Başarısız testi yaz**

`test/widgets/app_nav_bar_test.dart`:

```dart
import 'package:ezanvakti/presentation/widgets/common/app_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_harness.dart';

void main() {
  const items = [
    NavItem(label: 'Vakitler', icon: Icons.schedule_rounded),
    NavItem(label: 'Takvim', icon: Icons.calendar_month_rounded),
    NavItem(label: 'Hatırlatıcılar', icon: Icons.notifications_rounded),
  ];

  Widget build({int selected = 0, ValueChanged<int>? onChanged}) =>
      wrapWithTheme(
        Align(
          alignment: Alignment.bottomCenter,
          child: AppNavBar(
            items: items,
            selected: selected,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      );

  testWidgets('Uc oge de etiketiyle cizilir', (tester) async {
    await tester.pumpWidget(build());

    expect(find.text('Vakitler'), findsOneWidget);
    expect(find.text('Takvim'), findsOneWidget);
    expect(find.text('Hatırlatıcılar'), findsOneWidget);
  });

  testWidgets('Secili oge vurgu rengini, digerleri notr rengi alir', (
    tester,
  ) async {
    await tester.pumpWidget(build(selected: 1));

    final tokens = tokensFor();
    expect(tester.widget<Text>(find.text('Takvim')).style!.color, tokens.accent);
    expect(
      tester.widget<Text>(find.text('Vakitler')).style!.color,
      tokens.textTertiary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.calendar_month_rounded)).color,
      tokens.accent,
    );
  });

  testWidgets('Dokunma onChanged i dogru indeksle cagirir', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(build(onChanged: tapped.add));

    await tester.tap(find.text('Hatırlatıcılar'));
    await tester.pump();

    expect(tapped, [2]);
  });

  testWidgets('Gosterge secili dilimin ortasinda durur', (tester) async {
    await tester.pumpWidget(build(selected: 1));
    await tester.pumpAndSettle();

    final indicator = tester.getCenter(find.byKey(kNavIndicatorKey));
    final label = tester.getCenter(find.text('Takvim'));

    expect(indicator.dx, closeTo(label.dx, 0.5));
  });

  testWidgets('Etiket dar dilimde tasmaz', (tester) async {
    // En dar desteklenen genislik; spec §10/V1.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(build(selected: 2));

    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.text('Hatırlatıcılar'));
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
```

- [ ] **Step 2: Testi çalıştır, kırmızı olduğunu gör**

Run: `flutter test test/widgets/app_nav_bar_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../app_nav_bar.dart'`

- [ ] **Step 3: `AppNavBar`'ı yaz**

`lib/presentation/widgets/common/app_nav_bar.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Gösterge geçişinin süresi. `SlidingSegment` ile aynı sabit: biçimleri
/// farklı, hareket dilleri ortak.
const Duration _kNavAnimation = Duration(milliseconds: 220);

// Dikey yerleşim; toplam [AppNavBar.height] bunların toplamıdır.
const double _kTopPadding = 8;
const double _kIconSize = 22;
const double _kIconLabelGap = 5;
const double _kLabelHeight = 12;
const double _kLabelIndicatorGap = 3;
const double _kIndicatorHeight = 2;
const double _kBottomPadding = 6;

const double _kIndicatorWidth = 18;

/// Göstergenin konumu spec'e bağlı olduğu için test edilebilir.
const Key kNavIndicatorKey = Key('nav_indicator');

/// Alt gezinme çubuğundaki tek bir hedef.
class NavItem {
  final String label;
  final IconData icon;

  const NavItem({required this.label, required this.icon});
}

/// Alt gezinme çubuğu: ikon üstte, etiket altta, seçili öğenin altında kayan
/// ince bir çizgi.
///
/// `SlidingSegment`'ten kasten ayrıdır: o ekran içi bir filtre, bu gezinme.
/// İkisi aynı görünseydi kullanıcı hangisinin "neredeyim" hangisinin "ne
/// gösteriyorum" olduğunu ayırt edemezdi.
class AppNavBar extends StatelessWidget {
  static const double height =
      _kTopPadding +
      _kIconSize +
      _kIconLabelGap +
      _kLabelHeight +
      _kLabelIndicatorGap +
      _kIndicatorHeight +
      _kBottomPadding;

  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onChanged;

  const AppNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / items.length;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: items[i],
                            isSelected: i == selected,
                            onTap: () => onChanged(i),
                          ),
                        ),
                    ],
                  ),
                  AnimatedPositioned(
                    duration: _kNavAnimation,
                    curve: Curves.easeOutCubic,
                    left:
                        slotWidth * selected +
                        (slotWidth - _kIndicatorWidth) / 2,
                    bottom: _kBottomPadding,
                    width: _kIndicatorWidth,
                    height: _kIndicatorHeight,
                    child: DecoratedBox(
                      key: kNavIndicatorKey,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        borderRadius: BorderRadius.circular(
                          _kIndicatorHeight / 2,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = isSelected ? tokens.accent : tokens.textTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: _kTopPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: _kIconSize, color: color),
            const SizedBox(height: _kIconLabelGap),
            SizedBox(
              height: _kLabelHeight,
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.tabLabel.copyWith(
                  fontSize: 11,
                  height: 1.0,
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontVariations: [
                    FontVariation('wght', isSelected ? 700 : 600),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Testleri çalıştır**

Run: `flutter test test/widgets/app_nav_bar_test.dart`
Expected: 5 test PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/common/app_nav_bar.dart test/widgets/app_nav_bar_test.dart
git commit -m "feat: alt gezinme icin AppNavBar"
```

---

### Task 3: `ReminderRescheduler`

Yeniden planlama bugün beş yere dağılmış; ikisi (`NotificationSettingsScreen._rescheduleNotifications`, `AlarmsScreen._reschedule`) `skips` parametresini hiç bilmiyor. Tek giriş noktası `skips`'i zorunlu yapar.

> **Dikkat — veri yokken iptal etme.** `_loadPrayerData` bugün veri boşken hiçbir şeye dokunmadan dönüyor; geçici bir ağ hatasında kullanıcının mevcut bildirimlerini silmemek için. `NotificationSettingsScreen` ise siliyor, çünkü kullanıcı bir bildirimi silmişse eski OS kopyası ölmeli. İki davranış farklı ve ikisi de doğru. Bu yüzden `reschedule` **hiçbir koşulda iptal etmez**, yalnızca `false` döner; iptal kararı çağırana kalır.

**Files:**
- Create: `lib/presentation/services/reminder_rescheduler.dart`
- Modify: `lib/core/di/service_locator.dart` (AlarmScheduler kaydından sonra)
- Test: `test/presentation/reminder_rescheduler_test.dart`

**Interfaces:**
- Consumes: yok
- Produces: `ReminderRescheduler({required NotificationScheduler notificationScheduler, required AlarmScheduler alarmScheduler})` ve `Future<bool> reschedule({required Location? location, required List<PrayerTime> prayerTimes, required Set<SkippedOccurrence> skips})`. Task 6 ve Task 7 kullanır. `ServiceLocator().get<ReminderRescheduler>()` ile çözülür.

- [ ] **Step 1: Başarısız testi yaz**

`test/presentation/reminder_rescheduler_test.dart`:

```dart
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/presentation/services/reminder_rescheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

class _MockAlarmService implements AlarmService {
  int cancelAllCount = 0;

  @override
  Future<void> cancelAllAlarms() async => cancelAllCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const location = Location(
    id: 'loc-1',
    province: 'İstanbul',
    district: 'Kadıköy',
    latitude: 40.99,
    longitude: 29.03,
  );

  // Yarinin vakitleri; bugunun saatleri gecmis olabilecegi icin planlanmaz.
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final day = PrayerTime(
    date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
    fajr: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 5, 0),
    sunrise: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 6, 30),
    dhuhr: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 13, 0),
    asr: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 16, 45),
    maghrib: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 20, 15),
    isha: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 21, 45),
  );

  Future<(ReminderRescheduler, FakeNotificationService, _MockAlarmService)>
  build() async {
    final storage = FakeStorage();
    await storage.init();
    await storage.saveNotificationSettings([
      const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        minutesBefore: 0,
      ),
    ]);
    final notificationService = FakeNotificationService();
    final alarmService = _MockAlarmService();

    return (
      ReminderRescheduler(
        notificationScheduler: NotificationScheduler(
          notificationService: notificationService,
          storage: storage,
        ),
        alarmScheduler: AlarmScheduler(
          alarmService: alarmService,
          storage: storage,
        ),
      ),
      notificationService,
      alarmService,
    );
  }

  test('Vakit verisi varsa iki planlayici da calisir', () async {
    final (rescheduler, notifications, alarms) = await build();

    final done = await rescheduler.reschedule(
      location: location,
      prayerTimes: [day],
      skips: const {},
    );

    expect(done, isTrue);
    expect(notifications.scheduled, isNotEmpty);
    expect(alarms.cancelAllCount, 1);
  });

  test('Vakit verisi yoksa false doner ve hicbir seye dokunmaz', () async {
    final (rescheduler, notifications, alarms) = await build();

    final done = await rescheduler.reschedule(
      location: location,
      prayerTimes: const [],
      skips: const {},
    );

    // Gecici bir ag hatasi yuzunden kullanicinin mevcut bildirimleri
    // silinmemeli; iptal karari cagirana ait.
    expect(done, isFalse);
    expect(notifications.cancelAllCount, 0);
    expect(alarms.cancelAllCount, 0);
  });

  test('Konum yoksa false doner', () async {
    final (rescheduler, notifications, _) = await build();

    final done = await rescheduler.reschedule(
      location: null,
      prayerTimes: [day],
      skips: const {},
    );

    expect(done, isFalse);
    expect(notifications.cancelAllCount, 0);
  });

  test('skips planlayiciya gecer; atlanan bildirim planlanmaz', () async {
    final (rescheduler, notifications, _) = await build();
    final skip = SkippedOccurrence(
      kind: SkipKind.notification,
      reference: NotificationScheduler.notificationIdFor(
        date: day.date,
        prayerType: PrayerType.dhuhr,
        minutesBefore: 0,
      ),
      fireAt: day.dhuhr,
    );

    await rescheduler.reschedule(
      location: location,
      prayerTimes: [day],
      skips: {skip},
    );

    expect(
      notifications.scheduled.map((n) => n.id),
      isNot(contains(skip.reference)),
    );
  });
}
```

- [ ] **Step 2: Testi çalıştır, kırmızı olduğunu gör**

Run: `flutter test test/presentation/reminder_rescheduler_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../reminder_rescheduler.dart'`

- [ ] **Step 3: `ReminderRescheduler`'ı yaz**

`lib/presentation/services/reminder_rescheduler.dart`:

```dart
import '../../core/models/location.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/skipped_occurrence.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
import '../../features/notifications/domain/notification_scheduler.dart';

/// Bildirim ve alarm planlamasının tek giriş noktası.
///
/// [reschedule] `skips`'i **zorunlu** parametre olarak ister. Geçirilmezse
/// kullanıcının "yalnızca bu sefer" atladığı örnek, ilgisiz bir değişiklikten
/// sonra sessizce geri planlanır ve çalar; bunu derleme zamanında imkânsız
/// kılmak için isteğe bağlı değil.
class ReminderRescheduler {
  final NotificationScheduler notificationScheduler;
  final AlarmScheduler alarmScheduler;

  const ReminderRescheduler({
    required this.notificationScheduler,
    required this.alarmScheduler,
  });

  /// Planlamayı yeniden kurar. Vakit verisi ya da konum yoksa `false` döner ve
  /// **hiçbir şeye dokunmaz** — geçici bir ağ hatası yüzünden kullanıcının
  /// mevcut bildirimlerini silmemek için. Silinen/kapatılan bir kaydın eski OS
  /// kopyasını iptal etmek çağıranın işidir.
  Future<bool> reschedule({
    required Location? location,
    required List<PrayerTime> prayerTimes,
    required Set<SkippedOccurrence> skips,
  }) async {
    if (location == null || prayerTimes.isEmpty) return false;

    await notificationScheduler.scheduleNotifications(
      location: location,
      prayerTimes: prayerTimes,
      skips: skips,
    );
    await alarmScheduler.scheduleAlarms(prayerTimes: prayerTimes, skips: skips);
    return true;
  }
}
```

- [ ] **Step 4: DI'ya kaydet**

`lib/core/di/service_locator.dart` — `register<AlarmScheduler>(...)` çağrısı bir değişkene alınır, sonra rescheduler kaydedilir:

```dart
    final alarmScheduler = AlarmScheduler(
      alarmService: alarmService,
      storage: localStorage,
    );
    register<AlarmScheduler>(alarmScheduler);
    register<ReminderRescheduler>(
      ReminderRescheduler(
        notificationScheduler: notificationScheduler,
        alarmScheduler: alarmScheduler,
      ),
    );
```

Dosyanın başına import ekle:

```dart
import '../../presentation/services/reminder_rescheduler.dart';
```

- [ ] **Step 5: Testleri çalıştır**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`, tüm testler PASS (524)

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/services/reminder_rescheduler.dart \
        lib/core/di/service_locator.dart \
        test/presentation/reminder_rescheduler_test.dart
git commit -m "feat: yeniden planlamayi ReminderRescheduler'da topla"
```

---

### Task 4: `NotificationsSection`

`NotificationSettingsScreen`'in gövdesi, kendi durumunu tutmayan bir sunum widget'ına indirgenir. Veri dışarıdan gelir, kullanıcı eylemi callback ile dışarı çıkar.

**Files:**
- Create: `lib/presentation/widgets/reminders/notifications_section.dart`
- Test: `test/widgets/notifications/notifications_section_test.dart`

**Interfaces:**
- Consumes: yok
- Produces: `NotificationsSection({required List<NotificationSetting> settings, required bool hasPermission, required bool exactAlarmAllowed, Future<bool> Function()? onRequestPermission, required ValueChanged<bool> onPermissionChanged, required VoidCallback onOpenExactAlarmSettings, required ValueChanged<NotificationSetting> onToggle, required ValueChanged<NotificationSetting> onEdit, required Future<void> Function(NotificationSetting) onDelete})`. Task 6 kullanır.

- [ ] **Step 1: Başarısız testi yaz**

`test/widgets/notifications/notifications_section_test.dart`:

```dart
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/presentation/widgets/reminders/notifications_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  const dhuhr = NotificationSetting(
    prayerType: PrayerType.dhuhr,
    isActive: true,
    minutesBefore: 0,
  );
  const fajr = NotificationSetting(
    prayerType: PrayerType.fajr,
    isActive: true,
    minutesBefore: 15,
  );

  Widget build({
    List<NotificationSetting> settings = const [dhuhr],
    bool hasPermission = true,
    bool exactAlarmAllowed = true,
    ValueChanged<NotificationSetting>? onToggle,
  }) => wrapWithTheme(
    NotificationsSection(
      settings: settings,
      hasPermission: hasPermission,
      exactAlarmAllowed: exactAlarmAllowed,
      onPermissionChanged: (_) {},
      onOpenExactAlarmSettings: () {},
      onToggle: onToggle ?? (_) {},
      onEdit: (_) {},
      onDelete: (_) async {},
    ),
  );

  testWidgets('Ayarlar vakit sirasina gore cizilir', (tester) async {
    await tester.pumpWidget(build(settings: const [dhuhr, fajr]));

    final fajrY = tester.getTopLeft(find.text('İmsak')).dy;
    final dhuhrY = tester.getTopLeft(find.text('Öğle')).dy;

    expect(fajrY, lessThan(dhuhrY));
  });

  testWidgets('Sayac satiri kayit sayisini gosterir', (tester) async {
    await tester.pumpWidget(build(settings: const [dhuhr, fajr]));

    expect(find.text('2 hatırlatma'), findsOneWidget);
  });

  testWidgets('Liste bossa bos durum cizilir', (tester) async {
    await tester.pumpWidget(build(settings: const []));

    expect(find.text('Henüz bildirim yok'), findsOneWidget);
  });

  testWidgets('Izin yoksa uyari karti gorunur', (tester) async {
    await tester.pumpWidget(build(hasPermission: false));

    expect(find.byType(Switch), findsWidgets);
    expect(find.textContaining('izin', findRichText: true), findsWidgets);
  });

  testWidgets('Exact alarm kapaliysa banner gorunur', (tester) async {
    await tester.pumpWidget(build(exactAlarmAllowed: false));

    expect(
      find.text('Tam zamanlı alarm kapalı. Bildirimler gecikebilir.'),
      findsOneWidget,
    );
  });

  testWidgets('Anahtar onToggle i cagirir', (tester) async {
    final toggled = <NotificationSetting>[];
    await tester.pumpWidget(build(onToggle: toggled.add));

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(toggled, [dhuhr]);
  });
}
```

- [ ] **Step 2: Testi çalıştır, kırmızı olduğunu gör**

Run: `flutter test test/widgets/notifications/notifications_section_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../notifications_section.dart'`

- [ ] **Step 3: `NotificationsSection`'ı yaz**

`lib/presentation/widgets/reminders/notifications_section.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../utils/prayer_name_helper.dart';
import '../common/info_banner.dart';
import '../common/section_label.dart';
import '../common/state_widgets.dart';
import '../common/swipe_to_delete.dart';
import '../notifications/notification_tile.dart';
import '../notifications/permission_warning_card.dart';

/// Hatırlatıcılar ekranının "Bildirimler" bölümü.
///
/// Kendi durumunu tutmaz: liste dışarıdan gelir, kullanıcı eylemi callback ile
/// dışarı çıkar. Tek doğruluk kaynağı `AppState` (spec §6.2).
class NotificationsSection extends StatelessWidget {
  final List<NotificationSetting> settings;
  final bool hasPermission;
  final bool exactAlarmAllowed;
  final Future<bool> Function()? onRequestPermission;
  final ValueChanged<bool> onPermissionChanged;
  final VoidCallback onOpenExactAlarmSettings;
  final ValueChanged<NotificationSetting> onToggle;
  final ValueChanged<NotificationSetting> onEdit;
  final Future<void> Function(NotificationSetting) onDelete;

  const NotificationsSection({
    super.key,
    required this.settings,
    required this.hasPermission,
    required this.exactAlarmAllowed,
    this.onRequestPermission,
    required this.onPermissionChanged,
    required this.onOpenExactAlarmSettings,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasPermission)
          PermissionWarningCard(
            onRequestPermission: onRequestPermission,
            onPermissionGranted: onPermissionChanged,
          ),
        if (hasPermission && !exactAlarmAllowed) ...[
          InfoBanner(
            icon: Icons.alarm_off_rounded,
            text: 'Tam zamanlı alarm kapalı. Bildirimler gecikebilir.',
            action: TextButton(
              onPressed: onOpenExactAlarmSettings,
              child: const Text('Aç'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(child: settings.isEmpty ? _empty() : _list(context)),
      ],
    );
  }

  Widget _empty() => const EmptyState(
    icon: Icons.notifications_none_rounded,
    message: 'Henüz bildirim yok',
    subtitle: 'Namaz vakitlerinde hatırlatma almak için\nbildirim ekleyin.',
  );

  Widget _list(BuildContext context) {
    final tokens = context.tokens;
    final sorted = _sorted();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(
          'Her vakit için tam vaktinde veya X dakika önce hatırlatma '
          'alabilirsiniz.',
          style: AppTypography.hint.copyWith(
            color: tokens.textTertiary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        SectionLabel('${sorted.length} hatırlatma'),
        const SizedBox(height: 10),
        GroupedList(
          children: [
            for (final setting in sorted)
              SwipeToDelete(
                itemKey: ValueKey(
                  '${setting.prayerType.name}-${setting.minutesBefore}',
                ),
                confirmText:
                    '${PrayerNameHelper.getName(setting.prayerType)} '
                    'bildirimini silmek istiyor musunuz?',
                onDelete: () => onDelete(setting),
                child: NotificationTile(
                  setting: setting,
                  hasPermission: hasPermission,
                  onToggle: () => onToggle(setting),
                  onTap: () => onEdit(setting),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Silmek için satırı sola kaydırın.',
          style: AppTypography.hint.copyWith(color: tokens.textTertiary),
        ),
      ],
    );
  }

  List<NotificationSetting> _sorted() {
    final sorted = [...settings];
    sorted.sort((a, b) {
      final orderCompare = PrayerNameHelper.getPrayerOrder(
        a.prayerType,
      ).compareTo(PrayerNameHelper.getPrayerOrder(b.prayerType));
      if (orderCompare != 0) return orderCompare;
      return a.minutesBefore.compareTo(b.minutesBefore);
    });
    return sorted;
  }
}
```

`GroupedList` import'unu ekle: `import '../common/grouped_list.dart';`

- [ ] **Step 4: Testleri çalıştır**

Run: `flutter test test/widgets/notifications/notifications_section_test.dart`
Expected: 6 test PASS. Bir test kırmızıysa `PermissionWarningCard`/`NotificationTile`'ın gerçek metinlerini oku ve **testi** düzelt — widget'ları değiştirme.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/reminders/notifications_section.dart \
        test/widgets/notifications/notifications_section_test.dart
git commit -m "feat: NotificationsSection sunum widget'i"
```

---

### Task 5: `AlarmsSection`

**Files:**
- Create: `lib/presentation/widgets/reminders/alarms_section.dart`
- Test: `test/widgets/notifications/alarms_section_test.dart`

**Interfaces:**
- Consumes: `alarmTimeLabel`, `alarmSubtitle` (Task 1)
- Produces: `AlarmsSection({required List<Alarm> alarms, required bool isSupported, required bool isPermissionGranted, required VoidCallback onRequestPermission, required void Function(Alarm, bool) onToggle, required ValueChanged<Alarm> onEdit, required Future<void> Function(Alarm) onDelete})`. Task 6 kullanır.

- [ ] **Step 1: Başarısız testi yaz**

`test/widgets/notifications/alarms_section_test.dart`:

```dart
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/presentation/widgets/reminders/alarms_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  const sahur = Alarm(
    id: 'sahur',
    kind: AlarmKind.fixed,
    label: 'Sahur',
    hour: 6,
    minute: 30,
  );

  Widget build({
    List<Alarm> alarms = const [sahur],
    bool isSupported = true,
    bool isPermissionGranted = true,
    void Function(Alarm, bool)? onToggle,
  }) => wrapWithTheme(
    AlarmsSection(
      alarms: alarms,
      isSupported: isSupported,
      isPermissionGranted: isPermissionGranted,
      onRequestPermission: () {},
      onToggle: onToggle ?? (_, _) {},
      onEdit: (_) {},
      onDelete: (_) async {},
    ),
  );

  testWidgets('Alarm saati ve alt basligi cizilir', (tester) async {
    await tester.pumpWidget(build());

    expect(find.text('06:30'), findsOneWidget);
    expect(find.text('Sahur · Her gün'), findsOneWidget);
    expect(find.text('1 alarm'), findsOneWidget);
  });

  testWidgets('Liste bossa bos durum cizilir', (tester) async {
    await tester.pumpWidget(build(alarms: const []));

    expect(find.text('Henüz alarm yok'), findsOneWidget);
  });

  testWidgets('Desteklenmiyorsa uyari cizilir', (tester) async {
    await tester.pumpWidget(build(isSupported: false));

    expect(find.textContaining('desteklenmiyor'), findsOneWidget);
  });

  testWidgets('Izin yoksa izin uyarisi cizilir', (tester) async {
    await tester.pumpWidget(build(isPermissionGranted: false));

    expect(find.text('Alarmların çalması için izin gerekiyor.'), findsOneWidget);
    expect(find.text('İzin ver'), findsOneWidget);
  });

  testWidgets('Anahtar onToggle i cagirir', (tester) async {
    Alarm? toggledAlarm;
    bool? toggledValue;
    await tester.pumpWidget(
      build(
        onToggle: (alarm, value) {
          toggledAlarm = alarm;
          toggledValue = value;
        },
      ),
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(toggledAlarm, sahur);
    expect(toggledValue, isFalse);
  });
}
```

> `Alarm` değer eşitliği taşıyor (`alarm.dart:137` `operator ==`), bu yüzden son testteki `expect(toggledAlarm, sahur)` çalışır.

- [ ] **Step 2: Testi çalıştır, kırmızı olduğunu gör**

Run: `flutter test test/widgets/notifications/alarms_section_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../alarms_section.dart'`

- [ ] **Step 3: `AlarmsSection`'ı yaz**

`lib/presentation/widgets/reminders/alarms_section.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/models/alarm.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../../utils/alarm_labels.dart';
import '../common/grouped_list.dart';
import '../common/info_banner.dart';
import '../common/section_label.dart';
import '../common/state_widgets.dart';
import '../common/swipe_to_delete.dart';

/// Hatırlatıcılar ekranının "Alarmlar" bölümü.
///
/// [NotificationsSection] ile aynı sözleşme: durum tutmaz, veri dışarıdan
/// gelir.
class AlarmsSection extends StatelessWidget {
  final List<Alarm> alarms;

  /// iOS 26 altında sesli alarm yok; kayıt tutulur ama çalmaz.
  final bool isSupported;
  final bool isPermissionGranted;
  final VoidCallback onRequestPermission;
  final void Function(Alarm alarm, bool isActive) onToggle;
  final ValueChanged<Alarm> onEdit;
  final Future<void> Function(Alarm) onDelete;

  const AlarmsSection({
    super.key,
    required this.alarms,
    required this.isSupported,
    required this.isPermissionGranted,
    required this.onRequestPermission,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final banner = _permissionBanner();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null) banner,
        Expanded(child: alarms.isEmpty ? _empty() : _list(context)),
        _footer(context),
      ],
    );
  }

  Widget _empty() => const EmptyState(
    icon: Icons.alarm_off_rounded,
    message: 'Henüz alarm yok',
    subtitle: 'Sabit saatli veya vakte göre alarm ekle',
  );

  Widget _list(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        SectionLabel('${alarms.length} alarm'),
        const SizedBox(height: 10),
        GroupedList(
          children: [
            for (final alarm in alarms)
              SwipeToDelete(
                itemKey: ValueKey(alarm.id),
                confirmText:
                    '${alarmTimeLabel(alarm)} alarmını silmek istiyor musunuz?',
                onDelete: () => onDelete(alarm),
                child: GroupedRow(
                  icon: Icons.alarm_rounded,
                  title: Text(alarmTimeLabel(alarm)),
                  subtitle: Text(alarmSubtitle(alarm)),
                  onTap: () => onEdit(alarm),
                  dimmed: !alarm.isActive,
                  trailing: Switch(
                    value: alarm.isActive,
                    onChanged: (value) => onToggle(alarm, value),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            'Silmek için satırı sola kaydırın. Alarmlar vakit güncellendiğinde '
            'otomatik yeniden planlanır.',
            style: AppTypography.hint.copyWith(
              color: tokens.textTertiary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(Icons.bedtime_rounded, size: 16, color: tokens.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Alarmlar vakit verisi güncellendikçe yeniden planlanır.',
              style: AppTypography.hint.copyWith(color: tokens.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS < 26'da destek yok; izin verilmemişse uyarı + "İzin ver". Her şey
  /// yolundaysa null döner.
  Widget? _permissionBanner() {
    if (!isSupported) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: InfoBanner(
          icon: Icons.info_outline_rounded,
          text:
              'Sesli alarm bu cihazda desteklenmiyor (iOS 26 ve üzeri gerekir). '
              'Alarmlar kaydedilir ancak çalmaz.',
        ),
      );
    }
    if (!isPermissionGranted) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: InfoBanner(
          icon: Icons.notifications_off_rounded,
          text: 'Alarmların çalması için izin gerekiyor.',
          action: TextButton(
            onPressed: onRequestPermission,
            child: const Text('İzin ver'),
          ),
        ),
      );
    }
    return null;
  }
}
```

- [ ] **Step 4: Testleri çalıştır**

Run: `flutter test test/widgets/notifications/alarms_section_test.dart`
Expected: 5 test PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/reminders/alarms_section.dart \
        test/widgets/notifications/alarms_section_test.dart
git commit -m "feat: AlarmsSection sunum widget'i"
```

---

### Task 6: `RemindersScreen` kabuğu ve mutasyonlar

Kabuk hem segmenti hem "+" düğmesini hem de tüm mutasyonları sahiplenir. Her mutasyon aynı üç adımı yapar: manager'a yaz → `AppState`'i tazele → yeniden planla.

**Files:**
- Create: `lib/presentation/screens/reminders_screen.dart`
- Test: `test/widgets/screens/reminders_screen_test.dart`

**Interfaces:**
- Consumes: `NotificationsSection` (Task 4), `AlarmsSection` (Task 5), `ReminderRescheduler` (Task 3)
- Produces: `RemindersScreen({Key? key})` — `ServiceLocator` ve `AppState`'ten kendi bağımlılıklarını çözer. Task 7 sekme 2 olarak barındırır.

- [ ] **Step 1: `RemindersScreen`'i yaz**

`lib/presentation/screens/reminders_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/interfaces/alarm_service.dart';
import '../../core/interfaces/notification_service.dart';
import '../../core/models/alarm.dart';
import '../../core/models/notification_setting.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/exact_alarm_service.dart';
import '../../core/theme/tokens_context.dart';
import '../../features/alarms/domain/alarms_manager.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../services/reminder_rescheduler.dart';
import '../utils/alarm_labels.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/sliding_segment.dart';
import '../widgets/notifications/add_notification_bottom_sheet.dart';
import '../widgets/reminders/alarms_section.dart';
import '../widgets/reminders/notifications_section.dart';
import 'alarm_edit_screen.dart';

enum ReminderTab { notifications, alarms }

/// Bildirimler ve alarmların tek ekranda birleşmiş hali.
///
/// Listeler `AppState`'te tutulur; bu ekran yalnızca mutasyonu sahiplenir.
/// İzin durumu ekran ömrüne bağlı olduğu için burada kalır.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with WidgetsBindingObserver {
  late final NotificationSettingsManager _settingsManager;
  late final NotificationService _notificationService;
  late final ExactAlarmService _exactAlarmService;
  late final AlarmsManager _alarmsManager;
  late final AlarmService _alarmService;
  late final ReminderRescheduler _rescheduler;

  ReminderTab _tab = ReminderTab.notifications;
  bool _hasPermission = false;
  bool _exactAlarmAllowed = true;
  bool _alarmSupported = true;
  bool _alarmGranted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final locator = ServiceLocator();
    _settingsManager = locator.get<NotificationSettingsManager>();
    _notificationService = locator.get<NotificationService>();
    _exactAlarmService = locator.get<ExactAlarmService>();
    _alarmsManager = locator.get<AlarmsManager>();
    _alarmService = locator.get<AlarmService>();
    _rescheduler = locator.get<ReminderRescheduler>();
    _hasPermission = context.read<AppState>().hasNotificationPermission;
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı sistem ayarlarından dönünce izin durumunu tazele.
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final hasPermission = await _notificationService.isPermissionGranted();
    final exactAllowed = await _exactAlarmService.isExactAlarmAllowed();
    final supported = await _alarmService.isSupported();
    final granted = supported
        ? await _alarmService.isPermissionGranted()
        : false;

    if (!mounted) return;
    setState(() {
      _hasPermission = hasPermission;
      _exactAlarmAllowed = exactAllowed;
      _alarmSupported = supported;
      _alarmGranted = granted;
    });
  }

  /// Planlamayı tazeler. Vakit verisi yoksa planlanamaz; silinen/kapatılan
  /// kaydın eski OS kopyası tetiklenmesin diye hepsi iptal edilir. Aktif
  /// ayarlar bir sonraki veri yüklemesinde yeniden planlanır.
  Future<void> _reschedule(AppState appState) async {
    final rescheduled = await _rescheduler.reschedule(
      location: appState.activeLocation,
      prayerTimes: appState.prayerTimes,
      skips: appState.skips,
    );
    if (!rescheduled) await _notificationService.cancelAllNotifications();
  }

  Future<void> _syncNotifications(AppState appState) async {
    appState.setNotificationSettings(await _settingsManager.getSettings());
    await _reschedule(appState);
  }

  Future<void> _syncAlarms(AppState appState) async {
    appState.setAlarms(await _alarmsManager.getAlarms());
    await _reschedule(appState);
  }

  // --- Bildirim mutasyonları ---

  Future<void> _addNotification(PrayerType type, int minutesBefore) async {
    final appState = context.read<AppState>();
    final exists = appState.notificationSettings.any(
      (s) => s.prayerType == type && s.minutesBefore == minutesBefore,
    );
    if (exists) {
      _snack('Bu bildirim zaten mevcut', isError: true);
      return;
    }

    await _settingsManager.addSetting(
      NotificationSetting(
        prayerType: type,
        isActive: true,
        minutesBefore: minutesBefore,
      ),
    );
    await _syncNotifications(appState);
    _snack('Bildirim eklendi');
  }

  Future<void> _updateNotification(
    NotificationSetting original,
    PrayerType type,
    int minutesBefore,
  ) async {
    final appState = context.read<AppState>();
    final duplicate = appState.notificationSettings.any(
      (s) =>
          s.prayerType == type &&
          s.minutesBefore == minutesBefore &&
          !(s.prayerType == original.prayerType &&
              s.minutesBefore == original.minutesBefore),
    );
    if (duplicate) {
      _snack('Bu bildirim zaten mevcut', isError: true);
      return;
    }

    final updated = original.copyWith(
      prayerType: type,
      minutesBefore: minutesBefore,
    );
    final keyChanged =
        type != original.prayerType ||
        minutesBefore != original.minutesBefore;

    if (keyChanged) {
      await _settingsManager.removeSetting(
        prayerType: original.prayerType,
        minutesBefore: original.minutesBefore,
      );
      await _settingsManager.addSetting(updated);
    } else {
      await _settingsManager.updateSetting(updated);
    }

    await _syncNotifications(appState);
    _snack('Bildirim güncellendi');
  }

  Future<void> _deleteNotification(NotificationSetting setting) async {
    final appState = context.read<AppState>();
    await _settingsManager.removeSetting(
      prayerType: setting.prayerType,
      minutesBefore: setting.minutesBefore,
    );
    await _syncNotifications(appState);
    _snack('Bildirim silindi');
  }

  Future<void> _toggleNotification(NotificationSetting setting) async {
    final appState = context.read<AppState>();
    await _settingsManager.updateSetting(
      setting.copyWith(isActive: !setting.isActive),
    );
    await _syncNotifications(appState);
  }

  // --- Alarm mutasyonları ---

  Future<void> _ensureAlarmPermission() async {
    if (!await _alarmService.isSupported()) return;
    if (!await _alarmService.isPermissionGranted()) {
      await _alarmService.requestPermission();
    }
    await _refreshPermissions();
  }

  Future<void> _addOrEditAlarm([Alarm? existing]) async {
    final appState = context.read<AppState>();
    final result = await Navigator.of(context).push<Alarm>(
      MaterialPageRoute(builder: (_) => AlarmEditScreen(alarm: existing)),
    );
    if (result == null) return;

    await _ensureAlarmPermission();
    await _alarmsManager.save(result);
    await _syncAlarms(appState);
  }

  Future<void> _toggleAlarm(Alarm alarm, bool isActive) async {
    final appState = context.read<AppState>();
    await _alarmsManager.setActive(alarm, isActive);
    await _syncAlarms(appState);
  }

  Future<void> _deleteAlarm(Alarm alarm) async {
    final appState = context.read<AppState>();
    await _alarmsManager.delete(alarm.id);
    await _syncAlarms(appState);
    _snack('${alarmTimeLabel(alarm)} alarmı silindi');
  }

  // --- Ekleme düğmesi ---

  void _add() {
    if (_tab == ReminderTab.alarms) {
      _addOrEditAlarm();
      return;
    }
    _showNotificationSheet();
  }

  void _showNotificationSheet({NotificationSetting? initial}) {
    final appState = context.read<AppState>();
    final prayerTime =
        appState.todaysPrayerTime ??
        (appState.prayerTimes.isNotEmpty ? appState.prayerTimes.first : null);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddNotificationBottomSheet(
        prayerTime: prayerTime,
        initialSetting: initial,
        submitLabel: initial == null ? null : 'Güncelle',
        title: initial == null ? null : 'Bildirimi Güncelle',
        onAdd: (type, minutes) => initial == null
            ? _addNotification(type, minutes)
            : _updateNotification(initial, type, minutes),
      ),
    );
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : context.tokens.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: 'Hatırlatıcılar',
        showBack: false,
        actions: [
          AppBarActionButton(
            key: const Key('add_reminder_button'),
            icon: Icons.add_rounded,
            onTap: _add,
            tooltip: _tab == ReminderTab.alarms
                ? 'Alarm ekle'
                : 'Bildirim ekle',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              SlidingSegment<ReminderTab>(
                items: const [
                  SegmentItem(
                    value: ReminderTab.notifications,
                    label: 'Bildirimler',
                    icon: Icons.notifications_rounded,
                  ),
                  SegmentItem(
                    value: ReminderTab.alarms,
                    label: 'Alarmlar',
                    icon: Icons.alarm_rounded,
                  ),
                ],
                selected: _tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<AppState>(
      builder: (context, appState, _) => IndexedStack(
        index: _tab.index,
        children: [
          NotificationsSection(
            settings: appState.notificationSettings,
            hasPermission: _hasPermission,
            exactAlarmAllowed: _exactAlarmAllowed,
            onRequestPermission: () async {
              final granted = await _notificationService.requestPermission();
              appState.setNotificationPermission(granted);
              return granted;
            },
            onPermissionChanged: (granted) {
              setState(() => _hasPermission = granted);
              appState.setNotificationPermission(granted);
            },
            onOpenExactAlarmSettings:
                _notificationService.openExactAlarmSettings,
            onToggle: _toggleNotification,
            onEdit: (setting) => _showNotificationSheet(initial: setting),
            onDelete: _deleteNotification,
          ),
          AlarmsSection(
            alarms: appState.alarms,
            isSupported: _alarmSupported,
            isPermissionGranted: _alarmGranted,
            onRequestPermission: () async {
              await _alarmService.requestPermission();
              await _refreshPermissions();
            },
            onToggle: _toggleAlarm,
            onEdit: _addOrEditAlarm,
            onDelete: _deleteAlarm,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Derlemeyi doğrula**

Run: `flutter analyze`
Expected: `No issues found!`

Hata alırsan çoğu ihtimalle: `AddNotificationBottomSheet`'in `submitLabel`/`title` parametreleri `String?` değil `String` varsayılanlı olabilir. `lib/presentation/widgets/notifications/add_notification_bottom_sheet.dart`'ı oku ve çağrıyı ona göre düzelt — widget'ı değiştirme.

- [ ] **Step 3: Regresyon testini yaz**

Bu, §7'deki iki hatanın testi: bir mutasyondan sonra `AppState` tazelenmeli.

`test/widgets/screens/reminders_screen_test.dart`:

```dart
import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/interfaces/notification_service.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/core/services/exact_alarm_service.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:ezanvakti/features/alarms/domain/alarms_manager.dart';
import 'package:ezanvakti/features/notifications/domain/notification_scheduler.dart';
import 'package:ezanvakti/features/notifications/domain/notification_settings_manager.dart';
import 'package:ezanvakti/presentation/screens/reminders_screen.dart';
import 'package:ezanvakti/presentation/services/reminder_rescheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

class _StubAlarmService implements AlarmService {
  @override
  Future<bool> isSupported() async => true;

  @override
  Future<bool> isPermissionGranted() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> cancelAllAlarms() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeStorage storage;
  late AppState appState;

  setUp(() async {
    storage = FakeStorage();
    await storage.init();
    appState = AppState();

    final locator = ServiceLocator();
    final notificationService = FakeNotificationService();
    final alarmService = _StubAlarmService();

    locator.register<LocalStorage>(storage);
    locator.register<NotificationService>(notificationService);
    locator.register<ExactAlarmService>(ExactAlarmService());
    locator.register<AlarmService>(alarmService);
    locator.register<AlarmsManager>(AlarmsManager(storage: storage));
    locator.register<NotificationSettingsManager>(
      NotificationSettingsManager(storage: storage),
    );
    locator.register<ReminderRescheduler>(
      ReminderRescheduler(
        notificationScheduler: NotificationScheduler(
          notificationService: notificationService,
          storage: storage,
        ),
        alarmScheduler: AlarmScheduler(
          alarmService: alarmService,
          storage: storage,
        ),
      ),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: wrapWithTheme(const RemindersScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('Segment Alarmlar a gecince alarm bolumu gorunur', (
    tester,
  ) async {
    appState.setAlarms(const [
      Alarm(
        id: 'sahur',
        kind: AlarmKind.fixed,
        label: 'Sahur',
        hour: 6,
        minute: 30,
      ),
    ]);
    await pump(tester);

    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();

    expect(find.text('06:30'), findsOneWidget);
  });

  testWidgets('Alarm silinince AppState tazelenir', (tester) async {
    const alarm = Alarm(
      id: 'sahur',
      kind: AlarmKind.fixed,
      label: 'Sahur',
      hour: 6,
      minute: 30,
    );
    // LocalStorage tek tek kaydeder; toplu `saveAlarms` yok.
    await storage.saveAlarm(alarm);
    appState.setAlarms(const [alarm]);
    await pump(tester);

    await tester.tap(find.text('Alarmlar'));
    await tester.pumpAndSettle();

    // Satiri sola kaydirip silmek yerine mutasyonu dogrudan cagirmak yerine,
    // AlarmsManager uzerinden sil ve ekranin AppState'i tazelemesini bekle.
    // (Swipe + onay diyalogu ayri bir testin konusu.)
    await tester.drag(find.text('06:30'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(
      appState.alarms,
      isEmpty,
      reason: 'Mutasyon sonrasi AppState tazelenmezse ana ekrandaki '
          'SIRADAKI karti bayat alarm gosterir',
    );
  });
}
```

> **Not:** `SwipeToDelete`'in onay diyalogundaki düğme metnini `lib/presentation/widgets/common/swipe_to_delete.dart`'tan doğrula; `Sil` değilse testi ona göre düzelt. Diyalog yoksa `drag` sonrası doğrudan silinir, `tap` adımını kaldır.

- [ ] **Step 4: Testleri çalıştır**

Run: `flutter test test/widgets/screens/reminders_screen_test.dart`
Expected: 2 test PASS. `ServiceLocator` testler arası durum taşıyorsa `setUp` içinde temizleme metodu (`reset`/`clear`) ara; yoksa `register` üzerine yazdığı için sorun olmaz.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/reminders_screen.dart \
        test/widgets/screens/reminders_screen_test.dart
git commit -m "feat: Hatirlaticilar ekrani ve mutasyonlari"
```

---

### Task 7: `HomePage` kabuğu ve eski ekranların kaldırılması

Bu task tek commit olmak zorunda: `home_page.dart` eski ekranları import ettiği sürece silinemezler.

**Files:**
- Modify: `lib/presentation/pages/home_page.dart`
- Modify: `lib/presentation/widgets/home/home_top_bar.dart`
- Modify: `lib/presentation/screens/home_screen.dart`
- Modify: `lib/presentation/screens/calendar_screen.dart`
- Delete: `lib/presentation/widgets/home/home_menu_sheet.dart`
- Delete: `lib/presentation/screens/alarms_screen.dart`
- Delete: `lib/presentation/screens/notification_settings_screen.dart`
- Test: `test/widgets/screens/home_page_nav_test.dart`

**Interfaces:**
- Consumes: `AppNavBar`, `NavItem` (Task 2), `ReminderRescheduler` (Task 3), `RemindersScreen` (Task 6)
- Produces: yok (yaprak)

- [ ] **Step 1: `HomeTopBar`'ı Ayarlar'a bağla**

`lib/presentation/widgets/home/home_top_bar.dart`: `onMenuTap` → `onSettingsTap`, ikon `Icons.menu_rounded` → `Icons.settings_rounded`. Sınıf yorumunu güncelle:

```dart
/// Ana ekranın üst çubuğu: konum · ayarlar.
```

Alan ve parametre adları:

```dart
  final VoidCallback onSettingsTap;
  // ...
  required this.onSettingsTap,
```

`GestureDetector`:

```dart
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSettingsTap,
                child: Icon(
                  Icons.settings_rounded,
                  size: 22,
                  color: tokens.textSecondary,
                ),
              ),
```

- [ ] **Step 2: `HomeScreen`'den menüyü çıkar**

`lib/presentation/screens/home_screen.dart`:
- `import '../widgets/home/home_menu_sheet.dart';` satırını sil.
- `_openMenu()` metodunu sil.
- `onCalendarTap` ve `onNotificationSettingsTap` alanlarını sil; yerine sekme geçişi için tek callback ekle:

```dart
  /// "Tümünü gör" — Hatırlatıcılar sekmesine geçer (push değil).
  final VoidCallback? onSeeReminders;
```

- `HomeTopBar` çağrısını güncelle:

```dart
              HomeTopBar(
                locationName: widget.location.displayName,
                onLocationTap: widget.onLocationTap,
                onSettingsTap: widget.onSettingsTap ?? () {},
                isRefreshing: widget.isRefreshing,
              ),
```

- `UpcomingCard`'ın `onSeeAll` bağlantısını güncelle:

```dart
          onSeeAll: widget.onSeeReminders ?? () {},
```

- [ ] **Step 3: `CalendarScreen`'in geri okunu kaldır**

`lib/presentation/screens/calendar_screen.dart` — `_CalendarAppBar`'daki `leading:` bloğunu (93-107 satırları) sil ve `AppBar`'a ekle:

```dart
      automaticallyImplyLeading: false,
```

- [ ] **Step 4: `HomePage`'i üç sekmeye çevir**

`lib/presentation/pages/home_page.dart`:

Import'lardan sil:
```dart
import '../screens/notification_settings_screen.dart';
import '../screens/alarms_screen.dart';
import '../widgets/common/sliding_segment.dart';
```

Import'lara ekle:
```dart
import '../screens/reminders_screen.dart';
import '../services/reminder_rescheduler.dart';
import '../widgets/common/app_nav_bar.dart';
```

`build`'i değiştir:

```dart
  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Sekme geçmişi biriktirmek geri tuşunu öngörülemez kılar; 2. veya 3.
      // sekmedeyken geri ilk sekmeye döner, orada uygulamadan çıkar.
      canPop: _tabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tabIndex != 0) setState(() => _tabIndex = 0);
      },
      child: Scaffold(
        // Alt gezinme AppSurface'in disinda kaldigi icin zemini Scaffold verir;
        // seffaf birakilirsa arkasinda hicbir sey boyanmiyor.
        backgroundColor: context.tokens.backgroundStops.last,
        body: AppSurface(
          safeAreaTop: false,
          safeAreaBottom: false,
          child: IndexedStack(
            index: _tabIndex,
            children: [
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return HomeScreen(
                    location: appState.activeLocation!,
                    todaysPrayerTime: appState.todaysPrayerTime,
                    tomorrowsPrayerTime: appState.tomorrowsPrayerTime,
                    lastUpdateTime: appState.lastUpdateTime,
                    isLoading: appState.isLoading,
                    isRefreshing: appState.isRefreshing,
                    prayerTimes: appState.prayerTimes,
                    notificationSettings: appState.notificationSettings,
                    alarms: appState.alarms,
                    skips: appState.skips,
                    onSkipChanged: _toggleSkip,
                    errorMessage: appState.errorMessage,
                    onRefresh: _refreshData,
                    onGpsRefresh: _manualGpsRefresh,
                    onSettingsTap: _navigateToSettings,
                    onSeeReminders: () => setState(() => _tabIndex = 2),
                    onLocationTap: _navigateToLocationList,
                  );
                },
              ),
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return CalendarScreen(
                    location: appState.activeLocation!,
                    prayerTimes: appState.prayerTimes,
                    onRefresh: _refreshData,
                    isLoading: appState.isLoading,
                    errorMessage: appState.errorMessage,
                  );
                },
              ),
              const RemindersScreen(),
            ],
          ),
        ),
        bottomNavigationBar: AppNavBar(
          items: const [
            NavItem(label: 'Vakitler', icon: Icons.schedule_rounded),
            NavItem(label: 'Takvim', icon: Icons.calendar_month_rounded),
            NavItem(label: 'Hatırlatıcılar', icon: Icons.notifications_rounded),
          ],
          selected: _tabIndex,
          onChanged: (index) => setState(() => _tabIndex = index),
        ),
      ),
    );
  }
```

`_buildBottomNav()`, `_navigateToCalendar()`, `_navigateToNotificationSettings()` ve `_reloadNotificationSettings()` metotlarını **sil**.

- [ ] **Step 5: Yeniden planlamayı `ReminderRescheduler`'a bağla**

`_loadPrayerData` içinde 270-281 satırlarındaki blok:

```dart
      if (data.all.isEmpty) return;

      await ServiceLocator().get<ReminderRescheduler>().reschedule(
        location: location,
        prayerTimes: data.all,
        skips: data.skips,
      );
```

`_rescheduleOnResume` içindeki `try` bloğu:

```dart
    _lastResumeReschedule = now;
    try {
      await ServiceLocator().get<ReminderRescheduler>().reschedule(
        location: location,
        prayerTimes: prayerTimes,
        skips: appState.skips,
      );
      AppLogger().debug('Notifications + alarms rescheduled on resume');
    } catch (e) {
      AppLogger().warning('Resume reschedule failed (ignored)', e);
    }
```

`_toggleSkip` içindeki blok:

```dart
    try {
      await ServiceLocator().get<ReminderRescheduler>().reschedule(
        location: appState.activeLocation,
        prayerTimes: appState.prayerTimes,
        skips: next,
      );
    } catch (e) {
      AppLogger().warning('Atlama sonrasi yeniden planlama basarisiz', e);
    }
```

`_toggleSkip`'teki erken `return` (`if (location == null || prayerTimes.isEmpty) return;`) artık gereksiz — `reschedule` bunu kendi ele alıyor; sil.

Kullanılmayan import'ları temizle: `notification_scheduler.dart`, `alarm_scheduler.dart`, `alarms_manager.dart` hâlâ `_loadPrayerData`'daki `setAlarms` için gerekli olabilir — analyzer'ın dediğini yap.

- [ ] **Step 6: Eski dosyaları sil**

```bash
git rm lib/presentation/widgets/home/home_menu_sheet.dart \
       lib/presentation/screens/alarms_screen.dart \
       lib/presentation/screens/notification_settings_screen.dart
```

- [ ] **Step 7: Kabuk testini yaz**

`test/widgets/screens/home_page_nav_test.dart`:

```dart
import 'package:ezanvakti/presentation/widgets/common/app_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

/// `HomePage` tum servis grafigini cozdugu icin burada kabugun davranisi
/// (PopScope + sekme degisimi) ayni yapiyla izole olarak dogrulanir.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tabIndex != 0) setState(() => _tabIndex = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tabIndex,
          children: const [
            Center(child: Text('vakitler-govde')),
            Center(child: Text('takvim-govde')),
            Center(child: Text('hatirlaticilar-govde')),
          ],
        ),
        bottomNavigationBar: AppNavBar(
          items: const [
            NavItem(label: 'Vakitler', icon: Icons.schedule_rounded),
            NavItem(label: 'Takvim', icon: Icons.calendar_month_rounded),
            NavItem(label: 'Hatırlatıcılar', icon: Icons.notifications_rounded),
          ],
          selected: _tabIndex,
          onChanged: (index) => setState(() => _tabIndex = index),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Sekme degisimi dogru govdeyi one alir', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const _Shell()));

    await tester.tap(find.text('Takvim'));
    await tester.pumpAndSettle();

    // IndexedStack hepsini agacta tutar; gorunur olan test edilir.
    expect(find.text('takvim-govde'), findsOneWidget);
  });

  testWidgets('Sekme 2 de geri tusu ilk sekmeye doner', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const _Shell()));

    await tester.tap(find.text('Hatırlatıcılar'));
    await tester.pumpAndSettle();

    final navBar = tester.widget<AppNavBar>(find.byType(AppNavBar));
    expect(navBar.selected, 2);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      tester.widget<AppNavBar>(find.byType(AppNavBar)).selected,
      0,
      reason: 'Sekme gecmisi biriktirmeden ilk sekmeye donmeli',
    );
  });
}
```

> `wrapWithTheme` çocuğu `Scaffold(body: ...)` içine koyuyor; `_Shell` kendi `Scaffold`'unu taşıdığı için iç içe iki `Scaffold` olur — bu testte sorun değil. `handlePopRoute` çalışmazsa `tester.binding.defaultBinaryMessenger` üzerinden sistem geri olayı gönder veya `Navigator.maybePop` kullan.

- [ ] **Step 8: Tüm testleri çalıştır**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` ve tüm testler PASS

- [ ] **Step 9: Commit**

```bash
git add -A lib/ test/
git commit -m "feat: uc sekmelik navigasyon kabugu

Vakitler, Takvim ve Hatirlaticilar sekmeleri AppNavBar ile tek kabukta
toplandi. Hamburger menu kalkti, Ayarlar ust cubuktaki gear'a bagli.
Eski Alarmlar ve Bildirimler ekranlari silindi."
```

---

### Task 8: Kapanış

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Ölü kod taraması**

```bash
grep -rn "showHomeMenu\|onMenuTap\|onCalendarTap\|onNotificationSettingsTap\|_reloadNotificationSettings\|NotificationSettingsScreen\|AlarmsScreen" lib/ test/ integration_test/
```

Expected: boş çıktı. Kalan varsa temizle.

- [ ] **Step 2: Tam doğrulama**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`, tüm testler PASS. Sayıyı not al.

- [ ] **Step 3: Simülatörde gör**

```bash
xcrun simctl list devices booted
flutter run -d <device-id>
```

Elle kontrol et:
1. Alt barda üç sekme; seçili olanın altında ince accent çizgi.
2. Takvim sekmesinde geri oku **yok**, başlıkta konum ve gün sayısı var.
3. Hatırlatıcılar sekmesinde segment; "+" Bildirimler'de bildirim sheet'i, Alarmlar'da alarm ekranı açıyor.
4. Bildirim eklendikten sonra Vakitler sekmesine dön — SIRADAKİ kartı yeni bildirimi gösteriyor (§7/H1'in düzeldiğinin kanıtı).
5. Vakitler sekmesindeki gear Ayarlar'ı açıyor.
6. Hatırlatıcılar sekmesindeyken geri tuşu (Android) veya kaydırma (iOS) Vakitler'e dönüyor.

- [ ] **Step 4: CHANGELOG**

`CHANGELOG.md` → `## [0.3.0]` → `### Değişti` altına:

```markdown
- Gezinme yeniden düzenlendi: **Vakitler · Takvim · Hatırlatıcılar** üç sekmesi
  alt çubukta toplandı. Hamburger menü kaldırıldı; Ayarlar'a Vakitler
  sekmesinin sağ üstündeki dişli ikonundan gidiliyor.
- Bildirimler ve Alarmlar tek **Hatırlatıcılar** ekranında birleşti; aralarında
  üstteki segment ile geçiliyor.
```

`### Düzeltildi` altına:

```markdown
- Bildirim veya alarm eklendikten/silindikten sonra ana ekrandaki SIRADAKİ
  kartı eski listeyi göstermeye devam ediyordu. Listeler artık tek yerde
  tutuluyor.
```

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: navigasyon degisikligini CHANGELOG'a ekle"
```

---

## Self-Review Notları

**Spec kapsamı:** §4.1 → Task 7 · §4.2 → Task 2 · §4.3 → Task 7/Step 4 · §4.4 → Task 7/Step 1-3 · §5.1-5.4 → Task 4, 5, 6 · §6.1 → Task 1, 2, 3, 6, 7 · §6.2 → Task 4, 5, 6 · §6.3 → Task 3 · §6.4 → Task 6, 7 · §7 → Task 3, 6, 7 · §9 → her task'ın test adımları · §10/V1 → Task 2/Step 1 son test · §10/V6 → Task 8/Step 3.

**Bilinçli boşluk:** Spec §9'daki "`+` doğru tipi açıyor" testi Task 6'da yazılmadı — `showModalBottomSheet` ve `Navigator.push` widget testinde `ServiceLocator`'ın tüm grafiğini gerektiriyor. Bunun yerine Task 8/Step 3'te simülatörde elle doğrulanıyor. Otomatik test isteniyorsa `_add()`'i saf bir fonksiyona ayırmak gerekir; bu turda yapılmadı.
