import 'package:ezanvakti/core/models/skipped_occurrence.dart';
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
}
