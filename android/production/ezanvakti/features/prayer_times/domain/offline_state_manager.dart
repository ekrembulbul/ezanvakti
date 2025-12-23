import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/errors/prayer_times_errors.dart';

enum CacheStatus { available, stale, expired, notFound, incomplete }

class CacheInfo {
  final CacheStatus status;
  final DateTime? lastUpdate;
  final int? cachedDays;
  final String? message;

  const CacheInfo({
    required this.status,
    this.lastUpdate,
    this.cachedDays,
    this.message,
  });

  bool get isUsable =>
      status == CacheStatus.available || status == CacheStatus.stale;
  bool get hasData => cachedDays != null && cachedDays! > 0;
}

class OfflineStateManager {
  final LocalStorage storage;

  static const Duration cacheMaxAge = Duration(days: 7);
  static const Duration cacheStaleAge = Duration(days: 1);

  OfflineStateManager({required this.storage});

  Future<CacheInfo> getCacheStatus({
    required Location location,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final effectiveStartDate = startDate ?? today;
    final effectiveEndDate = endDate ?? today.add(const Duration(days: 7));

    final cachedTimes = await storage.getPrayerTimes(
      locationId: location.id,
      startDate: effectiveStartDate,
      endDate: effectiveEndDate,
    );

    if (cachedTimes.isEmpty) {
      return const CacheInfo(
        status: CacheStatus.notFound,
        message: 'No cached data found',
      );
    }

    final lastUpdate = await storage.getLastUpdateTime();

    if (lastUpdate == null) {
      return CacheInfo(
        status: CacheStatus.stale,
        cachedDays: cachedTimes.length,
        message: 'No update timestamp found',
      );
    }

    final age = DateTime.now().difference(lastUpdate);

    if (age > cacheMaxAge) {
      return CacheInfo(
        status: CacheStatus.expired,
        lastUpdate: lastUpdate,
        cachedDays: cachedTimes.length,
        message: 'Cache is too old (${age.inDays} days)',
      );
    }

    final expectedDays =
        effectiveEndDate.difference(effectiveStartDate).inDays + 1;
    if (cachedTimes.length < expectedDays) {
      return CacheInfo(
        status: CacheStatus.incomplete,
        lastUpdate: lastUpdate,
        cachedDays: cachedTimes.length,
        message:
            'Cache is incomplete: ${cachedTimes.length}/$expectedDays days',
      );
    }

    if (age > cacheStaleAge) {
      return CacheInfo(
        status: CacheStatus.stale,
        lastUpdate: lastUpdate,
        cachedDays: cachedTimes.length,
        message: 'Cache is stale but usable (${age.inHours} hours old)',
      );
    }

    return CacheInfo(
      status: CacheStatus.available,
      lastUpdate: lastUpdate,
      cachedDays: cachedTimes.length,
      message: 'Cache is fresh',
    );
  }

  Future<List<PrayerTime>> getOfflinePrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final cachedTimes = await storage.getPrayerTimes(
      locationId: location.id,
      startDate: startDate,
      endDate: endDate,
    );

    if (cachedTimes.isEmpty) {
      throw CacheNotFoundException(
        'No cached prayer times available for ${location.province}/${location.district}',
      );
    }

    return cachedTimes;
  }

  Future<PrayerTime?> getOfflineDailyPrayerTime({
    required Location location,
    required DateTime date,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    final cachedTime = await storage.getDailyPrayerTime(
      locationId: location.id,
      date: normalizedDate,
    );

    return cachedTime;
  }

  Future<bool> hasCacheForDate({
    required Location location,
    required DateTime date,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);

    final cachedTime = await storage.getDailyPrayerTime(
      locationId: location.id,
      date: normalizedDate,
    );

    return cachedTime != null;
  }

  Future<bool> hasCacheForPeriod({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final cachedTimes = await storage.getPrayerTimes(
      locationId: location.id,
      startDate: startDate,
      endDate: endDate,
    );

    final expectedDays = endDate.difference(startDate).inDays + 1;
    return cachedTimes.length >= expectedDays;
  }

  String getCacheStatusMessage(CacheStatus status) {
    switch (status) {
      case CacheStatus.available:
        return 'Veriler güncel';
      case CacheStatus.stale:
        return 'Veriler güncellenmeli';
      case CacheStatus.expired:
        return 'Veriler çok eski, güncelleme gerekli';
      case CacheStatus.notFound:
        return 'Veri bulunamadı';
      case CacheStatus.incomplete:
        return 'Veriler eksik';
    }
  }

  String getOfflineMessage() {
    return 'İnternet bağlantısı yok. Kaydedilmiş veriler gösteriliyor.';
  }

  String getNoDataMessage() {
    return 'Veri alınamadı. Lütfen internet bağlantınızı kontrol edin.';
  }

  String getUpdateFailedMessage() {
    return 'Güncelleme başarısız. Kaydedilmiş veriler gösteriliyor.';
  }
}
