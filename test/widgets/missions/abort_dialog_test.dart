import 'package:ezanvakti/core/config/mission_tuning.dart';
import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:ezanvakti/l10n/l10n_extensions.dart';
import 'package:ezanvakti/features/alarms/domain/abort_gate.dart';
import 'package:ezanvakti/presentation/widgets/missions/abort_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';
import '../../support/l10n_helper.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async => l10n = await loadTestL10n());

  Widget build(int level, {required void Function() onConfirmed}) =>
      wrapWithTheme(AbortDialog(level: level, onConfirmed: onConfirmed));

  /// Basili tutma jesti: uzun basma esigini gecip birakir.
  Future<void> hold(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(kAbortHoldKey)),
    );
    await tester.pump(const Duration(seconds: 4));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('Seviye 0: basili tutma yeter, cumle istenmez', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(build(0, onConfirmed: () => confirmed = true));

    expect(find.byType(TextField), findsNothing);
    await hold(tester);
    expect(confirmed, isTrue);
  });

  testWidgets('Basili tutma suresi dolmadan biraksa onaylanmaz', (
    tester,
  ) async {
    var confirmed = false;
    await tester.pumpWidget(build(0, onConfirmed: () => confirmed = true));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(kAbortHoldKey)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
  });

  testWidgets('Seviye 1: cumle alani cizilir ve metin gosterilir', (
    tester,
  ) async {
    await tester.pumpWidget(build(1, onConfirmed: () {}));
    expect(find.byType(TextField), findsOneWidget);
    expect(
      find.textContaining(l10n.abortPhrase(AbortPhrase.short)),
      findsWidgets,
    );
  });

  testWidgets('Yanlis cumleyle onaylanmaz', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(build(1, onConfirmed: () => confirmed = true));

    await tester.enterText(find.byType(TextField), 'yanlis');
    await hold(tester);

    expect(confirmed, isFalse);
  });

  testWidgets('Dogru cumle + basili tutma onaylar', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(build(1, onConfirmed: () => confirmed = true));

    await tester.enterText(
      find.byType(TextField),
      l10n.abortPhrase(AbortGate.requirementFor(1).phrase!),
    );
    await hold(tester);

    expect(confirmed, isTrue);
  });

  testWidgets('Uyari metni bir dahaki seferi haber verir', (tester) async {
    await tester.pumpWidget(build(0, onConfirmed: () {}));
    expect(find.textContaining('daha zor'), findsOneWidget);
  });

  testWidgets('Tavanda metin artik zorlasmayacagini soyler', (tester) async {
    await tester.pumpWidget(
      build(MissionTuning.abortMaxLevel, onConfirmed: () {}),
    );
    expect(find.textContaining('daha zor'), findsNothing);
    expect(find.textContaining('en zor'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 20));
  });

  testWidgets('Tavanda geri sayim dolmadan onaylanmaz', (tester) async {
    var confirmed = false;
    final req = AbortGate.requirementFor(MissionTuning.abortMaxLevel);
    await tester.pumpWidget(
      build(MissionTuning.abortMaxLevel, onConfirmed: () => confirmed = true),
    );

    await tester.enterText(find.byType(TextField), l10n.abortPhrase(req.phrase!));
    await hold(tester);
    expect(confirmed, isFalse);

    await tester.pump(Duration(seconds: req.countdownSeconds));
    await hold(tester);
    expect(confirmed, isTrue);
  });
}
