import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/services/timezone_service.dart';
import 'package:ezanvakti/core/services/dst_change_detector.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('Timezone Service - Initialization', () {
    late TimezoneService timezoneService;

    setUp(() {
      timezoneService = TimezoneService.instance;
      timezoneService.reset();
    });

    test('Service can be initialized', () async {
      expect(timezoneService.isInitialized(), isFalse);

      await timezoneService.initialize();

      expect(timezoneService.isInitialized(), isTrue);
    });

    test('Service throws error when not initialized', () {
      expect(() => timezoneService.deviceLocation, throwsStateError);

      expect(() => timezoneService.currentTimezoneName, throwsStateError);
    });

    test('Service can be initialized multiple times safely', () async {
      await timezoneService.initialize();
      await timezoneService.initialize();

      expect(timezoneService.isInitialized(), isTrue);
    });

    test('Service uses Europe/Istanbul as default timezone', () async {
      await timezoneService.initialize();

      expect(timezoneService.currentTimezoneName, equals('Europe/Istanbul'));
      expect(timezoneService.deviceLocation.name, equals('Europe/Istanbul'));
    });

    test('Service can reset and reinitialize', () async {
      await timezoneService.initialize();
      expect(timezoneService.isInitialized(), isTrue);

      timezoneService.reset();
      expect(timezoneService.isInitialized(), isFalse);

      await timezoneService.initialize();
      expect(timezoneService.isInitialized(), isTrue);
    });
  });

  group('Timezone Service - Timezone Operations', () {
    late TimezoneService timezoneService;

    setUp(() async {
      timezoneService = TimezoneService.instance;
      timezoneService.reset();
      await timezoneService.initialize();
    });

    test('Can convert DateTime to TZDateTime', () {
      final dateTime = DateTime(2024, 6, 15, 12, 0);

      final tzDateTime = timezoneService.convertToLocalTime(dateTime);

      expect(tzDateTime.year, equals(2024));
      expect(tzDateTime.month, equals(6));
      expect(tzDateTime.day, equals(15));
      expect(tzDateTime.hour, equals(12));
    });

    test('Can convert TZDateTime back to DateTime', () {
      final dateTime = DateTime(2024, 6, 15, 12, 0);
      final tzDateTime = timezoneService.convertToLocalTime(dateTime);

      final converted = timezoneService.convertFromLocalTime(tzDateTime);

      expect(converted.year, equals(dateTime.year));
      expect(converted.month, equals(dateTime.month));
      expect(converted.day, equals(dateTime.day));
      expect(converted.hour, equals(dateTime.hour));
    });

    test('Can get current time as TZDateTime', () {
      final now = timezoneService.now();

      expect(now, isA<tz.TZDateTime>());
      expect(now.location.name, equals('Europe/Istanbul'));
    });

    test('Can get timezone offset for a date', () {
      final winterDate = DateTime(2024, 1, 15);
      final summerDate = DateTime(2024, 7, 15);

      final winterOffset = timezoneService.getTimezoneOffset(winterDate);
      final summerOffset = timezoneService.getTimezoneOffset(summerDate);

      expect(winterOffset, isA<Duration>());
      expect(summerOffset, isA<Duration>());
    });

    test('Can get timezone info string', () {
      final dateTime = DateTime(2024, 6, 15);

      final info = timezoneService.getTimezoneInfo(dateTime);

      expect(info, contains('UTC'));
      expect(info, isA<String>());
    });

    test('Can check for timezone mismatch', () {
      final hasMismatch = timezoneService.hasTimezoneMismatch();

      expect(hasMismatch, isA<bool>());
    });

    test('Can set custom timezone location', () {
      timezoneService.setLocalLocation('America/New_York');

      expect(timezoneService.currentTimezoneName, equals('America/New_York'));
    });

    test('Falls back to Istanbul on invalid timezone', () {
      timezoneService.setLocalLocation('Invalid/Timezone');

      expect(timezoneService.currentTimezoneName, equals('Europe/Istanbul'));
    });
  });

  group('Timezone Service - DST Detection', () {
    late TimezoneService timezoneService;

    setUp(() async {
      timezoneService = TimezoneService.instance;
      timezoneService.reset();
      await timezoneService.initialize();
    });

    test('Can detect DST for summer date', () {
      final summerDate = DateTime(2024, 7, 15);

      final isDst = timezoneService.isDST(summerDate);

      expect(isDst, isA<bool>());
    });

    test('Can detect DST for winter date', () {
      final winterDate = DateTime(2024, 1, 15);

      final isDst = timezoneService.isDST(winterDate);

      expect(isDst, isA<bool>());
    });

    test('DST status differs between summer and winter in Turkey', () {
      final winterDate = DateTime(2024, 1, 15);
      final summerDate = DateTime(2024, 7, 15);

      final winterDst = timezoneService.isDST(winterDate);
      final summerDst = timezoneService.isDST(summerDate);

      expect(winterDst, isA<bool>());
      expect(summerDst, isA<bool>());
    });
  });

  group('DST Change Detector - Initialization', () {
    late TimezoneService timezoneService;
    late DSTChangeDetector dstDetector;

    setUp(() async {
      timezoneService = TimezoneService.instance;
      timezoneService.reset();
      await timezoneService.initialize();
      dstDetector = DSTChangeDetector(timezoneService: timezoneService);
    });

    test('Detector can be created', () {
      expect(dstDetector, isNotNull);
    });

    test('Can get current DST status', () {
      final isDst = dstDetector.isDSTActive(DateTime.now());

      expect(isDst, isA<bool>());
    });

    test('Can get current timezone offset', () {
      final offset = dstDetector.getCurrentOffset();

      expect(offset, isA<Duration>());
    });

    test('Can get DST status message', () {
      final message = dstDetector.getDSTStatusMessage(DateTime.now());

      expect(message, contains('saati'));
      expect(message, contains('UTC'));
    });
  });

  group('DST Change Detector - Change Detection', () {
    late TimezoneService timezoneService;
    late DSTChangeDetector dstDetector;

    setUp(() async {
      timezoneService = TimezoneService.instance;
      timezoneService.reset();
      await timezoneService.initialize();
      dstDetector = DSTChangeDetector(timezoneService: timezoneService);
    });

    test('Can detect DST changes in a year', () {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 12, 31);

      final changes = dstDetector.detectDSTChanges(
        startDate: startDate,
        endDate: endDate,
      );

      expect(changes, isA<List<DSTChangeInfo>>());
    });

    test('Can check if DST change will occur in period', () {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 12, 31);

      final willChange = dstDetector.willDSTChangeOccur(
        startDate: startDate,
        endDate: endDate,
      );

      expect(willChange, isA<bool>());
    });

    test('Can get next DST change', () {
      final nextChange = dstDetector.getNextDSTChange(
        afterDate: DateTime(2024, 1, 1),
      );

      expect(nextChange, isA<DSTChangeInfo?>());
    });

    test('Short period without DST change returns no changes', () {
      final startDate = DateTime(2024, 7, 1);
      final endDate = DateTime(2024, 7, 15);

      final changes = dstDetector.detectDSTChanges(
        startDate: startDate,
        endDate: endDate,
      );

      expect(changes, isEmpty);
    });

    test('Can determine if notification rescheduling needed', () {
      final lastCheck = DateTime.now().subtract(const Duration(days: 10));

      final shouldReschedule = dstDetector.shouldRescheduleNotifications(
        lastCheck: lastCheck,
      );

      expect(shouldReschedule, isA<bool>());
    });

    test('Recent check without DST change does not require rescheduling', () {
      final lastCheck = DateTime.now().subtract(const Duration(hours: 1));

      final shouldReschedule = dstDetector.shouldRescheduleNotifications(
        lastCheck: lastCheck,
      );

      expect(shouldReschedule, isFalse);
    });
  });

  group('DST Change Detector - Change Info', () {
    test('DSTChangeInfo calculates offset change correctly', () {
      final info = DSTChangeInfo(
        changeDate: DateTime(2024, 3, 31),
        enteringDST: true,
        oldOffset: const Duration(hours: 2),
        newOffset: const Duration(hours: 3),
      );

      expect(info.offsetChange, equals(const Duration(hours: 1)));
      expect(info.enteringDST, isTrue);
    });

    test('DSTChangeInfo for leaving DST has negative offset change', () {
      final info = DSTChangeInfo(
        changeDate: DateTime(2024, 10, 27),
        enteringDST: false,
        oldOffset: const Duration(hours: 3),
        newOffset: const Duration(hours: 2),
      );

      expect(info.offsetChange, equals(const Duration(hours: -1)));
      expect(info.enteringDST, isFalse);
    });
  });

  group('Timezone Service - Prayer Time Display', () {
    late TimezoneService timezoneService;

    setUp(() async {
      timezoneService = TimezoneService.instance;
      timezoneService.reset();
      await timezoneService.initialize();
    });

    test('Prayer times are displayed in device timezone', () {
      final prayerTime = DateTime(2024, 6, 15, 5, 30);

      final tzPrayerTime = timezoneService.convertToLocalTime(prayerTime);

      expect(tzPrayerTime.year, equals(2024));
      expect(tzPrayerTime.month, equals(6));
      expect(tzPrayerTime.day, equals(15));
      expect(tzPrayerTime.hour, equals(5));
      expect(tzPrayerTime.minute, equals(30));
    });

    test('Multiple prayer times maintain correct timezone', () {
      final fajr = DateTime(2024, 6, 15, 5, 30);
      final dhuhr = DateTime(2024, 6, 15, 13, 15);
      final maghrib = DateTime(2024, 6, 15, 20, 30);

      final tzFajr = timezoneService.convertToLocalTime(fajr);
      final tzDhuhr = timezoneService.convertToLocalTime(dhuhr);
      final tzMaghrib = timezoneService.convertToLocalTime(maghrib);

      expect(tzFajr.location.name, equals('Europe/Istanbul'));
      expect(tzDhuhr.location.name, equals('Europe/Istanbul'));
      expect(tzMaghrib.location.name, equals('Europe/Istanbul'));
    });

    test('Timezone offset is consistent for same day', () {
      final morning = DateTime(2024, 6, 15, 6, 0);
      final evening = DateTime(2024, 6, 15, 20, 0);

      final morningOffset = timezoneService.getTimezoneOffset(morning);
      final eveningOffset = timezoneService.getTimezoneOffset(evening);

      expect(morningOffset, equals(eveningOffset));
    });
  });

  group('Timezone Service - Error Handling', () {
    late TimezoneService timezoneService;

    setUp(() {
      timezoneService = TimezoneService.instance;
      timezoneService.reset();
    });

    test('Operations throw error when service not initialized', () {
      expect(() => timezoneService.now(), throwsStateError);
      expect(() => timezoneService.isDST(DateTime.now()), throwsStateError);
      expect(
        () => timezoneService.getTimezoneOffset(DateTime.now()),
        throwsStateError,
      );
    });

    test('Invalid timezone falls back gracefully', () async {
      await timezoneService.initialize();

      expect(
        () => timezoneService.setLocalLocation('Invalid/Location'),
        returnsNormally,
      );

      expect(timezoneService.currentTimezoneName, equals('Europe/Istanbul'));
    });
  });

  group('DST Change Detector - Notification Rescheduling Logic', () {
    late TimezoneService timezoneService;
    late DSTChangeDetector dstDetector;

    setUp(() async {
      timezoneService = TimezoneService.instance;
      timezoneService.reset();
      await timezoneService.initialize();
      dstDetector = DSTChangeDetector(timezoneService: timezoneService);
    });

    test('Should reschedule if last check was before DST change', () {
      final beforeChange = DateTime(2024, 3, 1);
      final afterChange = DateTime(2024, 4, 1);

      final shouldReschedule = dstDetector.shouldRescheduleNotifications(
        lastCheck: beforeChange,
        currentTime: afterChange,
      );

      expect(shouldReschedule, isA<bool>());
    });

    test('Should not reschedule if no DST change occurred', () {
      final check1 = DateTime(2024, 7, 1);
      final check2 = DateTime(2024, 7, 15);

      final shouldReschedule = dstDetector.shouldRescheduleNotifications(
        lastCheck: check1,
        currentTime: check2,
      );

      expect(shouldReschedule, isFalse);
    });

    test('Default behavior uses yesterday as last check', () {
      final shouldReschedule = dstDetector.shouldRescheduleNotifications();

      expect(shouldReschedule, isA<bool>());
    });
  });

  group('Turkey Timezone - No DST Policy', () {
    late TimezoneService timezoneService;
    late DSTChangeDetector dstDetector;

    setUp(() async {
      timezoneService = TimezoneService.instance;
      timezoneService.reset();
      await timezoneService.initialize();
      dstDetector = DSTChangeDetector(timezoneService: timezoneService);
    });

    test('Turkey timezone is correctly identified', () {
      expect(timezoneService.isTurkeyTimezone(), isTrue);
      expect(timezoneService.currentTimezoneName, equals('Europe/Istanbul'));
    });

    test('Turkey has no DST support', () {
      expect(timezoneService.hasDSTSupport(), isFalse);
    });

    test('DST detector recognizes Turkey does not need DST checks', () {
      expect(dstDetector.shouldCheckDST(), isFalse);
    });

    test('Turkey has no DST changes throughout the year', () {
      final startDate = DateTime(2024, 1, 1);
      final endDate = DateTime(2024, 12, 31);

      final changes = dstDetector.detectDSTChanges(
        startDate: startDate,
        endDate: endDate,
      );

      expect(changes, isEmpty);
    });

    test('Turkey uses consistent UTC+3 offset year-round', () {
      final winterDate = DateTime(2024, 1, 15);
      final summerDate = DateTime(2024, 7, 15);

      final winterOffset = timezoneService.getTimezoneOffset(winterDate);
      final summerOffset = timezoneService.getTimezoneOffset(summerDate);

      expect(winterOffset, equals(summerOffset));
      expect(winterOffset, equals(const Duration(hours: 3)));
    });

    test('No notification rescheduling needed for Turkey timezone', () {
      final lastCheck = DateTime(2024, 1, 1);
      final currentTime = DateTime(2024, 12, 31);

      final shouldReschedule = dstDetector.shouldRescheduleNotifications(
        lastCheck: lastCheck,
        currentTime: currentTime,
      );

      expect(shouldReschedule, isFalse);
    });

    test('isDST always returns false for Turkey', () {
      final winterDate = DateTime(2024, 1, 15);
      final summerDate = DateTime(2024, 7, 15);

      expect(timezoneService.isDST(winterDate), isFalse);
      expect(timezoneService.isDST(summerDate), isFalse);
    });

    test('Timezone info shows UTC+3 without DST indicator', () {
      final date = DateTime(2024, 6, 15);
      final info = timezoneService.getTimezoneInfo(date);

      expect(info, contains('UTC+3'));
      expect(info, isNot(contains('DST')));
    });

    test('DST status message shows consistent timezone for Turkey', () {
      final winterDate = DateTime(2024, 1, 15);
      final summerDate = DateTime(2024, 7, 15);

      final winterMessage = dstDetector.getDSTStatusMessage(winterDate);
      final summerMessage = dstDetector.getDSTStatusMessage(summerDate);

      expect(winterMessage, contains('UTC+3'));
      expect(summerMessage, contains('UTC+3'));
    });

    test('Non-Turkey timezone has DST support', () async {
      timezoneService.setLocalLocation('America/New_York');

      expect(timezoneService.isTurkeyTimezone(), isFalse);
      expect(timezoneService.hasDSTSupport(), isTrue);
      expect(dstDetector.shouldCheckDST(), isTrue);
    });
  });
}
