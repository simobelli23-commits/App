import 'dart:async';
import 'dart:convert';

import '../eta/eta_model.dart';
import '../geo/geo.dart';
import '../providers/providers.dart';
import '../rules/osm_access_rules.dart';
import '../rules/route_compliance.dart';
import '../vehicle/vehicle_profile.dart';

/// Trasporto HTTP minimo, iniettabile (implementazione reale nell'app con
/// package:http; nei test un server Valhalla reale o risposte registrate).
abstract interface class HttpTransport {
  Future<HttpReply> postJson(Uri url, String body, {Duration? timeout});
}

class HttpReply {
  final int statusCode;
  final String body;
  const HttpReply(this.statusCode, this.body);
}

/// Errori di trasporto che l'implementazione concreta deve lanciare.
class TransportException implements Exception {
  final bool noConnection;
  final bool timeout;
  final String message;
  const TransportException(this.message, {this.noConnection = false, this.timeout = false});
}

/// Costruzione richieste Valhalla per i profili supportati.
class ValhallaRequestBuilder {
  /// Solo il ciclomotore è supportato in questa versione.
  static bool supports(VehicleProfile p) => p.isMoped;

  static Map<String, dynamic> route(RouteRequest r) {
    final p = r.profile;
    return {
      'locations': [
        {
          'lat': r.origin.lat,
          'lon': r.origin.lon,
          'type': 'break',
          if (r.headingDeg != null) 'heading': r.headingDeg!.round(),
          if (r.headingDeg != null) 'heading_tolerance': 45,
        },
        {'lat': r.destination.lat, 'lon': r.destination.lon, 'type': 'break'},
      ],
      // motor_scooter usa la gerarchia di accesso OSM "moped" (ciclomotore).
      'costing': 'motor_scooter',
      'costing_options': {
        'motor_scooter': {
          // Limite superiore di progetto, non velocità media.
          'top_speed': p.maxDesignSpeedKmh.round(),
          'use_primary': 0.5,
          'use_hills': 0.5,
          'use_ferry': 0.0,
          'use_tracks': 0.0,
          'use_living_streets': 0.3,
        }
      },
      'directions_options': {'units': 'kilometers', 'language': 'it-IT'},
      if (r.alternatives) 'alternates': 1,
    };
  }

  static Map<String, dynamic> traceAttributes(List<LatLng> shape) => {
        'encoded_polyline': encodePolyline(shape),
        'shape_match': 'edge_walk',
        'costing': 'motor_scooter',
        'filters': {
          'attributes': [
            'edge.way_id',
            'edge.road_class',
            'edge.use',
            'edge.length',
            'edge.names',
            'edge.speed_limit',
          ],
          'action': 'include'
        },
      };
}

/// Parsing risposte Valhalla. Lancia [FormatException] su dati invalidi.
class ValhallaParser {
  static RouteResult parseTrip(Map<String, dynamic> trip) {
    final legs = trip['legs'];
    if (legs is! List || legs.isEmpty) {
      throw const FormatException('trip.legs mancante');
    }
    final shape = <LatLng>[];
    final maneuvers = <Maneuver>[];
    for (final leg in legs) {
      final enc = (leg as Map<String, dynamic>)['shape'];
      if (enc is! String) throw const FormatException('leg.shape mancante');
      final offset = shape.isEmpty ? 0 : shape.length - 1;
      final pts = decodePolyline(enc);
      shape.addAll(shape.isEmpty ? pts : pts.skip(1));
      for (final m in (leg['maneuvers'] as List? ?? const [])) {
        final mm = m as Map<String, dynamic>;
        maneuvers.add(Maneuver(
          type: (mm['type'] as num).toInt(),
          instruction: mm['instruction'] as String? ?? '',
          verbalPre: mm['verbal_pre_transition_instruction'] as String?,
          verbalPost: mm['verbal_post_transition_instruction'] as String?,
          lengthM: ((mm['length'] as num?) ?? 0) * 1000.0,
          timeS: ((mm['time'] as num?) ?? 0).toDouble(),
          beginShapeIndex: offset + ((mm['begin_shape_index'] as num?) ?? 0).toInt(),
          endShapeIndex: offset + ((mm['end_shape_index'] as num?) ?? 0).toInt(),
          streetNames: [
            for (final s in (mm['street_names'] as List? ?? const [])) s.toString()
          ],
        ));
      }
    }
    if (shape.length < 2) throw const FormatException('shape con meno di 2 punti');
    final summary = trip['summary'] as Map<String, dynamic>?;
    if (summary == null) throw const FormatException('trip.summary mancante');
    return RouteResult(
      shape: shape,
      maneuvers: maneuvers,
      lengthM: ((summary['length'] as num?) ?? 0) * 1000.0,
      engineTimeS: ((summary['time'] as num?) ?? 0).toDouble(),
    );
  }

