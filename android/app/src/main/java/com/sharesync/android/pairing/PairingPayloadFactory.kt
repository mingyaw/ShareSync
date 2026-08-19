package com.sharesync.android.pairing

import com.sharesync.android.sync.PairingPayload
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

class PairingPayloadFactory(
    private val deviceIdProvider: () -> String,
    private val deviceNameProvider: () -> String,
    private val publicKeyProvider: () -> String,
    private val localIpProvider: () -> String,
    private val portProvider: () -> Int,
) {
    fun createPayload(now: Instant = Instant.now()): PairingPayload {
        return PairingPayload(
            deviceId = deviceIdProvider(),
            deviceName = deviceNameProvider(),
            publicKey = publicKeyProvider(),
            ip = localIpProvider(),
            port = portProvider(),
            pairingToken = UUID.randomUUID().toString().replace("-", ""),
            expiresAt = now.plus(10, ChronoUnit.MINUTES).toString(),
        )
    }
}

