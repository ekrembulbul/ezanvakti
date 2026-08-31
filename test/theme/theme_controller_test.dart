import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/fasting_log.dart';
import 'package:ezanvakti/core/models/notification_setting.dart' show PrayerType;
import 'package:ezanvakti/core/models/prayer_log.dart';
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:ezanvakti/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryStorage implements LocalStorage {

  final Map<String, String> _rawSettings = {};

  @override
  Future<String?> getSetting(String key) async => _rawSettings[key];

  @override
  Future<void> setSetting(String key, String value) async =>
      _rawSettings[key] = value;

  final Map<String, FastingStatus> _fastingLog = {};
  int _fastingQada = 0;

  @override
  Future<Map<String, FastingStatus>> getFastingLog(
    DateTime from,
    DateTime to,
  ) async => Map.of(_fastingLog);

  @override
  Future<void> setFastingLog(DateTime date, FastingStatus? status) async {
    final key = fastingLogKey(date);
    if (status == null) {
      _fastingLog.remove(key);
    } else {
      _fastingLog[key] = status;
    }
  }

  @override
  Future<int> getFastingQadaCount() async => _fastingQada;

  @override
  Future<void> setFastingQadaCount(int count) async => _fastingQada = count;

  final Map<String, PrayerStatus> _prayerLog = {};
  final Map<PrayerType, int> _qadaCounts = {};
  final Map<String, int> _dhikrLog = {};

  @override
  Future<Map<String, PrayerStatus>> getPrayerLog(
    DateTime from,
    DateTime to,
  ) async => Map.of(_prayerLog);

  @override
  Future<void> setPrayerLog(
    DateTime date,
    PrayerType prayerType,
    PrayerStatus? status,
  ) async {
    final key = prayerLogKey(date, prayerType);
    if (status == null) {
      _prayerLog.remove(key);
    } else {
      _prayerLog[key] = status;
    }
  }

  @override
  Future<Map<PrayerType, int>> getQadaCounts() async => Map.of(_qadaCounts);

  @override
  Future<void> setQadaCount(PrayerType prayerType, int count) async =>
      _qadaCounts[prayerType] = clampQadaCount(count);

  @override
  Future<int> getDhikrCount(DateTime date) async =>
      _dhikrLog['${date.year}-${date.month}-${date.day}'] ?? 0;

  @override
  Future<void> setDhikrCount(DateTime date, int count) async =>
      _dhikrLog['${date.year}-${date.month}-${date.day}'] = count;

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
