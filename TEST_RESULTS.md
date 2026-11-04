# Risultati dei test

## 2026-11-04 — Milestone 0

| Suite | Stato | Note |
|---|---|---|
| `packages/scooter_core` unit test (5 file, ~45 casi) | **NON ESEGUITI** | Dart SDK non installato; download/installazione non autorizzati in questa sessione |
| `scripts/valhalla_integration_test.py` (13 scenari) | **NON ESEGUITI** | pyvalhalla/pyosmium non installati (autorizzazione negata) |
| Dataset Modena | **NON ESISTENTE** | estratti OSM non scaricabili (download.geofabrik.de bloccato) |
| Widget/UI | n/d | app Flutter non ancora creata |
| Dispositivo / campo | **NON ESEGUITI** | nessun dispositivo Android disponibile |

Unica verifica eseguita: controllo di sintassi Python (`ast.parse`) di
`scripts/build_fixture_network.py`. Nessun codice Dart è stato compilato.
