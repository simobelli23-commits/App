# Architettura

## Principi
- Logica di navigazione **separata** dalla UI: `packages/scooter_core` è Dart puro,
  testabile senza Flutter né dispositivo.
- Implementazioni concrete sostituibili dietro interfacce.
- Nessun backend proprietario: unico servizio remoto è il server di routing.

## Moduli

```
packages/scooter_core/lib/src/
  geo/          LatLng, haversine, polilinee (polyline6), proiezione su percorso
  vehicle/      VehicleProfile, categorie giuridiche, profili A–E (solo A in sviluppo)
  rules/        OsmAccessRules (tag OSM → Legality), TurnRestrictionEvaluator,
                RouteComplianceValidator, LegalRefs (fonti normative)
  eta/          EtaModel deterministico
  navigation/   NavigationSession: aggancio, prossima manovra, fuori percorso,
                perdita GPS, arrivo, limitazione ricalcoli
  providers/    Interfacce RoutingProvider, GeocodingProvider, LocationProvider,
                MapProvider + tipi Result/errori
  valhalla/     ValhallaRoutingProvider, request builder, parser, HttpTransport

app/ (Flutter) — stato M1: map, location, settings, vehicle implementati
  lib/app/          bootstrap, tema M3 chiaro/scuro, routing schermate
  lib/features/map/          MapLibre (maplibre_gl), posizione, ricentraggio
  lib/features/search/       ricerca su invio (Nominatim), cronologia, selezione su mappa
  lib/features/navigation/   schermata guida, TTS italiano (flutter_tts)
  lib/features/vehicle/      selezione profilo
  lib/features/settings/     voce, unità, tema, privacy, attribuzioni
  lib/data/                  SQLite (sqflite): preferiti, recenti, preferenze
  lib/adapters/              HttpTransport (package:http), LocationProvider (geolocator)
```

## Flusso di calcolo percorso

```
UI ──RouteRequest──▶ ValhallaRoutingProvider
                       1. POST /route (motor_scooter, top_speed=45, it-IT)
                       2. per ogni percorso (principale + alternativa):
                          POST /trace_attributes → archi (road_class, use, way_id)
                       3. RouteComplianceValidator: arco vietato ⇒ percorso scartato
                       4. EtaModel ⇒ modelTimeS; avvisi su dati incerti
                    ◀── Ok([percorsi validi]) | Err(RoutingError)
```

Se nessun percorso supera la verifica: `rejectedByCompliance` / `noRoute` — l'app
lo comunica e **non** propone alternative inventate. Se la verifica non è
possibile (server non risponde a trace_attributes) il percorso **non** viene mostrato
come valido.

## Errori
Tutti gli errori attraversano i confini come `Result.Err` tipizzati
(`RoutingErrorKind`, `GeocodingErrorKind`, `LocationErrorKind`); la UI ha un messaggio
per ciascun tipo. Nessuna eccezione dei provider deve arrivare alla UI.

## Dipendenze previste (da verificare versioni/licenze al momento dell'aggiunta)
| Pacchetto | Uso | Licenza |
|---|---|---|
| maplibre_gl | mappa vettoriale | BSD-3 (MapLibre: BSD-2) |
| geolocator | GPS | MIT |
| flutter_tts | sintesi vocale (motore TTS di sistema) | MIT |
| sqflite | SQLite | BSD-2 |
| http | HTTP | BSD-3 |
| permission_handler (se necessario) | permessi | MIT |

## Decisioni architetturali (ADR sintetici)
- **ADR-1** Valhalla primario (vedi `docs/M0_REPORT.md` §2).
- **ADR-2** Doppia verifica dei divieti (motore + validatore app).
- **ADR-3** `trunk` senza `motorroad` escluso per il 50cc (prudenza).
- **ADR-4** Nessun backend/account in v1; server di routing self-hosted.
- **ADR-5** ETA deterministico in-app, indipendente dal motore (confrontabile).
