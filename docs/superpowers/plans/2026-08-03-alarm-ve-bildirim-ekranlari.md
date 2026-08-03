# Alarm ve Bildirim Ekranları (Faz 3.2–3.3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alarmlar, alarm ekleme ve bildirimler ekranlarını tasarım sistemine geçirmek; bunu yaparken listeler için ortak `GroupedList` bileşenini ve durum widget'larını token'lara taşımak.

**Architecture:** Üç ekran da aynı iskeleti paylaşır: `AppSurface` zemin, `SectionLabel` başlık, ayıraçlı `GroupedList` grup, satırlarda `Switch` ve sola kaydırarak silme. Bu ortaklık önce bileşen olarak yazılır, sonra üç ekran ona oturur. Ekranların hiçbiri renk sabiti yazmaz.

**Tech Stack:** Flutter, `provider`, `intl`, `flutter_test`. Yeni paket eklenmez.

**Spec:** `docs/superpowers/specs/2026-08-01-redesign-0.3.0-design.md` §4.1, §6.2–6.4
**Önceki planlar:** `2026-08-01-tema-altyapisi.md`, `2026-08-02-ana-ekran.md` (ikisi de tamamlandı)

## Global Constraints

- Kod/dosya/sınıf/fonksiyon adları **İngilizce**; kullanıcıya görünen metin ve yorumlar Türkçe.
- **Yeni ve dokunulan kod renk sabiti yazmaz.** Renk `context.tokens`, tipografi `AppTypography`. `AppTheme.gold`, `Colors.white`, `Colors.orange` bu planın dokunduğu dosyalarda yasak.
- Font boyutu için çıplak sayı yok; `AppTypography` sabitleri. Ölçek: `11 · 12 · 13 · 14 · 16 · 17 · 20 · 24 · 44 · 62`.
- Kontrol animasyonları **220 ms `Curves.easeOutCubic`**.
- Yarıçap: 16 (grup) · 12 (alan/çip) · 999 (pill). Grup satır yüksekliği 74, ayıraç satırın ikon hizasından başlar (`indent: 52`).
- Uyarı ve pasif durumlar **nötr kalır**; vurgu rengi yalnızca vakit bilgisi ve tek birincil eylem için.
- Her task sonunda `flutter analyze` temiz ve `flutter test` yeşil.
- Commit'ler `redesign/0.3.0` branch'ine.

### Ekran görüntüsü alırken

`flutter drive` koşusu, alarm tohumlaması yüzünden AlarmKit izin dialog'unu ekranda **açık bırakıyor**. Sistem alert'i açıkken Flutter yeni kare çizmez ve `takeScreenshot` bayat kare döndürür — 18 kare de aynı çıkar. `simctl uninstall` bu alert'i kapatmaz.

**Her görüntü koşusundan önce simülatörü sıfırla:**

```bash
UDID=<simulator-udid>
xcrun simctl shutdown $UDID; sleep 3
xcrun simctl boot $UDID; sleep 10
xcrun simctl uninstall $UDID com.ekrembulbul.ezanvakti
rm -rf screenshots
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart -d $UDID
```

**Sonucu daima şununla doğrula** — 18 çıkmalı, 1 çıkarsa kareler geçersizdir:

```bash
shasum screenshots/*.png | awk '{print $1}' | sort -u | wc -l
```

---

## File Structure

**Yeni**

| Dosya | Sorumluluk |
|---|---|
| `lib/presentation/widgets/common/grouped_list.dart` | `GroupedList` (r16 yüzey + kenarlık) ve `GroupedRow` (74px satır, ikon + başlık/alt metin + sağ öğe) |
| `lib/presentation/widgets/common/info_banner.dart` | İzin uyarısı bandı: ikon + metin + opsiyonel eylem |
| `lib/presentation/widgets/common/swipe_to_delete.dart` | `Dismissible` sarmalayıcı; onay diyaloğu ve arka planı tek yerde |

**Değişen**

| Dosya | Değişiklik |
|---|---|
| `lib/presentation/widgets/common/state_widgets.dart` | `AppTheme` yerine token'lar |
| `lib/features/alarms/domain/alarm_scheduler.dart` | Planlama hatası yakalanır (aşağıda Task 3) |
| `lib/presentation/screens/alarms_screen.dart` | Yeniden düzenlenir; `_AlarmEditScreen` ayrı dosyaya çıkar |
| `lib/presentation/screens/notification_settings_screen.dart` | Yeniden düzenlenir |
| `lib/presentation/widgets/notifications/notification_tile.dart` | `GroupedRow`'a devredilir |
| `lib/presentation/widgets/notifications/permission_warning_card.dart` | `InfoBanner`'a devredilir |

**Yeni (bölünme)**

| Dosya | Sorumluluk |
|---|---|
| `lib/presentation/screens/alarm_edit_screen.dart` | `alarms_screen.dart` 944 satır; düzenleme ekranı kendi dosyasına taşınır |

---

## Task 1: `GroupedList`, `GroupedRow`, `InfoBanner`

**Files:**
- Create: `lib/presentation/widgets/common/grouped_list.dart`
- Create: `lib/presentation/widgets/common/info_banner.dart`
- Test: `test/widgets/grouped_list_test.dart`

**Interfaces:**
- Consumes: `context.tokens`, `AppTypography.rowTitle/rowSubtitle/hint`
- Produces:
  - `class GroupedList extends StatelessWidget` — `GroupedList({required List<Widget> children, Key? key})`
  - `class GroupedRow extends StatelessWidget` — `GroupedRow({IconData? icon, required Widget title, Widget? subtitle, Widget? trailing, VoidCallback? onTap, bool dimmed = false, Key? key})`
  - `class InfoBanner extends StatelessWidget` — `InfoBanner({required IconData icon, required String text, Widget? action, Key? key})`

- [ ] **Step 1: Testi yaz**

Create: `test/widgets/grouped_list_test.dart`

