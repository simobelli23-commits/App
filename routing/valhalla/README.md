# Valhalla — server di sviluppo

## Dati Modena
```bash
# 1. scaricare l'estratto (Geofabrik, ODbL)
curl -LO https://download.geofabrik.de/europe/italy/nord-est-latest.osm.pbf
# 2. ritagliare la provincia di Modena (bbox indicativa; osmium-tool, GPL-3)
osmium extract -b 10.45,44.10,11.35,44.95 nord-est-latest.osm.pbf -o data/modena.osm.pbf
```

## Avvio
- Docker: `docker compose up` (porta 8002).
- Senza Docker (WSL/Linux): `pip install pyvalhalla`, poi
  `python -m valhalla valhalla_build_tiles -c valhalla.json data/modena.osm.pbf`
  e `python -m valhalla valhalla_service valhalla.json 1`.

Configurazione obbligatoria per il progetto: `mjolnir.reclassify_links = false`.
**Da verificare**: che l'immagine Docker consenta di impostarla (altrimenti generare
`valhalla.json` personalizzato in `data/`).

## Test di integrazione (rete sintetica)
Vedi `scripts/valhalla_integration_test.py`. I risultati vanno in `fixtures/results.json`
e riassunti in `TEST_RESULTS.md`.
