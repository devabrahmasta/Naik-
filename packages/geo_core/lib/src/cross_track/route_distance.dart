import '../geo_point.dart';
import '../gpx.dart';
import '../models/local_point.dart';
import '../projection/local_plane.dart';
import 'off_route_detector.dart';

/// Hasil jarak dari posisi pengguna ke rute.
class RouteDistance {
  final double meters; // Jarak terdekat ke rute (meter)
  final GeoPoint nearest; // Titik terdekat di rute (lat/lon)
  final double bearing; // Arah dari posisi ke titik terdekat (derajat 0-360)

  const RouteDistance(this.meters, this.nearest, this.bearing);
}

/// Menyambung [Route] hasil GPX (US-05) ke L2 dan [CrossTrack].
class RouteDistanceCalculator {
  final LocalPlane _plane;
  final List<List<LocalPoint>> _segments = [];

  /// Titik acuan proyeksi = titik pertama rute.
  RouteDistanceCalculator(Route route)
    : _plane = LocalPlane(
        originLat: route.segments.first.first.lat,
        originLon: route.segments.first.first.lon,
      ) {
    // Proyeksikan titik rute sekali saja, bukan tiap ada fix baru.
    for (final segment in route.segments) {
      final points = <LocalPoint>[];
      for (final p in segment) {
        points.add(_plane.project(p.lat, p.lon));
      }
      _segments.add(points);
    }
  }

  RouteDistance distanceTo(double lat, double lon) {
    final position = _plane.project(lat, lon);

    // Cari segmen yang paling dekat. Segmen tidak disambung,
    // jadi celah di antara segmen tidak dianggap jalur.
    CrossTrackResult? best;
    for (final segment in _segments) {
      final result = CrossTrack.calculate(position, segment);
      if (best == null || result.distance < best.distance) {
        best = result;
      }
    }

    final (nearestLat, nearestLon) = _plane.unproject(best!.nearestPoint);
    return RouteDistance(
      best.distance,
      GeoPoint(nearestLat, nearestLon),
      best.bearingToNearest,
    );
  }
}
