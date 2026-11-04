import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigatore_scooter/app/app.dart';
import 'package:navigatore_scooter/app/app_config.dart';
import 'package:navigatore_scooter/features/location/location_controller.dart';
import 'package:navigatore_scooter/features/settings/settings_controller.dart';
import 'package:scooter_core/scooter_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_doubles.dart';

void main() {
  late SharedPreferences prefs;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 11, 4, 12);
  });

  Future<(RecordingMapFactory, ControlledLocationProvider, LocationController)> pumpApp(
      WidgetTester tester, List<Result<void, LocationError>> ready) async {
    final maps = RecordingMapFactory();
    final provider = ControlledLocationProvider(ready);
    final loc = LocationController(provider, clock: () => now);
    await tester.pumpWidget(ScooterApp(
        settings: SettingsController(prefs), location: loc, mapFactory: maps));
    await tester.pump();
    addTearDown(loc.dispose);
    return (maps, provider, loc);
  }

  testWidgets('schermata iniziale: mappa, ricerca, impostazioni, profilo, attribuzione',
      (tester) async {
    final (maps, _, _) = await pumpApp(tester, [ok]);
    expect(find.byKey(const Key('test-map')), findsOneWidget);
    expect(maps.styleUrl, AppConfig.mapStyleUrl);
    expect(find.byKey(const Key('search-placeholder')), findsOneWidget);
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
    expect(find.byKey(const Key('recenter')), findsOneWidget);
    expect(find.text('Ciclomotore 50 cc (45 km/h)'), findsOneWidget);
    expect(find.textContaining('OpenStreetMap contributors'), findsOneWidget);
    expect(find.byKey(const Key('location-banner-waitingFix')), findsOneWidget);
  });

  testWidgets('primo fix: posizione mostrata e mappa centrata con zoom', (tester) async {
    final (maps, provider, _) = await pumpApp(tester, [ok]);
    provider.fixesCtrl.add(fixAt(44.65, 10.93));
    await tester.pump();
    await tester.pump();
    expect(maps.map.positions, [const LatLng(44.65, 10.93)]);
    expect(maps.map.centers.single.$1, const LatLng(44.65, 10.93));
    expect(maps.map.centers.single.$2, AppConfig.followZoom);
    expect(find.byKey(const Key('location-banner-waitingFix')), findsNothing);
  });

  testWidgets('ricentraggio usa l\'ultima posizione', (tester) async {
    final (maps, provider, _) = await pumpApp(tester, [ok]);
    provider.fixesCtrl.add(fixAt(44.65, 10.93));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('recenter')));
    await tester.pump();
    expect(maps.map.centers.last.$1, const LatLng(44.65, 10.93));
  });

  testWidgets('ricentraggio senza posizione: avviso, nessun crash', (tester) async {
    final (maps, _, _) = await pumpApp(tester, [ok]);
    await tester.tap(find.byKey(const Key('recenter')));
    await tester.pump();
    expect(find.text('Posizione non ancora disponibile'), findsOneWidget);
    expect(maps.map.centers, isEmpty);
  });

  testWidgets('GPS disattivato: messaggio e apertura impostazioni', (tester) async {
    final (_, provider, _) =
        await pumpApp(tester, [err(LocationErrorKind.serviceDisabled), ok]);
    expect(find.byKey(const Key('location-banner-serviceDisabled')), findsOneWidget);
    await tester.tap(find.text('Apri impostazioni'));
    await tester.pump();
    expect(provider.openLocationSettingsCalls, 1);
    expect(provider.ensureReadyCalls, 2);
    expect(find.byKey(const Key('location-banner-waitingFix')), findsOneWidget);
  });

  testWidgets('permesso negato: nuova richiesta', (tester) async {
    final (_, provider, _) =
        await pumpApp(tester, [err(LocationErrorKind.permissionDenied), ok]);
    expect(find.byKey(const Key('location-banner-permissionDenied')), findsOneWidget);
    await tester.tap(find.text('Concedi permesso'));
    await tester.pump();
    expect(provider.ensureReadyCalls, 2);
  });

  testWidgets('permesso negato in modo permanente: impostazioni app', (tester) async {
    final (_, provider, _) =
        await pumpApp(tester, [err(LocationErrorKind.permissionDeniedForever)]);
    await tester.tap(find.text('Impostazioni app'));
    await tester.pump();
    expect(provider.openAppSettingsCalls, 1);
  });

  testWidgets('perdita del segnale GPS dopo 10 s senza fix', (tester) async {
    final (_, provider, _) = await pumpApp(tester, [ok]);
    provider.fixesCtrl.add(fixAt(44.65, 10.93));
    await tester.pump();
    await tester.pump();
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('location-banner-signalLost')), findsNothing);
    now = now.add(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('location-banner-signalLost')), findsOneWidget);
    provider.fixesCtrl.add(fixAt(44.651, 10.931));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('location-banner-signalLost')), findsNothing);
  });

  testWidgets('errore dello stream GPS: stato non disponibile, riprova', (tester) async {
    final (_, provider, loc) = await pumpApp(tester, [ok]);
    provider.fixesCtrl.addError(StateError('gps'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('location-banner-unavailable')), findsOneWidget);
    await tester.tap(find.text('Riprova'));
    await tester.pump();
    await tester.pump();
    expect(loc.status, LocationStatus.waitingFix);
    expect(provider.ensureReadyCalls, 2);
  });
}
