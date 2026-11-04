# Navigatore Scooter Italia

Navigatore Android (Flutter) per ciclomotori e scooter, con percorsi compatibili con la
categoria del veicolo e le restrizioni del Codice della Strada italiano.
Prima versione: **ciclomotore 50 cc (45 km/h)**, area di test **provincia di Modena**.

> Stato: **Milestone 0**. Esiste il nucleo logico (`packages/scooter_core`), ma **non è
> ancora stato compilato né testato**. Non esiste ancora un'app installabile.
> Vedi `ROADMAP.md` e `TEST_RESULTS.md`.

## Contenuto
- `packages/scooter_core/`: regole di percorribilità (tag OSM → vietato/consentito/incerto),
  divieti di svolta, verifica di conformità dei percorsi, modello ETA, logica di navigazione,
  provider Valhalla.
- `routing/valhalla/`: server Valhalla di sviluppo e fixture.
- `scripts/`: generatore di rete sintetica e test di integrazione del motore reale.
- Documentazione: `ARCHITECTURE.md`, `ROUTING_RULES.md`, `DATA_SOURCES.md`, `TEST_PLAN.md`,
  `SETUP_WINDOWS.md`, `COSTS.md`, `KNOWN_ISSUES.md`, `docs/M0_REPORT.md`.

## Avvertenza
I percorsi sono calcolati su dati OpenStreetMap, che possono essere incompleti. L'app non
garantisce la conformità legale del percorso: la segnaletica sul posto prevale sempre.

Dati cartografici © OpenStreetMap contributors (ODbL).
