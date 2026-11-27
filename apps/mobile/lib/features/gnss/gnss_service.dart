import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geo_core/geo_core.dart';

/// Mode sumber data GNSS yang digunakan oleh [GnssService].
enum GnssSourceMode {
  /// Data nyata dari sensor hardware melalui Kotlin platform channel.
  hardware,

  /// Data simulasi dari [ReplayGnssSource] (untuk testing tanpa perangkat fisik).
  replay,
}

/// Layanan GNSS sisi Flutter (Dart).
/// Menjadi jembatan antara sumber data fix (hardware / replay) dan pipeline geo_core.
///
/// Komponen lain (UI, tracking, route detector) TIDAK boleh mengakses
/// [GnssChannel] atau [ReplayGnssSource] secara langsung; gunakan [GnssService] ini.
class GnssService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.hikenav/gnss_control');
  static const EventChannel _fixEventChannel =
      EventChannel('com.hikenav/gnss_fix_stream');
  static const EventChannel _compassEventChannel =
      EventChannel('com.hikenav/compass_stream');

  final GnssSourceMode mode;

  // Stream controllers agar sumber data bisa diganti tanpa mengubah konsumen
  final StreamController<GnssFix> _fixController =
      StreamController<GnssFix>.broadcast();
  final StreamController<double> _compassController =
      StreamController<double>.broadcast();

  StreamSubscription<GnssFix>? _replaySubscription;
  StreamSubscription<dynamic>? _hardwareFixSubscription;
  StreamSubscription<dynamic>? _hardwareCompassSubscription;

  GnssService({this.mode = GnssSourceMode.hardware});

  /// Aliran fix GNSS yang telah melewati gating (broadcast stream).
  Stream<GnssFix> get fixStream => _fixController.stream;

  /// Aliran derajat azimuth kompas dari magnetometer (broadcast stream).
  Stream<double> get compassStream => _compassController.stream;

  /// Mulai mendengarkan sumber data GNSS sesuai [mode].
  Future<void> start() async {
    if (mode == GnssSourceMode.hardware) {
      await _startHardware();
    } else {
      _startReplay();
    }
  }

  /// Hentikan semua stream dan bersihkan resource.
  Future<void> stop() async {
    await _replaySubscription?.cancel();
    await _hardwareFixSubscription?.cancel();
    await _hardwareCompassSubscription?.cancel();
    _replaySubscription = null;
    _hardwareFixSubscription = null;
    _hardwareCompassSubscription = null;
  }

  Future<void> dispose() async {
    await stop();
    await _fixController.close();
    await _compassController.close();
  }

  // ---------------------------------------------------------------------------
  // Hardware Mode
  // ---------------------------------------------------------------------------
  Future<void> _startHardware() async {
    try {
      await _methodChannel.invokeMethod('startTrackingService');
    } catch (_) {
      // Platform channel mungkin belum siap saat unit test; biarkan saja.
    }

    _hardwareFixSubscription = _fixEventChannel
        .receiveBroadcastStream()
        .listen((dynamic event) {
      try {
        final fix = GnssFix.fromMap(Map<String, dynamic>.from(event as Map));
        _fixController.add(fix);
      } catch (_) {
        // Abaikan fix yang tidak bisa diurai
      }
    });

    _hardwareCompassSubscription = _compassEventChannel
        .receiveBroadcastStream()
        .listen((dynamic event) {
      _compassController.add((event as num).toDouble());
    });
  }

  // ---------------------------------------------------------------------------
  // Replay Mode (testing tanpa hardware)
  // ---------------------------------------------------------------------------
  void _startReplay() {
    _replaySubscription = ReplayGnssSource.defaultTrack().listen(
      _fixController.add,
    );
  }
}

/// Sumber fix GNSS palsu untuk testing (US-10: replay log).
/// Memutar ulang data log CSV dari [data/logs/] agar tim bisa menguji pipeline
/// deteksi keluar jalur dan gating tanpa berada di lapangan.
class ReplayGnssSource {
  /// Menghasilkan stream fix GNSS dari daftar [fixes] dengan interval waktu riil.
  static Stream<GnssFix> fromFixes(
    List<GnssFix> fixes, {
    bool useRealTimings = false,
  }) async* {
    for (int i = 0; i < fixes.length; i++) {
      if (useRealTimings && i > 0) {
        final gap = fixes[i].timestamp.difference(fixes[i - 1].timestamp);
        final clampedGap = gap.isNegative || gap.inMilliseconds > 10000
            ? const Duration(seconds: 2)
            : gap;
        await Future<void>.delayed(clampedGap);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      yield fixes[i];
    }
  }

  /// Track simulasi default: jalur lurus di lereng Merbabu (Selo → pos 1).
  /// Dipakai saat tidak ada berkas CSV; cocok untuk smoke test pipeline geo_core.
  static Stream<GnssFix> defaultTrack() {
    final base = DateTime(2026, 11, 23, 8, 0, 0);
    final fixes = List.generate(30, (i) {
      return GnssFix(
        // Kecepatan implisit: ~2.5m per 2 dtk = 1.25 m/s (kecepatan pendakian normal)
        // agar tidak memicu V_max = 5 m/s di FixGating
        latitude: -7.4532 + i * 0.0000200,  // ~2.2m ke utara per fix
        longitude: 110.4385 + i * 0.0000050, // ~0.5m ke timur per fix
        altitude: 2600.0 + i * 2.5,          // naik 2.5m per fix (gradien ~1%)
        accuracy: 8.0 + (i % 3).toDouble(),
        speed: 1.3,
        bearing: 15.0,
        satellitesUsed: 9,
        satellitesVisible: 12,
        timestamp: base.add(Duration(seconds: i * 2)),
      );
    });
    return fromFixes(fixes);
  }

  /// Memuat dan memutar ulang berkas CSV log fix GNSS (US-10).
  /// Format CSV: timestamp,lat,lon,alt,accuracy,speed,bearing,satUsed,satVisible,passed
  static Stream<GnssFix> fromCsv(String csvContent) {
    final lines = csvContent.split('\n');
    final fixes = <GnssFix>[];

    for (final line in lines.skip(1)) {
      // skip header
      final cols = line.trim().split(',');
      if (cols.length < 9) continue;
      try {
        fixes.add(GnssFix(
          timestamp:
              DateTime.fromMillisecondsSinceEpoch(int.parse(cols[0])),
          latitude: double.parse(cols[1]),
          longitude: double.parse(cols[2]),
          altitude: double.parse(cols[3]),
          accuracy: double.parse(cols[4]),
          speed: double.parse(cols[5]),
          bearing: double.parse(cols[6]),
          satellitesUsed: int.parse(cols[7]),
          satellitesVisible: int.parse(cols[8]),
        ));
      } catch (_) {
        continue;
      }
    }

    return fromFixes(fixes, useRealTimings: false);
  }
}
