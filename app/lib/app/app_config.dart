import 'package:scooter_core/scooter_core.dart' as core;

/// Configurazione di build. Valori sovrascrivibili con --dart-define.
class AppConfig {
  /// Stile vettoriale OpenFreeMap (gratuito, senza chiave). Vedi DATA_SOURCES.md.
  static const mapStyleUrl = String.fromEnvironment(
    'MAP_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );

  /// URL del server Valhalla (es. http://192.168.1.10:8002/). Vuoto = non configurato.
  static const routingUrl = String.fromEnvironment('ROUTING_URL');

  static const mapAttribution =
      '© OpenStreetMap contributors · OpenFreeMap · OpenMapTiles';

  /// Centro iniziale: Modena (area della prima sperimentazione).
  static const initialCenter = core.LatLng(44.6471, 10.9252);
  static const initialZoom = 13.0;
  static const followZoom = 16.0;
}
