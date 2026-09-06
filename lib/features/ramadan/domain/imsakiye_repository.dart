import '../../../core/models/location.dart';
import '../../../core/models/prayer_time.dart';
import '../../prayer_times/domain/prayer_times_repository.dart';
import 'ramadan_period.dart';

class IncompleteImsakiyeException implements Exception {
  const IncompleteImsakiyeException();
}

typedef ImsakiyeLoader =
    Future<List<PrayerTime>> Function({
      required Location location,
      required RamadanPeriod period,
      bool forceRefresh,
    });

class ImsakiyeRepository {
  final PrayerTimesRepository _prayerTimes;
  ImsakiyeRepository(this._prayerTimes);

  Future<List<PrayerTime>> load({
    required Location location,
    required RamadanPeriod period,
    bool forceRefresh = false,
  }) async {
    final times = await _prayerTimes.getPrayerTimes(
      location: location,
      startDate: period.start,
      endDate: period.lastDay,
      forceRefresh: forceRefresh,
    );
    return validateImsakiye(times, period);
  }
}

/// Checks every calendar day, including duplicates and out-of-range rows.
List<PrayerTime> validateImsakiye(
  List<PrayerTime> times,
  RamadanPeriod period,
) {
  final sorted = List<PrayerTime>.of(times)
    ..sort((a, b) => a.date.compareTo(b.date));
  final expected = period.days;
  if (sorted.length != expected.length) {
    throw const IncompleteImsakiyeException();
  }
  for (var i = 0; i < expected.length; i++) {
    final date = sorted[i].date;
    if (DateTime(date.year, date.month, date.day) != expected[i]) {
      throw const IncompleteImsakiyeException();
    }
  }
  return List.unmodifiable(sorted);
}
