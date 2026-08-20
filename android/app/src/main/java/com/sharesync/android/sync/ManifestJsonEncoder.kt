package com.sharesync.android.sync

class ManifestJsonEncoder {
    fun encode(payload: PairingPayload): String {
        return buildString {
            append("{")
            appendJsonField("version", payload.version)
            append(",")
            appendJsonField("type", payload.type)
            append(",")
            appendJsonField("deviceId", payload.deviceId)
            append(",")
            appendJsonField("deviceName", payload.deviceName)
            append(",")
            appendJsonField("platform", payload.platform)
            append(",")
            appendJsonField("publicKey", payload.publicKey)
            append(",")
            appendJsonField("ip", payload.ip)
            append(",")
            appendJsonField("port", payload.port)
            append(",")
            appendJsonField("pairingToken", payload.pairingToken)
            append(",")
            appendJsonField("expiresAt", payload.expiresAt)
            append("}")
        }
    }

    fun encode(manifest: SyncManifest): String {
        return buildString {
            append("{")
            appendJsonField("version", manifest.version)
            append(",")
            appendJsonField("sourceDeviceId", manifest.sourceDeviceId)
            append(",")
            appendJsonField("generatedAt", manifest.generatedAt)
            append(",")
            appendJsonField("cursor", manifest.cursor)
            append(",\"media\":")
            appendMediaArray(manifest.media)
            append(",\"contacts\":[]")
            append(",\"files\":[]")
            append("}")
        }
    }

    private fun StringBuilder.appendMediaArray(media: List<MediaAsset>) {
        append("[")
        media.forEachIndexed { index, asset ->
            if (index > 0) append(",")
            append("{")
            appendJsonField("assetId", asset.assetId)
            append(",")
            appendJsonField("sourceDeviceId", asset.sourceDeviceId)
            append(",")
            appendJsonField("mediaType", asset.mediaType.name)
            append(",")
            appendJsonField("fileName", asset.fileName)
            append(",")
            appendJsonField("mimeType", asset.mimeType)
            append(",")
            appendJsonField("size", asset.size)
            append(",")
            appendJsonNullableField("sha256", asset.sha256)
            append(",")
            appendJsonNullableField("createdAt", asset.createdAt)
            append(",")
            appendJsonNullableField("modifiedAt", asset.modifiedAt)
            append(",")
            appendJsonNullableField("takenAt", asset.takenAt)
            append(",")
            appendJsonNullableField("width", asset.width)
            append(",")
            appendJsonNullableField("height", asset.height)
            append(",")
            appendJsonNullableField("durationMs", asset.durationMs)
            append(",")
            appendJsonNullableField("relativePath", asset.relativePath)
            append("}")
        }
        append("]")
    }

    private fun StringBuilder.appendJsonField(name: String, value: String) {
        append("\"")
        append(escape(name))
        append("\":\"")
        append(escape(value))
        append("\"")
    }

    private fun StringBuilder.appendJsonField(name: String, value: Int) {
        append("\"")
        append(escape(name))
        append("\":")
        append(value)
    }

    private fun StringBuilder.appendJsonField(name: String, value: Long) {
        append("\"")
        append(escape(name))
        append("\":")
        append(value)
    }

    private fun StringBuilder.appendJsonNullableField(name: String, value: String?) {
        append("\"")
        append(escape(name))
        append("\":")
        if (value == null) {
            append("null")
        } else {
            append("\"")
            append(escape(value))
            append("\"")
        }
    }

    private fun StringBuilder.appendJsonNullableField(name: String, value: Int?) {
        append("\"")
        append(escape(name))
        append("\":")
        append(value?.toString() ?: "null")
    }

    private fun StringBuilder.appendJsonNullableField(name: String, value: Long?) {
        append("\"")
        append(escape(name))
        append("\":")
        append(value?.toString() ?: "null")
    }

    private fun escape(value: String): String {
        return buildString {
            value.forEach { char ->
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
}