```dart
import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:ezanvakti/presentation/widgets/common/info_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_harness.dart';

void main() {
  group('GroupedList', () {
    testWidgets('Satirlar arasina ayirac koyar, uclara koymaz', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const GroupedList(
            children: [
              GroupedRow(title: Text('bir')),
              GroupedRow(title: Text('iki')),
              GroupedRow(title: Text('üç')),
            ],
          ),
        ),
      );

      // Uc satir -> iki ayirac.
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('Tek satirda ayirac cizilmez', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const GroupedList(children: [GroupedRow(title: Text('tek'))]),
        ),
      );

      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('Grup yuzey ve kenarlik token larini kullanir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const GroupedList(children: [GroupedRow(title: Text('bir'))]),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(GroupedList),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      final tokens = tokensFor();

      expect(decoration.color, tokens.surface);
      expect(decoration.border, Border.all(color: tokens.border));
    });
  });

  group('GroupedRow', () {
    testWidgets('Ikon, baslik, alt metin ve sag oge cizilir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const GroupedList(
            children: [
              GroupedRow(
                icon: Icons.alarm_rounded,
                title: Text('Sahur'),
                subtitle: Text('Her gün'),
                trailing: Text('sağ'),
              ),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.alarm_rounded), findsOneWidget);
      expect(find.text('Sahur'), findsOneWidget);
      expect(find.text('Her gün'), findsOneWidget);
      expect(find.text('sağ'), findsOneWidget);
    });

    testWidgets('onTap verilince dokunma tetiklenir', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrapWithTheme(
          GroupedList(
            children: [
              GroupedRow(
                title: const Text('Sahur'),
                onTap: () => tapped = true,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Sahur'));
      expect(tapped, isTrue);
    });

    testWidgets('dimmed satir sondurulur', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const GroupedList(
            children: [GroupedRow(title: Text('Pasif'), dimmed: true)],
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(GroupedRow),
              matching: find.byType(Opacity),
            )
            .first,
      );

      expect(opacity.opacity, lessThan(1.0));
    });
  });

  group('InfoBanner', () {
    testWidgets('Ikon, metin ve eylem cizilir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          InfoBanner(
            icon: Icons.notifications_off_rounded,
            text: 'Alarmların çalması için izin gerekiyor.',
            action: TextButton(onPressed: () {}, child: const Text('İzin ver')),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
      expect(
        find.text('Alarmların çalması için izin gerekiyor.'),
        findsOneWidget,
      );
      expect(find.text('İzin ver'), findsOneWidget);
    });

    testWidgets('Uyari notr kalir — vurgu rengi kullanilmaz', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const InfoBanner(
            icon: Icons.info_outline_rounded,
            text: 'Bilgi',
          ),
        ),
      );

      final tokens = tokensFor();
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      final decoration = container.decoration! as BoxDecoration;

      // Spec §4.1: uyari, secim ve pasif durumlar notr kalir.
      expect(decoration.color, isNot(tokens.accent));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.info_outline_rounded)).color,
        isNot(tokens.accent),
      );
    });
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/widgets/grouped_list_test.dart`
Expected: FAIL — dosyalar yok.

- [ ] **Step 3: `grouped_list.dart`'ı yaz**

Create: `lib/presentation/widgets/common/grouped_list.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Ayıraçlı satır grubu.
///
/// Tasarımın "kart içinde kart yok" kuralı gereği tek yüzey seviyesi kullanır:
/// grup bir yüzey, içindeki satırlar ayıraçla bölünür.
class GroupedList extends StatelessWidget {
  final List<Widget> children;

  const GroupedList({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                // Ayıraç satırın ikon hizasından başlar.
                indent: 52,
                color: tokens.divider,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// [GroupedList] içindeki tek satır: ikon · başlık/alt metin · sağ öğe.
class GroupedRow extends StatelessWidget {
  final IconData? icon;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Pasif satırlar (kapalı bildirim gibi) söndürülür.
  final bool dimmed;

  const GroupedRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final row = SizedBox(
      height: 74,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(
                width: 22,
                child: Icon(icon, size: 20, color: tokens.textSecondary),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: AppTypography.rowTitle.copyWith(
                      color: tokens.textPrimary,
                    ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    DefaultTextStyle.merge(
                      style: AppTypography.rowSubtitle.copyWith(
                        color: tokens.textSecondary,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );

    final content = Opacity(opacity: dimmed ? 0.45 : 1.0, child: row);

    if (onTap == null) return content;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
```

- [ ] **Step 4: `info_banner.dart`'ı yaz**

Create: `lib/presentation/widgets/common/info_banner.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// İzin uyarısı ve bilgilendirme bandı.
///
/// Spec §4.1: uyarı, seçim ve pasif durumlar **nötr kalır** — vurgu rengi
/// yalnızca vakit bilgisi ve tek birincil eylem içindir. Bu yüzden band
/// yüzey/kenarlık token'larını kullanır, accent'i değil.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tokens.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.hint.copyWith(color: tokens.textSecondary),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Testleri çalıştır, analiz, commit**

```bash
flutter test test/widgets/grouped_list_test.dart
flutter analyze && flutter test
git add lib/presentation/widgets/common/grouped_list.dart lib/presentation/widgets/common/info_banner.dart test/widgets/grouped_list_test.dart
git commit -m "feat: GroupedList, GroupedRow ve InfoBanner

