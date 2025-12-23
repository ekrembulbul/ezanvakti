import '../../../core/interfaces/prayer_time_provider.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/location.dart';

class PrayerTimesRepository {
  final PrayerTimeProvider provider;
  final LocalStorage storage;

  static const int cacheDaysForward = 30;
  static const int cacheCleanupDaysOld = 90;

  PrayerTimesRepository({required this.provider, required this.storage});

  Future<List<PrayerTime>> getPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cachedTimes = await storage.getPrayerTimes(
        locationId: location.id,
        startDate: startDate,
        endDate: endDate,
      );

      if (cachedTimes.isNotEmpty &&
          _isCacheComplete(cachedTimes, startDate, endDate)) {
        return cachedTimes;
      }
    }

    try {
      final remoteTimes = await provider.fetchPrayerTimes(
        location: location,
        startDate: startDate,
        endDate: endDate,
      );

      if (remoteTimes.isNotEmpty) {
        await storage.savePrayerTimes(remoteTimes, location.id);
        await storage.saveLastUpdateTime(DateTime.now());
      }

      return remoteTimes;
    } catch (e) {
      final cachedTimes = await storage.getPrayerTimes(
        locationId: location.id,
        startDate: startDate,
        endDate: endDate,
      );

      if (cachedTimes.isEmpty) {
        rethrow;
      }

      return cachedTimes;
    }
  }

  Future<PrayerTime?> getDailyPrayerTime({
    required Location location,
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (!forceRefresh) {
      final cachedTime = await storage.getDailyPrayerTime(
        locationId: location.id,
        date: normalizedDate,
      );

      if (cachedTime != null) {
        return cachedTime;
      }
    }

    try {
      final remoteTime = await provider.fetchDailyPrayerTime(
        location: location,
        date: normalizedDate,
      );

      if (remoteTime != null) {
        await storage.savePrayerTimes([remoteTime], location.id);
        await storage.saveLastUpdateTime(DateTime.now());
      }

      return remoteTime;
    } catch (e) {
      final cachedTime = await storage.getDailyPrayerTime(
        locationId: location.id,
        date: normalizedDate,
      );

      if (cachedTime == null) {
        rethrow;
      }

      return cachedTime;
    }
  }

  Future<void> refreshPrayerTimes(Location location) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = today.add(Duration(days: cacheDaysForward));

    await getPrayerTimes(
      location: location,
      startDate: today,
      endDate: endDate,
      forceRefresh: true,
    );
  }

  Future<void> cleanupOldCache() async {
    final cutoffDate = DateTime.now().subtract(
      Duration(days: cacheCleanupDaysOld),
    );
    await storage.deleteOldPrayerTimes(cutoffDate);
  }

  Future<DateTime?> getLastUpdateTime() async {
    return await storage.getLastUpdateTime();
  }

  Future<bool> isCacheStale({
    Duration staleDuration = const Duration(days: 1),
  }) async {
    final lastUpdate = await getLastUpdateTime();
    if (lastUpdate == null) return true;

    final difference = DateTime.now().difference(lastUpdate);
    return difference > staleDuration;
  }

  bool _isCacheComplete(
    List<PrayerTime> cachedTimes,
    DateTime startDate,
    DateTime endDate,
  ) {
    if (cachedTimes.isEmpty) return false;

    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

    final expectedDays = normalizedEnd.difference(normalizedStart).inDays + 1;

    if (cachedTimes.length < expectedDays) return false;

    DateTime currentDate = normalizedStart;
    int index = 0;

    while (currentDate.isBefore(normalizedEnd.add(const Duration(days: 1)))) {
      if (index >= cachedTimes.length) return false;

      final cachedDate = cachedTimes[index].date;
      final normalizedCachedDate = DateTime(
        cachedDate.year,
        cachedDate.month,
        cachedDate.day,
      );

      if (!normalizedCachedDate.isAtSameMomentAs(currentDate)) {
        return false;
      }

      currentDate = currentDate.add(const Duration(days: 1));
      index++;
    }

    return true;
  }
}
