package com.sharesync.android.support

import com.sharesync.android.PhotoSharingTransportSecurityMode
import com.sharesync.android.sync.SyncItemStatus
import com.sharesync.android.sync.SyncResult
import com.sharesync.android.transfer.server.LocalRequestActivity
import org.json.JSONObject

data class AndroidSupportSnapshotInput(
    val generatedAt: String,
    val appVersion: String,
    val buildNumber: Int,
    val phase: String,
    val nextStep: String,
    val transportSecurityMode: PhotoSharingTransportSecurityMode,
    val endpoint: String?,
    val hasMediaPermission: Boolean,
    val hasNotificationPermission: Boolean,
    val isServerRunning: Boolean,
    val pendingPhotoCount: Int?,
    val requestActivity: LocalRequestActivity?,
    val syncResult: SyncResult?,
)

class AndroidSupportSnapshotBuilder {
    fun build(input: AndroidSupportSnapshotInput): String {
        val result = input.syncResult
        val latestSynced = result?.results?.count { it.status == SyncItemStatus.synced } ?: 0
        val latestSkipped = result?.results?.count { it.status == SyncItemStatus.skipped } ?: 0
        val latestFailed = result?.results?.count {
            it.status == SyncItemStatus.failed || it.status == SyncItemStatus.conflicted
        } ?: 0

        return JSONObject()
            .put("schemaVersion", 1)
            .put("type", "sharesync_support_snapshot")
            .put("platform", "android")
            .put("generatedAt", input.generatedAt)
            .put("appVersion", input.appVersion)
            .put("buildNumber", input.buildNumber)
            .put("phase", input.phase)
            .put("nextStep", input.nextStep)
            .put("transport", input.transportSecurityMode.name)
            .put("endpoint", input.endpoint ?: JSONObject.NULL)
            .put(
                "permissions",
                JSONObject()
                    .put("media", input.hasMediaPermission)
                    .put("notification", input.hasNotificationPermission),
            )
            .put(
                "android",
                JSONObject()
                    .put("serverRunning", input.isServerRunning)
                    .put("pendingPhotos", input.pendingPhotoCount ?: JSONObject.NULL),
            )
            .put(
                "latestRequest",
                JSONObject()
                    .put("endpoint", input.requestActivity?.endpoint ?: JSONObject.NULL)
                    .put("statusCode", input.requestActivity?.statusCode ?: JSONObject.NULL),
            )
            .put(
                "sync",
                JSONObject()
                    .put("latestBatch", result?.syncBatchId ?: JSONObject.NULL)
                    .put("synced", latestSynced)
                    .put("skipped", latestSkipped)
                    .put("failed", latestFailed),
            )
            .put(
                "redaction",
                JSONObject()
                    .put("pairingToken", "excluded")
                    .put("requestSignature", "excluded")
                    .put("sharedSecret", "excluded"),
            )
            .toString(2)
    }
}
