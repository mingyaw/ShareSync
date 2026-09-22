package com.sharesync.android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

class PhotoSharingService : Service() {
    private var notificationState = NotificationState.WAITING

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        notificationState = intent
            ?.getStringExtra(EXTRA_NOTIFICATION_STATE)
            ?.let { value -> NotificationState.entries.firstOrNull { it.name == value } }
            ?: notificationState
        startForeground(NOTIFICATION_ID, buildNotification(notificationState))
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        val activeSession = PhotoSharingSessionRegistry.current
        if (activeSession != null) {
            Thread {
                PhotoSharingSessionController.stop(activeSession)
            }.start()
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.sync_foreground_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = getString(R.string.sync_foreground_channel_description)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun buildNotification(state: NotificationState): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.drawable.ic_nav_sync)
            .setContentTitle(getString(R.string.sync_foreground_notification_title))
            .setContentText(getString(state.messageRes))
            .setContentIntent(openMainActivityIntent())
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOngoing(true)
            .build()
    }

    private fun openMainActivityIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            this,
            OPEN_MAIN_ACTIVITY_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentImmutableFlag(),
        )
    }

    companion object {
        private const val CHANNEL_ID = "sharesync_photo_transfer"
        private const val NOTIFICATION_ID = 48291
        private const val OPEN_MAIN_ACTIVITY_REQUEST_CODE = 48292
        private const val ACTION_START = "com.sharesync.android.action.START_PHOTO_SHARING"
        private const val ACTION_UPDATE = "com.sharesync.android.action.UPDATE_PHOTO_SHARING"
        private const val EXTRA_NOTIFICATION_STATE = "notification_state"

        private fun pendingIntentImmutableFlag(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        }

        fun start(context: Context) {
            val intent = Intent(context, PhotoSharingService::class.java)
                .setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, PhotoSharingService::class.java))
        }

        fun update(context: Context, state: NotificationState) {
            val intent = Intent(context, PhotoSharingService::class.java)
                .setAction(ACTION_UPDATE)
                .putExtra(EXTRA_NOTIFICATION_STATE, state.name)
            context.startService(intent)
        }
    }
}

enum class NotificationState(val messageRes: Int) {
    WAITING(R.string.sync_foreground_notification_waiting),
    CONNECTED(R.string.sync_foreground_notification_connected),
    COMPLETE(R.string.sync_foreground_notification_complete),
    ATTENTION(R.string.sync_foreground_notification_attention),
    ;

    companion object {
        fun from(hasConnectedPeer: Boolean, hasSyncResult: Boolean, hasFailures: Boolean): NotificationState {
            return when {
                hasFailures -> ATTENTION
                hasSyncResult -> COMPLETE
                hasConnectedPeer -> CONNECTED
                else -> WAITING
            }
        }
    }
}
