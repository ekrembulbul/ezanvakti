import 'package:ezanvakti/presentation/widgets/common/sliding_segment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_harness.dart';

enum _Tab { times, alarms }

void main() {
  const items = [
    SegmentItem(value: _Tab.times, label: 'Vakitler', icon: Icons.schedule),
    SegmentItem(value: _Tab.alarms, label: 'Alarmlar', icon: Icons.alarm),
  ];

  testWidgets('Iki bolme de etiketiyle cizilir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        SlidingSegment<_Tab>(
          items: items,
          selected: _Tab.times,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Vakitler'), findsOneWidget);
    expect(find.text('Alarmlar'), findsOneWidget);
  });

  testWidgets('Secili bolme vurgu rengini, digeri notr rengi alir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        SlidingSegment<_Tab>(
          items: items,
          selected: _Tab.times,
          onChanged: (_) {},
        ),
      ),
    );

    final tokens = tokensFor();
    final selected = tester.widget<Text>(find.text('Vakitler'));
    final unselected = tester.widget<Text>(find.text('Alarmlar'));

    expect(selected.style!.color, tokens.accent);
    expect(unselected.style!.color, tokens.textTertiary);
  });

  testWidgets('Bolmeye dokunmak onChanged tetikler', (tester) async {
    _Tab? picked;

    await tester.pumpWidget(
      wrapWithTheme(
        SlidingSegment<_Tab>(
          items: items,
          selected: _Tab.times,
          onChanged: (value) => picked = value,
        ),
      ),
    );

    await tester.tap(find.text('Alarmlar'));

    expect(picked, _Tab.alarms);
  });

  testWidgets('Zaten secili bolmeye dokunmak da onChanged tetikler', (
    tester,
  ) async {
    var calls = 0;

    await tester.pumpWidget(
      wrapWithTheme(
        SlidingSegment<_Tab>(
          items: items,
          selected: _Tab.times,
          onChanged: (_) => calls++,
        ),
      ),
    );

    await tester.tap(find.text('Vakitler'));

    expect(calls, 1);
  });

  testWidgets('Uc bolmeli kullanim da calisir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        SlidingSegment<String>(
          items: const [
            SegmentItem(value: 'dark', label: 'Koyu'),
            SegmentItem(value: 'light', label: 'Açık'),
            SegmentItem(value: 'system', label: 'Sistem'),
          ],
          selected: 'light',
          onChanged: (_) {},
          height: 40,
          radius: 12,
          padding: 3,
        ),
      ),
    );

    expect(find.text('Koyu'), findsOneWidget);
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Sistem'), findsOneWidget);
  });

  testWidgets('Ikonsuz bolmede ikon cizilmez', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        SlidingSegment<String>(
          items: const [
            SegmentItem(value: 'a', label: 'A'),
            SegmentItem(value: 'b', label: 'B'),
          ],
          selected: 'a',
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.byType(Icon), findsNothing);
  });

  /// Spec §4.4: alt gezinme yatagi 52/r26/dolgu 4 -> pill 42, tema secici
  /// 40/r12/dolgu 3 -> pill 32. Iki olcu de 1px kenarligi iki kez duser;
  /// hesaba katilmadiginda pill yatagin alt kenarligina tasiyordu.
  testWidgets('Pill yatagin ic kutusuna tam oturur', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        SlidingSegment<_Tab>(
          items: items,
          selected: _Tab.times,
          onChanged: (_) {},
        ),
      ),
    );

    final track = tester.getRect(find.byType(SlidingSegment<_Tab>));
    final pill = tester.getRect(find.byKey(kSegmentPillKey));

    expect(track.height, 52);
    expect(pill.height, 42);
    expect(pill.top - track.top, 5, reason: 'dolgu 4 + kenarlik 1');
    expect(track.bottom - pill.bottom, 5, reason: 'ust ve alt bosluk esit');
  });

  testWidgets('Ikon ve etiket pill ile ayni merkezde', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        SlidingSegment<_Tab>(
          items: items,
          selected: _Tab.times,
          onChanged: (_) {},
        ),
      ),
    );

    final pill = tester.getRect(find.byKey(kSegmentPillKey));
    final icon = tester.getRect(find.byIcon(Icons.schedule));
    final label = tester.getRect(find.text('Vakitler'));

    // Ikon + bosluk + etiket tek bir grup; grubun ortasi pill'in ortasinda.
    final groupCenterX = (icon.left + label.right) / 2;
    expect(groupCenterX, closeTo(pill.center.dx, 0.5));
    expect(icon.center.dy, closeTo(pill.center.dy, 0.5));
  });

  testWidgets('Tema seciciye ozgu olculer de spec ile ayni', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        SlidingSegment<String>(
          items: const [
            SegmentItem(value: 'dark', label: 'Koyu'),
            SegmentItem(value: 'light', label: 'Açık'),
            SegmentItem(value: 'system', label: 'Sistem'),
          ],
          selected: 'light',
          onChanged: (_) {},
          height: 40,
          radius: 12,
          padding: 3,
        ),
      ),
    );

    final pill = tester.getRect(find.byKey(kSegmentPillKey));

    expect(pill.height, 32);
  });
}
