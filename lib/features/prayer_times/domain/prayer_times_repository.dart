import '../../../core/interfaces/prayer_time_provider.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/location.dart';
import '../../../core/utils/app_logger.dart';

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
    final logger = AppLogger();
    final dayCount = endDate.difference(startDate).inDays + 1;
    logger.debug(
      'Repository: Getting prayer times for ${location.province}/${location.district} ($dayCount days, forceRefresh: $forceRefresh)',
    );

    if (!forceRefresh) {
      final cachedTimes = await storage.getPrayerTimes(
        locationId: location.id,
        startDate: startDate,
        endDate: endDate,
      );

      if (cachedTimes.isNotEmpty &&
          _isCacheComplete(cachedTimes, startDate, endDate)) {
        logger.debug('Cache HIT: ${cachedTimes.length} days from cache');
        return cachedTimes;
      } else {
        logger.debug(
          'Cache MISS: Found ${cachedTimes.length} days, but incomplete. Fetching from remote',
        );
      }
    } else {
      logger.debug('Force refresh requested, skipping cache');
    }

    try {
      logger.debug('Fetching from remote API');
      final remoteTimes = await provider.fetchPrayerTimes(
        location: await _resolveLocation(location),
        startDate: startDate,
        endDate: endDate,
      );

      if (remoteTimes.isNotEmpty) {
        logger.debug('Saving ${remoteTimes.length} days to cache');
        await storage.savePrayerTimes(remoteTimes, location.id);
        await storage.saveLastUpdateTime(DateTime.now());
      }

      return remoteTimes;
    } catch (e) {
      logger.warning('Remote fetch failed, attempting fallback to cache', e);
      final cachedTimes = await storage.getPrayerTimes(
        locationId: location.id,
        startDate: startDate,
        endDate: endDate,
      );

      if (cachedTimes.isEmpty) {
        logger.error('No cached data available, rethrowing error', e);
        rethrow;
      }

      logger.info('Fallback successful: ${cachedTimes.length} days from cache');
      return cachedTimes;
    }
  }

  Future<PrayerTime?> getDailyPrayerTime({
    required Location location,
    required DateTime date,
    bool forceRefresh = false,
  }) async {
    final logger = AppLogger();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    logger.debug(
      'Repository: Getting single day for ${location.province}/${location.district} on ${normalizedDate.toIso8601String().split('T')[0]}',
    );

    if (!forceRefresh) {
      final cachedTime = await storage.getDailyPrayerTime(
        locationId: location.id,
        date: normalizedDate,
      );

      if (cachedTime != null) {
        logger.debug('Cache HIT: Single day from cache');
        return cachedTime;
      } else {
        logger.debug('Cache MISS: Fetching from remote');
      }
    }

    try {
      logger.debug('Fetching from remote API');
      final remoteTime = await provider.fetchDailyPrayerTime(
        location: await _resolveLocation(location),
        date: normalizedDate,
      );

      if (remoteTime != null) {
        logger.debug('Saving single day to cache');
        await storage.savePrayerTimes([remoteTime], location.id);
        await storage.saveLastUpdateTime(DateTime.now());
      }

      return remoteTime;
    } catch (e) {
      logger.warning('Remote fetch failed, attempting fallback to cache', e);
      final cachedTime = await storage.getDailyPrayerTime(
        locationId: location.id,
        date: normalizedDate,
      );

      if (cachedTime == null) {
        logger.error('No cached data available, rethrowing error', e);
        rethrow;
      }

      logger.info('Fallback successful: Single day from cache');
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

  /// Bir konumun önbellekteki vakitlerini siler. Hesaplama parametreleri
  /// (method/school) değişince eski vakitler geçersiz olur; bir sonraki okuma
  /// güncel parametrelerle yeniden çeker.
  Future<void> clearCacheForLocation(String locationId) async {
    await storage.deletePrayerTimesForLocation(locationId);
  }

  /// Tüm konumların önbelleğini siler. Global hesaplama ayarı değişince
  /// (tüm "inherit" konumları etkilediği için) kullanılır.
  Future<void> clearAllCache() async {
    await storage.deleteAllPrayerTimes();
  }

  /// Konumun override'larını global ayarla birleştirip somut parametreli bir
  /// konum döner; sağlayıcıya bu gönderilir. Önbellek kimliği değişmez.
  Future<Location> _resolveLocation(Location location) async {
    final settings = await storage.getCalculationSettings();
    return location.withResolvedParams(settings);
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
