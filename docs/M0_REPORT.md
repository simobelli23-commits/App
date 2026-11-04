# Milestone 0 — Report: ambiente, ricerca tecnica, decisioni

Data: 2026-11-04

## 1. Ambiente effettivamente disponibile

Il prompt prevede un PC Windows. **Questa sessione gira invece in un container cloud
Linux** (Claude Code remoto). Le verifiche qui sotto valgono per il container; il
setup Windows è descritto (non eseguito) in `SETUP_WINDOWS.md`.

| Voce | Rilevato |
|---|---|
| OS | Ubuntu 24.04.5 LTS, x86_64, kernel 6.18 |
| CPU / RAM | 4 core / 15 GB, nessuno swap |
| Disco | ~31 GB disponibili |
| Git | presente |
| Java | OpenJDK 21.0.12 |
| Python | presente (python3) |
| Node | 22 |
| Docker | client presente, **daemon non attivo** |
| Flutter / Dart | **assenti** |
| Android SDK / adb | **assenti** |
| Dispositivo Android | **nessuno** collegato (impossibile in cloud) |

### Rete (policy dell'ambiente)
| Host | Esito |
|---|---|
| storage.googleapis.com (Flutter SDK) | raggiungibile |
| pub.dev, pypi.org, repo.maven.apache.org, maven.google.com, services.gradle.org | raggiungibili |
| ghcr.io, registry Docker Hub | raggiungibili |
| **dl.google.com** (Android SDK, platform-tools, build-tools) | **bloccato** |
| **download.geofabrik.de** (estratti OSM) | **bloccato** |
| planet.openstreetmap.org, overpass-api.de, nominatim.openstreetmap.org, tile.openstreetmap.org | **bloccati** |
| tiles.openfreemap.org | **bloccato** |
| www.normattiva.it (testi di legge ufficiali) | **bloccato** |

### Permessi
Il tentativo di scaricare Flutter SDK e installare `pyvalhalla` è stato **rifiutato
dal sistema di permessi** (codice esterno non approvato). Coerente con il principio 14:
serve l'approvazione dell'utente.

### Conseguenze
- In questa sessione **non è stato possibile compilare né eseguire alcun test**.
- APK: impossibile qui senza Android SDK (dl.google.com bloccato). Alternative:
  build su PC Windows dell'utente, oppure GitHub Actions (runner con Android SDK
  preinstallato; minuti gratuiti inclusi nel piano GitHub — da approvare).
- Dati OSM reali di Modena: non scaricabili qui. Il codice di test usa una rete
  **sintetica** generata da script (dichiarata come tale).

## 2. Valhalla vs GraphHopper per il profilo 50cc italiano

| Criterio | Valhalla | GraphHopper |
|---|---|---|
| Licenza | MIT | Apache 2.0 |
| Profilo ciclomotore nativo | **Sì**: costing `motor_scooter`, usa la gerarchia OSM `moped` → `motor_vehicle` → `vehicle` → `access` | No profilo moped nativo: si parte da `car` + custom model; i tag `moped=*` non sono letti di default |
| Velocità massima veicolo | `top_speed` (default 45 km/h per motor_scooter) | `limit_speed` nel custom model |
| Vincoli rigidi | accesso per modalità nel grafo (vietato = arco non percorribile) | `multiply_by: 0` nel custom model (rigido) — molto leggibile |
| Sensi unici / svolte | Sì, per modalità (incl. `restriction:*`, `except`) | Sì (turn costs da abilitare) |
| Restrizioni orarie | parziale (`conditional`, time-dependent) | parziale |
| Verifica post-percorso | `/trace_attributes` restituisce road_class/use/way_id per arco | `details` (road_class, road_access…) |
| Offline su dispositivo (futuro) | possibile (libvalhalla compilabile per Android; tile tar) | possibile (GraphHopper su Android, progetto meno mantenuto) |
| Requisiti server | leggero; tile da estratto regionale in minuti | JVM; RAM proporzionale all'area |
| Python per test | `pyvalhalla` (wheel con binari) | JAR da Maven Central |

