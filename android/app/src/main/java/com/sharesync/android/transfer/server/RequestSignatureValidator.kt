package com.sharesync.android.transfer.server

import java.security.MessageDigest
import java.util.Base64
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.math.abs

class RequestSignatureValidator(
    private val secretProvider: () -> String,
    private val clock: () -> Long = System::currentTimeMillis,
    private val allowedSkewMillis: Long = DEFAULT_ALLOWED_SKEW_MILLIS,
) {
    private val usedNonces = mutableSetOf<String>()

    fun isAuthorized(
        method: String,
        path: String,
        body: String,
        headers: Map<String, String>,
    ): Boolean {
        val timestamp = headers.valueFor(TIMESTAMP_HEADER)?.toLongOrNull() ?: return false
        if (abs(clock() - timestamp) > allowedSkewMillis) {
            return false
        }

        val nonce = headers.valueFor(NONCE_HEADER)?.takeIf { it.isNotBlank() } ?: return false

        val expectedSignature = sign(
            secret = secretProvider(),
            method = method,
            path = path,
            timestamp = timestamp.toString(),
            nonce = nonce,
            body = body,
        )
        val providedSignature = headers.valueFor(SIGNATURE_HEADER) ?: return false
        val matches = MessageDigest.isEqual(
            expectedSignature.toByteArray(Charsets.UTF_8),
            providedSignature.toByteArray(Charsets.UTF_8),
        )
        if (matches) {
            synchronized(usedNonces) {
                if (usedNonces.contains(nonce)) {
                    return false
                }
                usedNonces.add(nonce)
            }
        }
        return matches
    }

    companion object {
        const val VERSION_HEADER = "X-ShareSync-Version"
        const val DEVICE_ID_HEADER = "X-Device-Id"
        const val SESSION_ID_HEADER = "X-Session-Id"
        const val TIMESTAMP_HEADER = "X-Timestamp"
        const val NONCE_HEADER = "X-Nonce"
        const val SIGNATURE_HEADER = "X-Signature"
        const val DEFAULT_ALLOWED_SKEW_MILLIS = 5 * 60 * 1000L

        fun sign(
            secret: String,
            method: String,
            path: String,
            timestamp: String,
            nonce: String,
            body: String,
        ): String {
            val canonicalPayload = listOf(
                method.uppercase(),
                path,
                timestamp,
                nonce,
                sha256Hex(body),
            ).joinToString("\n")
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
            return Base64.getEncoder().encodeToString(
                mac.doFinal(canonicalPayload.toByteArray(Charsets.UTF_8)),
            )
        }

        fun sha256Hex(body: String): String {
            return MessageDigest.getInstance("SHA-256")
                .digest(body.toByteArray(Charsets.UTF_8))
                .joinToString("") { "%02x".format(it) }
        }
    }
}

private fun Map<String, String>.valueFor(name: String): String? {
    return entries.firstOrNull { (key, _) -> key.equals(name, ignoreCase = true) }?.value
}
