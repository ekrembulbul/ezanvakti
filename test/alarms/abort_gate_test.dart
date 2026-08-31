import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/core/models/abort_state.dart';
import 'package:ezanvakti/features/alarms/domain/abort_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 17, 5, 0);

  group('Kademe yukselmesi', () {
    test('Her kullanimda bir artar', () {
      var s = const AbortState();
      s = AbortGate.escalate(state: s, now: now);
      expect(s.level, 1);
      s = AbortGate.escalate(state: s, now: now);
      expect(s.level, 2);
    });

    test('Tavanda durur', () {
      var s = AbortState(level: MissionTuning.abortMaxLevel, lastUsedAt: now);
      s = AbortGate.escalate(state: s, now: now);
      expect(s.level, MissionTuning.abortMaxLevel);
    });

    test('Kullanim zamani kaydedilir', () {
      final s = AbortGate.escalate(state: const AbortState(), now: now);
      expect(s.lastUsedAt, now);
    });
  });

  group('Gerileme', () {
    test('Decay suresi gecmeden gerilemez', () {
      final s = AbortState(level: 2, lastUsedAt: now);
      final soon = now.add(Duration(days: MissionTuning.abortDecayDays - 1));
      expect(AbortGate.effectiveLevel(state: s, now: soon), 2);
    });

    test('Her decay periyodunda bir kademe iner', () {
      final s = AbortState(level: 3, lastUsedAt: now);
      final oneStep = now.add(Duration(days: MissionTuning.abortDecayDays));
      final twoSteps = now.add(
        Duration(days: MissionTuning.abortDecayDays * 2),
      );
      expect(AbortGate.effectiveLevel(state: s, now: oneStep), 2);
      expect(AbortGate.effectiveLevel(state: s, now: twoSteps), 1);
    });

    test('Sifirin altina inmez', () {
      final s = AbortState(level: 1, lastUsedAt: now);
      final muchLater = now.add(
        Duration(days: MissionTuning.abortDecayDays * 20),
      );
      expect(AbortGate.effectiveLevel(state: s, now: muchLater), 0);
    });

    test('Hic kullanilmamissa kademe sifir', () {
      expect(AbortGate.effectiveLevel(state: const AbortState(), now: now), 0);
    });
  });

  group('Kademe gereksinimleri', () {
    test('Seviye 0 yalnizca basili tutma ister', () {
      final r = AbortGate.requirementFor(0);
      expect(r.requiresPhrase, isFalse);
      expect(r.countdownSeconds, 0);
    });

    test('Seviye 1 cumle ister, geri sayim istemez', () {
      final r = AbortGate.requirementFor(1);
      expect(r.requiresPhrase, isTrue);
      expect(r.phrase, isNotNull);
      expect(r.countdownSeconds, 0);
    });

    test('Seviye 2 daha uzun cumle ister', () {
      expect(AbortGate.requirementFor(1).phrase, AbortPhrase.short);
      expect(AbortGate.requirementFor(2).phrase, AbortPhrase.long);
    });

    test('Tavan seviyesi geri sayim ekler', () {
      final r = AbortGate.requirementFor(MissionTuning.abortMaxLevel);
      expect(r.requiresPhrase, isTrue);
      expect(r.countdownSeconds, greaterThan(0));
    });

    test('Tavan ustu seviye tavana kirpilir, cikis kapanmaz', () {
      final r = AbortGate.requirementFor(MissionTuning.abortMaxLevel + 5);
      expect(r, AbortGate.requirementFor(MissionTuning.abortMaxLevel));
    });

    test('isAtCeiling tavanda dogru', () {
      expect(AbortGate.isAtCeiling(MissionTuning.abortMaxLevel), isTrue);
      expect(AbortGate.isAtCeiling(0), isFalse);
    });
  });

  group('Cumle dogrulama', () {
    test('Birebir yazim gecer', () {
      expect(
        AbortGate.phraseMatches(
          expected: 'alarmı kapatıyorum',
          typed: 'alarmı kapatıyorum',
        ),
        isTrue,
      );
    });

    test('Bastaki/sondaki bosluk ve fazla bosluk affedilir', () {
      expect(
        AbortGate.phraseMatches(
          expected: 'alarmı kapatıyorum',
          typed: '  alarmı   kapatıyorum ',
        ),
        isTrue,
      );
    });

    test('Turkce buyuk harf dogru kucultulur', () {
      // Dart'in toLowerCase'i 'I' -> 'i' yapar; Turkce'de 'I' -> 'ı'.
      expect(
        AbortGate.phraseMatches(
          expected: 'alarmı kapatıyorum',
          typed: 'ALARMI KAPATIYORUM',
        ),
        isTrue,
      );
    });

    test('Yanlis metin gecmez', () {
      expect(
        AbortGate.phraseMatches(expected: 'alarmı kapatıyorum', typed: 'alarm'),
        isFalse,
      );
    });
  });

  group('AbortState serilestirme', () {
    test('toJson/fromJson degerleri korur', () {
      final s = AbortState(level: 2, lastUsedAt: now);
      final round = AbortState.fromJson(s.toJson());
      expect(round.level, 2);
      expect(round.lastUsedAt, now);
    });

    test('Bozuk kayit varsayilana duser', () {
      final s = AbortState.fromJson({'level': 'abc', 'last_used_at': 'xyz'});
      expect(s.level, 0);
      expect(s.lastUsedAt, isNull);
    });
  });
}
