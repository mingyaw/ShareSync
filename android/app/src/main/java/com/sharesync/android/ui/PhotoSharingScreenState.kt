package com.sharesync.android.ui

import com.sharesync.android.PhotoSharingPhase
import com.sharesync.android.PhotoSharingRuntimeState

data class PhotoSharingScreenState(
    val phase: PhotoSharingPhase,
    val showPhotoAccessAction: Boolean,
    val showStartAction: Boolean,
    val showStopAction: Boolean,
    val startActionEnabled: Boolean,
    val stopActionEnabled: Boolean,
    val showPairingPanel: Boolean,
    val copyEndpointEnabled: Boolean,
    val copyPairingEnabled: Boolean,
    val copySyncResultEnabled: Boolean,
) {
    companion object {
        fun from(
            runtime: PhotoSharingRuntimeState,
            hasEndpoint: Boolean,
            hasPairingPayload: Boolean,
            hasSyncResult: Boolean,
        ): PhotoSharingScreenState {
            return PhotoSharingScreenState(
                phase = runtime.phase(),
                showPhotoAccessAction = !runtime.hasMediaPermission,
                showStartAction = runtime.hasMediaPermission && !runtime.isServerRunning,
                showStopAction = runtime.isServerRunning,
                startActionEnabled = runtime.hasMediaPermission &&
                    !runtime.isServerRunning &&
                    !runtime.isServerStarting,
                stopActionEnabled = runtime.isServerRunning,
                showPairingPanel = runtime.isServerRunning && hasPairingPayload,
                copyEndpointEnabled = hasEndpoint,
                copyPairingEnabled = hasPairingPayload,
                copySyncResultEnabled = hasSyncResult,
            )
        }
    }
}
