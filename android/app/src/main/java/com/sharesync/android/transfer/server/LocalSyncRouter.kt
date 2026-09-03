package com.sharesync.android.transfer.server

import com.sharesync.android.sync.ManifestJsonEncoder
import com.sharesync.android.sync.MediaAsset
import com.sharesync.android.sync.SyncItemType
import com.sharesync.android.sync.SyncItemStatus
import com.sharesync.android.sync.SyncResult
import com.sharesync.android.sync.SyncResultJsonCodec
import com.sharesync.android.sync.SyncResultStore
import org.json.JSONException

class LocalSyncRouter(
    private val deviceId: String,
    private val appVersion: String,
    private val pairingToken: String,
    private val manifestProvider: ManifestProvider,
    private val mediaProvider: MediaProvider,
    private val syncResultStore: SyncResultStore,
    private val manifestJsonEncoder: ManifestJsonEncoder = ManifestJsonEncoder(),
    private val syncResultJsonCodec: SyncResultJsonCodec = SyncResultJsonCodec(),
    private val requestActivityTracker: LocalRequestActivityTracker? = null,
    private val signatureValidator: RequestSignatureValidator = RequestSignatureValidator(
        secretProvider = { pairingToken },
    ),
) {
    suspend fun health(): LocalApiResponse {
        val response = LocalApiResponse.json(
            body = """
                {
                  "status": "ok",
                  "deviceId": "${deviceId.escapeJson()}",
                  "appVersion": "${appVersion.escapeJson()}",
                  "protocolVersion": 1
                }
            """.trimIndent()
        )
        requestActivityTracker?.record("health", response.statusCode)
        return response
    }

    suspend fun manifest(headers: Map<String, String> = emptyMap(), path: String = "/v1/manifest"): LocalApiResponse {
        if (!isAuthorized(method = "GET", path = path, body = "", headers = headers)) {
            val response = LocalApiResponse.jsonError(statusCode = 401, errorCode = "SS-AUTH-001")
            requestActivityTracker?.record("manifest", response.statusCode)
            return response
        }

        val response = LocalApiResponse.json(
            body = manifestJsonEncoder.encode(manifestProvider.currentManifest())
        )
        requestActivityTracker?.record("manifest", response.statusCode)
        return response
    }

    suspend fun media(
        assetId: String,
        rangeHeader: String? = null,
        headers: Map<String, String> = emptyMap(),
        path: String = "/v1/media/$assetId",
    ): LocalMediaResponse {
        if (!isAuthorized(method = "GET", path = path, body = "", headers = headers)) {
            val response = LocalMediaResponse.unauthorized("SS-AUTH-001")
            requestActivityTracker?.record("media", response.httpStatusCode())
            return response
        }

        val asset = mediaProvider.findMedia(assetId)
        if (asset == null) {
            val response = LocalMediaResponse.notFound("SS-MEDIA-404")
            requestActivityTracker?.record("media", response.httpStatusCode())
            return response
        }

        val range = ByteRange.parse(rangeHeader, asset.size)
        if (range == null) {
            val response = LocalMediaResponse.rangeNotSatisfiable("SS-REQ-416", asset.size)
            requestActivityTracker?.record("media", response.httpStatusCode())
            return response
        }

        val response = LocalMediaResponse.found(
            asset = asset,
            range = range,
        )
        requestActivityTracker?.record("media", response.httpStatusCode())
        return response
    }

    suspend fun syncResult(
        body: String,
        headers: Map<String, String> = emptyMap(),
        path: String = "/v1/sync/result",
    ): LocalApiResponse {
        if (!isAuthorized(method = "POST", path = path, body = body, headers = headers)) {
            val response = LocalApiResponse.jsonError(statusCode = 401, errorCode = "SS-AUTH-001")
            requestActivityTracker?.record("sync-result", response.statusCode)
            return response
        }

        return try {
            val result = syncResultJsonCodec.decode(body)
            validateSyncResult(result)
            syncResultStore.save(result)
            val response = LocalApiResponse.json(
                statusCode = 202,
                body = """
                    {
                      "status": "accepted",
                      "syncBatchId": "${result.syncBatchId.escapeJson()}",
                      "resultCount": ${result.results.size}
                    }
                """.trimIndent()
            )
            requestActivityTracker?.record("sync-result", response.statusCode)
            response
        } catch (_: JSONException) {
            val response = LocalApiResponse.jsonError(statusCode = 400, errorCode = "SS-REQ-001")
            requestActivityTracker?.record("sync-result", response.statusCode)
            response
        } catch (_: IllegalArgumentException) {
            val response = LocalApiResponse.jsonError(statusCode = 400, errorCode = "SS-REQ-001")
            requestActivityTracker?.record("sync-result", response.statusCode)
            response
        }
    }

    private fun validateSyncResult(result: SyncResult) {
        require(result.syncBatchId.isNotBlank())
        require(result.targetDeviceId.isNotBlank())
        result.results.forEach { item ->
            require(item.itemType == SyncItemType.media)
            require(item.sourceItemId.isNotBlank())
            when (item.status) {
                SyncItemStatus.synced,
                SyncItemStatus.skipped,
                -> require(item.errorCode.isNullOrBlank())
                SyncItemStatus.failed,
                SyncItemStatus.conflicted,
                -> require(!item.errorCode.isNullOrBlank())
            }
        }
    }

    private fun isAuthorized(method: String, path: String, body: String, headers: Map<String, String>): Boolean {
        if (signatureValidator.isAuthorized(method = method, path = path, body = body, headers = headers)) {
            return true
        }

        return headers.any { (name, value) ->
            name.equals(PAIRING_TOKEN_HEADER, ignoreCase = true) && value == pairingToken
        }
    }

    companion object {
        const val PAIRING_TOKEN_HEADER = "X-ShareSync-Pairing-Token"
    }
}

