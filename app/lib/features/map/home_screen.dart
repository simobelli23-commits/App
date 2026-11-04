import 'package:flutter/material.dart';
import 'package:scooter_core/scooter_core.dart' as core;

import '../../app/app_config.dart';
import '../navigation/messages.dart';
import '../navigation/navigation_screen.dart';
import '../location/location_controller.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_screen.dart';
import '../vehicle/vehicle_screen.dart';
import 'map_view.dart';

class HomeScreen extends StatefulWidget {
  final SettingsController settings;
  final LocationController location;
  final MapViewFactory mapFactory;
  final core.RoutingProvider routing;
  final core.VoiceOutput? voice;

  const HomeScreen({
    super.key,
    required this.settings,
    required this.location,
    required this.mapFactory,
    required this.routing,
    this.voice,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MapViewHandle? _map;
  bool _follow = true;
  bool _centeredOnce = false;

  core.LatLng? _destination;
  List<core.RouteResult>? _routes;
  int _selected = 0;
  bool _calculating = false;
  String? _routeError;
  int _requestId = 0;

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
      map.centerOn(fix.position,
          zoom: _centeredOnce ? null : AppConfig.followZoom);
      _centeredOnce = true;
    }
  }

  Future<void> _setDestination(core.LatLng dest) async {
    final id = ++_requestId;
    setState(() {
      _destination = dest;
      _routes = null;
      _selected = 0;
      _routeError = null;
      _calculating = true;
      _follow = false;
    });
    _map?.showDestination(dest);
    _map?.clearRoutes();
    final fix = _loc.lastFix;
    if (fix == null) {
      setState(() {
        _calculating = false;
        _routeError =
            'Serve la posizione GPS attuale per calcolare il percorso.';
      });
      return;
    }
    final res = await widget.routing.route(core.RouteRequest(
      origin: fix.position,
      destination: dest,
      profile: widget.settings.vehicleProfile,
      headingDeg: fix.headingDeg,
    ));
    if (!mounted || id != _requestId) return; // richiesta superata
    switch (res) {
      case core.Ok(:final value):
        setState(() {
          _calculating = false;
          _routes = value;
        });
        _drawRoutes();
        _map?.fitPoints([fix.position, dest, ...value.first.shape]);
      case core.Err(:final error):
        setState(() {
          _calculating = false;
          _routeError = routingErrorMessage(error);
        });
    }
  }

  void _drawRoutes() {
    final r = _routes;
    if (r == null) return;
    final ordered = [
      r[_selected],
      for (var i = 0; i < r.length; i++)
        if (i != _selected) r[i]
    ];
    _map?.showRoutes([for (final x in ordered) x.shape]);
  }

  void _cancelRoute() {
    _requestId++;
    setState(() {
      _destination = null;
      _routes = null;
      _routeError = null;
      _calculating = false;
    });
    _map?.clearRoutes();
    _map?.showDestination(null);
  }

  Future<void> _startNavigation() async {
    final r = _routes;
    final dest = _destination;
    if (r == null || dest == null) return;
    await _map?.clearRoutes();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NavigationScreen(
        route: r[_selected],
        destination: dest,
        routing: widget.routing,
        voice: widget.voice,
        settings: widget.settings,
        location: _loc,
        mapFactory: widget.mapFactory,
      ),
    ));
    if (mounted) {
      _cancelRoute();
      setState(() => _follow = true);
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
                onLongPress: _setDestination,
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
                          subtitle:
                              Text('In arrivo. Ora: tieni premuto sulla mappa'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      key: const Key('open-settings'),
                      iconSize: 30,
                      tooltip: 'Impostazioni',
                      icon: const Icon(Icons.settings),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  SettingsScreen(settings: widget.settings))),
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
      floatingActionButton: _destination != null
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: FloatingActionButton.large(
                key: const Key('recenter'),
                tooltip: 'Centra sulla mia posizione',
                onPressed: _recenter,
                child: Icon(
                    _follow ? Icons.my_location : Icons.location_searching),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_destination != null) _routePanel(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(children: [
              ListenableBuilder(
                listenable: widget.settings,
                builder: (context, _) => ActionChip(
                  key: const Key('vehicle-chip'),
                  avatar: const Icon(Icons.moped),
                  label: Text(widget.settings.vehicleProfile.label),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          VehicleScreen(settings: widget.settings))),
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
        ]),
      ),
    );
  }

  Widget _routePanel(BuildContext context) {
    final theme = Theme.of(context);
    final routes = _routes;
    Widget body;
    if (_calculating) {
      body = const Row(key: Key('route-calculating'), children: [
        SizedBox(width: 28, height: 28, child: CircularProgressIndicator()),
        SizedBox(width: 16),
        Expanded(child: Text('Calcolo del percorso…')),
      ]);
    } else if (_routeError != null) {
      body = Row(key: const Key('route-error'), children: [
        const Icon(Icons.block),
        const SizedBox(width: 12),
        Expanded(child: Text(_routeError!)),
      ]);
    } else if (routes != null) {
      final r = routes[_selected];
      final secs = r.modelTimeS ?? r.engineTimeS;
      body = Column(
        key: const Key('route-preview'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${core.FormatIt.distance(r.lengthM)} · ${core.FormatIt.duration(secs)} (stima)',
              key: const Key('route-summary'),
              style: theme.textTheme.headlineSmall),
          Text(widget.settings.vehicleProfile.label,
              style: theme.textTheme.bodyMedium),
          for (final w in r.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(w, style: theme.textTheme.bodySmall)),
              ]),
            ),
          if (routes.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, children: [
                for (var i = 0; i < routes.length; i++)
                  ChoiceChip(
                    key: Key('route-option-$i'),
                    label: Text(i == 0
                        ? 'Principale'
                        : 'Alternativa · ${core.FormatIt.distance(routes[i].lengthM)}'),
                    selected: i == _selected,
                    onSelected: (_) {
                      setState(() => _selected = i);
                      _drawRoutes();
                    },
                  ),
              ]),
            ),
        ],
      );
    } else {
      body = const SizedBox.shrink();
    }
    return Material(
      elevation: 6,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          body,
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('route-cancel'),
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(64, 56)),
                onPressed: _cancelRoute,
                child: const Text('Annulla'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _routeError != null
                  ? FilledButton(
                      key: const Key('route-retry'),
                      onPressed: () => _setDestination(_destination!),
                      child: const Text('Riprova'),
                    )
                  : FilledButton.icon(
                      key: const Key('route-start'),
                      onPressed: routes == null ? null : _startNavigation,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Avvia'),
                    ),
            ),
          ]),
        ]),
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
    final (String? text, String? action, VoidCallback? onAction) =
        switch (controller.status) {
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
      LocationStatus.signalLost => (
          'Segnale GPS perso. Ultima posizione mostrata.',
          null,
          null
        ),
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
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action)),
        ]),
      ),
    );
  }
}
