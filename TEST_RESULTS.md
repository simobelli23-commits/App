# Risultati dei test

Legenda fonte di verifica: **automatica** (codice/motore), **documentale**, **campo** (guida reale).

## 2026-11-04 — Milestone 0/2 (sessione cloud Linux)

Ambiente: Ubuntu 24.04 x86_64, Dart 3.13.7 (Flutter 3.47.9 stable, sha256 verificato),
pyvalhalla 3.9.1, pyosmium (PyPI).

### Unit test `packages/scooter_core` — `dart test` (escluso tag integration)
**53 / 53 superati, 0 falliti.** `dart analyze`: nessun problema.

| File | Casi | Esito |
|---|---|---|
| rules_test.dart | 28 | PASS |
| geo_eta_test.dart | 10 | PASS |
| navigation_test.dart | 6 | PASS |
| valhalla_provider_test.dart | 9 | PASS |

Verifica anti-test-vuoti (mutation check manuale):
- disattivata la regola "motorway" nel validatore → 2 test falliti (atteso);
- applicato `oneway:bicycle` ai ciclomotori → 1 test fallito (atteso).
Codice ripristinato dopo la verifica.

### Integrazione motore Valhalla reale — `scripts/valhalla_integration_test.py`
Rete **sintetica** (non dati reali), costing `motor_scooter`, `top_speed=45`,
`reclassify_links=false`, nessun database amministrativo. Fonte: automatica.

| Scenario | Atteso 50cc | Esito | Controllo (costing che deve usare la scorciatoia) |
|---|---|---|---|
| motorway | evita | PASS | auto: usa ✔ |
| motorway_only | nessun percorso | PASS (errore 442) | auto: usa ✔ |
| motorroad (trunk+motorroad=yes) | evita | PASS | auto ✔ |
| trunk_plain (trunk senza motorroad) | info | evitato dal motore | auto ✔ |
| trunk_moped_yes | info | evitato dal motore anche con moped=yes | auto ✔ |
| oneway_against (oneway=-1) | evita | PASS | pedestrian ✔ |
| oneway_except_bike (oneway=yes + oneway:bicycle=no) | evita | PASS | bicycle ✔ |
| oneway_yes_reversed | evita | PASS | pedestrian ✔ |
| cycleway | evita | PASS | bicycle ✔ |
| footway | evita | PASS | pedestrian ✔ |
| private (access=private) | evita | PASS | pedestrian ✔ |
| moped_no | evita | PASS | auto ✔ |
| motor_vehicle_no | evita | PASS | pedestrian ✔ |
| turn_restriction (no_straight_on) | evita | PASS | pedestrian ✔ |
| residential_ok | usa | PASS | auto ✔ |

**13 PASS, 2 INFO, 0 FAIL, 0 INVALID.**

Nota storica: alla prima esecuzione `oneway_except_bike` (con `oneway=-1`) risultava
INVALID: il controllo bicicletta non usava la scorciatoia, quindi la fixture non
dimostrava nulla. Fixture corretta (`oneway=yes` su way digitalizzata al contrario)
e aggiunto lo scenario `oneway_yes_reversed`.

### End-to-end provider Dart ↔ Valhalla HTTP reale — `test/valhalla_live_test.dart`
`valhalla_service` locale su tile della rete sintetica; `VALHALLA_URL=http://127.0.0.1:8002/`.
**4 / 4 superati**: percorso che evita l'autostrada (3560 m, istruzioni in italiano, ETA
modello calcolato), nessun percorso per destinazione raggiungibile solo in autostrada
(`noRoute`), istruzioni in italiano, server irraggiungibile gestito.

Esempio reale (scenario motorway): motore 370 s, modello app 602 s — vedi KNOWN_ISSUES §8.

### Non eseguiti
| Suite | Motivo |
|---|---|
| Dataset Modena (≥100 percorsi) | estratti OSM non scaricabili (download.geofabrik.de bloccato) |
| Widget/UI | app Flutter non ancora creata (M1) |
| Dispositivo / campo | nessun dispositivo Android; Android SDK non scaricabile (dl.google.com bloccato) |
