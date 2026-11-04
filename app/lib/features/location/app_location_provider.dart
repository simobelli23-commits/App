import 'package:scooter_core/scooter_core.dart';

/// Estende il LocationProvider del core con le azioni di sistema
/// necessarie per risolvere gli errori (aprire impostazioni).
abstract interface class AppLocationProvider implements LocationProvider {
  Future<void> openLocationSettings();
  Future<void> openAppSettings();
}
