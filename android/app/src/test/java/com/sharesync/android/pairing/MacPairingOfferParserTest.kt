package com.sharesync.android.pairing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.time.Instant

class MacPairingOfferParserTest {
    private val now = Instant.parse("2026-09-23T08:00:00Z")

    @Test
    fun parsesValidPrivateNetworkOffer() {
        val offer = MacPairingOfferParser().parse(validJson(), now)

        assertEquals("mac-device", offer.deviceId)
        assertEquals("Mingyao Mac", offer.deviceName)
        assertEquals("http://192.168.1.20:49152/v1/pairing/complete", offer.callbackUrl)
    }

    @Test
    fun rejectsExpiredOffer() {
        assertThrows(IllegalArgumentException::class.java) {
            MacPairingOfferParser().parse(validJson(expiresAt = "2026-09-23T07:59:59Z"), now)
        }
    }

    @Test
    fun rejectsPublicOrUnexpectedCallback() {
        listOf(
            "http://8.8.8.8:49152/v1/pairing/complete",
            "https://192.168.1.20:49152/v1/pairing/complete",
            "http://192.168.1.20:49152/upload",
        ).forEach { callback ->
            assertThrows(IllegalArgumentException::class.java) {
                MacPairingOfferParser().parse(validJson(callback = callback), now)
            }
        }
    }

    private fun validJson(
        callback: String = "http://192.168.1.20:49152/v1/pairing/complete",
        expiresAt: String = "2026-09-23T08:03:00Z",
    ): String = """
        {
          "version": 1,
          "type": "sharesync_mac_pairing",
          "deviceId": "mac-device",
          "deviceName": "Mingyao Mac",
          "platform": "macos",
          "callbackURL": "$callback",
          "pairingChallenge": "0123456789abcdef0123456789abcdef",
          "expiresAt": "$expiresAt"
        }
    """.trimIndent()
}
