package com.hikenav.hikenav_mobile

import android.Manifest
import android.app.Activity
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
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Plugin native yang mengelola empat channel komunikasi antara Kotlin dan Flutter (Dart):
 *
 * - [METHOD_CHANNEL_NAME]   : kontrol izin, pengaturan lokasi, monitoring, dan TrackingService
 * - [FIX_CHANNEL_NAME]      : aliran fix GNSS mentah dari GPS_PROVIDER (EventChannel)
 * - [STATUS_CHANNEL_NAME]   : aliran status satelit GnssStatus (US-01) (EventChannel)
 * - [COMPASS_CHANNEL_NAME]  : aliran derajat azimuth dari sensor magnetometer (EventChannel)
 *
 * Menggunakan LocationManager.GPS_PROVIDER (non-fused) sesuai PRD Bagian 4.
 */
class GnssChannelPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val METHOD_CHANNEL_NAME = "com.hikenav/gnss_control"
        const val FIX_CHANNEL_NAME = "com.hikenav/gnss_fix_stream"
        const val STATUS_CHANNEL_NAME = "com.hikenav/gnss_status_stream"
        const val COMPASS_CHANNEL_NAME = "com.hikenav/compass_stream"

        private const val MIN_INTERVAL_MS = 2000L // L0 PRD: interval sampel 2 dtk
        private const val MIN_DISTANCE_M = 0f     // Semua fix dikirim; gating dilakukan di Dart/geo_core
        private const val REQUEST_CODE_LOCATION = 4001
    }

    private val locationManager: LocationManager =
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val sensorManager: SensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activity: Activity? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private var fixEventSink: EventChannel.EventSink? = null
    private var statusEventSink: EventChannel.EventSink? = null
    private var compassEventSink: EventChannel.EventSink? = null

    private var isLocationUpdatesActive = false
    private var isMonitoringActive = false
    private var isTrackingActive = false

    private var latestSatellitesUsed = 0
    private var latestSatellitesVisible = 0

    fun attachActivity(activity: Activity?) {
        this.activity = activity
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_CODE_LOCATION) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        if (granted && (isMonitoringActive || isTrackingActive)) {
            ensureLocationUpdatesStarted()
        }
        return true
    }

    // -------------------------------------------------------------------------
    // LocationListener: GPS_PROVIDER (non-fused, sesuai PRD)
    // -------------------------------------------------------------------------
    private val locationListener = LocationListener { location ->
        val fixMap = locationToMap(location)
        mainHandler.post {
            fixEventSink?.success(fixMap)
        }
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
            // Akurasi sensor kompas ditangani pada layer UI US-11
        }
    }

    // -------------------------------------------------------------------------
    // MethodChannel.MethodCallHandler
    // -------------------------------------------------------------------------
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getGnssState" -> {
                result.success(
                    mapOf(
                        "hasPermission" to hasLocationPermission(),
                        "isGpsEnabled" to isGpsEnabled(),
                        "isTracking" to isTrackingActive,
                        "isMonitoring" to isMonitoringActive
                    )
                )
            }
            "requestLocationPermission" -> {
                if (hasLocationPermission()) {
                    result.success(true)
                    return
                }
                val currentActivity = activity
                if (currentActivity == null) {
                    result.success(false)
                    return
                }
                pendingPermissionResult?.success(false)
                pendingPermissionResult = result
                ActivityCompat.requestPermissions(
                    currentActivity,
                    arrayOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    ),
                    REQUEST_CODE_LOCATION
                )
            }
            "openLocationSettings" -> {
                val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                result.success(true)
            }
            "openAppSettings" -> {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", context.packageName, null)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                result.success(true)
            }
            "startGnssMonitoring" -> {
                isMonitoringActive = true
                ensureLocationUpdatesStarted()
                startCompassUpdates()
                result.success(hasLocationPermission() && isGpsEnabled())
            }
            "stopGnssMonitoring" -> {
                isMonitoringActive = false
                if (!isTrackingActive) {
                    stopLocationUpdates()
                    stopCompassUpdates()
                }
                result.success(true)
            }
            "startTrackingService" -> {
                isTrackingActive = true
                ensureLocationUpdatesStarted()
                startCompassUpdates()
                val intent = Intent(context, TrackingService::class.java).apply {
                    action = TrackingService.ACTION_START
                }
                context.startForegroundService(intent)
                result.success(true)
            }
            "stopTrackingService" -> {
                isTrackingActive = false
                if (!isMonitoringActive) {
                    stopLocationUpdates()
                    stopCompassUpdates()
                }
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
    // EventChannel StreamHandlers
    // -------------------------------------------------------------------------
    inner class FixStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            fixEventSink = events
        }

        override fun onCancel(arguments: Any?) {
            fixEventSink = null
        }
    }

    inner class StatusStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            statusEventSink = events
        }

        override fun onCancel(arguments: Any?) {
            statusEventSink = null
        }
    }

    inner class CompassStreamHandler : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            compassEventSink = events
        }

        override fun onCancel(arguments: Any?) {
            compassEventSink = null
        }
    }

    // -------------------------------------------------------------------------
    // Location & GnssStatus updates
    // -------------------------------------------------------------------------
    private fun ensureLocationUpdatesStarted() {
        if (isLocationUpdatesActive) return
        if (!hasLocationPermission() || !isGpsEnabled()) return

        @Suppress("MissingPermission")
        locationManager.requestLocationUpdates(
            LocationManager.GPS_PROVIDER,
            MIN_INTERVAL_MS,
            MIN_DISTANCE_M,
            locationListener,
            Looper.getMainLooper()
        )

        val callback = object : GnssStatus.Callback() {
            override fun onSatelliteStatusChanged(status: GnssStatus) {
                val snapshotMap = gnssStatusToMap(status)
                mainHandler.post {
                    statusEventSink?.success(snapshotMap)
                }
            }
        }
        gnssStatusCallback = callback

        @Suppress("MissingPermission")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            locationManager.registerGnssStatusCallback(context.mainExecutor, callback)
        } else {
            @Suppress("DEPRECATION")
            locationManager.registerGnssStatusCallback(callback, mainHandler)
        }

        isLocationUpdatesActive = true
    }

    private fun stopLocationUpdates() {
        if (!isLocationUpdatesActive) return
        locationManager.removeUpdates(locationListener)
        gnssStatusCallback?.let { locationManager.unregisterGnssStatusCallback(it) }
        gnssStatusCallback = null
        isLocationUpdatesActive = false
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
    // Mappers
    // -------------------------------------------------------------------------
    private fun gnssStatusToMap(status: GnssStatus): Map<String, Any> {
        val count = status.satelliteCount
        var usedCount = 0
        val satellites = ArrayList<Map<String, Any>>(count)

        for (i in 0 until count) {
            val used = status.usedInFix(i)
            if (used) usedCount++

            satellites.add(
                mapOf(
                    "svid" to status.getSvid(i),
                    "constellation" to status.getConstellationType(i),
                    "cn0DbHz" to status.getCn0DbHz(i).toDouble(),
                    "azimuthDegrees" to status.getAzimuthDegrees(i).toDouble(),
                    "elevationDegrees" to status.getElevationDegrees(i).toDouble(),
                    "usedInFix" to used,
                    "hasAlmanac" to status.hasAlmanacData(i),
                    "hasEphemeris" to status.hasEphemerisData(i)
                )
            )
        }

        latestSatellitesUsed = usedCount
        latestSatellitesVisible = count

        return mapOf(
            "timestamp" to System.currentTimeMillis(),
            "satellites" to satellites
        )
    }

    private fun locationToMap(loc: Location): Map<String, Any> {
        val isMockLocation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            loc.isMock
        } else {
            @Suppress("DEPRECATION")
            loc.isFromMockProvider
        }

        val usedFromExtras = loc.extras?.getInt("satellites", 0) ?: 0
        val satellitesUsed = if (latestSatellitesUsed > 0) latestSatellitesUsed else usedFromExtras

        return mapOf(
            "latitude" to loc.latitude,
            "longitude" to loc.longitude,
            "altitude" to loc.altitude,
            "accuracy" to loc.accuracy.toDouble(),
            "speed" to loc.speed.toDouble(),
            "bearing" to loc.bearing.toDouble(),
            "satellitesUsed" to satellitesUsed,
            "satellitesVisible" to latestSatellitesVisible,
            "timestamp" to loc.time,
            "isMock" to isMockLocation
        )
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun isGpsEnabled(): Boolean {
        return locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
    }
}
