package com.sharesync.android.transfer.server

import com.sharesync.android.security.LocalServerTlsContextProvider
import com.sharesync.android.sync.SyncManifest

interface LocalSyncServer {
    val port: Int

    suspend fun start()

    suspend fun stop()
}

interface ManifestProvider {
    suspend fun currentManifest(sinceCursor: String? = null, pageCursor: String? = null): SyncManifest
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

class EmbeddedLocalHttpsServerBinder(
    private val tlsContextProvider: LocalServerTlsContextProvider,
) : LocalServerBinder {
    override suspend fun bind(
        router: LocalSyncRouter,
        mediaStreamProvider: com.sharesync.android.scanner.media.MediaStreamProvider,
        port: Int,
    ): LocalSyncServer {
        return EmbeddedLocalSyncServer(
            requestedPort = port,
            router = router,
            mediaStreamProvider = mediaStreamProvider,
            serverSocketFactory = { requestedPort ->
                tlsContextProvider.serverSSLContext()
                    .serverSocketFactory
                    .createServerSocket(requestedPort)
            },
        )
    }
}

class LocalSyncServerStub(
    override val port: Int,
) : LocalSyncServer {
    override suspend fun start() {
        // Concrete implementations bind the local transfer server here.
    }

    override suspend fun stop() {
        // Concrete implementations release the local transfer server here.
    }
}
