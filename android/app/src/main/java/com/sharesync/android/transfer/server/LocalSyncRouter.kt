package com.sharesync.android.transfer.server

import com.sharesync.android.sync.ManifestJsonEncoder
import com.sharesync.android.sync.MediaAsset
import com.sharesync.android.sync.SyncResultJsonCodec
import com.sharesync.android.sync.SyncResultStore
import org.json.JSONException

class LocalSyncRouter(
    private val deviceId: String,
    private val appVersion: String,
    private val manifestProvider: ManifestProvider,
    private val mediaProvider: MediaProvider,
    private val syncResultStore: SyncResultStore,
    private val manifestJsonEncoder: ManifestJsonEncoder = ManifestJsonEncoder(),
    private val syncResultJsonCodec: SyncResultJsonCodec = SyncResultJsonCodec(),
) {
    suspend fun health(): LocalApiResponse {
        return LocalApiResponse.json(
            body = """
                {
                  "status": "ok",
                  "deviceId": "${deviceId.escapeJson()}",
                  "appVersion": "${appVersion.escapeJson()}",
                  "protocolVersion": 1
                }
            """.trimIndent()
        )
    }

    suspend fun manifest(): LocalApiResponse {
        return LocalApiResponse.json(
            body = manifestJsonEncoder.encode(manifestProvider.currentManifest())
        )
    }

    suspend fun media(assetId: String, rangeHeader: String? = null): LocalMediaResponse {
        val asset = mediaProvider.findMedia(assetId)
            ?: return LocalMediaResponse.notFound("SS-MEDIA-404")

        val range = ByteRange.parse(rangeHeader, asset.size)
        return LocalMediaResponse.found(
            asset = asset,
            range = range,
        )
    }

    suspend fun syncResult(body: String): LocalApiResponse {
        return try {
            val result = syncResultJsonCodec.decode(body)
            syncResultStore.save(result)
            LocalApiResponse.json(
                statusCode = 202,
                body = """
                    {
                      "status": "accepted",
                      "syncBatchId": "${result.syncBatchId.escapeJson()}",
                      "resultCount": ${result.results.size}
                    }
                """.trimIndent()
            )
        } catch (_: JSONException) {
            LocalApiResponse.jsonError(statusCode = 400, errorCode = "SS-REQ-001")
        } catch (_: IllegalArgumentException) {
            LocalApiResponse.jsonError(statusCode = 400, errorCode = "SS-REQ-001")
        }
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

    companion object {
        fun found(asset: MediaAsset, range: ByteRange): LocalMediaResponse {
            val contentLength = range.endInclusive - range.start + 1
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
    }
}

data class ByteRange(
    val start: Long,
    val endInclusive: Long,
    val totalSize: Long,
    val isPartial: Boolean,
) {
    companion object {
        fun parse(rangeHeader: String?, totalSize: Long): ByteRange {
            if (rangeHeader.isNullOrBlank() || !rangeHeader.startsWith("bytes=")) {
                return ByteRange(
                    start = 0,
                    endInclusive = maxOf(totalSize - 1, 0),
                    totalSize = totalSize,
                    isPartial = false,
                )
            }

            val range = rangeHeader.removePrefix("bytes=").substringBefore(",")
            val startText = range.substringBefore("-")
            val endText = range.substringAfter("-", missingDelimiterValue = "")
            val start = startText.toLongOrNull()?.coerceAtLeast(0) ?: 0
            val requestedEnd = endText.toLongOrNull() ?: (totalSize - 1)
            val end = requestedEnd.coerceAtMost(totalSize - 1).coerceAtLeast(start)

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
