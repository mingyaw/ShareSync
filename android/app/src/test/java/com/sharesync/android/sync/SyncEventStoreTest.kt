package com.sharesync.android.sync

import com.sharesync.android.SuspendBridge
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

class SyncEventStoreTest {
    @Test
    fun eventSummarizesSyncResult() {
        val event = SyncEvent.fromResult(
            result = SyncResult(
                syncBatchId = "batch-001",
                targetDeviceId = "ios-device-001",
                results = listOf(
                    syncItem("photo-001", SyncItemStatus.synced),
                    syncItem("photo-002", SyncItemStatus.skipped),
                    syncItem("photo-003", SyncItemStatus.failed),
                    syncItem("photo-004", SyncItemStatus.conflicted),
                ),
            ),
            recordedAtEpochMillis = 1_800_000_000_000L,
        )

        assertEquals("batch-001", event.syncBatchId)
        assertEquals("ios-device-001", event.targetDeviceId)
        assertEquals(1, event.syncedCount)
        assertEquals(1, event.skippedCount)
        assertEquals(1, event.failedCount)
        assertEquals(1, event.conflictedCount)
        assertEquals(2, event.successfulCount)
        assertEquals(false, event.isComplete)
    }

    @Test
    fun fileStorePersistsEventsInOrder() {
        val directory = File(System.getProperty("java.io.tmpdir"), "ShareSyncEventStoreTest-${System.nanoTime()}")
        val file = File(directory, "sync-events.json")
        val store = FileSyncEventStore(file = file)

        try {
            SuspendBridge.runBlocking {
                store.append(syncEvent("batch-001", recordedAt = 1_000L))
                store.append(syncEvent("batch-002", recordedAt = 2_000L))
            }

            val reloaded = FileSyncEventStore(file = file)
            val events = SuspendBridge.runBlocking { reloaded.all() }

            assertEquals(listOf("batch-001", "batch-002"), events.map { it.syncBatchId })
            assertEquals("batch-002", SuspendBridge.runBlocking { reloaded.latest() }?.syncBatchId)
        } finally {
            file.delete()
            directory.delete()
        }
    }

    @Test
    fun fileStoreKeepsMostRecentEvents() {
        val directory = File(System.getProperty("java.io.tmpdir"), "ShareSyncEventStoreTest-${System.nanoTime()}")
        val file = File(directory, "sync-events.json")
        val store = FileSyncEventStore(file = file)

        try {
            SuspendBridge.runBlocking {
                repeat(55) { index ->
                    store.append(syncEvent("batch-${index.toString().padStart(3, '0')}", recordedAt = index.toLong()))
                }
            }

            val events = SuspendBridge.runBlocking { store.all() }

            assertEquals(50, events.size)
            assertEquals("batch-005", events.first().syncBatchId)
            assertEquals("batch-054", events.last().syncBatchId)
        } finally {
            file.delete()
            directory.delete()
        }
    }

    @Test
    fun recentHistorySummariesReturnNewestEventsFirst() {
        val store = InMemorySyncEventStore()

        SuspendBridge.runBlocking {
            store.append(syncEvent("batch-001", recordedAt = 1_000L))
            store.append(
                SyncEvent(
                    syncBatchId = "batch-002",
                    targetDeviceId = "ios-device-001",
                    recordedAtEpochMillis = 2_000L,
                    syncedCount = 1,
                    skippedCount = 1,
                    failedCount = 1,
                    conflictedCount = 1,
                )
            )
            store.append(syncEvent("batch-003", recordedAt = 3_000L))
        }

        val summaries = SuspendBridge.runBlocking { store.recentHistorySummaries(limit = 2) }

        assertEquals(listOf("batch-003", "batch-002"), summaries.map { it.syncBatchId })
        assertEquals(4, summaries.last().totalCount)
        assertEquals(2, summaries.last().successfulCount)
        assertEquals(2, summaries.last().failedCount)
        assertEquals(false, summaries.last().isComplete)
        assertEquals(true, summaries.last().needsRetry)
    }

    private fun syncEvent(batchId: String, recordedAt: Long): SyncEvent {
        return SyncEvent(
            syncBatchId = batchId,
            targetDeviceId = "ios-device-001",
            recordedAtEpochMillis = recordedAt,
            syncedCount = 1,
            skippedCount = 0,
            failedCount = 0,
            conflictedCount = 0,
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
