import 'package:ezanvakti/presentation/widgets/common/app_nav_bar.dart';
import 'package:ezanvakti/presentation/widgets/common/main_tab_scaffold.dart';
import 'package:ezanvakti/presentation/widgets/common/swipe_to_delete.dart';
import 'package:ezanvakti/presentation/widgets/reminders/reminder_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

/// HomePage'in kullandığı gerçek navigation gövdesini kontrollü index ile kurar.
class _Shell extends StatefulWidget {
  final List<Widget>? pages;
  final int initialIndex;
  final ValueChanged<int>? onChanged;

  const _Shell({this.pages, this.initialIndex = 0, this.onChanged});

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late int _tabIndex = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return MainTabScaffold(
      selectedIndex: _tabIndex,
      onChanged: (index) {
        setState(() => _tabIndex = index);
        widget.onChanged?.call(index);
      },
      items: const [
        NavItem(label: 'Vakitler', icon: Icons.schedule_rounded),
        NavItem(label: 'Takvim', icon: Icons.calendar_month_rounded),
        NavItem(label: 'Hatırlatıcılar', icon: Icons.notifications_rounded),
        NavItem(label: 'Araçlar', icon: Icons.handyman_rounded),
      ],
      children:
          widget.pages ??
          [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('vakitler-govde'),
                  TextButton(
                    onPressed: () => setState(() => _tabIndex = 2),
                    child: const Text('hatırlatıcılara git'),
                  ),
                ],
              ),
            ),
            const Center(child: Text('takvim-govde')),
            const Center(child: Text('hatirlaticilar-govde')),
            const Center(child: Text('araclar-govde')),
          ],
    );
  }
}

class _EditableTab extends StatefulWidget {
  const _EditableTab({super.key});

  @override
  State<_EditableTab> createState() => _EditableTabState();
}

class _EditableTabState extends State<_EditableTab> {
  final _textController = TextEditingController();
  bool _selected = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: _textController),
        ChoiceChip(
          label: const Text('secim'),
          selected: _selected,
          onSelected: (value) => setState(() => _selected = value),
        ),
      ],
    );
  }
}

class _ReminderTab extends StatefulWidget {
  final bool isReordering;

  const _ReminderTab({this.isReordering = false});

  @override
  State<_ReminderTab> createState() => _ReminderTabState();
}

class _ReminderTabState extends State<_ReminderTab> {
  final _rows = List.generate(12, (index) => 'satır-${index + 1}');

  @override
  Widget build(BuildContext context) {
    return ReminderList(
      isReordering: widget.isReordering,
      onReorder: (oldIndex, newIndex) {
        setState(() => _rows.insert(newIndex, _rows.removeAt(oldIndex)));
      },
      header: const SizedBox(
        height: 100,
        child: Center(child: Text('liste başlığı')),
      ),
      footer: const SizedBox(height: 120),
      children: [
        for (final row in _rows)
          if (widget.isReordering)
            SizedBox(
              key: ValueKey(row),
              height: 80,
              child: Center(child: Text(row)),
            )
          else
            SwipeToDelete(
              itemKey: ValueKey(row),
              onDelete: () => setState(() => _rows.remove(row)),
              child: SizedBox(height: 80, child: Center(child: Text(row))),
            ),
      ],
    );
  }
}

