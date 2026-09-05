import 'package:flutter_test/flutter_test.dart';
import 'package:ezanvakti/core/interfaces/widget_publisher.dart';
import 'package:ezanvakti/core/models/appearance_settings.dart';
import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/utils/app_logger.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot.dart';
import 'package:ezanvakti/features/home_widget/domain/widget_snapshot_publish.dart';

class _ThrowingPublisher implements WidgetPublisher {
  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    throw StateError('App Group yazilamadi');
  }

  @override
  Future<void> publishTimeFormat(String storageValue) async {}

  @override
  Future<void> publishAppearance(AppearanceSettings settings) async {}
}

class _RecordingPublisher implements WidgetPublisher {
  WidgetSnapshot? published;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async {
    published = snapshot;
  }

  @override
  Future<void> publishTimeFormat(String storageValue) async {}

  @override
  Future<void> publishAppearance(AppearanceSettings settings) async {}
}

const _location = Location(
  id: 'loc-1',
  province: 'İstanbul',
  district: 'Kadıköy',
);

PrayerTime _day(DateTime date) => PrayerTime(
  date: date,
  fajr: DateTime(date.year, date.month, date.day, 4, 12),
  sunrise: DateTime(date.year, date.month, date.day, 5, 52),
  dhuhr: DateTime(date.year, date.month, date.day, 13, 15),
  asr: DateTime(date.year, date.month, date.day, 16, 58),
  maghrib: DateTime(date.year, date.month, date.day, 20, 26),
  isha: DateTime(date.year, date.month, date.day, 21, 58),
);

void main() {
  final today = DateTime(2026, 8, 25);

  test('yayinlama basarili oldugunda snapshot iletilir', () async {
    final publisher = _RecordingPublisher();

    await publishWidgetSnapshot(
      publisher: publisher,
      logger: AppLogger(),
      location: _location,
      prayerTimes: [_day(today)],
      now: DateTime(2026, 8, 25, 14, 0),
    );

    expect(publisher.published?.days.length, 1);
  });

  test('yayinlama patlarsa hata yukari sizmaz', () async {
    await expectLater(
      publishWidgetSnapshot(
        publisher: _ThrowingPublisher(),
        logger: AppLogger(),
        location: _location,
        prayerTimes: [_day(today)],
        now: DateTime(2026, 8, 25, 14, 0),
      ),
      completes,
    );
  });

  test('konum yoksa yayinlama yapilmaz', () async {
    final publisher = _RecordingPublisher();

    await publishWidgetSnapshot(
      publisher: publisher,
      logger: AppLogger(),
      location: null,
      prayerTimes: [_day(today)],
      now: DateTime(2026, 8, 25, 14, 0),
    );

    expect(publisher.published, isNull);
  });
}
