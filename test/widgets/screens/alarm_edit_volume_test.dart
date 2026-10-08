import 'package:ezanvakti/core/di/service_locator.dart';
import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/presentation/screens/alarm_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../theme_harness.dart';

/// Alarm başına ses seviyesi: yalnız Android'de (iOS'ta AlarmKit seviye
/// vermiyor, yerine "Zil Sesi ve Uyarılar" notu kalır).
void main() {
  const usePhone = 'Telefonun alarm ses seviyesi';
  const iosNote = 'Alarm, Zil Sesi ve Uyarılar ses seviyesiyle çalar.';
  const saved = Alarm(id: '1', kind: AlarmKind.fixed, hour: 6, minute: 30);

  setUp(() {
    ServiceLocator().register<LocalStorage>(FakeStorage());
  });

  Finder form() => find
      .descendant(
        of: find.byType(AlarmEditScreen),
        matching: find.byType(Scrollable),
      )
      .first;

  /// Ekranı bir rota olarak açar; kaydedilen alarm [onResult]'a düşer.
  Future<void> open(
    WidgetTester tester, {
    Alarm? alarm,
    required bool volumeSupported,
    ValueChanged<Alarm?>? onResult,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute<Alarm>(
                  builder: (_) => AlarmEditScreen(
                    alarm: alarm,
                    fadeInSupported: false,
                    volumeSupported: volumeSupported,
                  ),
                ),
              );
              onResult?.call(result);
            },
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('Desteklenmeyen platformda not var, ses anahtari yok', (
    tester,
  ) async {
    await open(tester, volumeSupported: false);
    await tester.scrollUntilVisible(
      find.text(iosNote),
      200,
      scrollable: form(),
    );

    expect(find.text(iosNote), findsOneWidget);
    expect(find.text(usePhone), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('Android: varsayilan telefonun seviyesi, kaydirici yok', (
    tester,
  ) async {
    await open(tester, volumeSupported: true);
    await tester.scrollUntilVisible(
      find.text(usePhone),
      200,
      scrollable: form(),
    );

    expect(find.text(iosNote), findsNothing);
    final tile = find.widgetWithText(SwitchListTile, usePhone);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    expect(find.byType(Slider), findsNothing);
    expect(
      find.text('Alarm çalarken ses tuşları sesi değiştirmez.'),
      findsOneWidget,
    );
  });

  testWidgets('Anahtar kapatilinca kaydirici gelir, kayitta volume 80', (
    tester,
  ) async {
    Alarm? result;
    await open(
      tester,
      alarm: saved,
      volumeSupported: true,
      onResult: (alarm) => result = alarm,
    );
    await tester.scrollUntilVisible(
      find.text(usePhone),
      200,
      scrollable: form(),
    );
    await tester.tap(find.text(usePhone));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('%80'), findsOneWidget);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.volume, 80);
  });

  testWidgets('Kayitli seviye kaydiricida gorunur', (tester) async {
    await open(
      tester,
      alarm: saved.copyWith(volume: 40),
      volumeSupported: true,
    );
    await tester.scrollUntilVisible(
      find.text(usePhone),
      200,
      scrollable: form(),
    );

    final tile = find.widgetWithText(SwitchListTile, usePhone);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 40);
    expect(find.text('%40'), findsOneWidget);
  });

  testWidgets('Desteklenmeyen platformda kayitli seviye korunur', (
    tester,
  ) async {
    Alarm? result;
    await open(
      tester,
      alarm: saved.copyWith(volume: 60),
      volumeSupported: false,
      onResult: (alarm) => result = alarm,
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(result!.volume, 60);
  });
}
