import 'package:geo_core/geo_core.dart';
import 'package:test/test.dart';

void main() {
  group('US-01: SatelliteInfo & GnssStatusSnapshot', () {
    test('memetakan tipe konstelasi Android ke enum GnssConstellation', () {
      expect(GnssConstellation.fromAndroidType(1), equals(GnssConstellation.gps));
      expect(GnssConstellation.fromAndroidType(3), equals(GnssConstellation.glonass));
      expect(GnssConstellation.fromAndroidType(4), equals(GnssConstellation.qzss));
      expect(GnssConstellation.fromAndroidType(5), equals(GnssConstellation.beidou));
      expect(GnssConstellation.fromAndroidType(6), equals(GnssConstellation.galileo));
      expect(GnssConstellation.fromAndroidType(99), equals(GnssConstellation.unknown));
    });

    test('serialisasi toMap dan fromMap mempertahankan seluruh nilai satelit', () {
      final original = GnssStatusSnapshot(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1732334400000),
        satellites: const [
          SatelliteInfo(
            svid: 12,
            constellation: GnssConstellation.gps,
            cn0DbHz: 34.5,
            azimuthDegrees: 120.0,
            elevationDegrees: 45.0,
            usedInFix: true,
            hasAlmanac: true,
            hasEphemeris: true,
          ),
          SatelliteInfo(
            svid: 8,
            constellation: GnssConstellation.galileo,
            cn0DbHz: 22.0,
            azimuthDegrees: 280.0,
            elevationDegrees: 18.0,
            usedInFix: false,
          ),
        ],
      );

      final map = original.toMap();
      final decoded = GnssStatusSnapshot.fromMap(map);

      expect(decoded.visibleCount, equals(2));
      expect(decoded.usedCount, equals(1));
      expect(decoded.satellites.first.displayId, equals('G12'));
      expect(decoded.satellites.last.displayId, equals('E8'));
      expect(decoded.satellites.first.cn0DbHz, closeTo(34.5, 0.001));
      expect(decoded.averageCn0Used, closeTo(34.5, 0.001));
      expect(decoded.averageCn0Visible, closeTo(28.25, 0.001));
      expect(decoded.constellationCounts[GnssConstellation.gps], equals(1));
      expect(decoded.constellationCounts[GnssConstellation.galileo], equals(1));
    });

    test('fromMap mendukung konstelasi berupa integer Android langsung', () {
      final decoded = SatelliteInfo.fromMap({
        'svid': 24,
        'constellation': 5, // BeiDou
        'cn0DbHz': 31.0,
        'azimuthDegrees': 65.0,
        'elevationDegrees': 72.0,
        'usedInFix': true,
      });

      expect(decoded.constellation, equals(GnssConstellation.beidou));
      expect(decoded.displayId, equals('C24'));
    });

    test('averageCn0Used bernilai null bila belum ada satelit terpakai', () {
      final snapshot = GnssStatusSnapshot(
        timestamp: DateTime.now(),
        satellites: const [
          SatelliteInfo(
            svid: 3,
            constellation: GnssConstellation.gps,
            cn0DbHz: 18.0,
            azimuthDegrees: 40.0,
            elevationDegrees: 12.0,
            usedInFix: false,
          ),
        ],
      );

      expect(snapshot.usedCount, equals(0));
      expect(snapshot.averageCn0Used, isNull);
      expect(snapshot.averageCn0Visible, closeTo(18.0, 0.001));
    });
  });
}
