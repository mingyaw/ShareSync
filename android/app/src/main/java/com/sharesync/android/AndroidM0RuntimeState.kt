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

    fun readiness(): AndroidPhotoSyncReadiness {
        if (!hasMediaPermission) {
            return AndroidPhotoSyncReadiness(
                primaryAction = AndroidPhotoSyncPrimaryAction.ALLOW_PHOTOS,
                blockingReason = AndroidPhotoSyncBlockingReason.PHOTO_PERMISSION_REQUIRED,
                canSharePhotos = false,
            )
        }

        if (isServerStarting) {
            return AndroidPhotoSyncReadiness(
                primaryAction = AndroidPhotoSyncPrimaryAction.WAIT_FOR_SERVER,
                blockingReason = AndroidPhotoSyncBlockingReason.SERVER_STARTING,
                canSharePhotos = false,
            )
        }

        if (!isServerRunning) {
            return AndroidPhotoSyncReadiness(
                primaryAction = AndroidPhotoSyncPrimaryAction.START_SHARING,
                blockingReason = AndroidPhotoSyncBlockingReason.SERVER_STOPPED,
                canSharePhotos = true,
            )
        }

        val manifestStatus = manifestStatus()
        return AndroidPhotoSyncReadiness(
            primaryAction = when (manifestStatus) {
                AndroidM0ManifestStatus.COMPLETE -> AndroidPhotoSyncPrimaryAction.WAIT_FOR_NEW_PHOTOS
                AndroidM0ManifestStatus.NEEDS_RETRY -> AndroidPhotoSyncPrimaryAction.KEEP_AVAILABLE_FOR_RETRY
                AndroidM0ManifestStatus.READY,
                null,
                -> AndroidPhotoSyncPrimaryAction.SHOW_PAIRING_CODE
            },
            blockingReason = null,
            canSharePhotos = true,
        )
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

data class AndroidPhotoSyncReadiness(
    val primaryAction: AndroidPhotoSyncPrimaryAction,
    val blockingReason: AndroidPhotoSyncBlockingReason?,
    val canSharePhotos: Boolean,
) {
    val recoveryGuidance: AndroidPhotoSyncRecoveryGuidance
        get() = when (primaryAction) {
            AndroidPhotoSyncPrimaryAction.ALLOW_PHOTOS -> AndroidPhotoSyncRecoveryGuidance.ALLOW_ANDROID_PHOTOS
            AndroidPhotoSyncPrimaryAction.START_SHARING -> AndroidPhotoSyncRecoveryGuidance.START_ANDROID_SHARING
            AndroidPhotoSyncPrimaryAction.WAIT_FOR_SERVER -> AndroidPhotoSyncRecoveryGuidance.WAIT_FOR_ANDROID_SERVER
            AndroidPhotoSyncPrimaryAction.SHOW_PAIRING_CODE -> AndroidPhotoSyncRecoveryGuidance.SCAN_PAIRING_CODE
            AndroidPhotoSyncPrimaryAction.KEEP_AVAILABLE_FOR_RETRY -> AndroidPhotoSyncRecoveryGuidance.KEEP_ANDROID_OPEN_FOR_RETRY
            AndroidPhotoSyncPrimaryAction.WAIT_FOR_NEW_PHOTOS -> AndroidPhotoSyncRecoveryGuidance.WAIT_FOR_NEW_ANDROID_PHOTOS
        }
}

enum class AndroidPhotoSyncPrimaryAction {
    ALLOW_PHOTOS,
    START_SHARING,
    WAIT_FOR_SERVER,
    SHOW_PAIRING_CODE,
    KEEP_AVAILABLE_FOR_RETRY,
    WAIT_FOR_NEW_PHOTOS,
}

enum class AndroidPhotoSyncBlockingReason {
    PHOTO_PERMISSION_REQUIRED,
    SERVER_STOPPED,
    SERVER_STARTING,
}

enum class AndroidPhotoSyncRecoveryGuidance {
    ALLOW_ANDROID_PHOTOS,
    START_ANDROID_SHARING,
    WAIT_FOR_ANDROID_SERVER,
    SCAN_PAIRING_CODE,
    KEEP_ANDROID_OPEN_FOR_RETRY,
    WAIT_FOR_NEW_ANDROID_PHOTOS,
}

private val SyncItemStatus.isRetryableFailure: Boolean
    get() = this == SyncItemStatus.failed || this == SyncItemStatus.conflicted
