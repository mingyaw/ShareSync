package com.sharesync.android.pairing

import org.json.JSONObject
import java.net.URI
import java.time.Instant

data class MacPairingOffer(
    val deviceId: String,
    val deviceName: String,
    val callbackUrl: String,
    val pairingChallenge: String,
    val expiresAt: Instant,
)

class MacPairingOfferParser {
    fun parse(json: String, now: Instant = Instant.now()): MacPairingOffer {
        val root = JSONObject(json)
        require(root.getInt("version") == 1)
        require(root.getString("type") == "sharesync_mac_pairing")
        require(root.getString("platform") == "macos")
        val callbackUrl = root.getString("callbackURL")
        require(isAllowedCallback(callbackUrl))
        val expiration = Instant.parse(root.getString("expiresAt"))
        require(expiration.isAfter(now))
        return MacPairingOffer(
            deviceId = root.getString("deviceId").also { require(it.isNotBlank()) },
            deviceName = root.getString("deviceName").also { require(it.isNotBlank()) },
            callbackUrl = callbackUrl,
            pairingChallenge = root.getString("pairingChallenge").also { require(it.length >= 24) },
            expiresAt = expiration,
        )
    }

    private fun isAllowedCallback(value: String): Boolean {
        val uri = runCatching { URI(value) }.getOrNull() ?: return false
        if (uri.scheme != "http" || uri.path != "/v1/pairing/complete" || uri.port !in 1..65535) return false
        val octets = uri.host?.split('.')?.mapNotNull(String::toIntOrNull) ?: return false
        if (octets.size != 4 || octets.any { it !in 0..255 }) return false
        return octets[0] == 10 ||
            (octets[0] == 192 && octets[1] == 168) ||
            (octets[0] == 172 && octets[1] in 16..31)
    }
}
