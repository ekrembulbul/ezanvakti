import 'package:ezanvakti/core/theme/app_theme.dart';
import 'package:ezanvakti/core/theme/app_tokens.dart';
import 'package:ezanvakti/core/theme/day_phase.dart';
import 'package:ezanvakti/core/theme/palettes.dart';
import 'package:ezanvakti/core/providers/app_state.dart';
import 'package:ezanvakti/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Widget testlerinde gercek palet altinda render etmek icin.
///
/// Token okuyan bir widget, `AppTokens` extension'i olmayan bir tema altinda
/// patlar; bu sarmalayici testin gercek kosullari taklit etmesini saglar.
/// [appState] verilmezse varsayilan bir tane kurulur: saat bicimi gibi genel
/// tercihleri okuyan widget'lar uygulamada her zaman bir `AppState` altinda
/// calisiyor; harness bunu taklit eder.
Widget wrapWithTheme(
  Widget child, {
  DayPhase phase = DayPhase.evening,
  Brightness brightness = Brightness.dark,
  AppState? appState,
  Locale locale = const Locale('tr'),
}) {
  final tokens = paletteFor(phase, brightness);
  return ChangeNotifierProvider<AppState>.value(
    value: appState ?? AppState(),
    child: MaterialApp(
      theme: AppTheme.build(tokens, brightness),
      // Ekranlar `context.l10n` okuyor; testler Turkce (kaynak dil) kosuyor.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      // Testler 24 saat bekliyor; Turkiye'deki cihaz varsayilani da bu.
      // Bicim tercihinin kendisi `TimeFormatter` testlerinde sinaniyor.
      home: MediaQuery(
        data: const MediaQueryData(alwaysUse24HourFormat: true),
        child: Scaffold(body: child),
      ),
    ),
  );
}

/// Testte beklenen rengi hesaplamak icin ayni paleti dondurur.
AppTokens tokensFor({
  DayPhase phase = DayPhase.evening,
  Brightness brightness = Brightness.dark,
}) => paletteFor(phase, brightness);
