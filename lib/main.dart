import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/di/service_locator.dart';
import 'core/providers/app_state.dart';
import 'presentation/pages/app_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
        title: 'Ezan Vakti',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AppRoot(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
