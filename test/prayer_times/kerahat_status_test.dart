import 'package:ezanvakti/features/prayer_times/domain/kerahat_status.dart';
import 'package:ezanvakti/features/prayer_times/domain/kerahat_times.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int hour, int minute) => DateTime(2026, 9, 10, hour, minute);

  final intervals = [
    KerahatInterval(
      kind: KerahatKind.afterSunrise,
      start: at(5, 52),
      end: at(6, 37),
    ),
    KerahatInterval(
      kind: KerahatKind.beforeDhuhr,
      start: at(13, 5),
      end: at(13, 15),
    ),
    KerahatInterval(
      kind: KerahatKind.beforeMaghrib,
      start: at(19, 41),
      end: at(20, 26),
    ),
  ];

  group('KerahatWarning.resolve', () {
    test('esik 30 dakika', () {
      expect(KerahatWarning.lead, const Duration(minutes: 30));
    });

    test('aralik icinde aktif', () {
      final status = KerahatWarning.resolve(intervals, at(19, 50));
      expect(status, isA<KerahatActive>());
      expect(status!.interval.kind, KerahatKind.beforeMaghrib);
    });

    test('baslangictan 20 dakika once yaklasiyor', () {
      final status = KerahatWarning.resolve(intervals, at(19, 21));
      expect(status, isA<KerahatApproaching>());
      expect(status!.interval.start, at(19, 41));
    });

    test('tam esikte yaklasiyor, bir dakika otesinde degil', () {
      expect(
        KerahatWarning.resolve(intervals, at(19, 11)),
        isA<KerahatApproaching>(),
      );
      expect(KerahatWarning.resolve(intervals, at(19, 10)), isNull);
    });

    test('bitisten sonra ve araliklar arasinda bos', () {
      expect(KerahatWarning.resolve(intervals, at(6, 37)), isNull);
      expect(KerahatWarning.resolve(intervals, at(10, 0)), isNull);
      expect(KerahatWarning.resolve(intervals, at(21, 0)), isNull);
    });

    test('baslangic ani aktif sayilir', () {
      expect(
        KerahatWarning.resolve(intervals, at(13, 5)),
        isA<KerahatActive>(),
      );
    });

    test('bos listede bos', () {
      expect(KerahatWarning.resolve(const [], at(19, 21)), isNull);
    });
  });
}
