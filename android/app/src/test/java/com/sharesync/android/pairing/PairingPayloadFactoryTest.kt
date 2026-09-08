package com.sharesync.android.pairing

import com.sharesync.android.sync.ManifestJsonEncoder
import com.sharesync.android.sync.PairingTransportSecurity
import com.sharesync.android.sync.PairingTransportSecurityMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class PairingPayloadFactoryTest {
    @Test
    fun createPayloadCanIncludeTransportSecurityForQrPinnedHttps() {
        val payload = pairingPayloadFactory(
            transportSecurity = PairingTransportSecurity(
                mode = PairingTransportSecurityMode.qr_pinned_https,
                certificateFingerprintSha256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
                certificateNotBefore = "2026-09-08T00:00:00Z",
                certificateNotAfter = "2027-09-08T00:00:00Z",
            )
        ).createPayload(now = Instant.parse("2026-09-08T00:00:00Z"))

        assertEquals(PairingTransportSecurityMode.qr_pinned_https, payload.transportSecurity?.mode)
        assertEquals(
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            payload.transportSecurity?.certificateFingerprintSha256,
        )

        val json = ManifestJsonEncoder().encode(payload)

        assertTrue(json.contains("\"transportSecurity\""))
        assertTrue(json.contains("\"mode\":\"qr_pinned_https\""))
        assertTrue(json.contains("\"certificateFingerprintEncoding\":\"hex\""))
    }

    @Test
    fun createPayloadKeepsTransportSecurityOptionalForSignedHttpCompatibility() {
        val payload = pairingPayloadFactory().createPayload(now = Instant.parse("2026-09-08T00:00:00Z"))

        assertEquals(null, payload.transportSecurity)

        val json = ManifestJsonEncoder().encode(payload)

        assertTrue(!json.contains("\"transportSecurity\""))
    }

    private fun pairingPayloadFactory(
        transportSecurity: PairingTransportSecurity? = null,
    ): PairingPayloadFactory {
        return PairingPayloadFactory(
            deviceIdProvider = { "android-demo-device" },
            deviceNameProvider = { "Pixel Demo" },
            publicKeyProvider = { "demo-public-key" },
            localIpProvider = { "192.168.1.20" },
            portProvider = { 48291 },
            pairingTokenProvider = { "0123456789abcdef0123456789abcdef" },
            transportSecurityProvider = { transportSecurity },
        )
    }
}
