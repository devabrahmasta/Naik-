package com.hikenav.hikenav_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Entry point native Android.
 * Mendaftarkan semua channel komunikasi Kotlin <-> Flutter:
 *   - MethodChannel  : start/stop foreground service (US-04)
 *   - EventChannel 1 : aliran fix GNSS raw (US-01, US-02, US-04, US-06, US-11)
 *   - EventChannel 2 : aliran derajat kompas (US-11)
 */
class MainActivity : FlutterActivity() {

    private lateinit var gnssPlugin: GnssChannelPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        gnssPlugin = GnssChannelPlugin(applicationContext)

        // 1. MethodChannel: kontrol foreground service
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GnssChannelPlugin.METHOD_CHANNEL_NAME
        ).setMethodCallHandler(gnssPlugin)

        // 2. EventChannel: aliran fix GNSS
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GnssChannelPlugin.FIX_CHANNEL_NAME
        ).setStreamHandler(gnssPlugin.FixStreamHandler())

        // 3. EventChannel: aliran kompas
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GnssChannelPlugin.COMPASS_CHANNEL_NAME
        ).setStreamHandler(gnssPlugin.CompassStreamHandler())
    }
}
