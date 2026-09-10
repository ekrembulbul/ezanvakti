import 'dart:math';

import 'package:ezanvakti/features/alarms/domain/math_challenge.dart';
import 'package:ezanvakti/presentation/widgets/missions/math_mission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  Future<void> pumpMission(
    WidgetTester tester, {
    int level = 2,
    int seed = 7,
    VoidCallback? onCompleted,
  }) async {
    await tester.pumpWidget(
      wrapWithTheme(
        MathMission(
          level: level,
          random: Random(seed),
          onCompleted: onCompleted ?? () {},
        ),
      ),
    );
    await tester.pump();
  }

  /// Cevabı ekrandaki tuş takımından girer; sistem klavyesi yok.
  Future<void> type(WidgetTester tester, int answer) async {
    for (final ch in '$answer'.split('')) {
      await tester.tap(find.byKey(kMathKey(int.parse(ch))));
      await tester.pump();
    }
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(kMathSubmitKey));
    await tester.pumpAndSettle();
  }

  Finder answerText(String text) => find.descendant(
    of: find.byKey(kMathAnswerKey),
    matching: find.text(text),
  );

  testWidgets('Rakamlar tusla girilir; TextField ve scroll yok', (
    tester,
  ) async {
    await pumpMission(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    for (var digit = 0; digit <= 9; digit++) {
      expect(find.byKey(kMathKey(digit)), findsOneWidget, reason: '$digit');
    }

    await type(tester, 42);
    expect(answerText('42'), findsOneWidget);
  });

  testWidgets('Geri tusu son rakami siler, uzun basinca hepsini', (
    tester,
  ) async {
    await pumpMission(tester);
    await type(tester, 123);

    await tester.tap(find.byKey(kMathBackspaceKey));
    await tester.pump();
    expect(answerText('12'), findsOneWidget);

    await tester.longPress(find.byKey(kMathBackspaceKey));
    await tester.pump();
    expect(answerText('12'), findsNothing);
    expect(answerText('1'), findsNothing);
  });

  testWidgets('Cevap en fazla alti hane alir', (tester) async {
    await pumpMission(tester);
    await type(tester, 1234567);
    expect(answerText('123456'), findsOneWidget);
  });

  testWidgets('Tum sorular dogru cevaplanirsa tamamlanir', (tester) async {
    var done = false;
    final questions = MathChallenge.generate(level: 2, random: Random(7));
    await pumpMission(tester, onCompleted: () => done = true);

    for (final q in questions) {
      await type(tester, q.answer);
      await submit(tester);
    }
    expect(done, isTrue);
  });

  testWidgets('Yanlis cevap ilerletmez, uyari gosterir ve girdiyi temizler', (
    tester,
  ) async {
    var done = false;
    await pumpMission(tester, onCompleted: () => done = true);

    await type(tester, 999999);
    await submit(tester);

    expect(done, isFalse);
    expect(find.textContaining('Yanlış'), findsOneWidget);
    expect(answerText('999999'), findsNothing);
  });

  testWidgets('Bos cevap gonderilemez', (tester) async {
    var done = false;
    await pumpMission(tester, level: 1, onCompleted: () => done = true);
    await submit(tester);
    expect(done, isFalse);
  });

  testWidgets('Ilerleme her soru icin bir nokta cizer', (tester) async {
    await pumpMission(tester, level: 3);
    final total = MathChallenge.questionCount(3);
    final dots = tester.widget<Row>(find.byKey(kMathProgressKey)).children;
    expect(dots, hasLength(total));
  });

  testWidgets('Ilerleme gostergesi yalnizca birden fazla soruda cizilir', (
    tester,
  ) async {
    // Kural soru sayisina bagli, seviyeye degil: tek soruda nokta dizisi
    // gereksiz gurultu olurdu. Sayilar kalibrasyonla degisebildigi icin
    // beklenti dogrudan `questionCount`tan turetiliyor.
    for (var level = 1; level <= MathChallenge.maxLevel; level++) {
      await tester.pumpWidget(
        wrapWithTheme(
          MathMission(
            key: ValueKey(level),
            level: level,
            random: Random(7),
            onCompleted: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(kMathProgressKey),
        MathChallenge.questionCount(level) > 1 ? findsOneWidget : findsNothing,
        reason: 'seviye $level',
      );
    }
  });

  testWidgets('Son soruda gonder tusu Bitir yazar, oncekilerde Onayla', (
    tester,
  ) async {
    final questions = MathChallenge.generate(level: 2, random: Random(7));
    await pumpMission(tester);

    expect(find.text('Onayla'), findsOneWidget);
    await type(tester, questions.first.answer);
    await submit(tester);
    expect(find.text('Bitir'), findsOneWidget);
  });

  testWidgets('Dar ve kisa ekranda tasmaz', (tester) async {
    tester.view.physicalSize = const Size(640, 900);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await pumpMission(tester, level: 4, seed: 1);

    expect(tester.takeException(), isNull);
  });
}
