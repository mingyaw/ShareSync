package com.sharesync.android.pairing

import org.json.JSONObject
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

class MacPairingPayloadCipher(
    private val secureRandom: SecureRandom = SecureRandom(),
) {
    fun encrypt(plaintext: ByteArray, encodedKey: String, associatedData: ByteArray): String {
        val key = Base64.getDecoder().decode(encodedKey)
        require(key.size == KEY_SIZE_BYTES)
        val nonce = ByteArray(NONCE_SIZE_BYTES).also(secureRandom::nextBytes)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_SIZE_BITS, nonce))
        cipher.updateAAD(associatedData)
        val encrypted = cipher.doFinal(plaintext)
        val combined = nonce + encrypted
        return JSONObject()
            .put("version", 1)
            .put("algorithm", "AES-256-GCM")
            .put("sealedPayload", Base64.getEncoder().encodeToString(combined))
            .toString()
    }

    fun decrypt(envelope: String, encodedKey: String, associatedData: ByteArray): ByteArray {
        val root = JSONObject(envelope)
        require(root.getInt("version") == 1)
        require(root.getString("algorithm") == "AES-256-GCM")
        val combined = Base64.getDecoder().decode(root.getString("sealedPayload"))
        require(combined.size > NONCE_SIZE_BYTES + TAG_SIZE_BYTES)
        val nonce = combined.copyOfRange(0, NONCE_SIZE_BYTES)
        val encrypted = combined.copyOfRange(NONCE_SIZE_BYTES, combined.size)
        val key = Base64.getDecoder().decode(encodedKey)
        require(key.size == KEY_SIZE_BYTES)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_SIZE_BITS, nonce))
        cipher.updateAAD(associatedData)
        return cipher.doFinal(encrypted)
    }

    private companion object {
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val KEY_SIZE_BYTES = 32
        const val NONCE_SIZE_BYTES = 12
        const val TAG_SIZE_BYTES = 16
        const val TAG_SIZE_BITS = TAG_SIZE_BYTES * 8
    }
}
