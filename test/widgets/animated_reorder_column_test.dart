import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_harness.dart';

void main() {
  testWidgets(
    'farklı yükseklikteki satırlar hareket sırasında silinince kalanlar sıçramaz',
    (tester) async {
      const a = SizedBox(key: ValueKey('a'), height: 60, child: Text('a'));
      const b = SizedBox(key: ValueKey('b'), height: 130, child: Text('b'));
      const c = SizedBox(key: ValueKey('c'), height: 90, child: Text('c'));
      final rows = ValueNotifier<List<Widget>>([a, b, c]);
      addTearDown(rows.dispose);
      await tester.pumpWidget(
        wrapWithTheme(
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              child: ValueListenableBuilder(
                valueListenable: rows,
                builder: (context, children, _) =>
                    GroupedList(animateOrder: true, children: children),
              ),
            ),
          ),
        ),
      );
      final initial = tester.getTopLeft(find.text('a')).dy;
      rows.value = [c, a, b];
      await tester.pump();
      expect(tester.getTopLeft(find.text('a')).dy, closeTo(initial, 0.5));
      await tester.pump(const Duration(milliseconds: 130));
      final moving = tester.getTopLeft(find.text('a')).dy;
      expect(moving, greaterThan(initial));
      expect(moving, lessThan(initial + 91));

      rows.value = [c, a];
      await tester.pump();
      expect(tester.getTopLeft(find.text('a')).dy, closeTo(moving, 0.5));
      await tester.pumpAndSettle();
      expect(find.text('b'), findsNothing);
      expect(tester.getTopLeft(find.text('a')).dy, closeTo(initial + 91, 0.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('yer değiştiren satırın düzenleme durumu korunur', (
    tester,
  ) async {
    const editor = SizedBox(
      key: ValueKey('editor'),
      height: 100,
      child: TextField(),
    );
    const other = SizedBox(
      key: ValueKey('other'),
      height: 80,
      child: Text('other'),
    );
    final rows = ValueNotifier<List<Widget>>([editor, other]);
    addTearDown(rows.dispose);
    await tester.pumpWidget(
      wrapWithTheme(
        Align(
          alignment: Alignment.topCenter,
          child: ValueListenableBuilder(
            valueListenable: rows,
            builder: (context, children, _) =>
                GroupedList(animateOrder: true, children: children),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Korunan metin');
    final state = tester.state(find.byType(TextField));
    rows.value = [other, editor];
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(TextField)), same(state));
    expect(find.text('Korunan metin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
