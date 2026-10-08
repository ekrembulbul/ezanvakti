import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/core/theme/app_theme.dart';
import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:ezanvakti/presentation/widgets/reminders/alarms_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../theme_harness.dart';

/// Android: tam ekran alarm izni ve pil optimizasyonu uyarı bantları.
void main() {
  const fullScreenText =
      'Tam ekran alarm izni kapalı. Alarm kilit ekranında açılmaz, yalnız '
      'bildirim olarak gelir.';
  const batteryText =
      'Bu telefon uygulamayı arka planda uyutup alarmı geciktirebilir. '
      "Ezan Vakti'yi pil optimizasyonundan çıkar.";
  const active = Alarm(id: 'sahur', kind: AlarmKind.fixed, hour: 5, minute: 0);
  const inactive = Alarm(
    id: 'ogle',
    kind: AlarmKind.fixed,
    hour: 13,
    minute: 0,
    isActive: false,
  );

  Widget build({
    List<Alarm> alarms = const [active],
    bool fullScreenAllowed = true,
    VoidCallback? onOpenFullScreenSettings,
    bool showBatteryWarning = false,
    VoidCallback? onOpenBatterySettings,
    VoidCallback? onDismissBatteryWarning,
  }) => wrapWithTheme(
    AlarmsSection(
      alarms: alarms,
      isSupported: true,
      isPermissionGranted: true,
      onRequestPermission: () {},
      onToggle: (a, b) {},
      onEdit: (_) {},
      onDelete: (_) async {},
      fullScreenAllowed: fullScreenAllowed,
      onOpenFullScreenSettings: onOpenFullScreenSettings,
      showBatteryWarning: showBatteryWarning,
      onOpenBatterySettings: onOpenBatterySettings,
      onDismissBatteryWarning: onDismissBatteryWarning,
    ),
  );

  group('Tam ekran izni bandı', () {
    testWidgets('Izin kapali ve acik alarm varken gorunur', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        build(
          fullScreenAllowed: false,
          onOpenFullScreenSettings: () => opened++,
        ),
      );

      expect(find.text(fullScreenText), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Aç'));
      expect(opened, 1);
    });

    testWidgets('Izin acikken cizilmez', (tester) async {
      await tester.pumpWidget(build());

      expect(find.text(fullScreenText), findsNothing);
    });

    testWidgets('Acik alarm yoksa cizilmez', (tester) async {
      await tester.pumpWidget(
        build(alarms: const [inactive], fullScreenAllowed: false),
      );

      expect(find.text(fullScreenText), findsNothing);
    });
  });

  group('Pil uyarısı bandı', () {
    testWidgets('Gorunur, iki dugme var; "Bir daha gosterme" geri cagirir', (
      tester,
    ) async {
      var opened = 0;
      var dismissed = 0;
      await tester.pumpWidget(
        build(
          showBatteryWarning: true,
          onOpenBatterySettings: () => opened++,
          onDismissBatteryWarning: () => dismissed++,
        ),
      );

      expect(find.text(batteryText), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Aç'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Bir daha gösterme'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Bir daha gösterme'));
      expect(dismissed, 1);
      await tester.tap(find.widgetWithText(TextButton, 'Aç'));
      expect(opened, 1);
    });

    testWidgets('Karar kapaliyken cizilmez', (tester) async {
      await tester.pumpWidget(build());

      expect(find.text(batteryText), findsNothing);
      expect(find.text('Bir daha gösterme'), findsNothing);
    });

    testWidgets('Dar ekran ve buyuk metinde tasmaz', (tester) async {
      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // Harness MediaQuery'yi sabitliyor; metin ölçeği için kendi ağacımız.
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: AppState(),
          child: MaterialApp(
            theme: AppTheme.build(tokensFor(), Brightness.dark),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('tr'),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 1400),
                textScaler: TextScaler.linear(1.6),
              ),
              child: Scaffold(
                body: AlarmsSection(
                  alarms: const [],
                  isSupported: true,
                  isPermissionGranted: true,
                  onRequestPermission: () {},
                  onToggle: (a, b) {},
                  onEdit: (_) {},
                  onDelete: (_) async {},
                  showBatteryWarning: true,
                  onOpenBatterySettings: () {},
                  onDismissBatteryWarning: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text(batteryText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
