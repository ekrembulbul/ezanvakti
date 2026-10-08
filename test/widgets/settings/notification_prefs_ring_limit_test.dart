import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/presentation/widgets/settings/notification_prefs_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

/// Ayarlar → Bildirim ve ses: "Alarm şu kadar sonra sussun" (yalnız Android).
void main() {
  late FakeStorage storage;

  setUp(() {
    storage = FakeStorage();
    ServiceLocator().register<LocalStorage>(storage);
  });

  Future<AppState> pump(
    WidgetTester tester, {
    required bool showAlarmRingLimit,
    Future<void> Function()? onChanged,
  }) async {
    final appState = AppState();
    await tester.pumpWidget(
      wrapWithTheme(
        SingleChildScrollView(
          child: NotificationPrefsSection(
            showAlarmRingLimit: showAlarmRingLimit,
            onChanged: onChanged,
          ),
        ),
        appState: appState,
      ),
    );
    await tester.pump();
    return appState;
  }

  testWidgets('Android: satir ve varsayilan "10 dk" gorunur', (tester) async {
    await pump(tester, showAlarmRingLimit: true);

    expect(find.text('Alarm şu kadar sonra sussun'), findsOneWidget);
    expect(find.text('10 dk'), findsOneWidget);
    expect(
      find.text(
        'Kapatılmayan alarm bu süre sonra ertelenir; erteleme hakkı yoksa '
        'susar.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Android disinda satir cizilmez', (tester) async {
    await pump(tester, showAlarmRingLimit: false);

    expect(find.text('Alarm şu kadar sonra sussun'), findsNothing);
    expect(find.text('10 dk'), findsNothing);
  });

  testWidgets('Secim depoya yazilir ve yeniden planlama tetiklenir', (
    tester,
  ) async {
    var changed = 0;
    final appState = await pump(
      tester,
      showAlarmRingLimit: true,
      onChanged: () async => changed++,
    );

    await tester.tap(find.text('Alarm şu kadar sonra sussun'));
    await tester.pumpAndSettle();
    expect(find.text('Sınırsız'), findsOneWidget);
    await tester.tap(find.text('30 dk'));
    await tester.pumpAndSettle();

    expect(appState.generalSettings.alarmRingLimitMinutes, 30);
    expect((await storage.getGeneralSettings()).alarmRingLimitMinutes, 30);
    expect(changed, 1);
    expect(find.text('30 dk'), findsOneWidget);
  });
}
