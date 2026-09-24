package com.sharesync.android.pairing

import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.InetSocketAddress
import java.net.Socket
import java.net.URI
import java.time.Instant

class MacPairingCallbackClient(
    private val payloadCipher: MacPairingPayloadCipher = MacPairingPayloadCipher(),
) {
    fun complete(offer: MacPairingOffer, androidPairingPayload: String) {
        require(offer.expiresAt.isAfter(Instant.now()))
        val callback = URI(offer.callbackUrl)
        require(callback.scheme == "http")
        require(callback.path == "/v1/pairing/complete")
        require(callback.port in 1..65_535)
        val body = payloadCipher.encrypt(
            plaintext = androidPairingPayload.toByteArray(Charsets.UTF_8),
            encodedKey = offer.callbackEncryptionKey,
            associatedData = offer.pairingChallenge.toByteArray(Charsets.UTF_8),
        ).toByteArray(Charsets.UTF_8)
        val request = buildString {
            append("POST ${callback.rawPath} HTTP/1.1\r\n")
            append("Host: ${callback.host}:${callback.port}\r\n")
            append("Content-Type: application/json\r\n")
            append("X-ShareSync-Pairing-Challenge: ${offer.pairingChallenge}\r\n")
            append("Content-Length: ${body.size}\r\n")
            append("Connection: close\r\n\r\n")
        }.toByteArray(Charsets.US_ASCII)

        Socket().use { socket ->
            socket.connect(InetSocketAddress(callback.host, callback.port), TIMEOUT_MILLIS)
            socket.soTimeout = TIMEOUT_MILLIS
            val output = socket.getOutputStream()
            output.write(request)
            output.write(body)
            output.flush()
            val statusLine = BufferedReader(
                InputStreamReader(socket.getInputStream(), Charsets.US_ASCII),
            ).readLine().orEmpty()
            require(statusLine.startsWith("HTTP/1.1 202 ") || statusLine.startsWith("HTTP/1.0 202 "))
        }
    }

    private companion object {
        const val TIMEOUT_MILLIS = 5_000
    }
}
