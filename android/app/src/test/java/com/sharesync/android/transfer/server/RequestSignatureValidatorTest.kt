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
            method = "GET",
            path = "/v1/manifest",
            timestamp = "1800000000000",
            nonce = "nonce-001",
            body = "",
        )

        assertEquals("V+Zfc9LZCzOl+H/8ZpZGbCjZ2WiZxwo2mgc17pPqPhY=", signature)
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

    private fun signedHeaders(): Map<String, String> {
        return mapOf(
            RequestSignatureValidator.VERSION_HEADER to "1",
            RequestSignatureValidator.DEVICE_ID_HEADER to "ios-local",
            RequestSignatureValidator.SESSION_ID_HEADER to "ios-photo-mvp",
            RequestSignatureValidator.TIMESTAMP_HEADER to "1800000000000",
            RequestSignatureValidator.NONCE_HEADER to "nonce-001",
            RequestSignatureValidator.SIGNATURE_HEADER to "V+Zfc9LZCzOl+H/8ZpZGbCjZ2WiZxwo2mgc17pPqPhY=",
        )
    }
}
