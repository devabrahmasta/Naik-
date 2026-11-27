package com.hikenav.hikenav_mobile

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.GnssStatus
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Plugin native yang mengelola tiga channel komunikasi antara Kotlin dan Flutter (Dart):
 *
 * - [METHOD_CHANNEL_NAME]   : start/stop TrackingService (MethodChannel)
 * - [FIX_CHANNEL_NAME]      : aliran fix GNSS mentah dari GPS_PROVIDER (EventChannel)
 * - [COMPASS_CHANNEL_NAME]  : aliran derajat azimuth dari sensor magnetometer (EventChannel)
 *
 * Sesuai kontrak platform channel yang didefinisikan di CLAUDE.md dan core/platform/gnss_channel.dart.
 * Menggunakan LocationManager.GPS_PROVIDER (non-fused) sesuai PRD Bagian 4.
 */
class GnssChannelPlugin(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL_NAME = "com.hikenav/gnss_control"
        const val FIX_CHANNEL_NAME = "com.hikenav/gnss_fix_stream"
        const val COMPASS_CHANNEL_NAME = "com.hikenav/compass_stream"

        private const val MIN_INTERVAL_MS = 2000L  // L0 PRD: interval sampel 2 dtk
        private const val MIN_DISTANCE_M = 0f      // Semua fix dikirim; gating dilakukan di Dart/geo_core
    }

    private val locationManager: LocationManager =
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val sensorManager: SensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    // Event sinks untuk dua EventChannel
    private var fixEventSink: EventChannel.EventSink? = null
    private var compassEventSink: EventChannel.EventSink? = null

    // -------------------------------------------------------------------------
    // LocationListener: GPS_PROVIDER (non-fused, sesuai PRD)
    // -------------------------------------------------------------------------
    private val locationListener = LocationListener { location ->
        val fixMap = locationToMap(location)
        fixEventSink?.success(fixMap)
    }

    // -------------------------------------------------------------------------
    // GnssStatus.Callback: data satelit (US-01)
    // -------------------------------------------------------------------------
    private var gnssStatusCallback: GnssStatus.Callback? = null

    // -------------------------------------------------------------------------
    // SensorEventListener: Magnetometer + Accelerometer -> Azimuth (US-11)
    // -------------------------------------------------------------------------
    private val gravity = FloatArray(3)
    private val geomagnetic = FloatArray(3)

    private val sensorListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            when (event.sensor.type) {
                Sensor.TYPE_ACCELEROMETER ->
                    System.arraycopy(event.values, 0, gravity, 0, 3)
                Sensor.TYPE_MAGNETIC_FIELD ->
                    System.arraycopy(event.values, 0, geomagnetic, 0, 3)
            }
            val rotationMatrix = FloatArray(9)
            if (SensorManager.getRotationMatrix(rotationMatrix, null, gravity, geomagnetic)) {
                val orientation = FloatArray(3)
                SensorManager.getOrientation(rotationMatrix, orientation)
                val azimuthDeg = ((Math.toDegrees(orientation[0].toDouble()) + 360) % 360)
                compassEventSink?.success(azimuthDeg)
            }
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
            // Kirim event akurasi sensor rendah jika dibutuhkan (US-11)
        }
    }

    // -------------------------------------------------------------------------
    // MethodChannel.MethodCallHandler: start/stop TrackingService
    // -------------------------------------------------------------------------
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startTrackingService" -> {
                startLocationUpdates()
                startCompassUpdates()
                val intent = Intent(context, TrackingService::class.java).apply {
                    action = TrackingService.ACTION_START
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                result.success(true)
            }
            "stopTrackingService" -> {
                stopLocationUpdates()
                stopCompassUpdates()
                val intent = Intent(context, TrackingService::class.java).apply {
                    action = TrackingService.ACTION_STOP
                }
                context.startService(intent)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // EventChannel.StreamHandler: dipakai oleh FIX_CHANNEL dan COMPASS_CHANNEL
    // Registrasi dibedakan berdasarkan channel name di MainActivity
    // -------------------------------------------------------------------------
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        // Implementasi dibagi oleh FixStreamHandler dan CompassStreamHandler di bawah
    }

    override fun onCancel(arguments: Any?) {
        // idem
    }

    // -------------------------------------------------------------------------
    // Fix EventChannel Handler
    // -------------------------------------------------------------------------
    inner class FixStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            fixEventSink = events
        }

        override fun onCancel(arguments: Any?) {
            fixEventSink = null
        }
    }

    // -------------------------------------------------------------------------
    // Compass EventChannel Handler
    // -------------------------------------------------------------------------
    inner class CompassStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            compassEventSink = events
        }

        override fun onCancel(arguments: Any?) {
            compassEventSink = null
        }
    }

    // -------------------------------------------------------------------------
    // Location updates
    // -------------------------------------------------------------------------
    private fun startLocationUpdates() {
        if (!hasLocationPermission()) return

        @Suppress("MissingPermission")
        locationManager.requestLocationUpdates(
            LocationManager.GPS_PROVIDER,
            MIN_INTERVAL_MS,
            MIN_DISTANCE_M,
            locationListener,
            Looper.getMainLooper()
        )

        // Daftarkan GnssStatus.Callback untuk data satelit (US-01)
        gnssStatusCallback = object : GnssStatus.Callback() {
            override fun onSatelliteStatusChanged(status: GnssStatus) {
                // Data satelit disimpan untuk dikirimkan bersama fix berikutnya jika diperlukan
            }
        }
        @Suppress("MissingPermission")
        locationManager.registerGnssStatusCallback(gnssStatusCallback!!, null)
    }

    private fun stopLocationUpdates() {
        locationManager.removeUpdates(locationListener)
        gnssStatusCallback?.let { locationManager.unregisterGnssStatusCallback(it) }
        gnssStatusCallback = null
    }

    // -------------------------------------------------------------------------
    // Compass updates
    // -------------------------------------------------------------------------
    private fun startCompassUpdates() {
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        val magnetometer = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        if (accelerometer != null && magnetometer != null) {
            sensorManager.registerListener(sensorListener, accelerometer, SensorManager.SENSOR_DELAY_UI)
            sensorManager.registerListener(sensorListener, magnetometer, SensorManager.SENSOR_DELAY_UI)
        }
    }

    private fun stopCompassUpdates() {
        sensorManager.unregisterListener(sensorListener)
    }

    // -------------------------------------------------------------------------
    // Helper: Location -> Map sesuai kontrak CLAUDE.md
    // -------------------------------------------------------------------------
    private fun locationToMap(loc: Location): Map<String, Any> {
        return mapOf(
            "latitude" to loc.latitude,
            "longitude" to loc.longitude,
            "altitude" to loc.altitude,
            "accuracy" to loc.accuracy.toDouble(),
            "speed" to loc.speed.toDouble(),
            "bearing" to loc.bearing.toDouble(),
            "satellitesUsed" to (loc.extras?.getInt("satellites", 0) ?: 0),
            "satellitesVisible" to 0,
            "timestamp" to loc.time,
            "isMock" to loc.isMock
        )
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }
}
