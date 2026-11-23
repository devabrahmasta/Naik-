import 'dart:math' as math;
import '../models/local_point.dart';

/// Logika L2 PRD: Proyeksi Bidang Lokal (Equirectangular)
/// Mengonversi lintang dan bujur (derajat) ke meter (x = Timur, y = Utara)
/// di sekitar titik acuan rute (lat0, lon0).
class LocalPlane {
  static const double earthRadius = 6371000.0; // WGS84 rata-rata (meter)

  final double originLat; // Derajat
  final double originLon; // Derajat
  final double _cosLat0;

  LocalPlane({required this.originLat, required this.originLon})
      : _cosLat0 = math.cos(originLat * math.pi / 180.0);

  /// Proyeksi derajat (lat, lon) -> meter (x, y)
  LocalPoint project(double lat, double lon) {
    final dLatRad = (lat - originLat) * math.pi / 180.0;
    final dLonRad = (lon - originLon) * math.pi / 180.0;

    final x = earthRadius * dLonRad * _cosLat0;
    final y = earthRadius * dLatRad;
    return LocalPoint(x, y);
  }

  /// Proyeksi balik meter (x, y) -> derajat (lat, lon)
  (double lat, double lon) unproject(LocalPoint point) {
    final dLatRad = point.y / earthRadius;
    final dLonRad = point.x / (earthRadius * _cosLat0);

    final lat = originLat + (dLatRad * 180.0 / math.pi);
    final lon = originLon + (dLonRad * 180.0 / math.pi);
    return (lat, lon);
  }

  /// Jarak Euclidean antara dua titik pada bidang lokal (meter)
  static double distance(LocalPoint p1, LocalPoint p2) {
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
