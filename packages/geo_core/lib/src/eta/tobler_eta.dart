import 'dart:math' as math;

/// Logika L4 PRD: Elevasi dan Estimasi Waktu Tempuh (Tobler's Hiking Function)
class ToblerEta {
  /// Menghitung kecepatan berjalan di lereng menggunakan Tobler's Hiking Function
  /// [slope] = delta_elevasi / delta_jarak_horizontal (tanpa satuan, misal 0.1 = naik 10m per 100m)
  /// Mengembalikan kecepatan dalam km/jam (km/h)
  static double speedKmh(double slope) {
    return 6.0 * math.exp(-3.5 * (slope + 0.05).abs());
  }

  /// Menghitung waktu tempuh (dalam detik) untuk segmen dengan jarak datar [distanceMeters]
  /// dan perbedaan elevasi [elevationDeltaMeters]
  static double travelTimeSeconds({
    required double distanceMeters,
    required double elevationDeltaMeters,
  }) {
    if (distanceMeters <= 0) return 0.0;

    final slope = elevationDeltaMeters / distanceMeters;
    final speed = speedKmh(slope); // km/h
    final speedMs = speed * (1000.0 / 3600.0); // m/s

    if (speedMs <= 0.01) return double.infinity;
    return distanceMeters / speedMs;
  }
}
