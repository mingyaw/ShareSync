package com.sharesync.android.pairing

import java.security.SecureRandom
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.Base64

data class PairingRegistrationWindow(
    val token: String,
    val expiresAt: Instant,
    private val clock: () -> Instant = Instant::now,
) {
    fun isOpen(): Boolean = expiresAt.isAfter(clock())

    companion object {
        fun create(now: Instant = Instant.now()): PairingRegistrationWindow {
            val bytes = ByteArray(32).also(SecureRandom()::nextBytes)
            return PairingRegistrationWindow(
                token = Base64.getEncoder().withoutPadding().encodeToString(bytes),
                expiresAt = now.plus(10, ChronoUnit.MINUTES),
            )
        }
    }
}