**Decisione: Valhalla** come motore primario, perché il costing `motor_scooter`
modella già la categoria giuridica "ciclomotore" tramite il tag `moped` usato dalla
comunità OSM italiana. GraphHopper resta alternativa (interfaccia `RoutingProvider`).

**Da verificare con test reali (M2)** — non dato per scontato:
- che `motor_scooter` neghi `highway=motorway` e `motorroad=yes` anche senza tag `moped=no`
  e senza database amministrativo dei paesi;
- comportamento con `access=private` (destinazione) e `oneway:bicycle=no`;
- effetto di `reclassify_links` sulla classe degli svincoli (impostato a `false`).

Per questo il progetto include la **seconda linea di difesa** lato app
(`RouteComplianceValidator`): ogni percorso viene ri-verificato arco per arco; un solo
arco autostradale/trunk/ciclabile → percorso rifiutato.

## 3. Criticità normative e dei dati

1. **Art. 175 c.2 CdS**: ciclomotori esclusi da autostrade ed extraurbane principali.
   Testo ufficiale non consultabile da questo ambiente (Normattiva bloccato):
   `verifiedOn = null` in `legal_refs.dart` finché non verificato.
2. **Riforma L. 177/2024**: ha modificato l'accesso dei motocicli (≥ 120 cc, conducente
   maggiorenne) ad autostrade/extraurbane principali. Rilevante per profili B/C,
   **non verificata** sul testo ufficiale → profili B/C non implementati.
3. **Mappatura OSM delle extraurbane principali**: in Italia si usa `highway=trunk` +
   `motorroad=yes`, ma non sempre in modo coerente. `trunk` senza `motorroad` è
   ambiguo → escluso in modalità prudente (possibili falsi negativi: percorsi più
   lunghi del necessario, mai percorsi vietati per questa causa).
4. **ZTL**: istituite per ordinanza comunale, orari e deroghe variabili. In OSM spesso
   assenti o come `*:conditional`. MVP: tratti con condizionali = "incerti", nessuna
   affermazione di conformità.
5. **Tangenziale di Modena** e svincoli A1/A22: casi di test prioritari (M2), da
   verificare sui dati reali.
6. Qualità dati: divieti locali (segnaletica) presenti solo se mappati in OSM.

## 4. Architettura minima

Vedi `ARCHITECTURE.md`. Nucleo pure-Dart (`scooter_core`) separato dalla UI Flutter,
interfacce `RoutingProvider`, `GeocodingProvider`, `LocationProvider`, `MapProvider`.

## 5. Strategia online/offline (sintesi)

| Opzione | Costo | Complessità | Utilizzabile fuori casa |
|---|---|---|---|
| A. Valhalla su PC locale (Docker/WSL) | 0 € | bassa | **No** (solo stessa rete Wi-Fi) |
| B. Valhalla su server remoto | 0 € (free tier, es. Oracle Cloud Always Free ARM) o ~4–6 €/mese VPS | media | Sì (richiede HTTPS) |
| C. Routing offline su dispositivo | 0 € | alta (build nativa Android di libvalhalla) | Sì, anche senza rete |

Scelta: **A per lo sviluppo**, B per la beta (richiede approvazione account), C in roadmap.

## 6. Cosa è stato prodotto in M0
- Documentazione iniziale e `CLAUDE.md`.
- `packages/scooter_core`: regole OSM per ciclomotore, restrizioni di svolta,
  validatore di conformità, modello ETA, sessione di navigazione, provider Valhalla,
  interfacce. **Test scritti ma NON eseguiti** (Dart non disponibile).
- Script per rete sintetica e test di integrazione del motore Valhalla reale con
  scenari di controllo. **Non eseguiti.**

## 7. Decisioni richieste all'utente
Vedi sezione finale del report in chat / `ROADMAP.md` → "Bloccanti".
