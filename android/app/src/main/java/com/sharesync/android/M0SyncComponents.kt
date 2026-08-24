package com.sharesync.android

import android.content.Context
import com.sharesync.android.scanner.media.MediaStoreMediaScanner
import com.sharesync.android.scanner.media.MediaStreamProvider
import com.sharesync.android.sync.FileSyncResultStore
import com.sharesync.android.sync.ManifestBuilder
import com.sharesync.android.sync.SyncResultStore
import com.sharesync.android.transfer.server.EmbeddedLocalServerBinder
import com.sharesync.android.transfer.server.LocalSyncRouter
import com.sharesync.android.transfer.server.ManifestProvider

class M0SyncComponents private constructor(
    val mediaScanner: MediaStoreMediaScanner,
    val mediaStreamProvider: MediaStreamProvider,
    val syncResultStore: SyncResultStore,
    val router: LocalSyncRouter,
    val serverBinder: EmbeddedLocalServerBinder,
) {
    companion object {
        private const val M0_SERVER_PORT = 48291

        fun create(
            context: Context,
            deviceId: String,
            appVersion: String,
        ): M0SyncComponents {
            val contentResolver = context.applicationContext.contentResolver
            val mediaScanner = MediaStoreMediaScanner(
                contentResolver = contentResolver,
                sourceDeviceId = deviceId,
            )
            val syncResultStore = FileSyncResultStore(
                file = FileSyncResultStore.defaultFile(context.applicationContext.filesDir),
            )
            val manifestBuilder = ManifestBuilder(
                sourceDeviceId = deviceId,
                mediaScanner = mediaScanner,
                syncResultStore = syncResultStore,
            )

            val manifestProvider = object : ManifestProvider {
                override suspend fun currentManifest() = manifestBuilder.buildM0Manifest()
            }

            return M0SyncComponents(
                mediaScanner = mediaScanner,
                mediaStreamProvider = MediaStreamProvider(contentResolver),
                syncResultStore = syncResultStore,
                router = LocalSyncRouter(
                    deviceId = deviceId,
                    appVersion = appVersion,
                    manifestProvider = manifestProvider,
                    mediaProvider = mediaScanner,
                    syncResultStore = syncResultStore,
                ),
                serverBinder = EmbeddedLocalServerBinder(),
            )
        }

        fun defaultPort(): Int = M0_SERVER_PORT
    }
}
