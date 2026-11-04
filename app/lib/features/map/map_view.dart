import 'package:flutter/widgets.dart';
import 'package:scooter_core/scooter_core.dart' as core;

/// Comandi verso la mappa, indipendenti dall'implementazione (MapLibre).
abstract interface class MapViewHandle {
  Future<void> centerOn(core.LatLng target, {double? zoom});
  Future<void> showUserPosition(core.LatLng position, double accuracyM);
}

/// Costruisce il widget mappa. L'app usa MapLibre; i test di widget usano un
/// doppio di test perché la vista nativa non è disponibile fuori dal dispositivo.
abstract interface class MapViewFactory {
  Widget build({
    required String styleUrl,
    required core.LatLng initialCenter,
    required double initialZoom,
    required ValueChanged<MapViewHandle> onReady,
    ValueChanged<String>? onError,
  });
}
