import 'dart:async';

import 'package:ezanvakti/features/alarms/domain/shake_detector.dart';
import 'package:ezanvakti/presentation/widgets/missions/shake_mission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  late StreamController<({double x, double y, double z})> samples;
  late DateTime clock;

  setUp(() {
    samples = StreamController.broadcast();
    clock = DateTime(2026, 8, 18, 5, 0);
  });
  tearDown(() => samples.close());

  Widget build({int level = 1, VoidCallback? onCompleted}) => wrapWithTheme(
    ShakeMission(
      level: level,
      onCompleted: onCompleted ?? () {},
      samples: samples.stream,
      now: () => clock,
    ),
  );

  /// Bekleme suresini asarak esigi gecen ornek gonderir.
  Future<void> shake(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      clock = clock.add(ShakeDetector.cooldown + const Duration(milliseconds: 10));
      samples.add((x: 25.0, y: 0.0, z: 0.0));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('Baslangicta hedef kadar sallama ister', (tester) async {
    await tester.pumpWidget(build(level: 1));
    await tester.pump();
    expect(
      find.text('${ShakeDetector.targetFor(1)}'),
      findsOneWidget,
    );
    expect(find.text('kez daha salla'), findsOneWidget);
  });

  testWidgets('Her sallamada kalan sayi azalir', (tester) async {
    await tester.pumpWidget(build(level: 1));
    await shake(tester, 3);
    expect(
      find.text('${ShakeDetector.targetFor(1) - 3}'),
      findsOneWidget,
    );
  });

  testWidgets('Durgun ornek sayilmaz', (tester) async {
    await tester.pumpWidget(build(level: 1));
    samples.add((x: 0.0, y: 0.0, z: 9.81));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('${ShakeDetector.targetFor(1)}'), findsOneWidget);
  });

  testWidgets('Hedefe ulasinca tamamlanir', (tester) async {
    var done = false;
    await tester.pumpWidget(build(level: 1, onCompleted: () => done = true));
    await shake(tester, ShakeDetector.targetFor(1));
    expect(done, isTrue);
  });
}
