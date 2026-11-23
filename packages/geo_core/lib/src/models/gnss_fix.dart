/// Model data untuk fix posisi dari sensor GNSS (GPS).
class GnssFix {
  final double latitude;
  final double longitude;
  final double altitude; // Ketinggian WGS84 (meter)
  final double accuracy; // Akurasi horizontal (meter) 1-sigma
  final double speed; // Kecepatan (m/s)
  final double bearing; // Arah pergerakan (derajat, 0-360)
  final int satellitesUsed; // Jumlah satelit yang digunakan untuk fix
  final int satellitesVisible; // Jumlah satelit yang terdeteksi
  final DateTime timestamp;
  final bool isMock; // Deteksi lokasi palsu

  const GnssFix({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.speed,
    required this.bearing,
    required this.satellitesUsed,
    this.satellitesVisible = 0,
    required this.timestamp,
    this.isMock = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'bearing': bearing,
      'satellitesUsed': satellitesUsed,
      'satellitesVisible': satellitesVisible,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isMock': isMock,
    };
  }

  factory GnssFix.fromMap(Map<String, dynamic> map) {
    return GnssFix(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude: (map['altitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      bearing: (map['bearing'] as num).toDouble(),
      satellitesUsed: (map['satellitesUsed'] as num).toInt(),
      satellitesVisible: (map['satellitesVisible'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num).toInt(),
      ),
      isMock: map['isMock'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'GnssFix(lat: $latitude, lon: $longitude, acc: ${accuracy}m, sat: $satellitesUsed)';
}
