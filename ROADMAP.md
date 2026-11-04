# Roadmap

| Milestone | Stato | Criteri di completamento |
|---|---|---|
| M0 Ambiente, ricerca, architettura | **completata con riserve** (vedi sotto) | report ambiente, confronto motori, criticità, architettura, docs |
| M1 Flutter compilabile + mappa | da iniziare | `flutter analyze` pulito, `flutter test` verde, mappa OpenFreeMap con attribuzione, posizione e ricentraggio |
| M2 Routing locale 50cc + test divieti | **in corso**: unit 53/53, integrazione sintetica 13 PASS + 2 INFO, e2e 4/4; manca dataset Modena | unit test core verdi; 13 scenari integrazione PASS; estratto Modena; ≥100 percorsi registrati |
| M3 GPS + turn-by-turn | logica core scritta | NavigationSession integrata, TTS it-IT, ricalcolo, gestione perdita GPS/rete |
| M4 Ricerca, preferiti, impostazioni | da iniziare | Nominatim su invio + throttle, SQLite, impostazioni complete |
| M5 Test e correzioni | da iniziare | tutte le suite verdi, KNOWN_ISSUES aggiornato |
| M6 APK + dispositivo reale | da iniziare | APK release installato su telefono, checklist dispositivo |
| M7 Beta privata | da iniziare | server raggiungibile in mobilità via HTTPS, test di guida reali |

## Riserve M0
- Ambiente analizzato è il container cloud, non il PC Windows.
- Test eseguiti solo nel container cloud (vedi `TEST_RESULTS.md`).

## Bloccanti (richiedono decisione dell'utente)
1. ~~Autorizzare installazioni Flutter/pyvalhalla~~ — autorizzato e fatto il 2026-11-04.
2. Abilitare nella policy di rete dell'ambiente: `download.geofabrik.de` (dati Modena),
   `dl.google.com` (Android SDK per APK); utili: `www.normattiva.it`, `tiles.openfreemap.org`.
3. In alternativa: lavorare sul PC Windows seguendo `SETUP_WINDOWS.md`.
4. Build APK tramite GitHub Actions (gratuito nei limiti del piano): approvare o no.

## Futuro
Profili B–E; routing offline su dispositivo; ZTL da fonti comunali verificate;
calibrazione ETA con dati aggregati e consenso; copertura nazionale.
