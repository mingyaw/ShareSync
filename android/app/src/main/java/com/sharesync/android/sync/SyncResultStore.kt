package com.sharesync.android.sync

interface SyncResultStore {
    suspend fun save(result: SyncResult)
    suspend fun latest(): SyncResult?
}

class InMemorySyncResultStore : SyncResultStore {
    private var latestResult: SyncResult? = null

    override suspend fun save(result: SyncResult) {
        latestResult = result
    }

    override suspend fun latest(): SyncResult? {
        return latestResult
    }
}
