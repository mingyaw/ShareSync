package com.sharesync.android.sync

import com.sharesync.android.SuspendBridge
import org.junit.Assert.assertEquals
import org.json.JSONObject
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
    fun inMemoryStoreKeepsCompletionStateSeparateForEachTargetDevice() {
        val store = InMemorySyncResultStore()

        SuspendBridge.runBlocking {
            store.save(syncResult("batch-ios", syncItem("media-001", SyncItemStatus.synced)))
            store.save(syncResult("batch-mac", syncItem("media-002", SyncItemStatus.synced), targetDeviceId = "mac-device-001"))
        }

        assertEquals(
            setOf("media-001"),
            SuspendBridge.runBlocking { store.completedMediaAssetIds("ios-device-001") },
        )
        assertEquals(
            setOf("media-002"),
            SuspendBridge.runBlocking { store.completedMediaAssetIds("mac-device-001") },
        )
        assertEquals("batch-mac", SuspendBridge.runBlocking { store.latest() }?.syncBatchId)
    }

    @Test
    fun inMemoryStoreCombinesCompletedMediaForGatewayGroup() {
        val store = InMemorySyncResultStore()

        SuspendBridge.runBlocking {
            store.save(syncResult("batch-ios", syncItem("media-ios", SyncItemStatus.synced)))
            store.save(
                syncResult(
                    "batch-mac",
                    syncItem("media-mac", SyncItemStatus.skipped),
                    syncItem("media-retry", SyncItemStatus.failed),
                    targetDeviceId = "mac-device-001",
                )
            )
        }

        assertEquals(
            setOf("media-ios", "media-mac"),
            SuspendBridge.runBlocking {
                store.completedMediaAssetIds(setOf("ios-device-001", "mac-device-001"))
            },
        )
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

            assertEquals(3, JSONObject(file.readText()).getInt("schemaVersion"))
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
    fun fileStoreMigratesLegacyUnversionedResult() {
        val directory = File(System.getProperty("java.io.tmpdir"), "ShareSyncStoreTest-${System.nanoTime()}")
        val file = File(directory, "latest-sync-result.json")
        val legacyResult = syncResult("batch-legacy", syncItem("media-001", SyncItemStatus.synced))

        try {
            directory.mkdirs()
            file.writeText(SyncResultJsonCodec().encode(legacyResult))

            val loaded = SuspendBridge.runBlocking { FileSyncResultStore(file = file).latest() }

            assertEquals(legacyResult, loaded)
        } finally {
            file.delete()
            directory.delete()
        }
    }

    @Test
    fun fileStoreMigratesVersionedSingleResultAndPreservesItWhenAnotherTargetSaves() {
        val directory = File(System.getProperty("java.io.tmpdir"), "ShareSyncStoreTest-${System.nanoTime()}")
        val file = File(directory, "latest-sync-result.json")
        val legacyResult = syncResult("batch-ios", syncItem("media-001", SyncItemStatus.synced))

        try {
            directory.mkdirs()
            file.writeText(
                JSONObject()
                    .put("schemaVersion", 2)
                    .put("result", JSONObject(SyncResultJsonCodec().encode(legacyResult)))
                    .toString(),
            )
            val store = FileSyncResultStore(file = file)

            SuspendBridge.runBlocking {
                store.save(
                    syncResult(
                        "batch-mac",
                        syncItem("media-002", SyncItemStatus.synced),
                        targetDeviceId = "mac-device-001",
                    )
                )
            }

            val reloaded = FileSyncResultStore(file = file)
            assertEquals(
                setOf("media-001"),
                SuspendBridge.runBlocking { reloaded.completedMediaAssetIds("ios-device-001") },
            )
            assertEquals(
                setOf("media-002"),
                SuspendBridge.runBlocking { reloaded.completedMediaAssetIds("mac-device-001") },
            )
            assertEquals(3, JSONObject(file.readText()).getInt("schemaVersion"))
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

    private fun syncResult(
        batchId: String,
        vararg items: SyncItemResult,
        targetDeviceId: String = "ios-device-001",
    ): SyncResult {
        return SyncResult(
            syncBatchId = batchId,
            targetDeviceId = targetDeviceId,
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