Uc ekranin paylastigi liste iskeleti: tek yuzey, satirlar ayiracla
bolunuyor, ayirac ikon hizasindan basliyor. InfoBanner izin uyarilari
icin; spec geregi notr kaliyor, vurgu rengi kullanmiyor."
```

---

## Task 2: Durum widget'larını token'lara taşı

`LoadingState` / `ErrorState` / `EmptyState` üç ekranda da kullanılıyor ve hâlâ `AppTheme.gold` + `Colors.white` yazıyor. Ekranlara geçmeden bunlar taşınmalı, yoksa yeni ekranlarda eski renkler sızar.

**Files:**
- Modify: `lib/presentation/widgets/common/state_widgets.dart`
- Test: `test/widgets/state_widgets_test.dart`

**Interfaces:**
- Consumes: `context.tokens`, `AppTypography`
- Produces: aynı üç sınıf, aynı parametreler (çağıranlar değişmez)

- [ ] **Step 1: Testi yaz**

Create: `test/widgets/state_widgets_test.dart`

```dart
import 'package:ezanvakti/presentation/widgets/common/state_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_harness.dart';

void main() {
  testWidgets('LoadingState gostergeyi vurgu renginde cizer', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const LoadingState()));

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );

    expect(indicator.color, tokensFor().accent);
    expect(find.text('Yükleniyor...'), findsOneWidget);
  });

  testWidgets('ErrorState mesaji ve yeniden dene dugmesini gosterir', (
    tester,
  ) async {
    var retried = false;

    await tester.pumpWidget(
      wrapWithTheme(
        ErrorState(message: 'Veri alınamadı', onRetry: () => retried = true),
      ),
    );

    expect(find.text('Veri alınamadı'), findsOneWidget);

    await tester.tap(find.text('Yeniden Dene'));
    expect(retried, isTrue);
  });

  testWidgets('ErrorState onRetry yoksa dugme cizilmez', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(const ErrorState(message: 'Veri alınamadı')),
    );

    expect(find.text('Yeniden Dene'), findsNothing);
  });

  testWidgets('EmptyState ikon, mesaj ve alt metni gosterir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const EmptyState(
          icon: Icons.alarm_off_rounded,
          message: 'Henüz alarm yok',
          subtitle: 'Sabit saatli veya vakte göre alarm ekle',
        ),
      ),
    );

    expect(find.byIcon(Icons.alarm_off_rounded), findsOneWidget);
    expect(find.text('Henüz alarm yok'), findsOneWidget);
    expect(find.text('Sabit saatli veya vakte göre alarm ekle'), findsOneWidget);
  });

  testWidgets('Durum widget lari renk sabiti yazmaz — metinler token renginde', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const EmptyState(icon: Icons.alarm_off_rounded, message: 'Boş'),
      ),
    );

    final tokens = tokensFor();
    final message = tester.widget<Text>(find.text('Boş'));

    expect(message.style!.color, tokens.textPrimary);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/widgets/state_widgets_test.dart`
Expected: FAIL — `LoadingState` göstergesi `AppTheme.gold`, `accent` değil.

- [ ] **Step 3: `state_widgets.dart`'ı yeniden yaz**

Modify: `lib/presentation/widgets/common/state_widgets.dart` — dosyanın tamamı:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

class LoadingState extends StatelessWidget {
  final String message;

  const LoadingState({super.key, this.message = 'Yükleniyor...'});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: tokens.accent),
          const SizedBox(height: 20),
          Text(
            message,
            style: AppTypography.rowSubtitle.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final errorColor = Theme.of(context).colorScheme.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Yeniden Dene'),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: tokens.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: tokens.textTertiary),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.rowSubtitle.copyWith(
                  color: tokens.textTertiary,
                  height: 1.5,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 32), action!],
          ],
        ),
      ),
    );
  }
}
```

> `ElevatedButton` artık kendi renklerini `elevatedButtonTheme`'den alıyor
> (Plan 1'de token'lara bağlandı); `styleFrom` ile ezmeye gerek yok.

- [ ] **Step 4: Testler, analiz, commit**

```bash
flutter test test/widgets/state_widgets_test.dart
flutter analyze && flutter test
git add lib/presentation/widgets/common/state_widgets.dart test/widgets/state_widgets_test.dart
git commit -m "refactor: durum widget'larini token'lara tasi

LoadingState/ErrorState/EmptyState hala AppTheme.gold ve Colors.white
yaziyordu; uc ekranda birden kullanildiklari icin ekranlara gecmeden
tasindilar. Hata rengi ColorScheme.error uzerinden geliyor."
```

---

## Task 3: Alarm planlama hatasını yakala

Kullanıcı alarm iznini reddettiğinde `AlarmScheduler.scheduleAlarms` yakalanmamış `PlatformException` fırlatıyor:

```
PlatformException(schedule_failed, Error Domain=com.apple.AlarmKit.Alarm Code=1)
  NativeAlarmService.scheduleAlarm (native_alarm_service.dart:44)
  AlarmScheduler.scheduleAlarms (alarm_scheduler.dart:39)
  _HomePageState._loadMoreDataInBackground (home_page.dart:248)
```

`_loadMoreDataInBackground` bunu sarmalamıyor; **her veri yüklemesinde** yakalanmamış async hata oluşuyor. Ekranlara geçmeden kapanmalı, yoksa görüntü koşuları kirli kalır.

**Files:**
- Modify: `lib/features/alarms/domain/alarm_scheduler.dart`
- Test: `test/alarms/alarm_scheduler_error_test.dart`

**Interfaces:**
- Consumes: `AlarmService`, `LocalStorage`, `AppLogger`
- Produces: `AlarmScheduler.scheduleAlarms` imzası **değişmez**; artık tek tek alarm hatalarını yutmadan loglayıp diğerlerine devam eder.

- [ ] **Step 1: Testi yaz**

Create: `test/alarms/alarm_scheduler_error_test.dart`

