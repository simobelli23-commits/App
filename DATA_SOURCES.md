# Fonti dati e condizioni d'uso

| Fonte | Uso | Licenza / policy | Note |
|---|---|---|---|
| OpenStreetMap (via estratto Geofabrik) | grafo di routing | ODbL 1.0 — attribuzione "© OpenStreetMap contributors", share-alike sul database derivato | estratto `italy/nord-est` ritagliato su provincia di Modena |
| Geofabrik download server | download estratti | gratuito, uso ragionevole | aggiornamento giornaliero; **bloccato nell'ambiente cloud** |
| OpenFreeMap (tiles.openfreemap.org) | tile vettoriali mappa | gratuito, senza chiave; dati OSM (ODbL) + schema OpenMapTiles (attribuzione) | da riverificare condizioni prima della beta; alternativa: tile self-hosted (Protomaps PMTiles) |
| tile.openstreetmap.org | — | **non usato**: la tile usage policy scoraggia l'uso intensivo da app | |
| Nominatim pubblico | geocoding | max 1 req/s, **niente autocomplete**, User-Agent identificativo, attribuzione, cache | ricerca solo su invio; per volumi maggiori: Nominatim/Photon self-hosted |
| Normattiva | testi di legge | pubblico | fonte di verifica delle regole (non ancora consultata: host bloccato) |

## Uso commerciale futuro
- ODbL consente uso commerciale con attribuzione; il database derivato (es. tile Valhalla)
  ridistribuito resta ODbL.
- Nominatim/OpenFreeMap pubblici non vanno usati per volumi commerciali: prevedere
  istanze proprie (costo da approvare).

## Copertura geografica
Prima sperimentazione: provincia di Modena (bbox indicativa 10.45–11.35 E, 44.10–44.95 N,
da raffinare con il confine amministrativo OSM). Ampliamento: cambiare estratto e
ricostruire le tile, nessuna modifica al codice.