  static List<RouteEdge> parseEdges(Map<String, dynamic> json) {
    final edges = json['edges'];
    if (edges is! List) throw const FormatException('edges mancante');
    return [
      for (final e in edges.cast<Map<String, dynamic>>())
        RouteEdge(
          wayId: (e['way_id'] as num?)?.toInt(),
          roadClass: e['road_class'] as String? ?? 'unknown',
          use: e['use'] as String? ?? 'unknown',
          lengthKm: ((e['length'] as num?) ?? 0).toDouble(),
          name: (e['names'] as List?)?.isNotEmpty == true
              ? (e['names'] as List).first.toString()
              : null,
        )
    ];
  }

  static ManeuverKind kindOf(int valhallaType) {
    // Codici tipo manovra Valhalla (vedi docs/api/turn-by-turn).
    switch (valhallaType) {
      case 8: // continue
      case 22: // stay straight
        return ManeuverKind.straight;
      case 9: // slight right
      case 16: // slight left
      case 23: // stay right
      case 24: // stay left
        return ManeuverKind.slightTurn;
      case 10: // right
      case 15: // left
        return ManeuverKind.turn;
      case 11: // sharp right
      case 14: // sharp left
        return ManeuverKind.sharpTurn;
      case 12: // uturn right
      case 13: // uturn left
        return ManeuverKind.uTurn;
      case 26: // roundabout enter
      case 27: // roundabout exit
        return ManeuverKind.roundabout;
      case 25: // merge
      case 37:
      case 38:
        return ManeuverKind.merge;
      default:
        return ManeuverKind.other;
    }
  }
}

/// Provider di routing basato su Valhalla, con verifica di conformità
/// indipendente del percorso (vincolo rigido lato app).
class ValhallaRoutingProvider implements RoutingProvider {
  final Uri baseUrl;
  final HttpTransport http;
  final Duration timeout;
  final EtaModel etaModel;
  final TrunkPolicy trunkPolicy;

  ValhallaRoutingProvider({
    required this.baseUrl,
    required this.http,
    this.timeout = const Duration(seconds: 15),
    this.etaModel = const EtaModel(),
    this.trunkPolicy = TrunkPolicy.strict,
  });

  @override
  String get name => 'Valhalla (${baseUrl.host})';

  @override
  Future<Result<List<RouteResult>, RoutingError>> route(RouteRequest request) async {
    if (!ValhallaRequestBuilder.supports(request.profile)) {
      return const Err(RoutingError(RoutingErrorKind.profileNotSupported,
          'Profilo non ancora supportato in questa versione'));
    }
    if (!request.origin.isValid || !request.destination.isValid) {
      return const Err(RoutingError(
          RoutingErrorKind.locationNotRoutable, 'Coordinate non valide'));
    }

    final reply = await _post('route', ValhallaRequestBuilder.route(request));
    if (reply is Err<Map<String, dynamic>, RoutingError>) return Err(reply.error);
    final json = (reply as Ok<Map<String, dynamic>, RoutingError>).value;

    final trips = <Map<String, dynamic>>[];
    try {
      trips.add(json['trip'] as Map<String, dynamic>);
      for (final alt in (json['alternates'] as List? ?? const [])) {
        trips.add((alt as Map<String, dynamic>)['trip'] as Map<String, dynamic>);
      }
    } catch (_) {
      return const Err(RoutingError(
          RoutingErrorKind.invalidResponse, 'Risposta del server non valida'));
    }

    final accepted = <RouteResult>[];
    var rejected = 0;
    for (final t in trips) {
      RouteResult r;
      try {
        r = ValhallaParser.parseTrip(t);
      } on FormatException catch (e) {
        return Err(RoutingError(RoutingErrorKind.invalidResponse, e.message));
      } on TypeError {
        return const Err(RoutingError(
            RoutingErrorKind.invalidResponse, 'Formato percorso non valido'));
      }
      final checked = await _checkCompliance(r, request.profile);
      if (checked is Err<RouteResult, RoutingError>) {
        if (checked.error.kind == RoutingErrorKind.rejectedByCompliance) {
          rejected++;
          continue;
        }
        return Err(checked.error);
      }
      accepted.add((checked as Ok<RouteResult, RoutingError>).value);
    }

    if (accepted.isEmpty) {
      return Err(RoutingError(
          rejected > 0 ? RoutingErrorKind.rejectedByCompliance : RoutingErrorKind.noRoute,
          rejected > 0
              ? 'Il percorso trovato include tratti vietati al veicolo: '
                  'nessun percorso consentito disponibile'
              : 'Nessun percorso consentito trovato'));
    }
    return Ok(accepted);
  }

