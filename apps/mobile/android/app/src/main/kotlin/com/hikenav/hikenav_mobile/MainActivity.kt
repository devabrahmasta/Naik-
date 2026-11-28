package com.hikenav.hikenav_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.os.StatFs

/**
 * Entry point native Android.
 * Mendaftarkan seluruh channel komunikasi Kotlin <-> Flutter:
 *   - MethodChannel  : kontrol izin, pengaturan lokasi, monitoring, dan TrackingService
 *   - EventChannel 1 : aliran fix GNSS raw (US-01, US-02, US-04, US-06, US-11)
 *   - EventChannel 2 : aliran status satelit GnssStatus (US-01)
 *   - EventChannel 3 : aliran derajat kompas (US-11)
 */
class MainActivity : FlutterActivity() {

    private lateinit var gnssPlugin: GnssChannelPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        gnssPlugin = GnssChannelPlugin(applicationContext).apply {
            attachActivity(this@MainActivity)
        }

        // 1. MethodChannel: kontrol GNSS dan foreground service
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GnssChannelPlugin.METHOD_CHANNEL_NAME
        ).setMethodCallHandler(gnssPlugin)

        // 2. EventChannel: aliran fix GNSS
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GnssChannelPlugin.FIX_CHANNEL_NAME
        ).setStreamHandler(gnssPlugin.FixStreamHandler())

        // 3. EventChannel: aliran status satelit
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GnssChannelPlugin.STATUS_CHANNEL_NAME
        ).setStreamHandler(gnssPlugin.StatusStreamHandler())

        // 4. EventChannel: aliran kompas
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GnssChannelPlugin.COMPASS_CHANNEL_NAME
        ).setStreamHandler(gnssPlugin.CompassStreamHandler())

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.hikenav/package_control"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStorageStats" -> {
                    val stat = StatFs(applicationContext.filesDir.absolutePath)
                    val blockSize = stat.blockSizeLong
                    val availableBytes = stat.availableBlocksLong * blockSize
                    val totalBytes = stat.blockCountLong * blockSize
                    result.success(
                        mapOf(
                            "availableBytes" to availableBytes,
                            "totalBytes" to totalBytes
                        )
                    )
                }
                "openStorageSettings" -> {
                    val intent = android.content.Intent(
                        android.provider.Settings.ACTION_INTERNAL_STORAGE_SETTINGS
                    ).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (::gnssPlugin.isInitialized &&
            gnssPlugin.onRequestPermissionsResult(requestCode, grantResults)
        ) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        if (::gnssPlugin.isInitialized) {
            gnssPlugin.attachActivity(null)
        }
        super.onDestroy()
    }
}
