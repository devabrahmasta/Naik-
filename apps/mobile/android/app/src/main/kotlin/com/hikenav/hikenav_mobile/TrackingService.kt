package com.hikenav.hikenav_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Android Foreground Service tipe "location" (US-04).
 * Menjaga proses tetap hidup saat layar mati, sehingga perekaman jejak tidak terputus.
 * Sesuai PRD K4: tidak ada celah > 10 dtk antar fix saat sinyal baik.
 *
 * Diaktifkan/dinonaktifkan dari Flutter melalui GnssChannelPlugin (MethodChannel).
 */
class TrackingService : Service() {

    companion object {
        const val CHANNEL_ID = "hikenav_tracking_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.hikenav.START_TRACKING"
        const val ACTION_STOP = "com.hikenav.STOP_TRACKING"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startForegroundTracking()
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun startForegroundTracking() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("HikeNav Aktif")
            .setContentText("Perekaman jalur berjalan di latar belakang")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "HikeNav Perekaman",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Notifikasi permanen saat perekaman jalur aktif"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
