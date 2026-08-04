import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Varsayilanlar: koyu tema, vakte gore renk acik, sabit palet evening',
    () {
      const settings = AppearanceSettings();

      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.timeBasedColor, isTrue);
      expect(settings.fixedPalette, DayPhase.evening);
    },
  );

  test('toMap/fromMap gidis donusu degeri korur', () {
    const original = AppearanceSettings(
      themeMode: AppThemeMode.system,
      timeBasedColor: false,
      fixedPalette: DayPhase.night,
    );

    expect(AppearanceSettings.fromMap(original.toMap()), original);
  });

  test('Bos map varsayilanlari verir', () {
    expect(AppearanceSettings.fromMap(const {}), const AppearanceSettings());
  });

  test('Bilinmeyen ya da bos degerler varsayilana duser', () {
    final restored = AppearanceSettings.fromMap({
      AppearanceSettings.themeModeKey: 'bilinmeyen',
      AppearanceSettings.timeBasedColorKey: 'belki',
      AppearanceSettings.fixedPaletteKey: '',
    });

    expect(restored, const AppearanceSettings());
  });

  test('copyWith yalnizca verilen alani degistirir', () {
    const original = AppearanceSettings();
    final changed = original.copyWith(timeBasedColor: false);

    expect(changed.timeBasedColor, isFalse);
    expect(changed.themeMode, original.themeMode);
    expect(changed.fixedPalette, original.fixedPalette);
  });

  test('Esitlik ve hashCode alan degerlerine dayanir', () {
    const a = AppearanceSettings(themeMode: AppThemeMode.light);
    const b = AppearanceSettings(themeMode: AppThemeMode.light);
    const c = AppearanceSettings(themeMode: AppThemeMode.dark);

    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
  });
}
