import 'dart:math';

import 'package:ezanvakti/features/alarms/domain/math_challenge.dart';
import 'package:ezanvakti/presentation/widgets/missions/math_mission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  Future<void> answerAll(
    WidgetTester tester,
    List<MathQuestion> questions,
  ) async {
    for (final q in questions) {
      await tester.enterText(find.byType(TextField), '${q.answer}');
      await tester.tap(find.byKey(kMathSubmitKey));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('Tum sorular dogru cevaplanirsa tamamlanir', (tester) async {
    var done = false;
    final questions = MathChallenge.generate(level: 1, random: Random(7));

    await tester.pumpWidget(
      wrapWithTheme(
        MathMission(
          level: 1,
          random: Random(7),
          onCompleted: () => done = true,
        ),
      ),
    );

    await answerAll(tester, questions);
    expect(done, isTrue);
  });

  testWidgets('Yanlis cevap ilerletmez ve uyari gosterir', (tester) async {
    var done = false;
    await tester.pumpWidget(
      wrapWithTheme(
        MathMission(
          level: 1,
          random: Random(7),
          onCompleted: () => done = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '999999');
    await tester.tap(find.byKey(kMathSubmitKey));
    await tester.pumpAndSettle();

    expect(done, isFalse);
    expect(find.textContaining('Yanlış'), findsOneWidget);
  });

  testWidgets('Ilerleme her soru icin bir nokta cizer', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        MathMission(level: 3, random: Random(7), onCompleted: () {}),
      ),
    );
    final total = MathChallenge.questionCount(3);
    final dots = tester.widget<Row>(find.byKey(kMathProgressKey)).children;
    expect(dots, hasLength(total));
  });

  testWidgets('Tek soruluk gorevde ilerleme gostergesi cizilmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        MathMission(level: 1, random: Random(7), onCompleted: () {}),
      ),
    );
    // Seviye 1 su an tek soru; nokta dizisi gereksiz gurultu olurdu.
    expect(find.byKey(kMathProgressKey), findsNothing);
  });

  testWidgets('Bos cevap gonderilemez', (tester) async {
    var done = false;
    await tester.pumpWidget(
      wrapWithTheme(
        MathMission(
          level: 1,
          random: Random(7),
          onCompleted: () => done = true,
        ),
      ),
    );
    await tester.tap(find.byKey(kMathSubmitKey));
    await tester.pumpAndSettle();
    expect(done, isFalse);
  });
}
