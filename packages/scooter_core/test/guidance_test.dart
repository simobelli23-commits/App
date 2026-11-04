import 'dart:async';

import 'package:scooter_core/scooter_core.dart';
import 'package:test/test.dart';

/// Percorso a L: 791 m verso est, poi 1112 m verso nord.
RouteResult lRoute({double offsetLat = 0}) => RouteResult(
      shape: [
        LatLng(44.6450 + offsetLat, 10.9200),
        LatLng(44.6450 + offsetLat, 10.9300),
        LatLng(44.6550 + offsetLat, 10.9300),
      ],
      maneuvers: const [
        Maneuver(type: 1, instruction: 'Guida verso est su Via Emilia.',
            verbalPre: 'Guida verso est su Via Emilia.', lengthM: 791, timeS: 70,
            beginShapeIndex: 0, endShapeIndex: 1),
        Maneuver(type: 15, instruction: 'Svolta a sinistra su Via Giardini.',
            verbalAlert: 'Svolta a sinistra su Via Giardini.',
            verbalPre: 'Svolta a sinistra su Via Giardini.', lengthM: 1112, timeS: 100,
            beginShapeIndex: 1, endShapeIndex: 2),
        Maneuver(type: 4, instruction: 'Sei arrivato a destinazione.', lengthM: 0, timeS: 0,
            beginShapeIndex: 2, endShapeIndex: 2),
      ],
      lengthM: 1903,
      engineTimeS: 170,
    );

LocationFix fix(double lat, double lon, int sec, {double speed = 12.5}) => LocationFix(
    position: LatLng(lat, lon), accuracyM: 5, speedMps: speed,
    timestamp: DateTime.utc(2026, 1, 1, 12, 0, 0).add(Duration(seconds: sec)));

class RecordingVoice implements VoiceOutput {
  final said = <String>[];
  @override
  Future<void> speak(String text) async => said.add(text);
  @override
  Future<void> stop() async {}
}

class ScriptedRouting implements RoutingProvider {
  final List<Result<List<RouteResult>, RoutingError>> replies;
  final requests = <RouteRequest>[];
  ScriptedRouting(this.replies);
  @override
  String get name => 'scripted';
  @override
  Future<Result<List<RouteResult>, RoutingError>> route(RouteRequest r) async {
    requests.add(r);
    return replies[requests.length - 1 < replies.length ? requests.length - 1 : replies.length - 1];
  }
}

