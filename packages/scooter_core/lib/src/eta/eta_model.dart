import 'dart:math' as math;

import '../vehicle/vehicle_profile.dart';

/// Segmento per il calcolo ETA.
class EtaSegment {
  final double lengthM;

  /// Classe stradale (valori Valhalla: motorway, trunk, primary, secondary,
  /// tertiary, unclassified, residential, service_other).
  final String roadClass;

  /// Uso (road, living_street, service_road, ramp, track, ...).
  final String use;

  /// Limite legale noto (km/h), `null` se assente nei dati.
  final double? speedLimitKmh;

  /// Il segmento è in centro abitato.
  final bool urban;

  const EtaSegment({
    required this.lengthM,
    required this.roadClass,
    this.use = 'road',
    this.speedLimitKmh,
    this.urban = true,
  });
}

/// Tipi di manovra rilevanti per le penalità.
enum ManeuverKind { straight, slightTurn, turn, sharpTurn, uTurn, roundabout, merge, other }

class EtaBreakdown {
  final double drivingSeconds;
  final double maneuverSeconds;
  final double urbanSeconds;

  const EtaBreakdown(this.drivingSeconds, this.maneuverSeconds, this.urbanSeconds);

  double get totalSeconds => drivingSeconds + maneuverSeconds + urbanSeconds;
}

/// Modello ETA deterministico (MVP). Documentato in ROUTING_RULES.md §ETA.
///
/// velocità_segmento = min(
///     velocità_massima_veicolo * fattore_crociera,
///     limite_legale (o default per classe/ambito),
///     velocità_tipica_classe)
/// + penalità per manovra + penalità urbana per km.
class EtaModel {
  /// Quota della velocità massima di progetto realisticamente sostenuta.
  final double cruiseFactor;

  /// Secondi aggiuntivi per km in centro abitato (semafori, precedenze).
  final double urbanPenaltySecPerKm;

  final Map<ManeuverKind, double> maneuverPenaltySec;

  const EtaModel({
    this.cruiseFactor = 0.9,
    this.urbanPenaltySecPerKm = 20,
    this.maneuverPenaltySec = const {
      ManeuverKind.straight: 0,
      ManeuverKind.slightTurn: 2,
      ManeuverKind.turn: 6,
      ManeuverKind.sharpTurn: 8,
      ManeuverKind.uTurn: 15,
      ManeuverKind.roundabout: 8,
      ManeuverKind.merge: 4,
      ManeuverKind.other: 3,
    },
  });

  /// Velocità tipica (km/h) per classe, prima dei limiti di veicolo/legge.
  static double typicalSpeedKmh(String roadClass, String use, bool urban) {
    if (use == 'living_street') return 10;
    if (use == 'track') return 15;
    if (use == 'service_road' || use == 'parking_aisle' || use == 'driveway') return 15;
    switch (roadClass) {
      case 'motorway':
      case 'trunk':
        return urban ? 60 : 90;
      case 'primary':
        return urban ? 40 : 70;
      case 'secondary':
        return urban ? 35 : 65;
      case 'tertiary':
        return urban ? 30 : 55;
      case 'unclassified':
        return urban ? 28 : 45;
      case 'residential':
        return 25;
      default:
        return 15;
    }
  }

  /// Limite legale di default in assenza di `maxspeed` (art. 142 CdS:
  /// 50 km/h nei centri abitati, 90 km/h extraurbane secondarie/locali).
  static double defaultLegalLimitKmh(String roadClass, bool urban) {
    if (urban) return 50;
    switch (roadClass) {
      case 'motorway':
        return 130;
      case 'trunk':
        return 110;
      default:
        return 90;
    }
  }

  double segmentSpeedKmh(EtaSegment s, VehicleProfile v) {
    final vehicle = v.maxDesignSpeedKmh * cruiseFactor;
    final legal = s.speedLimitKmh ?? defaultLegalLimitKmh(s.roadClass, s.urban);
    final typical = typicalSpeedKmh(s.roadClass, s.use, s.urban);
    return math.max(1.0, [vehicle, legal, typical].reduce(math.min));
  }

  EtaBreakdown estimate(
    List<EtaSegment> segments,
    List<ManeuverKind> maneuvers,
    VehicleProfile v,
  ) {
    var driving = 0.0, urban = 0.0;
    for (final s in segments) {
      if (s.lengthM <= 0) continue;
      driving += s.lengthM / (segmentSpeedKmh(s, v) / 3.6);
      if (s.urban) urban += s.lengthM / 1000.0 * urbanPenaltySecPerKm;
    }
    var man = 0.0;
    for (final m in maneuvers) {
      man += maneuverPenaltySec[m] ?? 0;
    }
    return EtaBreakdown(driving, man, urban);
  }

  /// ETA residuo durante la navigazione: tempo totale scalato sulla
  /// distanza residua (MVP; sufficiente finché i segmenti hanno velocità
  /// simili). [totalSeconds] e [totalM] riferiti al percorso intero.
  static double remainingSeconds({
    required double totalSeconds,
    required double totalM,
    required double remainingM,
  }) {
    if (totalM <= 0) return 0;
    final ratio = (remainingM / totalM).clamp(0.0, 1.0);
    return totalSeconds * ratio;
  }
}
