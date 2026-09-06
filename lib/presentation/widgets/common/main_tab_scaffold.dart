import 'package:flutter/material.dart';

import '../../../core/theme/tokens_context.dart';
import 'app_nav_bar.dart';
import 'app_surface.dart';

/// Ana sekmelerin ortak gövdesi, alt gezinmesi ve geri tuşu davranışı.
class MainTabScaffold extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<NavItem> items;
  final List<Widget> children;

  const MainTabScaffold({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.items,
    required this.children,
  }) : assert(children.length > 0),
       assert(items.length == children.length),
       assert(selectedIndex >= 0 && selectedIndex < children.length);

  @override
  State<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<MainTabScaffold> {
  late final PageController _pageController;
  late int _visibleIndex;

  @override
  void initState() {
    super.initState();
    _visibleIndex = widget.selectedIndex;
    _pageController = PageController(
      initialPage: widget.selectedIndex,
      keepPage: false,
    );
  }

  @override
  void didUpdateWidget(covariant MainTabScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex == oldWidget.selectedIndex ||
        widget.selectedIndex == _visibleIndex) {
      return;
    }

    _visibleIndex = widget.selectedIndex;
    _pageController.jumpToPage(widget.selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    _visibleIndex = index;
    // Uzak sekmeye dokunmak ara sekmeleri seçmez; devam eden swipe da durur.
    _pageController.jumpToPage(index);
    widget.onChanged(index);
  }

  void _onPageChanged(int index) {
    if (_visibleIndex == index) return;
    _visibleIndex = index;
    widget.onChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.selectedIndex != 0) _selectPage(0);
      },
      child: Scaffold(
        backgroundColor: context.tokens.backgroundStops.last,
        body: AppSurface(
          safeAreaTop: false,
          safeAreaBottom: false,
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: [
              for (final child in widget.children) _KeptAliveTab(child: child),
            ],
          ),
        ),
        bottomNavigationBar: AppNavBar(
          items: widget.items,
          selected: widget.selectedIndex,
          onChanged: _selectPage,
        ),
      ),
    );
  }
}

class _KeptAliveTab extends StatefulWidget {
  final Widget child;

  const _KeptAliveTab({required this.child});

  @override
  State<_KeptAliveTab> createState() => _KeptAliveTabState();
}

class _KeptAliveTabState extends State<_KeptAliveTab>
    with AutomaticKeepAliveClientMixin<_KeptAliveTab> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
