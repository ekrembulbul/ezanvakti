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
}
