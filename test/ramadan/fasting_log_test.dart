import 'package:ezanvakti/core/models/fasting_log.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test('dokunus dongusu: bos -> tuttum -> kaza -> muaf -> bos', () {
    expect(nextFastingStatus(null), FastingStatus.fasted);
    expect(nextFastingStatus(FastingStatus.fasted), FastingStatus.missed);
    expect(nextFastingStatus(FastingStatus.missed), FastingStatus.exempt);
    expect(nextFastingStatus(FastingStatus.exempt), isNull);
  });

  test('depolama degerleri kararli', () {
    for (final status in FastingStatus.values) {
      expect(FastingStatusX.fromStorage(status.storageValue), status);
    }
    expect(FastingStatusX.fromStorage(null), isNull);
    expect(FastingStatusX.fromStorage('bilinmeyen'), isNull);
  });

  test('anahtar gun icindeki saatten bagimsiz', () {
    expect(
      fastingLogKey(DateTime(2027, 2, 8)),
      fastingLogKey(DateTime(2027, 2, 8, 23, 59)),
    );
    expect(fastingLogKey(DateTime(2027, 2, 8)), '2027-02-08');
  });

  test('depoya yazilip okunur, silinebilir', () async {
    final storage = FakeStorage();
    final day = DateTime(2027, 2, 10);

    await storage.setFastingLog(day, FastingStatus.fasted);
    var log = await storage.getFastingLog(day, day);
    expect(log[fastingLogKey(day)], FastingStatus.fasted);

    await storage.setFastingLog(day, null);
    log = await storage.getFastingLog(day, day);
    expect(log, isEmpty);
  });

  test('kaza orucu sayaci saklanir', () async {
    final storage = FakeStorage();
    expect(await storage.getFastingQadaCount(), 0);
    await storage.setFastingQadaCount(5);
    expect(await storage.getFastingQadaCount(), 5);
  });
}
