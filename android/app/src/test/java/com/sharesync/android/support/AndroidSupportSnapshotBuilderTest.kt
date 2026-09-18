package com.sharesync.android.support

import com.sharesync.android.PhotoSharingTransportSecurityMode
import com.sharesync.android.sync.SyncItemResult
import com.sharesync.android.sync.SyncItemStatus
import com.sharesync.android.sync.SyncItemType
import com.sharesync.android.sync.SyncResult
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AndroidSupportSnapshotBuilderTest {
    @Test
    fun buildSummarizesResultsAndExcludesSecrets() {
        val json = AndroidSupportSnapshotBuilder().build(
            AndroidSupportSnapshotInput(
                generatedAt = "2026-09-18T12:00:00Z",
                appVersion = "0.1.0",
                buildNumber = 1,
                phase = "Ready For iPhone",
                nextStep = "scan_from_iphone",
                transportSecurityMode = PhotoSharingTransportSecurityMode.SIGNED_HTTP,
                endpoint = "http://192.168.1.2:48291/v1/health",
                hasMediaPermission = true,
                hasNotificationPermission = true,
                isServerRunning = true,
                pendingPhotoCount = 2,
                requestActivity = null,
                syncResult = SyncResult(
                    syncBatchId = "batch-1",
                    targetDeviceId = "iphone-1",
                    results = listOf(
                        result("photo-1", SyncItemStatus.synced),
                        result("photo-2", SyncItemStatus.failed),
                    ),
                ),
            ),
        )

        val root = JSONObject(json)
        assertEquals(1, root.getJSONObject("sync").getInt("synced"))
        assertEquals(1, root.getJSONObject("sync").getInt("failed"))
        assertEquals("excluded", root.getJSONObject("redaction").getString("pairingToken"))
        assertFalse(json.contains("iphone-1"))
    }

    private fun result(sourceId: String, status: SyncItemStatus): SyncItemResult {
        return SyncItemResult(
            itemType = SyncItemType.media,
            sourceItemId = sourceId,
            targetItemId = null,
            status = status,
        )
    }
}
