import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/data/ramadan_periods.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/features/location/domain/location_repository.dart';
import 'package:ezanvakti/features/location/domain/location_service.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:ezanvakti/features/ramadan/domain/imsakiye_repository.dart';
import '../support/fakes.dart';

const gps = Location(
  id: 'saved-gps',
  province: 'İstanbul',
  district: 'Fatih',
  latitude: 41,
  longitude: 29,
  type: LocationType.gps,
);

class CoordinateProvider extends FakeProvider {
  Location? requested;
  @override
  Future<List<PrayerTime>> fetchPrayerTimes({
    required Location location,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    requested = location;
    return super.fetchPrayerTimes(
      location: location,
      startDate: startDate,
      endDate: endDate,
    );
  }
}

void main() {
  test(
    'GPS update invalidates entire future month using saved id; unchanged input keeps cache',
    () async {
      final storage = FakeStorage();
      final provider = CoordinateProvider();
      final prayers = PrayerTimesRepository(
        provider: provider,
        storage: storage,
      );
      final cleared = <String>[];
      final locations = LocationRepository(
        storage: storage,
        clearPrayerCache: (id) async {
          cleared.add(id);
          await prayers.clearCacheForLocation(id);
        },
      );
      final imsakiye = ImsakiyeRepository(prayers);
      await locations.saveOrUpdateGpsLocation(gps);
      await imsakiye.load(location: gps, period: ramadanPeriods[3]);
      await locations.saveOrUpdateGpsLocation(gps.copyWith(id: 'incoming-id'));
      expect(cleared, isEmpty);
      final changed = await locations.saveOrUpdateGpsLocation(
        gps.copyWith(id: 'another-incoming', latitude: 39, longitude: 32),
      );
      expect(cleared, [gps.id]);
      expect(changed.id, gps.id);
      expect(
        await storage.getPrayerTimes(
          locationId: gps.id,
          startDate: ramadanPeriods[3].start,
          endDate: ramadanPeriods[3].lastDay,
        ),
        isEmpty,
      );
      await imsakiye.load(location: changed, period: ramadanPeriods[3]);
      expect(provider.requested!.latitude, 39);
      expect(provider.requested!.longitude, 32);
      expect(provider.fetchCount, 2);
    },
  );
  test('same-id new coordinates are persisted as active location', () async {
    final storage = FakeStorage();
    final locations = LocationRepository(storage: storage);
    await locations.setActiveLocation(gps);
    final service = LocationService(
      locationRepository: locations,
      prayerTimesRepository: PrayerTimesRepository(
        provider: FakeProvider(),
        storage: storage,
      ),
    );
    final changed = gps.copyWith(latitude: 39);
    await service.changeLocation(changed);
    expect(await locations.getActiveLocation(), changed);
  });
}
