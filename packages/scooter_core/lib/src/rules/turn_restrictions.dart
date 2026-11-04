import '../vehicle/vehicle_profile.dart';

/// Relazione OSM `type=restriction` semplificata (via = nodo).
class TurnRestriction {
  final int fromWay;
  final int viaNode;
  final int toWay;
  final Map<String, String> tags;

  const TurnRestriction({
    required this.fromWay,
    required this.viaNode,
    required this.toWay,
    required this.tags,
  });
}

enum TurnDecision { allowed, forbidden, uncertain }

/// Valuta le restrizioni di svolta per un profilo.
/// Regole: `restriction:moped` prevale su `restriction`; `except=*`
/// esenta il ciclomotore solo se elenca `moped` (non `bicycle`).
class TurnRestrictionEvaluator {
  final VehicleProfile profile;
  const TurnRestrictionEvaluator(this.profile);

  String? _effectiveType(TurnRestriction r) {
    final key = profile.isMoped ? 'restriction:moped' : 'restriction:motorcycle';
    final specific = r.tags[key];
    if (specific != null) return specific;
    final generic = r.tags['restriction'];
    if (generic == null) return null;
    final except = (r.tags['except'] ?? '').split(';').map((s) => s.trim());
    final exemptKey = profile.isMoped ? 'moped' : 'motorcycle';
    if (except.contains(exemptKey)) return null;
    return generic;
  }

  /// Decide se la manovra fromWay -> (viaNode) -> toWay è consentita.
  TurnDecision decide(
      int fromWay, int viaNode, int toWay, Iterable<TurnRestriction> all) {
    var decision = TurnDecision.allowed;
    for (final r in all) {
      if (r.fromWay != fromWay || r.viaNode != viaNode) continue;
      final hasConditional = r.tags.keys.any((k) => k.endsWith(':conditional'));
      final type = _effectiveType(r);
      if (type == null) {
        if (hasConditional) decision = TurnDecision.uncertain;
        continue;
      }
      if (type.startsWith('no_') && r.toWay == toWay) {
        return TurnDecision.forbidden;
      }
      if (type.startsWith('only_') && r.toWay != toWay) {
        return TurnDecision.forbidden;
      }
      if (hasConditional) decision = TurnDecision.uncertain;
    }
    return decision;
  }
}
