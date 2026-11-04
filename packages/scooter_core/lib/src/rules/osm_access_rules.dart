import '../vehicle/vehicle_profile.dart';
import 'legal_refs.dart';

/// Esito della valutazione di percorribilità.
enum Legality {
  /// Percorribile secondo i dati disponibili.
  allowed,

  /// Percorribile solo come origine/destinazione (private, destination...).
  destinationOnly,

  /// Vietato con certezza secondo norma o tag espliciti: vincolo rigido.
  forbidden,

  /// Dati incerti/incompleti: non si può garantire la legalità.
  uncertain,
}

class Verdict {
  final Legality legality;
  final List<String> reasons;
  final LegalRef? legalRef;

  const Verdict(this.legality, this.reasons, [this.legalRef]);

  bool get isHardBlock => legality == Legality.forbidden;

  @override
  String toString() => 'Verdict(${legality.name}: ${reasons.join('; ')})';
}

/// Direzioni percorribili rispetto al verso di digitalizzazione della way.
class DirectionAccess {
  final bool forward;
  final bool backward;
  final bool uncertain;

  const DirectionAccess(this.forward, this.backward, {this.uncertain = false});
}

class WayEvaluation {
  final Verdict access;
  final DirectionAccess direction;

  const WayEvaluation(this.access, this.direction);
}

/// Modalità di gestione delle `highway=trunk` senza `motorroad=yes`.
/// In Italia `trunk` è usato spesso (non sempre) per le extraurbane
/// principali (tipo B). In modalità [strict] vengono escluse.
enum TrunkPolicy { strict, permissive }

/// Valutatore di regole sui tag OpenStreetMap per un profilo veicolo.
///
/// Implementato e destinato alla validazione: profilo ciclomotore (A).
/// Per gli altri profili restituisce [Legality.uncertain] su ogni regola
/// dipendente dalla categoria, finché non saranno implementati e testati.
class OsmAccessRules {
  final VehicleProfile profile;
  final TrunkPolicy trunkPolicy;

  const OsmAccessRules(this.profile, {this.trunkPolicy = TrunkPolicy.strict});

  static const _nonRoad = {
    'construction', 'proposed', 'abandoned', 'razed', 'platform',
    'raceway', 'bus_guideway', 'escape', 'busway', 'via_ferrata',
  };

  static const _nonMotor = {
    'footway', 'pedestrian', 'cycleway', 'path', 'steps', 'bridleway',
    'corridor', 'elevator', 'sidewalk', 'crossing',
  };

  static const _roads = {
    'motorway', 'motorway_link', 'trunk', 'trunk_link', 'primary',
    'primary_link', 'secondary', 'secondary_link', 'tertiary',
    'tertiary_link', 'unclassified', 'residential', 'living_street',
    'service', 'road', 'track',
  };

  /// Chiavi di accesso dalla più specifica alla più generale (ciclomotore).
  static const mopedAccessHierarchy = ['moped', 'motor_vehicle', 'vehicle', 'access'];

  WayEvaluation evaluateWay(Map<String, String> tags) {
    final access = evaluateAccess(tags);
    return WayEvaluation(access, evaluateDirection(tags));
  }

  Verdict evaluateAccess(Map<String, String> tags) {
    final hw = tags['highway'];
    if (hw == null) {
      return const Verdict(Legality.forbidden, ['Non è una strada (manca highway)']);
    }
    if (_nonRoad.contains(hw)) {
      return Verdict(Legality.forbidden, ['highway=$hw non percorribile']);
    }
    if (!profile.isMoped) {
      return const Verdict(Legality.uncertain,
          ['Regole per questo profilo non ancora implementate/validate']);
    }

    // 1) Divieti di legge per classe di strada (art. 175 c.2): prevalgono
    //    su qualunque tag di accesso (un moped=yes in autostrada è un errore).
    if (hw == 'motorway' || hw == 'motorway_link') {
      return const Verdict(Legality.forbidden,
          ['Autostrada: vietata ai ciclomotori'], LegalRefs.art175c2);
    }
    if (tags['motorroad'] == 'yes') {
      return const Verdict(Legality.forbidden,
          ['motorroad=yes (extraurbana principale): vietata ai ciclomotori'],
          LegalRefs.art175c2);
    }

    // 2) Tag esplicito per ciclomotori (il più specifico).
    final mopedTag = tags['moped'];
    if (mopedTag != null) {
      final v = _accessValue(mopedTag, 'moped');
      if (v != null) return _applyTrunk(hw, _withConditional(tags, v));
    }

    // 3) Percorsi non motorizzati: vietati salvo autorizzazione esplicita.
    if (_nonMotor.contains(hw)) {
      final mv = tags['motor_vehicle'];
      if (mv == 'yes' || mv == 'designated' || mv == 'permissive') {
        return _withConditional(tags,
            Verdict(Legality.allowed, ['highway=$hw con motor_vehicle=$mv']));
      }
      return Verdict(Legality.forbidden,
          ['highway=$hw: percorso pedonale/ciclabile non autorizzato ai ciclomotori'],
          LegalRefs.signage);
    }

    if (!_roads.contains(hw)) {
      return Verdict(Legality.uncertain, ['highway=$hw non classificato dalle regole']);
    }

    // 4) Gerarchia generica motor_vehicle > vehicle > access.
    for (final key in mopedAccessHierarchy.skip(1)) {
      final raw = tags[key];
      if (raw == null) continue;
      final v = _accessValue(raw, key);
      if (v != null) return _applyTrunk(hw, _withConditional(tags, v));
    }

    // 5) Nessun tag di accesso: default per classe.
    if (hw == 'track') {
      return _withConditional(tags, const Verdict(Legality.uncertain,
          ['highway=track senza tag di accesso: percorribilità non garantita']));
    }
    return _applyTrunk(
        hw, _withConditional(tags, Verdict(Legality.allowed, ['highway=$hw'])));
  }

