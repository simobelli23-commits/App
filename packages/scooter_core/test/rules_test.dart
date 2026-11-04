import 'package:scooter_core/scooter_core.dart';
import 'package:test/test.dart';

void main() {
  const rules = OsmAccessRules(VehicleProfiles.a50cc);
  Legality acc(Map<String, String> t) => rules.evaluateAccess(t).legality;

  group('Profilo A - divieti per classe (art. 175)', () {
    test('autostrada e svincoli vietati, anche con moped=yes errato', () {
      expect(acc({'highway': 'motorway'}), Legality.forbidden);
      expect(acc({'highway': 'motorway_link'}), Legality.forbidden);
      expect(acc({'highway': 'motorway', 'moped': 'yes'}), Legality.forbidden);
    });

    test('extraurbana principale (motorroad=yes) vietata su qualunque classe', () {
      expect(acc({'highway': 'trunk', 'motorroad': 'yes'}), Legality.forbidden);
      expect(acc({'highway': 'primary', 'motorroad': 'yes'}), Legality.forbidden);
    });

    test('trunk senza motorroad: escluso in modalità prudente, incerto altrimenti', () {
      expect(acc({'highway': 'trunk'}), Legality.forbidden);
      const permissive =
          OsmAccessRules(VehicleProfiles.a50cc, trunkPolicy: TrunkPolicy.permissive);
      expect(permissive.evaluateAccess({'highway': 'trunk'}).legality, Legality.uncertain);
    });

    test('il divieto cita la fonte normativa', () {
      final v = rules.evaluateAccess({'highway': 'motorway'});
      expect(v.legalRef?.id, 'CdS-175-2');
      expect(v.isHardBlock, isTrue);
    });
  });

  group('Profilo A - strade ordinarie', () {
    test('strade urbane ed extraurbane secondarie consentite', () {
      for (final hw in ['primary', 'secondary', 'tertiary', 'residential',
          'unclassified', 'living_street', 'service']) {
        expect(acc({'highway': hw}), Legality.allowed, reason: hw);
      }
    });

    test('non-strade e cantieri vietati', () {
      expect(acc({}), Legality.forbidden);
      expect(acc({'highway': 'construction'}), Legality.forbidden);
      expect(acc({'highway': 'proposed'}), Legality.forbidden);
    });
  });

  group('Profilo A - percorsi pedonali e ciclabili', () {
    test('vietati di default', () {
      for (final hw in ['footway', 'pedestrian', 'cycleway', 'path', 'steps', 'bridleway']) {
        expect(acc({'highway': hw}), Legality.forbidden, reason: hw);
      }
    });

    test('consentiti solo con autorizzazione esplicita', () {
      expect(acc({'highway': 'cycleway', 'moped': 'yes'}), Legality.allowed);
      expect(acc({'highway': 'pedestrian', 'motor_vehicle': 'yes'}), Legality.allowed);
      expect(acc({'highway': 'cycleway', 'bicycle': 'designated'}), Legality.forbidden);
    });
  });

  group('Profilo A - gerarchia di accesso', () {
    test('moped prevale su motor_vehicle e access', () {
      expect(acc({'highway': 'residential', 'motor_vehicle': 'no', 'moped': 'yes'}),
          Legality.allowed);
      expect(acc({'highway': 'residential', 'moped': 'no'}), Legality.forbidden);
      expect(acc({'highway': 'residential', 'access': 'no'}), Legality.forbidden);
      expect(acc({'highway': 'residential', 'access': 'no', 'motor_vehicle': 'yes'}),
          Legality.allowed);
    });

    test('accessi privati e destinazione: solo come destinazione', () {
      expect(acc({'highway': 'service', 'access': 'private'}), Legality.destinationOnly);
      expect(acc({'highway': 'residential', 'motor_vehicle': 'destination'}),
          Legality.destinationOnly);
    });

    test('agricolo/forestale vietato, valori sconosciuti incerti', () {
      expect(acc({'highway': 'track', 'motor_vehicle': 'agricultural'}), Legality.forbidden);
      expect(acc({'highway': 'residential', 'access': 'boh'}), Legality.uncertain);
      expect(acc({'highway': 'track'}), Legality.uncertain);
    });

    test('valori multipli: prevale il più restrittivo', () {
      expect(acc({'highway': 'service', 'access': 'yes;no'}), Legality.forbidden);
    });

    test('restrizioni condizionali (ZTL/orari) rendono il tratto incerto', () {
      expect(acc({'highway': 'residential', 'motor_vehicle:conditional': 'no @ (08:00-20:00)'}),
          Legality.uncertain);
    });
  });

  group('Sensi unici', () {
    DirectionAccess dir(Map<String, String> t) => rules.evaluateDirection(t);

    test('oneway=yes / -1 / no', () {
      expect(dir({'oneway': 'yes'}).backward, isFalse);
      expect(dir({'oneway': 'yes'}).forward, isTrue);
      expect(dir({'oneway': '-1'}).forward, isFalse);
      expect(dir({'oneway': 'no'}).backward, isTrue);
    });

    test('rotatoria implica senso unico', () {
      final d = dir({'highway': 'primary', 'junction': 'roundabout'});
      expect(d.forward, isTrue);
      expect(d.backward, isFalse);
    });

    test('"eccetto bici" NON vale per i ciclomotori', () {
      final d = dir({'oneway': 'yes', 'oneway:bicycle': 'no'});
      expect(d.backward, isFalse);
    });

    test('oneway:moped prevale', () {
      expect(dir({'oneway': 'yes', 'oneway:moped': 'no'}).backward, isTrue);
    });

    test('alternato: incerto', () {
      expect(dir({'oneway': 'alternating'}).uncertain, isTrue);
    });
  });

  group('Restrizioni di svolta', () {
    const ev = TurnRestrictionEvaluator(VehicleProfiles.a50cc);

    test('no_left_turn vieta solo la manovra indicata', () {
      final r = [
        const TurnRestriction(fromWay: 1, viaNode: 10, toWay: 2,
            tags: {'type': 'restriction', 'restriction': 'no_left_turn'})
      ];
      expect(ev.decide(1, 10, 2, r), TurnDecision.forbidden);
      expect(ev.decide(1, 10, 3, r), TurnDecision.allowed);
      expect(ev.decide(4, 10, 2, r), TurnDecision.allowed);
    });

    test('only_straight_on vieta tutte le altre uscite', () {
      final r = [
        const TurnRestriction(fromWay: 1, viaNode: 10, toWay: 2,
            tags: {'restriction': 'only_straight_on'})
      ];
      expect(ev.decide(1, 10, 2, r), TurnDecision.allowed);
      expect(ev.decide(1, 10, 3, r), TurnDecision.forbidden);
    });

    test('except=bicycle non esenta il ciclomotore; except=moped sì', () {
      final bike = [
        const TurnRestriction(fromWay: 1, viaNode: 10, toWay: 2,
            tags: {'restriction': 'no_right_turn', 'except': 'bicycle'})
      ];
      final moped = [
        const TurnRestriction(fromWay: 1, viaNode: 10, toWay: 2,
            tags: {'restriction': 'no_right_turn', 'except': 'bicycle;moped'})
      ];
      expect(ev.decide(1, 10, 2, bike), TurnDecision.forbidden);
      expect(ev.decide(1, 10, 2, moped), TurnDecision.allowed);
    });

    test('restriction:moped prevale', () {
      final r = [
        const TurnRestriction(fromWay: 1, viaNode: 10, toWay: 2,
            tags: {'restriction:moped': 'no_u_turn'})
      ];
      expect(ev.decide(1, 10, 2, r), TurnDecision.forbidden);
    });
  });

  group('Validatore di conformità del percorso', () {
    const v = RouteComplianceValidator(VehicleProfiles.a50cc);
    RouteEdge e(String rc, [String use = 'road']) =>
        RouteEdge(roadClass: rc, use: use, lengthKm: 0.1, wayId: 1);

    test('percorso solo urbano: nessuna violazione', () {
      final r = v.validate([e('residential'), e('tertiary'), e('secondary')]);
      expect(r.status, ComplianceStatus.noViolationsFound);
      expect(r.mustReject, isFalse);
    });

    test('un solo arco autostradale fa rifiutare il percorso', () {
      final r = v.validate([e('residential'), e('motorway', 'ramp'), e('primary')]);
      expect(r.mustReject, isTrue);
    });

    test('trunk e ciclabili rifiutati', () {
      expect(v.validate([e('trunk')]).mustReject, isTrue);
      expect(v.validate([e('service_other', 'cycleway')]).mustReject, isTrue);
      expect(v.validate([e('service_other', 'footway')]).mustReject, isTrue);
    });

    test('strada sterrata: incerto ma non rifiutato', () {
      final r = v.validate([e('service_other', 'track')]);
      expect(r.status, ComplianceStatus.uncertain);
    });

    test('profili non validati non sono mai dichiarati conformi', () {
      const v2 = RouteComplianceValidator(VehicleProfiles.b125Adult);
      expect(v2.validate([e('residential')]).status, ComplianceStatus.uncertain);
    });
  });

  test('profili non ancora implementati: regole incerte', () {
    const b = OsmAccessRules(VehicleProfiles.b125Adult);
    expect(b.evaluateAccess({'highway': 'motorway'}).legality, Legality.uncertain);
  });
}
