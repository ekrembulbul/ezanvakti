import 'package:ezanvakti/presentation/widgets/common/state_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_harness.dart';

void main() {
  testWidgets('LoadingState gostergeyi vurgu renginde cizer', (tester) async {
    await tester.pumpWidget(wrapWithTheme(const LoadingState()));

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );

    expect(indicator.color, tokensFor().accent);
    expect(find.text('Yükleniyor...'), findsOneWidget);
  });

  testWidgets('LoadingState ozel mesaj alabilir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(const LoadingState(message: 'Konumlar yükleniyor...')),
    );

    expect(find.text('Konumlar yükleniyor...'), findsOneWidget);
  });

  testWidgets('ErrorState mesaji ve yeniden dene dugmesini gosterir', (
    tester,
  ) async {
    var retried = false;

    await tester.pumpWidget(
      wrapWithTheme(
        ErrorState(message: 'Veri alınamadı', onRetry: () => retried = true),
      ),
    );

    expect(find.text('Veri alınamadı'), findsOneWidget);

    await tester.tap(find.text('Yeniden Dene'));
    expect(retried, isTrue);
  });

  testWidgets('ErrorState onRetry yoksa dugme cizilmez', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(const ErrorState(message: 'Veri alınamadı')),
    );

    expect(find.text('Yeniden Dene'), findsNothing);
  });

  testWidgets('ErrorState hata rengini ColorScheme ten alir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(const ErrorState(message: 'Veri alınamadı')),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
    final scheme = Theme.of(
      tester.element(find.byType(ErrorState)),
    ).colorScheme;

    expect(icon.color, scheme.error);
  });

  testWidgets('EmptyState ikon, mesaj ve alt metni gosterir', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const EmptyState(
          icon: Icons.alarm_off_rounded,
          message: 'Henüz alarm yok',
          subtitle: 'Sabit saatli veya vakte göre alarm ekle',
        ),
      ),
    );

    expect(find.byIcon(Icons.alarm_off_rounded), findsOneWidget);
    expect(find.text('Henüz alarm yok'), findsOneWidget);
    expect(find.text('Sabit saatli veya vakte göre alarm ekle'), findsOneWidget);
  });

  testWidgets('EmptyState eylem verilince cizer', (tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        EmptyState(
          icon: Icons.location_off_rounded,
          message: 'Henüz konum eklenmedi',
          action: ElevatedButton(
            onPressed: () {},
            child: const Text('Konum Ekle'),
          ),
        ),
      ),
    );

    expect(find.text('Konum Ekle'), findsOneWidget);
  });

  testWidgets('Durum widget lari renk sabiti yazmaz — metinler token renginde', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const EmptyState(icon: Icons.alarm_off_rounded, message: 'Boş'),
      ),
    );

    final tokens = tokensFor();
    final message = tester.widget<Text>(find.text('Boş'));

    expect(message.style!.color, tokens.textPrimary);
  });
}
