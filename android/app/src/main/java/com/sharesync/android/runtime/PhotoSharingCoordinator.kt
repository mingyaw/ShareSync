package com.sharesync.android.runtime

import android.content.Context
import com.sharesync.android.PhotoSharingService
import com.sharesync.android.PhotoSharingSession
import com.sharesync.android.PhotoSharingSessionController
import com.sharesync.android.PhotoSharingSessionRegistry
import com.sharesync.android.PhotoSharingTransportSecurityMode
import com.sharesync.android.SuspendBridge
import com.sharesync.android.security.DeviceIdentityStore
import com.sharesync.android.sync.FileSyncEventStore
import com.sharesync.android.sync.FileSyncResultStore
import com.sharesync.android.sync.ManifestBuilder
import com.sharesync.android.sync.SyncEvent
import com.sharesync.android.sync.SyncEventStore
import com.sharesync.android.sync.SyncHistorySummary
import com.sharesync.android.sync.SyncResult
import com.sharesync.android.sync.SyncResultStore
import com.sharesync.android.sync.recentHistorySummaries
import com.sharesync.android.transfer.server.LocalRequestActivity
import com.sharesync.android.transfer.server.LocalRequestActivityTracker
import com.sharesync.android.transfer.server.LocalSyncServer

data class PhotoSharingSnapshot(
    val isStarting: Boolean = false,
    val isRunning: Boolean = false,
    val serverPort: Int? = null,
    val pairingPayloadJson: String? = null,
    val transportSecurityMode: PhotoSharingTransportSecurityMode =
        PhotoSharingTransportSecurityMode.SIGNED_HTTP,
    val pendingPhotoCount: Int? = null,
    val syncResult: SyncResult? = null,
    val syncEvent: SyncEvent? = null,
    val syncHistory: List<SyncHistorySummary> = emptyList(),
    val requestActivity: LocalRequestActivity? = null,
)

sealed interface PhotoSharingCoordinatorEvent {
    data object Starting : PhotoSharingCoordinatorEvent
    data object HistoryCleared : PhotoSharingCoordinatorEvent
    data class Failed(val error: Throwable) : PhotoSharingCoordinatorEvent
}

