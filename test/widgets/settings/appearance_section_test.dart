import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/theme_controller.dart';
import 'package:ezanvakti/presentation/widgets/settings/appearance_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../theme_harness.dart';

class _InMemoryStorage implements LocalStorage {

  List<QuietWindow> _quietWindows = [];

  @override
  Future<List<QuietWindow>> getQuietWindows() async => _quietWindows;

  @override
  Future<void> saveQuietWindows(List<QuietWindow> windows) async =>
      _quietWindows = windows;

  GeneralSettings _generalSettings = const GeneralSettings();

  @override
  Future<GeneralSettings> getGeneralSettings() async => _generalSettings;

  @override
  Future<void> saveGeneralSettings(GeneralSettings settings) async =>
      _generalSettings = settings;
  AppearanceSettings stored = const AppearanceSettings();

  @override
  Future<AppearanceSettings> getAppearanceSettings() async => stored;

  @override
  Future<void> saveAppearanceSettings(AppearanceSettings settings) async {
    stored = settings;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<ThemeController> pumpSection(
    WidgetTester tester, {
    AppearanceSettings? initial,
  }) async {
    final storage = _InMemoryStorage();
    if (initial != null) storage.stored = initial;
    final controller = ThemeController(
      storage: storage,
      clock: () => DateTime(2026, 8, 3, 12),
    );
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeController>.value(
        value: controller,
        child: wrapWithTheme(const AppearanceSection()),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('Tema secici uc secenek gosterir', (tester) async {
    await pumpSection(tester);

    expect(find.text('Koyu'), findsOneWidget);
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Sistem'), findsOneWidget);
  });

  testWidgets('Tema secimi controller a yazilir', (tester) async {
    final controller = await pumpSection(tester);

    await tester.tap(find.text('Açık'));
    await tester.pumpAndSettle();

    expect(controller.settings.themeMode, AppThemeMode.light);
  });

  testWidgets('Vakte gore renk anahtari acik baslar ve kapatilabilir', (
    tester,
  ) async {
    final controller = await pumpSection(tester);

    expect(controller.settings.timeBasedColor, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(controller.settings.timeBasedColor, isFalse);
  });

  testWidgets('Anahtar kapaliyken alt metin degisir', (tester) async {
    await pumpSection(
      tester,
      initial: const AppearanceSettings(timeBasedColor: false),
    );

    expect(find.text('Sabit bir palet seçin'), findsOneWidget);
    expect(find.text('Zemin gün içinde ilerler'), findsNothing);
  });

  testWidgets('Anahtar acikken palet seridi secilemez', (tester) async {
    final controller = await pumpSection(tester);

    await tester.tap(find.byKey(const Key('palette_swatch_morning')));
    await tester.pumpAndSettle();

    // Acikken serit salt gosterim; secim degismemeli.
    expect(controller.settings.fixedPalette, DayPhase.evening);
  });

  testWidgets('Anahtar kapaliyken palet secilebilir', (tester) async {
    final controller = await pumpSection(
      tester,
      initial: const AppearanceSettings(timeBasedColor: false),
    );

    await tester.tap(find.byKey(const Key('palette_swatch_morning')));
    await tester.pumpAndSettle();

    expect(controller.settings.fixedPalette, DayPhase.morning);
  });

  testWidgets('Dort palet ornegi cizilir', (tester) async {
    await pumpSection(tester);

    for (final phase in DayPhase.values) {
      expect(
        find.byKey(Key('palette_swatch_${phase.name}')),
        findsOneWidget,
        reason: phase.name,
      );
    }
  });
}
