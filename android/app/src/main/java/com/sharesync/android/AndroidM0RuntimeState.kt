package com.sharesync.android

import com.sharesync.android.sync.SyncItemStatus
import com.sharesync.android.sync.SyncResult

data class AndroidM0RuntimeState(
    val hasMediaPermission: Boolean,
    val isServerStarting: Boolean,
    val isServerRunning: Boolean,
    val pendingPhotoCount: Int?,
    val latestSyncResult: SyncResult?,
) {
    val hasFailedResult: Boolean
        get() = latestSyncResult?.results?.any { it.status.isRetryableFailure } == true

    fun phase(): AndroidM0Phase {
        if (!hasMediaPermission) {
            return AndroidM0Phase.PERMISSION_REQUIRED
        }

        if (isServerStarting) {
            return AndroidM0Phase.SERVER_STARTING
        }

        if (!isServerRunning) {
            return AndroidM0Phase.READY_TO_START
        }

        return when {
            pendingPhotoCount == 0 -> AndroidM0Phase.TRANSFER_COMPLETE
            hasFailedResult -> AndroidM0Phase.RETRY_REQUIRED
            else -> AndroidM0Phase.READY_TO_PAIR
        }
    }

    fun manifestStatus(): AndroidM0ManifestStatus? {
        val count = pendingPhotoCount ?: return null
        return when {
            count == 0 -> AndroidM0ManifestStatus.COMPLETE
            hasFailedResult -> AndroidM0ManifestStatus.NEEDS_RETRY
            else -> AndroidM0ManifestStatus.READY
        }
    }
}

enum class AndroidM0Phase {
    PERMISSION_REQUIRED,
    READY_TO_START,
    SERVER_STARTING,
    READY_TO_PAIR,
    RETRY_REQUIRED,
    TRANSFER_COMPLETE,
}

enum class AndroidM0ManifestStatus {
    READY,
    COMPLETE,
    NEEDS_RETRY,
}

private val SyncItemStatus.isRetryableFailure: Boolean
    get() = this == SyncItemStatus.failed || this == SyncItemStatus.conflicted
