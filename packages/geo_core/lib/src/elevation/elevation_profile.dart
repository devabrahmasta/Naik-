import 'dart:math' as math;

import '../gpx.dart';
import '../geo_point.dart';
import '../eta/tobler_eta.dart';
import 'srtm_elevation.dart';

class ElevationProfilePoint {
  final double distanceFromStartMeters;
  final double latitude;
  final double longitude;
  final double elevationMeters;

  const ElevationProfilePoint({
    required this.distanceFromStartMeters,
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
  });
}

class ElevationSegment {
  final double startMeters;
  final double endMeters;
  final double elevationDeltaMeters;
  final double travelTimeSeconds;

  const ElevationSegment({
    required this.startMeters,
    required this.endMeters,
    required this.elevationDeltaMeters,
    required this.travelTimeSeconds,
  });

  double get distanceMeters => endMeters - startMeters;
}

class ElevationProfile {
  final double totalDistanceMeters;
  final double totalAscentMeters;
  final double totalDescentMeters;
  final double minimumElevationMeters;
  final double maximumElevationMeters;
  final double estimatedTimeSeconds;
  final List<ElevationProfilePoint> points;
  final List<ElevationSegment> segments;
  final bool dataComplete;

  const ElevationProfile({
    required this.totalDistanceMeters,
    required this.totalAscentMeters,
    required this.totalDescentMeters,
    required this.minimumElevationMeters,
    required this.maximumElevationMeters,
    required this.estimatedTimeSeconds,
    required this.points,
    required this.segments,
    required this.dataComplete,
  });
}

class ElevationProfileBuilder {
  static const double routeSampleMeters = 30.0;
  static const double ascentDescentHysteresisMeters = 3.0;

  static double distanceMeters(GeoPoint a, GeoPoint b) {
    const earthRadius = 6371000.0;
    final lat1 = a.lat * math.pi / 180.0;
    final lat2 = b.lat * math.pi / 180.0;
    final dLat = (b.lat - a.lat) * math.pi / 180.0;
    final dLon = (b.lon - a.lon) * math.pi / 180.0;
    final hav = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(hav), math.sqrt(1 - hav));
  }

  static ElevationProfile? build({
    required Route route,
    required ElevationProvider elevationProvider,
  }) {
    final sampled = _sampleRoute(route);
    if (sampled.isEmpty) return null;

    final profilePoints = <ElevationProfilePoint>[];
    var complete = true;
    var cumulativeDistance = 0.0;

    for (var i = 0; i < sampled.length; i++) {
      final point = sampled[i];
      final elevation = elevationProvider.elevationAt(point.lat, point.lon);
      if (elevation == null) {
        complete = false;
        continue;
      }
      if (profilePoints.isNotEmpty) {
        cumulativeDistance += distanceMeters(
          GeoPoint(
            profilePoints.last.latitude,
            profilePoints.last.longitude,
          ),
          point,
        );
      }
      profilePoints.add(
        ElevationProfilePoint(
          distanceFromStartMeters: cumulativeDistance,
          latitude: point.lat,
          longitude: point.lon,
          elevationMeters: elevation,
        ),
      );
    }

    if (profilePoints.isEmpty) return null;

    var minimum = profilePoints.first.elevationMeters;
    var maximum = minimum;
    var ascent = 0.0;
    var descent = 0.0;
    var baseline = profilePoints.first.elevationMeters;
    var totalDistance = 0.0;
    var estimatedTime = 0.0;
    final segments = <ElevationSegment>[];

    for (var i = 1; i < profilePoints.length; i++) {
      final previous = profilePoints[i - 1];
      final current = profilePoints[i];
      final distance = distanceMeters(
        GeoPoint(previous.latitude, previous.longitude),
        GeoPoint(current.latitude, current.longitude),
      );
      final delta = current.elevationMeters - previous.elevationMeters;

      totalDistance += distance;
      minimum = math.min(minimum, current.elevationMeters);
      maximum = math.max(maximum, current.elevationMeters);

      final elapsed = ToblerEta.travelTimeSeconds(
        distanceMeters: distance,
        elevationDeltaMeters: delta,
      );
      estimatedTime += elapsed.isFinite ? elapsed : 0.0;
      segments.add(
        ElevationSegment(
          startMeters: previous.distanceFromStartMeters,
          endMeters: current.distanceFromStartMeters,
          elevationDeltaMeters: delta,
          travelTimeSeconds: elapsed,
        ),
      );

      final trendDelta = current.elevationMeters - baseline;
      if (trendDelta >= ascentDescentHysteresisMeters) {
        ascent += trendDelta;
        baseline = current.elevationMeters;
      } else if (trendDelta <= -ascentDescentHysteresisMeters) {
        descent += -trendDelta;
        baseline = current.elevationMeters;
      }
    }

    return ElevationProfile(
      totalDistanceMeters: totalDistance,
      totalAscentMeters: ascent,
      totalDescentMeters: descent,
      minimumElevationMeters: minimum,
      maximumElevationMeters: maximum,
      estimatedTimeSeconds: estimatedTime,
      points: profilePoints,
      segments: segments,
      dataComplete: complete,
    );
  }

  static List<GeoPoint> _sampleRoute(Route route) {
    final result = <GeoPoint>[];
    var distanceToNextSample = routeSampleMeters;

    for (final segment in route.segments) {
      if (segment.isEmpty) continue;
      for (var i = 0; i < segment.length - 1; i++) {
        final start = segment[i];
        final end = segment[i + 1];
        final distance = distanceMeters(start, end);
        if (distance <= 0) continue;

        if (result.isEmpty) {
          result.add(start);
        }

        var position = 0.0;
        while (position + distanceToNextSample <= distance) {
          final fraction = (position + distanceToNextSample) / distance;
          result.add(
            GeoPoint(
              start.lat + (end.lat - start.lat) * fraction,
              start.lon + (end.lon - start.lon) * fraction,
            ),
          );
          position += distanceToNextSample;
          distanceToNextSample = routeSampleMeters;
        }
        distanceToNextSample -= distance - position;
        if (distanceToNextSample < 0) distanceToNextSample = 0;
      }
    }

    return result;
  }
}
