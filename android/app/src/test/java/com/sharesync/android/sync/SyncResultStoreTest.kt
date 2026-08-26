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
            errorCode = if (status == SyncItemStatus.failed) "SS-NET-002" else null,
        )
    }
}
