/// Konstelasi satelit GNSS sesuai konstanta GnssStatus Android.
enum GnssConstellation {
  gps('GPS', 'G'),
  glonass('GLONASS', 'R'),
  galileo('Galileo', 'E'),
  beidou('BeiDou', 'C'),
  qzss('QZSS', 'J'),
  sbas('SBAS', 'S'),
  irnss('NavIC', 'I'),
  unknown('Lainnya', '?');

  final String label;
  final String shortPrefix;

  const GnssConstellation(this.label, this.shortPrefix);

  /// Pemetaan dari konstanta Android GnssStatus.CONSTELLATION_* (API 24+).
  static GnssConstellation fromAndroidType(int type) {
    return switch (type) {
      1 => GnssConstellation.gps,
      2 => GnssConstellation.sbas,
      3 => GnssConstellation.glonass,
      4 => GnssConstellation.qzss,
      5 => GnssConstellation.beidou,
      6 => GnssConstellation.galileo,
      7 => GnssConstellation.irnss,
      _ => GnssConstellation.unknown,
    };
  }

  static GnssConstellation fromName(String? name) {
    if (name == null) return GnssConstellation.unknown;
    for (final value in GnssConstellation.values) {
      if (value.name == name) return value;
    }
    return GnssConstellation.unknown;
  }
}

/// Informasi satu satelit dari pembacaan GnssStatus (US-01).
class SatelliteInfo {
  final int svid;
  final GnssConstellation constellation;
  final double cn0DbHz; // Carrier-to-noise density (dB-Hz)
  final double azimuthDegrees; // 0..360 derajat (0 = Utara)
  final double elevationDegrees; // 0..90 derajat (90 = zenit)
  final bool usedInFix;
  final bool hasAlmanac;
  final bool hasEphemeris;

  const SatelliteInfo({
    required this.svid,
    required this.constellation,
    required this.cn0DbHz,
    required this.azimuthDegrees,
    required this.elevationDegrees,
    required this.usedInFix,
    this.hasAlmanac = false,
    this.hasEphemeris = false,
  });

  /// Kode ringkas satelit untuk label skyplot dan daftar (mis. G12, E04).
  String get displayId => '${constellation.shortPrefix}$svid';

  Map<String, dynamic> toMap() {
    return {
      'svid': svid,
      'constellation': constellation.name,
      'cn0DbHz': cn0DbHz,
      'azimuthDegrees': azimuthDegrees,
      'elevationDegrees': elevationDegrees,
      'usedInFix': usedInFix,
      'hasAlmanac': hasAlmanac,
      'hasEphemeris': hasEphemeris,
    };
  }

  factory SatelliteInfo.fromMap(Map<String, dynamic> map) {
    final constellationRaw = map['constellation'];
    final constellation = constellationRaw is int
        ? GnssConstellation.fromAndroidType(constellationRaw)
        : GnssConstellation.fromName(constellationRaw as String?);

    return SatelliteInfo(
      svid: (map['svid'] as num).toInt(),
      constellation: constellation,
      cn0DbHz: (map['cn0DbHz'] as num).toDouble(),
      azimuthDegrees: (map['azimuthDegrees'] as num).toDouble(),
      elevationDegrees: (map['elevationDegrees'] as num).toDouble(),
      usedInFix: map['usedInFix'] as bool? ?? false,
      hasAlmanac: map['hasAlmanac'] as bool? ?? false,
      hasEphemeris: map['hasEphemeris'] as bool? ?? false,
    );
  }
}

/// Snapshot kondisi satelit GNSS pada satu waktu pengamatan (US-01).
class GnssStatusSnapshot {
  final DateTime timestamp;
  final List<SatelliteInfo> satellites;

  const GnssStatusSnapshot({
    required this.timestamp,
    required this.satellites,
  });

  int get visibleCount => satellites.length;

  int get usedCount => satellites.where((s) => s.usedInFix).length;

  /// Jumlah satelit per konstelasi (terlihat), diurutkan dari terbanyak.
  Map<GnssConstellation, int> get constellationCounts {
    final counts = <GnssConstellation, int>{};
    for (final sat in satellites) {
      counts[sat.constellation] = (counts[sat.constellation] ?? 0) + 1;
    }
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map<GnssConstellation, int>.fromEntries(sortedEntries);
  }

  /// Rata-rata C/N0 (dB-Hz) untuk satelit yang terpakai dalam fix.
  /// Mengembalikan null bila belum ada satelit yang dipakai.
  double? get averageCn0Used {
    final used = satellites.where((s) => s.usedInFix && s.cn0DbHz > 0).toList();
    if (used.isEmpty) return null;
    final total = used.fold<double>(0.0, (sum, s) => sum + s.cn0DbHz);
    return total / used.length;
  }

  /// Rata-rata C/N0 (dB-Hz) untuk semua satelit terlihat yang punya sinyal > 0.
  double? get averageCn0Visible {
    final active = satellites.where((s) => s.cn0DbHz > 0).toList();
    if (active.isEmpty) return null;
    final total = active.fold<double>(0.0, (sum, s) => sum + s.cn0DbHz);
    return total / active.length;
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'satellites': satellites.map((s) => s.toMap()).toList(),
    };
  }

  factory GnssStatusSnapshot.fromMap(Map<String, dynamic> map) {
    final rawList = map['satellites'] as List<dynamic>? ?? const [];
    final satellites = rawList
        .map((item) => SatelliteInfo.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    return GnssStatusSnapshot(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      satellites: satellites,
    );
  }
}
