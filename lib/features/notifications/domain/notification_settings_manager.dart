import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/app_logger.dart';
import 'default_notification_settings.dart';

class NotificationSettingsManager {
  final LocalStorage storage;
  final AppLogger _logger = AppLogger();

  NotificationSettingsManager({required this.storage});

  Future<List<NotificationSetting>> getSettings() async {
    return await storage.getNotificationSettings();
  }

  Future<void> saveSettings(List<NotificationSetting> settings) async {
    await storage.saveNotificationSettings(settings);
    _logger.debug('Saved notification settings (${settings.length} items)');
  }

  Future<void> updateSetting(NotificationSetting setting) async {
    final settings = await getSettings();

    final index = settings.indexWhere(
      (s) =>
          s.prayerType == setting.prayerType &&
          s.minutesBefore == setting.minutesBefore,
    );

    if (index != -1) {
      settings[index] = setting;
    } else {
      settings.add(setting);
    }

    await saveSettings(settings);
    _logger.debug(
      'Updated setting ${setting.prayerType.name} (${setting.minutesBefore} dk) active=${setting.isActive}',
    );
  }

  Future<void> toggleSetting({
    required PrayerType prayerType,
    required int minutesBefore,
  }) async {
    final settings = await getSettings();

    final index = settings.indexWhere(
      (s) => s.prayerType == prayerType && s.minutesBefore == minutesBefore,
    );

    if (index != -1) {
      settings[index] = settings[index].copyWith(
        isActive: !settings[index].isActive,
      );
      await saveSettings(settings);
      _logger.debug(
        'Toggled setting $prayerType ($minutesBefore dk) -> active=${settings[index].isActive}',
      );
    }
  }

  Future<void> enableAllForPrayer(PrayerType prayerType) async {
    final settings = await getSettings();

    final updated = settings.map((s) {
      if (s.prayerType == prayerType) {
        return s.copyWith(isActive: true);
      }
      return s;
    }).toList();

    await saveSettings(updated);
    _logger.debug('Enabled all settings for $prayerType');
  }

  Future<void> disableAllForPrayer(PrayerType prayerType) async {
    final settings = await getSettings();

    final updated = settings.map((s) {
      if (s.prayerType == prayerType) {
        return s.copyWith(isActive: false);
      }
      return s;
    }).toList();

    await saveSettings(updated);
    _logger.debug('Disabled all settings for $prayerType');
  }

  Future<void> enableAll() async {
    final settings = await getSettings();

    final updated = settings.map((s) => s.copyWith(isActive: true)).toList();

    await saveSettings(updated);
    _logger.debug('Enabled all notification settings (${updated.length})');
  }

  Future<void> disableAll() async {
    final settings = await getSettings();

    final updated = settings.map((s) => s.copyWith(isActive: false)).toList();

    await saveSettings(updated);
    _logger.debug('Disabled all notification settings (${updated.length})');
  }

  Future<List<NotificationSetting>> getActiveSettings() async {
    final settings = await getSettings();
    return settings.where((s) => s.isActive).toList();
  }

  Future<List<NotificationSetting>> getSettingsForPrayer(
    PrayerType prayerType,
  ) async {
    final settings = await getSettings();
    return settings.where((s) => s.prayerType == prayerType).toList();
  }

  Future<bool> hasActiveSettings() async {
    final settings = await getActiveSettings();
    return settings.isNotEmpty;
  }

  Future<NotificationSetting?> getSetting({
    required PrayerType prayerType,
    required int minutesBefore,
  }) async {
    final settings = await getSettings();

    try {
      return settings.firstWhere(
        (s) => s.prayerType == prayerType && s.minutesBefore == minutesBefore,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> createDefaultSettings() async {
    await saveSettings(defaultNotificationSettings);
  }

  /// Varsayılan bildirimleri uygulama ömründe yalnızca bir kez oluşturur.
  ///
  /// Daha önce işaretlenmişse hiçbir şey yapmaz; böylece kullanıcı tüm
  /// bildirimleri silse bile (örn. konum değişiminde) varsayılanlar otomatik
  /// geri gelmez. Bayrak öncesi kurulumlarda mevcut ayarlar korunur, yalnızca
  /// "tohumlandı" olarak işaretlenir.
  Future<void> ensureDefaultsSeeded() async {
    if (await storage.isNotificationDefaultsInitialized()) {
      return;
    }

    final existing = await getSettings();
    if (existing.isEmpty) {
      await createDefaultSettings();
      _logger.debug('First launch: created default notification settings');
    } else {
      _logger.debug('Existing notification settings found; marking seeded');
    }

    await storage.markNotificationDefaultsInitialized();
  }

  Future<void> removeSetting({
    required PrayerType prayerType,
    required int minutesBefore,
  }) async {
    await storage.deleteNotificationSetting(
      prayerType: prayerType,
      minutesBefore: minutesBefore,
    );
    _logger.debug('Removed setting $prayerType ($minutesBefore dk)');
  }

  Future<void> addSetting(NotificationSetting setting) async {
    await storage.addNotificationSetting(setting);
    _logger.debug(
      'Added setting ${setting.prayerType.name} (${setting.minutesBefore} dk) active=${setting.isActive}',
    );
  }

  Future<int> getActiveNotificationCount() async {
    final settings = await getActiveSettings();
    return settings.length;
  }

  Future<Map<PrayerType, List<NotificationSetting>>>
  getSettingsGroupedByPrayer() async {
    final settings = await getSettings();
    final grouped = <PrayerType, List<NotificationSetting>>{};

    for (final setting in settings) {
      if (!grouped.containsKey(setting.prayerType)) {
        grouped[setting.prayerType] = [];
      }
      grouped[setting.prayerType]!.add(setting);
    }

    return grouped;
  }
}
