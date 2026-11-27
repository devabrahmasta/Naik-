import 'dart:async';
import 'dart:math' as math;

import 'package:geo_core/geo_core.dart';
import 'package:hikenav_mobile/core/platform/gnss_channel.dart';

/// Mode sumber data GNSS yang digunakan oleh [GnssService].
enum GnssSourceMode {
  /// Data nyata dari sensor hardware melalui Kotlin platform channel.
  hardware,

  /// Data simulasi dari [ReplayGnssSource] (untuk testing tanpa perangkat fisik).
  replay,
}

/// Kondisi kesiapan sensor dan izin GNSS (US-01).
enum GnssReadinessState {
  checking,
  ready,
  permissionDenied,
  gpsDisabled,
  error,
}

class GnssReadiness {
  final GnssReadinessState state;
  final String? message;

  const GnssReadiness({
    required this.state,
    this.message,
  });

  bool get isReady => state == GnssReadinessState.ready;
}

/// Layanan GNSS sisi Flutter (Dart).
/// Menjadi jembatan antara sumber data fix/status (hardware / replay) dan pipeline geo_core.
///
/// Komponen lain (UI, tracking, route detector) mengakses data GNSS melalui [GnssService].
class GnssService {
  GnssSourceMode _mode;
  final Future<GnssNativeState?> Function()? _nativeStateReader;
  final Stream<GnssFix>? _customFixStream;
  final Stream<GnssStatusSnapshot>? _customStatusStream;

  final StreamController<GnssFix> _fixController =
      StreamController<GnssFix>.broadcast();
  final StreamController<GnssStatusSnapshot> _statusController =
      StreamController<GnssStatusSnapshot>.broadcast();
  final StreamController<double> _compassController =
      StreamController<double>.broadcast();
  final StreamController<GnssReadiness> _readinessController =
      StreamController<GnssReadiness>.broadcast();

  StreamSubscription<GnssFix>? _replayFixSubscription;
  StreamSubscription<GnssStatusSnapshot>? _replayStatusSubscription;
  StreamSubscription<GnssFix>? _hardwareFixSubscription;
  StreamSubscription<GnssStatusSnapshot>? _hardwareStatusSubscription;
  StreamSubscription<double>? _hardwareCompassSubscription;
  bool _hardwareMonitoringStarted = false;
  bool _foregroundTrackingStarted = false;

  GnssReadiness _currentReadiness =
      const GnssReadiness(state: GnssReadinessState.checking);

  GnssService({
    this._mode = GnssSourceMode.hardware,
    this._nativeStateReader,
    this._customFixStream,
    this._customStatusStream,
  });

  GnssSourceMode get mode => _mode;

  GnssReadiness get currentReadiness => _currentReadiness;

  /// Aliran fix GNSS (broadcast stream).
  Stream<GnssFix> get fixStream => _fixController.stream;

  /// Aliran snapshot satelit GNSS: konstelasi, C/N0, azimut, elevasi (US-01).
  Stream<GnssStatusSnapshot> get statusStream => _statusController.stream;

  /// Aliran derajat azimuth kompas dari magnetometer (broadcast stream).
  Stream<double> get compassStream => _compassController.stream;

  /// Aliran perubahan kesiapan izin dan GPS.
  Stream<GnssReadiness> get readinessStream => _readinessController.stream;

  /// Mengubah mode sumber data (misal dari hardware ke simulasi replay) dan memulai ulang stream.
  Future<void> setMode(GnssSourceMode newMode) async {
    if (_mode == newMode) return;
    await stop();
    _mode = newMode;
    await start();
  }

  /// Memeriksa status izin lokasi dan aktivasi GPS perangkat.
  Future<GnssReadiness> checkReadiness() async {
    if (_mode == GnssSourceMode.replay) {
      return _updateReadiness(
        const GnssReadiness(state: GnssReadinessState.ready),
      );
    }

    try {
      final reader = _nativeStateReader ?? GnssChannel.getGnssState;
      final state = await reader();
      if (state == null) {
        return _updateReadiness(
          const GnssReadiness(
            state: GnssReadinessState.error,
            message: 'Layanan GNSS native tidak tersedia di perangkat ini.',
          ),
        );
      }
      if (!state.hasPermission) {
        return _updateReadiness(
          const GnssReadiness(
            state: GnssReadinessState.permissionDenied,
            message: 'Izin lokasi belum diberikan.',
          ),
        );
      }
      if (!state.isGpsEnabled) {
        return _updateReadiness(
          const GnssReadiness(
            state: GnssReadinessState.gpsDisabled,
            message: 'Layanan lokasi (GPS) perangkat sedang mati.',
          ),
        );
      }
      return _updateReadiness(
        const GnssReadiness(state: GnssReadinessState.ready),
      );
    } catch (e) {
      return _updateReadiness(
        GnssReadiness(
          state: GnssReadinessState.error,
          message: 'Gagal memeriksa status GNSS: $e',
        ),
      );
    }
  }

