import 'package:scooter_core/scooter_core.dart';

/// Piattaforme senza dart:io (web, usato solo come verifica di compilazione).
HttpTransport createTransport() => const _Unsupported();

class _Unsupported implements HttpTransport {
  const _Unsupported();
  @override
  Future<HttpReply> postJson(Uri url, String body, {Duration? timeout}) async =>
      throw const TransportException(
          'Rete non supportata su questa piattaforma');
}