  Future<Result<RouteResult, RoutingError>> _checkCompliance(
      RouteResult r, VehicleProfile profile) async {
    final reply = await _post('trace_attributes', ValhallaRequestBuilder.traceAttributes(r.shape));
    if (reply is Err<Map<String, dynamic>, RoutingError>) {
      // Senza verifica non si dichiara il percorso conforme.
      return Err(RoutingError(reply.error.kind,
          'Impossibile verificare la conformità del percorso: ${reply.error.message}'));
    }
    final List<RouteEdge> edges;
    try {
      edges = ValhallaParser.parseEdges((reply as Ok<Map<String, dynamic>, RoutingError>).value);
    } catch (_) {
      return const Err(RoutingError(
          RoutingErrorKind.invalidResponse, 'Attributi del percorso non validi'));
    }
    final report =
        RouteComplianceValidator(profile, trunkPolicy: trunkPolicy).validate(edges);
    if (report.mustReject) {
      return const Err(RoutingError(
          RoutingErrorKind.rejectedByCompliance, 'Percorso con tratti vietati'));
    }
    final warnings = <String>[
      if (report.status == ComplianceStatus.uncertain)
        'Alcuni tratti hanno dati incompleti: la conformità non è garantita.',
      'Percorso calcolato su dati OpenStreetMap: rispetta sempre la segnaletica.',
    ];
    final segments = [
      for (final e in edges)
        EtaSegment(
          lengthM: e.lengthKm * 1000.0,
          roadClass: e.roadClass,
          use: e.use,
          // MVP: ambito urbano non noto per arco -> assunto urbano (prudente).
          urban: true,
        )
    ];
    final kinds = [for (final m in r.maneuvers) ValhallaParser.kindOf(m.type)];
    final eta = etaModel.estimate(segments, kinds, profile);
    return Ok(r.copyWith(modelTimeS: eta.totalSeconds, warnings: warnings));
  }

  Future<Result<Map<String, dynamic>, RoutingError>> _post(
      String action, Map<String, dynamic> body) async {
    final HttpReply reply;
    try {
      reply = await http.postJson(baseUrl.resolve(action), jsonEncode(body), timeout: timeout);
    } on TransportException catch (e) {
      return Err(RoutingError(
          e.noConnection
              ? RoutingErrorKind.noConnection
              : e.timeout
                  ? RoutingErrorKind.timeout
                  : RoutingErrorKind.serverUnreachable,
          e.message));
    } on TimeoutException {
      return const Err(RoutingError(RoutingErrorKind.timeout, 'Timeout'));
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(reply.body) as Map<String, dynamic>;
    } catch (_) {
      return Err(RoutingError(RoutingErrorKind.invalidResponse,
          'Risposta non JSON (HTTP ${reply.statusCode})'));
    }
    if (reply.statusCode == 200) return Ok(json);

    // Codici di errore Valhalla: 442 nessun percorso, 171 nessun arco vicino.
    final code = (json['error_code'] as num?)?.toInt();
    if (code == 442 || code == 443) {
      return const Err(RoutingError(RoutingErrorKind.noRoute,
          'Nessun percorso consentito per questo veicolo'));
    }
    if (code == 171 || code == 170 || code == 172) {
      return const Err(RoutingError(RoutingErrorKind.locationNotRoutable,
          'Partenza o destinazione lontana da strade percorribili'));
    }
    if (reply.statusCode >= 500) {
      return Err(RoutingError(
          RoutingErrorKind.serverUnreachable, 'Errore server (HTTP ${reply.statusCode})'));
    }
    return Err(RoutingError(RoutingErrorKind.invalidResponse,
        json['error']?.toString() ?? 'HTTP ${reply.statusCode}'));
  }
}
