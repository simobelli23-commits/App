import 'package:scooter_core/scooter_core.dart';

import '../app/app_config.dart';
import 'transport.dart';

/// Crea il provider di routing dalla configurazione di build. Se ROUTING_URL
/// non è impostato, ogni richiesta fallisce in modo esplicito (nessun
/// percorso simulato).
RoutingProvider createRoutingProvider({String url = AppConfig.routingUrl}) {
  final uri = Uri.tryParse(url);
  if (url.isEmpty || uri == null || !uri.hasScheme) {
    return const UnconfiguredRoutingProvider();
  }
  return ValhallaRoutingProvider(
    baseUrl: url.endsWith('/') ? uri : Uri.parse('$url/'),
    http: createTransport(),
  );
}

class UnconfiguredRoutingProvider implements RoutingProvider {
  const UnconfiguredRoutingProvider();

  @override
  String get name => 'non configurato';

  @override
  Future<Result<List<RouteResult>, RoutingError>> route(
          RouteRequest request) async =>
      const Err(RoutingError(RoutingErrorKind.serverUnreachable,
          'Server di routing non configurato in questa versione dell\'app'));
}
