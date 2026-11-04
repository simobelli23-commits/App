import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:scooter_core/scooter_core.dart';

import 'app_location_provider.dart';

enum LocationStatus {
  idle,
  starting,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  waitingFix,
  tracking,
  signalLost,
  unavailable,
}

/// Stato della posizione per la UI. Gestisce errori di permesso/servizio e
/// la perdita del segnale (nessun fix da più di [signalLostAfter]).
class LocationController extends ChangeNotifier {
  final AppLocationProvider provider;
  final Duration signalLostAfter;
  final DateTime Function() clock;

  LocationStatus _status = LocationStatus.idle;
  LocationFix? _lastFix;
  DateTime? _lastFixAt;
  String? _errorMessage;
  StreamSubscription<LocationFix>? _sub;
  Timer? _watchdog;

  LocationController(
    this.provider, {
    this.signalLostAfter = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  LocationStatus get status => _status;
  LocationFix? get lastFix => _lastFix;
  String? get errorMessage => _errorMessage;

  Future<void> start() async {
    // Cancellazione senza attesa: un nuovo tentativo non deve bloccarsi.
    _sub?.cancel();
    _sub = null;
    _set(LocationStatus.starting);
    final ready = await provider.ensureReady();
    if (ready is Err<void, LocationError>) {
      _errorMessage = ready.error.message;
      _set(switch (ready.error.kind) {
        LocationErrorKind.serviceDisabled => LocationStatus.serviceDisabled,
        LocationErrorKind.permissionDenied => LocationStatus.permissionDenied,
        LocationErrorKind.permissionDeniedForever =>
          LocationStatus.permissionDeniedForever,
        LocationErrorKind.unavailable => LocationStatus.unavailable,
      });
      return;
    }
    _errorMessage = null;
    _set(LocationStatus.waitingFix);
    _sub = provider.fixes().listen(_onFix, onError: (Object e) {
      _errorMessage = e.toString();
      _watchdog?.cancel();
      _sub?.cancel();
      _sub = null;
      _set(LocationStatus.unavailable);
    });
    _watchdog?.cancel();
    _watchdog =
        Timer.periodic(const Duration(seconds: 1), (_) => checkSignal());
  }

  void _onFix(LocationFix fix) {
    _lastFix = fix;
    _lastFixAt = clock();
    _set(LocationStatus.tracking);
  }

  /// Verifica la perdita del segnale (chiamata dal watchdog ogni secondo).
  void checkSignal() {
    final at = _lastFixAt;
    if (_status == LocationStatus.tracking &&
        at != null &&
        clock().difference(at) > signalLostAfter) {
      _set(LocationStatus.signalLost);
    }
  }

  void _set(LocationStatus s) {
    if (_status == s) {
      if (s == LocationStatus.tracking) notifyListeners(); // nuovo fix
      return;
    }
    _status = s;
    notifyListeners();
  }

  /// Ferma GPS e watchdog (app chiusa o schermata distrutta).
  Future<void> stop() async {
    _watchdog?.cancel();
    _watchdog = null;
    await _sub?.cancel();
    _sub = null;
    _set(LocationStatus.idle);
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
