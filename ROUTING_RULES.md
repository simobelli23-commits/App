# Regole di routing implementate

Versione regole: **0.1.0** — 2026-11-04. Profilo implementato: **A (ciclomotore 50cc)**.

> ⚠️ I testi normativi **non sono ancora stati verificati sulla fonte ufficiale**
> (Normattiva non raggiungibile dall'ambiente di sviluppo). Ogni regola riporta il
> riferimento; `verifiedOn` in `legal_refs.dart` resta `null` finché non verificato.

## Fonti
| ID | Fonte | Stato |
|---|---|---|
| CdS-175-2 | D.Lgs. 285/1992 art. 175 c.2 — divieto autostrade/extraurbane principali per ciclomotori | da verificare su Normattiva |
| CdS-52 | art. 52 — definizione ciclomotore (≤50 cc / ≤4 kW, ≤45 km/h) | da verificare |
| CdS-7 | art. 7 — ZTL e regolamentazione urbana | da verificare |
| L.177/2024 | riforma CdS: accesso motocicli ≥120 cc (maggiorenni) ad autostrade | da verificare — rilevante solo per profili B/C |
| SEGNALETICA | divieti locali tramite tag OSM | dipende dai dati |

## Profilo A — vincoli rigidi (Legality.forbidden)
| Condizione OSM | Motivo | Rif. |
|---|---|---|
| `highway=motorway`, `motorway_link` (anche se `moped=yes`) | autostrada | CdS-175-2 |
| `motorroad=yes` su qualunque classe | extraurbana principale | CdS-175-2 |
| `highway=trunk`/`trunk_link` senza `motorroad` *(modalità prudente, default)* | possibile extraurbana principale | CdS-175-2 |
| `moped=no` | divieto esplicito | SEGNALETICA |
| `motor_vehicle`/`vehicle`/`access` = `no`, `agricultural`, `forestry`, `use_sidepath` (se non c'è un tag più specifico) | divieto | SEGNALETICA |
| `highway` ∈ footway, pedestrian, cycleway, path, steps, bridleway, corridor, elevator senza `moped`/`motor_vehicle`=yes | non motorizzato | SEGNALETICA |
| `highway` ∈ construction, proposed, abandoned, platform, raceway… | non percorribile | — |
| Senso unico: `oneway:moped` > `oneway`; `junction=roundabout` implica senso unico; **`oneway:bicycle=no` NON vale** | sensi unici | SEGNALETICA |
| Svolte: `restriction:moped` > `restriction`; `except` esenta solo se contiene `moped` | divieti/obblighi di svolta | SEGNALETICA |

Gerarchia di accesso: `moped` → `motor_vehicle` → `vehicle` → `access`. Valori multipli
(`a;b`): prevale il più restrittivo.

## Profilo A — solo come destinazione (Legality.destinationOnly)
`private`, `destination`, `delivery`, `customers`.

## Profilo A — incerto (Legality.uncertain)
- `*:conditional` (orari, ZTL): non interpretati nell'MVP.
- `highway=track` senza tag; `discouraged`; valori sconosciuti; `oneway=alternating`.
- Trunk in modalità permissiva.

Un percorso con soli tratti incerti è mostrato **con avviso** ("conformità non
garantita"); non è mai dichiarato legalmente garantito.

## Implementazione nel motore
1. **Valhalla `motor_scooter`** (gerarchia `moped`), `top_speed=45`, `use_ferry=0`,
   `use_tracks=0`. Config tile: `mjolnir.reclassify_links=false` per non far
   "declassare" gli svincoli autostradali.
2. **RouteComplianceValidator** (app): rifiuta percorsi con archi `road_class`
   motorway/trunk o `use` cycleway/footway/pedestrian/steps/path/... .

Limite noto: il validatore vede classe/uso dell'arco, non i tag `motorroad`/`moped`;
l'esclusione di questi dipende dal motore → coperta dai test di integrazione
`scripts/valhalla_integration_test.py` (scenari `motorroad`, `moped_no`).

## ETA (modello deterministico MVP)
```
v_seg = max(1, min(v_max_veicolo × 0.9, limite_legale, v_tipica_classe))
t = Σ len/v_seg + Σ penalità_manovra + 20 s/km in ambito urbano
```
- Limite legale di default: 50 km/h urbano, 90 extraurbano (art. 142).
- Velocità tipiche: residenziale 25, terziaria 30/55, secondaria 35/65, primaria 40/70
  (urbano/extraurbano), living_street 10, service/track 15.
- Penalità manovra (s): lieve 2, svolta 6, stretta 8, inversione 15, rotatoria 8, immissione 4.
- MVP: ogni arco è considerato urbano (stima prudente) finché non è disponibile il dato.
- ETA residuo in guida: proporzionale alla distanza residua.
- Calibrazione futura con dati GPS aggregati **solo con consenso** (non implementata).

## Profili B–E
Predisposti (`VehicleProfiles`), stato `experimental`. Il provider restituisce
`profileNotSupported`; le regole restituiscono `uncertain`. Non selezionabili come pronti.
