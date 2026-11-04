import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scooter_core/scooter_core.dart';

import '../../app/app_config.dart';
import '../location/location_controller.dart';
import '../map/map_view.dart';
import '../settings/settings_controller.dart';
import 'maneuver_icon.dart';
import 'messages.dart';

/// Guida turn-by-turn. Pochi elementi, testi grandi: nessuna interazione
/// necessaria durante la marcia (le indicazioni sono anche vocali).
class NavigationScreen extends StatefulWidget {
  final RouteResult route;
  final LatLng destination;
  final RoutingProvider routing;
  final VoiceOutput? voice;
  final SettingsController settings;
  final LocationController location;
  final MapViewFactory mapFactory;
  final DateTime Function() clock;

  /// Mantiene lo schermo acceso durante la guida (wakelock nell'app).
  final Future<void> Function(bool on)? keepScreenOn;

  const NavigationScreen({
    super.key,
    required this.route,
    required this.destination,
    required this.routing,
    required this.voice,
    required this.settings,
    required this.location,
    required this.mapFactory,
    this.clock = DateTime.now,
    this.keepScreenOn,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late final NavigationEngine _engine;
  StreamSubscription<void>? _sub;
  Timer? _ticker;
  MapViewHandle? _map;
  RouteResult? _drawn;
  LocationFix? _lastFed;

  @override
  void initState() {
    super.initState();
    _engine = NavigationEngine(
      routing: widget.routing,
      profile: widget.settings.vehicleProfile,
      destination: widget.destination,
      voice: widget.voice,
      voiceEnabled: widget.settings.voiceEnabled,
    );
    _sub = _engine.changes.listen((_) {
      if (!mounted) return;
      _syncMap();
      setState(() {});
    });
    _engine.startWithRoute(widget.route);
    widget.keepScreenOn?.call(true).catchError((Object _) {});
    widget.location.addListener(_onLocation);
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => _engine.onTick(widget.clock()));
    _onLocation();
  }

  @override
  void dispose() {
    widget.location.removeListener(_onLocation);
    widget.keepScreenOn?.call(false).catchError((Object _) {});
    _ticker?.cancel();
    _sub?.cancel();
    _engine.dispose();
    super.dispose();
  }

  void _onLocation() {
    final fix = widget.location.lastFix;
    if (fix == null || identical(fix, _lastFed)) return;
    _lastFed = fix;
    _engine.onFix(fix);
    _map?.showUserPosition(fix.position, fix.accuracyM);
    if (_engine.status != EngineStatus.arrived) {
      _map?.centerOn(fix.position, zoom: AppConfig.followZoom);
    }
  }

  void _syncMap() {
    final r = _engine.route;
    if (_map == null || r == null || identical(r, _drawn)) return;
    _drawn = r;
    _map!.showRoutes([r.shape]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snap = _engine.snapshot;
    final next = _engine.nextManeuver;
    final arrived = _engine.status == EngineStatus.arrived;
    final remainingS = snap?.remainingS ??
        (widget.route.modelTimeS ?? widget.route.engineTimeS);
    final remainingM = snap?.remainingM ?? widget.route.lengthM;
    final eta = widget.clock().add(Duration(seconds: remainingS.round()));

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: widget.mapFactory.build(
            styleUrl: AppConfig.mapStyleUrl,
            initialCenter: widget.route.shape.first,
            initialZoom: AppConfig.followZoom,
            onReady: (h) {
              _map = h;
              h.showDestination(widget.destination);
              _syncMap();
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (arrived)
                _BigCard(
                  key: const Key('nav-arrived'),
                  icon: Icons.flag,
                  title: 'Sei arrivato',
                  subtitle: 'Destinazione raggiunta',
                )
              else if (next != null)
                _BigCard(
                  key: const Key('nav-maneuver'),
                  icon: maneuverIcon(next.type),
                  title: snap == null
                      ? '—'
                      : FormatIt.distance(snap.distanceToManeuverM),
                  subtitle: next.instruction,
                ),
              const SizedBox(height: 8),
              ..._banners(),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(arrived ? 'Arrivato' : 'Arrivo ${FormatIt.clock(eta)}',
                      key: const Key('nav-eta'),
                      style: theme.textTheme.headlineSmall),
                  Text(
                    arrived
                        ? ''
                        : '${FormatIt.distance(remainingM)} · ${FormatIt.duration(remainingS)} (stima)',
                    key: const Key('nav-remaining'),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              key: const Key('nav-stop'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: Text(arrived ? 'Chiudi' : 'Termina'),
            ),
          ]),
        ),
      ),
    );
  }

  List<Widget> _banners() {
    final out = <Widget>[];
    void add(String key, IconData icon, String text) => out.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            key: Key('nav-banner-$key'),
            elevation: 3,
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
              ]),
            ),
          ),
        ));

    if (_engine.status == EngineStatus.rerouting) {
      add('rerouting', Icons.sync, 'Ricalcolo del percorso…');
    }
    switch (_engine.notice) {
      case EngineNotice.gpsLost:
        add('gps', Icons.gps_off, 'Segnale GPS perso. Indicazioni sospese.');
      case EngineNotice.rerouteNoConnection:
        add('offline', Icons.cloud_off,
            'Connessione assente: mantengo il percorso precedente. Riprovo a breve.');
      case EngineNotice.rerouteNoRoute:
        add('noroute', Icons.block,
            'Nessun percorso consentito dalla posizione attuale. Torna sul percorso indicato.');
      case EngineNotice.rerouteServerError:
        add(
            'server',
            Icons.error_outline,
            _engine.error == null
                ? 'Errore del server.'
                : routingErrorMessage(_engine.error!));
      case EngineNotice.none:
        break;
    }
    if (widget.route.warnings.any((w) => w.contains('non è garantita'))) {
      add('uncertain', Icons.warning_amber,
          'Alcuni tratti hanno dati incompleti: rispetta la segnaletica.');
    }
    return out;
  }
}

class _BigCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _BigCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(icon, size: 64, color: scheme.onPrimary),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: text.displaySmall?.copyWith(
                      color: scheme.onPrimary, fontWeight: FontWeight.bold)),
              Text(subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge?.copyWith(color: scheme.onPrimary)),
            ]),
          ),
        ]),
      ),
    );
  }
}
