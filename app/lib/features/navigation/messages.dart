import 'package:scooter_core/scooter_core.dart';

/// Messaggi per l'utente, uno per ogni tipo di errore di routing.
String routingErrorMessage(RoutingError e) => switch (e.kind) {
      RoutingErrorKind.noConnection =>
        'Connessione assente. Controlla la rete e riprova.',
      RoutingErrorKind.serverUnreachable =>
        e.message.contains('non configurato')
            ? e.message
            : 'Server di calcolo percorso non raggiungibile.',
      RoutingErrorKind.timeout =>
        'Il server non ha risposto in tempo. Riprova.',
      RoutingErrorKind.noRoute =>
        'Nessun percorso consentito al tuo veicolo verso questa destinazione.',
      RoutingErrorKind.rejectedByCompliance =>
        'L\'unico percorso trovato attraversa strade vietate al tuo veicolo: '
            'nessun percorso consentito disponibile.',
      RoutingErrorKind.locationNotRoutable =>
        'Partenza o destinazione troppo lontane da una strada percorribile.',
      RoutingErrorKind.invalidResponse =>
        'Risposta non valida dal server di calcolo percorso.',
      RoutingErrorKind.profileNotSupported =>
        'Profilo veicolo non ancora supportato.',
    };