```dart
import 'package:ezanvakti/core/interfaces/alarm_service.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ilk alarmda patlayan, digerlerinde basarili olan servis.
class _FlakyAlarmService implements AlarmService {
  final List<String> scheduled = [];
  int cancelAllCount = 0;

  @override
  Future<void> cancelAllAlarms() async => cancelAllCount++;

  @override
  Future<void> scheduleAlarm({
    required String id,
    required DateTime scheduledTime,
    required String label,
    required String soundId,
    required bool vibrate,
    required bool snoozeEnabled,
    required int snoozeMinutes,
  }) async {
    if (id == 'patlayan') {
      throw PlatformException(code: 'schedule_failed', message: 'izin yok');
    }
    scheduled.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StorageWithAlarms implements LocalStorage {
  final List<Alarm> alarms;

  _StorageWithAlarms(this.alarms);

  @override
  Future<List<Alarm>> getAlarms() async => alarms;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Alarm fixed(String id, int hour) => Alarm(
    id: id,
    kind: AlarmKind.fixed,
    hour: hour,
    minute: 0,
  );

  test('Bir alarm planlanamazsa digerleri planlanmaya devam eder', () async {
    final service = _FlakyAlarmService();
    final scheduler = AlarmScheduler(
      alarmService: service,
      storage: _StorageWithAlarms([
        fixed('patlayan', 6),
        fixed('saglam', 7),
      ]),
    );

    // Yakalanmamis istisna firlatmamali.
    await scheduler.scheduleAlarms(prayerTimes: const []);

    expect(service.scheduled, ['saglam']);
  });

  test('Alarm listesi bos olsa da mevcut planlar temizlenir', () async {
    final service = _FlakyAlarmService();
    final scheduler = AlarmScheduler(
      alarmService: service,
      storage: _StorageWithAlarms([]),
    );

    await scheduler.scheduleAlarms(prayerTimes: const []);

    expect(service.cancelAllCount, 1);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/alarms/alarm_scheduler_error_test.dart`
Expected: FAIL — ilk test `PlatformException` ile düşer.

- [ ] **Step 3: `alarm_scheduler.dart`'ı düzelt**

Modify: `lib/features/alarms/domain/alarm_scheduler.dart` — import ekle:

```dart
import '../../../core/utils/app_logger.dart';
```

Sınıfa logger alanı ekle ve yapıcıyı güncelle:

```dart
  final AlarmService alarmService;
  final LocalStorage storage;
  final AppLogger _logger;

  AlarmScheduler({
    required this.alarmService,
    required this.storage,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger();
```

`scheduleAlarms` içindeki `scheduleAlarm` çağrısını sarmala:

```dart
      // Tek bir alarm planlanamazsa (ör. kullanıcı izni reddetti) diğerleri
      // etkilenmemeli. Hata yutulmaz, loglanır: sessiz başarısızlık debug'ı
      // imkânsız kılar.
      try {
        await alarmService.scheduleAlarm(
          id: alarm.id,
          scheduledTime: fire,
          label: alarm.label,
          soundId: alarm.soundId,
          vibrate: alarm.vibrate,
          snoozeEnabled: alarm.snoozeEnabled,
          snoozeMinutes: alarm.snoozeMinutes,
        );
      } catch (e) {
        _logger.warning('Alarm planlanamadı (id: ${alarm.id})', e);
      }
```

- [ ] **Step 4: Testler, analiz, commit**

```bash
flutter test test/alarms/
flutter analyze && flutter test
git add lib/features/alarms/domain/alarm_scheduler.dart test/alarms/alarm_scheduler_error_test.dart
git commit -m "fix: alarm planlama hatasi digerlerini dusurmesin

Kullanici alarm iznini reddettiginde AlarmKit schedule_failed firlatiyor
ve _loadMoreDataInBackground bunu sarmalamadigi icin her veri
yuklemesinde yakalanmamis async hata olusuyordu.

Tek alarmin hatasi artik loglanip geciliyor; digerleri planlanmaya devam
ediyor. Hata yutulmuyor, warning olarak loglaniyor."
```

---

## Task 4: Alarmlar ekranı

`alarms_screen.dart` şu an 944 satır ve iki ekranı barındırıyor. Önce düzenleme ekranı ayrılır, sonra liste ekranı yeniden düzenlenir.

**Files:**
- Create: `lib/presentation/screens/alarm_edit_screen.dart` (mevcut `_AlarmEditScreen` taşınır ve `AlarmEditScreen` olarak public yapılır)
- Modify: `lib/presentation/screens/alarms_screen.dart`
- Test: `test/widgets/screens/alarms_screen_test.dart`

**Interfaces:**
- Consumes: `GroupedList`, `GroupedRow`, `InfoBanner`, `SectionLabel`, `AppSurface`, `EmptyState`, `context.tokens`
- Produces:
  - `class AlarmEditScreen extends StatefulWidget` — `AlarmEditScreen({Alarm? alarm, Key? key})`
  - `alarmTimeLabel(Alarm)`, `alarmSubtitle(Alarm)`, `weekdaysLabel(Set<int>)` — mevcut üst seviye fonksiyonlar `alarms_screen.dart`'ta **kalır** (test ediliyorlar)

- [ ] **Step 1: Düzenleme ekranını ayır**

`alarms_screen.dart` içindeki `_AlarmEditScreen` ve `_AlarmEditScreenState` sınıflarını **olduğu gibi** yeni dosyaya taşı; sınıf adından alt çizgiyi kaldır (`AlarmEditScreen`). Gerekli import'ları taşı. `alarms_screen.dart`'a:

```dart
import 'alarm_edit_screen.dart';
```

ve `_addOrEdit` içindeki `_AlarmEditScreen(alarm: existing)` çağrısını `AlarmEditScreen(alarm: existing)` yap.

Run: `flutter analyze && flutter test`
Expected: temiz ve yeşil — bu adım **davranış değiştirmez**, yalnızca dosya böler.

Commit:
```bash
git add lib/presentation/screens/alarm_edit_screen.dart lib/presentation/screens/alarms_screen.dart
git commit -m "refactor: alarm duzenleme ekranini kendi dosyasina cikar

alarms_screen.dart 944 satirdi ve iki ekrani bariniyordu. Davranis
degismedi, yalnizca dosya bolundu."
```

- [ ] **Step 2: Liste ekranı testini yaz**

