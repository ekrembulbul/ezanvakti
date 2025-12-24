import 'package:flutter/foundation.dart';
import '../models/location.dart';
import '../models/prayer_time.dart';
import '../models/notification_setting.dart';

class AppState extends ChangeNotifier {
  Location? _activeLocation;
  PrayerTime? _todaysPrayerTime;
  PrayerTime? _tomorrowsPrayerTime;
  List<PrayerTime> _prayerTimes = [];
  List<NotificationSetting> _notificationSettings = [];
  DateTime? _lastUpdateTime;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasNotificationPermission = false;

  Location? get activeLocation => _activeLocation;
  PrayerTime? get todaysPrayerTime => _todaysPrayerTime;
  PrayerTime? get tomorrowsPrayerTime => _tomorrowsPrayerTime;
  List<PrayerTime> get prayerTimes => _prayerTimes;
  List<NotificationSetting> get notificationSettings => _notificationSettings;
  DateTime? get lastUpdateTime => _lastUpdateTime;
  bool get isLoading => _isLoading;
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

  void setLastUpdateTime(DateTime? time) {
    _lastUpdateTime = time;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
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
