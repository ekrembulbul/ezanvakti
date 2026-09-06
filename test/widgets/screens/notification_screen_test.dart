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
    DateTime? now,
    DateTime? nextFireAt,
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
              now: now,
              nextFireAt: nextFireAt,
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

    expect(find.text('Her gün'), findsOneWidget);
    expect(find.text('Öğle · Tam vaktinde'), findsOneWidget);
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

    expect(find.text('Her gün'), findsOneWidget);
    expect(find.text('İmsak · 30 dk önce'), findsOneWidget);
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
      now: DateTime(2026, 9, 10, 12, 15),
      nextFireAt: DateTime(2026, 9, 11, 12, 15),
    );

    final days = find.text('Cum');
    final schedule = find.text('Öğle · 45 dk önce');
    final remaining = find.text('1 gün');
    final label = find.text('Cuma namazı');
    final details = find.text('yarın 12:15');
    expect(days, findsOneWidget);
    expect(remaining, findsOneWidget);
    expect(schedule, findsOneWidget);
    expect(label, findsOneWidget);
    expect(details, findsOneWidget);
    expect(
      tester.getTopLeft(days).dy,
      lessThan(tester.getTopLeft(schedule).dy),
    );
    expect(
      tester.getTopLeft(schedule).dy,
      lessThan(tester.getTopLeft(details).dy),
    );
  });
}
