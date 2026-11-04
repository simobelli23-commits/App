import 'dart:convert';

import 'package:scooter_core/scooter_core.dart';
import 'package:test/test.dart';

/// Trasporto di test: risponde con JSON nel formato documentato dell'API
/// Valhalla. NON sostituisce i test di integrazione contro un server reale
/// (scripts/valhalla_integration_test.py), verifica parsing e gestione errori.
class ScriptedTransport implements HttpTransport {
  final Map<String, HttpReply Function(Map<String, dynamic> body)> handlers;
  final List<Map<String, dynamic>> requests = [];
  final Object? throwOnCall;
  ScriptedTransport(this.handlers, {this.throwOnCall});

  @override
  Future<HttpReply> postJson(Uri url, String body, {Duration? timeout}) async {
    if (throwOnCall != null) throw throwOnCall!;
    final b = jsonDecode(body) as Map<String, dynamic>;
    requests.add({'action': url.pathSegments.last, ...b});
    return handlers[url.pathSegments.last]!(b);
  }
}

const shapePts = [LatLng(44.6450, 10.9200), LatLng(44.6450, 10.9300), LatLng(44.6550, 10.9300)];

String tripJson() => jsonEncode({
      'trip': {
        'status': 0,
        'legs': [
          {
            'shape': encodePolyline(shapePts),
            'maneuvers': [
              {'type': 1, 'instruction': 'Procedi verso est.', 'length': 0.791,
                'time': 70, 'begin_shape_index': 0, 'end_shape_index': 1,
                'street_names': ['Via Emilia']},
              {'type': 15, 'instruction': 'Svolta a sinistra.', 'length': 1.112,
                'time': 100, 'begin_shape_index': 1, 'end_shape_index': 2},
              {'type': 4, 'instruction': 'Sei arrivato.', 'length': 0, 'time': 0,
                'begin_shape_index': 2, 'end_shape_index': 2},
            ]
          }
        ],
        'summary': {'length': 1.903, 'time': 170}
      }
    });

HttpReply edges(List<List<String>> classUse) => HttpReply(
    200,
    jsonEncode({
      'edges': [
        for (final cu in classUse)
          {'way_id': 1, 'road_class': cu[0], 'use': cu[1], 'length': 0.5, 'names': ['X']}
      ]
    }));

RouteRequest req([VehicleProfile p = VehicleProfiles.a50cc]) => RouteRequest(
    origin: const LatLng(44.645, 10.92), destination: const LatLng(44.655, 10.93), profile: p);

ValhallaRoutingProvider provider(HttpTransport t) =>
    ValhallaRoutingProvider(baseUrl: Uri.parse('http://localhost:8002/'), http: t);

void main() {
  test('richiesta: costing motor_scooter con top_speed 45', () {
    final body = ValhallaRequestBuilder.route(req());
    expect(body['costing'], 'motor_scooter');
    expect((body['costing_options'] as Map)['motor_scooter']['top_speed'], 45);
    expect((body['directions_options'] as Map)['language'], 'it-IT');
  });

  test('percorso conforme: parsing, avvisi ed ETA del modello', () async {
    final t = ScriptedTransport({
      'route': (_) => HttpReply(200, tripJson()),
      'trace_attributes': (_) => edges([['residential', 'road'], ['tertiary', 'road']]),
    });
    final res = await provider(t).route(req());
    expect(res, isA<Ok<List<RouteResult>, RoutingError>>());
    final r = (res as Ok<List<RouteResult>, RoutingError>).value.single;
    expect(r.shape.length, 3);
    expect(r.maneuvers[1].lengthM, closeTo(1112, 1e-6));
    expect(r.maneuvers[0].streetNames, ['Via Emilia']);
    expect(r.lengthM, closeTo(1903, 1e-6));
    expect(r.modelTimeS, isNotNull);
    expect(r.warnings, isNotEmpty);
    expect(t.requests.map((r) => r['action']), ['route', 'trace_attributes']);
  });

  test('percorso con autostrada: rifiutato dal validatore', () async {
    final t = ScriptedTransport({
      'route': (_) => HttpReply(200, tripJson()),
      'trace_attributes': (_) => edges([['residential', 'road'], ['motorway', 'road']]),
    });
    final res = await provider(t).route(req());
    expect((res as Err).error.kind, RoutingErrorKind.rejectedByCompliance);
  });

  test('errore Valhalla 442: nessun percorso, nessuna alternativa inventata', () async {
    final t = ScriptedTransport({
      'route': (_) => const HttpReply(400,
          '{"error_code":442,"error":"No path could be found for input","status_code":400}'),
    });
    final res = await provider(t).route(req());
    expect((res as Err).error.kind, RoutingErrorKind.noRoute);
  });

  test('errore 171: punto non raggiungibile', () async {
    final t = ScriptedTransport({
      'route': (_) => const HttpReply(400, '{"error_code":171,"error":"No suitable edges"}'),
    });
    expect(((await provider(t).route(req())) as Err).error.kind,
        RoutingErrorKind.locationNotRoutable);
  });

  test('risposta non JSON o malformata', () async {
    final t1 = ScriptedTransport({'route': (_) => const HttpReply(200, '<html>')});
    expect(((await provider(t1).route(req())) as Err).error.kind,
        RoutingErrorKind.invalidResponse);
    final t2 = ScriptedTransport({'route': (_) => const HttpReply(200, '{"trip":{"legs":[]}}')});
    expect(((await provider(t2).route(req())) as Err).error.kind,
        RoutingErrorKind.invalidResponse);
  });

  test('assenza di connessione e server irraggiungibile', () async {
    final t1 = ScriptedTransport({},
        throwOnCall: const TransportException('offline', noConnection: true));
    expect(((await provider(t1).route(req())) as Err).error.kind,
        RoutingErrorKind.noConnection);
    final t2 = ScriptedTransport({}, throwOnCall: const TransportException('refused'));
    expect(((await provider(t2).route(req())) as Err).error.kind,
        RoutingErrorKind.serverUnreachable);
  });

  test('verifica di conformità non disponibile: percorso non presentato come valido',
      () async {
    final t = ScriptedTransport({
      'route': (_) => HttpReply(200, tripJson()),
      'trace_attributes': (_) => const HttpReply(503, '{"error":"busy"}'),
    });
    final res = await provider(t).route(req());
    expect(res, isA<Err>());
  });

  test('profilo non supportato', () async {
    final t = ScriptedTransport({});
    final res = await provider(t).route(req(VehicleProfiles.b125Adult));
    expect((res as Err).error.kind, RoutingErrorKind.profileNotSupported);
    expect(t.requests, isEmpty);
  });
}
