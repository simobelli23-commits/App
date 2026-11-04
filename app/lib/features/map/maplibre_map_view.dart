import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:scooter_core/scooter_core.dart' as core;

import 'map_view.dart';

class MapLibreMapViewFactory implements MapViewFactory {
  const MapLibreMapViewFactory();

  @override
  Widget build({
    required String styleUrl,
    required core.LatLng initialCenter,
    required double initialZoom,
    required ValueChanged<MapViewHandle> onReady,
    ValueChanged<String>? onError,
  }) =>
      _MapLibreView(
        styleUrl: styleUrl,
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        onReady: onReady,
      );
}

class _MapLibreView extends StatefulWidget {
  final String styleUrl;
  final core.LatLng initialCenter;
  final double initialZoom;
  final ValueChanged<MapViewHandle> onReady;

  const _MapLibreView({
    required this.styleUrl,
    required this.initialCenter,
    required this.initialZoom,
    required this.onReady,
  });

  @override
  State<_MapLibreView> createState() => _MapLibreViewState();
}

class _MapLibreViewState extends State<_MapLibreView> implements MapViewHandle {
  ml.MapLibreMapController? _c;
  ml.Circle? _accuracy;
  ml.Circle? _dot;
  bool _styleReady = false;

  static ml.LatLng _ml(core.LatLng p) => ml.LatLng(p.lat, p.lon);

  @override
  Widget build(BuildContext context) => ml.MapLibreMap(
        styleString: widget.styleUrl,
        initialCameraPosition: ml.CameraPosition(
            target: _ml(widget.initialCenter), zoom: widget.initialZoom),
        // Posizione disegnata dall'app (unica fonte: LocationController).
        myLocationEnabled: false,
        compassEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: false,
        attributionButtonPosition: ml.AttributionButtonPosition.bottomRight,
        onMapCreated: (c) => _c = c,
        onStyleLoadedCallback: () {
          _styleReady = true;
          widget.onReady(this);
        },
      );

  @override
  Future<void> centerOn(core.LatLng target, {double? zoom}) async {
    final c = _c;
    if (c == null) return;
    await c.animateCamera(zoom == null
        ? ml.CameraUpdate.newLatLng(_ml(target))
        : ml.CameraUpdate.newLatLngZoom(_ml(target), zoom));
  }

  @override
  Future<void> showUserPosition(core.LatLng position, double accuracyM) async {
    final c = _c;
    if (c == null || !_styleReady) return;
    final g = _ml(position);
    // Raggio di accuratezza approssimato in pixel a zoom 16 (~2,4 m/px a 45°N).
    final accPx = (accuracyM / 1.7).clamp(8.0, 120.0);
    if (_dot == null) {
      _accuracy = await c.addCircle(ml.CircleOptions(
          geometry: g, circleRadius: accPx, circleColor: '#0B57D0', circleOpacity: 0.15));
      _dot = await c.addCircle(ml.CircleOptions(
          geometry: g,
          circleRadius: 9,
          circleColor: '#0B57D0',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3));
    } else {
      await c.updateCircle(_accuracy!, ml.CircleOptions(geometry: g, circleRadius: accPx));
      await c.updateCircle(_dot!, ml.CircleOptions(geometry: g));
    }
  }
}
