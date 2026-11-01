import 'dart:async';

import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/models/notification_setting.dart'
    show PrayerType;
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/core/services/device_settings_service.dart';
import 'package:ezanvakti/core/utils/time_formatter.dart';
import 'package:ezanvakti/presentation/screens/quiet_windows_screen.dart';
import 'package:ezanvakti/presentation/widgets/common/delete_action_button.dart';
import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

/// Verilen günün vakitleri; yalnız öğle ve ikindi testte okunuyor.
PrayerTime _day(DateTime date, {int dhuhrMinute = 37}) => PrayerTime(
  date: date,
  fajr: DateTime(date.year, date.month, date.day, 6, 10),
  sunrise: DateTime(date.year, date.month, date.day, 7, 35),
  dhuhr: DateTime(date.year, date.month, date.day, 12, dhuhrMinute),
  asr: DateTime(date.year, date.month, date.day, 15, 30),
  maghrib: DateTime(date.year, date.month, date.day, 17, 54),
  isha: DateTime(date.year, date.month, date.day, 19, 15),
);

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

  /// Çarşamba 4 Kasım 2026; bu haftanın Cuması 6 Kasım.
  final wednesday = DateTime(2026, 11, 4, 9);

  late FakeStorage storage;
  late int changes;

  setUp(() async {
    storage = FakeStorage();
    await storage.init();
    changes = 0;
    ServiceLocator().register<LocalStorage>(storage);
    // Telefonu susturma satırı Android dışında yok; ekran servisi yine sorar.
    ServiceLocator().register<DeviceSettingsService>(
      DeviceSettingsService(isAndroid: false),
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    List<QuietWindow> windows, {
    List<PrayerTime> prayerTimes = const [],
    DateTime? now,
  }) async {
    await storage.saveQuietWindows(windows);
    await tester.pumpWidget(
      wrapWithTheme(
        QuietWindowsScreen(
          onChanged: () async => changes++,
          clock: now == null ? null : () => now,
        ),
        // Harness'ın 24 saat ayarı yalnız ekranın altında; panel ayrı bir
        // rotada açıldığı için biçimi uygulama tercihiyle sabitle.
        appState: AppState()
          ..setGeneralSettings(
            const GeneralSettings(timeFormat: TimeFormatPreference.h24),
          )
          ..setPrayerTimes(prayerTimes),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<List<String>> savedIds() async => [
    for (final window in await storage.getQuietWindows()) window.id,
  ];

  /// Paneldeki artı düğmeleri: ilki "Vakitten önce", sonuncusu "Vakitten
  /// sonra". Ekrandaki ekleme düğmesinin ikonu da aynı olduğu için panelle
  /// sınırlanır.
  Finder sheetPlus() => find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byIcon(Icons.add_rounded),
  );

  Future<QuietWindow> saved(String id) async =>
      (await storage.getQuietWindows()).firstWhere((w) => w.id == id);

  testWidgets(
    'Kaydırma yok; menü vakit ve süreyi yazar, Sil siler, Geri al eski sırasına koyar',
    (tester) async {
      await pumpScreen(tester, [QuietWindow.fridayDefault(), dhuhr, asr]);
      expect(find.byType(Dismissible), findsNothing);

      await tester.longPress(find.widgetWithText(GroupedRow, 'Öğle · her gün'));
      await tester.pumpAndSettle();
      expect(find.text('ÖĞLE · 10 DK ÖNCE – 30 DK SONRA'), findsOneWidget);
      expect(find.text('Kopyala'), findsNothing);
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(await savedIds(), ['friday', 'q2']);
      expect(find.widgetWithText(GroupedRow, 'Öğle · her gün'), findsNothing);
      expect(find.text('Sessiz vakit silindi'), findsOneWidget);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(await savedIds(), ['friday', 'q1', 'q2']);
      expect(find.widgetWithText(GroupedRow, 'Öğle · her gün'), findsOneWidget);
      expect(changes, 2, reason: 'silme ve geri alma ikisi de yeniden planlar');
    },
  );

  testWidgets('Cuma satırında basılı tutma menü açmaz', (tester) async {
    await pumpScreen(tester, [QuietWindow.fridayDefault(), dhuhr]);

    await tester.longPress(find.text('Cuma namazında sessiz'));
    await tester.pumpAndSettle();

    expect(find.text('Sil'), findsNothing);
  });

  testWidgets(
    'Satırlar bugünün saat aralığını ve mod özetini yazar; Cuma bu haftanın Cumasını gösterir',
    (tester) async {
      await pumpScreen(
        tester,
        [
          QuietWindow.fridayDefault(),
          dhuhr,
          asr.copyWith(mode: QuietMode.skip, isActive: false),
        ],
        prayerTimes: [
          _day(DateTime(2026, 11, 4), dhuhrMinute: 30),
          _day(DateTime(2026, 11, 5)),
          _day(DateTime(2026, 11, 6)),
        ],
        now: wednesday,
      );

      expect(find.text('Sessiz vakitler'), findsOneWidget);
      expect(
        find.text('Cuma 12:22 – 13:37 · Bildirimler sessiz gelir'),
        findsOneWidget,
      );
      // Öğle bugünün (Çarşamba) vaktinden: 12:30 − 10 dk, 12:30 + 30 dk.
      expect(find.text('12:20 – 13:00'), findsOneWidget);
      expect(find.text('Bildirim sessiz gelir'), findsOneWidget);
      expect(find.text('15:25 – 15:50'), findsOneWidget);
      expect(find.text('Bildirim gelmez'), findsOneWidget);
      expect(
        tester
            .widget<GroupedRow>(
              find.widgetWithText(GroupedRow, 'İkindi · her gün'),
            )
            .dimmed,
        isTrue,
      );
    },
  );

  testWidgets('Vakit verisi yoksa göreli özet; kapalı Cuma "Kapalı" yazar', (
    tester,
  ) async {
    await pumpScreen(tester, [
      QuietWindow.fridayDefault().copyWith(isActive: false),
      dhuhr,
    ]);

    expect(find.text('Kapalı'), findsOneWidget);
    expect(find.text('10 dk önce – 30 dk sonra'), findsOneWidget);
  });

  testWidgets('Boş listede kısa metin görünür', (tester) async {
    await pumpScreen(tester, [QuietWindow.fridayDefault()]);

    expect(find.text('DİĞER VAKİTLER'), findsOneWidget);
    expect(find.text('Henüz başka sessiz vakit yok.'), findsOneWidget);
  });

  testWidgets('Cuma anahtarı paneli açmadan kaydı açıp kapatır', (
    tester,
  ) async {
    await pumpScreen(tester, [QuietWindow.fridayDefault()]);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(GroupedRow, 'Cuma namazında sessiz'),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect((await saved('friday')).isActive, isFalse);
    expect(changes, 1);
  });

  testWidgets(
    'Cuma satırına dokununca vakit seçimi ve silme olmadan panel açılır',
    (tester) async {
      await pumpScreen(
        tester,
        [QuietWindow.fridayDefault()],
        prayerTimes: [_day(DateTime(2026, 11, 6))],
        now: wednesday,
      );

      await tester.tap(find.text('Cuma namazında sessiz'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Cuma öğle vakti çevresinde'), findsOneWidget);
      expect(find.text('Öğle 12:37'), findsOneWidget);
      expect(find.text('Vakit'), findsNothing);
      expect(find.byType(DeleteActionButton), findsNothing);
      expect(find.text('Ekle'), findsNothing);

      // Değişiklik anında kaydedilir.
      await tester.tap(sheetPlus().last);
      await tester.pumpAndSettle();
      expect((await saved('friday')).minutesAfter, 65);
      expect(changes, 1);
    },
  );

  testWidgets('Var olan kayıtta paneldeki değişiklik anında kaydedilir', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      [dhuhr],
      prayerTimes: [_day(DateTime(2026, 11, 4), dhuhrMinute: 30)],
      now: wednesday,
    );

    await tester.tap(find.text('Öğle · her gün'));
    await tester.pumpAndSettle();
    expect(find.text('Öğle vakti çevresinde'), findsOneWidget);
    expect(find.text('Vakitten önce'), findsOneWidget);
    expect(find.text('Vakitten sonra'), findsOneWidget);
    expect(find.text('BİLDİRİMLER'), findsOneWidget);
    expect(find.text('Bildirim görünür, ses çalmaz'), findsOneWidget);

    await tester.tap(sheetPlus().first);
    await tester.pumpAndSettle();
    expect((await saved('q1')).minutesBefore, 15);
    expect(
      find.text('12:15'),
      findsOneWidget,
      reason: 'zaman çizgisi güncellenir',
    );

    await tester.tap(find.text('Hiç gelmesin'));
    await tester.pumpAndSettle();
    expect((await saved('q1')).mode, QuietMode.skip);
    expect(find.text('Bildirim hiç planlanmaz'), findsOneWidget);
    expect(changes, 2);
  });

  testWidgets(
    '"Sessiz vakit ekle" taslak açar; Ekle\'siz kapanırsa kaydetmez',
    (tester) async {
      await pumpScreen(tester, [QuietWindow.fridayDefault()]);

      await tester.tap(find.text('Sessiz vakit ekle'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(await savedIds(), ['friday'], reason: 'açmak kayıt eklemez');

      await tester.tap(sheetPlus().last);
      await tester.pumpAndSettle();
      expect(await savedIds(), [
        'friday',
      ], reason: 'taslak değişikliği kaydedilmez');

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(await savedIds(), ['friday']);
      expect(changes, 0);
    },
  );

  testWidgets('Taslak "Ekle" ile kaydedilir ve yeniden planlanır', (
    tester,
  ) async {
    await pumpScreen(tester, [QuietWindow.fridayDefault()]);

    await tester.tap(find.text('Sessiz vakit ekle'));
    await tester.pumpAndSettle();
    await tester.tap(sheetPlus().last);
    await tester.pumpAndSettle();
    final add = find.text('Ekle');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    final windows = await storage.getQuietWindows();
    expect(windows, hasLength(2));
    expect(windows.last.prayerType, PrayerType.dhuhr);
    expect(windows.last.minutesBefore, 10);
    expect(windows.last.minutesAfter, 35);
    expect(changes, 1);
    expect(find.widgetWithText(GroupedRow, 'Öğle · her gün'), findsOneWidget);
  });

  testWidgets(
    'Paneldeki "Sessiz vakti sil" paneli kapatır ve siler; Geri al geri getirir',
    (tester) async {
      await pumpScreen(tester, [dhuhr, asr]);

      await tester.tap(find.text('İkindi · her gün'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DeleteActionButton>(find.byType(DeleteActionButton))
            .framed,
        isTrue,
      );
      final delete = find.text('Sessiz vakti sil');
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      // İkinci dokunuş aynı karede gelir; ekran kapanmamalı.
      await tester.tap(delete, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(QuietWindowsScreen), findsOneWidget);
      expect(await savedIds(), ['q1']);
      expect(find.text('Sessiz vakit silindi'), findsOneWidget);

      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      expect(await savedIds(), ['q1', 'q2']);
    },
  );

  testWidgets('"Geri al" çubuğu yeniden planlamayı beklemeden çıkar', (
    tester,
  ) async {
    final reschedule = Completer<void>();
    await storage.saveQuietWindows([dhuhr, asr]);
    await tester.pumpWidget(
      wrapWithTheme(QuietWindowsScreen(onChanged: () => reschedule.future)),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.widgetWithText(GroupedRow, 'Öğle · her gün'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(await savedIds(), ['q2']);
    expect(
      find.text('Sessiz vakit silindi'),
      findsOneWidget,
      reason: 'planlama sürerken de geri alma sunulur',
    );
    reschedule.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Yeniden planlama hata verse de silme kalır ve "Geri al" çıkar', (
    tester,
  ) async {
    await storage.saveQuietWindows([dhuhr, asr]);
    await tester.pumpWidget(
      wrapWithTheme(
        QuietWindowsScreen(onChanged: () async => throw Exception('plan')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.widgetWithText(GroupedRow, 'Öğle · her gün'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();

    expect(await savedIds(), ['q2']);
    expect(find.text('Sessiz vakit silindi'), findsOneWidget);

    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(await savedIds(), ['q1', 'q2']);
    expect(tester.takeException(), isNull);
  });
}
