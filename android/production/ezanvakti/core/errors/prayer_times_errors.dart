class PrayerTimesException implements Exception {
  final String message;
  final dynamic originalError;

  PrayerTimesException(this.message, [this.originalError]);

  @override
  String toString() => 'PrayerTimesException: $message';
}

class NetworkException extends PrayerTimesException {
  NetworkException([String? message, dynamic originalError])
    : super(message ?? 'Network error occurred', originalError);
}

class CacheNotFoundException extends PrayerTimesException {
  CacheNotFoundException([String? message])
    : super(message ?? 'No cached data available');
}

class CacheExpiredException extends PrayerTimesException {
  final DateTime? lastUpdate;
  final Duration? staleDuration;

  CacheExpiredException({String? message, this.lastUpdate, this.staleDuration})
    : super(message ?? 'Cached data has expired');

  @override
  String toString() {
    if (lastUpdate != null && staleDuration != null) {
      return 'CacheExpiredException: Cache is stale. Last update: $lastUpdate, Max age: $staleDuration';
    }
    return super.toString();
  }
}

class IncompleteCacheException extends PrayerTimesException {
  final int expectedDays;
  final int actualDays;

  IncompleteCacheException({
    required this.expectedDays,
    required this.actualDays,
    String? message,
  }) : super(
         message ??
             'Cache is incomplete. Expected $expectedDays days, found $actualDays days',
       );
}
