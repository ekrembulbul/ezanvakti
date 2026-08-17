import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final firedAt = DateTime(2026, 8, 17, 5, 0);

  group('MissionSession', () {
    test('Varsayilan sayaclar sifir', () {
      final s = MissionSession(alarmId: 'a', firedAt: firedAt);
      expect(s.snoozeUsed, 0);
      expect(s.rearmCount, 0);
      expect(s.completedAt, isNull);
      expect(s.isPending, isTrue);
    });

    test('completedAt dolunca beklemede degil', () {
      final s = MissionSession(
        alarmId: 'a',
        firedAt: firedAt,
        completedAt: firedAt,
      );
      expect(s.isPending, isFalse);
    });

    test('toJson/fromJson degerleri korur', () {
      final s = MissionSession(
        alarmId: 'sahur',
        firedAt: firedAt,
        snoozeUsed: 2,
        rearmCount: 7,
        completedAt: firedAt.add(const Duration(minutes: 3)),
      );
      final round = MissionSession.fromJson(s.toJson());
      expect(round.alarmId, 'sahur');
      expect(round.firedAt, firedAt);
      expect(round.snoozeUsed, 2);
      expect(round.rearmCount, 7);
      expect(round.completedAt, firedAt.add(const Duration(minutes: 3)));
    });

    test('copyWith yalnizca verileni degistirir', () {
      final s = MissionSession(alarmId: 'a', firedAt: firedAt, snoozeUsed: 1);
      final n = s.copyWith(snoozeUsed: 2);
      expect(n.snoozeUsed, 2);
      expect(n.alarmId, 'a');
      expect(n.firedAt, firedAt);
    });
  });
}
