package com.sharesync.android.pairing

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class PairingPayloadPersonalizerTest {
    @Test
    fun replacesOnlyPairingToken() {
        val original = """{"version":1,"type":"sharesync_pairing","platform":"android","pairingToken":"bootstrap","registrationToken":"ios-only"}"""

        val personalized = PairingPayloadPersonalizer().replacePairingToken(original, "mac-secret")
        val payload = JSONObject(personalized)

        assertEquals(1, payload.getInt("version"))
        assertEquals("sharesync_pairing", payload.getString("type"))
        assertEquals("android", payload.getString("platform"))
        assertEquals("mac-secret", payload.getString("pairingToken"))
        assertEquals(false, payload.has("registrationToken"))
    }
}
