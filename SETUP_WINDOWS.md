# Setup su Windows (NON ancora eseguito)

Questa guida è il piano di installazione per il PC Windows dell'utente. Nessun
passaggio è stato eseguito: la sessione di sviluppo attuale gira in un container
Linux cloud. Ogni installazione richiede approvazione.

## Requisiti minimi stimati
| Componente | Disco | Note |
|---|---|---|
| Flutter SDK (stable 3.47.x, Dart 3.13) | ~2,5 GB | zip ufficiale |
| Android Studio o solo cmdline-tools + SDK (platform 35/36, build-tools) | ~6–8 GB | serve per l'APK |
| JDK 17 o 21 | ~300 MB | incluso in Android Studio |
| Git for Windows | ~300 MB | |
| WSL2 + Ubuntu **oppure** Docker Desktop | 2–5 GB | per Valhalla locale |
| Valhalla tile area Modena | < 1 GB | estratto + tile |
| **Totale** | **~15 GB** | RAM consigliata 8 GB (16 GB comodi) |

## Passi
1. **Verifica**: `winver`, `systeminfo | findstr /C:"Memoria fisica"`, `wsl --status`,
   `git --version`, `java -version`, `flutter --version`.
2. **Git**: https://git-scm.com/download/win
3. **Flutter**: scaricare lo zip stable da https://docs.flutter.dev/get-started/install/windows,
   estrarre in `C:\dev\flutter`, aggiungere `C:\dev\flutter\bin` al PATH, `flutter doctor`.
4. **Android**: installare Android Studio (o cmdline-tools), poi
   `flutter doctor --android-licenses`.
5. **Telefono**: Opzioni sviluppatore → Debug USB; `flutter devices`.
6. **Valhalla** (sviluppo, opzione A):
   - WSL2: `wsl --install -d Ubuntu`, poi in Ubuntu: `python3 -m venv ~/vh && ~/vh/bin/pip install pyvalhalla osmium`;
   - oppure Docker Desktop: `docker compose -f routing/valhalla/docker-compose.yml up`.
7. **Dati**: scaricare `nord-est-latest.osm.pbf` da Geofabrik e ritagliare la provincia di
   Modena (vedi `routing/valhalla/README.md`).
8. **Rete locale**: il telefono deve raggiungere il PC (stessa Wi-Fi, IP del PC, porta 8002,
   regola firewall in ingresso). Solo per test in casa.

## Build
```powershell
cd packages\scooter_core; dart pub get; dart test
cd ..\..\app; flutter pub get; flutter test; flutter build apk --release
```
