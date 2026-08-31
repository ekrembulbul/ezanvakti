import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/theme/theme_controller.dart';
import 'package:ezanvakti/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../theme_harness.dart';

class _InMemoryStorage implements LocalStorage {

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

const _location = Location(id: '1', province: 'İstanbul', district: 'Kadıköy');

void main() {
  Future<void> pumpSettings(WidgetTester tester, {VoidCallback? onCalc}) async {
    // Ekran Genel kartiyla uzadi; alt bolumler (Gorunum/Bilgi) icin uzun bir
    // yuzey veriliyor ki testler kaydirmadan da hepsini gorebilsin.
    tester.view.physicalSize = const Size(1206, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final controller = ThemeController(
      storage: _InMemoryStorage(),
      clock: () => DateTime(2026, 8, 3, 12),
    );
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeController>.value(
        value: controller,
        child: wrapWithTheme(
          SettingsScreen(
            currentLocation: _location,
            onCalculationSettings: onCalc,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Uc bolum basligi buyuk harfle cizilir', (tester) async {
    await pumpSettings(tester);

    expect(find.text('GENEL'), findsOneWidget);
    expect(find.text('GÖRÜNÜM'), findsOneWidget);
    expect(find.text('BİLGİ'), findsOneWidget);
  });

  testWidgets('Konum ve hesaplama satirlari gorunur', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Konum'), findsOneWidget);
    expect(find.text('Hesaplama'), findsOneWidget);
    expect(find.text('Kadıköy, İstanbul'), findsOneWidget);
  });

  testWidgets('Hesaplama satirina dokunmak callback tetikler', (tester) async {
    var tapped = false;
    await pumpSettings(tester, onCalc: () => tapped = true);

    await tester.tap(find.text('Hesaplama'));
    expect(tapped, isTrue);
  });

  testWidgets('Veri kaynagi ve gizlilik satirlari BILGI altinda', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text('Veri kaynağı'), findsOneWidget);
    expect(find.text('Aladhan API'), findsOneWidget);
    expect(find.text('Gizlilik'), findsOneWidget);
  });

  testWidgets('Gorunum bolumu tema secicisini icerir', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Vakte göre renk'), findsOneWidget);
  });

  testWidgets('Gizlilik satiri ozet diyalogu acar', (tester) async {
    await pumpSettings(tester);

    await tester.ensureVisible(find.text('Gizlilik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gizlilik'));
    await tester.pumpAndSettle();

    expect(find.textContaining('cihazınızda saklanır'), findsWidgets);
    expect(find.text('Tamam'), findsOneWidget);
  });
}
