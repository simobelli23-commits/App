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

## 2026-11-04 — Milestone 1 (app Flutter)

| Verifica | Esito |
|---|---|
| `flutter analyze` (app) | nessun problema |
| `flutter test` (app) — 14 test widget/unità | **14 / 14 superati** |
| `flutter build web --release` (compilazione completa, incluso maplibre_gl) | riuscita |
| `flutter build apk` | **non eseguito**: Android SDK assente (dl.google.com bloccato) |
| Rendering reale della mappa / tile OpenFreeMap | **non verificato**: tiles.openfreemap.org bloccato, vista nativa non disponibile nei test |
| GPS reale | **non verificato**: nessun dispositivo |

Test coperti: schermata iniziale (mappa, ricerca, impostazioni, ricentraggio, profilo,
attribuzione); primo fix GPS con centratura; ricentraggio con/senza posizione;
GPS disattivato; permesso negato (temporaneo e permanente); perdita del segnale dopo
10 s e ripristino; errore dello stream GPS e nuovo tentativo; tema scuro persistente;
voce on/off persistente; solo profilo A selezionabile; profilo salvato non supportato →
ciclomotore; attribuzioni ODbL e privacy.

Nei test la mappa nativa è sostituita da un doppio di test (`test/test_doubles.dart`)
che registra i comandi: verifica la logica della schermata, **non** il rendering.

Bug reali trovati dai test e corretti:
1. Tema: `fontSizeFactor` su un textTheme senza dimensioni → assert all'avvio (crash in debug).
2. Timer del watchdog GPS non fermato alla chiusura della schermata.
3. Nuovo tentativo GPS dopo un errore bloccato in attesa della cancellazione della sottoscrizione.

## 2026-11-04 — Milestone 3 (navigazione turn-by-turn)

| Suite | Esito | Fonte |
|---|---|---|
| Core unit (`dart test -x integration`) | **68 / 68** | automatica |
| Core e2e con Valhalla reale (`dart test -t integration`) | **6 / 6** | automatica, rete sintetica |
| App (`flutter test`) | **21 / 21** | automatica, doppi di test per mappa/GPS/routing |
| `flutter analyze`, `dart analyze` | nessun problema | |
| `flutter build web` (verifica compilazione) | riuscita | |

Nuovi test core (`guidance_test.dart`): formattazione italiana; annunci vocali in tre
fasi senza ripetizioni, soglie in funzione della velocità, arrivo, partenza accorpata;
motore: avvio, guida, arrivo, nessun percorso, ricalcolo con origine e direzione
attuali, ricalcolo senza rete (percorso mantenuto), perdita GPS, voce disattivata,
errore TTS non bloccante. Mutation check: rimossa la deduplica degli annunci → 2
test falliti; sostituito il percorso in caso di errore di ricalcolo → 1 test fallito.

E2e con server reale: guida simulata (un fix ogni 10 m) lungo il percorso che evita
l'autostrada → 2 svolte annunciate, arrivo; uscita sulla strada di deviazione →
ricalcolo reale dalla nuova posizione. Trascrizione vocale reale (estratto):
"Tra 100 metri, svolta a sinistra su Via motorway deviazione." → "Svolta a sinistra
su Via motorway deviazione." → … → "Sei arrivato a destinazione."
Difetto trovato e corretto: preavviso doppio quando Valhalla accorpa la partenza
con la manovra successiva ("…, poi Svolta a sinistra…").

App (`navigation_flow_test.dart`, 7 test): pressione prolungata → anteprima (distanza,
stima, avvisi, alternative); senza GPS nessuna richiesta; nessun percorso consentito
(niente "Avvia", "Riprova"); server irraggiungibile vs connessione assente; annulla;
guida completa (manovra, distanza, voce, ricalcolo, arrivo, schermo acceso/spento);
voce disattivata.

**Non verificato**: voce italiana reale del TTS Android, GPS reale, guida su strada.

## 2026-11-04 — Build APK su GitHub Actions

| Run | Commit | Esito | Note |
|---|---|---|---|
| #1 | c6a5686 | **fallita** | `maplibre_gl`: "invalid source release: 21" con JDK 17 → workflow portato a Java 21 |
| #2 | d737f79 | **riuscita** | test core + app verdi su CI; APK ~35 MB |
| #3 | d6669f7 | **riuscita** | include schermo acceso e opzione HTTP; APK senza `ROUTING_URL` |

L'APK è compilato ma **non ancora installato né provato su un telefono**.

### Non eseguiti
| Suite | Motivo |
|---|---|
| Dataset Modena (≥100 percorsi) | estratti OSM non scaricabili (download.geofabrik.de bloccato) |
| Widget/UI | app Flutter non ancora creata (M1) |
| Dispositivo / campo | nessun dispositivo Android; Android SDK non scaricabile (dl.google.com bloccato) |
