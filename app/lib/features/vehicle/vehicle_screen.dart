import 'package:flutter/material.dart';
import 'package:scooter_core/scooter_core.dart';

import '../settings/settings_controller.dart';

class VehicleScreen extends StatelessWidget {
  final SettingsController settings;
  const VehicleScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilo veicolo')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final current = settings.vehicleProfile;
          return RadioGroup<String>(
            groupValue: current.id,
            onChanged: (id) {
              final p = VehicleProfiles.byId(id ?? '');
              if (p != null && SettingsController.isSelectable(p)) {
                settings.setVehicleProfile(p);
              }
            },
            child: ListView(children: [
              for (final p in VehicleProfiles.all)
                RadioListTile<String>(
                  key: Key('profile-${p.id}'),
                  value: p.id,
                  enabled: SettingsController.isSelectable(p),
                  title: Text(p.label),
                  subtitle: Text(SettingsController.isSelectable(p)
                      ? 'Velocità massima di progetto ${p.maxDesignSpeedKmh.round()} km/h'
                      : 'Non ancora disponibile: regole e test in sviluppo'),
                ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'I percorsi escludono le strade vietate al veicolo secondo i dati '
                    'OpenStreetMap disponibili. I dati possono essere incompleti: '
                    'rispetta sempre la segnaletica.'),
              ),
            ]),
          );
        },
      ),
    );
  }
}