  /// Meminta izin lokasi runtime pada Android.
  Future<bool> requestPermission() async {
    if (_mode == GnssSourceMode.replay) return true;
    final granted = await GnssChannel.requestLocationPermission();
    await checkReadiness();
    if (granted && _currentReadiness.isReady) {
      await _startHardwareStreams();
    }
    return granted;
  }

  /// Membuka pengaturan sumber lokasi Android agar pengguna dapat menyalakan GPS.
  Future<bool> openLocationSettings() async {
    return GnssChannel.openLocationSettings();
  }

  /// Membuka halaman detail izin aplikasi di pengaturan Android.
  Future<bool> openAppSettings() async {
    return GnssChannel.openAppSettings();
  }

  /// Mulai mendengarkan sumber data GNSS sesuai [mode].
  /// Jika [startForegroundTracking] true, aktifkan juga Foreground Service (US-04).
  Future<void> start({bool startForegroundTracking = false}) async {
    await stop();

    if (_customFixStream != null || _customStatusStream != null) {
      await checkReadiness();
      if (_customFixStream != null) {
        _hardwareFixSubscription = _customFixStream.listen(
          _fixController.add,
          onError: _fixController.addError,
        );
      }
      if (_customStatusStream != null) {
        _hardwareStatusSubscription = _customStatusStream.listen(
          _statusController.add,
          onError: _statusController.addError,
        );
      }
      return;
    }

    if (_mode == GnssSourceMode.hardware) {
      final readiness = await checkReadiness();
      if (!readiness.isReady) return;
      await _startHardwareStreams(
        startForegroundTracking: startForegroundTracking,
      );
    } else {
      _updateReadiness(const GnssReadiness(state: GnssReadinessState.ready));
      _startReplay();
    }
  }

  /// Hentikan semua stream dan monitoring sensor.
  Future<void> stop({bool stopForegroundTracking = false}) async {
    final replayFixSub = _replayFixSubscription;
    final replayStatusSub = _replayStatusSubscription;
    final hwFixSub = _hardwareFixSubscription;
    final hwStatusSub = _hardwareStatusSubscription;
    final hwCompassSub = _hardwareCompassSubscription;

    _replayFixSubscription = null;
    _replayStatusSubscription = null;
    _hardwareFixSubscription = null;
    _hardwareStatusSubscription = null;
    _hardwareCompassSubscription = null;

    if (replayFixSub != null) await replayFixSub.cancel();
    if (replayStatusSub != null) await replayStatusSub.cancel();
    if (hwFixSub != null) await hwFixSub.cancel();
    if (hwStatusSub != null) await hwStatusSub.cancel();
    if (hwCompassSub != null) await hwCompassSub.cancel();

    if (_mode == GnssSourceMode.hardware && _customFixStream == null) {
      if (_hardwareMonitoringStarted) {
        await GnssChannel.stopGnssMonitoring();
        _hardwareMonitoringStarted = false;
      }
      if (stopForegroundTracking && _foregroundTrackingStarted) {
        await GnssChannel.stopTrackingService();
        _foregroundTrackingStarted = false;
      }
    }
  }

  Future<void> dispose() async {
    await stop();
    await _fixController.close();
    await _statusController.close();
    await _compassController.close();
    await _readinessController.close();
  }

  GnssReadiness _updateReadiness(GnssReadiness next) {
    _currentReadiness = next;
    if (!_readinessController.isClosed) {
      _readinessController.add(next);
    }
    return next;
  }

