import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/presentation/widgets/common/grouped_list.dart';
import 'package:ezanvakti/presentation/widgets/notifications/notification_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  Future<void> pumpTile(
    WidgetTester tester, {
    required NotificationSetting setting,
    bool hasPermission = true,
    VoidCallback? onToggle,
  }) async {
    await tester.pumpWidget(
      wrapWithTheme(
        GroupedList(
          children: [
            NotificationTile(
              setting: setting,
              hasPermission: hasPermission,
              onToggle: onToggle ?? () {},
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('Tam vaktinde bildirim alt metni', (tester) async {
    await pumpTile(
      tester,
      setting: const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
      ),
    );

    expect(find.text('Öğle'), findsOneWidget);
    expect(find.text('Tam vaktinde · Her gün'), findsOneWidget);
  });

  testWidgets('X dakika once bildirim alt metni', (tester) async {
    await pumpTile(
      tester,
      setting: const NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        minutesBefore: 30,
      ),
    );

    expect(find.text('30 dk önce · Her gün'), findsOneWidget);
  });

  testWidgets('Kapali bildirim sondurulmus cizilir', (tester) async {
    await pumpTile(
      tester,
      setting: const NotificationSetting(
        prayerType: PrayerType.isha,
        isActive: false,
      ),
    );

    final opacity = tester.widget<Opacity>(
      find
          .descendant(
            of: find.byType(NotificationTile),
            matching: find.byType(Opacity),
          )
          .first,
    );

    expect(opacity.opacity, lessThan(1.0));
  });

  testWidgets('Izin yoksa satir sondurulur ve anahtar pasif', (tester) async {
    await pumpTile(
      tester,
      setting: const NotificationSetting(
        prayerType: PrayerType.asr,
        isActive: true,
      ),
      hasPermission: false,
    );

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    final opacity = tester.widget<Opacity>(
      find
          .descendant(
            of: find.byType(NotificationTile),
            matching: find.byType(Opacity),
          )
          .first,
    );

    expect(switchWidget.onChanged, isNull);
    expect(opacity.opacity, lessThan(1.0));
  });

  testWidgets('Anahtara dokunmak onToggle tetikler', (tester) async {
    var toggled = false;

    await pumpTile(
      tester,
      setting: const NotificationSetting(
        prayerType: PrayerType.asr,
        isActive: true,
      ),
      onToggle: () => toggled = true,
    );

    await tester.tap(find.byType(Switch));
    expect(toggled, isTrue);
  });

  testWidgets('Özel bildirim adı vakit ve tekrar bilgisini gizlemez', (
    tester,
  ) async {
    await pumpTile(
      tester,
      setting: const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: true,
        label: 'Cuma namazı',
        minutesBefore: 45,
        weekdays: {5},
      ),
    );

    expect(find.text('Cuma namazı'), findsOneWidget);
    expect(find.text('Öğle · 45 dk önce · Cum'), findsOneWidget);
  });
}
