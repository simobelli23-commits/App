import '../geo/geo.dart';
import '../vehicle/vehicle_profile.dart';

/// Risultato tipizzato: nessuna eccezione non gestita verso la UI.
sealed class Result<T, E> {
  const Result();
}

class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);
}

class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);
}

// ---------------------------------------------------------------- Routing

enum RoutingErrorKind {
  noConnection,
  serverUnreachable,
  timeout,
  noRoute,
  locationNotRoutable,
  invalidResponse,
  rejectedByCompliance,
  profileNotSupported,
}

class RoutingError {
  final RoutingErrorKind kind;
  final String message;
  const RoutingError(this.kind, this.message);

  @override
  String toString() => 'RoutingError(${kind.name}: $message)';
}

class Maneuver {
  final int type; // codice tipo Valhalla
  final String instruction;
  final String? verbalPre;
  final String? verbalPost;
  final double lengthM;
  final double timeS;
  final int beginShapeIndex;
  final int endShapeIndex;
  final List<String> streetNames;

  const Maneuver({
    required this.type,
    required this.instruction,
    this.verbalPre,
    this.verbalPost,
    required this.lengthM,
    required this.timeS,
    required this.beginShapeIndex,
    required this.endShapeIndex,
    this.streetNames = const [],
  });
}

class RouteResult {
  final List<LatLng> shape;
  final List<Maneuver> maneuvers;
  final double lengthM;
  final double engineTimeS;

  /// ETA del modello deterministico dell'app (se calcolato).
  final double? modelTimeS;

  /// Avvisi da mostrare (dati incerti ecc.).
  final List<String> warnings;

  const RouteResult({
    required this.shape,
    required this.maneuvers,
    required this.lengthM,
    required this.engineTimeS,
    this.modelTimeS,
    this.warnings = const [],
  });

  RouteResult copyWith({double? modelTimeS, List<String>? warnings}) => RouteResult(
        shape: shape,
        maneuvers: maneuvers,
        lengthM: lengthM,
        engineTimeS: engineTimeS,
        modelTimeS: modelTimeS ?? this.modelTimeS,
        warnings: warnings ?? this.warnings,
      );
}

class RouteRequest {
  final LatLng origin;
  final LatLng destination;
  final VehicleProfile profile;
  final bool alternatives;

  /// Rotta attuale del veicolo (gradi), utile nel ricalcolo.
  final double? headingDeg;

  const RouteRequest({
    required this.origin,
    required this.destination,
    required this.profile,
    this.alternatives = true,
    this.headingDeg,
  });
}

abstract interface class RoutingProvider {
  String get name;

  /// Primo elemento: percorso principale; altri: alternative valide.
  Future<Result<List<RouteResult>, RoutingError>> route(RouteRequest request);
}

// ---------------------------------------------------------------- Geocoding

class Place {
  final String label;
  final LatLng position;
  final String? category;
  const Place(this.label, this.position, {this.category});
}

enum GeocodingErrorKind { noConnection, serviceUnavailable, notFound, invalidResponse, rateLimited }

class GeocodingError {
  final GeocodingErrorKind kind;
  final String message;
  const GeocodingError(this.kind, this.message);
}

abstract interface class GeocodingProvider {
  String get name;
  String get attribution;

  /// Ricerca esplicita (su invio), NON autocomplete.
  Future<Result<List<Place>, GeocodingError>> search(String query, {LatLng? near});
}

// ---------------------------------------------------------------- Location

class LocationFix {
  final LatLng position;
  final double accuracyM;
  final double? speedMps;
  final double? headingDeg;
  final DateTime timestamp;

  const LocationFix({
    required this.position,
    required this.accuracyM,
    this.speedMps,
    this.headingDeg,
    required this.timestamp,
  });
}

enum LocationErrorKind { serviceDisabled, permissionDenied, permissionDeniedForever, unavailable }

class LocationError {
  final LocationErrorKind kind;
  final String message;
  const LocationError(this.kind, this.message);
}

abstract interface class LocationProvider {
  Future<Result<void, LocationError>> ensureReady();
  Stream<LocationFix> fixes();
}

// ---------------------------------------------------------------- Map

/// Configurazione della mappa base (stile vettoriale + attribuzioni).
abstract interface class MapProvider {
  String get styleUrl;
  String get attribution;
}
