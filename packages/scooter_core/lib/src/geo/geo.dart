import 'dart:math' as math;

/// Punto geografico WGS84.
class LatLng {
  final double lat;
  final double lon;

  const LatLng(this.lat, this.lon);

  bool get isValid =>
      lat.isFinite && lon.isFinite && lat.abs() <= 90 && lon.abs() <= 180;

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'LatLng($lat, $lon)';
}

const double earthRadiusM = 6371008.8;

double _rad(double deg) => deg * math.pi / 180.0;

/// Distanza ortodromica (haversine) in metri.
double haversineM(LatLng a, LatLng b) {
  final dLat = _rad(b.lat - a.lat);
  final dLon = _rad(b.lon - a.lon);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Rotta iniziale da [a] a [b] in gradi [0, 360).
double bearingDeg(LatLng a, LatLng b) {
  final y = math.sin(_rad(b.lon - a.lon)) * math.cos(_rad(b.lat));
  final x = math.cos(_rad(a.lat)) * math.sin(_rad(b.lat)) -
      math.sin(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.cos(_rad(b.lon - a.lon));
  final deg = math.atan2(y, x) * 180.0 / math.pi;
  return (deg + 360.0) % 360.0;
}

/// Risultato della proiezione di un punto su una polilinea.
class PolylineProjection {
  /// Indice del segmento (tra vertice [segmentIndex] e [segmentIndex]+1).
  final int segmentIndex;

  /// Frazione [0,1] lungo il segmento.
  final double fraction;

  /// Punto proiettato.
  final LatLng point;

  /// Distanza in metri tra il punto originale e la proiezione.
  final double distanceM;

  /// Distanza in metri dall'inizio della polilinea al punto proiettato.
  final double alongM;

  const PolylineProjection({
    required this.segmentIndex,
    required this.fraction,
    required this.point,
    required this.distanceM,
    required this.alongM,
  });
}

/// Polilinea con distanze cumulative precalcolate.
class Polyline {
  final List<LatLng> points;
  final List<double> cumulativeM;

  Polyline._(this.points, this.cumulativeM);

  factory Polyline(List<LatLng> points) {
    if (points.length < 2) {
      throw ArgumentError('Una polilinea richiede almeno 2 punti');
    }
    final cum = <double>[0.0];
    for (var i = 1; i < points.length; i++) {
      cum.add(cum.last + haversineM(points[i - 1], points[i]));
    }
    return Polyline._(List.unmodifiable(points), List.unmodifiable(cum));
  }

  double get lengthM => cumulativeM.last;

  /// Proietta [p] sul segmento più vicino. Usa una proiezione
  /// equirettangolare locale: adeguata per segmenti stradali (< qualche km).
  PolylineProjection project(LatLng p, {int fromSegment = 0}) {
    PolylineProjection? best;
    for (var i = math.max(0, fromSegment); i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final cosLat = math.cos(_rad(p.lat));
      final ax = a.lon * cosLat, ay = a.lat;
      final bx = b.lon * cosLat, by = b.lat;
      final px = p.lon * cosLat, py = p.lat;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final proj = LatLng(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t);
      final d = haversineM(p, proj);
      if (best == null || d < best.distanceM) {
        final segLen = cumulativeM[i + 1] - cumulativeM[i];
        best = PolylineProjection(
          segmentIndex: i,
          fraction: t,
          point: proj,
          distanceM: d,
          alongM: cumulativeM[i] + segLen * t,
        );
      }
    }
    return best!;
  }
}

/// Decodifica una polilinea codificata (formato Google/Valhalla).
/// Valhalla usa precisione 6 (polyline6).
List<LatLng> decodePolyline(String encoded, {int precision = 6}) {
  final factor = math.pow(10, precision).toDouble();
  final out = <LatLng>[];
  var index = 0, lat = 0, lon = 0;
  int next() {
    var result = 0, shift = 0, b = 0;
    do {
      if (index >= encoded.length) {
        throw const FormatException('Polilinea troncata');
      }
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  }

  while (index < encoded.length) {
    lat += next();
    lon += next();
    out.add(LatLng(lat / factor, lon / factor));
  }
  return out;
}

/// Codifica (usata da test e per inviare shape a trace_attributes).
String encodePolyline(List<LatLng> points, {int precision = 6}) {
  final factor = math.pow(10, precision).toDouble();
  final sb = StringBuffer();
  var prevLat = 0, prevLon = 0;
  void enc(int v) {
    var s = v < 0 ? ~(v << 1) : (v << 1);
    while (s >= 0x20) {
      sb.writeCharCode((0x20 | (s & 0x1f)) + 63);
      s >>= 5;
    }
    sb.writeCharCode(s + 63);
  }

  for (final p in points) {
    final lat = (p.lat * factor).round();
    final lon = (p.lon * factor).round();
    enc(lat - prevLat);
    enc(lon - prevLon);
    prevLat = lat;
    prevLon = lon;
  }
  return sb.toString();
}
