package com.sharesync.android.pairing

import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant

class MacPairingCallbackClient {
    fun complete(offer: MacPairingOffer, androidPairingPayload: String) {
        require(offer.expiresAt.isAfter(Instant.now()))
        val connection = URL(offer.callbackUrl).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 5_000
            connection.readTimeout = 5_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("X-ShareSync-Pairing-Challenge", offer.pairingChallenge)
            connection.outputStream.use { output -> output.write(androidPairingPayload.toByteArray(Charsets.UTF_8)) }
            require(connection.responseCode == HttpURLConnection.HTTP_ACCEPTED)
        } finally {
            connection.disconnect()
        }
    }
}
