# Problemi noti e limitazioni

1. Core testato solo con unit test e rete **sintetica**: nessuna verifica su dati reali di Modena.
2. Valhalla `motor_scooter` verificato su rete sintetica **senza database amministrativo**
   (`build_admins` non eseguito): con admin per Italia le regole di accesso per paese
   potrebbero cambiare → ripetere i test di integrazione con admin.
2b. Valhalla evita `highway=trunk` anche con `moped=yes` esplicito (scenario `trunk_moped_yes`):
   causa (accesso negato vs costo) non indagata; coerente con la politica prudente ma da capire.
3. **Regole normative non verificate sul testo ufficiale** (Normattiva bloccato).
4. **`highway=trunk` escluso per prudenza**: può allungare percorsi dove una trunk è
   in realtà consentita ai ciclomotori.
5. Il validatore lato app vede solo `road_class`/`use` degli archi: `motorroad=yes`
   su strade non-trunk e `moped=no` dipendono dal motore (coperti dai test di integrazione).
6. Con `reclassify_links=true` (default Valhalla) gli svincoli autostradali possono
   ricevere una classe inferiore: la config del progetto lo imposta a `false` — da verificare.
7. ZTL e restrizioni orarie (`*:conditional`) non interpretate: tratti marcati incerti.
8. ETA: tutti gli archi considerati urbani (manca il dato per arco); stima prudente.
   Su 3,6 km residenziali sintetici: modello app 602 s vs motore 370 s. Da calibrare sui
   dati reali (le velocità tipiche sono ipotesi, non misure).
9. ETA residuo proporzionale alla distanza: impreciso su percorsi misti urbano/extraurbano.
10. Ricerca per indirizzo non ancora disponibile (M4): destinazione solo con pressione
    prolungata sulla mappa. Preferiti/cronologia/SQLite non implementati.
10f. URL del server di routing fissato in fase di build (`--dart-define=ROUTING_URL`);
    senza, ogni calcolo fallisce con "Server di routing non configurato".
10g. HTTP in chiaro consentito solo con build `ALLOW_CLEARTEXT=true` (server di sviluppo
    in LAN). Per la beta serve HTTPS.
10h. Se il telefono non ha la voce italiana installata, l'app resta in silenzio (nessun
    avviso visivo dedicato ancora).
10i. Navigazione solo in primo piano: con app in background o schermo bloccato il GPS
    si ferma (nessun servizio in background).
10j. Il "fuori percorso" non usa map matching vero: proiezione sul percorso con soglia
    40 m + accuratezza, 3 fix consecutivi. Ricalcolo al massimo ogni 15 s.
10b. Rendering mappa e GPS mai provati su dispositivo; tile OpenFreeMap non verificate.
10c. Tema scuro: la mappa usa lo stesso stile chiaro "liberty" (nessuno stile scuro configurato).
10d. APK release firmato con chiave di debug (solo test, non pubblicabile).
10e. Raggio di accuratezza GPS disegnato in pixel con approssimazione fissa (non in metri reali).
11. Navigazione fuori casa impossibile finché il server di routing gira solo sul PC (opzione A).
12. Ambiente cloud: niente Android SDK (dl.google.com bloccato) → APK generato su GitHub Actions.
13. `IoHttpTransport` distingue "nessuna rete" da "server irraggiungibile" con euristiche
    sull'errore socket; su Android va verificato anche con la connettività di sistema.
