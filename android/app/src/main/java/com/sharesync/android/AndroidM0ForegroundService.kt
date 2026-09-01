package com.sharesync.android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

class AndroidM0ForegroundService : Service() {
    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> startForeground(NOTIFICATION_ID, buildNotification())
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.m0_foreground_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.m0_foreground_channel_description)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle(getString(R.string.m0_foreground_notification_title))
            .setContentText(getString(R.string.m0_foreground_notification_text))
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "sharesync_m0_transfer"
        private const val NOTIFICATION_ID = 48291
        private const val ACTION_START = "com.sharesync.android.action.START_M0_FOREGROUND"
        private const val ACTION_STOP = "com.sharesync.android.action.STOP_M0_FOREGROUND"

        fun start(context: Context) {
            val intent = Intent(context, AndroidM0ForegroundService::class.java)
                .setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, AndroidM0ForegroundService::class.java)
                .setAction(ACTION_STOP)
            context.startService(intent)
        }
    }
}
