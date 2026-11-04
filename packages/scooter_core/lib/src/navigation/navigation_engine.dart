import 'dart:async';

import '../geo/geo.dart';
import '../providers/providers.dart';
import '../vehicle/vehicle_profile.dart';
import 'navigation_session.dart';
import 'voice_planner.dart';

/// Uscita vocale (implementata nell'app con il TTS di sistema).
abstract interface class VoiceOutput {
  Future<void> speak(String text);
  Future<void> stop();
}

enum EngineStatus { idle, calculating, navigating, rerouting, arrived, failed }

/// Avviso non bloccante mostrato durante la guida.
enum EngineNotice {
  none,
  gpsLost,
  rerouteNoConnection,
  rerouteServerError,
  rerouteNoRoute,
}

/// Coordina percorso, sessione di navigazione, voce e ricalcolo.
/// Indipendente dalla UI: l'app osserva [changes].
class NavigationEngine {
  final RoutingProvider routing;
  final VehicleProfile profile;
  final LatLng destination;
  final VoiceOutput? voice;
  bool voiceEnabled;

  /// Parametri per la sessione (soglie fuori percorso ecc.).
  final NavigationSession Function(RouteResult) sessionFactory;

  final _changes = StreamController<void>.broadcast();
  final VoicePlanner _planner = VoicePlanner();

  EngineStatus _status = EngineStatus.idle;
  EngineNotice _notice = EngineNotice.none;
  RoutingError? _error;
  RouteResult? _route;
  NavigationSession? _session;
  NavigationSnapshot? _snapshot;
  LocationFix? _lastFix;
  int _reroutes = 0;
  bool _disposed = false;

  NavigationEngine({
    required this.routing,
    required this.profile,
    required this.destination,
    this.voice,
    this.voiceEnabled = true,
    NavigationSession Function(RouteResult)? sessionFactory,
  }) : sessionFactory = sessionFactory ?? ((r) => NavigationSession(r));

  Stream<void> get changes => _changes.stream;
  EngineStatus get status => _status;
  EngineNotice get notice => _notice;
  RoutingError? get error => _error;
  RouteResult? get route => _route;
  NavigationSnapshot? get snapshot => _snapshot;
  int get rerouteCount => _reroutes;

  Maneuver? get nextManeuver {
    final r = _route, s = _snapshot;
    if (r == null || r.maneuvers.isEmpty) return null;
    final i = (s?.maneuverIndex ?? 0).clamp(0, r.maneuvers.length - 1);
    return r.maneuvers[i];
  }

  /// Avvia con un percorso già calcolato (scelto dall'utente in anteprima).
  void startWithRoute(RouteResult route) {
    _setRoute(route);
    _status = EngineStatus.navigating;
    final dep = _planner.departure(route.maneuvers);
    if (dep != null) _say(dep);
    _emit();
  }

  /// Calcola il percorso da [origin] e avvia la navigazione.
  Future<Result<RouteResult, RoutingError>> start(LatLng origin, {double? headingDeg}) async {
    _status = EngineStatus.calculating;
    _emit();
    final res = await routing.route(RouteRequest(
        origin: origin, destination: destination, profile: profile,
        alternatives: false, headingDeg: headingDeg));
    if (_disposed) return const Err(RoutingError(RoutingErrorKind.noRoute, 'Annullato'));
    switch (res) {
      case Ok(:final value):
        startWithRoute(value.first);
        return Ok(value.first);
      case Err(:final error):
        _error = error;
        _status = EngineStatus.failed;
        _emit();
        return Err(error);
    }
  }

  void onFix(LocationFix fix) {
    final session = _session;
    if (session == null || _status == EngineStatus.arrived) return;
    _lastFix = fix;
    final snap = session.update(fix);
    _snapshot = snap;
    if (_notice == EngineNotice.gpsLost) _notice = EngineNotice.none;

    if (snap.status == NavStatus.arrived) {
      _status = EngineStatus.arrived;
      for (final t in _planner.plan(snap, _route!.maneuvers)) {
        _say(t);
      }
      _emit();
      return;
    }
    if (snap.shouldReroute && _status != EngineStatus.rerouting) {
      _reroute(fix);
    } else if (_status == EngineStatus.navigating) {
      for (final t in _planner.plan(snap, _route!.maneuvers, speedMps: fix.speedMps)) {
        _say(t);
      }
    }
    _emit();
  }

  /// Da chiamare ogni secondo: rileva la perdita del segnale GPS.
  void onTick(DateTime now) {
    final snap = _session?.tick(now);
    if (snap == null) return;
    _snapshot = snap;
    if (snap.status == NavStatus.gpsLost && _notice != EngineNotice.gpsLost &&
        _status != EngineStatus.arrived) {
      _notice = EngineNotice.gpsLost;
      _say('Segnale GPS perso.');
      _emit();
    }
  }

  Future<void> _reroute(LocationFix fix) async {
    _status = EngineStatus.rerouting;
    _say('Ricalcolo del percorso.');
    _emit();
    final res = await routing.route(RouteRequest(
        origin: fix.position, destination: destination, profile: profile,
        alternatives: false, headingDeg: fix.headingDeg));
    if (_disposed) return;
    switch (res) {
      case Ok(:final value):
        _reroutes++;
        _setRoute(value.first);
        _planner.reset();
        _notice = EngineNotice.none;
        _status = EngineStatus.navigating;
        final last = _lastFix;
        if (last != null) _snapshot = _session!.update(last);
      case Err(:final error):
        // Si mantiene il percorso precedente: la sessione richiederà un nuovo
        // tentativo dopo l'intervallo minimo. Nessun percorso inventato.
        _error = error;
        _notice = switch (error.kind) {
          RoutingErrorKind.noConnection || RoutingErrorKind.timeout =>
            EngineNotice.rerouteNoConnection,
          RoutingErrorKind.noRoute || RoutingErrorKind.rejectedByCompliance ||
          RoutingErrorKind.locationNotRoutable => EngineNotice.rerouteNoRoute,
          _ => EngineNotice.rerouteServerError,
        };
        _status = EngineStatus.navigating;
        if (_notice == EngineNotice.rerouteNoConnection) {
          _say('Connessione assente. Mantengo il percorso precedente.');
        }
    }
    _emit();
  }

  void _setRoute(RouteResult r) {
    _route = r;
    _session = sessionFactory(r);
    _snapshot = null;
  }

  void _say(String text) {
    if (!voiceEnabled || voice == null || text.isEmpty) return;
    // Errori del TTS non devono interrompere la navigazione.
    voice!.speak(text).catchError((Object _) {});
  }

  void _emit() {
    if (!_disposed) _changes.add(null);
  }

  Future<void> dispose() async {
    _disposed = true;
    await voice?.stop().catchError((Object _) {});
    await _changes.close();
  }
}
