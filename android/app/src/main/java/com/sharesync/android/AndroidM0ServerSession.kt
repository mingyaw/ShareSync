package com.sharesync.android

import com.sharesync.android.sync.ManifestBuilder
import com.sharesync.android.sync.SyncResultStore
import com.sharesync.android.transfer.server.LocalSyncServer

data class AndroidM0ServerSession(
    val server: LocalSyncServer,
    val syncResultStore: SyncResultStore,
    val manifestBuilder: ManifestBuilder,
    val pairingPayloadJson: String?,
)

object AndroidM0ServerSessionRegistry {
    @Volatile
    var current: AndroidM0ServerSession? = null
        private set

    fun set(session: AndroidM0ServerSession) {
        current = session
    }

    fun clear(session: AndroidM0ServerSession? = null) {
        if (session == null || current === session) {
            current = null
        }
    }
}
