# CLAUDE.md — Istruzioni permanenti del progetto

Progetto: **Navigatore Scooter Italia**, app Android (Flutter) di navigazione per
ciclomotori/scooter con routing conforme al Codice della Strada.

## Regole non negoziabili
1. Costo zero salvo approvazione esplicita (vedi `COSTS.md`).
2. Nessuna installazione di software, account, servizio cloud o pubblicazione senza approvazione.
3. I divieti certi sono **vincoli rigidi** (mai solo penalità). Doppia difesa:
   motore (Valhalla `motor_scooter`) + `RouteComplianceValidator` lato app.
4. Mai dichiarare un percorso "garantito legalmente". Dati incerti → avviso esplicito.
5. Nessuna simulazione nascosta: una funzione non implementata deve risultare tale.
6. Mai dichiarare test eseguiti se non eseguiti. Registrare tutto in `TEST_RESULTS.md`
   distinguendo: automatico / documentale / sul campo.
7. Solo il **profilo A (ciclomotore 50cc)** è in sviluppo per la v1; gli altri restano
   `ProfileStatus.experimental` finché non hanno regole e test propri.
8. Nessuna telemetria/analytics. Dati personali solo sul dispositivo.
9. Rispettare le policy OSM: niente autocomplete su Nominatim pubblico, max 1 req/s,
   User-Agent identificativo, attribuzione "© OpenStreetMap contributors".

## Struttura
- `packages/scooter_core/` — logica pura Dart (regole, ETA, navigazione, provider). Nessuna dipendenza Flutter.
- `app/` — app Flutter: `lib/app` (bootstrap, tema, config), `lib/features/{map,location,settings,vehicle}`.
  La mappa è dietro `MapViewFactory` (MapLibre nell'app, doppio di test nei test widget).
- `routing/valhalla/` — configurazione server Valhalla, fixture di test.
- `scripts/` — strumenti (fixture sintetiche, test di integrazione del motore).
- `docs/` — report di milestone.

## Comandi
```bash
cd packages/scooter_core && dart pub get && dart test -x integration   # unit test core
VALHALLA_URL=http://127.0.0.1:8002/ dart test -t integration            # e2e con server reale
cd app && flutter analyze && flutter test && flutter build web   # app (web = verifica compilazione)
python -I scripts/build_fixture_network.py routing/valhalla/fixtures/scenarios.osm.pbf
python -I scripts/valhalla_integration_test.py routing/valhalla/fixtures/scenarios.osm.pbf
```

## Stato e ripresa del lavoro
Leggere in quest'ordine: `ROADMAP.md` (milestone e stato), `KNOWN_ISSUES.md`,
`TEST_RESULTS.md`, `docs/M0_REPORT.md`. Aggiornare `CHANGELOG.md` a ogni consegna.

## Decisioni prese (non rimettere in discussione senza nuovi dati)
- Frontend Flutter + MapLibre (`maplibre_gl`), Material 3.
- Routing: Valhalla (prima scelta), GraphHopper alternativa documentata.
- `highway=trunk` senza `motorroad=yes`: escluso per il 50cc (modalità prudente `TrunkPolicy.strict`).
- Tile vettoriali: OpenFreeMap (gratuito, senza chiave) — da riverificare prima della beta.
- Geocoding: Nominatim pubblico solo su invio esplicito, con throttling.
