import 'package:ezanvakti/core/models/alarm.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/screens/home_screen.dart';
import 'package:ezanvakti/presentation/widgets/common/app_nav_bar.dart';
import 'package:ezanvakti/presentation/widgets/common/main_tab_scaffold.dart';
import 'package:ezanvakti/presentation/widgets/home/upcoming_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../theme_harness.dart';

PrayerTime _day(DateTime date) {
  DateTime at(int hour, int minute) =>
      DateTime(date.year, date.month, date.day, hour, minute);
  return PrayerTime(
    fajr: at(4, 8),
    sunrise: at(5, 53),
    dhuhr: at(13, 15),
    asr: at(17, 10),
    maghrib: at(20, 27),
    isha: at(22, 4),
    date: DateTime(date.year, date.month, date.day),
  );
}

Future<void> _pumpHome(
  WidgetTester tester, {
  Size size = const Size(402, 874),
  double textScale = 1,
  bool hasReminders = false,
  Locale locale = const Locale('tr'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final today = _day(DateTime.now());
  final tomorrow = _day(today.date.add(const Duration(days: 1)));
  await tester.pumpWidget(
    wrapWithTheme(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          alwaysUse24HourFormat: true,
        ),
        child: MainTabScaffold(
          selectedIndex: 0,
          onChanged: (_) {},
          items: const [
            NavItem(label: 'Vakitler', icon: Icons.schedule_rounded),
            NavItem(label: 'Takvim', icon: Icons.calendar_month_rounded),
          ],
          children: [
            HomeScreen(
              location: const Location(
                id: '1',
                province: 'İstanbul',
                district: 'Kadıköy',
              ),
              todaysPrayerTime: today,
              tomorrowsPrayerTime: tomorrow,
              lastUpdateTime: today.date,
              prayerTimes: [today, tomorrow],
              alarms: hasReminders
                  ? const [
                      Alarm(
                        id: 'home-scroll-alarm',
                        kind: AlarmKind.fixed,
                        hour: 7,
                        label: 'Sabah hazırlığı',
                      ),
                    ]
                  : const [],
              notificationSettings: hasReminders
                  ? const [
                      NotificationSetting(
                        prayerType: PrayerType.dhuhr,
                        isActive: true,
                        minutesBefore: 45,
                        label: 'Namaz hazırlığı',
                      ),
                    ]
                  : const [],
            ),
            const Center(child: Text('calendar-page')),
          ],
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pump();
}

Finder _verticalScrollable() => find.descendant(
  of: find.byType(HomeScreen),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
  });

  testWidgets(
    'sığan ana ekran çekiştirilince yerinden oynamaz',
    (tester) async {
      await _pumpHome(tester);
      final scroll = tester
          .state<ScrollableState>(_verticalScrollable())
          .position;
      expect(scroll.maxScrollExtent, 0);

      final gesture = await tester.startGesture(
        tester.getCenter(_verticalScrollable()),
      );
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -130));
      await tester.pump();
      expect(scroll.pixels, 0);
      await gesture.up();
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'taşan içerik yukarı kayar, yenilemede ve sekmeye dönünce konumu korur',
    (tester) async {
      await _pumpHome(tester, size: const Size(360, 520), hasReminders: true);
      final scroll = tester
          .state<ScrollableState>(_verticalScrollable())
          .position;
      expect(scroll.maxScrollExtent, greaterThan(0));
      final initialTop = tester.getTopLeft(find.byType(UpcomingCard)).dy;

      await tester.drag(_verticalScrollable(), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(scroll.pixels, greaterThan(0));
      expect(
        tester.getTopLeft(find.byType(UpcomingCard)).dy,
        lessThan(initialTop),
      );
      final offset = scroll.pixels;
      await tester.pump(const Duration(seconds: 11));
      expect(scroll.pixels, closeTo(offset, 0.1));

      await tester.tap(find.text('Takvim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vakitler'));
      await tester.pumpAndSettle();
      expect(scroll.pixels, closeTo(offset, 0.1));

      scroll.jumpTo(scroll.maxScrollExtent);
      final gesture = await tester.startGesture(
        tester.getCenter(_verticalScrollable()),
      );
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -130));
      await tester.pump();
      expect(scroll.pixels, lessThanOrEqualTo(scroll.maxScrollExtent));
      await gesture.up();
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final locale in [const Locale('tr'), const Locale('ar')]) {
    testWidgets(
      '${locale.languageCode} dar ekranda yüzde 200 metinle tüm içeriğe kaydırılır',
      (tester) async {
        await _pumpHome(
          tester,
          size: const Size(320, 480),
          textScale: 2,
          hasReminders: true,
          locale: locale,
        );
        expect(tester.takeException(), isNull);
        final scroll = tester
            .state<ScrollableState>(_verticalScrollable())
            .position;
        expect(scroll.maxScrollExtent, greaterThan(0));
        await tester.drag(_verticalScrollable(), const Offset(0, -900));
        await tester.pumpAndSettle();
        expect(find.text('Sabah hazırlığı').hitTestable(), findsOneWidget);
        expect(find.text('Namaz hazırlığı').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
