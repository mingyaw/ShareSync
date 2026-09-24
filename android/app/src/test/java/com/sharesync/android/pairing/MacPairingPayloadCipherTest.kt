package com.sharesync.android.pairing

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class MacPairingPayloadCipherTest {
    private val cipher = MacPairingPayloadCipher()

    @Test
    fun encryptsAndDecryptsPairingPayloadWithChallengeBinding() {
        val plaintext = "{\"pairingToken\":\"secret-token\"}".toByteArray()
        val challenge = "0123456789abcdef0123456789abcdef".toByteArray()

        val envelope = cipher.encrypt(plaintext, ENCRYPTION_KEY, challenge)
        val decrypted = cipher.decrypt(envelope, ENCRYPTION_KEY, challenge)

        assertNotEquals(String(plaintext), envelope)
        assertEquals(String(plaintext), String(decrypted))
    }

    @Test
    fun rejectsEnvelopeWhenPairingChallengeChanges() {
        val envelope = cipher.encrypt("secret".toByteArray(), ENCRYPTION_KEY, "challenge-a".toByteArray())

        assertThrows(Exception::class.java) {
            cipher.decrypt(envelope, ENCRYPTION_KEY, "challenge-b".toByteArray())
        }
    }

    private companion object {
        const val ENCRYPTION_KEY = "MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDE="
    }
}