void main() {
  int selectedTab(WidgetTester tester) =>
      tester.widget<AppNavBar>(find.byType(AppNavBar)).selected;

  Widget reminderShell({bool isReordering = false}) => wrapWithTheme(
    _Shell(
      initialIndex: 2,
      pages: [
        const Center(child: Text('vakitler-govde')),
        const Center(child: Text('takvim-govde')),
        _ReminderTab(isReordering: isReordering),
        const Center(child: Text('araclar-govde')),
      ],
    ),
  );

  testWidgets('Uzak sekmeye dokunmak ara sekmeleri seçmez', (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(wrapWithTheme(_Shell(onChanged: changes.add)));

    await tester.tap(find.text('Araçlar'));
    await tester.pumpAndSettle();

    expect(changes, [3]);
    expect(selectedTab(tester), 3);
    expect(find.text('araclar-govde').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Vakitler'));
    await tester.pumpAndSettle();

    expect(changes, [3, 0]);
    expect(find.text('vakitler-govde').hitTestable(), findsOneWidget);
  });

  testWidgets('Aynı frame içindeki ardışık dokunuşlarda son seçim korunur', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithTheme(const _Shell()));

    await tester.tap(find.text('Araçlar'));
    await tester.tap(find.text('Vakitler'));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
    expect(find.text('vakitler-govde').hitTestable(), findsOneWidget);
  });

  testWidgets('Ana ekran kısayolu hem gövdeyi hem seçili sekmeyi değiştirir', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithTheme(const _Shell()));

    await tester.tap(find.text('hatırlatıcılara git'));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 2);
    expect(find.text('hatirlaticilar-govde').hitTestable(), findsOneWidget);
  });

  testWidgets('İlk ve son sekmede dışa swipe sınırı aşmaz', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const _Shell()));

    await tester.drag(find.byType(MainTabScaffold), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 0);
    expect(find.text('vakitler-govde').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Araçlar'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(MainTabScaffold), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 3);
    expect(find.text('araclar-govde').hitTestable(), findsOneWidget);
  });

  testWidgets('Seçili sekmeye dokunmak yarım swipe hareketini iptal eder', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithTheme(const _Shell()));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MainTabScaffold)),
    );
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump(const Duration(milliseconds: 30));

    await tester.tap(find.text('Vakitler'));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
    expect(find.text('vakitler-govde').hitTestable(), findsOneWidget);
  });

  testWidgets('Swipe sürerken son sekme dokunuşu seçili kalır', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const _Shell()));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MainTabScaffold)),
    );
    await gesture.moveBy(const Offset(-440, 0));
    await tester.pump(const Duration(milliseconds: 30));

    await tester.tap(find.text('Araçlar'));
    await tester.pump();
    await tester.tap(find.text('Takvim'));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 1);
    expect(find.text('takvim-govde').hitTestable(), findsOneWidget);
  });

  testWidgets('Satır swipe siler ve ana sekmeyi değiştirmez', (tester) async {
    await tester.pumpWidget(reminderShell());

    await tester.drag(find.text('satır-1'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 2);
    expect(find.text('satır-1'), findsNothing);
    expect(find.text('satır-2').hitTestable(), findsOneWidget);
  });

  testWidgets('Liste başlığındaki swipe sekme değiştirir ve satırı silmez', (
    tester,
  ) async {
    await tester.pumpWidget(reminderShell());

    await tester.drag(find.text('liste başlığı'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 3);

    await tester.tap(find.text('Hatırlatıcılar'));
    await tester.pumpAndSettle();
    expect(find.text('satır-1').hitTestable(), findsOneWidget);
  });

  testWidgets('Dikey liste scroll konumu sekmeye dönünce korunur', (
    tester,
  ) async {
    await tester.pumpWidget(reminderShell());

    await tester.drag(find.text('satır-3'), const Offset(0, -300));
    await tester.pumpAndSettle();
    final rowTop = tester.getTopLeft(find.text('satır-5')).dy;
    expect(selectedTab(tester), 2);
    expect(find.text('satır-1').hitTestable(), findsNothing);

    await tester.tap(find.text('Vakitler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hatırlatıcılar'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('satır-5')).dy, closeTo(rowTop, 0.5));
  });

  testWidgets('Reorder handle sürüklemek satırları taşır ve sekmeyi korur', (
    tester,
  ) async {
    await tester.pumpWidget(reminderShell(isReordering: true));

    await tester.timedDrag(
      find.byKey(const ValueKey('reminder-drag-0')),
      const Offset(-40, 170),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 2);
    expect(
      tester.getTopLeft(find.text('satır-1')).dy,
      greaterThan(tester.getTopLeft(find.text('satır-2')).dy),
    );
  });

  testWidgets('Reorder handle üzerindeki yatay hareket sekmeyi değiştirmez', (
    tester,
  ) async {
    await tester.pumpWidget(reminderShell(isReordering: true));

    await tester.timedDrag(
      find.byKey(const ValueKey('reminder-drag-0')),
      const Offset(-500, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 2);
    expect(find.text('satır-1').hitTestable(), findsOneWidget);
  });

  testWidgets('Sekmeden ayrılınca düzenlenen metin ve iç seçim korunur', (
    tester,
  ) async {
    final pageKey = GlobalKey();
    await tester.pumpWidget(
      wrapWithTheme(
        _Shell(
          pages: [
            _EditableTab(key: pageKey),
            const Center(child: Text('takvim-govde')),
            const Center(child: Text('hatirlaticilar-govde')),
            const Center(child: Text('araclar-govde')),
          ],
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'korunan metin');
    await tester.tap(find.text('secim'));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Araçlar'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(MainTabScaffold), const Offset(600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vakitler'));
    await tester.pumpAndSettle();

    expect(find.text('korunan metin').hitTestable(), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byType(ChoiceChip)).selected, isTrue);
  });

  testWidgets('Yatay swipe tüm ana sekmeler ve alt gezinmeyi senkron tutar', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWithTheme(const _Shell()));

    for (final (index, body) in [
      (1, 'takvim-govde'),
      (2, 'hatirlaticilar-govde'),
      (3, 'araclar-govde'),
    ]) {
      await tester.drag(find.byType(MainTabScaffold), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(selectedTab(tester), index);
      expect(find.text(body).hitTestable(), findsOneWidget);
    }

    await tester.drag(find.byType(MainTabScaffold), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 2);
    expect(find.text('hatirlaticilar-govde').hitTestable(), findsOneWidget);
  });

  testWidgets('RTL swipe okuma yönüne göre sonraki sekmeye geçer', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(const _Shell(), locale: const Locale('ar')),
    );

    await tester.drag(find.byType(MainTabScaffold), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 1);
    expect(find.text('takvim-govde').hitTestable(), findsOneWidget);

    await tester.drag(find.byType(MainTabScaffold), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
    expect(find.text('vakitler-govde').hitTestable(), findsOneWidget);
  });

  testWidgets('Sekme degisimi dogru govdeyi one alir', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const _Shell()));

    await tester.tap(find.text('Takvim'));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 1);
    expect(find.text('takvim-govde').hitTestable(), findsOneWidget);
    expect(find.text('vakitler-govde').hitTestable(), findsNothing);
  });

  testWidgets('Sekme 2 de geri tusu ilk sekmeye doner', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const _Shell()));

    await tester.tap(find.text('Hatırlatıcılar'));
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 2);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      selectedTab(tester),
      0,
      reason: 'Sekme gecmisi biriktirmeden ilk sekmeye donmeli',
    );
  });
}
