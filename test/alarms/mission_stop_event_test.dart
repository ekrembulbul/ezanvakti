import 'package:ezanvakti/core/models/mission_stop_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromMap chainStopped bayragini okur, yoksa false', () {
    final flagged = MissionStopEvent.fromMap({
      'alarmId': 'a',
      'stoppedAt': 1000,
      'chainStopped': true,
    });
    final plain = MissionStopEvent.fromMap({'alarmId': 'a', 'stoppedAt': 1000});
    expect(flagged.chainStopped, isTrue);
    expect(plain.chainStopped, isFalse);
  });
}
