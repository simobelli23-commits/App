import 'package:scooter_core/scooter_core.dart';
import 'package:test/test.dart';

void main() {
  group('Geo', () {
    test('haversine Modena-Bologna (centri) ~37,1 km', () {
      final d = haversineM(const LatLng(44.6471, 10.9252), const LatLng(44.4949, 11.3426));
      expect(d, closeTo(37143, 20));
    });

    test('decodifica polyline di riferimento (precisione 5)', () {
      final pts = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@', precision: 5);
      expect(pts.length, 3);
      expect(pts[0].lat, closeTo(38.5, 1e-9));
      expect(pts[0].lon, closeTo(-120.2, 1e-9));
      expect(pts[2].lat, closeTo(43.252, 1e-9));
      expect(pts[2].lon, closeTo(-126.453, 1e-9));
    });

    test('encode/decode polyline6 reversibile', () {
      const pts = [LatLng(44.645, 10.92), LatLng(44.6455, 10.9213), LatLng(44.6401, 10.9301)];
      final back = decodePolyline(encodePolyline(pts));
      for (var i = 0; i < pts.length; i++) {
        expect(back[i].lat, closeTo(pts[i].lat, 1e-6));
        expect(back[i].lon, closeTo(pts[i].lon, 1e-6));
      }
    });

    test('polyline troncata -> FormatException', () {
      expect(() => decodePolyline('_p~iF~ps|U_'), throwsFormatException);
    });

    test('proiezione su polilinea', () {
      final line = Polyline(const [LatLng(44.645, 10.92), LatLng(44.645, 10.93)]);
      expect(line.lengthM, closeTo(791.1, 1));
      final p = line.project(const LatLng(44.6452, 10.925));
      expect(p.distanceM, closeTo(22.2, 1.0));
      expect(p.alongM, closeTo(395.6, 2));
    });
  });

  group('ETA', () {
    const model = EtaModel();
    const a = VehicleProfiles.a50cc;

    test('la velocità non supera mai il 90% di 45 km/h', () {
      const s = EtaSegment(lengthM: 1000, roadClass: 'primary', urban: false);
      expect(model.segmentSpeedKmh(s, a), closeTo(40.5, 1e-9));
    });

    test('il limite legale prevale se più basso', () {
      const s = EtaSegment(lengthM: 1000, roadClass: 'primary', speedLimitKmh: 30, urban: false);
      expect(model.segmentSpeedKmh(s, a), 30);
    });

    test('strada residenziale: velocità tipica 25 km/h', () {
      const s = EtaSegment(lengthM: 1000, roadClass: 'residential');
      expect(model.segmentSpeedKmh(s, a), 25);
    });

    test('ETA include manovre e penalità urbana', () {
      final eta = model.estimate(
        const [
          EtaSegment(lengthM: 1000, roadClass: 'residential'), // 144 s + 20 s
          EtaSegment(lengthM: 2025, roadClass: 'secondary', urban: false), // 40.5 km/h -> 180 s
        ],
        const [ManeuverKind.turn, ManeuverKind.roundabout, ManeuverKind.straight],
        a,
      );
      expect(eta.drivingSeconds, closeTo(144 + 180, 1e-6));
      expect(eta.urbanSeconds, closeTo(20, 1e-9));
      expect(eta.maneuverSeconds, 14);
      expect(eta.totalSeconds, closeTo(358, 1e-6));
    });

    test('ETA residuo proporzionale e limitato', () {
      expect(EtaModel.remainingSeconds(totalSeconds: 600, totalM: 6000, remainingM: 3000), 300);
      expect(EtaModel.remainingSeconds(totalSeconds: 600, totalM: 6000, remainingM: 9000), 600);
      expect(EtaModel.remainingSeconds(totalSeconds: 600, totalM: 0, remainingM: 10), 0);
    });
  });
}
