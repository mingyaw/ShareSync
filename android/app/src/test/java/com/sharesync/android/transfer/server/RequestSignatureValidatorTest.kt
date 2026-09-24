package com.sharesync.android.transfer.server

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RequestSignatureValidatorTest {
    @Test
    fun signerMatchesSharedFixture() {
        val signature = RequestSignatureValidator.sign(
            secret = "pairing-token-001",
            version = "2",
            deviceId = "ios-local",
            sessionId = "ios-photo-mvp",
            method = "GET",
            path = "/v1/manifest",
            timestamp = "1800000000000",
            nonce = "nonce-001",
            body = "",
        )

        assertEquals("GBIh1J4UTOluh0qNqDDZIVMZbxRg2aXS4wxAUGusjM8=", signature)
        assertEquals(
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            RequestSignatureValidator.sha256Hex(""),
        )
    }

    @Test
    fun validatorAcceptsSignedRequestOnce() {
        val validator = RequestSignatureValidator(
            secretProvider = { "pairing-token-001" },
            clock = { 1_800_000_000_000L },
        )
        val headers = signedHeaders()

        assertTrue(
            validator.isAuthorized(
                method = "GET",
                path = "/v1/manifest",
                body = "",
                headers = headers,
            )
        )
        assertFalse(
            validator.isAuthorized(
                method = "GET",
                path = "/v1/manifest",
                body = "",
                headers = headers,
            )
        )
    }

    @Test
    fun validatorRejectsStaleTimestamp() {
        val validator = RequestSignatureValidator(
            secretProvider = { "pairing-token-001" },
            clock = { 1_800_000_400_001L },
        )

        assertFalse(
            validator.isAuthorized(
                method = "GET",
                path = "/v1/manifest",
                body = "",
                headers = signedHeaders(),
            )
        )
    }

    @Test
    fun validatorRejectsDeviceIdentityChangedAfterSigning() {
        val validator = RequestSignatureValidator(
            secretProvider = { "pairing-token-001" },
            clock = { 1_800_000_000_000L },
        )
        val headers = signedHeaders().toMutableMap().apply {
            this[RequestSignatureValidator.DEVICE_ID_HEADER] = "mac-device-001"
        }

        assertFalse(
            validator.isAuthorized(
                method = "GET",
                path = "/v1/manifest",
                body = "",
                headers = headers,
            )
        )
    }

    @Test
    fun validatorRejectsLegacySignatureVersion() {
        val validator = RequestSignatureValidator(
            secretProvider = { "pairing-token-001" },
            clock = { 1_800_000_000_000L },
        )
        val headers = signedHeaders().toMutableMap().apply {
            this[RequestSignatureValidator.VERSION_HEADER] = "1"
        }

        assertFalse(validator.isAuthorized("GET", "/v1/manifest", "", headers))
    }

    @Test
    fun registeredDeviceUsesOnlyItsDeviceSecrets() {
        val validator = RequestSignatureValidator(
            secretProvider = { "bootstrap-secret" },
            deviceSecretsProvider = { deviceId ->
                if (deviceId == "mac-device-001") listOf("mac-secret") else null
            },
            clock = { 1_800_000_000_000L },
        )

        assertFalse(
            validator.isAuthorized(
                method = "GET",
                path = "/v1/manifest",
                body = "",
                headers = signedHeaders(secret = "bootstrap-secret", deviceId = "mac-device-001"),
            )
        )
        assertTrue(
            validator.isAuthorized(
                method = "GET",
                path = "/v1/manifest",
                body = "",
                headers = signedHeaders(secret = "mac-secret", deviceId = "mac-device-001", nonce = "nonce-002"),
            )
        )
    }

    @Test
    fun revokedDeviceDoesNotFallBackToBootstrapSecret() {
        val validator = RequestSignatureValidator(
            secretProvider = { "bootstrap-secret" },
            deviceSecretsProvider = { emptyList() },
            clock = { 1_800_000_000_000L },
        )

        assertFalse(
            validator.isAuthorized(
                method = "GET",
                path = "/v1/manifest",
                body = "",
                headers = signedHeaders(secret = "bootstrap-secret", deviceId = "mac-device-001"),
            )
        )
    }

    private fun signedHeaders(): Map<String, String> {
        return signedHeaders(secret = "pairing-token-001", deviceId = "ios-local")
    }

    private fun signedHeaders(
        secret: String,
        deviceId: String,
        nonce: String = "nonce-001",
    ): Map<String, String> {
        val signature = RequestSignatureValidator.sign(
            secret = secret,
            version = "2",
            deviceId = deviceId,
            sessionId = "ios-photo-mvp",
            method = "GET",
            path = "/v1/manifest",
            timestamp = "1800000000000",
            nonce = nonce,
            body = "",
        )
        return mapOf(
            RequestSignatureValidator.VERSION_HEADER to "2",
            RequestSignatureValidator.DEVICE_ID_HEADER to deviceId,
            RequestSignatureValidator.SESSION_ID_HEADER to "ios-photo-mvp",
            RequestSignatureValidator.TIMESTAMP_HEADER to "1800000000000",
            RequestSignatureValidator.NONCE_HEADER to nonce,
            RequestSignatureValidator.SIGNATURE_HEADER to signature,
        )
    }
}
