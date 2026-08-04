import 'package:ezanvakti/presentation/widgets/common/app_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

/// `HomePage` tum servis grafigini cozdugu icin burada kabugun davranisi
/// (PopScope + sekme degisimi) ayni yapiyla izole olarak dogrulanir.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tabIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tabIndex != 0) setState(() => _tabIndex = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tabIndex,
          children: const [
            Center(child: Text('vakitler-govde')),
            Center(child: Text('takvim-govde')),
            Center(child: Text('hatirlaticilar-govde')),
          ],
        ),
        bottomNavigationBar: AppNavBar(
          items: const [
            NavItem(label: 'Vakitler', icon: Icons.schedule_rounded),
            NavItem(label: 'Takvim', icon: Icons.calendar_month_rounded),
            NavItem(label: 'Hatırlatıcılar', icon: Icons.notifications_rounded),
          ],
          selected: _tabIndex,
          onChanged: (index) => setState(() => _tabIndex = index),
        ),
      ),
    );
  }
}

void main() {
  int selectedTab(WidgetTester tester) =>
      tester.widget<AppNavBar>(find.byType(AppNavBar)).selected;

  testWidgets('Sekme degisimi dogru govdeyi one alir', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const _Shell()));

    await tester.tap(find.text('Takvim'));
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 1);
    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
      1,
      reason: 'IndexedStack hepsini agacta tutar; one alinan govde indekstir',
    );
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
