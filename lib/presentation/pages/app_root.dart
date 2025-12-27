import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/di/service_locator.dart';
import '../../features/location/domain/location_repository.dart';
import '../screens/location_add_screen.dart';
import 'home_page.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkInitialSetup();
  }

  Future<void> _checkInitialSetup() async {
    final locationRepository = ServiceLocator().get<LocationRepository>();
    final appState = context.read<AppState>();

    try {
      final activeLocation = await locationRepository.getActiveLocation();

      if (activeLocation != null) {
        appState.setActiveLocation(activeLocation);
        setState(() {
          _isChecking = false;
        });
      } else {
        setState(() {
          _isChecking = false;
        });
      }
    } catch (e) {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.hasActiveLocation) {
          return const HomePage();
        } else {
          final locationRepository = ServiceLocator().get<LocationRepository>();
          return LocationAddScreen(locationRepository: locationRepository);
        }
      },
    );
  }
}