interface MediaProvider {
    suspend fun findMedia(assetId: String): MediaAsset?
}

data class LocalApiResponse(
    val statusCode: Int,
    val headers: Map<String, String>,
    val body: String,
) {
    companion object {
        fun json(body: String, statusCode: Int = 200): LocalApiResponse {
            return LocalApiResponse(
                statusCode = statusCode,
                headers = mapOf("Content-Type" to "application/json; charset=utf-8"),
                body = body,
            )
        }

        fun jsonError(statusCode: Int, errorCode: String): LocalApiResponse {
            return json(
                statusCode = statusCode,
                body = """{"errorCode":"${errorCode.escapeJson()}"}""",
            )
        }
    }
}

sealed class LocalMediaResponse {
    data class Found(
        val asset: MediaAsset,
        val range: ByteRange,
        val statusCode: Int,
        val headers: Map<String, String>,
    ) : LocalMediaResponse()

    data class NotFound(
        val statusCode: Int,
        val errorCode: String,
    ) : LocalMediaResponse()

    data class Unauthorized(
        val statusCode: Int,
        val errorCode: String,
    ) : LocalMediaResponse()

    data class RangeNotSatisfiable(
        val statusCode: Int,
        val errorCode: String,
        val headers: Map<String, String>,
    ) : LocalMediaResponse()

    companion object {
        fun found(asset: MediaAsset, range: ByteRange): LocalMediaResponse {
            val contentLength = (range.endInclusive - range.start + 1).coerceAtLeast(0)
            val statusCode = if (range.isPartial) 206 else 200
            val headers = buildMap {
                put("Content-Type", asset.mimeType)
                put("Content-Length", contentLength.toString())
                put("Accept-Ranges", "bytes")
                put("X-ShareSync-Asset-Id", asset.assetId)
                asset.sha256?.let { put("X-ShareSync-SHA256", it) }
                if (range.isPartial) {
                    put("Content-Range", "bytes ${range.start}-${range.endInclusive}/${range.totalSize}")
                }
            }

            return Found(
                asset = asset,
                range = range,
                statusCode = statusCode,
                headers = headers,
            )
        }

        fun notFound(errorCode: String): LocalMediaResponse {
            return NotFound(statusCode = 404, errorCode = errorCode)
        }

        fun unauthorized(errorCode: String): LocalMediaResponse {
            return Unauthorized(statusCode = 401, errorCode = errorCode)
        }

        fun rangeNotSatisfiable(errorCode: String, totalSize: Long): LocalMediaResponse {
            return RangeNotSatisfiable(
                statusCode = 416,
                errorCode = errorCode,
                headers = mapOf("Content-Range" to "bytes */${totalSize.coerceAtLeast(0)}"),
            )
        }
    }
}

data class ByteRange(
    val start: Long,
    val endInclusive: Long,
    val totalSize: Long,
    val isPartial: Boolean,
) {
    companion object {
        fun parse(rangeHeader: String?, totalSize: Long): ByteRange? {
            if (rangeHeader.isNullOrBlank() || !rangeHeader.startsWith("bytes=")) {
                return ByteRange(
                    start = 0,
                    endInclusive = maxOf(totalSize - 1, 0),
                    totalSize = totalSize,
                    isPartial = false,
                )
            }

            if (totalSize <= 0) {
                return null
            }

            val range = rangeHeader.removePrefix("bytes=").substringBefore(",").trim()
            if (!range.contains("-")) {
                return null
            }

            val startText = range.substringBefore("-")
            val endText = range.substringAfter("-", missingDelimiterValue = "")
            val start = if (startText.isEmpty()) {
                val suffixLength = endText.toLongOrNull() ?: return null
                if (suffixLength <= 0) {
                    return null
                }
                (totalSize - suffixLength).coerceAtLeast(0)
            } else {
                startText.toLongOrNull()?.coerceAtLeast(0) ?: return null
            }
            if (start >= totalSize) {
                return null
            }

            val requestedEnd = if (startText.isEmpty()) {
                totalSize - 1
            } else {
                endText.toLongOrNull() ?: (totalSize - 1)
            }
            if (requestedEnd < start) {
                return null
            }

            val end = requestedEnd.coerceAtMost(totalSize - 1)

            return ByteRange(
                start = start,
                endInclusive = end,
                totalSize = totalSize,
                isPartial = true,
            )
        }
    }
}

private fun String.escapeJson(): String {
    return buildString {
        this@escapeJson.forEach { char ->
            when (char) {
                '\\' -> append("\\\\")
                '"' -> append("\\\"")
                '\n' -> append("\\n")
                '\r' -> append("\\r")
                '\t' -> append("\\t")
                else -> append(char)
            }
        }
    }
}

private fun LocalMediaResponse.httpStatusCode(): Int {
    return when (this) {
        is LocalMediaResponse.Found -> statusCode
        is LocalMediaResponse.NotFound -> statusCode
        is LocalMediaResponse.Unauthorized -> statusCode
        is LocalMediaResponse.RangeNotSatisfiable -> statusCode
    }
}
