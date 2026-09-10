import 'package:ezanvakti/core/models/derived_time.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/models/notification_draft.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/core/utils/time_formatter.dart';
import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:ezanvakti/l10n/l10n_extensions.dart';
import 'package:ezanvakti/presentation/screens/notification_edit_screen.dart';
import 'package:ezanvakti/presentation/widgets/common/section_label.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/l10n_helper.dart';
import '../theme_harness.dart';

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
  late AppLocalizations l10n;
  final now = DateTime(2026, 9, 10, 10, 0);
  final prayerTimes = [
    _day(DateTime(2026, 9, 10)),
    _day(DateTime(2026, 9, 11)),
    _day(DateTime(2026, 9, 12)),
  ];

  setUpAll(() async => l10n = await loadTestL10n());

  /// Sayfayi bir rota olarak acar; "Kaydet" ile donen taslak okunabilir.
  /// Donus: taslagi (ya da vazgecildiyse null) veren okuyucu.
  Future<NotificationDraft? Function()> open(
    WidgetTester tester, {
    NotificationSetting? initial,
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    NotificationDraft? result;
    // Harness'in 24 saat MediaQuery'si yalnizca home'u sariyor; ustune
    // acilan rota ve alt sayfa onu gormez, saatler "4:12 AM" olurdu. Tercih
    // AppState'ten 24 saat olarak verilince MediaQuery'ye bakilmiyor.
    final appState = AppState()
      ..setGeneralSettings(
        const GeneralSettings(timeFormat: TimeFormatPreference.h24),
      );
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<NotificationDraft>(
                MaterialPageRoute(
                  builder: (_) => NotificationEditScreen(
                    initial: initial,
                    prayerTimes: prayerTimes,
                    clock: () => now,
                  ),
                ),
              );
            },
            child: const Text('aç'),
          ),
        ),
        brightness: brightness,
        appState: appState,
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    return () => result;
  }

  /// Alt sayfadaki liste tembel kuruluyor; alttaki secenekler ancak
  /// kaydirilinca insa ediliyor.
  Future<void> revealInSheet(WidgetTester tester, String name) async {
    final list = find.byType(ListView).last;
    for (var i = 0; i < 10 && find.text(name).evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -200));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> pickPoint(WidgetTester tester, String name) async {
    await tester.tap(find.text('Ne zaman?'));
    await tester.pumpAndSettle();
    await revealInSheet(tester, name);
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
  }

  testWidgets('Yeni bildirimde baslik "Yeni bildirim"', (tester) async {
    await open(tester);
    expect(find.text('Yeni bildirim'), findsOneWidget);
  });

  testWidgets('Mevcut bildirimde baslik "Bildirimi düzenle"', (tester) async {
    await open(
      tester,
      initial: const NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
      ),
    );
    expect(find.text('Bildirimi düzenle'), findsOneWidget);
  });

  testWidgets('Ne zaman secicisi iki grupta on bir secenek sunar', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Ne zaman?'));
    await tester.pumpAndSettle();

    expect(find.text('NAMAZ VAKİTLERİ'), findsOneWidget);
    // Her secenegin yaninda bugunku saat. Liste tembel: kaydirilinca ust
    // satirlar sokuluyor, bu yuzden kontrol satir gorunurken yapiliyor.
    expect(find.textContaining('Bugün 05:52'), findsOneWidget);
    for (final type in PrayerType.values) {
      await revealInSheet(tester, l10n.prayerName(type));
      expect(find.text(l10n.prayerName(type)), findsWidgets, reason: '$type');
    }
    for (final kind in DerivedTimeKind.values) {
      await revealInSheet(tester, l10n.derivedName(kind));
      expect(
        find.text(l10n.derivedName(kind)),
        findsOneWidget,
        reason: '$kind',
      );
      if (kind == DerivedTimeKind.istiwa) {
        expect(find.textContaining('Bugün 13:05'), findsOneWidget);
      }
    }
    expect(find.text('HESAPLANAN VAKİTLER'), findsOneWidget);
  });

  testWidgets('Hesaplanan nokta secilince formul, aciklama ve bugunku saat', (
    tester,
  ) async {
    await open(tester);
    await pickPoint(tester, l10n.derivedName(DerivedTimeKind.istiwa));

    expect(find.text('Öğle vaktinden 10 dk önce'), findsOneWidget);
    expect(find.text('Öğleden önceki kerahat başlar'), findsOneWidget);
    expect(find.textContaining('Bugün 13:05'), findsOneWidget);
    expect(find.byType(SectionLabel), findsWidgets);
  });

  testWidgets('Onizleme siradaki bildirimi soyler', (tester) async {
    await open(tester);
    expect(find.textContaining('Sıradaki:'), findsOneWidget);
    expect(find.textContaining('yarın 04:12'), findsOneWidget);

    await pickPoint(tester, l10n.derivedName(DerivedTimeKind.istiwa));
    expect(find.textContaining('bugün 13:05'), findsOneWidget);

    await tester.tap(find.text('Öncesinde'));
    await tester.pumpAndSettle();
    expect(find.textContaining('bugün 12:50'), findsOneWidget);
  });

  testWidgets('Varsayilan kayit: imsak, tam vaktinde, her gun, etiketsiz', (
    tester,
  ) async {
    final result = await open(tester);
    await save(tester);

    final draft = result();
    expect(draft, isNotNull);
    expect(draft!.prayerType, PrayerType.fajr);
    expect(draft.derivedKind, isNull);
    expect(draft.minutesBefore, 0);
    expect(draft.weekdays, isEmpty);
    expect(draft.label, isNull);
  });

  testWidgets('Hesaplanan nokta kaydinda cipa vakti yazilir', (tester) async {
    final result = await open(tester);
    await pickPoint(tester, l10n.derivedName(DerivedTimeKind.istiwa));
    await save(tester);

    expect(result()?.derivedKind, DerivedTimeKind.istiwa);
    expect(result()?.prayerType, PrayerType.dhuhr);
  });

  testWidgets('Oncesinde secilince dakika tekerlegi gelir ve kaydedilir', (
    tester,
  ) async {
    final result = await open(tester);
    expect(find.text('Dakika seçin'), findsNothing);

    await tester.tap(find.text('Öncesinde'));
    await tester.pumpAndSettle();
    expect(find.text('Dakika seçin'), findsOneWidget);

    await save(tester);
    expect(result()?.minutesBefore, 15, reason: 'varsayilan sapma');
  });

  testWidgets('Vakit degisince asan sapma hatasi saat olarak gosterilir', (
    tester,
  ) async {
    final result = await open(
      tester,
      initial: const NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        minutesBefore: 240,
      ),
    );
    await pickPoint(tester, l10n.prayerName(PrayerType.isha));
    await save(tester);

    expect(
      find.text('Bu vakitten en fazla 1 sa önce bildirim ekleyebilirsin.'),
      findsOneWidget,
    );
    expect(result(), isNull, reason: 'sayfa kapanmadi');
  });

  testWidgets('Gunler ve etiket kaydedilir', (tester) async {
    final result = await open(tester);
    // Varsayilan 7 gun secili; Pazartesi disindaki 6 gunu kapatinca yalnizca
    // Pazartesi kalir ve model bunu kume olarak alir.
    for (final day in ['Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa']) {
      await tester.tap(find.text(day));
      await tester.pump();
    }
    await tester.enterText(find.byType(TextField), 'Sahur');
    await save(tester);

    expect(result()?.weekdays, {1});
    expect(result()?.label, 'Sahur');
  });

  testWidgets('Mevcut ayar sayfaya yuklenir', (tester) async {
    final result = await open(
      tester,
      initial: const NotificationSetting(
        prayerType: PrayerType.maghrib,
        derivedKind: DerivedTimeKind.preMaghrib,
        isActive: true,
        minutesBefore: 10,
        weekdays: {5},
        label: 'İkindi için son çağrı',
      ),
    );
    expect(find.text('Dakika seçin'), findsOneWidget);
    expect(find.text('İkindi için son çağrı'), findsOneWidget);
    await save(tester);

    expect(result()?.derivedKind, DerivedTimeKind.preMaghrib);
    expect(result()?.minutesBefore, 10);
    expect(result()?.weekdays, {5});
  });

  testWidgets('Geri tusu taslak dondurmez', (tester) async {
    final result = await open(tester);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    expect(result(), isNull);
    expect(find.text('aç'), findsOneWidget);
  });

  // Secim bandi tekerlegin ustune cizilir; opak bir renk secili satiri
  // tamamen orter. Acik temada `surface` opak beyaz oldugu icin dakika
  // gorunmez oluyordu.
  for (final brightness in Brightness.values) {
    testWidgets('Dakika tekerleginin secim bandi saydam (${brightness.name})', (
      tester,
    ) async {
      await open(tester, brightness: brightness);
      await tester.tap(find.text('Öncesinde'));
      await tester.pumpAndSettle();

      final picker = tester.widget<CupertinoPicker>(
        find.byType(CupertinoPicker),
      );
      final overlay =
          picker.selectionOverlay as CupertinoPickerDefaultSelectionOverlay;

      expect(overlay.background.a, lessThan(1.0));
    });
  }
}
