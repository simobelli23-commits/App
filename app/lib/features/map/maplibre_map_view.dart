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
    ValueChanged<core.LatLng>? onLongPress,
    ValueChanged<String>? onError,
  }) =>
      _MapLibreView(
        styleUrl: styleUrl,
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        onReady: onReady,
        onLongPress: onLongPress,
      );
}

class _MapLibreView extends StatefulWidget {
  final String styleUrl;
  final core.LatLng initialCenter;
  final double initialZoom;
  final ValueChanged<MapViewHandle> onReady;
  final ValueChanged<core.LatLng>? onLongPress;

  const _MapLibreView({
    required this.styleUrl,
    required this.initialCenter,
    required this.initialZoom,
    required this.onReady,
    this.onLongPress,
  });

  @override
  State<_MapLibreView> createState() => _MapLibreViewState();
}

class _MapLibreViewState extends State<_MapLibreView> implements MapViewHandle {
  ml.MapLibreMapController? _c;
  ml.Circle? _accuracy;
  ml.Circle? _dot;
  ml.Circle? _dest;
  final List<ml.Line> _lines = [];
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
        onMapLongClick: (_, p) =>
            widget.onLongPress?.call(core.LatLng(p.latitude, p.longitude)),
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
          geometry: g,
          circleRadius: accPx,
          circleColor: '#0B57D0',
          circleOpacity: 0.15));
      _dot = await c.addCircle(ml.CircleOptions(
          geometry: g,
          circleRadius: 9,
          circleColor: '#0B57D0',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3));
    } else {
      await c.updateCircle(
          _accuracy!, ml.CircleOptions(geometry: g, circleRadius: accPx));
      await c.updateCircle(_dot!, ml.CircleOptions(geometry: g));
    }
  }

  @override
  Future<void> showRoutes(List<List<core.LatLng>> routes) async {
    final c = _c;
    if (c == null || !_styleReady) return;
    await clearRoutes();
    // Alternative prima (sotto), percorso selezionato per ultimo (sopra).
    for (var i = routes.length - 1; i >= 0; i--) {
      if (routes[i].length < 2) continue;
      _lines.add(await c.addLine(ml.LineOptions(
        geometry: [for (final p in routes[i]) _ml(p)],
        lineColor: i == 0 ? '#0B57D0' : '#7A7A7A',
        lineWidth: i == 0 ? 7 : 5,
        lineOpacity: i == 0 ? 0.95 : 0.7,
        lineJoin: 'round',
      )));
    }
  }

  @override
  Future<void> clearRoutes() async {
    final c = _c;
    if (c == null) return;
    for (final l in _lines) {
      await c.removeLine(l);
    }
    _lines.clear();
  }

  @override
  Future<void> showDestination(core.LatLng? destination) async {
    final c = _c;
    if (c == null || !_styleReady) return;
    if (_dest != null) {
      await c.removeCircle(_dest!);
      _dest = null;
    }
    if (destination == null) return;
    _dest = await c.addCircle(ml.CircleOptions(
        geometry: _ml(destination),
        circleRadius: 11,
        circleColor: '#C5221F',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3));
  }

  @override
  Future<void> fitPoints(List<core.LatLng> points) async {
    final c = _c;
    if (c == null || points.isEmpty) return;
    var s = points.first.lat, n = s, w = points.first.lon, e = w;
    for (final p in points) {
      if (p.lat < s) s = p.lat;
      if (p.lat > n) n = p.lat;
      if (p.lon < w) w = p.lon;
      if (p.lon > e) e = p.lon;
    }
    await c.animateCamera(ml.CameraUpdate.newLatLngBounds(
        ml.LatLngBounds(southwest: ml.LatLng(s, w), northeast: ml.LatLng(n, e)),
        left: 48,
        right: 48,
        top: 160,
        bottom: 260));
  }
}