Create: `test/widgets/screens/alarms_screen_test.dart`

```dart
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/presentation/screens/alarms_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('alarmTimeLabel', () {
    test('Sabit alarm saati sifir dolgulu yazar', () {
      const alarm = Alarm(id: '1', kind: AlarmKind.fixed, hour: 6, minute: 5);

      expect(alarmTimeLabel(alarm), '06:05');
    });

    test('Cipali alarm vakit adi ve sapmayi yazar', () {
      const alarm = Alarm(
        id: '1',
        kind: AlarmKind.anchored,
        anchor: PrayerType.fajr,
        offsetMinutes: -30,
      );

      expect(alarmTimeLabel(alarm), 'İmsak −30 dk');
    });

    test('Sapma sifirsa yalnizca vakit adi', () {
      const alarm = Alarm(
        id: '1',
        kind: AlarmKind.anchored,
        anchor: PrayerType.isha,
      );

      expect(alarmTimeLabel(alarm), 'Yatsı');
    });
  });

  group('weekdaysLabel', () {
    test('Bos kume ve yedi gun "Her gün"', () {
      expect(weekdaysLabel(const {}), 'Her gün');
      expect(weekdaysLabel(const {1, 2, 3, 4, 5, 6, 7}), 'Her gün');
    });

    test('Hafta ici ve hafta sonu ozel etiketler', () {
      expect(weekdaysLabel(const {1, 2, 3, 4, 5}), 'Hafta içi');
      expect(weekdaysLabel(const {6, 7}), 'Hafta sonu');
    });

    test('Diger kombinasyonlar kisa gun adlariyla siralanir', () {
      expect(weekdaysLabel(const {3, 1}), 'Pzt, Çar');
    });
  });

  group('alarmSubtitle', () {
    test('Etiket varsa tekrar bilgisiyle birlestirilir', () {
      const alarm = Alarm(
        id: '1',
        kind: AlarmKind.fixed,
        label: 'Sahur',
        weekdays: {1, 2, 3, 4, 5},
      );

      expect(alarmSubtitle(alarm), 'Sahur · Hafta içi');
    });

    test('Etiket yoksa yalnizca tekrar bilgisi', () {
      const alarm = Alarm(id: '1', kind: AlarmKind.fixed);

      expect(alarmSubtitle(alarm), 'Her gün');
    });
  });
}
```

- [ ] **Step 3: Testi çalıştır**

Run: `flutter test test/widgets/screens/alarms_screen_test.dart`
Expected: PASS — bu fonksiyonlar zaten var, test onları kilitliyor. Düşen olursa mevcut davranışa göre testi düzelt (bu bir karakterizasyon testi, davranışı değiştirmiyoruz).

- [ ] **Step 4: `SwipeToDelete`'i yaz**

Bu bileşen Step 5'teki liste tarafından kullanılıyor; önce o yazılır.

Create: `lib/presentation/widgets/common/swipe_to_delete.dart`

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Satırı sola kaydırarak silme. Onay diyaloğu ve kaydırma arka planı tek
/// yerde tanımlıdır; alarm ve bildirim listeleri aynı davranışı paylaşır.
class SwipeToDelete extends StatelessWidget {
  final Key itemKey;
  final Widget child;
  final String confirmText;
  final VoidCallback onDelete;

