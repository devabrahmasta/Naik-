import 'dart:math' as math;

import 'package:geo_core/geo_core.dart';
import 'package:test/test.dart';

/// Jarak Haversine (meter), hanya untuk membandingkan hasil L2 di tes.
double haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Mengubah meter ke arah timur menjadi selisih bujur (derajat) di lintang [lat].
double metersToLon(double meters, double lat) {
  return meters / (6371000.0 * math.pi / 180 * math.cos(lat * math.pi / 180));
}

void main() {
  // Rute lurus utara-selatan di bujur 110.43, panjang sekitar 1,1 km.
  final straightRoute = Route('Lurus', [
    [GeoPoint(-7.450, 110.43), GeoPoint(-7.440, 110.43)],
  ]);

  test('posisi tepat di atas rute berjarak 0 m', () {
    final calc = RouteDistanceCalculator(straightRoute);
    final result = calc.distanceTo(-7.445, 110.43);
    expect(result.meters, closeTo(0, 0.01));
  });

  test('posisi 50 m di timur rute: jarak 50 m, arah ke barat', () {
    final calc = RouteDistanceCalculator(straightRoute);
    final lon = 110.43 + metersToLon(50, -7.445);
    final result = calc.distanceTo(-7.445, lon);

    expect(result.meters, closeTo(50, 0.5));
    expect(result.bearing, closeTo(270, 0.5)); // 270 derajat = barat
    expect(result.nearest.lat, closeTo(-7.445, 0.00001));
    expect(result.nearest.lon, closeTo(110.43, 0.00001));
  });

  test('memilih segmen yang paling dekat', () {
    // Segmen kedua ada sekitar 1,1 km di timur segmen pertama.
    final route = Route('Dua segmen', [
      [GeoPoint(-7.450, 110.43), GeoPoint(-7.445, 110.43)],
      [GeoPoint(-7.450, 110.44), GeoPoint(-7.445, 110.44)],
    ]);
    final calc = RouteDistanceCalculator(route);
    final result = calc.distanceTo(-7.447, 110.4398);

    expect(result.nearest.lon, closeTo(110.44, 0.00001));
    expect(result.meters, lessThan(30));
  });

  test('celah di antara dua segmen tidak dianggap jalur', () {
    // Segmen 1 berakhir di -7.445, segmen 2 mulai di -7.440 (celah sekitar 556 m).
    final route = Route('Bercelah', [
      [GeoPoint(-7.450, 110.43), GeoPoint(-7.445, 110.43)],
      [GeoPoint(-7.440, 110.43), GeoPoint(-7.435, 110.43)],
    ]);
    final calc = RouteDistanceCalculator(route);
    final result = calc.distanceTo(-7.4425, 110.43); // tengah celah

    // Kalau segmen disambung, jaraknya akan 0. Yang benar: setengah celah.
    expect(result.meters, closeTo(278, 1));
  });

  test('L2 (bidang lokal) hampir sama dengan Haversine untuk jarak 3 km', () {
    final plane = LocalPlane(originLat: -7.45, originLon: 110.43);
    final a = plane.project(-7.45, 110.43);
    final b = plane.project(-7.43, 110.45);

    final planeMeters = LocalPlane.distance(a, b);
    final haversineMeters = haversine(-7.45, 110.43, -7.43, 110.45);

    expect(haversineMeters, greaterThan(3000));
    expect((planeMeters - haversineMeters).abs(), lessThan(1));
  });
}
