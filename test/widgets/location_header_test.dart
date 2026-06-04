import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/presentation/widgets/home/location_header.dart';

void main() {
  testWidgets('LocationWidget ellipsizes long names without overflow', (
    tester,
  ) async {
    // Dar bir başlık satırı: uzun (yabancı) konum adı + sağda tarih alanı.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: Row(
              children: [
                Expanded(
                  child: LocationWidget(
                    location: const Location(
                      id: '1',
                      province: 'California',
                      district: 'San Francisco County',
                      type: LocationType.gps,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const SizedBox(width: 150, height: 40),
              ],
            ),
          ),
        ),
      ),
    );

    // Taşma olsaydı RenderFlex bir FlutterError fırlatırdı.
    expect(tester.takeException(), isNull);
    expect(find.text('San Francisco County'), findsOneWidget);
  });
}
