package com.sharesync.android

import android.content.Context
import com.sharesync.android.discovery.LocalPeerDiscoveryAdvertiser
import com.sharesync.android.pairing.PairingPayloadFactory
import com.sharesync.android.security.DeviceIdentity
import com.sharesync.android.security.DeviceIdentityStore
import com.sharesync.android.sync.ManifestBuilder
import com.sharesync.android.sync.ManifestJsonEncoder
import com.sharesync.android.sync.SyncEventStore
import com.sharesync.android.sync.SyncResultStore
import com.sharesync.android.transfer.server.LocalServerBinder
import com.sharesync.android.transfer.server.LocalRequestActivityTracker
import com.sharesync.android.transfer.server.LocalSyncRouter
import com.sharesync.android.transfer.server.LocalSyncServer
import java.net.BindException
import java.util.UUID

data class AndroidM0ServerSession(
    val server: LocalSyncServer,
    val syncResultStore: SyncResultStore,
    val syncEventStore: SyncEventStore,
    val manifestBuilder: ManifestBuilder,
    val requestActivityTracker: LocalRequestActivityTracker,
    val discoveryAdvertiser: LocalPeerDiscoveryAdvertiser,
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

object AndroidM0ServerSessionController {
    fun start(
        context: Context,
        deviceIdentityStore: DeviceIdentityStore,
        appVersion: String,
    ): AndroidM0ServerSession {
        val identity = SuspendBridge.runBlocking {
            deviceIdentityStore.getOrCreate()
        }
        val pairingToken = UUID.randomUUID().toString().replace("-", "")
        val components = M0SyncComponents.create(
            context = context.applicationContext,
            deviceId = identity.deviceId,
            appVersion = appVersion,
            pairingToken = pairingToken,
        )
        val server = startLocalServer(
            serverBinder = components.serverBinder,
            router = components.router,
            mediaStreamProvider = components.mediaStreamProvider,
        )
        val discoveryAdvertiser = LocalPeerDiscoveryAdvertiser(context.applicationContext)
        discoveryAdvertiser.start(identity = identity, port = server.port)
        val session = AndroidM0ServerSession(
            server = server,
            syncResultStore = components.syncResultStore,
            syncEventStore = components.syncEventStore,
            manifestBuilder = components.manifestBuilder,
            requestActivityTracker = components.requestActivityTracker,
            discoveryAdvertiser = discoveryAdvertiser,
            pairingPayloadJson = createPairingPayloadJson(
                identity = identity,
                port = server.port,
                pairingToken = pairingToken,
            ),
        )
        AndroidM0ServerSessionRegistry.set(session)
        return session
    }

    fun stop(session: AndroidM0ServerSession?) {
        val activeSession = session ?: AndroidM0ServerSessionRegistry.current ?: return
        AndroidM0ServerSessionRegistry.clear(activeSession)
        activeSession.discoveryAdvertiser.stop()
        SuspendBridge.runBlocking { activeSession.server.stop() }
    }

    private fun startLocalServer(
        serverBinder: LocalServerBinder,
        router: LocalSyncRouter,
        mediaStreamProvider: com.sharesync.android.scanner.media.MediaStreamProvider,
    ): LocalSyncServer {
        return try {
            bindAndStartServer(
                serverBinder = serverBinder,
                router = router,
                mediaStreamProvider = mediaStreamProvider,
                port = M0SyncComponents.defaultPort(),
            )
        } catch (error: BindException) {
            bindAndStartServer(
                serverBinder = serverBinder,
                router = router,
                mediaStreamProvider = mediaStreamProvider,
                port = AVAILABLE_PORT,
            )
        }
    }

    private fun bindAndStartServer(
        serverBinder: LocalServerBinder,
        router: LocalSyncRouter,
        mediaStreamProvider: com.sharesync.android.scanner.media.MediaStreamProvider,
        port: Int,
    ): LocalSyncServer {
        val server = SuspendBridge.runBlocking {
            serverBinder.bind(
                router = router,
                mediaStreamProvider = mediaStreamProvider,
                port = port,
            )
        }
        SuspendBridge.runBlocking { server.start() }
        return server
    }

    private fun createPairingPayloadJson(
        identity: DeviceIdentity,
        port: Int,
        pairingToken: String,
    ): String? {
        val ip = LocalNetworkAddresses.firstIpv4Address() ?: return null
        val payload = PairingPayloadFactory(
            deviceIdProvider = { identity.deviceId },
            deviceNameProvider = { identity.deviceName },
            publicKeyProvider = { identity.publicKey },
            localIpProvider = { ip },
            portProvider = { port },
            pairingTokenProvider = { pairingToken },
        ).createPayload()
        return ManifestJsonEncoder().encode(payload)
    }

    private const val AVAILABLE_PORT = 0
}
