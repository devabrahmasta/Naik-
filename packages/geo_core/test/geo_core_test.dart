import 'package:geo_core/geo_core.dart';
import 'package:test/test.dart';

void main() {
  group('L1: Fix Gating', () {
    test('menerima fix normal dengan akurasi baik', () {
      final gating = FixGating(aMax: 30.0, vMax: 5.0);
      final fix = GnssFix(
        latitude: -7.4532,
        longitude: 110.4385,
        altitude: 2800.0,
        accuracy: 8.5,
        speed: 1.2,
        bearing: 45.0,
        satellitesUsed: 9,
        timestamp: DateTime.now(),
      );

      final res = gating.evaluate(fix);
      expect(res.isAccepted, isTrue);
    });

    test('menolak fix dengan akurasi buruk (> A_max)', () {
      final gating = FixGating(aMax: 30.0, vMax: 5.0);
      final fix = GnssFix(
        latitude: -7.4532,
        longitude: 110.4385,
        altitude: 2800.0,
        accuracy: 45.0,
        speed: 1.2,
        bearing: 45.0,
        satellitesUsed: 3,
        timestamp: DateTime.now(),
      );

      final res = gating.evaluate(fix);
      expect(res.isAccepted, isFalse);
      expect(res.status, equals(GatingStatus.rejectedAccuracy));
    });

    test('menolak lokasi mock', () {
      final gating = FixGating();
      final fix = GnssFix(
        latitude: -7.4532,
        longitude: 110.4385,
        altitude: 2800.0,
        accuracy: 5.0,
        speed: 1.0,
        bearing: 0.0,
        satellitesUsed: 10,
        timestamp: DateTime.now(),
        isMock: true,
      );

      final res = gating.evaluate(fix);
      expect(res.isAccepted, isFalse);
      expect(res.status, equals(GatingStatus.rejectedMock));
    });
  });

  group('L2: Local Plane Projection', () {
    test('proyeksi titik acuan bernilai (0, 0)', () {
      final plane = LocalPlane(originLat: -7.45, originLon: 110.43);
      final p = plane.project(-7.45, 110.43);
      expect(p.x, closeTo(0.0, 0.001));
      expect(p.y, closeTo(0.0, 0.001));
    });

    test('proyeksi bolak-balik (project -> unproject) konsisten', () {
      final plane = LocalPlane(originLat: -7.45, originLon: 110.43);
      final p = plane.project(-7.455, 110.435);
      final (lat, lon) = plane.unproject(p);
      expect(lat, closeTo(-7.455, 0.00001));
      expect(lon, closeTo(110.435, 0.00001));
    });
  });

  group('L3: Cross Track & Off-Route Detection', () {
    test('menghitung jarak cross-track ke garis lurus', () {
      final route = [const LocalPoint(0, 0), const LocalPoint(0, 100)];
      final user = const LocalPoint(20, 50);

      final res = CrossTrack.calculate(user, route);
      expect(res.distance, closeTo(20.0, 0.01));
      expect(res.nearestPoint.x, closeTo(0.0, 0.01));
      expect(res.nearestPoint.y, closeTo(50.0, 0.01));
    });

    test('mendeteksi keluar jalur adaptif dengan durasi dan fix berurutan', () {
      final detector = OffRouteDetector(
        tMin: 30.0,
        k: 2.0,
        minConsecutiveFixes: 5,
        minDuration: const Duration(seconds: 15),
      );

      final t0 = DateTime(2026, 11, 23, 8, 0, 0);

      // 4 fix awal di luar jalur (belum >= 5 fix dan belum >= 15 dtk) -> tetap false
      for (int i = 0; i < 4; i++) {
        final off = detector.update(
          crossTrackDistance: 40.0,
          accuracy: 5.0, // threshold = max(30, 10) = 30m
          timestamp: t0.add(Duration(seconds: i * 3)),
        );
        expect(off, isFalse);
      }

      // Fix ke-5 pada detik ke-15 -> sekarang true (keluar jalur)
      final off5 = detector.update(
        crossTrackDistance: 40.0,
        accuracy: 5.0,
        timestamp: t0.add(const Duration(seconds: 15)),
      );
      expect(off5, isTrue);

      // Pemulihan kembali ke jalur: butuh d < 0.7 * 30 (21m) pada 3 fix
      detector.update(crossTrackDistance: 15.0, accuracy: 5.0, timestamp: t0.add(const Duration(seconds: 18)));
      detector.update(crossTrackDistance: 15.0, accuracy: 5.0, timestamp: t0.add(const Duration(seconds: 20)));
      expect(detector.isOffRoute, isTrue); // baru 2 fix

      detector.update(crossTrackDistance: 15.0, accuracy: 5.0, timestamp: t0.add(const Duration(seconds: 22)));
      expect(detector.isOffRoute, isFalse); // fix ke-3 berhasil kembali ke jalur
    });
  });

  group('L4: Tobler ETA', () {
    test('kecepatan datar mendekati 5 km/jam', () {
      final speed = ToblerEta.speedKmh(0.0);
      expect(speed, closeTo(5.03, 0.1));
    });

    test('kecepatan menurun tajam saat tanjakan curam', () {
      final flatSpeed = ToblerEta.speedKmh(0.0);
      final steepSpeed = ToblerEta.speedKmh(0.3); // kemiringan 30%
      expect(steepSpeed, lessThan(flatSpeed));
      expect(steepSpeed, greaterThan(0.0));
    });
  });
}
