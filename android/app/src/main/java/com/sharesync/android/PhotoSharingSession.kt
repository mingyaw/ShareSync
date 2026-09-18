package com.sharesync.android

import android.content.Context
import com.sharesync.android.discovery.LocalPeerDiscoveryAdvertiser
import com.sharesync.android.pairing.PairingPayloadFactory
import com.sharesync.android.pairing.PairingTransportSecurityFactory
import com.sharesync.android.security.AndroidKeyStoreLocalCertificateProvider
import com.sharesync.android.security.DeviceIdentity
import com.sharesync.android.security.DeviceIdentityStore
import com.sharesync.android.security.LocalCertificateProvider
import com.sharesync.android.security.LocalServerTlsContextProvider
import com.sharesync.android.sync.ManifestBuilder
import com.sharesync.android.sync.ManifestJsonEncoder
import com.sharesync.android.sync.SyncEventStore
import com.sharesync.android.sync.SyncResultStore
import com.sharesync.android.transfer.server.EmbeddedLocalHttpsServerBinder
import com.sharesync.android.transfer.server.EmbeddedLocalServerBinder
import com.sharesync.android.transfer.server.LocalServerBinder
import com.sharesync.android.transfer.server.LocalRequestActivityTracker
import com.sharesync.android.transfer.server.LocalSyncRouter
import com.sharesync.android.transfer.server.LocalSyncServer
import java.net.BindException
import java.util.UUID

data class PhotoSharingSession(
    val server: LocalSyncServer,
    val syncResultStore: SyncResultStore,
    val syncEventStore: SyncEventStore,
    val manifestBuilder: ManifestBuilder,
    val requestActivityTracker: LocalRequestActivityTracker,
    val discoveryAdvertiser: LocalPeerDiscoveryAdvertiser,
    val pairingPayloadJson: String?,
    val transportSecurityMode: PhotoSharingTransportSecurityMode,
)

enum class PhotoSharingTransportSecurityMode {
    SIGNED_HTTP,
    QR_PINNED_HTTPS,
}

object PhotoSharingSessionRegistry {
    @Volatile
    var current: PhotoSharingSession? = null
        private set

    fun set(session: PhotoSharingSession) {
        current = session
    }

    fun clear(session: PhotoSharingSession? = null) {
        if (session == null || current === session) {
            current = null
        }
    }
}

object PhotoSharingSessionController {
    fun start(
        context: Context,
        deviceIdentityStore: DeviceIdentityStore,
        appVersion: String,
    ): PhotoSharingSession {
        val identity = SuspendBridge.runBlocking {
            deviceIdentityStore.getOrCreate()
        }
        val pairingToken = UUID.randomUUID().toString().replace("-", "")
        val transportConfiguration = PhotoSharingTransportConfigurationFactory.create(
            enableQrPinnedHttps = PhotoSharingTransportFlags.enableQrPinnedHttps,
        )
        val components = PhotoSyncComponents.create(
            context = context.applicationContext,
            deviceId = identity.deviceId,
            appVersion = appVersion,
            pairingToken = pairingToken,
        )
        val server = startLocalServer(
            serverBinder = transportConfiguration.serverBinder,
            router = components.router,
            mediaStreamProvider = components.mediaStreamProvider,
        )
        val discoveryAdvertiser = LocalPeerDiscoveryAdvertiser(context.applicationContext)
        discoveryAdvertiser.start(identity = identity, port = server.port)
        val session = PhotoSharingSession(
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
                transportSecurityFactory = transportConfiguration.transportSecurityFactory,
            ),
            transportSecurityMode = transportConfiguration.mode,
        )
        PhotoSharingSessionRegistry.set(session)
        return session
    }

    fun stop(session: PhotoSharingSession?) {
        val activeSession = session ?: PhotoSharingSessionRegistry.current ?: return
        PhotoSharingSessionRegistry.clear(activeSession)
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
                port = PhotoSyncComponents.defaultPort(),
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
        transportSecurityFactory: PairingTransportSecurityFactory?,
    ): String? {
        val ip = LocalNetworkAddresses.firstIpv4Address() ?: return null
        val payload = PairingPayloadFactory(
            deviceIdProvider = { identity.deviceId },
            deviceNameProvider = { identity.deviceName },
            publicKeyProvider = { identity.publicKey },
            localIpProvider = { ip },
            portProvider = { port },
            pairingTokenProvider = { pairingToken },
            transportSecurityProvider = { transportSecurityFactory?.currentTransportSecurity() },
        ).createPayload()
        return ManifestJsonEncoder().encode(payload)
    }

    private const val AVAILABLE_PORT = 0
}

object PhotoSharingTransportFlags {
    val enableQrPinnedHttps: Boolean
        get() = BuildConfig.SHARESYNC_QR_PINNED_HTTPS
}

data class PhotoSharingTransportConfiguration(
    val mode: PhotoSharingTransportSecurityMode,
    val serverBinder: LocalServerBinder,
    val transportSecurityFactory: PairingTransportSecurityFactory?,
)

object PhotoSharingTransportConfigurationFactory {
    fun create(enableQrPinnedHttps: Boolean): PhotoSharingTransportConfiguration {
        if (!enableQrPinnedHttps) {
            return signedHttp()
        }

        val certificateProvider = AndroidKeyStoreLocalCertificateProvider()
        return qrPinnedHttps(certificateProvider)
    }

    fun signedHttp(): PhotoSharingTransportConfiguration {
        return PhotoSharingTransportConfiguration(
            mode = PhotoSharingTransportSecurityMode.SIGNED_HTTP,
            serverBinder = EmbeddedLocalServerBinder(),
            transportSecurityFactory = null,
        )
    }

    fun qrPinnedHttps(
        certificateProvider: LocalCertificateProvider,
    ): PhotoSharingTransportConfiguration {
        require(certificateProvider is LocalServerTlsContextProvider) {
            "QR-pinned HTTPS transport requires local TLS server context support."
        }
        return PhotoSharingTransportConfiguration(
            mode = PhotoSharingTransportSecurityMode.QR_PINNED_HTTPS,
            serverBinder = EmbeddedLocalHttpsServerBinder(certificateProvider),
            transportSecurityFactory = PairingTransportSecurityFactory(certificateProvider),
        )
    }
}