void main() {
  group('Formattazione italiana', () {
    test('distanze', () {
      expect(FormatIt.distance(83), '80 m');
      expect(FormatIt.distance(437), '450 m');
      expect(FormatIt.distance(1234), '1,2 km');
      expect(FormatIt.distance(15400), '15 km');
      expect(FormatIt.spokenDistance(149), '150 metri');
      expect(FormatIt.spokenDistance(1000), '1 chilometro');
      expect(FormatIt.spokenDistance(2510), '2,5 chilometri');
    });
    test('durate e orario', () {
      expect(FormatIt.duration(42), '42 s');
      expect(FormatIt.duration(721), '12 min');
      expect(FormatIt.duration(3900), '1 h 05 min');
      expect(FormatIt.clock(DateTime(2026, 1, 1, 9, 5)), '09:05');
    });
  });

  group('Annunci vocali', () {
    NavigationSnapshot snap(int i, double d, [NavStatus st = NavStatus.onRoute]) =>
        NavigationSnapshot(status: st, maneuverIndex: i, distanceToManeuverM: d,
            remainingM: 1000, remainingS: 100, snapped: null, shouldReroute: false);
    final man = lRoute().maneuvers;

    test('tre fasi, ciascuna una sola volta', () {
      final p = VoicePlanner();
      expect(p.plan(snap(1, 700), man, speedMps: 12.5), isEmpty);
      expect(p.plan(snap(1, 500), man, speedMps: 12.5),
          ['Tra 500 metri, svolta a sinistra su Via Giardini.']);
      expect(p.plan(snap(1, 480), man, speedMps: 12.5), isEmpty);
      expect(p.plan(snap(1, 120), man, speedMps: 12.5),
          ['Tra 100 metri, svolta a sinistra su Via Giardini.']);
      expect(p.plan(snap(1, 35), man, speedMps: 12.5), ['Svolta a sinistra su Via Giardini.']);
      expect(p.plan(snap(1, 10), man, speedMps: 12.5), isEmpty);
    });

    test('se si salta direttamente vicino, niente annuncio lontano tardivo', () {
      final p = VoicePlanner();
      expect(p.plan(snap(1, 90), man, speedMps: 5), hasLength(1));
      expect(p.plan(snap(1, 400), man, speedMps: 5), isEmpty);
    });

    test('soglie proporzionali alla velocità', () {
      final slow = VoicePlanner(), fast = VoicePlanner();
      expect(slow.plan(snap(1, 50), man, speedMps: 2), isNot(contains('Svolta a sinistra su Via Giardini.')));
      expect(fast.plan(snap(1, 50), man, speedMps: 20), ['Svolta a sinistra su Via Giardini.']);
    });

    test('arrivo annunciato una volta; nessun annuncio fuori percorso', () {
      final p = VoicePlanner();
      expect(p.plan(snap(1, 100, NavStatus.offRoute), man), isEmpty);
      expect(p.plan(snap(2, 0, NavStatus.arrived), man), ['Sei arrivato a destinazione.']);
      expect(p.plan(snap(2, 0, NavStatus.arrived), man), isEmpty);
    });

    test('partenza', () {
      final p = VoicePlanner();
      expect(p.departure(man), 'Guida verso est su Via Emilia.');
      expect(p.departure(man), isNull);
    });
  });

  group('Motore di navigazione', () {
    const dest = LatLng(44.6550, 10.9300);

    test('avvio: calcolo, annuncio di partenza, guida e arrivo', () async {
      final voice = RecordingVoice();
      final routing = ScriptedRouting([Ok([lRoute()])]);
      final e = NavigationEngine(routing: routing, profile: VehicleProfiles.a50cc,
          destination: dest, voice: voice);
      final res = await e.start(const LatLng(44.6450, 10.9200));
      expect(res, isA<Ok>());
      expect(e.status, EngineStatus.navigating);
      expect(routing.requests.single.profile.id, VehicleProfiles.a50cc.id);
      expect(voice.said, ['Guida verso est su Via Emilia.']);

      e.onFix(fix(44.6450, 10.9255, 0)); // ~350 m dalla svolta: fase "lontano"
      expect(e.snapshot!.maneuverIndex, 1);
      expect(voice.said.last, startsWith('Tra 350 metri'));
      e.onFix(fix(44.6450, 10.9296, 30)); // ~32 m
      expect(voice.said.last, 'Svolta a sinistra su Via Giardini.');
      e.onFix(fix(44.6549, 10.9300, 120));
      expect(e.status, EngineStatus.arrived);
      expect(voice.said.last, 'Sei arrivato a destinazione.');
      await e.dispose();
    });

    test('nessun percorso: stato fallito, nessuna alternativa inventata', () async {
      final e = NavigationEngine(
          routing: ScriptedRouting([const Err(RoutingError(RoutingErrorKind.noRoute, 'x'))]),
          profile: VehicleProfiles.a50cc, destination: dest);
      final res = await e.start(const LatLng(44.6450, 10.9200));
      expect(res, isA<Err>());
      expect(e.status, EngineStatus.failed);
      expect(e.route, isNull);
      await e.dispose();
    });

    test('fuori percorso: ricalcolo dalla posizione attuale con direzione', () async {
      final voice = RecordingVoice();
      final routing = ScriptedRouting([Ok([lRoute()]), Ok([lRoute(offsetLat: -0.001)])]);
      final e = NavigationEngine(routing: routing, profile: VehicleProfiles.a50cc,
          destination: dest, voice: voice);
      await e.start(const LatLng(44.6450, 10.9200));
      e.onFix(fix(44.6450, 10.9220, 0));
      for (var i = 1; i <= 3; i++) {
        e.onFix(LocationFix(position: LatLng(44.6440, 10.9240 + i * 0.0001), accuracyM: 5,
            headingDeg: 90, speedMps: 10,
            timestamp: DateTime.utc(2026, 1, 1, 12, 0, i)));
      }
      await Future<void>.delayed(Duration.zero);
      expect(routing.requests, hasLength(2));
      expect(routing.requests[1].origin.lat, closeTo(44.6440, 1e-9));
      expect(routing.requests[1].headingDeg, 90);
      expect(voice.said, contains('Ricalcolo del percorso.'));
      expect(e.rerouteCount, 1);
      expect(e.status, EngineStatus.navigating);
      expect(e.route!.shape.first.lat, closeTo(44.6440, 1e-9));
      await e.dispose();
    });

    test('ricalcolo senza connessione: percorso precedente mantenuto, avviso', () async {
      final voice = RecordingVoice();
      final first = lRoute();
      final routing = ScriptedRouting([
        Ok([first]),
        const Err(RoutingError(RoutingErrorKind.noConnection, 'offline')),
      ]);
      final e = NavigationEngine(routing: routing, profile: VehicleProfiles.a50cc,
          destination: dest, voice: voice);
      await e.start(const LatLng(44.6450, 10.9200));
      for (var i = 0; i < 3; i++) {
        e.onFix(fix(44.6440, 10.9240 + i * 0.0001, i));
      }
      await Future<void>.delayed(Duration.zero);
      expect(identical(e.route, first), isTrue);
      expect(e.notice, EngineNotice.rerouteNoConnection);
      expect(voice.said.last, contains('Connessione assente'));
      await e.dispose();
    });

    test('perdita GPS annunciata una volta, poi ripristino', () async {
      final voice = RecordingVoice();
      final e = NavigationEngine(routing: ScriptedRouting([Ok([lRoute()])]),
          profile: VehicleProfiles.a50cc, destination: dest, voice: voice);
      await e.start(const LatLng(44.6450, 10.9200));
      e.onFix(fix(44.6450, 10.9210, 0));
      e.onTick(DateTime.utc(2026, 1, 1, 12, 0, 11));
      e.onTick(DateTime.utc(2026, 1, 1, 12, 0, 12));
      expect(e.notice, EngineNotice.gpsLost);
      expect(voice.said.where((s) => s.contains('GPS')), hasLength(1));
      e.onFix(fix(44.6450, 10.9215, 13));
      expect(e.notice, EngineNotice.none);
      await e.dispose();
    });

    test('voce disattivata: nessun annuncio', () async {
      final voice = RecordingVoice();
      final e = NavigationEngine(routing: ScriptedRouting([Ok([lRoute()])]),
          profile: VehicleProfiles.a50cc, destination: dest, voice: voice,
          voiceEnabled: false);
      await e.start(const LatLng(44.6450, 10.9200));
      e.onFix(fix(44.6450, 10.9296, 0));
      expect(voice.said, isEmpty);
      await e.dispose();
    });

    test('errore del TTS non interrompe la navigazione', () async {
      final e = NavigationEngine(routing: ScriptedRouting([Ok([lRoute()])]),
          profile: VehicleProfiles.a50cc, destination: dest, voice: _FailingVoice());
      await e.start(const LatLng(44.6450, 10.9200));
      e.onFix(fix(44.6450, 10.9296, 0));
      await Future<void>.delayed(Duration.zero);
      expect(e.status, EngineStatus.navigating);
      await e.dispose();
    });
  });
}

class _FailingVoice implements VoiceOutput {
  @override
  Future<void> speak(String text) => Future.error(StateError('tts'));
  @override
  Future<void> stop() async {}
}
