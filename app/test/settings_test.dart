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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<SettingsController> pumpSettings(WidgetTester tester) async {
    final settings = SettingsController(prefs);
    final loc = LocationController(ControlledLocationProvider([ok]));
    addTearDown(loc.dispose);
    await tester.pumpWidget(ScooterApp(
        settings: settings,
        location: loc,
        mapFactory: RecordingMapFactory(),
        routing: ScriptedRouting([
          Ok([lRoute()])
        ])));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('tema scuro applicato e salvato', (tester) async {
    final settings = await pumpSettings(tester);
    await tester.tap(find.text('Scuro'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.dark);
    expect(prefs.getString('theme_mode'), 'dark');
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(Theme.of(tester.element(find.text('Impostazioni'))).brightness,
        Brightness.dark);
  });

  testWidgets('indicazioni vocali disattivabili e persistenti', (tester) async {
    final settings = await pumpSettings(tester);
    expect(settings.voiceEnabled, isTrue);
    await tester.tap(find.byKey(const Key('settings-voice')));
    await tester.pumpAndSettle();
    expect(prefs.getBool('voice_enabled'), isFalse);
    expect(SettingsController(prefs).voiceEnabled, isFalse);
  });

  testWidgets('profilo veicolo: solo il ciclomotore è selezionabile',
      (tester) async {
    final settings = await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('settings-vehicle')));
    await tester.pumpAndSettle();
    final b = tester.widget<RadioListTile<String>>(
        find.byKey(Key('profile-${VehicleProfiles.b125Adult.id}')));
    final a = tester.widget<RadioListTile<String>>(
        find.byKey(Key('profile-${VehicleProfiles.a50cc.id}')));
    expect(a.enabled, isTrue);
    expect(b.enabled, isFalse);
    await tester
        .tap(find.byKey(Key('profile-${VehicleProfiles.b125Adult.id}')));
    await tester.pumpAndSettle();
    expect(settings.vehicleProfile.id, VehicleProfiles.a50cc.id);
    expect(find.textContaining('Non ancora disponibile'), findsNWidgets(3));
  });

  test('profilo salvato non supportato: si torna al ciclomotore', () async {
    SharedPreferences.setMockInitialValues(
        {'vehicle_profile': VehicleProfiles.dOver125.id});
    final p = await SharedPreferences.getInstance();
    expect(SettingsController(p).vehicleProfile.id, VehicleProfiles.a50cc.id);
    expect(
        () => SettingsController(p).setVehicleProfile(VehicleProfiles.dOver125),
        throwsArgumentError);
  });

  testWidgets('attribuzioni ODbL e privacy accessibili', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('settings-attributions')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open Database License'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-privacy')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Non viene registrata né inviata a server'),
        findsOneWidget);
  });
}
