# Prova su smartphone — checklist

APK: GitHub → Actions → "Android APK" → ultima esecuzione riuscita → Artifacts →
`navigatore-scooter-apk` (zip con `app-release.apk`).
Build senza server di routing: il calcolo percorso deve rispondere
"Server di routing non configurato" (comportamento atteso, non un errore).

**Sicurezza:** tutte le prove da fermo. Nessuna prova di guida in questa fase.

| # | Prova | Atteso | Esito (OK/KO + note) |
|---|---|---|---|
| 1 | Installazione (consentire "origini sconosciute") | l'app "Navigatore Scooter" si installa e si apre | |
| 2 | Primo avvio | richiesta permesso posizione | |
| 3 | Concedi permesso | mappa visibile (strade, nomi) centrata su di te, pallino blu | |
| 4 | Sposta la mappa, poi pulsante ricentra | torna sulla tua posizione | |
| 5 | Nega il permesso (reinstalla o da Impostazioni Android) | banner "Permesso di posizione negato" + pulsante | |
| 6 | Disattiva la localizzazione del telefono | banner "GPS disattivato" + "Apri impostazioni" | |
| 7 | Modalità aereo e avvio app | l'app non si chiude; mappa assente o parziale | |
| 8 | Tieni premuto sulla mappa | punto rosso + "Server di routing non configurato…" + "Riprova" | |
| 9 | Impostazioni → Tema → Scuro | interfaccia scura, scelta mantenuta dopo riavvio | |
| 10 | Impostazioni → Profilo veicolo | solo "Ciclomotore 50 cc" selezionabile | |
| 11 | Impostazioni → Attribuzioni / Privacy | testi leggibili | |
| 12 | Testo e pulsanti | leggibili e premibili con un dito, anche con i guanti | |
| 13 | Voce italiana installata? (Impostazioni Android → Sintesi vocale) | lingua italiana disponibile | |

Annotare: modello del telefono, versione Android, eventuali messaggi d'errore
(screenshot). Riportare l'esito in chat o in `TEST_RESULTS.md` (fonte: **campo**).
