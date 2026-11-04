/// Categorie giuridiche (Codice della Strada, art. 52-53).
enum VehicleCategory {
  /// Ciclomotore: art. 52 CdS (<= 50 cc termico o <= 4 kW elettrico,
  /// velocità massima di costruzione <= 45 km/h). Categoria UE L1e.
  ciclomotore,

  /// Motociclo: art. 53 CdS. Categoria UE L3e.
  motociclo,
}

enum Propulsion { termico, elettrico }

/// Stato di validazione di un profilo. Solo i profili [validated]
/// possono essere selezionati come "pronti" nell'interfaccia.
enum ProfileStatus { validated, experimental }

/// Profilo veicolo + conducente usato dal motore di regole e dal routing.
class VehicleProfile {
  final String id;
  final String label;
  final VehicleCategory category;
  final Propulsion propulsion;

  /// Cilindrata in cc (solo termico).
  final int? displacementCc;

  /// Potenza nominale continua in kW (solo elettrico).
  final double? powerKw;

  /// Velocità massima di costruzione (km/h). Limite superiore di
  /// riferimento, NON velocità media.
  final double maxDesignSpeedKmh;

  /// Il conducente è maggiorenne (rilevante per art. 175 dopo L. 177/2024,
  /// da verificare: vedi ROUTING_RULES.md).
  final bool driverIsAdult;

  final ProfileStatus status;

  const VehicleProfile({
    required this.id,
    required this.label,
    required this.category,
    required this.propulsion,
    this.displacementCc,
    this.powerKw,
    required this.maxDesignSpeedKmh,
    required this.driverIsAdult,
    required this.status,
  });

  bool get isMoped => category == VehicleCategory.ciclomotore;
}

/// Profili predefiniti. Solo il profilo A è destinato alla validazione
/// completa nella prima versione.
class VehicleProfiles {
  static const a50cc = VehicleProfile(
    id: 'A_ciclomotore_50',
    label: 'Ciclomotore 50 cc (45 km/h)',
    category: VehicleCategory.ciclomotore,
    propulsion: Propulsion.termico,
    displacementCc: 50,
    maxDesignSpeedKmh: 45,
    driverIsAdult: false, // irrilevante per il ciclomotore: regole identiche
    status: ProfileStatus.experimental, // diventa validated dopo i test M2
  );

  static const b125Adult = VehicleProfile(
    id: 'B_scooter_125_maggiorenne',
    label: 'Scooter 125 cc, conducente maggiorenne',
    category: VehicleCategory.motociclo,
    propulsion: Propulsion.termico,
    displacementCc: 125,
    maxDesignSpeedKmh: 110,
    driverIsAdult: true,
    status: ProfileStatus.experimental,
  );

  static const c125Minor = VehicleProfile(
    id: 'C_scooter_125_minorenne',
    label: 'Scooter 125 cc, conducente minorenne',
    category: VehicleCategory.motociclo,
    propulsion: Propulsion.termico,
    displacementCc: 125,
    maxDesignSpeedKmh: 110,
    driverIsAdult: false,
    status: ProfileStatus.experimental,
  );

  static const dOver125 = VehicleProfile(
    id: 'D_moto_oltre_125',
    label: 'Motociclo oltre 125 cc',
    category: VehicleCategory.motociclo,
    propulsion: Propulsion.termico,
    displacementCc: 300,
    maxDesignSpeedKmh: 140,
    driverIsAdult: true,
    status: ProfileStatus.experimental,
  );

  static VehicleProfile electric({
    required VehicleCategory category,
    required double powerKw,
    required double maxDesignSpeedKmh,
    required bool driverIsAdult,
  }) =>
      VehicleProfile(
        id: 'E_elettrico_${category.name}_${powerKw}kW',
        label: 'Elettrico ${category.name} ${powerKw} kW',
        category: category,
        propulsion: Propulsion.elettrico,
        powerKw: powerKw,
        maxDesignSpeedKmh: maxDesignSpeedKmh,
        driverIsAdult: driverIsAdult,
        status: ProfileStatus.experimental,
      );

  static const all = [a50cc, b125Adult, c125Minor, dOver125];

  static VehicleProfile? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
