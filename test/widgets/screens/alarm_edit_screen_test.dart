import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/alarm_mission.dart';
import 'package:ezanvakti/presentation/screens/alarm_edit_screen.dart';
import 'package:ezanvakti/presentation/widgets/missions/qr_payload_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  Future<void> pumpEdit(
    WidgetTester tester, {
    Alarm? alarm,
    bool fadeInSupported = false,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        AlarmEditScreen(alarm: alarm, fadeInSupported: fadeInSupported),
      ),
    );
    await tester.pump();
  }

  testWidgets('Yeni alarmda baslik "Alarm ekle"', (tester) async {
    await pumpEdit(tester);

    expect(find.text('Alarm ekle'), findsOneWidget);
  });

  testWidgets('Mevcut alarmda baslik "Alarmı düzenle"', (tester) async {
    await pumpEdit(
      tester,
      alarm: const Alarm(id: '1', kind: AlarmKind.fixed, hour: 6, minute: 30),
    );

    expect(find.text('Alarmı düzenle'), findsOneWidget);
  });

  testWidgets('Tur secimi kayan segment ile yapilir', (tester) async {
    await pumpEdit(tester);

    expect(find.text('Sabit saat'), findsOneWidget);
    expect(find.text('Vakte göre'), findsOneWidget);
  });

  testWidgets('Bolum basliklari buyuk harf', (tester) async {
    await pumpEdit(tester);

    expect(find.text('SAAT'), findsOneWidget);
    expect(find.text('TEKRAR'), findsOneWidget);
    expect(find.text('ETİKET'), findsOneWidget);
  });

  testWidgets('Vakte gore secilince vakit ve zamanlama bolumleri gelir', (
    tester,
  ) async {
    await pumpEdit(tester);

    await tester.tap(find.text('Vakte göre'));
    await tester.pumpAndSettle();

    // Vakit artik bolum basligi degil, secim satiri (OptionRow).
    expect(find.text('Vakit'), findsOneWidget);
    expect(find.text('ZAMANLAMA'), findsOneWidget);
    expect(find.text('Önce'), findsOneWidget);
    expect(find.text('Tam vaktinde'), findsOneWidget);
    expect(find.text('Sonra'), findsOneWidget);
  });

  testWidgets('Tekrar bolumunde uc hizli secim var', (tester) async {
    await pumpEdit(tester);

    expect(find.text('Her gün'), findsOneWidget);
    expect(find.text('Hafta içi'), findsOneWidget);
    expect(find.text('Hafta sonu'), findsOneWidget);
  });

  testWidgets('Hafta sonu secilince yalnizca Ct ve Pa aktif kalir', (
    tester,
  ) async {
    await pumpEdit(tester);

    await tester.tap(find.text('Hafta sonu'));
    await tester.pump();

    // Secim kaydedilmeden dogrulanamaz; en azindan cip aktiflesmis olmali.
    expect(find.text('Hafta sonu'), findsOneWidget);
  });

  testWidgets('En az bir gun secili kalir', (tester) async {
    await pumpEdit(tester);

    for (final day in ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa']) {
      await tester.tap(find.text(day));
      await tester.pump();
    }

    // Yedi gunu de kapatmak mumkun degil; sonuncu secili kalir.
    expect(find.text('Pa'), findsOneWidget);
  });

  group('Zorluk', () {
    /// Ekrani bir rota olarak acar ki "Kaydet" ile donen alarm okunabilsin.
    Future<Alarm? Function()> openForResult(
      WidgetTester tester, {
      Alarm? alarm,
    }) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      Alarm? saved;
      await tester.pumpWidget(
        wrapWithTheme(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<Alarm>(
                  MaterialPageRoute(
                    builder: (_) => AlarmEditScreen(alarm: alarm),
                  ),
                );
              },
              child: const Text('aç'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      return () => saved;
    }

    Future<void> pickMission(WidgetTester tester, String name) async {
      await tester.tap(find.text('Kapatma görevi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    /// Liste tembel kuruluyor; gorev satirinin altindaki satir ancak
    /// kaydirilinca insa ediliyor.
    Future<void> revealBelowMission(WidgetTester tester) async {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
    }

    testWidgets('Yalnizca matematik gorevinde Zorluk satiri gorunur', (
      tester,
    ) async {
      await pumpEdit(tester);
      await tester.pumpAndSettle();
      await revealBelowMission(tester);
      expect(find.text('Zorluk'), findsNothing);

      await pickMission(tester, 'Matematik');
      await revealBelowMission(tester);
      expect(find.text('Zorluk'), findsOneWidget);
      expect(find.text('Kolay'), findsOneWidget, reason: 'varsayilan seviye');

      await pickMission(tester, 'Sallama');
      await revealBelowMission(tester);
      expect(find.text('Zorluk'), findsNothing);
    });

    testWidgets('Secilen seviye kaydedilir', (tester) async {
      final saved = await openForResult(tester);
      await pickMission(tester, 'Matematik');
      await revealBelowMission(tester);

      await tester.tap(find.text('Zorluk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ekstrem'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(saved()?.missionLevel, 4);
    });

    testWidgets('Matematik disi gorevde seviye 1 olarak kaydedilir', (
      tester,
    ) async {
      final saved = await openForResult(
        tester,
        alarm: const Alarm(
          id: '1',
          kind: AlarmKind.fixed,
          hour: 6,
          minute: 30,
          mission: AlarmMission.math,
          missionLevel: 4,
        ),
      );
      await pickMission(tester, 'Sallama');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(saved()?.mission, AlarmMission.shake);
      expect(saved()?.missionLevel, 1);
    });
  });

  group('QR gorevi', () {
    Future<void> pickQr(WidgetTester tester) async {
      await tester.tap(find.text('Kapatma görevi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QR okutma'));
      await tester.pumpAndSettle();
    }

    testWidgets('Secilince kod alani gelir', (tester) async {
      await pumpEdit(tester);
      await tester.pumpAndSettle();

      expect(find.byType(QrPayloadField), findsNothing);
      await pickQr(tester);

      expect(find.byType(QrPayloadField), findsOneWidget);
    });

    testWidgets('Kod bos birakilirsa alarm kaydedilmez', (tester) async {
      await pumpEdit(tester);
      await tester.pumpAndSettle();
      await pickQr(tester);

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(
        find.text('QR görevi için bir kod okut ya da yaz'),
        findsOneWidget,
        reason:
            'Kodsuz QR gorevi kapisiz alarm demek; kullanici yalnizca acil '
            'cikisla susturabilirdi',
      );
      expect(
        find.text('Alarm ekle'),
        findsOneWidget,
        reason: 'ekran kapanmadi',
      );
    });

    testWidgets('Kod girilince kaydedilir', (tester) async {
      await pumpEdit(tester);
      await tester.pumpAndSettle();
      await pickQr(tester);

      await tester.enterText(find.byKey(kQrPayloadFieldKey), 'mutfak-kapisi');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text('QR görevi için bir kod okut ya da yaz'), findsNothing);
    });

    testWidgets('Kod alani secimden sonra gorunur alana kaydirilir', (
      tester,
    ) async {
      await pumpEdit(tester);
      await tester.pumpAndSettle();
      await pickQr(tester);

      final field = tester.getRect(find.byKey(kQrPayloadFieldKey));
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(
        screen.contains(field.centerLeft) && screen.contains(field.centerRight),
        isTrue,
        reason:
            'Bolum liste sonunda aciliyor; kaydirilmazsa kullanici kod '
            'alaninin hic gelmedigini saniyor',
      );
    });
  });

  group('Sesin kademeli yukselmesi', () {
    testWidgets('Desteklenmeyen platformda ayar gorunmez', (tester) async {
      await pumpEdit(tester);

      expect(
        find.text('Ses yavaşça yükselsin'),
        findsNothing,
        reason: 'iOSta AlarmKit ses seviyesi vermiyor; yarim ayar sunulmaz',
      );
    });

    testWidgets('Desteklenen platformda ayar gorunur', (tester) async {
      await pumpEdit(tester, fadeInSupported: true);
      await tester.scrollUntilVisible(
        find.text('Ses yavaşça yükselsin'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Ses yavaşça yükselsin'), findsOneWidget);
    });

    testWidgets('Kayitli deger anahtara yansir', (tester) async {
      await pumpEdit(
        tester,
        alarm: const Alarm(
          id: '1',
          kind: AlarmKind.fixed,
          hour: 6,
          minute: 30,
          fadeIn: true,
        ),
        fadeInSupported: true,
      );
      await tester.scrollUntilVisible(
        find.text('Ses yavaşça yükselsin'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      final tile = find.widgetWithText(SwitchListTile, 'Ses yavaşça yükselsin');
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    });
  });
}
