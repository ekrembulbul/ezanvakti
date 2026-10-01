import 'package:ezanvakti/features/daily_content/domain/daily_content.dart';
import 'package:ezanvakti/presentation/widgets/home/daily_content_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

const _content = DailyContent(
  date: '2026-10-01',
  verse: '"Kötü işler yapmak için tuzak kuranlar…"',
  verseSource: '(Nahl, 16/45)',
  hadith: '“Âdemoğlu ihtiyarlayıp çöker…”',
  hadithSource: '(Müslim, “Zekât”, 115)',
  prayer: '"Ey yerleri ve gökleri yaratan…"',
  prayerSource: '(İbn Ebî Şeybe, "Dua", 23)',
);

void main() {
  Future<void> pump(WidgetTester tester, DailyContent content) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapWithTheme(
        SingleChildScrollView(child: DailyContentSection(content: content)),
      ),
    );
  }

  testWidgets('üç kart başlık, metin ve kaynakla görünür', (tester) async {
    await pump(tester, _content);
    expect(find.text('Günün Ayeti'), findsOneWidget);
    expect(find.text('Günün Hadisi'), findsOneWidget);
    expect(find.text('Günün Duası'), findsOneWidget);
    expect(find.text(_content.verse), findsOneWidget);
    expect(find.text(_content.verseSource), findsOneWidget);
    expect(find.text(_content.hadithSource), findsOneWidget);
    expect(find.text(_content.prayerSource!), findsOneWidget);
    expect(find.byTooltip('Paylaş'), findsNWidgets(3));
  });

  testWidgets('dua kaynağı yoksa kaynak satırı çizilmez', (tester) async {
    const noSource = DailyContent(
      date: '2026-10-01',
      verse: 'v',
      verseSource: 'vs',
      hadith: 'h',
      hadithSource: 'hs',
      prayer: 'p',
    );
    await pump(tester, noSource);
    expect(find.text('p'), findsOneWidget);
    expect(find.text('vs'), findsOneWidget);
    expect(find.text('hs'), findsOneWidget);
    // Dua kartında yalnız metin var.
    final prayerCard = find.ancestor(
      of: find.text('p'),
      matching: find.byKey(const ValueKey('daily-prayer')),
    );
    expect(
      find.descendant(of: prayerCard, matching: find.byType(Text)),
      findsNWidgets(2), // başlık + metin
    );
  });

  testWidgets('basılı tutunca metni kaynağıyla kopyalar ve haber verir', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester, _content);
    await tester.longPress(find.text(_content.hadith));
    await tester.pump();
    expect(copied, '${_content.hadith}\n${_content.hadithSource}');
    expect(find.text('Kopyalandı'), findsOneWidget);
  });
}
