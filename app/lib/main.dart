import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/location/geolocator_location_provider.dart';
import 'features/location/location_controller.dart';
import 'features/map/maplibre_map_view.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs);
  final location = LocationController(GeolocatorLocationProvider());
  runApp(ScooterApp(
    settings: settings,
    location: location,
    mapFactory: const MapLibreMapViewFactory(),
  ));
}
