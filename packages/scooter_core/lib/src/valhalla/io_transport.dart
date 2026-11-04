import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'valhalla_routing_provider.dart';

/// Implementazione [HttpTransport] basata su dart:io (Android, desktop, test).
class IoHttpTransport implements HttpTransport {
  final HttpClient _client;
  IoHttpTransport([HttpClient? client]) : _client = client ?? HttpClient();

  @override
  Future<HttpReply> postJson(Uri url, String body, {Duration? timeout}) async {
    final t = timeout ?? const Duration(seconds: 15);
    try {
      final req = await _client.postUrl(url).timeout(t);
      req.headers.contentType = ContentType.json;
      req.write(body);
      final res = await req.close().timeout(t);
      final text = await res.transform(utf8.decoder).join().timeout(t);
      return HttpReply(res.statusCode, text);
    } on TimeoutException {
      throw const TransportException('Timeout', timeout: true);
    } on SocketException catch (e) {
      // Errori DNS/rete assente vs server che rifiuta la connessione.
      final noNet = e.osError?.errorCode == 101 || // ENETUNREACH
          e.message.contains('Failed host lookup');
      throw TransportException(e.message, noConnection: noNet);
    } on HttpException catch (e) {
      throw TransportException(e.message);
    }
  }

  void close() => _client.close(force: true);
}
