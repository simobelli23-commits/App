# Licenze e dipendenze

## Dipendenze attuali
| Componente | Dove | Licenza | Stato |
|---|---|---|---|
| Flutter 3.47.9 / Dart 3.13.7 | build | BSD-3 | installato in /opt/tools (container) |
| package:test, package:lints | dev core | BSD-3 | dichiarate in pubspec |
| Valhalla / pyvalhalla 3.9.1 | routing, test | MIT | installato in venv /opt/tools/venv |
| pyosmium | fixture | BSD-2 | installato in venv |
| Docker image `ghcr.io/valhalla/valhalla-scripted` | server sviluppo | MIT | non scaricata |

## Dipendenze app (verificate su pub.dev il 2026-11-04)
| Pacchetto | Versione | Licenza | Note |
|---|---|---|---|
| maplibre_gl | 0.27.1 (fissata) | BSD-3 | 0.28.0 uscita il giorno prima: scartata per prudenza |
| geolocator | ^14.1.2 | MIT | |
| shared_preferences | ^2.5.6 | BSD-3 | preferenze locali |
| flutter_localizations | SDK | BSD-3 | testi Material in italiano |
Previste: flutter_tts (MIT, M3), sqflite (BSD-2, M4), http (BSD-3) o dart:io.

## Dati
OpenStreetMap — ODbL 1.0. Attribuzione obbligatoria visibile sulla mappa e nella
schermata Impostazioni → Attribuzioni.

## Licenza del progetto
Da decidere con l'utente (il codice è privato finché non indicato diversamente).
