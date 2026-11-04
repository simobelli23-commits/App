# Problemi noti e limitazioni

1. **Codice core non compilato né testato** (manca Dart SDK). Possibili errori di
   compilazione da correggere alla prima esecuzione.
2. **Comportamento reale di Valhalla `motor_scooter` non verificato** su motorway,
   motorroad, private, oneway:bicycle, restrizioni di svolta.
3. **Regole normative non verificate sul testo ufficiale** (Normattiva bloccato).
4. **`highway=trunk` escluso per prudenza**: può allungare percorsi dove una trunk è
   in realtà consentita ai ciclomotori.
5. Il validatore lato app vede solo `road_class`/`use` degli archi: `motorroad=yes`
   su strade non-trunk e `moped=no` dipendono dal motore (coperti dai test di integrazione).
6. Con `reclassify_links=true` (default Valhalla) gli svincoli autostradali possono
   ricevere una classe inferiore: la config del progetto lo imposta a `false` — da verificare.
7. ZTL e restrizioni orarie (`*:conditional`) non interpretate: tratti marcati incerti.
8. ETA: tutti gli archi considerati urbani (manca il dato per arco); stima prudente.
9. ETA residuo proporzionale alla distanza: impreciso su percorsi misti urbano/extraurbano.
10. Nessuna app Flutter ancora: mappa, GPS, TTS, ricerca, SQLite da implementare (M1–M4).
11. Navigazione fuori casa impossibile finché il server di routing gira solo sul PC (opzione A).
12. Ambiente cloud: niente Android SDK (dl.google.com bloccato) → APK non generabile qui.
