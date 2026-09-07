import 'package:ezanvakti/core/models/prayer_time.dart';
import 'package:ezanvakti/core/models/general_settings.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/core/utils/time_formatter.dart';
import 'package:ezanvakti/features/prayer_times/domain/kerahat_times.dart';
import 'package:ezanvakti/presentation/widgets/home/kerahat_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../theme_harness.dart';

const _sourceUrl =
    'https://kurul.diyanet.gov.tr/tr/fetva/mekruh-vakitler-hangileridir-hangi-vakitlerde-kaza-ve-hangi-vakitlerde-nafile-namaz-kilinmaz/0193c42d-52b7-7186-d5b4-f1d3c950ad73';

PrayerTime _times() {
  DateTime at(int hour, [int minute = 0]) => DateTime(2026, 8, 2, hour, minute);
  return PrayerTime(
    fajr: at(4),
    sunrise: at(6),
    dhuhr: at(13),
    asr: at(17),
    maghrib: at(20),
    isha: at(22),
    date: DateTime(2026, 8, 2),
  );
}

Future<void> _openDetails(
  WidgetTester tester, {
  Locale locale = const Locale('tr'),
  double textScale = 1,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final appState = AppState()
    ..setGeneralSettings(
      const GeneralSettings(timeFormat: TimeFormatPreference.h24),
    );
  addTearDown(appState.dispose);
  final opener = Builder(
    builder: (context) => TextButton(
      onPressed: () =>
          showKerahatDetails(context, intervals: KerahatTimes.forDay(_times())),
      child: const Text('open-details'),
    ),
  );
  await tester.pumpWidget(
    wrapWithTheme(opener, locale: locale, appState: appState),
  );
  await tester.tap(find.text('open-details'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dokununca uc aralik ve secilebilir Diyanet kaynagi acilir', (
    tester,
  ) async {
    await _openDetails(tester);

    expect(find.text('Kerahat vakitleri'), findsOneWidget);
    expect(find.text('Güneş sonrası'), findsOneWidget);
    expect(find.text('Öğle öncesi'), findsOneWidget);
    expect(find.text('Akşam öncesi'), findsOneWidget);
    expect(find.text('06:00–06:45'), findsOneWidget);
    expect(find.text('12:50–13:00'), findsOneWidget);
    expect(find.text('19:15–20:00'), findsOneWidget);
    expect(find.textContaining('45/10/45'), findsOneWidget);
    expect(find.textContaining('mezhebe'), findsOneWidget);
    expect(find.textContaining('İkindi farzı'), findsOneWidget);
    expect(
      find.textContaining('Diyanet Din İşleri Yüksek Kurulu'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == _sourceUrl,
      ),
      findsOneWidget,
    );
  });

  for (final locale in [const Locale('tr'), const Locale('ar')]) {
    testWidgets(
      '${locale.languageCode} büyük metinde ayrıntılar ve kaynak kaydırılarak okunur',
      (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _openDetails(tester, locale: locale, textScale: 2);
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.byType(KerahatDetailsSheet)),
          ).scale(14),
          28,
        );
        expect(tester.takeException(), isNull);
        final scrollable = find
            .descendant(
              of: find.byType(KerahatDetailsSheet),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byType(SelectableText),
          160,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(find.byType(SelectableText).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
