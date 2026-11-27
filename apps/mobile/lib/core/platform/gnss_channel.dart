import 'package:flutter/services.dart';
import 'package:geo_core/geo_core.dart';

/// State kesiapan GNSS dari sistem Android.
class GnssNativeState {
  final bool hasPermission;
  final bool isGpsEnabled;
  final bool isTracking;
  final bool isMonitoring;

  const GnssNativeState({
    required this.hasPermission,
    required this.isGpsEnabled,
    this.isTracking = false,
    this.isMonitoring = false,
  });

  factory GnssNativeState.fromMap(Map<dynamic, dynamic> map) {
    return GnssNativeState(
      hasPermission: map['hasPermission'] as bool? ?? false,
      isGpsEnabled: map['isGpsEnabled'] as bool? ?? false,
      isTracking: map['isTracking'] as bool? ?? false,
      isMonitoring: map['isMonitoring'] as bool? ?? false,
    );
  }
}

/// Kontrak komunikasi native Android (Kotlin) <-> Flutter Dart.
/// Satu sumber definisi channel untuk seluruh fitur agar tidak duplikat.
class GnssChannel {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.hikenav/gnss_control',
  );
  static const EventChannel _fixEventChannel = EventChannel(
    'com.hikenav/gnss_fix_stream',
  );
  static const EventChannel _statusEventChannel = EventChannel(
    'com.hikenav/gnss_status_stream',
  );
  static const EventChannel _compassEventChannel = EventChannel(
    'com.hikenav/compass_stream',
  );

  static Future<GnssNativeState?> getGnssState() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getGnssState',
      );
      if (result == null) return null;
      return GnssNativeState.fromMap(result);
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> requestLocationPermission() async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            'requestLocationPermission',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> openLocationSettings() async {
    try {
      return await _methodChannel.invokeMethod<bool>('openLocationSettings') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> openAppSettings() async {
    try {
      return await _methodChannel.invokeMethod<bool>('openAppSettings') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> startGnssMonitoring() async {
    try {
      return await _methodChannel.invokeMethod<bool>('startGnssMonitoring') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> stopGnssMonitoring() async {
    try {
      return await _methodChannel.invokeMethod<bool>('stopGnssMonitoring') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Memulai layanan pelacakan lokasi di latar belakang (Foreground Service)
  static Future<bool> startTrackingService() async {
    try {
      return await _methodChannel.invokeMethod<bool>('startTrackingService') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Menghentikan foreground service
  static Future<bool> stopTrackingService() async {
    try {
      return await _methodChannel.invokeMethod<bool>('stopTrackingService') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Aliran data raw GNSS Fix langsung dari GPS_PROVIDER Kotlin
  static Stream<GnssFix> get fixStream {
    return _fixEventChannel.receiveBroadcastStream().map((dynamic event) {
      final map = Map<String, dynamic>.from(event as Map);
      return GnssFix.fromMap(map);
    });
  }

  /// Aliran data status satelit langsung dari GnssStatus Kotlin (US-01)
  static Stream<GnssStatusSnapshot> get statusStream {
    return _statusEventChannel.receiveBroadcastStream().map((dynamic event) {
      final map = Map<String, dynamic>.from(event as Map);
      return GnssStatusSnapshot.fromMap(map);
    });
  }

  /// Aliran data sensor kompas (derajat azimuth 0-360)
  static Stream<double> get compassStream {
    return _compassEventChannel.receiveBroadcastStream().map((dynamic event) {
      return (event as num).toDouble();
    });
  }
}
