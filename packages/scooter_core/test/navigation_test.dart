import 'package:scooter_core/scooter_core.dart';
import 'package:test/test.dart';

/// Percorso a L: 791 m verso est, poi 1112 m verso nord.
RouteResult lRoute() => const RouteResult(
      shape: [LatLng(44.6450, 10.9200), LatLng(44.6450, 10.9300), LatLng(44.6550, 10.9300)],
      maneuvers: [
        Maneuver(type: 1, instruction: 'Parti verso est', lengthM: 791, timeS: 70,
            beginShapeIndex: 0, endShapeIndex: 1),
        Maneuver(type: 15, instruction: 'Svolta a sinistra', lengthM: 1112, timeS: 100,
            beginShapeIndex: 1, endShapeIndex: 2),
        Maneuver(type: 4, instruction: 'Sei arrivato', lengthM: 0, timeS: 0,
            beginShapeIndex: 2, endShapeIndex: 2),
      ],
      lengthM: 1903,
      engineTimeS: 170,
    );

LocationFix fix(double lat, double lon, int sec, {double acc = 5}) => LocationFix(
    position: LatLng(lat, lon),
    accuracyM: acc,
    timestamp: DateTime.utc(2026, 1, 1, 12, 0, sec));

void main() {
  test('sul percorso: distanza alla prossima manovra e residuo', () {
    final s = NavigationSession(lRoute());
    final snap = s.update(fix(44.6450, 10.9250, 0));
    expect(snap.status, NavStatus.onRoute);
    expect(snap.maneuverIndex, 1);
    expect(snap.distanceToManeuverM, closeTo(395.6, 3));
    expect(snap.remainingM, closeTo(395.6 + 1112, 4));
    expect(snap.remainingS, closeTo(170 * (395.6 + 1112) / 1903.1, 1));
  });

  test('fuori percorso solo dopo fix consecutivi, con richiesta di ricalcolo', () {
    final s = NavigationSession(lRoute());
    s.update(fix(44.6450, 10.9220, 0));
    final a = s.update(fix(44.6440, 10.9240, 1)); // ~111 m a sud
    expect(a.status, NavStatus.offRouteSuspected);
    expect(a.shouldReroute, isFalse);
    s.update(fix(44.6439, 10.9242, 2));
    final c = s.update(fix(44.6438, 10.9244, 3));
    expect(c.status, NavStatus.offRoute);
    expect(c.shouldReroute, isTrue);
    final d = s.update(fix(44.6437, 10.9246, 4));
    expect(d.shouldReroute, isFalse, reason: 'ricalcolo limitato nel tempo');
  });

  test('fix con accuratezza scarsa non causano falsi fuori-percorso', () {
    final s = NavigationSession(lRoute());
    for (var i = 0; i < 5; i++) {
      final snap = s.update(fix(44.6440, 10.9240, i, acc: 120));
      expect(snap.status, NavStatus.onRoute);
    }
  });

  test('ritorno sul percorso azzera il conteggio', () {
    final s = NavigationSession(lRoute());
    s.update(fix(44.6440, 10.9240, 0));
    s.update(fix(44.6440, 10.9241, 1));
    expect(s.update(fix(44.6450, 10.9243, 2)).status, NavStatus.onRoute);
    expect(s.update(fix(44.6440, 10.9245, 3)).status, NavStatus.offRouteSuspected);
  });

  test('perdita del segnale GPS', () {
    final s = NavigationSession(lRoute());
    s.update(fix(44.6450, 10.9250, 0));
    expect(s.tick(DateTime.utc(2026, 1, 1, 12, 0, 5))!.status, NavStatus.onRoute);
    expect(s.tick(DateTime.utc(2026, 1, 1, 12, 0, 11))!.status, NavStatus.gpsLost);
  });

  test('arrivo a destinazione', () {
    final s = NavigationSession(lRoute());
    s.update(fix(44.6450, 10.9280, 0));
    s.update(fix(44.6500, 10.9300, 30));
    expect(s.update(fix(44.6549, 10.9300, 60)).status, NavStatus.arrived);
  });
}
