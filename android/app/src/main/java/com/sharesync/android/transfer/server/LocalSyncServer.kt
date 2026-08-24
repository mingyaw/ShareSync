package com.sharesync.android.transfer.server

import com.sharesync.android.sync.SyncManifest

interface LocalSyncServer {
    val port: Int

    suspend fun start()

    suspend fun stop()
}

interface ManifestProvider {
    suspend fun currentManifest(): SyncManifest
}

interface LocalServerBinder {
    suspend fun bind(
        router: LocalSyncRouter,
        mediaStreamProvider: com.sharesync.android.scanner.media.MediaStreamProvider,
        port: Int,
    ): LocalSyncServer
}

class EmbeddedLocalServerBinder : LocalServerBinder {
    override suspend fun bind(
        router: LocalSyncRouter,
        mediaStreamProvider: com.sharesync.android.scanner.media.MediaStreamProvider,
        port: Int,
    ): LocalSyncServer {
        return EmbeddedLocalSyncServer(
            requestedPort = port,
            router = router,
            mediaStreamProvider = mediaStreamProvider,
        )
    }
}

class LocalSyncServerStub(
    override val port: Int,
) : LocalSyncServer {
    override suspend fun start() {
        // M0 implementation will bind an embedded HTTP server here.
    }

    override suspend fun stop() {
        // M0 implementation will stop the embedded HTTP server here.
    }
}