  const SwipeToDelete({
    super.key,
    required this.itemKey,
    required this.child,
    required this.confirmText,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final errorColor = Theme.of(context).colorScheme.error;

    return Dismissible(
      key: itemKey,
      direction: DismissDirection.endToStart,
      background: Container(
        color: errorColor.withValues(alpha: 0.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline_rounded, color: errorColor),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: tokens.backgroundStops[1],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Sil',
              style: AppTypography.rowTitle.copyWith(
                color: tokens.textPrimary,
              ),
            ),
            content: Text(
              confirmText,
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: errorColor),
                child: const Text('Sil'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}
```

- [ ] **Step 5: Liste ekranını yeniden düzenle**

Modify: `lib/presentation/screens/alarms_screen.dart` — `build` ve yardımcılarını değiştir:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const SimpleAppBar(title: 'Alarmlar', showBack: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Alarm ekle'),
      ),
      body: AppSurface(
        child: _loading
            ? const LoadingState()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?_permissionBanner(),
                    Expanded(
                      child: _alarms.isEmpty ? _empty() : _list(),
                    ),
                    _footer(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _list() {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 96),
      children: [
        SectionLabel('${_alarms.length} alarm'),
        const SizedBox(height: 10),
        GroupedList(
          children: [
            for (final alarm in _alarms)
              SwipeToDelete(
                itemKey: ValueKey(alarm.id),
                confirmText:
                    '${alarmTimeLabel(alarm)} alarmını silmek istiyor musunuz?',
                onDelete: () => _delete(alarm),
                child: GroupedRow(
                  icon: Icons.alarm_rounded,
                  title: Text(alarmTimeLabel(alarm)),
                  subtitle: Text(alarmSubtitle(alarm)),
                  onTap: () => _addOrEdit(alarm),
                  dimmed: !alarm.isActive,
                  trailing: Switch(
                    value: alarm.isActive,
                    onChanged: (value) => _toggle(alarm, value),
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
              color: context.tokens.textTertiary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(Icons.bedtime_rounded, size: 16, color: tokens.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              // Siradaki alarm hesabi ayri bir turda baglanacak.
              'Alarmlar vakit verisi güncellendikçe yeniden planlanır.',
              style: AppTypography.hint.copyWith(color: tokens.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _permissionBanner() {
    if (!_supported) {
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
    if (!_granted) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: InfoBanner(
          icon: Icons.notifications_off_rounded,
          text: 'Alarmların çalması için izin gerekiyor.',
          action: TextButton(
            onPressed: _requestPermission,
            child: const Text('İzin ver'),
          ),
        ),
      );
    }
    return null;
  }

  Widget _empty() {
    return const EmptyState(
      icon: Icons.alarm_off_rounded,
      message: 'Henüz alarm yok',
      subtitle: 'Sabit saatli veya vakte göre alarm ekle',
    );
  }
```

`_AlarmCard` sınıfını **sil** — yerini `GroupedRow` aldı. `AppTheme` import'unu kaldır; `AppSurface`, `GroupedList`, `InfoBanner`, `SectionLabel`, `SwipeToDelete`, `AppTypography`, `tokens_context` import'larını ekle.

- [ ] **Step 6: Analiz, testler, commit**

```bash
flutter analyze && flutter test
git add lib/presentation/screens/alarms_screen.dart lib/presentation/widgets/common/swipe_to_delete.dart test/widgets/screens/alarms_screen_test.dart
git commit -m "feat: alarmlar ekranini yeni duzene gecir

Kart listesi yerine ayiracli grup, N alarm bolum etiketi ve sola
kaydirarak silme. Izin uyarilari InfoBanner uzerinden ve notr.
Etiket fonksiyonlari (alarmTimeLabel/weekdaysLabel/alarmSubtitle)
karakterizasyon testleriyle kilitlendi."
```

---

## Task 5: Alarm ekle ekranı

**Files:**
- Modify: `lib/presentation/screens/alarm_edit_screen.dart`
- Test: `test/widgets/screens/alarm_edit_screen_test.dart`

**Interfaces:**
- Consumes: `SlidingSegment`, `SegmentItem`, `SectionLabel`, `AppSurface`, `GroupedList`, `context.tokens`
- Produces: `AlarmEditScreen` — parametre listesi değişmez

- [ ] **Step 1: Testi yaz**

Create: `test/widgets/screens/alarm_edit_screen_test.dart`

```dart
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/presentation/screens/alarm_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  testWidgets('Yeni alarmda baslik "Alarm ekle"', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const AlarmEditScreen()));
    await tester.pump();

    expect(find.text('Alarm ekle'), findsOneWidget);
  });

  testWidgets('Mevcut alarmda baslik "Alarmı düzenle"', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const AlarmEditScreen(
          alarm: Alarm(id: '1', kind: AlarmKind.fixed, hour: 6, minute: 30),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Alarmı düzenle'), findsOneWidget);
  });

  testWidgets('Tur secimi kayan segment ile yapilir', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const AlarmEditScreen()));
    await tester.pump();

    expect(find.text('Sabit saat'), findsOneWidget);
    expect(find.text('Vakte göre'), findsOneWidget);
  });

  testWidgets('Vakte gore secilince vakit ve zamanlama bolumleri gelir', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithTheme(const AlarmEditScreen()));
    await tester.pump();

    await tester.tap(find.text('Vakte göre'));
    await tester.pumpAndSettle();

    expect(find.text('VAKİT'), findsOneWidget);
    expect(find.text('ZAMANLAMA'), findsOneWidget);
    expect(find.text('Önce'), findsOneWidget);
    expect(find.text('Tam vaktinde'), findsOneWidget);
    expect(find.text('Sonra'), findsOneWidget);
  });

  testWidgets('Tekrar bolumunde hafta sonu hizli secimi de var', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithTheme(const AlarmEditScreen()));
    await tester.pump();

    expect(find.text('Her gün'), findsOneWidget);
    expect(find.text('Hafta içi'), findsOneWidget);
    expect(find.text('Hafta sonu'), findsOneWidget);
  });

  testWidgets('En az bir gun secili kalir', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const AlarmEditScreen()));
    await tester.pump();

    // "Her gün" secili basliyor; yedi gunu de kapatmayi dene.
    for (final day in ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa']) {
      await tester.tap(find.text(day));
      await tester.pump();
    }

    // Sonuncusu kapanmamali; etiket "Her gün" olmaktan cikar ama bos kalmaz.
    expect(find.text('Pa'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `flutter test test/widgets/screens/alarm_edit_screen_test.dart`
Expected: FAIL — `VAKİT`/`ZAMANLAMA` etiketleri henüz `SectionLabel` ile büyük harfe çevrilmiyor; "Hafta sonu" yok.

- [ ] **Step 3: Ekranı yeniden düzenle**

Modify: `lib/presentation/screens/alarm_edit_screen.dart`

1. `Scaffold` → `backgroundColor: Colors.transparent`, gövde `AppSurface` ile sarılır.
2. `_kindToggle()` içindeki `SegmentedButton` yerine:

```dart
  Widget _kindToggle() {
    return SlidingSegment<AlarmKind>(
      items: const [
        SegmentItem(value: AlarmKind.fixed, label: 'Sabit saat'),
        SegmentItem(value: AlarmKind.anchored, label: 'Vakte göre'),
      ],
      selected: _kind,
      onChanged: (kind) => setState(() => _kind = kind),
    );
  }
```

3. `_section(String title, Widget child)` içindeki başlığı `SectionLabel` ile değiştir:

```dart
  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
```

Çağrılardaki başlıklar zaten `'Saat'`, `'Tekrar'`, `'Etiket'`, `'Ses'`; `'Vakit'` ve `'Zamanlama'` da öyle — `SectionLabel` büyütmeyi kendisi yapıyor.

4. `_weekdaysSelector()` içindeki hızlı çiplere üçüncüsünü ekle:

```dart
            _quickChip('Hafta sonu', _isWeekendOnly, () {
              setState(() => _weekdays = {6, 7});
            }),
```

ve getter'ı ekle:

```dart
  bool get _isWeekendOnly =>
      _weekdays.length == 2 && _weekdays.containsAll(const {6, 7});
```

Üç çip tek satıra sığması için `Row` yerine `Wrap(spacing: 8, runSpacing: 8, ...)` kullan.

5. Tüm `AppTheme.gold` → `context.tokens.accent`, `Colors.white...` → uygun token. `_fieldDecoration`, `_timeChip`, `_quickChip`, `_dayCell`, `_minutePicker`, `_switchTile`, `_switchRow` bu dönüşümden geçer. `AppTheme` import'u kalkar.

- [ ] **Step 4: Testler, analiz, commit**

```bash
flutter test test/widgets/screens/alarm_edit_screen_test.dart
flutter analyze && flutter test
git add lib/presentation/screens/alarm_edit_screen.dart test/widgets/screens/alarm_edit_screen_test.dart
git commit -m "feat: alarm ekleme ekranini yeni duzene gecir

Tur secimi SegmentedButton yerine SlidingSegment; bolum basliklari
SectionLabel; tasarimda olan 'Hafta sonu' hizli secimi eklendi.
Ekran renk sabiti yazmiyor."
```

---

## Task 6: Bildirimler ekranı

**Files:**
- Modify: `lib/presentation/screens/notification_settings_screen.dart`
- Modify: `lib/presentation/widgets/notifications/notification_tile.dart`
- Modify: `lib/presentation/widgets/notifications/permission_warning_card.dart`
- Test: `test/widgets/screens/notification_screen_test.dart`

**Interfaces:**
- Consumes: `GroupedList`, `GroupedRow`, `InfoBanner`, `SectionLabel`, `AppSurface`, `SwipeToDelete`
- Produces: `NotificationSettingsScreen` — parametre listesi değişmez

- [ ] **Step 1: Testi yaz**

Create: `test/widgets/screens/notification_screen_test.dart`

```dart
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/presentation/widgets/notifications/notification_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  testWidgets('Tam vaktinde bildirim alt metni', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        NotificationTile(
          setting: const NotificationSetting(
            prayerType: PrayerType.dhuhr,
            isActive: true,
          ),
          hasPermission: true,
          onToggle: () {},
          onDelete: () {},
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Öğle'), findsOneWidget);
    expect(find.textContaining('Tam vaktinde'), findsOneWidget);
  });

  testWidgets('X dakika once bildirim alt metni', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        NotificationTile(
          setting: const NotificationSetting(
            prayerType: PrayerType.fajr,
            isActive: true,
            minutesBefore: 30,
          ),
          hasPermission: true,
          onToggle: () {},
          onDelete: () {},
          onTap: () {},
        ),
      ),
    );

    expect(find.textContaining('30 dk önce'), findsOneWidget);
  });

