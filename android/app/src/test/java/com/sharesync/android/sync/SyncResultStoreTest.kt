package com.sharesync.android.sync

import com.sharesync.android.SuspendBridge
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

class SyncResultStoreTest {
    @Test
    fun inMemoryStoreMergesResultsAcrossBatches() {
        val store = InMemorySyncResultStore()

        SuspendBridge.runBlocking {
            store.save(syncResult("batch-001", syncItem("media-001", SyncItemStatus.synced)))
            store.save(syncResult("batch-002", syncItem("media-002", SyncItemStatus.skipped)))
        }

        val latest = SuspendBridge.runBlocking { store.latest() }

        assertEquals("batch-002", latest?.syncBatchId)
        assertEquals(
            listOf("media-001" to SyncItemStatus.synced, "media-002" to SyncItemStatus.skipped),
            latest?.results?.map { it.sourceItemId to it.status },
        )
        assertEquals(
            setOf("media-001", "media-002"),
            SuspendBridge.runBlocking { store.completedMediaAssetIds() },
        )
    }

    @Test
    fun inMemoryStoreReplacesSameSourceItemWithLatestStatus() {
        val store = InMemorySyncResultStore()

        SuspendBridge.runBlocking {
            store.save(syncResult("batch-001", syncItem("media-001", SyncItemStatus.synced)))
            store.save(syncResult("batch-002", syncItem("media-001", SyncItemStatus.failed)))
        }

        val latest = SuspendBridge.runBlocking { store.latest() }

        assertEquals(listOf("media-001" to SyncItemStatus.failed), latest?.results?.map { it.sourceItemId to it.status })
        assertEquals(emptySet<String>(), SuspendBridge.runBlocking { store.completedMediaAssetIds() })
    }

    @Test
    fun inMemoryStoreTreatsRetriedSuccessAsCompleted() {
        val store = InMemorySyncResultStore()

        SuspendBridge.runBlocking {
            store.save(syncResult("batch-001", syncItem("media-001", SyncItemStatus.failed)))
            store.save(syncResult("batch-002", syncItem("media-001", SyncItemStatus.synced)))
        }

        val latest = SuspendBridge.runBlocking { store.latest() }

        assertEquals(listOf("media-001" to SyncItemStatus.synced), latest?.results?.map { it.sourceItemId to it.status })
        assertEquals(setOf("media-001"), SuspendBridge.runBlocking { store.completedMediaAssetIds() })
    }

    @Test
    fun inMemoryStoreKeepsConflictedMediaRetryable() {
        val store = InMemorySyncResultStore()

        SuspendBridge.runBlocking {
            store.save(syncResult("batch-001", syncItem("media-001", SyncItemStatus.conflicted)))
        }

        val latest = SuspendBridge.runBlocking { store.latest() }

        assertEquals(listOf("media-001" to SyncItemStatus.conflicted), latest?.results?.map { it.sourceItemId to it.status })
        assertEquals(emptySet<String>(), SuspendBridge.runBlocking { store.completedMediaAssetIds() })
    }

    @Test
    fun inMemoryStoreClearRemovesResults() {
        val store = InMemorySyncResultStore()

        SuspendBridge.runBlocking {
            store.save(syncResult("batch-001", syncItem("media-001", SyncItemStatus.synced)))
            store.clear()
        }

        assertEquals(null, SuspendBridge.runBlocking { store.latest() })
        assertEquals(emptySet<String>(), SuspendBridge.runBlocking { store.completedMediaAssetIds() })
    }

    @Test
    fun fileStorePersistsMergedResults() {
        val directory = File(System.getProperty("java.io.tmpdir"), "ShareSyncStoreTest-${System.nanoTime()}")
        val file = File(directory, "latest-sync-result.json")
        val store = FileSyncResultStore(file = file)

        try {
            SuspendBridge.runBlocking {
                store.save(syncResult("batch-001", syncItem("media-001", SyncItemStatus.synced)))
                store.save(syncResult("batch-002", syncItem("media-002", SyncItemStatus.failed)))
            }

            val reloaded = FileSyncResultStore(file = file)
            val latest = SuspendBridge.runBlocking { reloaded.latest() }

            assertEquals("batch-002", latest?.syncBatchId)
            assertEquals(
                listOf("media-001" to SyncItemStatus.synced, "media-002" to SyncItemStatus.failed),
                latest?.results?.map { it.sourceItemId to it.status },
            )
        } finally {
            file.delete()
            directory.delete()
        }
    }

    @Test
    fun fileStoreClearRemovesPersistedResults() {
        val directory = File(System.getProperty("java.io.tmpdir"), "ShareSyncStoreTest-${System.nanoTime()}")
        val file = File(directory, "latest-sync-result.json")
        val store = FileSyncResultStore(file = file)

        try {
            SuspendBridge.runBlocking {
                store.save(syncResult("batch-001", syncItem("media-001", SyncItemStatus.synced)))
            }
            assertEquals(true, file.exists())

            SuspendBridge.runBlocking { store.clear() }

            assertEquals(null, SuspendBridge.runBlocking { store.latest() })
            assertEquals(false, file.exists())
        } finally {
            file.delete()
            directory.delete()
        }
    }

    @Test
    fun clearingResultStoreDoesNotClearEventStore() {
        val directory = File(System.getProperty("java.io.tmpdir"), "ShareSyncStoreTest-${System.nanoTime()}")
        val resultFile = File(directory, "latest-sync-result.json")
        val eventFile = File(directory, "sync-events.json")
        val resultStore = FileSyncResultStore(file = resultFile)
        val eventStore = FileSyncEventStore(file = eventFile)

        try {
            SuspendBridge.runBlocking {
                resultStore.save(syncResult("batch-001", syncItem("media-001", SyncItemStatus.synced)))
                eventStore.append(syncEvent("batch-001", recordedAt = 1_000L))
                resultStore.clear()
            }

            assertEquals(null, SuspendBridge.runBlocking { resultStore.latest() })
            assertEquals("batch-001", SuspendBridge.runBlocking { eventStore.latest() }?.syncBatchId)
        } finally {
            resultFile.delete()
            eventFile.delete()
            directory.delete()
        }
    }

    @Test
    fun clearingEventStoreDoesNotClearResultStore() {
        val directory = File(System.getProperty("java.io.tmpdir"), "ShareSyncStoreTest-${System.nanoTime()}")
        val resultFile = File(directory, "latest-sync-result.json")
        val eventFile = File(directory, "sync-events.json")
        val resultStore = FileSyncResultStore(file = resultFile)
        val eventStore = FileSyncEventStore(file = eventFile)

        try {
            SuspendBridge.runBlocking {
                resultStore.save(syncResult("batch-001", syncItem("media-001", SyncItemStatus.synced)))
                eventStore.append(syncEvent("batch-001", recordedAt = 1_000L))
                eventStore.clear()
            }

            assertEquals("batch-001", SuspendBridge.runBlocking { resultStore.latest() }?.syncBatchId)
            assertEquals(null, SuspendBridge.runBlocking { eventStore.latest() })
        } finally {
            resultFile.delete()
            eventFile.delete()
            directory.delete()
        }
    }

    private fun syncResult(batchId: String, vararg items: SyncItemResult): SyncResult {
        return SyncResult(
            syncBatchId = batchId,
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
}
