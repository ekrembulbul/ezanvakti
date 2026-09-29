import 'dart:async';

import 'package:ezanvakti/core/models/location.dart';
import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/presentation/controllers/calendar_month_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

const location = Location(id: 'test', province: 'İstanbul', district: 'Fatih');

List<PrayerTime> monthDays(DateTime month) => [
  for (var day = 1; day <= DateTime(month.year, month.month + 1, 0).day; day++)
    prayerTimeFor(DateTime(month.year, month.month, day)),
];

void main() {
  test(
    'acilista bu ay yuklenir; aralik bu yilin Ocagi ile gelecek yilin Araligi',
    () async {
      final requests = <({DateTime month, bool force})>[];
      final controller = CalendarMonthController(
        loader:
            ({required location, required month, forceRefresh = false}) async {
              requests.add((month: month, force: forceRefresh));
              return monthDays(month);
            },
        now: DateTime(2026, 9, 15, 23, 30),
      );

      expect(controller.month, DateTime(2026, 9));
      expect(controller.firstMonth, DateTime(2026, 1));
      expect(controller.lastMonth, DateTime(2027, 12));
      expect(controller.isUnavailable, isFalse, reason: 'henuz yuklenmedi');

      await controller.updateSource(location, 0);

      expect(requests, [(month: DateTime(2026, 9), force: false)]);
      expect(controller.days, hasLength(30));
      expect(controller.loadedMonth, DateTime(2026, 9));
      expect(controller.canShare, isTrue);
      controller.dispose();
    },
  );

  test('sinirda gecis yok: Ocak geri, gelecek yilin Araligi ileri', () async {
    final requested = <DateTime>[];
    final controller = CalendarMonthController(
      loader:
          ({required location, required month, forceRefresh = false}) async {
            requested.add(month);
            return monthDays(month);
          },
      now: DateTime(2026, 1, 20),
    );
    await controller.updateSource(location, 0);

    expect(controller.canGoPrevious, isFalse);
    expect(controller.canGoNext, isTrue);
    await controller.previous();
    expect(controller.month, DateTime(2026, 1));

    await controller.selectMonth(DateTime(2027, 12, 15));
    expect(controller.month, DateTime(2027, 12));
    expect(controller.canGoNext, isFalse);
    expect(controller.canGoPrevious, isTrue);

    await controller.next();
    await controller.selectMonth(DateTime(2028, 1));
    await controller.selectMonth(DateTime(2025, 12));
    expect(controller.month, DateTime(2027, 12));
    expect(requested, [DateTime(2026, 1), DateTime(2027, 12)]);
    controller.dispose();
  });

  test('Araliktan ileri gelecek yilin Ocagina gecer', () async {
    final controller = CalendarMonthController(
      loader:
          ({required location, required month, forceRefresh = false}) async =>
              monthDays(month),
      now: DateTime(2026, 12, 3),
    );
    await controller.updateSource(location, 0);
    await controller.next();
    expect(controller.month, DateTime(2027, 1));
    expect(controller.days.first.date, DateTime(2027, 1, 1));
    controller.dispose();
  });

  test(
    'hizli geciste yalniz son ayin yaniti uygulanir; eski gunler yuklenirken kalir',
    () async {
      final requests =
          <({DateTime month, Completer<List<PrayerTime>> response})>[];
      final controller = CalendarMonthController(
        loader: ({required location, required month, forceRefresh = false}) {
          final response = Completer<List<PrayerTime>>();
          requests.add((month: month, response: response));
          return response.future;
        },
        now: DateTime(2026, 9, 15),
      );
      final first = controller.updateSource(location, 0);
      requests[0].response.complete(monthDays(DateTime(2026, 9)));
      await first;

      final october = controller.next();
      final november = controller.next();
      expect(controller.month, DateTime(2026, 11));
      expect(controller.isLoading, isTrue);
      expect(
        controller.days.first.date.month,
        9,
        reason: 'onceki ayin tablosu yeni ay gelene kadar kalir',
      );
      expect(controller.canShare, isFalse);

      requests[2].response.complete(monthDays(DateTime(2026, 11)));
      await november;
      requests[1].response.complete(monthDays(DateTime(2026, 10)));
      await october;

      expect(requests.map((r) => r.month).toList(), [
        DateTime(2026, 9),
        DateTime(2026, 10),
        DateTime(2026, 11),
      ]);
      expect(controller.loadedMonth, DateTime(2026, 11));
      expect(controller.days.first.date, DateTime(2026, 11, 1));
      expect(controller.days, hasLength(30));
      expect(controller.isLoading, isFalse);
      controller.dispose();
    },
  );

  test('bos sonuc "yayimlanmadi" durumudur, hata degildir', () async {
    final controller = CalendarMonthController(
      loader:
          ({required location, required month, forceRefresh = false}) async =>
              const [],
      now: DateTime(2026, 9, 15),
    );
    final load = controller.updateSource(location, 0);
    expect(controller.isUnavailable, isFalse, reason: 'yukleniyor');
    await load;

    expect(controller.isUnavailable, isTrue);
    expect(controller.error, isNull);
    expect(controller.canShare, isFalse);
    controller.dispose();
  });

  test('hata: gunler temizlenir, refresh ayi zorla yeniden yukler', () async {
    final calls = <({DateTime month, bool force})>[];
    var failOctober = true;
    final controller = CalendarMonthController(
      loader:
          ({required location, required month, forceRefresh = false}) async {
            calls.add((month: month, force: forceRefresh));
            if (month == DateTime(2026, 10) && failOctober) {
              throw Exception('offline');
            }
            return monthDays(month);
          },
      now: DateTime(2026, 9, 15),
    );
    await controller.updateSource(location, 0);
    await controller.next();

    expect(controller.error, isNotNull);
    expect(
      controller.days,
      isEmpty,
      reason: 'eylul tablosu ekim etiketiyle kalmamali',
    );
    expect(controller.isUnavailable, isFalse);
    expect(controller.canShare, isFalse);

    failOctober = false;
    await controller.refresh();

    expect(calls.last, (month: DateTime(2026, 10), force: true));
    expect(controller.error, isNull);
    expect(controller.days, hasLength(31));
    controller.dispose();
  });

  test(
    'ayni kaynak yeniden yuklemez; konum ya da duzeltme degisince ayni ay yeniden yuklenir',
    () async {
      final requested = <DateTime>[];
      final controller = CalendarMonthController(
        loader:
            ({required location, required month, forceRefresh = false}) async {
              requested.add(month);
              return monthDays(month);
            },
        now: DateTime(2026, 9, 15),
      );
      await controller.updateSource(location, 0);
      await controller.updateSource(location, 0);
      expect(requested, [DateTime(2026, 9)]);

      await controller.next();
      final reload = controller.updateSource(location, 1);
      expect(
        controller.days,
        isEmpty,
        reason: 'eski duzeltmeyle okunmus gunler gosterilmez',
      );
      await reload;
      expect(requested, [
        DateTime(2026, 9),
        DateTime(2026, 10),
        DateTime(2026, 10),
      ]);

      await controller.updateSource(location.copyWith(latitude: 42), 1);
      expect(requested, hasLength(4));
      controller.dispose();
    },
  );

  test('dispose sonrasi gelen yanit bildirim uretmez', () async {
    final pending = Completer<List<PrayerTime>>();
    final controller = CalendarMonthController(
      loader: ({required location, required month, forceRefresh = false}) =>
          pending.future,
      now: DateTime(2026, 9, 15),
    );
    var notified = 0;
    controller.addListener(() => notified++);
    final load = controller.updateSource(location, 0);
    expect(notified, 1);

    controller.dispose();
    pending.complete(monthDays(DateTime(2026, 9)));
    await load;
    expect(notified, 1);
  });
}
