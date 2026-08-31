import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/core/models/quiet_window.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/models/qr_code_entry.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/abort_state.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/core/interfaces/notification_service.dart';
import 'package:ezanvakti/core/interfaces/prayer_time_provider.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/models/calculation_settings.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';

/// Katmanlari birlestiren testlerin ortak sahte altyapisi.
///
/// Her test dosyasi kendi LocalStorage taklidini yazmak zorunda kalmasin diye
/// burada tek yerde duruyor.
DateTime atMidnight(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Verilen gun icin sabit saatlerde bir [PrayerTime] uretir.
PrayerTime prayerTimeFor(DateTime day) {
  DateTime at(int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);
  return PrayerTime(
    date: atMidnight(day),
    fajr: at(4, 11),
    sunrise: at(5, 55),
    dhuhr: at(13, 15),
    asr: at(17, 9),
    maghrib: at(20, 25),
    isha: at(22, 1),
  );
}

/// Istege bagli olarak hata firlatabilen, cagri sayan saglayici.
class FakeProvider implements PrayerTimeProvider {
  int fetchCount = 0;
  Exception? failWith;

  @override
  String get providerName => 'fake';

  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    fetchCount++;
    final failure = failWith;
    if (failure != null) throw failure;

    final days = endDate.difference(startDate).inDays;
    return List.generate(
      days + 1,
      (i) => prayerTimeFor(startDate.add(Duration(days: i))),
    );
  }

  @override
  Future<PrayerTime?> fetchDailyPrayerTime({
    required Location location,
    required DateTime date,
  }) async {
    fetchCount++;
    final failure = failWith;
    if (failure != null) throw failure;
    return prayerTimeFor(date);
  }
}

/// Bellekte tutan depo. Vakitler konum + gun anahtariyla saklanir.
class FakeStorage implements LocalStorage {

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

  final List<QrCodeEntry> _qrCodes = [];

  @override
  Future<List<QrCodeEntry>> getQrCodes() async => List.of(_qrCodes);

  @override
  Future<void> saveQrCode(QrCodeEntry entry) async {
    _qrCodes.removeWhere((e) => e.id == entry.id);
    _qrCodes.insert(0, entry);
  }

  @override
  Future<void> deleteQrCode(String id) async =>
      _qrCodes.removeWhere((e) => e.id == id);

  Map<String, String> _alarmScheduleFailures = {};

  @override
  Future<Map<String, String>> getAlarmScheduleFailures() async =>
      _alarmScheduleFailures;

  @override
  Future<void> saveAlarmScheduleFailures(Map<String, String> failures) async =>
      _alarmScheduleFailures = failures;
  final Map<String, Map<String, PrayerTime>> _times = {};
  final List<Location> _locations = [];
  final List<Alarm> _alarms = [];
  List<NotificationSetting> _notificationSettings = [];
  Location? _activeLocation;
  DateTime? _lastUpdate;
  CalculationSettings _calculationSettings = CalculationSettings.defaults;
  AppearanceSettings _appearanceSettings = const AppearanceSettings();
  bool _defaultsInitialized = false;

  static String _dayKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  @override
  Future<void> init() async {}

  @override
  Future<void> savePrayerTimes(
    List<PrayerTime> prayerTimes,
    String locationId,
  ) async {
    final bucket = _times.putIfAbsent(locationId, () => {});
    for (final time in prayerTimes) {
      bucket[_dayKey(time.date)] = time;
    }
  }

