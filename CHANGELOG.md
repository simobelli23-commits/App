# Changelog

## [0.0.2] — 2026-11-04
### Aggiunto
- `IoHttpTransport` (dart:io) e test end-to-end contro `valhalla_service` reale.
- Scenari `trunk_moped_yes`, `oneway_yes_reversed`.
### Corretto
- Script integrazione: configurazione pyvalhalla e invocazione diretta di `valhalla_build_tiles`.
- Fixture `oneway_except_bike` (prima risultava INVALID: controllo bici non significativo).
### Test
- Unit 53/53, integrazione sintetica 13 PASS + 2 INFO, e2e 4/4. Vedi TEST_RESULTS.md.

## [0.0.1] — 2026-11-04 — Milestone 0
### Aggiunto
- Documentazione iniziale (architettura, regole, fonti, licenze, costi, piano test, setup Windows).
- `scooter_core`: profili veicolo, regole OSM per ciclomotore, restrizioni di svolta,
  `RouteComplianceValidator`, `EtaModel`, `NavigationSession`, `ValhallaRoutingProvider`,
  interfacce dei provider; test unitari (non ancora eseguiti).
- Script: rete sintetica di test e test di integrazione Valhalla con scenari di controllo (non eseguiti).
