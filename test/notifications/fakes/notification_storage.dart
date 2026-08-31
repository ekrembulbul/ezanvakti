import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/fasting_log.dart';
import 'package:ezanvakti/core/models/prayer_log.dart';
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';

/// Planlayici testleri icin bellek-ici depo.
class NotificationTestStorage implements LocalStorage {

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

  List<QuietWindow> quietWindows = [];

  @override
  Future<List<QuietWindow>> getQuietWindows() async => quietWindows;

  @override
  Future<void> saveQuietWindows(List<QuietWindow> windows) async =>
      quietWindows = windows;
  List<NotificationSetting> settings = [];
  GeneralSettings general = const GeneralSettings();

  @override
  Future<List<NotificationSetting>> getNotificationSettings() async => settings;

  @override
  Future<GeneralSettings> getGeneralSettings() async => general;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('NotificationTestStorage.${invocation.memberName}');
}
