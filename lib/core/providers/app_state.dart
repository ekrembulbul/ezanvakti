import 'package:flutter/foundation.dart';
import '../models/alarm.dart';
import '../models/location.dart';
import '../models/skipped_occurrence.dart';
import '../models/prayer_time.dart';
import '../models/notification_setting.dart';

class AppState extends ChangeNotifier {
  Location? _activeLocation;
  PrayerTime? _todaysPrayerTime;
  PrayerTime? _tomorrowsPrayerTime;
  List<PrayerTime> _prayerTimes = [];
  List<NotificationSetting> _notificationSettings = [];
  List<Alarm> _alarms = [];
  Set<SkippedOccurrence> _skips = const {};
  DateTime? _lastUpdateTime;
  bool _isRefreshing = false;
  String? _errorMessage;
  bool _hasNotificationPermission = false;

  Location? get activeLocation => _activeLocation;
  PrayerTime? get todaysPrayerTime => _todaysPrayerTime;
  PrayerTime? get tomorrowsPrayerTime => _tomorrowsPrayerTime;
  List<PrayerTime> get prayerTimes => _prayerTimes;
  List<NotificationSetting> get notificationSettings => _notificationSettings;
  List<Alarm> get alarms => _alarms;

  /// "Yalnızca bu sefer" atlanmış örnekler.
  Set<SkippedOccurrence> get skips => _skips;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// Bir veri yüklemesi uçuşta mı.
  bool get isRefreshing => _isRefreshing;

  /// Ekranda gösterilecek hiçbir şey yokken süren yükleme. Yalnızca bu durumda
  /// tam ekran yükleme gösterilir; veri varken yenileme ekranı boşaltmaz.
  bool get isLoading => _isRefreshing && _todaysPrayerTime == null;

  String? get errorMessage => _errorMessage;
  bool get hasNotificationPermission => _hasNotificationPermission;
  bool get hasActiveLocation => _activeLocation != null;

  void setActiveLocation(Location? location) {
    _activeLocation = location;
    notifyListeners();
  }

  void setTodaysPrayerTime(PrayerTime? prayerTime) {
    _todaysPrayerTime = prayerTime;
    notifyListeners();
  }

  void setTomorrowsPrayerTime(PrayerTime? prayerTime) {
    _tomorrowsPrayerTime = prayerTime;
    notifyListeners();
  }

  void setPrayerTimes(List<PrayerTime> times) {
    _prayerTimes = times;
    notifyListeners();
  }

  void setNotificationSettings(List<NotificationSetting> settings) {
    _notificationSettings = settings;
    notifyListeners();
  }

  void setAlarms(List<Alarm> alarms) {
    _alarms = alarms;
    notifyListeners();
  }

  void setSkips(Set<SkippedOccurrence> skips) {
    _skips = skips;
    notifyListeners();
  }

  void setLastUpdateTime(DateTime? time) {
    _lastUpdateTime = time;
    notifyListeners();
  }

  void setRefreshing(bool refreshing) {
    _isRefreshing = refreshing;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void setNotificationPermission(bool hasPermission) {
    _hasNotificationPermission = hasPermission;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearPrayerTimes() {
    _prayerTimes = [];
    notifyListeners();
  }
}
