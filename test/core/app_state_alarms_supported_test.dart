import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alarm destegi varsayilan acik; kapatinca dinleyiciler uyarilir', () {
    final state = AppState();
    var notified = 0;
    state.addListener(() => notified++);

    expect(state.alarmsSupported, isTrue);
    state.setAlarmsSupported(false);

    expect(state.alarmsSupported, isFalse);
    expect(notified, 1);
  });
}