  testWidgets('Kapali bildirim sondurulmus cizilir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        NotificationTile(
          setting: const NotificationSetting(
            prayerType: PrayerType.isha,
            isActive: false,
          ),
          hasPermission: true,
          onToggle: () {},
          onDelete: () {},
          onTap: () {},
        ),
      ),
    );

    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, lessThan(1.0));
  });

  testWidgets('Anahtara dokunmak onToggle tetikler', (tester) async {
    var toggled = false;

    await tester.pumpWidget(
      wrapWithTheme(
        NotificationTile(
          setting: const NotificationSetting(
            prayerType: PrayerType.asr,
            isActive: true,
          ),
          hasPermission: true,
          onToggle: () => toggled = true,
          onDelete: () {},
          onTap: () {},
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    expect(toggled, isTrue);
  });
}
```

- [ ] **Step 2: Testi çalıştır, mevcut davranışı gör**

Run: `flutter test test/widgets/screens/notification_screen_test.dart`
Expected: bir kısmı geçer, `Opacity` testi düşer (tile şu an söndürme kullanmıyor olabilir). Düşenler Step 3'te kapanır.

- [ ] **Step 3: `notification_tile.dart`'ı `GroupedRow`'a devret**

Modify: `lib/presentation/widgets/notifications/notification_tile.dart` — `build`'i şu iskelete indir:

```dart
  @override
  Widget build(BuildContext context) {
    return GroupedRow(
      icon: PrayerUtils.getPrayerIcon(setting.prayerType),
      title: Text(PrayerUtils.getPrayerName(setting.prayerType)),
      subtitle: Text(_subtitle()),
      onTap: onTap,
      dimmed: !setting.isActive || !hasPermission,
      trailing: Switch(
        value: setting.isActive,
        onChanged: hasPermission ? (_) => onToggle() : null,
      ),
    );
  }

  String _subtitle() {
    if (setting.minutesBefore == 0) return 'Tam vaktinde';
    return '${setting.minutesBefore} dk önce';
  }
```

Mevcut dosyada saat de gösteriliyorsa (`· 03:38`) o mantığı `_subtitle()` içinde koru; testler yalnızca `textContaining` ile bakıyor.

- [ ] **Step 4: `permission_warning_card.dart`'ı `InfoBanner`'a devret**

Modify: dosyadaki kartı `InfoBanner` döndürecek şekilde sadeleştir; parametreler aynı kalsın ki çağıran değişmesin.

- [ ] **Step 5: Ekranı yeniden düzenle**

Modify: `lib/presentation/screens/notification_settings_screen.dart`

1. `Scaffold` → `backgroundColor: Colors.transparent`, gövde `AppSurface`.
2. Liste `ListView.builder` yerine `GroupedList` + `SwipeToDelete`:

```dart
  Widget _buildBody() {
    if (_isLoading) return const LoadingState();

    if (_settings.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        message: 'Henüz bildirim yok',
        subtitle: 'Namaz vakitlerinde hatırlatma almak için\nbildirim ekleyin.',
      );
    }

    final sorted = _sortedSettings();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Text(
          'Her vakit için tam vaktinde veya X dakika önce hatırlatma '
          'alabilirsiniz.',
          style: AppTypography.hint.copyWith(
            color: context.tokens.textTertiary,
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
                    '${PrayerUtils.getPrayerName(setting.prayerType)} '
                    'bildirimini silmek istiyor musunuz?',
                onDelete: () => _deleteNotification(
                  setting.prayerType,
                  setting.minutesBefore,
                ),
                child: NotificationTile(
                  setting: setting,
                  hasPermission: _hasPermission,
                  onToggle: () => _toggleNotification(setting),
                  onDelete: () => _confirmDelete(setting),
                  onTap: () => _showEditDialog(setting),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Silmek için satırı sola kaydırın.',
          style: AppTypography.hint.copyWith(
            color: context.tokens.textTertiary,
          ),
        ),
      ],
    );
  }
```

3. `_ExactAlarmWarningCard`'ı sil, yerine `InfoBanner` kullan (turuncu renk kalkar — spec §4.1 uyarıların nötr kalmasını istiyor).
4. `AppTheme` import'unu kaldır.

- [ ] **Step 6: Testler, analiz, commit**

```bash
flutter analyze && flutter test
git add lib/presentation/screens/notification_settings_screen.dart lib/presentation/widgets/notifications/
git add test/widgets/screens/notification_screen_test.dart
git commit -m "feat: bildirimler ekranini yeni duzene gecir

Kart listesi yerine ayiracli grup, N hatirlatma bolum etiketi, sola
kaydirarak silme. Turuncu exact-alarm uyarisi InfoBanner'a tasindi ve
notrlestirildi (spec 4.1: uyarilar vurgu rengi kullanmaz)."
```

---

## Task 7: Görsel doğrulama ve temizlik

- [ ] **Step 1: Kalan renk sabitlerini say**

Run:
```bash
grep -rn "AppTheme\." lib --include='*.dart' | grep -v "AppTheme.build" | wc -l
grep -rn "Colors\.white\|Colors\.orange" lib/presentation/screens/alarms_screen.dart \
  lib/presentation/screens/alarm_edit_screen.dart \
  lib/presentation/screens/notification_settings_screen.dart | wc -l
```
Expected: ikinci komut **0** dönmeli. İlk sayı Plan 1'deki 209'dan belirgin düşmüş olmalı; kalanlar takvim, ayarlar ve konum ekranlarında (Plan 4).

- [ ] **Step 2: Simülatörü sıfırla ve görüntü al**

Yukarıdaki "Ekran görüntüsü alırken" bloğundaki komutları çalıştır.

- [ ] **Step 3: Benzersiz hash sayısını doğrula**

Run: `shasum screenshots/*.png | awk '{print $1}' | sort -u | wc -l`
Expected: **18**. 1 çıkarsa kareler geçersizdir — simülatörü tekrar sıfırla.

- [ ] **Step 4: Üç ekranı tasarımla karşılaştır**

`15-alarmlar-bos.png`, `16-alarm-ekle-sabit-saat.png`, `17-alarm-ekle-vakte-gore.png`,
`08-bildirimler.png`, `18-alarmlar-dolu.png` karelerini tasarım dosyasındaki
karşılıklarıyla karşılaştır. **Kontrol listesi:**
- Gruplar tek yüzey, satırlar ayıraçla bölünmüş, ayıraç ikon hizasından başlıyor
- Bölüm etiketleri büyük harf ve seyrek harf aralıklı
- İzin bandı nötr (vurgu rengi yok)
- Alarm ekle'de segment kayıyor, üç hızlı tekrar çipi var
- Taşma (sarı-siyah şerit) yok

- [ ] **Step 5: Commit**

```bash
git add -A screenshots 2>/dev/null || true
git commit -am "chore: alarm ve bildirim ekranlari icin gorsel dogrulama" || true
```

> `screenshots/` `.gitignore`'da; bu commit yalnızca kod değişikliği kaldıysa
> anlamlı. Değişiklik yoksa atla.

---

## Self-Review

**1. Spec coverage**

| Spec | Karşılığı |
|---|---|
| §4.1 tek yüzey, ayıraç ikon hizasından | Task 1 `GroupedList` |
| §4.1 uyarılar nötr kalır | Task 1 `InfoBanner` + testi |
| §6.2 alarmlar: N ALARM etiketi, swipe-to-delete, izin bandı, boş durum, alt bilgi | Task 4 |
| §6.3 alarm ekle: kayan segment, SAAT/VAKİT/ZAMANLAMA/TEKRAR/DETAY, hafta sonu çipi | Task 5 |
| §6.4 bildirimler: N HATIRLATMA, swipe-to-delete, açıklama satırı, alt bilgi | Task 6 |
| §6.2/§6.4 "Sıradaki alarm/bildirim ...'da" alt bilgisi | **Hariç** — spec §2 veriyi ayrı tura bıraktı; yerleşim statik metinle duruyor |
| §6.5–6.7 takvim, ayarlar, konum | **Plan 4** |
| Sessiz saatler | **Hariç** (spec §2) |

**2. Placeholder scan:** Temiz. Task 5 Step 3'teki "tüm `AppTheme.gold` → `context.tokens.accent`" mekanik bir dönüşüm ve hangi metotların etkilendiği tek tek sayılmış; Task 7 Step 1 bunu sayıyla doğruluyor.

**3. Type consistency**

- `GroupedRow({icon, title, subtitle, trailing, onTap, dimmed})` Task 1'de tanımlandı; Task 4 ve Task 6'da aynı adlarla kullanıldı.
- `SwipeToDelete({itemKey, child, confirmText, onDelete})` Task 4 Step 4'te tanımlanıp Step 5'te kullanılıyor (öz-incelemede sıra ters bulundu, düzeltildi); Task 6 Step 5'te aynı imzayla çağrılıyor.
- `InfoBanner({icon, text, action})` Task 1'de tanımlandı; Task 4 ve Task 6'da kullanıldı.
- `AlarmEditScreen({alarm})` Task 4 Step 1'de public yapıldı; Task 5 ve testleri bu adı kullanıyor.
- `alarmTimeLabel` / `alarmSubtitle` / `weekdaysLabel` `alarms_screen.dart`'ta kalıyor; Task 4 testleri oradan import ediyor.
