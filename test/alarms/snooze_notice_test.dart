import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/core/models/mission_session.dart';
import 'package:ezanvakti/presentation/widgets/reminders/snooze_notice.dart';
import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/l10n_helper.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async => l10n = await loadTestL10n());

  final firedAt = DateTime(2026, 8, 18, 5, 0);
  final until = DateTime(2026, 8, 18, 5, 10);

  const gated = Alarm(
    id: 'sahur',
    kind: AlarmKind.fixed,
    mission: AlarmMission.math,
  );
  const plain = Alarm(id: 'ogle', kind: AlarmKind.fixed);

  MissionSession session({
    String alarmId = 'sahur',
    DateTime? snoozedUntil,
    DateTime? completedAt,
  }) => MissionSession(
    alarmId: alarmId,
    firedAt: firedAt,
    snoozedUntil: snoozedUntil,
    completedAt: completedAt,
  );

  group('snoozedUntilFor', () {
    test('Oturum yoksa ertelenmis degil', () {
      expect(SnoozeNotice.snoozedUntilFor(null, gated), isNull);
    });

    test('Baska alarmin oturumu bu alarmi ertelemis saymaz', () {
      expect(
        SnoozeNotice.snoozedUntilFor(
          session(alarmId: 'baska', snoozedUntil: until),
          gated,
        ),
        isNull,
      );
    });

    test('Kapanmis oturum ertelenmis saymaz', () {
      expect(
        SnoozeNotice.snoozedUntilFor(
          session(snoozedUntil: until, completedAt: firedAt),
          gated,
        ),
        isNull,
      );
    });

    test('Ertelenmis oturumda saat doner', () {
      expect(
        SnoozeNotice.snoozedUntilFor(session(snoozedUntil: until), gated),
        until,
      );
    });
  });

  group('canDisable', () {
    test('Gorevsiz alarm her zaman kapatilabilir', () {
      expect(
        SnoozeNotice.canDisable(session(alarmId: 'ogle', snoozedUntil: until), plain),
        isTrue,
      );
    });

    test('Ertelenmis gorevli alarm kapatilamaz', () {
      expect(
        SnoozeNotice.canDisable(session(snoozedUntil: until), gated),
        isFalse,
      );
    });

    test('Ertelenmemis gorevli alarm kapatilabilir', () {
      expect(SnoozeNotice.canDisable(session(), gated), isTrue);
    });
  });

  group('label', () {
    test('Saat HH:mm bicimiyle yazilir', () {
      expect(SnoozeNotice.label(until, l10n), contains('05:10'));
    });
  });
}
