import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/location/location_controller.dart';
import '../features/map/home_screen.dart';
import '../features/map/map_view.dart';
import '../features/settings/settings_controller.dart';
import 'theme.dart';

class ScooterApp extends StatelessWidget {
  final SettingsController settings;
  final LocationController location;
  final MapViewFactory mapFactory;

  const ScooterApp({
    super.key,
    required this.settings,
    required this.location,
    required this.mapFactory,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Navigatore Scooter',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: settings.themeMode,
        locale: const Locale('it', 'IT'),
        supportedLocales: const [Locale('it', 'IT')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: HomeScreen(settings: settings, location: location, mapFactory: mapFactory),
      ),
    );
  }
}
