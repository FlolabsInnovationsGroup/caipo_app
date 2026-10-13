package com.flolabs.caipo.ble

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Keeps the process alive while a CAIPO GATT link is managed.
 * Wi-Fi is not held. BLE is the always-on channel.
 */
class CaipoBleForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val address = intent?.getStringExtra(EXTRA_ADDRESS)
        createChannel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification(address),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification(address))
        }
        if (address != null) {
            CaipoBleManager.instance.connect(address)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun createChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(CHANNEL_ID, "CAIPO connection", NotificationManager.IMPORTANCE_LOW)
        channel.description = "Keeps the CAIPO Bluetooth link alive"
        manager.createNotificationChannel(channel)
    }

    private fun notification(address: String?): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CAIPO connected")
            .setContentText(address ?: "Maintaining the Bluetooth link")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "caipo_ble"
        private const val NOTIFICATION_ID = 42
        private const val EXTRA_ADDRESS = "address"

        fun start(context: Context, address: String) {
            val intent = Intent(context, CaipoBleForegroundService::class.java).putExtra(EXTRA_ADDRESS, address)
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, CaipoBleForegroundService::class.java))
        }
    }
}
