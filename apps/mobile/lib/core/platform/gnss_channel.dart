import 'package:flutter/services.dart';
import 'package:geo_core/geo_core.dart';

/// Kontrak komunikasi native Android (Kotlin) <-> Flutter Dart
/// Sesuai PRD Bagian 4 (Alur data satu fix & Integration Points).
class GnssChannel {
  static const MethodChannel _methodChannel = MethodChannel('com.hikenav/gnss_control');
  static const EventChannel _fixEventChannel = EventChannel('com.hikenav/gnss_fix_stream');
  static const EventChannel _compassEventChannel = EventChannel('com.hikenav/compass_stream');

  /// Memulai layanan pelacakan lokasi di latar belakang (Foreground Service)
  static Future<bool> startTrackingService() async {
    try {
      final bool result = await _methodChannel.invokeMethod('startTrackingService') ?? false;
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Menghentikan foreground service
  static Future<bool> stopTrackingService() async {
    try {
      final bool result = await _methodChannel.invokeMethod('stopTrackingService') ?? false;
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Aliran data raw GNSS Fix langsung dari GPS_PROVIDER Kotlin
  static Stream<GnssFix> get fixStream {
    return _fixEventChannel.receiveBroadcastStream().map((dynamic event) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(event as Map);
      return GnssFix.fromMap(map);
    });
  }

  /// Aliran data sensor kompas (derajat azimuth 0-360)
  static Stream<double> get compassStream {
    return _compassEventChannel.receiveBroadcastStream().map((dynamic event) {
      return (event as num).toDouble();
    });
  }
}
