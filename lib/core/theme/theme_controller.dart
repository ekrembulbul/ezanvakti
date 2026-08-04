import 'dart:async';

import 'package:flutter/material.dart';

import '../interfaces/local_storage.dart';
import '../models/alarm_theme.dart';
import '../models/appearance_settings.dart';
import '../models/prayer_time.dart';
import 'app_tokens.dart';
import 'day_phase.dart';
import 'palettes.dart';

/// Palet geçişlerinin süresi.
///
/// Vakit sınırı geçişi, tema değişimi ve sabit palet seçimi — hepsi aynı
/// süreyi kullanır. Kontrol animasyonları (kayan segment) ayrı ve daha
/// kısadır (220 ms).
const Duration kPaletteTransition = Duration(milliseconds: 400);

/// Görünüm ayarlarını, gün dilimini ve aktif paleti yöneten tek merkez.
///
/// Dakikalık yoklama yapmaz: bir sonraki dilim sınırına tek seferlik bir
/// [Timer] kurar, tetiklenince yeniden hesaplayıp timer'ı yeniler.
class ThemeController extends ChangeNotifier {
  final LocalStorage _storage;
  final DateTime Function() _clock;

  AppearanceSettings _settings = const AppearanceSettings();
  Brightness _platformBrightness = Brightness.dark;
  PrayerTime? _today;
  PrayerTime? _tomorrow;
  Timer? _boundaryTimer;

  ThemeController({required LocalStorage storage, DateTime Function()? clock})
    : _storage = storage,
      _clock = clock ?? DateTime.now;

  AppearanceSettings get settings => _settings;

  /// Etkin parlaklık: kullanıcı seçimi, `system` ise platformunki.
  Brightness get brightness => switch (_settings.themeMode) {
    AppThemeMode.dark => Brightness.dark,
    AppThemeMode.light => Brightness.light,
    AppThemeMode.system => _platformBrightness,
  };

  /// Etkin dilim. "Vakte göre renk" kapalıysa kullanıcının seçtiği sabit palet.
  DayPhase get phase {
    if (!_settings.timeBasedColor) return _settings.fixedPalette;
    return resolveDayPhase(today: _today, tomorrow: _tomorrow, now: _clock());
  }

  AppTokens get tokens => paletteFor(phase, brightness);

  /// Native çalar ekranın paletini hesaplayan katmana verilen anlık görünüm.
  ///
  /// [phase] yerine ham tercihler taşınır: alarmın paleti planlama anına değil
  /// çalma anına göre çözülür, dilimi orası hesaplar.
  AlarmAppearance get alarmAppearance => AlarmAppearance(
    brightness: brightness,
    timeBasedColor: _settings.timeBasedColor,
    fixedPalette: _settings.fixedPalette,
  );

  /// Kayıtlı ayarları okur. Uygulama açılışında bir kez çağrılır.
  Future<void> load() async {
    _settings = await _storage.getAppearanceSettings();
    notifyListeners();
  }

  /// Vakit verisi değiştiğinde çağrılır; dilimi ve sınır timer'ını tazeler.
  void updatePrayerTimes({PrayerTime? today, PrayerTime? tomorrow}) {
    _today = today;
    _tomorrow = tomorrow;
    _scheduleBoundary();
    notifyListeners();
  }

  /// Cihazın gece/gündüz tercihi değiştiğinde çağrılır.
  void setPlatformBrightness(Brightness brightness) {
    if (_platformBrightness == brightness) return;
    _platformBrightness = brightness;
    // Yalnızca "Sistem" modunda görünümü etkiler; diğer modlarda sessizce
    // saklanır ki kullanıcı Sistem'e geçtiğinde doğru değer hazır olsun.
    if (_settings.themeMode == AppThemeMode.system) notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) =>
      _persist(_settings.copyWith(themeMode: mode));

  Future<void> setTimeBasedColor(bool enabled) =>
      _persist(_settings.copyWith(timeBasedColor: enabled));

  Future<void> setFixedPalette(DayPhase palette) =>
      _persist(_settings.copyWith(fixedPalette: palette));

  /// Uygulama ön plana geldiğinde çağrılır: arka planda timer'ın çalışmamış
  /// olma ihtimaline karşı dilimi ve timer'ı yeniden kurar.
  void refresh() {
    _scheduleBoundary();
    notifyListeners();
  }

  Future<void> _persist(AppearanceSettings next) async {
    if (next == _settings) return;
    _settings = next;
    await _storage.saveAppearanceSettings(next);
    _scheduleBoundary();
    notifyListeners();
  }

  void _scheduleBoundary() {
    _boundaryTimer?.cancel();
    _boundaryTimer = null;

    // Sabit palet modunda sınır beklemenin anlamı yok.
    if (!_settings.timeBasedColor) return;

    final boundary = nextDayPhaseBoundary(
      today: _today,
      tomorrow: _tomorrow,
      now: _clock(),
    );
    if (boundary == null) return;

    final delay = boundary.difference(_clock());
    if (delay.isNegative) return;

    _boundaryTimer = Timer(delay, () {
      notifyListeners();
      _scheduleBoundary();
    });
  }

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    super.dispose();
  }
}