  // ---------------------------------------------------------------------------
  // Hardware Mode
  // ---------------------------------------------------------------------------
  Future<void> _startHardwareStreams({
    bool startForegroundTracking = false,
  }) async {
    if (startForegroundTracking) {
      await GnssChannel.startTrackingService();
      _foregroundTrackingStarted = true;
    } else {
      await GnssChannel.startGnssMonitoring();
      _hardwareMonitoringStarted = true;
    }

    _hardwareFixSubscription = GnssChannel.fixStream.listen(
      (fix) {
        if (!_fixController.isClosed) _fixController.add(fix);
      },
      onError: (Object err) {
        if (!_fixController.isClosed) _fixController.addError(err);
      },
    );

    _hardwareStatusSubscription = GnssChannel.statusStream.listen(
      (snapshot) {
        if (!_statusController.isClosed) _statusController.add(snapshot);
      },
      onError: (Object err) {
        if (!_statusController.isClosed) _statusController.addError(err);
      },
    );

    _hardwareCompassSubscription = GnssChannel.compassStream.listen(
      (azimuth) {
        if (!_compassController.isClosed) _compassController.add(azimuth);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Replay Mode (testing tanpa hardware)
  // ---------------------------------------------------------------------------
  void _startReplay() {
    _replayFixSubscription = ReplayGnssSource.defaultTrack().listen(
      (fix) {
        if (!_fixController.isClosed) _fixController.add(fix);
      },
    );
    _replayStatusSubscription = ReplayGnssSource.defaultStatusStream().listen(
      (snapshot) {
        if (!_statusController.isClosed) _statusController.add(snapshot);
      },
    );
  }
}

/// Sumber fix dan status satelit GNSS palsu untuk testing (US-01 & US-10).
class ReplayGnssSource {
  /// Menghasilkan stream fix GNSS dari daftar [fixes].
  /// Memakai Timer agar pembatalan langganan (cancel) berlaku seketika.
  static Stream<GnssFix> fromFixes(
    List<GnssFix> fixes, {
    bool useRealTimings = false,
  }) {
    late final StreamController<GnssFix> controller;
    Timer? timer;
    int index = 0;

    void scheduleNext() {
      if (controller.isClosed || index >= fixes.length) {
        controller.close();
        return;
      }

      Duration delay = const Duration(milliseconds: 50);
      if (useRealTimings && index > 0) {
        final gap = fixes[index].timestamp.difference(fixes[index - 1].timestamp);
        delay = gap.isNegative || gap.inMilliseconds > 10000
            ? const Duration(seconds: 2)
            : gap;
      }

      timer = Timer(delay, () {
        if (controller.isClosed) return;
        controller.add(fixes[index]);
        index++;
        scheduleNext();
      });
    }

    controller = StreamController<GnssFix>(
      onListen: scheduleNext,
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );

    return controller.stream;
  }

  /// Track simulasi default: jalur lurus di lereng Merbabu (Selo ke Pos 1).
  static Stream<GnssFix> defaultTrack() {
    final base = DateTime(2026, 11, 23, 8, 0, 0);
    final fixes = List.generate(30, (i) {
      return GnssFix(
        // Kecepatan implisit: ~2.5m per 2 dtk = 1.25 m/s (kecepatan pendakian normal)
        // agar tidak memicu V_max = 5 m/s di FixGating
        latitude: -7.4532 + i * 0.0000200,
        longitude: 110.4385 + i * 0.0000050,
        altitude: 2600.0 + i * 2.5,
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

  /// Stream status satelit simulasi untuk menguji Skyplot dan daftar C/N0 (US-01).
  static Stream<GnssStatusSnapshot> defaultStatusStream({
    Duration interval = const Duration(milliseconds: 250),
    int ticks = 12,
  }) {
    final base = DateTime(2026, 11, 23, 8, 0, 0);
    final baseSatellites = <SatelliteInfo>[
      const SatelliteInfo(
        svid: 12,
        constellation: GnssConstellation.gps,
        cn0DbHz: 38.4,
        azimuthDegrees: 32,
        elevationDegrees: 68,
        usedInFix: true,
        hasAlmanac: true,
        hasEphemeris: true,
      ),
      const SatelliteInfo(
        svid: 24,
        constellation: GnssConstellation.gps,
        cn0DbHz: 35.1,
        azimuthDegrees: 118,
        elevationDegrees: 54,
        usedInFix: true,
        hasAlmanac: true,
        hasEphemeris: true,
      ),
      const SatelliteInfo(
        svid: 7,
        constellation: GnssConstellation.gps,
        cn0DbHz: 29.8,
        azimuthDegrees: 245,
        elevationDegrees: 34,
        usedInFix: true,
        hasAlmanac: true,
        hasEphemeris: true,
      ),
      const SatelliteInfo(
        svid: 19,
        constellation: GnssConstellation.gps,
        cn0DbHz: 19.2,
        azimuthDegrees: 310,
        elevationDegrees: 14,
        usedInFix: false,
        hasAlmanac: true,
      ),
      const SatelliteInfo(
        svid: 4,
        constellation: GnssConstellation.glonass,
        cn0DbHz: 33.0,
        azimuthDegrees: 72,
        elevationDegrees: 61,
        usedInFix: true,
        hasAlmanac: true,
        hasEphemeris: true,
      ),
      const SatelliteInfo(
        svid: 15,
        constellation: GnssConstellation.glonass,
        cn0DbHz: 27.5,
        azimuthDegrees: 195,
        elevationDegrees: 41,
        usedInFix: true,
        hasAlmanac: true,
        hasEphemeris: true,
      ),
      const SatelliteInfo(
        svid: 11,
        constellation: GnssConstellation.galileo,
        cn0DbHz: 36.2,
        azimuthDegrees: 154,
        elevationDegrees: 74,
        usedInFix: true,
        hasAlmanac: true,
        hasEphemeris: true,
      ),
      const SatelliteInfo(
        svid: 29,
        constellation: GnssConstellation.galileo,
        cn0DbHz: 23.4,
        azimuthDegrees: 288,
        elevationDegrees: 22,
        usedInFix: false,
        hasAlmanac: true,
      ),
      const SatelliteInfo(
        svid: 21,
        constellation: GnssConstellation.beidou,
        cn0DbHz: 34.7,
        azimuthDegrees: 15,
        elevationDegrees: 47,
        usedInFix: true,
        hasAlmanac: true,
        hasEphemeris: true,
      ),
      const SatelliteInfo(
        svid: 38,
        constellation: GnssConstellation.beidou,
        cn0DbHz: 31.5,
        azimuthDegrees: 96,
        elevationDegrees: 29,
        usedInFix: true,
        hasAlmanac: true,
        hasEphemeris: true,
      ),
      const SatelliteInfo(
        svid: 194,
        constellation: GnssConstellation.qzss,
        cn0DbHz: 37.8,
        azimuthDegrees: 62,
        elevationDegrees: 79,
        usedInFix: true,
        hasAlmanac: true,
        hasEphemeris: true,
      ),
      const SatelliteInfo(
        svid: 14,
        constellation: GnssConstellation.beidou,
        cn0DbHz: 16.5,
        azimuthDegrees: 212,
        elevationDegrees: 9,
        usedInFix: false,
      ),
    ];

    late final StreamController<GnssStatusSnapshot> controller;
    Timer? timer;
    int t = 0;

    void emitTick() {
      if (controller.isClosed || t >= ticks) {
        controller.close();
        return;
      }

      final adjusted = baseSatellites.map((sat) {
        final deltaCn0 = math.sin(t * 0.6 + sat.svid) * 1.4;
        return SatelliteInfo(
          svid: sat.svid,
          constellation: sat.constellation,
          cn0DbHz: (sat.cn0DbHz + deltaCn0).clamp(10.0, 50.0),
          azimuthDegrees: (sat.azimuthDegrees + t * 0.8) % 360.0,
          elevationDegrees: sat.elevationDegrees,
          usedInFix: sat.usedInFix,
          hasAlmanac: sat.hasAlmanac,
          hasEphemeris: sat.hasEphemeris,
        );
      }).toList();

      controller.add(
        GnssStatusSnapshot(
          timestamp: base.add(Duration(seconds: t * 2)),
          satellites: adjusted,
        ),
      );
      t++;

      if (t >= ticks) {
        controller.close();
        return;
      }

      timer = Timer(interval, emitTick);
    }

    controller = StreamController<GnssStatusSnapshot>(
      onListen: emitTick,
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );

    return controller.stream;
  }

  /// Memuat dan memutar ulang berkas CSV log fix GNSS (US-10).
  /// Format CSV: timestamp,lat,lon,alt,accuracy,speed,bearing,satUsed,satVisible,passed
  static Stream<GnssFix> fromCsv(String csvContent) {
    final lines = csvContent.split('\n');
    final fixes = <GnssFix>[];

    for (final line in lines.skip(1)) {
      final cols = line.trim().split(',');
      if (cols.length < 9) continue;
      try {
        fixes.add(GnssFix(
          timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(cols[0])),
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
