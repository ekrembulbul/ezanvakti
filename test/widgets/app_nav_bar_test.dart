import 'package:ezanvakti/presentation/widgets/common/app_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_harness.dart';

const _items = [
  NavItem(label: 'Vakitler', icon: Icons.schedule_rounded),
  NavItem(label: 'Takvim', icon: Icons.calendar_month_rounded),
  NavItem(label: 'Hatırlatıcılar', icon: Icons.notifications_rounded),
  NavItem(label: 'Araçlar', icon: Icons.handyman_rounded),
];
const _arabicItems = [
  NavItem(label: 'الأوقات', icon: Icons.schedule_rounded),
  NavItem(label: 'التقويم', icon: Icons.calendar_month_rounded),
  NavItem(label: 'التنبيهات', icon: Icons.notifications_rounded),
  NavItem(label: 'الأدوات', icon: Icons.handyman_rounded),
];

Future<void> _pumpBar(
  WidgetTester tester, {
  double width = 402,
  double textScale = 1,
  double bottomInset = 0,
  int selected = 0,
  ValueChanged<int>? onChanged,
  Locale locale = const Locale('tr'),
  List<NavItem> items = _items,
}) async {
  tester.view.physicalSize = Size(width, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapWithTheme(
      MediaQuery(
        data: MediaQueryData(
          size: Size(width, 640),
          textScaler: TextScaler.linear(textScale),
          padding: EdgeInsets.only(bottom: bottomInset),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AppNavBar(
            items: items,
            selected: selected,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

void _expectCompleteLabels(WidgetTester tester, List<NavItem> items) {
  final bar = tester.getRect(find.byType(AppNavBar));
  for (final item in items) {
    final label = find.text(item.label);
    expect(label.hitTestable(), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(label);
    expect(paragraph.didExceedMaxLines, isFalse, reason: item.label);
    final rect = tester.getRect(label);
    expect(rect.left, greaterThanOrEqualTo(bar.left));
    expect(rect.right, lessThanOrEqualTo(bar.right));
    expect(rect.bottom, lessThanOrEqualTo(bar.bottom));
  }
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'))).load();
  });

  for (final width in [320.0, 402.0]) {
    testWidgets('$width genişlikte dört isim tek sırada eksiksiz görünür', (
      tester,
    ) async {
      await _pumpBar(tester, width: width, selected: 2);
      _expectCompleteLabels(tester, _items);
      final top = tester.getTopLeft(find.text('Vakitler')).dy;
      for (final item in _items) {
        expect(tester.getTopLeft(find.text(item.label)).dy, closeTo(top, 0.5));
      }
    });
  }

  testWidgets('seçili öğe vurgu rengini alır', (tester) async {
    await _pumpBar(tester, selected: 1);
    expect(
      tester.widget<Text>(find.text('Takvim')).style?.color,
      tokensFor().accent,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.calendar_month_rounded)).color,
      tokensFor().accent,
    );
    expect(
      tester.widget<Text>(find.text('Vakitler')).style?.color,
      isNot(tokensFor().accent),
    );
  });

  testWidgets('sekme dokunuşları doğru indeksi seçer ve hedefler çakışmaz', (
    tester,
  ) async {
    final tapped = <int>[];
    await _pumpBar(tester, width: 320, onChanged: tapped.add);
    for (final item in _items) {
      await tester.tap(find.text(item.label));
      await tester.pumpAndSettle();
    }
    expect(tapped, [0, 1, 2, 3]);
  });

  testWidgets('seçim değişince etiketlerin yeri oynamaz', (tester) async {
    await _pumpBar(tester, width: 320);
    final positions = [
      for (final item in _items) tester.getCenter(find.text(item.label)),
    ];
    await _pumpBar(tester, width: 320, selected: 2);
    for (var i = 0; i < _items.length; i++) {
      expect(
        tester.getCenter(find.text(_items[i].label)).dx,
        closeTo(positions[i].dx, 0.5),
      );
    }
  });

  for (final (locale, items) in [
    (const Locale('tr'), _items),
    (const Locale('ar'), _arabicItems),
  ]) {
    testWidgets(
      '${locale.languageCode} yüzde 200 yazıda tüm sekmeler eksiksiz okunur ve seçilir',
      (tester) async {
        final tapped = <int>[];
        await _pumpBar(
          tester,
          width: 320,
          textScale: 2,
          locale: locale,
          items: items,
          onChanged: tapped.add,
        );
        _expectCompleteLabels(tester, items);
        for (final item in items) {
          await tester.tap(find.text(item.label));
          await tester.pumpAndSettle();
        }
        expect(tapped, [0, 1, 2, 3]);
      },
    );
  }

  testWidgets('RTL ilk sekmeyi sağdan başlatır', (tester) async {
    await _pumpBar(tester, locale: const Locale('ar'), items: _arabicItems);
    final centers = [
      for (final item in _arabicItems)
        tester.getCenter(find.text(item.label)).dx,
    ];
    expect(centers[0], greaterThan(centers[1]));
    expect(centers[1], greaterThan(centers[2]));
    expect(centers[2], greaterThan(centers[3]));
  });

  testWidgets('sekme isimleri ve seçim ekran okuyucuya bildirilir', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpBar(tester, selected: 2);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Hatırlatıcılar')),
        matchesSemantics(
          label: 'Hatırlatıcılar',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('sekme hedefleri alt sistem hareket alanından uzak kalır', (
    tester,
  ) async {
    await _pumpBar(tester, bottomInset: 34);
    for (final item in _items) {
      expect(
        tester.getRect(find.text(item.label)).bottom,
        lessThanOrEqualTo(640 - 34),
      );
    }
  });
}
