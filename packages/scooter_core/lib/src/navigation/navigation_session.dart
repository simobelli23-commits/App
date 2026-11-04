import '../geo/geo.dart';
import '../providers/providers.dart';
import '../eta/eta_model.dart';

enum NavStatus { onRoute, offRouteSuspected, offRoute, arrived, gpsLost }

class NavigationSnapshot {
  final NavStatus status;
  final int maneuverIndex;
  final double distanceToManeuverM;
  final double remainingM;
  final double remainingS;
  final LatLng? snapped;

  /// Vero quando il controller suggerisce di ricalcolare il percorso.
  final bool shouldReroute;

  const NavigationSnapshot({
    required this.status,
    required this.maneuverIndex,
    required this.distanceToManeuverM,
    required this.remainingM,
    required this.remainingS,
    required this.snapped,
    required this.shouldReroute,
  });
}

/// Logica di navigazione indipendente dalla UI: aggancio al percorso,
/// prossima manovra, rilevamento fuori percorso, perdita GPS, arrivo.
class NavigationSession {
  final RouteResult route;
  final Polyline _line;
  final List<double> _maneuverAlongM;

  /// Distanza minima dal percorso per considerare un fix "fuori".
  final double offRouteThresholdM;

  /// Fix consecutivi fuori percorso prima di dichiarare offRoute.
  final int offRouteConsecutiveFixes;

  /// Fix con accuratezza peggiore di questa vengono ignorati per offRoute.
  final double maxUsableAccuracyM;

  final Duration gpsLostAfter;
  final double arrivalRadiusM;
  final Duration minRerouteInterval;

  int _offCount = 0;
  int _segmentHint = 0;
  DateTime? _lastFixAt;
  DateTime? _lastRerouteAt;
  NavigationSnapshot? _last;

  NavigationSession(
    this.route, {
    this.offRouteThresholdM = 40,
    this.offRouteConsecutiveFixes = 3,
    this.maxUsableAccuracyM = 50,
    this.gpsLostAfter = const Duration(seconds: 10),
    this.arrivalRadiusM = 25,
    this.minRerouteInterval = const Duration(seconds: 15),
  })  : _line = Polyline(route.shape),
        _maneuverAlongM = [] {
    final line = _line;
    for (final m in route.maneuvers) {
      final idx = m.beginShapeIndex.clamp(0, line.points.length - 1);
      _maneuverAlongM.add(line.cumulativeM[idx]);
    }
  }

  NavigationSnapshot? get last => _last;

  /// Da chiamare periodicamente (es. ogni secondo) per rilevare la perdita
  /// del segnale anche in assenza di nuovi fix.
  NavigationSnapshot? tick(DateTime now) {
    final l = _last;
    if (l == null || _lastFixAt == null) return null;
    if (now.difference(_lastFixAt!) > gpsLostAfter && l.status != NavStatus.arrived) {
      _last = NavigationSnapshot(
        status: NavStatus.gpsLost,
        maneuverIndex: l.maneuverIndex,
        distanceToManeuverM: l.distanceToManeuverM,
        remainingM: l.remainingM,
        remainingS: l.remainingS,
        snapped: l.snapped,
        shouldReroute: false,
      );
    }
    return _last;
  }

  NavigationSnapshot update(LocationFix fix) {
    _lastFixAt = fix.timestamp;
    // Proiezione a partire da poco prima dell'ultimo segmento noto, per non
    // agganciarsi a tratti già percorsi che passano vicino (anelli).
    final fromSeg = (_segmentHint - 2).clamp(0, _line.points.length - 2);
    var proj = _line.project(fix.position, fromSegment: fromSeg);
    if (proj.distanceM > offRouteThresholdM && fromSeg > 0) {
      final full = _line.project(fix.position);
      if (full.distanceM < proj.distanceM) proj = full;
    }

    final remainingM = (_line.lengthM - proj.alongM).clamp(0.0, double.infinity);
    var status = NavStatus.onRoute;
    var reroute = false;

    final usable = fix.accuracyM <= maxUsableAccuracyM;
    final threshold = offRouteThresholdM + (usable ? fix.accuracyM * 0.5 : 0);
    if (usable && proj.distanceM > threshold) {
      _offCount++;
      status = _offCount >= offRouteConsecutiveFixes
          ? NavStatus.offRoute
          : NavStatus.offRouteSuspected;
    } else if (usable) {
      _offCount = 0;
      _segmentHint = proj.segmentIndex;
    }

    if (status == NavStatus.offRoute) {
      final can = _lastRerouteAt == null ||
          fix.timestamp.difference(_lastRerouteAt!) >= minRerouteInterval;
      if (can) {
        reroute = true;
        _lastRerouteAt = fix.timestamp;
      }
    }

    final destDist = haversineM(fix.position, route.shape.last);
    if (status == NavStatus.onRoute &&
        (destDist <= arrivalRadiusM || remainingM <= arrivalRadiusM * 0.5)) {
      status = NavStatus.arrived;
    }

    // Prossima manovra: la prima il cui inizio è oltre la posizione attuale.
    var mIdx = _maneuverAlongM.length - 1;
    for (var i = 0; i < _maneuverAlongM.length; i++) {
      if (_maneuverAlongM[i] > proj.alongM + 1.0) {
        mIdx = i;
        break;
      }
    }
    final distToMan = mIdx >= 0
        ? (_maneuverAlongM[mIdx] - proj.alongM).clamp(0.0, double.infinity)
        : remainingM;

    final totalS = route.modelTimeS ?? route.engineTimeS;
    final snap = NavigationSnapshot(
      status: status,
      maneuverIndex: mIdx < 0 ? 0 : mIdx,
      distanceToManeuverM: distToMan.toDouble(),
      remainingM: remainingM.toDouble(),
      remainingS: EtaModel.remainingSeconds(
          totalSeconds: totalS, totalM: _line.lengthM, remainingM: remainingM.toDouble()),
      snapped: status == NavStatus.onRoute ? proj.point : null,
      shouldReroute: reroute,
    );
    _last = snap;
    return snap;
  }
}
