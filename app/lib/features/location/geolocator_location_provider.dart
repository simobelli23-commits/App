import 'package:geolocator/geolocator.dart';
import 'package:scooter_core/scooter_core.dart';

import 'app_location_provider.dart';

/// GPS reale tramite package:geolocator. Posizione solo in primo piano,
/// mai inviata a server.
class GeolocatorLocationProvider implements AppLocationProvider {
  @override
  Future<Result<void, LocationError>> ensureReady() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Err(LocationError(
            LocationErrorKind.serviceDisabled, 'Localizzazione disattivata'));
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      switch (perm) {
        case LocationPermission.denied:
          return const Err(LocationError(
              LocationErrorKind.permissionDenied, 'Permesso di posizione negato'));
        case LocationPermission.deniedForever:
          return const Err(LocationError(LocationErrorKind.permissionDeniedForever,
              'Permesso di posizione negato in modo permanente'));
        case LocationPermission.unableToDetermine:
          return const Err(LocationError(
              LocationErrorKind.unavailable, 'Stato del permesso non determinabile'));
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return const Ok(null);
      }
    } catch (e) {
      return Err(LocationError(LocationErrorKind.unavailable, e.toString()));
    }
  }

  @override
  Stream<LocationFix> fixes() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).map((p) => LocationFix(
            position: LatLng(p.latitude, p.longitude),
            accuracyM: p.accuracy,
            speedMps: p.speed >= 0 ? p.speed : null,
            headingDeg: p.heading >= 0 ? p.heading : null,
            timestamp: p.timestamp,
          ));

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
