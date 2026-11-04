import '../providers/providers.dart';
import 'format_it.dart';
import 'navigation_session.dart';

enum _Stage { far, near, now }

/// Decide quando e cosa annunciare a voce. Ogni manovra ha al massimo tre
/// annunci (lontano, vicino, adesso), ciascuno pronunciato una sola volta.
/// Le soglie dipendono dalla velocità: a 45 km/h (12,5 m/s) "vicino" scatta
/// a ~125 m (10 s) e "adesso" a ~38 m (3 s).
class VoicePlanner {
  final double farMaxM;
  final double farMinM;
  final double nearSeconds;
  final double nearMinM;
  final double nowSeconds;
  final double nowMinM;

  final Map<int, Set<_Stage>> _done = {};
  bool _departureSaid = false;
  bool _arrivalSaid = false;

  VoicePlanner({
    this.farMaxM = 600,
    this.farMinM = 300,
    this.nearSeconds = 10,
    this.nearMinM = 100,
    this.nowSeconds = 3,
    this.nowMinM = 25,
  });

  static bool isArrival(Maneuver m) => m.type == 4 || m.type == 5 || m.type == 6;

  String _alert(Maneuver m) => (m.verbalAlert ?? m.instruction).trim();

  /// Annuncio iniziale (es. "Guida verso est su Via Emilia").
  String? departure(List<Maneuver> maneuvers) {
    if (_departureSaid || maneuvers.isEmpty) return null;
    _departureSaid = true;
    final m = maneuvers.first;
    return (m.verbalPre ?? m.instruction).trim();
  }

  /// Annunci da pronunciare per lo stato corrente (di solito 0 o 1).
  List<String> plan(NavigationSnapshot s, List<Maneuver> maneuvers, {double? speedMps}) {
    if (s.status == NavStatus.arrived) {
      if (_arrivalSaid) return const [];
      _arrivalSaid = true;
      return const ['Sei arrivato a destinazione.'];
    }
    if (s.status != NavStatus.onRoute) return const [];
    final i = s.maneuverIndex;
    if (i <= 0 || i >= maneuvers.length) return const [];
    final m = maneuvers[i];
    final d = s.distanceToManeuverM;
    final v = (speedMps ?? 0).clamp(0.0, 40.0);
    final nowAt = (v * nowSeconds).clamp(nowMinM, 80.0);
    final nearAt = (v * nearSeconds).clamp(nearMinM, 250.0);
    final done = _done.putIfAbsent(i, () => <_Stage>{});

    _Stage? stage;
    if (d <= nowAt) {
      stage = _Stage.now;
    } else if (d <= nearAt) {
      stage = _Stage.near;
    } else if (d <= farMaxM && d >= farMinM) {
      stage = _Stage.far;
    }
    if (stage == null || done.contains(stage)) return const [];
    // Una fase raggiunta rende superflue quelle precedenti.
    for (final st in _Stage.values) {
      done.add(st);
      if (st == stage) break;
    }
    if (isArrival(m)) {
      // L'arrivo viene annunciato dallo stato "arrived"; prima solo un preavviso.
      if (stage == _Stage.now) return const [];
      return ['Tra ${FormatIt.spokenDistance(d)}, arrivo a destinazione.'];
    }
    switch (stage) {
      case _Stage.now:
        return [(m.verbalPre ?? m.instruction).trim()];
      case _Stage.near:
      case _Stage.far:
        return ['Tra ${FormatIt.spokenDistance(d)}, ${_lowerFirst(_alert(m))}'];
    }
  }

  /// Da chiamare quando il percorso cambia (ricalcolo).
  void reset({bool keepDeparture = true}) {
    _done.clear();
    _arrivalSaid = false;
    if (!keepDeparture) _departureSaid = false;
  }

  static String _lowerFirst(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}
