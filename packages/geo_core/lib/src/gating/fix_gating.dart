import 'dart:math' as math;
import '../models/gnss_fix.dart';

enum GatingStatus {
  passed,
  rejectedAccuracy,
  rejectedVelocity,
  rejectedMock,
}

class GatingResult {
  final bool isAccepted;
  final GatingStatus status;
  final String reason;

  const GatingResult.passed()
      : isAccepted = true,
        status = GatingStatus.passed,
        reason = 'Fix lolos gating kualitas.';

  const GatingResult.rejected(this.status, this.reason) : isAccepted = false;
}

/// Logika L1 PRD: Gating Fix
/// Memfilter fix GNSS berkualitas rendah atau anomali lompatan lokasi.
class FixGating {
  final double aMax; // Ambang batas akurasi maksimum (meter)
  final double vMax; // Ambang batas kecepatan maksimum (m/s)

  GnssFix? _lastAcceptedFix;
  int _consecutiveVMaxRejections = 0;

  FixGating({this.aMax = 30.0, this.vMax = 5.0});

  GnssFix? get lastAcceptedFix => _lastAcceptedFix;

  GatingResult evaluate(GnssFix fix) {
    if (fix.isMock) {
      return const GatingResult.rejected(
        GatingStatus.rejectedMock,
        'Lokasi mock/palsu ditolak.',
      );
    }

    if (fix.accuracy > aMax) {
      return GatingResult.rejected(
        GatingStatus.rejectedAccuracy,
        'Akurasi (${fix.accuracy.toStringAsFixed(1)}m) melebihi batas A_max ($aMax m).',
      );
    }

    if (_lastAcceptedFix != null) {
      final prev = _lastAcceptedFix!;
      final dt = fix.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
      if (dt > 0.05) {
        final dist = _approxDistance(prev.latitude, prev.longitude, fix.latitude, fix.longitude);
        final impliedSpeed = dist / dt;

        // Tolak bila kecepatan implisit > vMax DAN jarak > jumlah akurasi kedua fix
        if (impliedSpeed > vMax && dist > (prev.accuracy + fix.accuracy)) {
          _consecutiveVMaxRejections++;
          // Pemulihan jika sinyal memang berpindah:
          // Bila >= 5 fix berturut-turut ditolak karena V_max dan fix terbaru berakurasi <= A_max
          if (_consecutiveVMaxRejections >= 5) {
            _lastAcceptedFix = fix;
            _consecutiveVMaxRejections = 0;
            return const GatingResult.passed();
          }
          return GatingResult.rejected(
            GatingStatus.rejectedVelocity,
            'Kecepatan implisit (${impliedSpeed.toStringAsFixed(1)} m/s) melebihi V_max ($vMax m/s).',
          );
        }
      }
    }

    _consecutiveVMaxRejections = 0;
    _lastAcceptedFix = fix;
    return const GatingResult.passed();
  }

  void reset() {
    _lastAcceptedFix = null;
    _consecutiveVMaxRejections = 0;
  }

  static double _approxDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final meanLat = ((lat1 + lat2) / 2.0) * math.pi / 180.0;
    final x = dLon * math.cos(meanLat);
    final y = dLat;
    return r * math.sqrt(x * x + y * y);
  }
}
