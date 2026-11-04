# Piano di test

## Livelli
| Livello | Strumento | Cosa esercita |
|---|---|---|
| Unitari core | `dart test` in `packages/scooter_core` | regole OSM, svolte, validatore, ETA, geo, navigazione, parsing/errori provider |
| Integrazione motore | `scripts/valhalla_integration_test.py` | **Valhalla reale** su rete sintetica, con scenari di controllo |
| Integrazione dati reali | dataset Modena (M2) | Valhalla reale su estratto OSM di Modena |
| Widget/UI | `flutter test` (M1+) | schermate, stati di errore |
| Dispositivo | APK su telefono (M6) | GPS, TTS, permessi, rete |
| Campo | guida reale (M7) | navigazione; **mai manipolare il telefono in marcia** |

## Copertura richiesta → test
| Requisito | Test |
|---|---|
| Parsing dati stradali | `rules_test.dart` (tag), `valhalla_provider_test.dart` (risposte) |
| Selezione profilo | `rules_test.dart` "profili non ancora implementati", provider `profileNotSupported` |
| Esclusione autostrade 50cc | unit + integrazione `motorway`, `motorway_only` |
| Esclusione extraurbane principali | unit + integrazione `motorroad`, `trunk_plain` |
| Sensi unici | unit + integrazione `oneway_against`, `oneway_except_bike` |
| Restrizioni di svolta | unit + integrazione `turn_restriction` |
| Accessi privati | unit + integrazione `private` |
| ETA | `geo_eta_test.dart` |
| Ricerca destinazione | M4 (provider Nominatim) |
| Ricalcolo | `navigation_test.dart` (fuori percorso, limitazione ricalcoli) |
| Errori GPS | `navigation_test.dart` (perdita segnale, accuratezza) + M3 adapter |
| Errori di rete | `valhalla_provider_test.dart` (offline, server, timeout, JSON invalido) |
| Persistenza | M4 (SQLite) |

Regola anti-test-vuoti: ogni scenario di integrazione ha un **controllo** con un
costing a cui la scorciatoia è consentita; se il controllo non la usa, lo scenario è
`INVALID` (la fixture non dimostra nulla) e conta come fallimento.

## Dataset geografico Modena (M2) — ≥ 100 percorsi
File: `routing/test_routes/modena_routes.csv` (da creare con dati reali).
Colonne: `id, categoria, origine_lat, origine_lon, destinazione_lat, destinazione_lon,
profilo, atteso (route|no_route), restrizioni_rilevanti, fonte_verifica
(automatica|documentale|campo), esito, lunghezza_m, durata_s, note_errori`.

Distribuzione minima: urbani 30, extraurbani 20, vicino a tangenziali 15, svincoli
A1/A22 10, accessi limitati 10, sensi unici 10, destinazioni isolate 5.
Percorsi senza alternativa consentita: inclusi nelle categorie sopra.

Le verifiche sul campo vanno registrate solo se effettivamente svolte.
