import 'dart:async';

import 'package:flutter/material.dart';
import 'package:navigatore_scooter/features/location/app_location_provider.dart';
import 'package:navigatore_scooter/features/map/map_view.dart';
import 'package:scooter_core/scooter_core.dart';

/// Doppio di test della mappa: la vista nativa MapLibre non esiste nei test
/// di widget. Registra i comandi ricevuti per verificarli.
class RecordingMap implements MapViewHandle {
  final centers = <(LatLng, double?)>[];
  final positions = <LatLng>[];
  List<List<LatLng>> routes = [];
  LatLng? destination;
  int fits = 0;

  @override
  Future<void> showRoutes(List<List<LatLng>> r) async => routes = r;

  @override
  Future<void> clearRoutes() async => routes = [];

  @override
  Future<void> showDestination(LatLng? d) async => destination = d;

  @override
  Future<void> fitPoints(List<LatLng> points) async => fits++;

  @override
  Future<void> centerOn(LatLng target, {double? zoom}) async =>
      centers.add((target, zoom));

  @override
  Future<void> showUserPosition(LatLng position, double accuracyM) async =>
      positions.add(position);
}

class RecordingMapFactory implements MapViewFactory {
  final map = RecordingMap();
  String? styleUrl;
  ValueChanged<LatLng>? onLongPress;

  @override
  Widget build({
    required String styleUrl,
    required LatLng initialCenter,
    required double initialZoom,
    required ValueChanged<MapViewHandle> onReady,
    ValueChanged<LatLng>? onLongPress,
    ValueChanged<String>? onError,
  }) {
    this.styleUrl = styleUrl;
    if (onLongPress != null) this.onLongPress = onLongPress;
    scheduleMicrotask(() => onReady(map));
    return const ColoredBox(key: Key('test-map'), color: Colors.grey);
  }
}

/// Provider di posizione controllato dal test.
class ControlledLocationProvider implements AppLocationProvider {
  final List<Result<void, LocationError>> readyResults;
  final fixesCtrl = StreamController<LocationFix>.broadcast();
  int ensureReadyCalls = 0;
  int openLocationSettingsCalls = 0;
  int openAppSettingsCalls = 0;

  ControlledLocationProvider(this.readyResults);

  @override
  Future<Result<void, LocationError>> ensureReady() async {
    final i = ensureReadyCalls++;
    return readyResults[i < readyResults.length ? i : readyResults.length - 1];
  }

  @override
  Stream<LocationFix> fixes() => fixesCtrl.stream;

  @override
  Future<void> openLocationSettings() async => openLocationSettingsCalls++;

  @override
  Future<void> openAppSettings() async => openAppSettingsCalls++;
}

const ok = Ok<void, LocationError>(null);
Err<void, LocationError> err(LocationErrorKind k) =>
    Err(LocationError(k, k.name));

LocationFix fixAt(double lat, double lon) => LocationFix(
    position: LatLng(lat, lon),
    accuracyM: 5,
    timestamp: DateTime.utc(2026, 11, 4, 12));

/// Routing controllato dal test (le risposte reali del motore sono coperte
/// dai test di integrazione in scooter_core).
class ScriptedRouting implements RoutingProvider {
  final List<Result<List<RouteResult>, RoutingError>> replies;
  final requests = <RouteRequest>[];
  ScriptedRouting(this.replies);

  @override
  String get name => 'scripted';

  @override
  Future<Result<List<RouteResult>, RoutingError>> route(RouteRequest r) async {
    requests.add(r);
    final i = requests.length - 1;
    return replies[i < replies.length ? i : replies.length - 1];
  }
}

class RecordingVoice implements VoiceOutput {
  final said = <String>[];
  @override
  Future<void> speak(String text) async => said.add(text);
  @override
  Future<void> stop() async {}
}

/// Percorso a L: 791 m verso est, poi 1112 m verso nord.
RouteResult lRoute({double km = 1.903, List<String> warnings = const []}) =>
    RouteResult(
      shape: const [
        LatLng(44.6450, 10.9200),
        LatLng(44.6450, 10.9300),
        LatLng(44.6550, 10.9300)
      ],
      maneuvers: const [
        Maneuver(
            type: 1,
            instruction: 'Guida verso est su Via Emilia.',
            verbalPre: 'Guida verso est su Via Emilia.',
            lengthM: 791,
            timeS: 70,
            beginShapeIndex: 0,
            endShapeIndex: 1),
        Maneuver(
            type: 15,
            instruction: 'Svolta a sinistra su Via Giardini.',
            verbalAlert: 'Svolta a sinistra su Via Giardini.',
            verbalPre: 'Svolta a sinistra su Via Giardini.',
            lengthM: 1112,
            timeS: 100,
            beginShapeIndex: 1,
            endShapeIndex: 2),
        Maneuver(
            type: 4,
            instruction: 'Sei arrivato a destinazione.',
            lengthM: 0,
            timeS: 0,
            beginShapeIndex: 2,
            endShapeIndex: 2),
      ],
      lengthM: km * 1000,
      engineTimeS: 170,
      modelTimeS: 240,
      warnings: warnings,
    );
