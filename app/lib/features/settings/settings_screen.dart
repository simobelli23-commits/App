import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../vehicle/vehicle_screen.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsController settings;
  const SettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(children: [
          ListTile(
            key: const Key('settings-vehicle'),
            leading: const Icon(Icons.moped),
            title: const Text('Profilo veicolo'),
            subtitle: Text(settings.vehicleProfile.label),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VehicleScreen(settings: settings))),
          ),
          SwitchListTile(
            key: const Key('settings-voice'),
            secondary: const Icon(Icons.record_voice_over),
            title: const Text('Indicazioni vocali'),
            subtitle: const Text('In italiano, durante la navigazione'),
            value: settings.voiceEnabled,
            onChanged: settings.setVoiceEnabled,
          ),
          const ListTile(
            leading: Icon(Icons.straighten),
            title: Text('Unità di misura'),
            subtitle: Text('Chilometri e metri'),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Tema'),
            subtitle: SegmentedButton<ThemeMode>(
              key: const Key('settings-theme'),
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                ButtonSegment(value: ThemeMode.light, label: Text('Chiaro')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Scuro')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          ListTile(
            key: const Key('settings-privacy'),
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy'),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
          ListTile(
            key: const Key('settings-attributions'),
            leading: const Icon(Icons.info_outline),
            title: const Text('Attribuzioni cartografiche'),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AttributionsScreen())),
          ),
        ]),
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Privacy')),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Text(
            'Nessun account, nessuna pubblicità, nessuna statistica di utilizzo.\n\n'
            'La posizione GPS è usata solo sul telefono, mentre l\'app è aperta, per '
            'mostrarti sulla mappa e guidarti. Non viene registrata né inviata a server.\n\n'
            'Quando calcoli un percorso, partenza e destinazione vengono inviate al '
            'server di routing configurato. Quando cerchi un indirizzo, il testo della '
            'ricerca viene inviato al servizio di geocoding.\n\n'
            'Preferenze, preferiti e cronologia restano sul dispositivo.',
          ),
        ),
      );
}

class AttributionsScreen extends StatelessWidget {
  const AttributionsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Attribuzioni')),
        body: ListView(padding: const EdgeInsets.all(16), children: const [
          Text(AppConfig.mapAttribution),
          SizedBox(height: 12),
          Text(
              'Dati cartografici © OpenStreetMap contributors, disponibili con '
              'licenza Open Database License (ODbL) 1.0 — openstreetmap.org/copyright.'),
          SizedBox(height: 12),
          Text(
              'Tile vettoriali: OpenFreeMap (openfreemap.org), schema OpenMapTiles.'),
          SizedBox(height: 12),
          Text(
              'Mappa: MapLibre (licenza BSD). Routing: Valhalla (licenza MIT).'),
        ]),
      );
}
