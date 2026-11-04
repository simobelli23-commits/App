# Licenze e dipendenze

## Dipendenze attuali
| Componente | Dove | Licenza | Stato |
|---|---|---|---|
| Flutter 3.47.9 / Dart 3.13.7 | build | BSD-3 | installato in /opt/tools (container) |
| package:test, package:lints | dev core | BSD-3 | dichiarate in pubspec |
| Valhalla / pyvalhalla 3.9.1 | routing, test | MIT | installato in venv /opt/tools/venv |
| pyosmium | fixture | BSD-2 | installato in venv |
| Docker image `ghcr.io/valhalla/valhalla-scripted` | server sviluppo | MIT | non scaricata |

## Dipendenze previste per l'app (M1)
maplibre_gl (BSD-3), geolocator (MIT), flutter_tts (MIT), sqflite (BSD-2), http (BSD-3).
Versioni e licenze da riverificare su pub.dev al momento dell'aggiunta.

## Dati
OpenStreetMap — ODbL 1.0. Attribuzione obbligatoria visibile sulla mappa e nella
schermata Impostazioni → Attribuzioni.

## Licenza del progetto
Da decidere con l'utente (il codice è privato finché non indicato diversamente).
