package com.sharesync.android

import com.sharesync.android.sync.SyncItemStatus
import com.sharesync.android.sync.SyncResult

data class PhotoSharingRuntimeState(
    val hasMediaPermission: Boolean,
    val isServerStarting: Boolean,
    val isServerRunning: Boolean,
    val pendingPhotoCount: Int?,
    val latestSyncResult: SyncResult?,
    val hasConnectedPeer: Boolean = false,
) {
    val hasFailedResult: Boolean
        get() = latestSyncResult?.results?.any { it.status.isRetryableFailure } == true

    fun phase(): PhotoSharingPhase {
        if (!hasMediaPermission) {
            return PhotoSharingPhase.PERMISSION_REQUIRED
        }

        if (isServerStarting) {
            return PhotoSharingPhase.SERVER_STARTING
        }

        if (!isServerRunning) {
            return PhotoSharingPhase.READY_TO_START
        }

        return when {
            pendingPhotoCount == 0 -> PhotoSharingPhase.TRANSFER_COMPLETE
            hasFailedResult -> PhotoSharingPhase.RETRY_REQUIRED
            hasConnectedPeer -> PhotoSharingPhase.IPHONE_CONNECTED
            else -> PhotoSharingPhase.READY_TO_PAIR
        }
    }

    fun manifestStatus(): PhotoManifestStatus? {
        val count = pendingPhotoCount ?: return null
        return when {
            count == 0 -> PhotoManifestStatus.COMPLETE
            hasFailedResult -> PhotoManifestStatus.NEEDS_RETRY
            else -> PhotoManifestStatus.READY
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
                PhotoManifestStatus.COMPLETE -> AndroidPhotoSyncPrimaryAction.WAIT_FOR_NEW_PHOTOS
                PhotoManifestStatus.NEEDS_RETRY -> AndroidPhotoSyncPrimaryAction.KEEP_AVAILABLE_FOR_RETRY
                PhotoManifestStatus.READY,
                null,
                -> if (hasConnectedPeer) {
                    AndroidPhotoSyncPrimaryAction.KEEP_AVAILABLE_FOR_TRANSFER
                } else {
                    AndroidPhotoSyncPrimaryAction.SHOW_PAIRING_CODE
                }
            },
            blockingReason = null,
            canSharePhotos = true,
        )
    }
}

enum class PhotoSharingPhase {
    PERMISSION_REQUIRED,
    READY_TO_START,
    SERVER_STARTING,
    READY_TO_PAIR,
    IPHONE_CONNECTED,
    RETRY_REQUIRED,
    TRANSFER_COMPLETE,
}

enum class PhotoManifestStatus {
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
            AndroidPhotoSyncPrimaryAction.KEEP_AVAILABLE_FOR_TRANSFER -> AndroidPhotoSyncRecoveryGuidance.KEEP_ANDROID_OPEN_FOR_TRANSFER
            AndroidPhotoSyncPrimaryAction.KEEP_AVAILABLE_FOR_RETRY -> AndroidPhotoSyncRecoveryGuidance.KEEP_ANDROID_OPEN_FOR_RETRY
            AndroidPhotoSyncPrimaryAction.WAIT_FOR_NEW_PHOTOS -> AndroidPhotoSyncRecoveryGuidance.WAIT_FOR_NEW_ANDROID_PHOTOS
        }

    val nextStep: AndroidPhotoSyncNextStep
        get() = when (primaryAction) {
            AndroidPhotoSyncPrimaryAction.ALLOW_PHOTOS -> AndroidPhotoSyncNextStep.ALLOW_ANDROID_PHOTOS
            AndroidPhotoSyncPrimaryAction.START_SHARING -> AndroidPhotoSyncNextStep.START_ANDROID_SHARING
            AndroidPhotoSyncPrimaryAction.WAIT_FOR_SERVER -> AndroidPhotoSyncNextStep.WAIT_FOR_ANDROID_SERVER
            AndroidPhotoSyncPrimaryAction.SHOW_PAIRING_CODE -> AndroidPhotoSyncNextStep.SCAN_FROM_IPHONE
            AndroidPhotoSyncPrimaryAction.KEEP_AVAILABLE_FOR_TRANSFER -> AndroidPhotoSyncNextStep.KEEP_ANDROID_OPEN_FOR_TRANSFER
            AndroidPhotoSyncPrimaryAction.KEEP_AVAILABLE_FOR_RETRY -> AndroidPhotoSyncNextStep.KEEP_ANDROID_OPEN_FOR_RETRY
            AndroidPhotoSyncPrimaryAction.WAIT_FOR_NEW_PHOTOS -> AndroidPhotoSyncNextStep.WAIT_FOR_NEW_ANDROID_PHOTOS
        }
}

enum class AndroidPhotoSyncPrimaryAction {
    ALLOW_PHOTOS,
    START_SHARING,
    WAIT_FOR_SERVER,
    SHOW_PAIRING_CODE,
    KEEP_AVAILABLE_FOR_TRANSFER,
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
    KEEP_ANDROID_OPEN_FOR_TRANSFER,
    KEEP_ANDROID_OPEN_FOR_RETRY,
    WAIT_FOR_NEW_ANDROID_PHOTOS,
}

enum class AndroidPhotoSyncNextStep {
    ALLOW_ANDROID_PHOTOS,
    START_ANDROID_SHARING,
    WAIT_FOR_ANDROID_SERVER,
    SCAN_FROM_IPHONE,
    KEEP_ANDROID_OPEN_FOR_TRANSFER,
    KEEP_ANDROID_OPEN_FOR_RETRY,
    WAIT_FOR_NEW_ANDROID_PHOTOS,
}

private val SyncItemStatus.isRetryableFailure: Boolean
    get() = this == SyncItemStatus.failed || this == SyncItemStatus.conflicted
