import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/data/ramadan_periods.dart';
import 'package:ezanvakti/core/models/calculation_settings.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/features/prayer_times/domain/prayer_times_repository.dart';
import 'package:ezanvakti/features/ramadan/domain/imsakiye_repository.dart';
import 'package:ezanvakti/presentation/controllers/imsakiye_controller.dart';
import '../support/fakes.dart';

const location = Location(id: 'test', province: 'İstanbul', district: 'Fatih');
void main() {
  test('validation sorts dates but rejects duplicates and missing days', () {
    final period = ramadanPeriods.first;
    final days = period.days.map(prayerTimeFor).toList();
    expect(
      validateImsakiye(days.reversed.toList(), period).first.date,
      period.start,
    );
    expect(
      () => validateImsakiye(days.sublist(1), period),
      throwsA(isA<IncompleteImsakiyeException>()),
    );
    days[29] = days[28];
    expect(
      () => validateImsakiye(days, period),
      throwsA(isA<IncompleteImsakiyeException>()),
    );
  });
  test(
    'period switch hides previous full month and incomplete result cannot share',
    () async {
      final controller = ImsakiyeController(
        loader:
            ({
              required location,
              required period,
              forceRefresh = false,
            }) async => period.hijriYear == 1445
            ? period.days.map(prayerTimeFor).toList()
            : [prayerTimeFor(period.start)],
        period: ramadanPeriods.first,
      );
      await controller.updateSource(location, 0);
      expect(controller.canShare, isTrue);
      final request = controller.selectPeriod(ramadanPeriods[1]);
      expect(controller.days, isEmpty);
      expect(controller.canShare, isFalse);
      await request;
      expect(controller.error, isA<IncompleteImsakiyeException>());
      expect(controller.days, isEmpty);
      controller.dispose();
    },
  );
  test(
    'catalog has verified 29/30 day periods and preserves two starts in 2030',
    () {
      expect(ramadanPeriods.map((p) => p.dayCount), [
        30,
        29,
        29,
        29,
        29,
        29,
        30,
        29,
      ]);
      expect(ramadanPeriods[2].start, DateTime(2026, 2, 19));
      expect(ramadanPeriods[2].lastDay, DateTime(2026, 3, 19));
      expect(ramadanPeriods[3].lastDay, DateTime(2027, 3, 8));
      expect(ramadanPeriods.last.days.last, DateTime(2031, 1, 23));
      expect(
        ramadanPeriods
            .where((p) => p.start.year == 2030)
            .map((p) => p.hijriYear),
        [1451, 1452],
      );
      expect(defaultRamadanPeriod(DateTime(2026, 9, 6)).hijriYear, 1448);
      expect(defaultRamadanPeriod(DateTime(2040)).hijriYear, 1452);
    },
  );
  test(
    'repository uses entire period with existing tune and complete cache fallback',
    () async {
      final storage = FakeStorage();
      final provider = FakeProvider();
      final repository = ImsakiyeRepository(
        PrayerTimesRepository(provider: provider, storage: storage),
      );
      await storage.saveCalculationSettings(
        CalculationSettings.defaults.copyWith(tune: {PrayerType.fajr: 3}),
      );
      final period = ramadanPeriods[2];
      final times = await repository.load(location: location, period: period);
      expect(times.length, 29);
      expect(times.first.fajr.minute, 14);
      provider.failWith = Exception('offline');
      expect(
        (await repository.load(
          location: location,
          period: period,
          forceRefresh: true,
        )).length,
        29,
      );
      await storage.deleteAllPrayerTimes();
      await storage.savePrayerTimes([prayerTimeFor(period.start)], location.id);
      await expectLater(
        repository.load(location: location, period: period),
        throwsA(isA<IncompleteImsakiyeException>()),
      );
    },
  );
  test(
    'controller ignores reversed responses and invalidates same-id location/revision',
    () async {
      final requests = <Completer<List<PrayerTime>>>[];
      final controller = ImsakiyeController(
        loader: ({required location, required period, forceRefresh = false}) {
          final pending = Completer<List<PrayerTime>>();
          requests.add(pending);
          return pending.future;
        },
        period: ramadanPeriods[2],
      );
      final first = controller.updateSource(location, 0);
      final second = controller.updateSource(
        location.copyWith(latitude: 42),
        0,
      );
      requests[1].complete(ramadanPeriods[2].days.map(prayerTimeFor).toList());
      await second;
      requests[0].completeError(Exception('old'));
      await first;
      expect(controller.error, isNull);
      expect(controller.days.length, 29);
      final refresh = controller.refresh();
      requests[2].completeError(Exception('offline'));
      await refresh;
      expect(controller.days.length, 29);
      expect(controller.error, isNotNull);
      final revision = controller.updateSource(
        location.copyWith(latitude: 42),
        1,
      );
      expect(controller.days, isEmpty);
      controller.dispose();
      requests[3].complete(ramadanPeriods[2].days.map(prayerTimeFor).toList());
      await revision;
    },
  );
}
