package com.sharesync.android

import com.sharesync.android.sync.SyncItemResult
import com.sharesync.android.sync.SyncItemStatus
import com.sharesync.android.sync.SyncItemType
import com.sharesync.android.sync.SyncResult
import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidM0RuntimeStateTest {
    @Test
    fun phaseRequiresPermissionBeforeServerWork() {
        val state = runtimeState(
            hasMediaPermission = false,
            isServerStarting = true,
            isServerRunning = true,
        )

        assertEquals(AndroidM0Phase.PERMISSION_REQUIRED, state.phase())
    }

    @Test
    fun phaseShowsServerStartingAfterPermission() {
        val state = runtimeState(
            isServerStarting = true,
            isServerRunning = false,
        )

        assertEquals(AndroidM0Phase.SERVER_STARTING, state.phase())
    }

    @Test
    fun phaseShowsReadyToStartWhenServerIsStopped() {
        val state = runtimeState(isServerRunning = false)

        assertEquals(AndroidM0Phase.READY_TO_START, state.phase())
    }

    @Test
    fun phaseShowsReadyToPairWhenServerRunsWithPendingPhotos() {
        val state = runtimeState(
            isServerRunning = true,
            pendingPhotoCount = 12,
        )

        assertEquals(AndroidM0Phase.READY_TO_PAIR, state.phase())
    }

    @Test
    fun phaseShowsRetryRequiredWhenLatestResultHasFailure() {
        val state = runtimeState(
            isServerRunning = true,
            pendingPhotoCount = 3,
            latestSyncResult = syncResult(syncItem("photo-001", SyncItemStatus.failed)),
        )

        assertEquals(AndroidM0Phase.RETRY_REQUIRED, state.phase())
    }

    @Test
    fun phaseShowsRetryRequiredWhenLatestResultHasConflict() {
        val state = runtimeState(
            isServerRunning = true,
            pendingPhotoCount = 3,
            latestSyncResult = syncResult(syncItem("photo-001", SyncItemStatus.conflicted)),
        )

        assertEquals(AndroidM0Phase.RETRY_REQUIRED, state.phase())
    }

    @Test
    fun phaseShowsTransferCompleteWhenNoPhotosRemainPending() {
        val state = runtimeState(
            isServerRunning = true,
            pendingPhotoCount = 0,
            latestSyncResult = syncResult(syncItem("photo-001", SyncItemStatus.synced)),
        )

        assertEquals(AndroidM0Phase.TRANSFER_COMPLETE, state.phase())
    }

    @Test
    fun manifestStatusIsUnavailableBeforeManifestCountExists() {
        val state = runtimeState(pendingPhotoCount = null)

        assertEquals(null, state.manifestStatus())
    }

    @Test
    fun manifestStatusUsesPendingCountAndLatestFailure() {
        assertEquals(
            AndroidM0ManifestStatus.READY,
            runtimeState(pendingPhotoCount = 4).manifestStatus(),
        )
        assertEquals(
            AndroidM0ManifestStatus.NEEDS_RETRY,
            runtimeState(
                pendingPhotoCount = 4,
                latestSyncResult = syncResult(syncItem("photo-001", SyncItemStatus.failed)),
            ).manifestStatus(),
        )
        assertEquals(
            AndroidM0ManifestStatus.NEEDS_RETRY,
            runtimeState(
                pendingPhotoCount = 4,
                latestSyncResult = syncResult(syncItem("photo-001", SyncItemStatus.conflicted)),
            ).manifestStatus(),
        )
        assertEquals(
            AndroidM0ManifestStatus.COMPLETE,
            runtimeState(
                pendingPhotoCount = 0,
                latestSyncResult = syncResult(syncItem("photo-001", SyncItemStatus.failed)),
            ).manifestStatus(),
        )
    }

    private fun runtimeState(
        hasMediaPermission: Boolean = true,
        isServerStarting: Boolean = false,
        isServerRunning: Boolean = false,
        pendingPhotoCount: Int? = null,
        latestSyncResult: SyncResult? = null,
    ): AndroidM0RuntimeState {
        return AndroidM0RuntimeState(
            hasMediaPermission = hasMediaPermission,
            isServerStarting = isServerStarting,
            isServerRunning = isServerRunning,
            pendingPhotoCount = pendingPhotoCount,
            latestSyncResult = latestSyncResult,
        )
    }

    private fun syncResult(vararg items: SyncItemResult): SyncResult {
        return SyncResult(
            syncBatchId = "batch-001",
            targetDeviceId = "ios-device-001",
            results = items.toList(),
        )
    }

    private fun syncItem(sourceItemId: String, status: SyncItemStatus): SyncItemResult {
        return SyncItemResult(
            itemType = SyncItemType.media,
            sourceItemId = sourceItemId,
            targetItemId = null,
            status = status,
            errorCode = if (status == SyncItemStatus.failed || status == SyncItemStatus.conflicted) "SS-NET-002" else null,
        )
    }
}
