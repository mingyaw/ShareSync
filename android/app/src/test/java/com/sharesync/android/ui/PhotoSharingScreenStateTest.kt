package com.sharesync.android.ui

import com.sharesync.android.PhotoSharingPhase
import com.sharesync.android.PhotoSharingRuntimeState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PhotoSharingScreenStateTest {
    @Test
    fun permissionStateShowsOnlyPhotoAccessAction() {
        val state = screenState(runtime(hasPermission = false))

        assertEquals(PhotoSharingPhase.PERMISSION_REQUIRED, state.phase)
        assertTrue(state.showPhotoAccessAction)
        assertFalse(state.showStartAction)
        assertFalse(state.showStopAction)
        assertFalse(state.showPairingPanel)
    }

    @Test
    fun startingStateDisablesStartAction() {
        val state = screenState(runtime(hasPermission = true, isStarting = true))

        assertEquals(PhotoSharingPhase.SERVER_STARTING, state.phase)
        assertTrue(state.showStartAction)
        assertFalse(state.startActionEnabled)
        assertFalse(state.showPairingPanel)
    }

    @Test
    fun runningStateShowsPairingAndSupportActions() {
        val state = screenState(
            runtime(hasPermission = true, isRunning = true),
            hasEndpoint = true,
            hasPairingPayload = true,
            hasSyncResult = true,
        )

        assertTrue(state.showStopAction)
        assertTrue(state.stopActionEnabled)
        assertTrue(state.showPairingPanel)
        assertTrue(state.copyEndpointEnabled)
        assertTrue(state.copyPairingEnabled)
        assertTrue(state.copySyncResultEnabled)
    }

    private fun runtime(
        hasPermission: Boolean,
        isStarting: Boolean = false,
        isRunning: Boolean = false,
    ): PhotoSharingRuntimeState {
        return PhotoSharingRuntimeState(
            hasMediaPermission = hasPermission,
            isServerStarting = isStarting,
            isServerRunning = isRunning,
            pendingPhotoCount = null,
            latestSyncResult = null,
        )
    }

    private fun screenState(
        runtime: PhotoSharingRuntimeState,
        hasEndpoint: Boolean = false,
        hasPairingPayload: Boolean = false,
        hasSyncResult: Boolean = false,
    ): PhotoSharingScreenState {
        return PhotoSharingScreenState.from(
            runtime = runtime,
            hasEndpoint = hasEndpoint,
            hasPairingPayload = hasPairingPayload,
            hasSyncResult = hasSyncResult,
        )
    }
}
