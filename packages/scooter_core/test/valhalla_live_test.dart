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

  group('navigazione', () => navigationLiveTests(url));

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

/// Navigazione completa contro il server reale: guida simulata lungo il
/// percorso calcolato (posizioni sintetiche), uscita di strada e ricalcolo.
void navigationLiveTests(String? url) {
  final skip = url == null ? 'VALHALLA_URL non impostata: server reale assente' : null;

  test('guida lungo il percorso reale: annunci delle svolte e arrivo', () async {
    final t = IoHttpTransport();
    final voice = _Voice();
    final e = NavigationEngine(
        routing: ValhallaRoutingProvider(baseUrl: Uri.parse(url!), http: t),
        profile: VehicleProfiles.a50cc,
        destination: const LatLng(44.50, 10.724),
        voice: voice);
    final res = await e.start(const LatLng(44.50, 10.696));
    expect(res, isA<Ok<RouteResult, RoutingError>>(), reason: '$res');
    final shape = Polyline(e.route!.shape);
    final start = DateTime.utc(2026, 1, 1, 12);
    // un fix ogni 10 m a ~10 m/s
    for (var along = 0.0, s = 0; along <= shape.lengthM; along += 10, s++) {
      e.onFix(LocationFix(position: _pointAt(shape, along), accuracyM: 5, speedMps: 10,
          timestamp: start.add(Duration(seconds: s))));
    }
    e.onFix(LocationFix(position: e.route!.shape.last, accuracyM: 5, speedMps: 0,
        timestamp: start.add(const Duration(hours: 1))));
    expect(e.status, EngineStatus.arrived);
    final turns = voice.said.where((s) => s.toLowerCase().contains('svolta')).toList();
    // il percorso che evita l'autostrada ha 2 svolte a sinistra
    expect(turns.where((s) => s.startsWith('Tra ')), isNotEmpty, reason: '${voice.said}');
    expect(turns.where((s) => s.startsWith('Svolta')), hasLength(2), reason: '${voice.said}');
    expect(voice.said.last, 'Sei arrivato a destinazione.');
    expect(e.rerouteCount, 0);
    await e.dispose();
    t.close();
  }, skip: skip);

  test('uscita dal percorso: ricalcolo reale dalla nuova posizione', () async {
    final t = IoHttpTransport();
    const lat = 44.50 + 14 * 0.03; // residential_ok: scorciatoia diretta consentita
    final e = NavigationEngine(
        routing: ValhallaRoutingProvider(baseUrl: Uri.parse(url!), http: t),
        profile: VehicleProfiles.a50cc,
        destination: const LatLng(lat, 10.724),
        voice: _Voice());
    await e.start(const LatLng(lat, 10.696));
    final before = e.route!;
    final start = DateTime.utc(2026, 1, 1, 12);
    // si imbocca la strada di deviazione verso nord (fuori dal percorso)
    for (var i = 0; i < 4; i++) {
      e.onFix(LocationFix(position: LatLng(lat + 0.0008 + i * 0.0004, 10.700), accuracyM: 5,
          speedMps: 8, headingDeg: 0, timestamp: start.add(Duration(seconds: i))));
    }
    for (var i = 0; i < 50 && e.status == EngineStatus.rerouting; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(e.rerouteCount, 1);
    expect(e.status, EngineStatus.navigating);
    expect(identical(e.route, before), isFalse);
    expect(e.route!.shape.first.lat, greaterThan(lat + 0.001));
    expect(e.route!.lengthM, greaterThan(before.lengthM * 0.5));
    await e.dispose();
    t.close();
  }, skip: skip);
}

LatLng _pointAt(Polyline line, double along) {
  for (var i = 0; i < line.points.length - 1; i++) {
    final a = line.cumulativeM[i], b = line.cumulativeM[i + 1];
    if (along <= b) {
      final f = b == a ? 0.0 : (along - a) / (b - a);
      final p = line.points[i], q = line.points[i + 1];
      return LatLng(p.lat + (q.lat - p.lat) * f, p.lon + (q.lon - p.lon) * f);
    }
  }
  return line.points.last;
}

class _Voice implements VoiceOutput {
  final said = <String>[];
  @override
  Future<void> speak(String text) async => said.add(text);
  @override
  Future<void> stop() async {}
}
