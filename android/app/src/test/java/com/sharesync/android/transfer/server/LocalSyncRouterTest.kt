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
        val activityTracker = LocalRequestActivityTracker(clock = { 1234L })
        val response = SuspendBridge.runBlocking {
            router(requestActivityTracker = activityTracker)
                .manifest(mapOf(LocalSyncRouter.PAIRING_TOKEN_HEADER to PAIRING_TOKEN))
        }

        assertEquals(200, response.statusCode)
        assertEquals(LocalRequestActivity("manifest", 200, 1234L, 1), activityTracker.latest())
    }

    @Test
    fun mediaRejectsWrongPairingToken() {
        val activityTracker = LocalRequestActivityTracker(clock = { 5678L })
        val response = SuspendBridge.runBlocking {
            router(requestActivityTracker = activityTracker).media(
                assetId = "media-001",
                headers = pairingHeaders("wrong-token"),
            )
        }

        assertEquals(LocalMediaResponse.Unauthorized(401, "SS-AUTH-001"), response)
        assertEquals(LocalRequestActivity("media", 401, 5678L, 1), activityTracker.latest())
    }

    @Test
    fun syncResultRecordsBadRequestActivity() {
        val activityTracker = LocalRequestActivityTracker(clock = { 9012L })
        val response = SuspendBridge.runBlocking {
            router(requestActivityTracker = activityTracker).syncResult(
                body = """{"bad": true}""",
                headers = pairingHeaders(),
            )
        }

        assertEquals(400, response.statusCode)
        assertEquals(LocalRequestActivity("sync-result", 400, 9012L, 1), activityTracker.latest())
    }

    @Test
    fun requestActivityCountsLocalRequestsAcrossEndpoints() {
        var now = 10_000L
        val activityTracker = LocalRequestActivityTracker(clock = { now })
        val router = router(requestActivityTracker = activityTracker)

        SuspendBridge.runBlocking {
            router.health()
            now = 11_000L
            router.manifest(pairingHeaders())
            now = 12_000L
            router.media(assetId = "media-001", headers = pairingHeaders())
        }

        assertEquals(LocalRequestActivity("media", 200, 12_000L, 3), activityTracker.latest())
    }

    @Test
    fun mediaReturnsPartialRangeMetadata() {
        val response = SuspendBridge.runBlocking {
            router().media(
                assetId = "media-001",
                rangeHeader = "bytes=100-199",
                headers = pairingHeaders(),
            )
        } as LocalMediaResponse.Found

        assertEquals(206, response.statusCode)
        assertEquals(ByteRange(start = 100, endInclusive = 199, totalSize = 1024, isPartial = true), response.range)
        assertEquals("100", response.headers["Content-Length"])
        assertEquals("bytes 100-199/1024", response.headers["Content-Range"])
    }

    @Test
    fun mediaSupportsSuffixRangeMetadata() {
        val response = SuspendBridge.runBlocking {
            router().media(
                assetId = "media-001",
                rangeHeader = "bytes=-24",
                headers = pairingHeaders(),
            )
        } as LocalMediaResponse.Found

        assertEquals(206, response.statusCode)
        assertEquals(ByteRange(start = 1000, endInclusive = 1023, totalSize = 1024, isPartial = true), response.range)
        assertEquals("24", response.headers["Content-Length"])
        assertEquals("bytes 1000-1023/1024", response.headers["Content-Range"])
    }

    @Test
    fun mediaRejectsUnsatisfiableRange() {
        val response = SuspendBridge.runBlocking {
            router().media(
                assetId = "media-001",
                rangeHeader = "bytes=2048-4096",
                headers = pairingHeaders(),
            )
        }

        assertEquals(
            LocalMediaResponse.RangeNotSatisfiable(
                statusCode = 416,
                errorCode = "SS-REQ-416",
                headers = mapOf("Content-Range" to "bytes */1024"),
            ),
            response,
        )
    }

    private fun router(
        requestActivityTracker: LocalRequestActivityTracker? = null,
    ): LocalSyncRouter {
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
            requestActivityTracker = requestActivityTracker,
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
