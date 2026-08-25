package com.sharesync.android.transfer.server

import com.sharesync.android.SuspendBridge
import com.sharesync.android.sync.InMemorySyncResultStore
import com.sharesync.android.sync.MediaAsset
import com.sharesync.android.sync.MediaType
import com.sharesync.android.sync.SyncManifest
import org.junit.Assert.assertEquals
import org.junit.Test

class LocalSyncRouterTest {
    @Test
    fun manifestRejectsMissingPairingToken() {
        val response = SuspendBridge.runBlocking {
            router().manifest()
        }

        assertEquals(401, response.statusCode)
        assertEquals("""{"errorCode":"SS-AUTH-001"}""", response.body)
    }

    @Test
    fun manifestAcceptsExpectedPairingToken() {
        val response = SuspendBridge.runBlocking {
            router().manifest(mapOf(LocalSyncRouter.PAIRING_TOKEN_HEADER to PAIRING_TOKEN))
        }

        assertEquals(200, response.statusCode)
    }

    @Test
    fun mediaRejectsWrongPairingToken() {
        val response = SuspendBridge.runBlocking {
            router().media(
                assetId = "media-001",
                headers = pairingHeaders("wrong-token"),
            )
        }

        assertEquals(LocalMediaResponse.Unauthorized(401, "SS-AUTH-001"), response)
    }

    private fun router(): LocalSyncRouter {
        return LocalSyncRouter(
            deviceId = "android-device-001",
            appVersion = "0.1.0",
            pairingToken = PAIRING_TOKEN,
            manifestProvider = object : ManifestProvider {
                override suspend fun currentManifest(): SyncManifest {
                    return SyncManifest(
                        version = 1,
                        sourceDeviceId = "android-device-001",
                        generatedAt = "2026-08-25T00:00:00Z",
                        cursor = "cursor-001",
                        media = listOf(mediaAsset("media-001")),
                        contacts = emptyList(),
                        files = emptyList(),
                    )
                }
            },
            mediaProvider = object : MediaProvider {
                override suspend fun findMedia(assetId: String): MediaAsset? {
                    return mediaAsset(assetId)
                }
            },
            syncResultStore = InMemorySyncResultStore(),
        )
    }

    private fun pairingHeaders(token: String = PAIRING_TOKEN): Map<String, String> {
        return mapOf(LocalSyncRouter.PAIRING_TOKEN_HEADER.lowercase() to token)
    }

    private fun mediaAsset(assetId: String): MediaAsset {
        return MediaAsset(
            assetId = assetId,
            sourceDeviceId = "android-device-001",
            mediaType = MediaType.photo,
            fileName = "$assetId.jpg",
            mimeType = "image/jpeg",
            size = 1024,
        )
    }

    private companion object {
        const val PAIRING_TOKEN = "expected-token"
    }
}
