import 'dart:typed_data';

import 'package:geo_core/geo_core.dart';
import 'package:test/test.dart';

void main() {
  group('SRTM bilinear', () {
    test('menginterpolasi empat sudut tile', () {
      final bytes = ByteData(8);
      bytes.setInt16(0, 100, Endian.big);
      bytes.setInt16(2, 200, Endian.big);
      bytes.setInt16(4, 300, Endian.big);
      bytes.setInt16(6, 400, Endian.big);
      final raster = SrtmElevationRaster(
        southLatitude: -1,
        westLongitude: 100,
        size: 2,
        bytes: bytes,
      );

      expect(raster.elevationAt(-1.0, 100.0), 300);
      expect(raster.elevationAt(-0.5, 100.5), closeTo(250, 0.001));
      expect(raster.elevationAt(-1.5, 100.5), isNull);
    });

    test('mengembalikan null untuk nilai void dan luar tile', () {
      final bytes = ByteData(8)
        ..setInt16(0, -32768, Endian.big)
        ..setInt16(2, 200, Endian.big)
        ..setInt16(4, 300, Endian.big)
        ..setInt16(6, 400, Endian.big);
      final raster = SrtmElevationRaster(
        southLatitude: -1,
        westLongitude: 100,
        size: 2,
        bytes: bytes,
      );

      expect(raster.elevationAt(-1.0, 100.0), isNull);
      expect(raster.elevationAt(1.0, 100.0), isNull);
    });
  });

  group('Elevasi profil', () {
    test('histeresis 3 m menghitung naik dan turun', () {
      final route = Route(
        null,
        [
          [
            const GeoPoint(0, 0),
            const GeoPoint(0, 0.0009),
          ],
        ],
      );
      final profile = ElevationProfileBuilder.build(
        route: route,
        elevationProvider: _LatLonElevationProvider(),
      );

      expect(profile, isNotNull);
      expect(profile!.minimumElevationMeters, greaterThanOrEqualTo(101));
      expect(profile.maximumElevationMeters, greaterThanOrEqualTo(104));
      expect(profile.totalAscentMeters, closeTo(4, 0.001));
      expect(profile.totalDescentMeters, closeTo(3, 0.001));
      expect(profile.segments, isNotEmpty);
    });
  });
}

class _LatLonElevationProvider implements ElevationProvider {
  @override
  double? elevationAt(double latitude, double longitude) {
    if (longitude == 0) return 100;
    if (longitude < 0.00035) return 102;
    if (longitude < 0.00075) return 104;
    return 101;
  }
}
