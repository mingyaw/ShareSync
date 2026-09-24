package com.sharesync.android

import android.content.Context
import com.sharesync.android.scanner.media.MediaStoreMediaScanner
import com.sharesync.android.scanner.media.MediaStreamProvider
import com.sharesync.android.sync.FileSyncEventStore
import com.sharesync.android.sync.FileSyncResultStore
import com.sharesync.android.sync.GatewayOwnershipStore
import com.sharesync.android.sync.ManifestBuilder
import com.sharesync.android.sync.SharedPreferencesGatewayOwnershipStore
import com.sharesync.android.sync.SyncEventStore
import com.sharesync.android.sync.SyncResultStore
import com.sharesync.android.transfer.server.LocalRequestActivityTracker
import com.sharesync.android.transfer.server.LocalSyncRouter
import com.sharesync.android.transfer.server.ManifestProvider

class PhotoSyncComponents private constructor(
    val mediaScanner: MediaStoreMediaScanner,
    val mediaStreamProvider: MediaStreamProvider,
    val manifestBuilder: ManifestBuilder,
    val syncResultStore: SyncResultStore,
    val syncEventStore: SyncEventStore,
    val gatewayOwnershipStore: GatewayOwnershipStore,
    val requestActivityTracker: LocalRequestActivityTracker,
    val router: LocalSyncRouter,
) {
    companion object {
        private const val PHOTO_SYNC_PORT = 48291

        fun create(
            context: Context,
            deviceId: String,
            appVersion: String,
            pairingToken: String,
        ): PhotoSyncComponents {
            val contentResolver = context.applicationContext.contentResolver
            val mediaScanner = MediaStoreMediaScanner(
                contentResolver = contentResolver,
                sourceDeviceId = deviceId,
            )
            val syncResultStore = FileSyncResultStore(
                file = FileSyncResultStore.defaultFile(context.applicationContext.filesDir),
            )
            val syncEventStore = FileSyncEventStore(
                file = FileSyncEventStore.defaultFile(context.applicationContext.filesDir),
            )
            val gatewayOwnershipStore = SharedPreferencesGatewayOwnershipStore(context.applicationContext)
            val manifestBuilder = ManifestBuilder(
                sourceDeviceId = deviceId,
                mediaScanner = mediaScanner,
                syncResultStore = syncResultStore,
            )

            val manifestProvider = object : ManifestProvider {
                override suspend fun currentManifest(
                    sinceCursor: String?,
                    pageCursor: String?,
                    targetDeviceId: String?,
                ) = manifestBuilder.buildPhotoManifest(
                    sinceCursor = sinceCursor,
                    pageCursor = pageCursor,
                    targetDeviceId = targetDeviceId,
                )
            }
            val requestActivityTracker = LocalRequestActivityTracker()

            return PhotoSyncComponents(
                mediaScanner = mediaScanner,
                mediaStreamProvider = MediaStreamProvider(contentResolver),
                manifestBuilder = manifestBuilder,
                syncResultStore = syncResultStore,
                syncEventStore = syncEventStore,
                gatewayOwnershipStore = gatewayOwnershipStore,
                requestActivityTracker = requestActivityTracker,
                router = LocalSyncRouter(
                    deviceId = deviceId,
                    appVersion = appVersion,
                    pairingToken = pairingToken,
                    manifestProvider = manifestProvider,
                    mediaProvider = mediaScanner,
                    syncResultStore = syncResultStore,
                    syncEventStore = syncEventStore,
                    gatewayOwnershipStore = gatewayOwnershipStore,
                    requestActivityTracker = requestActivityTracker,
                ),
            )
        }

        fun defaultPort(): Int = PHOTO_SYNC_PORT
    }
}
