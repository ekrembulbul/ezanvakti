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
    expect(find.text('Tam vaktinde'), findsOneWidget);
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

    expect(find.text('30 dk önce'), findsOneWidget);
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

  testWidgets('Satir kendi kartini cizmez — grup icinde yasar', (tester) async {
    await pumpTile(
      tester,
      setting: const NotificationSetting(
        prayerType: PrayerType.maghrib,
        isActive: true,
      ),
    );

    expect(find.byType(GroupedRow), findsOneWidget);
  });
}
