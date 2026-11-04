@Tags(['integration'])
library;

import 'dart:io';

import 'package:scooter_core/scooter_core.dart';
import 'package:scooter_core/scooter_core_io.dart';
import 'package:test/test.dart';

/// Test end-to-end contro un server Valhalla REALE che serve le tile
/// costruite da routing/valhalla/fixtures/scenarios.osm.pbf (rete sintetica).
/// Avvio: vedi routing/valhalla/README.md. Impostare VALHALLA_URL
/// (es. http://127.0.0.1:8002/). Senza la variabile i test vengono saltati
/// e lo dichiarano.
void main() {
  final url = Platform.environment['VALHALLA_URL'];
  final skip = url == null ? 'VALHALLA_URL non impostata: server reale assente' : null;
  late IoHttpTransport transport;
  late ValhallaRoutingProvider provider;

  setUpAll(() {
    transport = IoHttpTransport();
    provider = ValhallaRoutingProvider(baseUrl: Uri.parse(url ?? 'http://invalid/'), http: transport);
  });
  tearDownAll(() => transport.close());

  // Coordinate dal manifest della rete sintetica (scenari a lat 44.50 + i*0.03).
  RouteRequest at(double lat) => RouteRequest(
      origin: LatLng(lat, 10.696),
      destination: LatLng(lat, 10.724),
      profile: VehicleProfiles.a50cc);

  test('scenario motorway: percorso valido che evita l\'autostrada', () async {
    final res = await provider.route(at(44.50));
    expect(res, isA<Ok<List<RouteResult>, RoutingError>>(), reason: '$res');
    final routes = (res as Ok<List<RouteResult>, RoutingError>).value;
    final r = routes.first;
    // deviazione residenziale ~3,6 km; percorso via autostrada ~2,2 km
    expect(r.lengthM, greaterThan(3000));
    expect(r.maneuvers, isNotEmpty);
    expect(r.maneuvers.first.instruction, isNotEmpty);
    expect(r.modelTimeS, greaterThan(0));
    final names = r.maneuvers.expand((m) => m.streetNames).toList();
    expect(names.any((n) => n.contains('scorciatoia')), isFalse, reason: '$names');
  }, skip: skip);

  test('scenario motorway_only: nessun percorso, nessuna alternativa inventata', () async {
    final res = await provider.route(at(44.53));
    expect(res, isA<Err<List<RouteResult>, RoutingError>>());
    expect((res as Err<List<RouteResult>, RoutingError>).error.kind, RoutingErrorKind.noRoute);
  }, skip: skip);

  test('istruzioni in italiano', () async {
    final res = await provider.route(at(44.50 + 14 * 0.03)); // residential_ok
    final r = (res as Ok<List<RouteResult>, RoutingError>).value.first;
    final text = r.maneuvers.map((m) => m.instruction).join(' ').toLowerCase();
    expect(text, anyOf(contains('svolta'), contains('procedi'), contains('dirigiti'),
        contains('arrivat'), contains('destinazione')), reason: text);
  }, skip: skip);

  test('server irraggiungibile: errore gestito', () async {
    final t = IoHttpTransport();
    final p = ValhallaRoutingProvider(baseUrl: Uri.parse('http://127.0.0.1:1/'), http: t);
    final res = await p.route(at(44.50));
    t.close();
    expect((res as Err).error.kind,
        anyOf(RoutingErrorKind.serverUnreachable, RoutingErrorKind.noConnection));
  });
}
