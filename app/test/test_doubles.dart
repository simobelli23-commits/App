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

  @override
  Future<void> centerOn(LatLng target, {double? zoom}) async => centers.add((target, zoom));

  @override
  Future<void> showUserPosition(LatLng position, double accuracyM) async =>
      positions.add(position);
}

class RecordingMapFactory implements MapViewFactory {
  final map = RecordingMap();
  String? styleUrl;

  @override
  Widget build({
    required String styleUrl,
    required LatLng initialCenter,
    required double initialZoom,
    required ValueChanged<MapViewHandle> onReady,
    ValueChanged<String>? onError,
  }) {
    this.styleUrl = styleUrl;
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
Err<void, LocationError> err(LocationErrorKind k) => Err(LocationError(k, k.name));

LocationFix fixAt(double lat, double lon) => LocationFix(
    position: LatLng(lat, lon), accuracyM: 5, timestamp: DateTime.utc(2026, 11, 4, 12));
