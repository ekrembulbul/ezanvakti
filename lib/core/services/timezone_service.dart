import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class TimezoneService {
  static TimezoneService? _instance;
  bool _isInitialized = false;
  String? _currentTimezoneName;
  tz.Location? _deviceLocation;

  TimezoneService._();

  static TimezoneService get instance {
    _instance ??= TimezoneService._();
    return _instance!;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();

    _deviceLocation = tz.getLocation('Europe/Istanbul');
    _currentTimezoneName = 'Europe/Istanbul';

    _isInitialized = true;
  }

  bool isTurkeyTimezone() {
    return _currentTimezoneName == 'Europe/Istanbul';
  }

  void setLocalLocation(String locationName) {
    try {
      _deviceLocation = tz.getLocation(locationName);
      _currentTimezoneName = locationName;
    } catch (e) {
      _deviceLocation = tz.getLocation('Europe/Istanbul');
      _currentTimezoneName = 'Europe/Istanbul';
    }
  }

  tz.Location get deviceLocation {
    if (!_isInitialized || _deviceLocation == null) {
      throw StateError(
        'TimezoneService not initialized. Call initialize() first.',
      );
    }
    return _deviceLocation!;
  }

  String get currentTimezoneName {
    if (!_isInitialized || _currentTimezoneName == null) {
      throw StateError(
        'TimezoneService not initialized. Call initialize() first.',
      );
    }
    return _currentTimezoneName!;
  }

  tz.TZDateTime convertToLocalTime(DateTime dateTime) {
    if (!_isInitialized) {
      throw StateError(
        'TimezoneService not initialized. Call initialize() first.',
      );
    }

    return tz.TZDateTime.from(dateTime, deviceLocation);
  }

  DateTime convertFromLocalTime(tz.TZDateTime tzDateTime) {
    return DateTime(
      tzDateTime.year,
      tzDateTime.month,
      tzDateTime.day,
      tzDateTime.hour,
      tzDateTime.minute,
      tzDateTime.second,
      tzDateTime.millisecond,
      tzDateTime.microsecond,
    );
  }

  tz.TZDateTime now() {
    if (!_isInitialized) {
      throw StateError(
        'TimezoneService not initialized. Call initialize() first.',
      );
    }
    return tz.TZDateTime.now(deviceLocation);
  }

  bool isDST(DateTime dateTime) {
    if (!_isInitialized) {
      throw StateError(
        'TimezoneService not initialized. Call initialize() first.',
      );
    }

    final tzDateTime = tz.TZDateTime.from(dateTime, deviceLocation);
    final offset = tzDateTime.timeZoneOffset;

    final winterDate = DateTime(dateTime.year, 1, 1);
    final winterTzDate = tz.TZDateTime.from(winterDate, deviceLocation);
    final winterOffset = winterTzDate.timeZoneOffset;

    return offset != winterOffset;
  }

  bool hasDSTSupport() {
    return !isTurkeyTimezone();
  }

  Duration getTimezoneOffset(DateTime dateTime) {
    if (!_isInitialized) {
      throw StateError(
        'TimezoneService not initialized. Call initialize() first.',
      );
    }

    final tzDateTime = tz.TZDateTime.from(dateTime, deviceLocation);
    return tzDateTime.timeZoneOffset;
  }

  bool hasTimezoneMismatch({Duration threshold = const Duration(minutes: 5)}) {
    final deviceTime = DateTime.now();
    final systemTime = DateTime.now().toUtc();
    final expectedUtc = deviceTime.toUtc();

    final difference = systemTime.difference(expectedUtc).abs();
    return difference > threshold;
  }

  String getTimezoneInfo(DateTime dateTime) {
    if (!_isInitialized) {
      throw StateError(
        'TimezoneService not initialized. Call initialize() first.',
      );
    }

    final tzDateTime = tz.TZDateTime.from(dateTime, deviceLocation);
    final offset = tzDateTime.timeZoneOffset;
    final isDst = isDST(dateTime);

    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60).abs();
    final sign = hours >= 0 ? '+' : '-';

    return 'UTC$sign${hours.abs()}:${minutes.toString().padLeft(2, '0')}${isDst ? ' (DST)' : ''}';
  }

  bool isInitialized() => _isInitialized;

  void reset() {
    _isInitialized = false;
    _currentTimezoneName = null;
    _deviceLocation = null;
  }
}