  Verdict _applyTrunk(String hw, Verdict v) {
    if ((hw == 'trunk' || hw == 'trunk_link') && v.legality != Legality.forbidden) {
      if (trunkPolicy == TrunkPolicy.strict) {
        return const Verdict(Legality.forbidden, [
          'highway=trunk senza motorroad: possibile extraurbana principale, '
              'esclusa in modalità prudente'
        ], LegalRefs.art175c2);
      }
      return const Verdict(Legality.uncertain,
          ['highway=trunk senza motorroad: possibile extraurbana principale'],
          LegalRefs.art175c2);
    }
    return v;
  }

  Verdict? _accessValue(String raw, String key) {
    // Valori multipli "a;b": si usa il più restrittivo.
    final values = raw.split(';').map((s) => s.trim()).toList();
    Verdict? worst;
    for (final value in values) {
      final v = _single(value, key);
      if (worst == null || _rank(v.legality) > _rank(worst.legality)) worst = v;
    }
    return worst;
  }

  Verdict _single(String value, String key) {
    switch (value) {
      case 'yes':
      case 'designated':
      case 'permissive':
        return Verdict(Legality.allowed, ['$key=$value']);
      case 'no':
      case 'agricultural':
      case 'forestry':
      case 'use_sidepath':
      case 'discouraged':
        if (value == 'discouraged') {
          return Verdict(Legality.uncertain, ['$key=discouraged']);
        }
        return Verdict(Legality.forbidden, ['$key=$value'], LegalRefs.signage);
      case 'private':
      case 'destination':
      case 'delivery':
      case 'customers':
        return Verdict(Legality.destinationOnly, ['$key=$value'], LegalRefs.signage);
      default:
        return Verdict(Legality.uncertain, ['$key=$value: valore non riconosciuto']);
    }
  }

  static int _rank(Legality l) => switch (l) {
        Legality.allowed => 0,
        Legality.destinationOnly => 1,
        Legality.uncertain => 2,
        Legality.forbidden => 3,
      };

  Verdict _withConditional(Map<String, String> tags, Verdict v) {
    if (v.legality == Legality.forbidden) return v;
    for (final key in mopedAccessHierarchy) {
      if (tags.containsKey('$key:conditional')) {
        return Verdict(Legality.uncertain, [
          ...v.reasons,
          '$key:conditional presente (restrizione oraria/ZTL non interpretata)'
        ], LegalRefs.art7Ztl);
      }
    }
    return v;
  }

  DirectionAccess evaluateDirection(Map<String, String> tags) {
    // oneway:bicycle NON si applica ai ciclomotori.
    final specific = tags['oneway:moped'];
    final general = tags['oneway'];
    final value = specific ?? general;
    final impliedOneway = tags['junction'] == 'roundabout' ||
        tags['junction'] == 'circular' ||
        tags['highway'] == 'motorway';
    switch (value) {
      case 'yes':
      case 'true':
      case '1':
        return const DirectionAccess(true, false);
      case '-1':
      case 'reverse':
        return const DirectionAccess(false, true);
      case 'no':
      case 'false':
      case '0':
        return const DirectionAccess(true, true);
      case 'alternating':
      case 'reversible':
        return const DirectionAccess(true, true, uncertain: true);
      case null:
        return impliedOneway
            ? const DirectionAccess(true, false)
            : const DirectionAccess(true, true);
      default:
        return const DirectionAccess(true, true, uncertain: true);
    }
  }
}