  @override
  Future<List<PrayerTime>> getPrayerTimes({
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bucket = _times[locationId];
    if (bucket == null) return [];
    return bucket.values
        .where(
          (t) =>
              !t.date.isBefore(atMidnight(startDate)) &&
              !t.date.isAfter(atMidnight(endDate)),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<PrayerTime?> getDailyPrayerTime({
    required String locationId,
    required DateTime date,
  }) async {
    return _times[locationId]?[_dayKey(date)];
  }

  @override
  Future<void> deleteOldPrayerTimes(DateTime cutoffDate) async {
    for (final bucket in _times.values) {
      bucket.removeWhere((_, time) => time.date.isBefore(cutoffDate));
    }
  }

  @override
  Future<void> deletePrayerTimesForLocation(String locationId) async {
    _times.remove(locationId);
  }

  @override
  Future<void> deleteAllPrayerTimes() async => _times.clear();

  @override
  Future<CalculationSettings> getCalculationSettings() async =>
      _calculationSettings;

  @override
  Future<void> saveCalculationSettings(CalculationSettings settings) async {
    _calculationSettings = settings;
  }

  @override
  Future<AppearanceSettings> getAppearanceSettings() async =>
      _appearanceSettings;

  @override
  Future<void> saveAppearanceSettings(AppearanceSettings settings) async {
    _appearanceSettings = settings;
  }

  @override
  Future<void> saveActiveLocation(Location location) async {
    _activeLocation = location;
    if (!_locations.any((l) => l.id == location.id)) _locations.add(location);
  }

  @override
  Future<Location?> getActiveLocation() async => _activeLocation;

  @override
  Future<List<Location>> getSavedLocations() async => List.of(_locations);

  @override
  Future<void> saveLocation(Location location) async {
    _locations.add(location);
  }

  @override
  Future<void> updateLocation(Location location) async {
    final index = _locations.indexWhere((l) => l.id == location.id);
    if (index >= 0) _locations[index] = location;
    if (_activeLocation?.id == location.id) _activeLocation = location;
  }

  @override
  Future<void> deleteLocation(String locationId) async {
    _locations.removeWhere((l) => l.id == locationId);
  }

  @override
  Future<void> saveNotificationSettings(
    List<NotificationSetting> settings,
  ) async {
    _notificationSettings = List.of(settings);
  }

  @override
  Future<List<NotificationSetting>> getNotificationSettings() async =>
      List.of(_notificationSettings);

  @override
  Future<void> addNotificationSetting(NotificationSetting setting) async {
    _notificationSettings.add(setting);
  }

  @override
  Future<void> deleteNotificationSetting({
    required PrayerType prayerType,
    required int minutesBefore,
    String weekdays = '',
  }) async {
    _notificationSettings.removeWhere(
      (s) => s.prayerType == prayerType && s.minutesBefore == minutesBefore,
    );
  }

  @override
  Future<bool> isNotificationDefaultsInitialized() async =>
      _defaultsInitialized;

  @override
  Future<void> markNotificationDefaultsInitialized() async {
    _defaultsInitialized = true;
  }

  @override
  Future<void> saveLastUpdateTime(DateTime time) async => _lastUpdate = time;

  @override
  Future<DateTime?> getLastUpdateTime() async => _lastUpdate;

  List<SkippedOccurrence> _skippedOccurrences = [];

  @override
  Future<List<SkippedOccurrence>> getSkippedOccurrences() async =>
      List.of(_skippedOccurrences);

  @override
  Future<void> saveSkippedOccurrences(
    List<SkippedOccurrence> occurrences,
  ) async {
    _skippedOccurrences = List.of(occurrences);
  }

  @override
  Future<List<Alarm>> getAlarms() async => List.of(_alarms);

  @override
  Future<void> saveAlarm(Alarm alarm) async {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index >= 0) {
      _alarms[index] = alarm;
    } else {
      _alarms.add(alarm);
    }
  }

  @override
  Future<void> deleteAlarm(String id) async {
    _alarms.removeWhere((a) => a.id == id);
  }

  // Gorev oturumu ve acil cikis kademesi bu testlerde kullanilmiyor; bellekte
  // tutulur ki fake gercek kontrati karsilasin.
  MissionSession? _missionSession;
  AbortState _abortState = const AbortState();

  @override
  Future<MissionSession?> getMissionSession() async => _missionSession;

  @override
  Future<void> saveMissionSession(MissionSession? session) async {
    _missionSession = session;
  }

  @override
  Future<AbortState> getAbortState() async => _abortState;

  @override
  Future<void> saveAbortState(AbortState state) async {
    _abortState = state;
  }

}

/// Planlanan bildirimleri ve izin cagrilarini kaydeden servis.
class FakeNotificationService implements NotificationService {
  final List<ScheduledNotification> scheduled = [];
  int cancelAllCount = 0;
  int permissionRequestCount = 0;
  bool permissionGranted = true;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequestCount++;
    return permissionGranted;
  }

  @override
  Future<bool> isPermissionGranted() async => permissionGranted;

  @override
  Future<void> scheduleNotification({
    required String id,
    required DateTime scheduledTime,
    required String title,
    required String body,
    String? soundId,
    bool silent = false,
    bool timeSensitive = true,
  }) async {
    scheduled.add(
      ScheduledNotification(
        id: id,
        scheduledTime: scheduledTime,
        // Kimlik "<prayer>_<offset>_<gun>" bicimindedir; testler id uzerinden
        // dogruladigi icin burada varsayilan degerler yeterli.
        prayerType: PrayerType.fajr,
        minutesBefore: 0,
      ),
    );
  }

  @override
  Future<void> cancelNotification(String id) async {
    scheduled.removeWhere((n) => n.id == id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    cancelAllCount++;
    scheduled.clear();
  }

  @override
  Future<List<ScheduledNotification>> getPendingNotifications() async =>
      List.of(scheduled);

  @override
  Future<void> openExactAlarmSettings() async {}
}
