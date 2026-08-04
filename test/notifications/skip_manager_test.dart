import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/skipped_occurrence.dart';
import 'package:ezanvakti/features/alarms/domain/alarm_scheduler.dart';
import 'package:ezanvakti/features/notifications/domain/skip_rules.dart';
import 'package:ezanvakti/features/notifications/domain/skip_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  final now = DateTime(2026, 8, 5, 12);
  final future = SkippedOccurrence(
    kind: SkipKind.alarm,
    reference: 'sahur',
    fireAt: DateTime(2026, 8, 5, 13),
  );
  final past = SkippedOccurrence(
    kind: SkipKind.notification,
    reference: 'eski',
    fireAt: DateTime(2026, 8, 5, 11),
  );

  SkipManager build(FakeStorage storage) =>
      SkipManager(storage: storage, clock: () => now);

  test('skip yazar, load geri getirir', () async {
    final storage = FakeStorage();
    final manager = build(storage);

    final afterSkip = await manager.skip(future);

    expect(afterSkip, {future});
    expect(await manager.load(), {future});
  });

  test('unskip kaydi siler', () async {
    final storage = FakeStorage();
    final manager = build(storage);
    await manager.skip(future);

    final afterUnskip = await manager.unskip(future);

    expect(afterUnskip, isEmpty);
    expect(await manager.load(), isEmpty);
  });

  test('load suresi gecmis kaydi eler ve depoyu temizler', () async {
    final storage = FakeStorage();
    await storage.saveSkippedOccurrences([past, future]);
    final manager = build(storage);

    expect(await manager.load(), {future});
    // Temizlik depoya da yazilir; yoksa liste zamanla sismeye devam eder.
    expect(await storage.getSkippedOccurrences(), [future]);
  });

  test('Ayni kayit iki kez atlanirsa tek kayit kalir', () async {
    final storage = FakeStorage();
    final manager = build(storage);

    await manager.skip(future);
    final result = await manager.skip(future);

    expect(result, hasLength(1));
  });

  test('Saat kayarsa alarm planlanir VE anahtar acik gorunur', () {
    // Spec degismez kurali: kart ve planlayici ayni sorguyu kullandigi icin
    // ayrisamazlar. Ikisi tek testte birlikte kontrol edilir ki ileride biri
    // degisirse digeri de dussun.
    const alarm = Alarm(
      id: 'sahur',
      kind: AlarmKind.fixed,
      label: 'Sahur',
      hour: 6,
      minute: 30,
    );
    final staleSkip = SkippedOccurrence(
      kind: SkipKind.alarm,
      reference: 'sahur',
      fireAt: DateTime(2026, 8, 6, 6, 25), // eski saat
    );
    final actualFire = DateTime(2026, 8, 6, 6, 30); // vakit kaydi

    // Planlayici: kayit eslesmedigi icin alarmi planlar.
    final fire = AlarmScheduler.computeNextFire(
      alarm: alarm,
      now: DateTime(2026, 8, 5, 7),
      prayerTimesByDate: const {},
      skips: {staleSkip},
    );
    expect(fire, actualFire);

    // Kart: ayni sorgu atlanmis demiyor, yani anahtar acik cizilir.
    expect(
      isSkipped(
        {staleSkip},
        kind: SkipKind.alarm,
        reference: 'sahur',
        fireAt: actualFire,
      ),
      isFalse,
    );
  });
}
