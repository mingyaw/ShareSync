package com.sharesync.android.security

import java.security.MessageDigest
import javax.net.ssl.SSLContext

data class LocalCertificateDescriptor(
    val alias: String,
    val certificateDer: ByteArray,
    val notBefore: String? = null,
    val notAfter: String? = null,
) {
    init {
        require(alias.isNotBlank()) { "certificate alias must not be blank" }
        require(certificateDer.isNotEmpty()) { "certificate DER must not be empty" }
    }

    val fingerprintSha256Hex: String
        get() = CertificateFingerprint.sha256Hex(certificateDer)
}

interface LocalCertificateProvider {
    fun currentCertificate(): LocalCertificateDescriptor
    fun rotateCertificate(): LocalCertificateDescriptor
}

interface LocalServerTlsContextProvider {
    fun serverSSLContext(): SSLContext
}

object CertificateFingerprint {
    fun sha256Hex(certificateDer: ByteArray): String {
        require(certificateDer.isNotEmpty()) { "certificate DER must not be empty" }
        val digest = MessageDigest.getInstance("SHA-256").digest(certificateDer)
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
    }
}
