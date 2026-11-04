import 'package:flutter/widgets.dart';
import 'package:scooter_core/scooter_core.dart' as core;

/// Comandi verso la mappa, indipendenti dall'implementazione (MapLibre).
abstract interface class MapViewHandle {
  Future<void> centerOn(core.LatLng target, {double? zoom});
  Future<void> showUserPosition(core.LatLng position, double accuracyM);

  /// Disegna i percorsi: il primo è quello selezionato, gli altri alternative.
  Future<void> showRoutes(List<List<core.LatLng>> routes);
  Future<void> clearRoutes();
  Future<void> showDestination(core.LatLng? destination);

  /// Inquadra il riquadro che contiene tutti i punti.
  Future<void> fitPoints(List<core.LatLng> points);
}

/// Costruisce il widget mappa. L'app usa MapLibre; i test di widget usano un
/// doppio di test perché la vista nativa non è disponibile fuori dal dispositivo.
abstract interface class MapViewFactory {
  Widget build({
    required String styleUrl,
    required core.LatLng initialCenter,
    required double initialZoom,
    required ValueChanged<MapViewHandle> onReady,
    ValueChanged<core.LatLng>? onLongPress,
    ValueChanged<String>? onError,
  });
}
