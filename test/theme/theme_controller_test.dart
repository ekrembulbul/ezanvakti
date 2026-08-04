import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:ezanvakti/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryStorage implements LocalStorage {
  AppearanceSettings stored = const AppearanceSettings();
  int saveCount = 0;

  @override
  Future<AppearanceSettings> getAppearanceSettings() async => stored;

  @override
  Future<void> saveAppearanceSettings(AppearanceSettings settings) async {
    stored = settings;
    saveCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Imsak 04:00, Ogle 13:00, Ikindi 17:00, Aksam 20:00, Yatsi 22:00.
PrayerTime _day(int day) {
  DateTime at(int hour) => DateTime(2026, 8, day, hour, 0);
  return PrayerTime(
    fajr: at(4),
    sunrise: at(6),
    dhuhr: at(13),
    asr: at(17),
    maghrib: at(20),
    isha: at(22),
    date: DateTime(2026, 8, day),
  );
}

ThemeController _controller(_InMemoryStorage storage, {DateTime? now}) {
  return ThemeController(
    storage: storage,
    clock: () => now ?? DateTime(2026, 8, 1, 9, 0),
  );
}

void main() {
  test('Vakit verisi yokken evening paleti kullanilir', () async {
    final controller = _controller(_InMemoryStorage());
    await controller.load();

    expect(controller.phase, DayPhase.evening);
    expect(
      controller.tokens.accent,
      paletteFor(DayPhase.evening, Brightness.dark).accent,
    );

    controller.dispose();
  });

  test('Vakit verisi gelince dilim hesaplanir', () async {
    final controller = _controller(_InMemoryStorage());
    await controller.load();

    controller.updatePrayerTimes(today: _day(1), tomorrow: _day(2));

    expect(controller.phase, DayPhase.morning);

    controller.dispose();
  });

  test('Vakte gore renk kapaliyken sabit palet kullanilir', () async {
    final storage = _InMemoryStorage()
      ..stored = const AppearanceSettings(
        timeBasedColor: false,
        fixedPalette: DayPhase.night,
      );
    final controller = _controller(storage);
    await controller.load();
    controller.updatePrayerTimes(today: _day(1), tomorrow: _day(2));

    expect(controller.phase, DayPhase.night);

    controller.dispose();
  });

  test('Tema modu dark iken platform parlakligi yok sayilir', () async {
    final storage = _InMemoryStorage()
      ..stored = const AppearanceSettings(themeMode: AppThemeMode.dark);
    final controller = _controller(storage);
    await controller.load();

    controller.setPlatformBrightness(Brightness.light);

    expect(controller.brightness, Brightness.dark);

    controller.dispose();
  });

  test('Tema modu system iken platform parlakligi izlenir', () async {
    final storage = _InMemoryStorage()
      ..stored = const AppearanceSettings(themeMode: AppThemeMode.system);
    final controller = _controller(storage);
    await controller.load();

    controller.setPlatformBrightness(Brightness.light);

    expect(controller.brightness, Brightness.light);
    expect(
      controller.tokens.accent,
      paletteFor(DayPhase.evening, Brightness.light).accent,
    );

    controller.dispose();
  });

  test('Ayar degisimi kalici olur ve dinleyicileri uyarir', () async {
    final storage = _InMemoryStorage();
    final controller = _controller(storage);
    await controller.load();

    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setTimeBasedColor(false);

    expect(storage.stored.timeBasedColor, isFalse);
    expect(notified, greaterThan(0));

    controller.dispose();
  });

  test('Ayni degeri yazmak depoya gitmez', () async {
    final storage = _InMemoryStorage()
      ..stored = const AppearanceSettings(themeMode: AppThemeMode.dark);
    final controller = _controller(storage);
    await controller.load();

    await controller.setThemeMode(AppThemeMode.dark);

    expect(storage.saveCount, 0);

    controller.dispose();
  });

  test('Sabit palet secimi kalici olur', () async {
    final storage = _InMemoryStorage();
    final controller = _controller(storage);
    await controller.load();

    await controller.setFixedPalette(DayPhase.morning);

    expect(storage.stored.fixedPalette, DayPhase.morning);

    controller.dispose();
  });

  test('Kayitli ayarlar acilista okunur', () async {
    final storage = _InMemoryStorage()
      ..stored = const AppearanceSettings(
        themeMode: AppThemeMode.light,
        timeBasedColor: false,
        fixedPalette: DayPhase.afternoon,
      );
    final controller = _controller(storage);

    await controller.load();

    expect(controller.settings.themeMode, AppThemeMode.light);
    expect(controller.brightness, Brightness.light);
    expect(controller.phase, DayPhase.afternoon);

    controller.dispose();
  });
}
