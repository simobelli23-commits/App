/// Riferimenti normativi usati dalle regole. Ogni regola implementata
/// deve puntare a uno di questi riferimenti (vedi ROUTING_RULES.md).
class LegalRef {
  final String id;
  final String source;
  final String citation;
  final String summary;

  /// Data dell'ultima verifica sul testo ufficiale, `null` se NON ancora
  /// verificata su fonte ufficiale (Normattiva / Gazzetta Ufficiale).
  final String? verifiedOn;

  const LegalRef({
    required this.id,
    required this.source,
    required this.citation,
    required this.summary,
    this.verifiedOn,
  });

  bool get isVerified => verifiedOn != null;
}

class LegalRefs {
  static const normattivaCdS =
      'https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:decreto.legislativo:1992-04-30;285';

  static const art175c2 = LegalRef(
    id: 'CdS-175-2',
    source: normattivaCdS,
    citation: 'D.Lgs. 285/1992 (Codice della Strada), art. 175, comma 2',
    summary:
        'Divieto di circolazione su autostrade e strade extraurbane principali '
        'per, tra gli altri, velocipedi e ciclomotori.',
    verifiedOn: null,
  );

  static const art52 = LegalRef(
    id: 'CdS-52',
    source: normattivaCdS,
    citation: 'D.Lgs. 285/1992, art. 52 (definizione di ciclomotore)',
    summary: 'Ciclomotore: <= 50 cc termico (o <= 4 kW elettrico), '
        'velocità massima di costruzione <= 45 km/h.',
    verifiedOn: null,
  );

  static const art7Ztl = LegalRef(
    id: 'CdS-7',
    source: normattivaCdS,
    citation: 'D.Lgs. 285/1992, art. 7 (ZTL e regolamentazione urbana)',
    summary: 'ZTL istituite con ordinanza comunale: le regole variano per '
        'comune, orario e categoria; dati OSM non sempre completi.',
    verifiedOn: null,
  );

  static const signage = LegalRef(
    id: 'SEGNALETICA',
    source: 'Segnaletica stradale (D.P.R. 495/1992) tradotta nei tag OSM',
    citation: 'Divieti di accesso, sensi unici, obblighi/divieti di svolta',
    summary: 'Restrizioni locali derivate dai dati OpenStreetMap; '
        'affidabilità dipendente dalla qualità dei dati.',
    verifiedOn: null,
  );
}