class PhotoSharingCoordinator(
    context: Context,
    private val deviceIdentityStore: DeviceIdentityStore,
    private val appVersion: String,
    private val onUpdate: (PhotoSharingSnapshot, PhotoSharingCoordinatorEvent?) -> Unit,
) {
    private val appContext = context.applicationContext
    private val lifecycleLock = Any()

    @Volatile
    private var operationGeneration = 0L

    @Volatile
    private var isRunning = false

    @Volatile
    private var isStarting = false

    @Volatile
    private var pollThread: Thread? = null

    private var server: LocalSyncServer? = null
    private var syncResultStore: SyncResultStore? = null
    private var syncEventStore: SyncEventStore? = null
    private var manifestBuilder: ManifestBuilder? = null
    private var requestActivityTracker: LocalRequestActivityTracker? = null
    private var pairingPayloadJson: String? = null
    private var transportSecurityMode = PhotoSharingTransportSecurityMode.SIGNED_HTTP

    @Volatile
    var snapshot = PhotoSharingSnapshot()
        private set

    fun restore(): PhotoSharingSnapshot {
        restorePersistedHistory()
        PhotoSharingSessionRegistry.current?.let(::attachSession)
        refreshSnapshot()
        if (isRunning) {
            startPolling()
        }
        return snapshot
    }

    fun start() {
        val generation = synchronized(lifecycleLock) {
            if (isRunning || isStarting) {
                return
            }
            operationGeneration += 1
            isStarting = true
            snapshot = snapshot.copy(isStarting = true, isRunning = false)
            onUpdate(snapshot, PhotoSharingCoordinatorEvent.Starting)
            operationGeneration
        }

        Thread {
            var createdSession: PhotoSharingSession? = null
            try {
                val session = PhotoSharingSessionController.start(
                    context = appContext,
                    deviceIdentityStore = deviceIdentityStore,
                    appVersion = appVersion,
                )
                createdSession = session
                val accepted = synchronized(lifecycleLock) {
                    if (generation != operationGeneration) {
                        false
                    } else {
                        attachSession(session)
                        PhotoSharingService.start(appContext)
                        publish()
                        startPolling()
                        true
                    }
                }
                if (!accepted) {
                    PhotoSharingSessionController.stop(session)
                }
            } catch (error: Throwable) {
                val shouldStopSession = synchronized(lifecycleLock) {
                    if (generation == operationGeneration) {
                        resetSessionState()
                        PhotoSharingSessionRegistry.clear()
                        PhotoSharingService.stop(appContext)
                        restorePersistedHistory()
                        publish(PhotoSharingCoordinatorEvent.Failed(error))
                        true
                    } else {
                        false
                    }
                }
                if (shouldStopSession) {
                    createdSession?.let(PhotoSharingSessionController::stop)
                }
            }
        }.start()
    }

    fun stop() {
        val stopTarget = synchronized(lifecycleLock) {
            operationGeneration += 1
            val session = PhotoSharingSessionRegistry.current
            val activeServer = server ?: session?.server
            if (activeServer == null && !isStarting) {
                return
            }
            PhotoSharingSessionRegistry.clear(session)
            resetSessionState()
            restorePersistedHistory()
            stopPolling()
            PhotoSharingService.stop(appContext)
            publish()
            session to activeServer
        }

        Thread {
            val (session, activeServer) = stopTarget
            if (session != null) {
                PhotoSharingSessionController.stop(session)
            } else if (activeServer != null) {
                SuspendBridge.runBlocking { activeServer.stop() }
            }
        }.start()
    }

    fun clearHistory() {
        val resultStore = syncResultStore ?: return
        Thread {
            SuspendBridge.runBlocking { resultStore.clear() }
            syncEventStore?.let { store -> SuspendBridge.runBlocking { store.clear() } }
            snapshot = snapshot.copy(
                syncResult = null,
                syncEvent = null,
                syncHistory = emptyList(),
                pendingPhotoCount = manifestBuilder?.let(::photoCount),
            )
            onUpdate(snapshot, PhotoSharingCoordinatorEvent.HistoryCleared)
        }.start()
    }

    fun pauseMonitoring() {
        stopPolling()
    }

    private fun attachSession(session: PhotoSharingSession) {
        server = session.server
        syncResultStore = session.syncResultStore
        syncEventStore = session.syncEventStore
        manifestBuilder = session.manifestBuilder
        requestActivityTracker = session.requestActivityTracker
        pairingPayloadJson = session.pairingPayloadJson
        transportSecurityMode = session.transportSecurityMode
        isStarting = false
        isRunning = true
        refreshSnapshot()
    }

    private fun resetSessionState() {
        server = null
        manifestBuilder = null
        requestActivityTracker = null
        pairingPayloadJson = null
        transportSecurityMode = PhotoSharingTransportSecurityMode.SIGNED_HTTP
        isStarting = false
        isRunning = false
    }

    private fun restorePersistedHistory() {
        val resultStore = FileSyncResultStore(FileSyncResultStore.defaultFile(appContext.filesDir))
        val eventStore = FileSyncEventStore(FileSyncEventStore.defaultFile(appContext.filesDir))
        syncResultStore = resultStore
        syncEventStore = eventStore
        snapshot = snapshot.copy(
            syncResult = SuspendBridge.runBlocking { resultStore.latest() },
            syncEvent = SuspendBridge.runBlocking { eventStore.latest() },
            syncHistory = SuspendBridge.runBlocking { eventStore.recentHistorySummaries(HISTORY_LIMIT) },
        )
    }

    private fun startPolling() {
        if (pollThread?.isAlive == true) {
            return
        }
        pollThread = Thread {
            while (isRunning) {
                try {
                    Thread.sleep(POLL_INTERVAL_MS)
                } catch (_: InterruptedException) {
                    return@Thread
                }
                if (!isRunning) {
                    return@Thread
                }
                refreshSnapshot()
                publish()
            }
        }.also(Thread::start)
    }

    private fun stopPolling() {
        pollThread?.interrupt()
        pollThread = null
    }

    private fun refreshSnapshot() {
        val eventStore = syncEventStore
        snapshot = PhotoSharingSnapshot(
            isStarting = isStarting,
            isRunning = isRunning,
            serverPort = server?.port,
            pairingPayloadJson = pairingPayloadJson,
            transportSecurityMode = transportSecurityMode,
            pendingPhotoCount = manifestBuilder?.let(::photoCount),
            syncResult = syncResultStore?.let { store -> SuspendBridge.runBlocking { store.latest() } },
            syncEvent = eventStore?.let { store -> SuspendBridge.runBlocking { store.latest() } },
            syncHistory = eventStore?.let { store ->
                SuspendBridge.runBlocking { store.recentHistorySummaries(HISTORY_LIMIT) }
            }.orEmpty(),
            requestActivity = requestActivityTracker?.latest(),
        )
    }

    private fun photoCount(builder: ManifestBuilder): Int {
        return SuspendBridge.runBlocking { builder.buildPhotoManifest().media.size }
    }

    private fun publish(event: PhotoSharingCoordinatorEvent? = null) {
        refreshSnapshot()
        onUpdate(snapshot, event)
    }

    private companion object {
        const val HISTORY_LIMIT = 3
        const val POLL_INTERVAL_MS = 2_000L
    }
}
