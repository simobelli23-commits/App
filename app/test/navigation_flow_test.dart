import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigatore_scooter/app/app.dart';
import 'package:navigatore_scooter/features/location/location_controller.dart';
import 'package:navigatore_scooter/features/settings/settings_controller.dart';
import 'package:scooter_core/scooter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_doubles.dart';

void main() {
  late SharedPreferences prefs;
  final screenOn = <bool>[];
  setUp(() async {
    screenOn.clear();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<
          ({
            RecordingMapFactory maps,
            ControlledLocationProvider gps,
            ScriptedRouting routing,
            RecordingVoice voice,
          })>
      pumpApp(WidgetTester tester,
          List<Result<List<RouteResult>, RoutingError>> replies,
          {bool withFix = true}) async {
    final maps = RecordingMapFactory();
    final gps = ControlledLocationProvider([ok]);
    final loc = LocationController(gps);
    final routing = ScriptedRouting(replies);
    final voice = RecordingVoice();
    addTearDown(loc.dispose);
    await tester.pumpWidget(ScooterApp(
        settings: SettingsController(prefs),
        location: loc,
        mapFactory: maps,
        routing: routing,
        voice: voice,
        keepScreenOn: (on) async => screenOn.add(on)));
    await tester.pump();
    if (withFix) {
      gps.fixesCtrl.add(fixAt(44.6450, 10.9200));
      await tester.pump();
      await tester.pump();
    }
    return (maps: maps, gps: gps, routing: routing, voice: voice);
  }

  Future<void> longPress(WidgetTester tester, RecordingMapFactory maps) async {
    maps.onLongPress!(const LatLng(44.6550, 10.9300));
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
      'pressione prolungata: calcolo e anteprima con distanza, stima e avvisi',
      (tester) async {
    final app = await pumpApp(tester, [
      Ok([
        lRoute(warnings: [
          'Percorso calcolato su dati OpenStreetMap: rispetta sempre la segnaletica.'
        ]),
        lRoute(km: 2.4),
      ])
    ]);
    await longPress(tester, app.maps);
    expect(app.routing.requests.single.profile.id, VehicleProfiles.a50cc.id);
    expect(app.routing.requests.single.origin, const LatLng(44.6450, 10.9200));
    expect(app.maps.map.destination, const LatLng(44.6550, 10.9300));
    expect(find.text('1,9 km · 4 min (stima)'), findsOneWidget);
    expect(
        find.textContaining('rispetta sempre la segnaletica'), findsOneWidget);
    expect(app.maps.map.routes, hasLength(2));
    // selezione dell'alternativa: diventa il percorso disegnato per primo
    await tester.tap(find.byKey(const Key('route-option-1')));
    await tester.pump();
    expect(find.text('2,4 km · 4 min (stima)'), findsOneWidget);
  });

  testWidgets('senza posizione GPS: nessuna richiesta, messaggio chiaro',
      (tester) async {
    final app = await pumpApp(
        tester,
        [
          Ok([lRoute()])
        ],
        withFix: false);
    await longPress(tester, app.maps);
    expect(app.routing.requests, isEmpty);
    expect(find.textContaining('Serve la posizione GPS'), findsOneWidget);
  });

  testWidgets(
      'nessun percorso consentito: messaggio, niente pulsante Avvia, riprova',
      (tester) async {
    final app = await pumpApp(tester, [
      const Err(RoutingError(RoutingErrorKind.noRoute, 'x')),
      Ok([lRoute()]),
    ]);
    await longPress(tester, app.maps);
    expect(find.textContaining('Nessun percorso consentito'), findsOneWidget);
    expect(find.byKey(const Key('route-start')), findsNothing);
    await tester.tap(find.byKey(const Key('route-retry')));
    await tester.pump();
    await tester.pump();
    expect(app.routing.requests, hasLength(2));
    expect(find.byKey(const Key('route-start')), findsOneWidget);
  });

  testWidgets(
      'server non raggiungibile e connessione assente: messaggi distinti',
      (tester) async {
    final app = await pumpApp(tester, [
      const Err(RoutingError(RoutingErrorKind.serverUnreachable, 'refused')),
      const Err(RoutingError(RoutingErrorKind.noConnection, 'offline')),
    ]);
    await longPress(tester, app.maps);
    expect(find.textContaining('non raggiungibile'), findsOneWidget);
    await tester.tap(find.byKey(const Key('route-retry')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Connessione assente'), findsOneWidget);
  });

  testWidgets('annulla: destinazione e percorsi rimossi', (tester) async {
    final app = await pumpApp(tester, [
      Ok([lRoute()])
    ]);
    await longPress(tester, app.maps);
    await tester.tap(find.byKey(const Key('route-cancel')));
    await tester.pump();
    expect(app.maps.map.destination, isNull);
    expect(app.maps.map.routes, isEmpty);
    expect(find.byKey(const Key('route-preview')), findsNothing);
  });

  testWidgets('guida: manovra, distanza, voce, ricalcolo e arrivo',
      (tester) async {
    final app = await pumpApp(tester, [
      Ok([lRoute()]),
      Ok([lRoute()])
    ]);
    await longPress(tester, app.maps);
    await tester.tap(find.byKey(const Key('route-start')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nav-maneuver')), findsOneWidget);
    expect(screenOn, [true], reason: 'schermo acceso durante la guida');
    expect(app.voice.said.first, 'Guida verso est su Via Emilia.');
    expect(find.textContaining('Arrivo '), findsOneWidget);

    // ~350 m dalla svolta a sinistra
    app.gps.fixesCtrl.add(LocationFix(
        position: const LatLng(44.6450, 10.9255),
        accuracyM: 5,
        speedMps: 12,
        timestamp: DateTime.now()));
    await tester.pump();
    await tester.pump();
    expect(find.text('350 m'), findsOneWidget);
    expect(find.text('Svolta a sinistra su Via Giardini.'), findsOneWidget);
    expect(app.voice.said.last, startsWith('Tra 350 metri'));

    // tre fix fuori percorso -> ricalcolo dalla posizione attuale
    for (var i = 0; i < 3; i++) {
      app.gps.fixesCtrl.add(LocationFix(
          position: LatLng(44.6430, 10.9260 + i * 0.0001),
          accuracyM: 5,
          timestamp: DateTime.now()));
      await tester.pump();
      await tester.pump();
    }
    expect(app.routing.requests, hasLength(2));
    expect(app.routing.requests.last.origin.lat, closeTo(44.6430, 1e-9));
    expect(app.voice.said, contains('Ricalcolo del percorso.'));

    // arrivo
    app.gps.fixesCtrl.add(LocationFix(
        position: const LatLng(44.6549, 10.9300),
        accuracyM: 5,
        timestamp: DateTime.now()));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('nav-arrived')), findsOneWidget);
    expect(app.voice.said.last, 'Sei arrivato a destinazione.');

    await tester.tap(find.byKey(const Key('nav-stop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-placeholder')), findsOneWidget);
    expect(find.byKey(const Key('route-preview')), findsNothing);
    expect(screenOn, [true, false]);
  });

  testWidgets('guida con voce disattivata: nessun annuncio', (tester) async {
    await prefs.setBool('voice_enabled', false);
    final app = await pumpApp(tester, [
      Ok([lRoute()])
    ]);
    await longPress(tester, app.maps);
    await tester.tap(find.byKey(const Key('route-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav-maneuver')), findsOneWidget);
    expect(app.voice.said, isEmpty);
    await tester.tap(find.byKey(const Key('nav-stop')));
    await tester.pumpAndSettle();
  });
}
