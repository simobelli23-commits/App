# App Flutter — Navigatore Scooter

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=ROUTING_URL=http://<ip-pc>:8002/
```
Configurazione via `--dart-define`: `MAP_STYLE_URL`, `ROUTING_URL` (vedi `lib/app/app_config.dart`).

Server di sviluppo in HTTP sulla rete di casa: compilare con `ALLOW_CLEARTEXT=true`
nell'ambiente (altrimenti Android blocca le connessioni non cifrate). Su GitHub Actions
basta indicare `routing_url` all'avvio del workflow.
La piattaforma `web` è usata solo come verifica di compilazione nell'ambiente cloud.
