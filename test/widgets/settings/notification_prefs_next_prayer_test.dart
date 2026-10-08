import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/interfaces/widget_publisher.dart';
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot.dart';
import 'package:ezanvakti/presentation/widgets/settings/notification_prefs_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

class _RecordingPublisher implements WidgetPublisher {
  final published = <bool>[];

  @override
  Future<void> publishNextPrayerNotification(bool enabled) async =>
      published.add(enabled);

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {}

  @override
  Future<void> publishAppearance(AppearanceSettings settings) async {}

  @override
  Future<void> publishTimeFormat(String storageValue) async {}
}

/// Ayarlar → Bildirim ve ses: "Bildirim çubuğunda sıradaki vakit" (Android).
void main() {
  late FakeStorage storage;
  late _RecordingPublisher publisher;

  setUp(() {
    storage = FakeStorage();
    publisher = _RecordingPublisher();
    ServiceLocator().register<LocalStorage>(storage);
    ServiceLocator().register<WidgetPublisher>(publisher);
  });

  Future<AppState> pump(WidgetTester tester, {required bool show}) async {
    final appState = AppState();
    await tester.pumpWidget(
      wrapWithTheme(
        SingleChildScrollView(
          child: NotificationPrefsSection(
            showAlarmRingLimit: false,
            showNextPrayerNotification: show,
          ),
        ),
        appState: appState,
      ),
    );
    await tester.pump();
    return appState;
  }

  testWidgets('Android: anahtar açık gelir', (tester) async {
    await pump(tester, show: true);

    expect(find.text('Bildirim çubuğunda sıradaki vakit'), findsOneWidget);
    final row = find.ancestor(
      of: find.text('Bildirim çubuğunda sıradaki vakit'),
      matching: find.byType(Row),
    );
    final toggle = tester.widget<Switch>(
      find.descendant(of: row.first, matching: find.byType(Switch)),
    );
    expect(toggle.value, isTrue);
  });

  testWidgets('Android dışında satır yok', (tester) async {
    await pump(tester, show: false);
    expect(find.text('Bildirim çubuğunda sıradaki vakit'), findsNothing);
  });

  testWidgets('kapatınca depoya yazılır ve widget tarafına yayınlanır', (
    tester,
  ) async {
    final appState = await pump(tester, show: true);
    final row = find.ancestor(
      of: find.text('Bildirim çubuğunda sıradaki vakit'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: row.first, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(appState.generalSettings.nextPrayerNotification, isFalse);
    expect(
      (await storage.getGeneralSettings()).nextPrayerNotification,
      isFalse,
    );
    expect(publisher.published, [false]);
  });
}
