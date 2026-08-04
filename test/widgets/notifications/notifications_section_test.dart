import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/presentation/widgets/reminders/notifications_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

void main() {
  const dhuhr = NotificationSetting(
    prayerType: PrayerType.dhuhr,
    isActive: true,
    minutesBefore: 0,
  );
  const fajr = NotificationSetting(
    prayerType: PrayerType.fajr,
    isActive: true,
    minutesBefore: 15,
  );

  Widget build({
    List<NotificationSetting> settings = const [dhuhr],
    bool hasPermission = true,
    bool exactAlarmAllowed = true,
    ValueChanged<NotificationSetting>? onToggle,
  }) => wrapWithTheme(
    NotificationsSection(
      settings: settings,
      hasPermission: hasPermission,
      exactAlarmAllowed: exactAlarmAllowed,
      onPermissionChanged: (_) {},
      onOpenExactAlarmSettings: () {},
      onToggle: onToggle ?? (_) {},
      onEdit: (_) {},
      onDelete: (_) async {},
    ),
  );

  testWidgets('Ayarlar vakit sirasina gore cizilir', (tester) async {
    await tester.pumpWidget(build(settings: const [dhuhr, fajr]));

    final fajrY = tester.getTopLeft(find.text('İmsak')).dy;
    final dhuhrY = tester.getTopLeft(find.text('Öğle')).dy;

    expect(fajrY, lessThan(dhuhrY));
  });

  testWidgets('Sayac satiri kayit sayisini gosterir', (tester) async {
    await tester.pumpWidget(build(settings: const [dhuhr, fajr]));

    // SectionLabel metni kendisi buyutur (Turkce i → İ kuralIyla).
    expect(find.text('2 HATIRLATMA'), findsOneWidget);
  });

  testWidgets('Liste bossa bos durum cizilir', (tester) async {
    await tester.pumpWidget(build(settings: const []));

    expect(find.text('Henüz bildirim yok'), findsOneWidget);
  });

  testWidgets('Exact alarm kapaliysa banner gorunur', (tester) async {
    await tester.pumpWidget(build(exactAlarmAllowed: false));

    expect(
      find.text('Tam zamanlı alarm kapalı. Bildirimler gecikebilir.'),
      findsOneWidget,
    );
  });

  testWidgets('Izin varken izin uyarisi cizilmez', (tester) async {
    await tester.pumpWidget(build());

    expect(find.text('Henüz bildirim yok'), findsNothing);
    expect(find.text('1 HATIRLATMA'), findsOneWidget);
  });

  testWidgets('Anahtar onToggle i cagirir', (tester) async {
    final toggled = <NotificationSetting>[];
    await tester.pumpWidget(build(onToggle: toggled.add));

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(toggled, [dhuhr]);
  });
}
