import 'dart:math' as math;

import '../models/local_point.dart';

class CrossTrackResult {
  final double distance; // Jarak tegak lurus terpendek ke rute (meter)
  final LocalPoint nearestPoint; // Titik terdekat pada polyline
  final double bearingToNearest; // Bearing sudut ke titik terdekat (derajat 0-360)

  const CrossTrackResult({
    required this.distance,
    required this.nearestPoint,
    required this.bearingToNearest,
  });
}

/// Menghitung jarak cross-track titik pengguna ke rute polyline 2D
class CrossTrack {
  /// Mencari titik terdekat pada segmen garis [a] -> [b] ke titik [p]
  static LocalPoint nearestPointOnSegment(LocalPoint p, LocalPoint a, LocalPoint b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared == 0) return a;

    // Proyeksi skalar parameter t
    final t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared;
    final clampedT = t.clamp(0.0, 1.0);

    return LocalPoint(a.x + clampedT * dx, a.y + clampedT * dy);
  }

  /// Menghitung jarak terdekat titik [p] ke seluruh segmen polyline [route]
  static CrossTrackResult calculate(LocalPoint p, List<LocalPoint> route) {
    if (route.isEmpty) {
      throw ArgumentError('Route polyline cannot be empty');
    }
    if (route.length == 1) {
      final dx = route.first.x - p.x;
      final dy = route.first.y - p.y;
      final d = math.sqrt(dx * dx + dy * dy);
      final bearing = (math.atan2(dx, dy) * 180.0 / math.pi + 360.0) % 360.0;
      return CrossTrackResult(
        distance: d,
        nearestPoint: route.first,
        bearingToNearest: bearing,
      );
    }

    double minDistance = double.infinity;
    LocalPoint nearest = route.first;

    for (int i = 0; i < route.length - 1; i++) {
      final candidate = nearestPointOnSegment(p, route[i], route[i + 1]);
      final dx = candidate.x - p.x;
      final dy = candidate.y - p.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = candidate;
      }
    }

    final dx = nearest.x - p.x;
    final dy = nearest.y - p.y;
    final bearing = (math.atan2(dx, dy) * 180.0 / math.pi + 360.0) % 360.0;

    return CrossTrackResult(
      distance: minDistance,
      nearestPoint: nearest,
      bearingToNearest: bearing,
    );
  }
}

/// Logika L3 PRD: Deteksi Keluar Jalur Adaptif dengan Histeresis
class OffRouteDetector {
  final double tMin; // Jarak minimum dianggap keluar jalur (default 30m)
  final double k; // Pengali akurasi (default 2)
  final int minConsecutiveFixes; // Minimal 5 fix
  final Duration minDuration; // Minimal 15 detik
  final Duration alarmInterval; // Alarm diulang tiap 60 detik

  bool _isOffRoute = false;
  int _consecutiveOffRouteFixes = 0;
  DateTime? _firstOffRouteTime;
  int _consecutiveOnRouteFixes = 0;
  DateTime? _lastAlarmTime;
  bool _shouldAlarm = false;
  bool _isWeakSignal = false;

  OffRouteDetector({
    this.tMin = 30.0,
    this.k = 2.0,
    this.minConsecutiveFixes = 5,
    this.minDuration = const Duration(seconds: 15),
    this.alarmInterval = const Duration(seconds: 60),
  });

  bool get isOffRoute => _isOffRoute;

  /// True hanya pada update yang harus membunyikan alarm.
  bool get shouldAlarm => _shouldAlarm;

  /// True setelah [weakSignal] dipanggil, sampai ada fix bagus lagi.
  bool get isWeakSignal => _isWeakSignal;

  /// Dipanggil untuk fix yang ditolak gating karena akurasi buruk.
  /// Hitungan fix tidak diubah, dan alarm tidak bunyi.
  void weakSignal() {
    _isWeakSignal = true;
    _shouldAlarm = false;
  }

  /// Memperbarui status berdasarkan jarak ke rute dan akurasi fix
  bool update({
    required double crossTrackDistance,
    required double accuracy,
    required DateTime timestamp,
  }) {
    // Ambang dinamis T = max(tMin, k * accuracy)
    final threshold = math.max(tMin, k * accuracy);

    if (!_isOffRoute) {
      if (crossTrackDistance > threshold) {
        _consecutiveOffRouteFixes++;
        _firstOffRouteTime ??= timestamp;

        final elapsed = timestamp.difference(_firstOffRouteTime!);
        if (_consecutiveOffRouteFixes >= minConsecutiveFixes && elapsed >= minDuration) {
          _isOffRoute = true;
          _consecutiveOnRouteFixes = 0;
        }
      } else {
        _consecutiveOffRouteFixes = 0;
        _firstOffRouteTime = null;
      }
    } else {
      // Ambang kembali ke jalur: d < 0.7 * T pada 3 fix berturut-turut
      final returnThreshold = 0.7 * threshold;
      if (crossTrackDistance < returnThreshold) {
        _consecutiveOnRouteFixes++;
        if (_consecutiveOnRouteFixes >= 3) {
          _isOffRoute = false;
          _consecutiveOffRouteFixes = 0;
          _firstOffRouteTime = null;
          _consecutiveOnRouteFixes = 0;
        }
      } else {
        _consecutiveOnRouteFixes = 0;
      }
    }

    _isWeakSignal = false;
    _shouldAlarm = false;
    if (_isOffRoute) {
      // Alarm pertama langsung, lalu tiap alarmInterval. Kalau jatahnya jatuh
      // saat sinyal lemah, alarm bunyi di fix bagus berikutnya ini.
      if (_lastAlarmTime == null ||
          timestamp.difference(_lastAlarmTime!) >= alarmInterval) {
        _shouldAlarm = true;
        _lastAlarmTime = timestamp;
      }
    } else {
      _lastAlarmTime = null;
    }

    return _isOffRoute;
  }

  void reset() {
    _isOffRoute = false;
    _consecutiveOffRouteFixes = 0;
    _firstOffRouteTime = null;
    _consecutiveOnRouteFixes = 0;
    _lastAlarmTime = null;
    _shouldAlarm = false;
    _isWeakSignal = false;
  }
}
