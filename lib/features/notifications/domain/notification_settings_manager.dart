import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/utils/app_logger.dart';
import '../../prayer_times/data/sqlite_storage.dart';

class NotificationSettingsManager {
  final LocalStorage storage;
  final AppLogger _logger = AppLogger();
  SqliteStorage? get _sqliteStorage =>
      storage is SqliteStorage ? storage as SqliteStorage : null;

  NotificationSettingsManager({required this.storage});

  Future<List<NotificationSetting>> getSettings() async {
    return await storage.getNotificationSettings();
  }

  Future<void> saveSettings(List<NotificationSetting> settings) async {
    await storage.saveNotificationSettings(settings);
    _logger.info('💾 Saved notification settings (${settings.length} items)');
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
    _logger.info(
      '✏️ Updated setting ${setting.prayerType.name} (${setting.minutesBefore} dk) active=${setting.isActive}',
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
      _logger.info(
        '🔀 Toggled setting $prayerType ($minutesBefore dk) -> active=${settings[index].isActive}',
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
    _logger.info('✅ Enabled all settings for $prayerType');
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
    _logger.info('🚫 Disabled all settings for $prayerType');
  }

  Future<void> enableAll() async {
    final settings = await getSettings();

    final updated = settings.map((s) => s.copyWith(isActive: true)).toList();

    await saveSettings(updated);
    _logger.info('✅ Enabled all notification settings (${updated.length})');
  }

  Future<void> disableAll() async {
    final settings = await getSettings();

    final updated = settings.map((s) => s.copyWith(isActive: false)).toList();

    await saveSettings(updated);
    _logger.info('🚫 Disabled all notification settings (${updated.length})');
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
    final defaultSettings = [
      const NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        minutesBefore: 5,
      ),
      // const NotificationSetting(
      //   prayerType: PrayerType.sunrise,
      //   isActive: false,
      //   minutesBefore: 0,
      // ),
      // const NotificationSetting(
      //   prayerType: PrayerType.dhuhr,
      //   isActive: true,
      //   minutesBefore: 0,
      // ),
      // const NotificationSetting(
      //   prayerType: PrayerType.asr,
      //   isActive: true,
      //   minutesBefore: 0,
      // ),
      // const NotificationSetting(
      //   prayerType: PrayerType.maghrib,
      //   isActive: true,
      //   minutesBefore: 0,
      // ),
      // const NotificationSetting(
      //   prayerType: PrayerType.isha,
      //   isActive: true,
      //   minutesBefore: 0,
      // ),
    ];

    await saveSettings(defaultSettings);
  }

  Future<void> removeSetting({
    required PrayerType prayerType,
    required int minutesBefore,
  }) async {
    final sqliteStorage = _sqliteStorage;
    if (sqliteStorage != null) {
      await sqliteStorage.deleteNotificationSetting(
        prayerType: prayerType,
        minutesBefore: minutesBefore,
      );
    } else {
      final settings = await getSettings();
      final updated = settings
          .where(
            (s) =>
                !(s.prayerType == prayerType &&
                    s.minutesBefore == minutesBefore),
          )
          .toList();
      await saveSettings(updated);
    }
    _logger.info('🗑️ Removed setting $prayerType ($minutesBefore dk)');
  }

  Future<void> addSetting(NotificationSetting setting) async {
    final sqliteStorage = _sqliteStorage;
    if (sqliteStorage != null) {
      await sqliteStorage.addNotificationSetting(setting);
    } else {
      final settings = await getSettings();
      settings.add(setting);
      await saveSettings(settings);
    }
    _logger.info(
      '➕ Added setting ${setting.prayerType.name} (${setting.minutesBefore} dk) active=${setting.isActive}',
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
