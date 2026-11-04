import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../location/location_controller.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_screen.dart';
import '../vehicle/vehicle_screen.dart';
import 'map_view.dart';

class HomeScreen extends StatefulWidget {
  final SettingsController settings;
  final LocationController location;
  final MapViewFactory mapFactory;

  const HomeScreen({
    super.key,
    required this.settings,
    required this.location,
    required this.mapFactory,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MapViewHandle? _map;
  bool _follow = true;
  bool _centeredOnce = false;

  LocationController get _loc => widget.location;

  @override
  void initState() {
    super.initState();
    _loc.addListener(_onLocation);
    _loc.start();
  }

  @override
  void dispose() {
    _loc.removeListener(_onLocation);
    _loc.stop();
    super.dispose();
  }

  void _onLocation() {
    final fix = _loc.lastFix;
    final map = _map;
    if (fix == null || map == null) return;
    map.showUserPosition(fix.position, fix.accuracyM);
    if (_follow || !_centeredOnce) {
      map.centerOn(fix.position, zoom: _centeredOnce ? null : AppConfig.followZoom);
      _centeredOnce = true;
    }
  }

  void _recenter() {
    final fix = _loc.lastFix;
    if (fix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Posizione non ancora disponibile')));
      if (_loc.status != LocationStatus.tracking &&
          _loc.status != LocationStatus.waitingFix) {
        _loc.start();
      }
      return;
    }
    setState(() => _follow = true);
    _map?.centerOn(fix.position, zoom: AppConfig.followZoom);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              // Un gesto dell'utente sulla mappa sospende l'inseguimento.
              onPointerMove: (_) {
                if (_follow) setState(() => _follow = false);
              },
              child: widget.mapFactory.build(
                styleUrl: AppConfig.mapStyleUrl,
                initialCenter: AppConfig.initialCenter,
                initialZoom: AppConfig.initialZoom,
                onReady: (h) {
                  _map = h;
                  _onLocation();
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(28),
                        color: scheme.surfaceContainerHigh,
                        child: const ListTile(
                          key: Key('search-placeholder'),
                          enabled: false,
                          leading: Icon(Icons.search),
                          title: Text('Cerca destinazione'),
                          subtitle: Text('Disponibile nella prossima versione'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      key: const Key('open-settings'),
                      iconSize: 30,
                      tooltip: 'Impostazioni',
                      icon: const Icon(Icons.settings),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SettingsScreen(settings: widget.settings))),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ListenableBuilder(
                    listenable: _loc,
                    builder: (context, _) => _LocationBanner(controller: _loc),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: FloatingActionButton.large(
          key: const Key('recenter'),
          tooltip: 'Centra sulla mia posizione',
          onPressed: _recenter,
          child: Icon(_follow ? Icons.my_location : Icons.location_searching),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            ListenableBuilder(
              listenable: widget.settings,
              builder: (context, _) => ActionChip(
                key: const Key('vehicle-chip'),
                avatar: const Icon(Icons.moped),
                label: Text(widget.settings.vehicleProfile.label),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VehicleScreen(settings: widget.settings))),
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(AppConfig.mapAttribution,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LocationBanner extends StatelessWidget {
  final LocationController controller;
  const _LocationBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = controller.provider;
    final (String? text, String? action, VoidCallback? onAction) = switch (controller.status) {
      LocationStatus.serviceDisabled => (
          'GPS disattivato. Attiva la localizzazione per vedere la tua posizione.',
          'Apri impostazioni',
          () async {
            await p.openLocationSettings();
            await controller.start();
          }
        ),
      LocationStatus.permissionDenied => (
          'Permesso di posizione negato.',
          'Concedi permesso',
          controller.start
        ),
      LocationStatus.permissionDeniedForever => (
          'Permesso di posizione negato. Abilitalo dalle impostazioni dell\'app.',
          'Impostazioni app',
          () async {
            await p.openAppSettings();
            await controller.start();
          }
        ),
      LocationStatus.waitingFix => ('Ricerca del segnale GPS…', null, null),
      LocationStatus.signalLost => ('Segnale GPS perso. Ultima posizione mostrata.', null, null),
      LocationStatus.unavailable => (
          'Posizione non disponibile.',
          'Riprova',
          controller.start
        ),
      _ => (null, null, null),
    };
    if (text == null) return const SizedBox.shrink();
    return Material(
      key: Key('location-banner-${controller.status.name}'),
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.gps_off),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action)),
        ]),
      ),
    );
  }
}
