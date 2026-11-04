import '../vehicle/vehicle_profile.dart';
import 'legal_refs.dart';
import 'osm_access_rules.dart';

/// Attributi di un arco del percorso calcolato, come restituiti da
/// Valhalla `/trace_attributes` (edge.road_class, edge.use, edge.way_id).
class RouteEdge {
  final int? wayId;
  final String roadClass;
  final String use;
  final double lengthKm;
  final String? name;

  const RouteEdge({
    this.wayId,
    required this.roadClass,
    required this.use,
    required this.lengthKm,
    this.name,
  });
}

class ComplianceIssue {
  final RouteEdge edge;
  final Legality severity;
  final String reason;
  final LegalRef? ref;

  const ComplianceIssue(this.edge, this.severity, this.reason, [this.ref]);
}

enum ComplianceStatus {
  /// Nessuna violazione rilevata con i dati disponibili (MAI "garantito").
  noViolationsFound,

  /// Nessuna violazione certa, ma tratti con dati incerti.
  uncertain,

  /// Il percorso contiene tratti vietati: va scartato.
  violation,
}

class ComplianceReport {
  final ComplianceStatus status;
  final List<ComplianceIssue> issues;

  const ComplianceReport(this.status, this.issues);

  bool get mustReject => status == ComplianceStatus.violation;
}

/// Seconda linea di difesa: verifica indipendente del percorso restituito
/// dal motore. Se il motore (o la sua configurazione) lasciasse passare un
/// tratto vietato, il percorso viene rifiutato e non mostrato come valido.
class RouteComplianceValidator {
  final VehicleProfile profile;
  final TrunkPolicy trunkPolicy;

  const RouteComplianceValidator(this.profile,
      {this.trunkPolicy = TrunkPolicy.strict});

  static const _forbiddenUsesMoped = {
    'cycleway', 'footway', 'sidewalk', 'pedestrian', 'steps', 'path',
    'mountain_bike', 'bridleway', 'elevator', 'pedestrian_crossing',
    'escalator', 'platform', 'rail', 'bus', 'transit_connection',
  };

  ComplianceReport validate(List<RouteEdge> edges) {
    if (!profile.isMoped) {
      return const ComplianceReport(ComplianceStatus.uncertain, []);
    }
    final issues = <ComplianceIssue>[];
    for (final e in edges) {
      if (e.roadClass == 'motorway') {
        issues.add(ComplianceIssue(e, Legality.forbidden,
            'Tratto autostradale', LegalRefs.art175c2));
      } else if (e.roadClass == 'trunk') {
        issues.add(ComplianceIssue(
            e,
            trunkPolicy == TrunkPolicy.strict ? Legality.forbidden : Legality.uncertain,
            'Strada classificata trunk (possibile extraurbana principale)',
            LegalRefs.art175c2));
      }
      if (_forbiddenUsesMoped.contains(e.use)) {
        issues.add(ComplianceIssue(e, Legality.forbidden,
            'Uso "${e.use}" non consentito ai ciclomotori', LegalRefs.signage));
      } else if (e.use == 'track') {
        issues.add(ComplianceIssue(e, Legality.uncertain,
            'Strada sterrata/agricola: accesso non garantito'));
      }
    }
    final status = issues.any((i) => i.severity == Legality.forbidden)
        ? ComplianceStatus.violation
        : issues.isEmpty
            ? ComplianceStatus.noViolationsFound
            : ComplianceStatus.uncertain;
    return ComplianceReport(status, issues);
  }
}
