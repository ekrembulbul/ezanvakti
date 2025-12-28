import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_constants.dart';
import 'core/di/service_locator.dart';
import 'core/providers/app_state.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/app_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for immersive dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.primaryDark,
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
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: AppConstants.appTitle,
        theme: AppTheme.darkTheme,
        home: const AppRoot(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
