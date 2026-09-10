import 'package:ezanvakti/presentation/widgets/reminders/reminder_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  for (final locale in const [Locale('tr'), Locale('ar')]) {
    testWidgets(
      'önemli zaman dar ekranda ve büyük yazıda taşmaz (${locale.languageCode})',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.8)),
                child: const Center(
                  child: SizedBox(
                    width: 320,
                    child: ReminderRow(
                      days: 'Pazartesi, Çarşamba, Cuma',
                      remaining: '1 gün 2 sa 5 dk',
                      primary: 'İmsak · 1 sa 45 dk önce',
                      primaryIcon: Icons.qr_code_scanner_rounded,
                      primaryIconTooltip: 'QR okutma',
                      label: 'Sabah hazırlığı için çok uzun bir etiket',
                      detail: 'Yalnızca bu sefer atlanacak · yarın 04:15',
                      trailing: Switch(value: true, onChanged: null),
                    ),
                  ),
                ),
              ),
            ),
            locale: locale,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
      },
    );
  }

  testWidgets('etiket büyük ve ayrı satırda, zaman bilgisi altında', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const Center(
          child: SizedBox(
            width: 360,
            child: ReminderRow(
              days: 'Her gün',
              remaining: '1 sa 20 dk',
              primary: '05:46',
              label: 'Sahur',
              detail: 'yarın',
              trailing: Switch(value: true, onChanged: null),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final label = tester.widget<Text>(find.text('Sahur'));
    expect(label.style?.fontSize, 16);
    expect(label.style?.fontWeight, FontWeight.w600);

    // Detay ve kalan süre tek satırda, etiketin altında.
    final info = find.text('yarın · 1 sa 20 dk');
    expect(info, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Sahur')).dy,
      lessThan(tester.getTopLeft(info).dy),
    );
    expect(tester.widget<Text>(info).style?.fontSize, 13);
  });

  testWidgets('etiket yoksa yalnızca zaman bilgisi satırı çizilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const Center(
          child: SizedBox(
            width: 360,
            child: ReminderRow(
              days: 'Her gün',
              remaining: '1 sa 20 dk',
              primary: '05:46',
              trailing: Switch(value: true, onChanged: null),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1 sa 20 dk'), findsOneWidget);
  });
}
