# App Flutter — Navigatore Scooter

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=ROUTING_URL=http://<ip-pc>:8002/
```
Configurazione via `--dart-define`: `MAP_STYLE_URL`, `ROUTING_URL` (vedi `lib/app/app_config.dart`).
La piattaforma `web` è usata solo come verifica di compilazione nell'ambiente cloud.
