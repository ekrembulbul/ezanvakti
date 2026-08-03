import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:ezanvakti/presentation/widgets/common/info_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_harness.dart';

void main() {
  group('GroupedList', () {
    testWidgets('Satirlar arasina ayirac koyar, uclara koymaz', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const GroupedList(
            children: [
              GroupedRow(title: Text('bir')),
              GroupedRow(title: Text('iki')),
              GroupedRow(title: Text('üç')),
            ],
          ),
        ),
      );

      // Uc satir -> iki ayirac.
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('Tek satirda ayirac cizilmez', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const GroupedList(children: [GroupedRow(title: Text('tek'))]),
        ),
      );

      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('Grup yuzey ve kenarlik token larini kullanir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const GroupedList(children: [GroupedRow(title: Text('bir'))]),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(GroupedList),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      final tokens = tokensFor();

      expect(decoration.color, tokens.surface);
      expect(decoration.border, Border.all(color: tokens.border));
    });
  });

  group('GroupedRow', () {
    testWidgets('Ikon, baslik, alt metin ve sag oge cizilir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const GroupedList(
            children: [
              GroupedRow(
                icon: Icons.alarm_rounded,
                title: Text('Sahur'),
                subtitle: Text('Her gün'),
                trailing: Text('sağ'),
              ),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.alarm_rounded), findsOneWidget);
      expect(find.text('Sahur'), findsOneWidget);
      expect(find.text('Her gün'), findsOneWidget);
      expect(find.text('sağ'), findsOneWidget);
    });

    testWidgets('onTap verilince dokunma tetiklenir', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        wrapWithTheme(
          GroupedList(
            children: [
              GroupedRow(title: const Text('Sahur'), onTap: () => tapped = true),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Sahur'));
      expect(tapped, isTrue);
    });

    testWidgets('dimmed satir sondurulur', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const GroupedList(
            children: [GroupedRow(title: Text('Pasif'), dimmed: true)],
          ),
        ),
      );

      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(GroupedRow),
              matching: find.byType(Opacity),
            )
            .first,
      );

      expect(opacity.opacity, lessThan(1.0));
    });

    testWidgets('Baslik ve alt metin token renklerini alir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const GroupedList(
            children: [
              GroupedRow(title: Text('Başlık'), subtitle: Text('Alt metin')),
            ],
          ),
        ),
      );

      final tokens = tokensFor();
      final title = tester.widget<Text>(find.text('Başlık'));
      final subtitle = tester.widget<Text>(find.text('Alt metin'));
      final titleStyle = DefaultTextStyle.of(
        tester.element(find.text('Başlık')),
      ).style;
      final subtitleStyle = DefaultTextStyle.of(
        tester.element(find.text('Alt metin')),
      ).style;

      expect(title.style, isNull, reason: 'stil DefaultTextStyle ten gelmeli');
      expect(subtitle.style, isNull);
      expect(titleStyle.color, tokens.textPrimary);
      expect(subtitleStyle.color, tokens.textSecondary);
    });
  });

  group('InfoBanner', () {
    testWidgets('Ikon, metin ve eylem cizilir', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          InfoBanner(
            icon: Icons.notifications_off_rounded,
            text: 'Alarmların çalması için izin gerekiyor.',
            action: TextButton(onPressed: () {}, child: const Text('İzin ver')),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
      expect(
        find.text('Alarmların çalması için izin gerekiyor.'),
        findsOneWidget,
      );
      expect(find.text('İzin ver'), findsOneWidget);
    });

    testWidgets('Uyari notr kalir — vurgu rengi kullanilmaz', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const InfoBanner(icon: Icons.info_outline_rounded, text: 'Bilgi'),
        ),
      );

      final tokens = tokensFor();
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(InfoBanner),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;

      // Spec 4.1: uyari, secim ve pasif durumlar notr kalir.
      expect(decoration.color, isNot(tokens.accent));
      expect(decoration.color, tokens.surface);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.info_outline_rounded)).color,
        isNot(tokens.accent),
      );
    });
  });
}
