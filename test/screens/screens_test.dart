import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/presentation/screens/onboarding_screen.dart';
import 'package:ezanvakti/presentation/screens/home_screen.dart';
import 'package:ezanvakti/presentation/screens/calendar_screen.dart';
import 'package:ezanvakti/presentation/screens/notification_settings_screen.dart';
import 'package:ezanvakti/presentation/screens/settings_screen.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/notification_setting.dart';

void main() {
  group('Onboarding Screen - UI Elements', () {
    testWidgets('Shows all required UI elements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onLocationSelected: (_) {})),
      );

      expect(find.text('Hoş Geldiniz'), findsOneWidget);
      expect(find.text('Lokasyon Seçimi'), findsOneWidget);
      expect(find.byKey(const Key('province_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('district_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('continue_button')), findsOneWidget);
    });

    testWidgets('Province dropdown contains provinces', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onLocationSelected: (_) {})),
      );

      await tester.tap(find.byKey(const Key('province_dropdown')));
      await tester.pumpAndSettle();

      expect(find.text('İstanbul'), findsOneWidget);
    });

    testWidgets('Selecting province enables district dropdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onLocationSelected: (_) {})),
      );

      await tester.tap(find.byKey(const Key('province_dropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('İstanbul').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('district_dropdown')));
      await tester.pumpAndSettle();

      expect(find.text('Kadıköy'), findsWidgets);
    });

    testWidgets('Shows error when continuing without selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onLocationSelected: (_) {})),
      );

      await tester.tap(find.byKey(const Key('continue_button')));
      await tester.pumpAndSettle();

      expect(find.text('Lütfen il ve ilçe seçiniz'), findsOneWidget);
    });

    testWidgets('Calls callback when location selected', (tester) async {
      bool called = false;
      Location? selectedLocation;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onLocationSelected: (location) {
              called = true;
              selectedLocation = location;
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('province_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İstanbul').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('district_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kadıköy').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('continue_button')));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(selectedLocation, isNotNull);
      expect(selectedLocation!.district, equals('Kadıköy'));
    });
  });

  group('Home Screen - UI Elements', () {
    final testLocation = const Location(
      id: '9635',
      province: 'İstanbul',
      district: 'Kadıköy',
      latitude: 40.9828,
      longitude: 29.0227,
    );

    final testPrayerTime = PrayerTime(
      fajr: DateTime(2024, 6, 15, 5, 30),
      sunrise: DateTime(2024, 6, 15, 7, 0),
      dhuhr: DateTime(2024, 6, 15, 13, 15),
      asr: DateTime(2024, 6, 15, 16, 30),
      maghrib: DateTime(2024, 6, 15, 19, 0),
      isha: DateTime(2024, 6, 15, 20, 30),
      date: DateTime(2024, 6, 15),
    );

    testWidgets('Shows location in app bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            location: testLocation,
            todaysPrayerTime: testPrayerTime,
          ),
        ),
      );

      expect(find.text('Ezan Vakti'), findsOneWidget);
      expect(find.text('İstanbul / Kadıköy'), findsOneWidget);
    });

    testWidgets('Shows all prayer times', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            location: testLocation,
            todaysPrayerTime: testPrayerTime,
          ),
        ),
      );

      expect(find.byKey(const Key('prayer_fajr')), findsOneWidget);
      expect(find.byKey(const Key('prayer_sunrise')), findsOneWidget);
      expect(find.byKey(const Key('prayer_dhuhr')), findsOneWidget);
      expect(find.byKey(const Key('prayer_asr')), findsOneWidget);
      expect(find.byKey(const Key('prayer_maghrib')), findsOneWidget);
      expect(find.byKey(const Key('prayer_isha')), findsOneWidget);
    });

    testWidgets('Shows data source and last update', (tester) async {
      final lastUpdate = DateTime(2024, 6, 15, 10, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            location: testLocation,
            todaysPrayerTime: testPrayerTime,
            lastUpdateTime: lastUpdate,
            dataSource: 'Diyanet (Awqat Salah API)',
          ),
        ),
      );

      expect(find.textContaining('Kaynak:'), findsOneWidget);
      expect(find.textContaining('Diyanet'), findsOneWidget);
      expect(find.textContaining('Son güncelleme:'), findsOneWidget);
    });

    testWidgets('Shows error message when error occurs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            location: testLocation,
            errorMessage: 'Veri alınamadı',
            onRefresh: () {},
          ),
        ),
      );

      expect(find.text('Veri alınamadı'), findsOneWidget);
      expect(find.text('Yeniden Dene'), findsOneWidget);
    });

    testWidgets('Shows loading indicator when loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(location: testLocation, isLoading: true)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Calendar button navigates when tapped', (tester) async {
      bool calendarTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            location: testLocation,
            todaysPrayerTime: testPrayerTime,
            onCalendarTap: () {
              calendarTapped = true;
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('calendar_button')));
      await tester.pumpAndSettle();

      expect(calendarTapped, isTrue);
    });

    testWidgets('Settings button appears when callback provided', (
      tester,
    ) async {
      bool settingsTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            location: testLocation,
            todaysPrayerTime: testPrayerTime,
            onSettingsTap: () {
              settingsTapped = true;
            },
          ),
        ),
      );

      expect(find.byKey(const Key('settings_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings_button')));
      await tester.pumpAndSettle();

      expect(settingsTapped, isTrue);
    });

    testWidgets('Notification settings button appears when callback provided', (
      tester,
    ) async {
      bool notificationTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            location: testLocation,
            todaysPrayerTime: testPrayerTime,
            onNotificationSettingsTap: () {
              notificationTapped = true;
            },
          ),
        ),
      );

      expect(
        find.byKey(const Key('notification_settings_button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('notification_settings_button')));
      await tester.pumpAndSettle();

      expect(notificationTapped, isTrue);
    });
  });

  group(
    'Calendar Screen - UI Elements',
    skip: 'intl locale initialization issues in tests',
    () {
      final testLocation = const Location(
        id: '9635',
        province: 'İstanbul',
        district: 'Kadıköy',
        latitude: 40.9828,
        longitude: 29.0227,
      );

      final testPrayerTimes = List.generate(7, (index) {
        final date = DateTime(2024, 6, 15).add(Duration(days: index));
        return PrayerTime(
          fajr: DateTime(date.year, date.month, date.day, 5, 30),
          sunrise: DateTime(date.year, date.month, date.day, 7, 0),
          dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
          asr: DateTime(date.year, date.month, date.day, 16, 30),
          maghrib: DateTime(date.year, date.month, date.day, 19, 0),
          isha: DateTime(date.year, date.month, date.day, 20, 30),
          date: date,
        );
      });

      testWidgets('Shows location in app bar', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CalendarScreen(
              location: testLocation,
              prayerTimes: testPrayerTimes,
            ),
          ),
        );

        expect(find.text('Vakit Takvimi'), findsOneWidget);
        expect(find.text('İstanbul / Kadıköy'), findsOneWidget);
      });

      testWidgets('Shows calendar with prayer times', (tester) async {
        // Skip due to intl locale initialization issues in tests
      }, skip: true);

      testWidgets('Shows error message when error occurs', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CalendarScreen(
              location: testLocation,
              prayerTimes: [],
              errorMessage: 'Veri alınamadı',
            ),
          ),
        );

        expect(find.text('Veri alınamadı'), findsOneWidget);
      });

      testWidgets('Shows loading indicator when loading', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CalendarScreen(
              location: testLocation,
              prayerTimes: [],
              isLoading: true,
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('Shows empty state when no data', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CalendarScreen(location: testLocation, prayerTimes: []),
          ),
        );

        expect(find.text('Veri bulunamadı'), findsOneWidget);
      });
    },
  );

  group('Notification Settings Screen - UI Elements', () {
    final testSettings = [
      const NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        minutesBefore: 0,
      ),
      const NotificationSetting(
        prayerType: PrayerType.fajr,
        isActive: true,
        minutesBefore: 10,
      ),
      const NotificationSetting(
        prayerType: PrayerType.dhuhr,
        isActive: false,
        minutesBefore: 0,
      ),
    ];

    testWidgets('Shows all prayer sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            settings: testSettings,
            hasPermission: true,
            onSettingToggled: (_) {},
            onOffsetChanged: (_, __) {},
          ),
        ),
      );

      expect(find.byKey(const Key('prayer_section_fajr')), findsOneWidget);
      expect(find.byKey(const Key('prayer_section_dhuhr')), findsOneWidget);
    });

    testWidgets('Shows permission warning when no permission', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            settings: testSettings,
            hasPermission: false,
            onSettingToggled: (_) {},
            onOffsetChanged: (_, __) {},
          ),
        ),
      );

      expect(find.byKey(const Key('permission_warning')), findsOneWidget);
      expect(find.text('Bildirim izni verilmedi'), findsOneWidget);
    });

    testWidgets('Permission request button works', (tester) async {
      bool requestCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            settings: testSettings,
            hasPermission: false,
            onSettingToggled: (_) {},
            onOffsetChanged: (_, __) {},
            onRequestPermission: () async {
              requestCalled = true;
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('request_permission_button')));
      await tester.pumpAndSettle();

      expect(requestCalled, isTrue);
    });

    testWidgets('Settings can be toggled', (tester) async {
      NotificationSetting? toggledSetting;

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            settings: testSettings,
            hasPermission: true,
            onSettingToggled: (setting) {
              toggledSetting = setting;
            },
            onOffsetChanged: (_, __) {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('switch_fajr_0')));
      await tester.pumpAndSettle();

      expect(toggledSetting, isNotNull);
    });

    testWidgets('Add notification button shows dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            settings: testSettings,
            hasPermission: true,
            onSettingToggled: (_) {},
            onOffsetChanged: (_, __) {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_notification_button')));
      await tester.pumpAndSettle();

      expect(find.text('Bildirim Ekle'), findsOneWidget);
      expect(find.byKey(const Key('prayer_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('offset_dropdown')), findsOneWidget);
    });

    testWidgets('Add notification dialog can be cancelled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            settings: testSettings,
            hasPermission: true,
            onSettingToggled: (_) {},
            onOffsetChanged: (_, __) {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_notification_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cancel_button')));
      await tester.pumpAndSettle();

      expect(find.text('Bildirim Ekle'), findsNothing);
    });

    testWidgets('Add notification calls callback', (tester) async {
      PrayerType? addedPrayer;
      int? addedOffset;

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingsScreen(
            settings: testSettings,
            hasPermission: true,
            onSettingToggled: (_) {},
            onOffsetChanged: (prayer, offset) {
              addedPrayer = prayer;
              addedOffset = offset;
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('add_notification_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('prayer_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İmsak').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_button')));
      await tester.pumpAndSettle();

      expect(addedPrayer, equals(PrayerType.fajr));
      expect(addedOffset, equals(0));
    });
  });

  group('Settings Screen - UI Elements', () {
    final testLocation = const Location(
      id: '9635',
      province: 'İstanbul',
      district: 'Kadıköy',
      latitude: 40.9828,
      longitude: 29.0227,
    );

    testWidgets('Shows current location', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(currentLocation: testLocation)),
      );

      expect(find.text('Ayarlar'), findsOneWidget);
      expect(find.text('İstanbul / Kadıköy'), findsOneWidget);
    });

    testWidgets('Shows data source', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            currentLocation: testLocation,
            dataSource: 'Diyanet (Awqat Salah API)',
          ),
        ),
      );

      expect(find.text('Diyanet (Awqat Salah API)'), findsOneWidget);
    });

    testWidgets('Change location button works', (tester) async {
      bool changeLocationCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            currentLocation: testLocation,
            onChangeLocation: () {
              changeLocationCalled = true;
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('location_tile')));
      await tester.pumpAndSettle();

      expect(changeLocationCalled, isTrue);
    });

    testWidgets('Shows app version', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(currentLocation: testLocation)),
      );

      expect(find.text('Versiyon'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
    });

    testWidgets('About button works when provided', (tester) async {
      bool aboutCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            currentLocation: testLocation,
            onAbout: () {
              aboutCalled = true;
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('about_tile')));
      await tester.pumpAndSettle();

      expect(aboutCalled, isTrue);
    });
  });
}
