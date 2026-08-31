import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'l10n/locale_resolver.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_constants.dart';
import 'core/di/service_locator.dart';
import 'core/providers/app_state.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'presentation/pages/app_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('tr_TR', null);

  final serviceLocator = ServiceLocator();
  await serviceLocator.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider<ThemeController>.value(
          value: ServiceLocator().get<ThemeController>(),
        ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, controller, _) {
          // Cihazin gece/gunduz tercihi degisince "Sistem" modu izlesin.
          controller.setPlatformBrightness(
            MediaQuery.platformBrightnessOf(context),
          );

          // Sistem cubugu aktif paletin zemini ve parlakligiyla uyumlu kalsin;
          // palet gun icinde degistigi icin her yapida guncellenir.
          final isDark = controller.brightness == Brightness.dark;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              // Android: simgelerin rengi. iOS: `statusBarBrightness` ve o
              // simgeyi degil **zemini** tarif eder, bu yuzden ters deger
              // verilir. Yalnizca ilki ayarlandigi icin iOS'ta acik temada
              // saat/pil beyaz kaliyor ve gorunmuyordu.
              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: isDark
                  ? Brightness.dark
                  : Brightness.light,
              systemNavigationBarColor: controller.tokens.backgroundStops.last,
              systemNavigationBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
            ),
          );

          return MaterialApp(
            title: AppConstants.appTitle,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Kullanıcı tercihi; null ise cihaz dili kullanılır. Arapça
            // seçilince yön (RTL) MaterialApp tarafından uygulanır.
            locale: context.watch<AppState>().generalSettings.language.locale,
            // Desteklenmeyen cihaz dilinde Flutter listenin ilkine (alfabetik
            // olarak Arapça) düşüyordu; İngilizce daha geniş anlaşılıyor.
            localeResolutionCallback: (deviceLocale, _) =>
                LocaleResolver.resolve(deviceLocale),
            theme: AppTheme.build(controller.tokens, controller.brightness),
            // Palet gecisi: vakit siniri, tema degisimi ve sabit palet secimi
            // ayni sureyi kullanir.
            themeAnimationDuration: kPaletteTransition,
            themeAnimationCurve: Curves.easeOutCubic,
            home: const AppRoot(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
