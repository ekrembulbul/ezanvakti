import 'package:flutter/material.dart';
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

  // Set system UI overlay style for immersive dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF120E1B),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

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

          return MaterialApp(
            title: AppConstants.appTitle,
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
