package com.sharesync.android.security

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.cert.X509Certificate
import java.security.spec.ECGenParameterSpec
import java.time.Duration
import java.time.Instant
import java.util.Date
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.security.auth.x500.X500Principal

class AndroidKeyStoreLocalCertificateProvider(
    private val alias: String = DEFAULT_ALIAS,
    private val clock: () -> Instant = Instant::now,
    private val validity: Duration = DEFAULT_VALIDITY,
) : LocalCertificateProvider, LocalServerTlsContextProvider {
    private val lock = Any()

    init {
        require(alias.isNotBlank()) { "certificate alias must not be blank" }
        require(!validity.isNegative && !validity.isZero) { "certificate validity must be positive" }
    }

    override fun currentCertificate(): LocalCertificateDescriptor {
        synchronized(lock) {
            val keyStore = loadedKeyStore()
            if (!keyStore.containsAlias(alias)) {
                generateKeyPair()
            }
            return descriptorFrom(keyStore)
        }
    }

    override fun rotateCertificate(): LocalCertificateDescriptor {
        synchronized(lock) {
            val keyStore = loadedKeyStore()
            if (keyStore.containsAlias(alias)) {
                keyStore.deleteEntry(alias)
            }
            generateKeyPair()
            return descriptorFrom(loadedKeyStore())
        }
    }

    override fun serverSSLContext(): SSLContext {
        synchronized(lock) {
            currentCertificate()
            val keyStore = loadedKeyStore()
            val keyManagerFactory = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm())
            keyManagerFactory.init(keyStore, null)
            return SSLContext.getInstance("TLS").apply {
                init(keyManagerFactory.keyManagers, null, null)
            }
        }
    }

    private fun generateKeyPair() {
        val now = clock()
        val notBefore = Date.from(now)
        val notAfter = Date.from(now.plus(validity))
        val spec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
        )
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setCertificateSubject(X500Principal("CN=ShareSync Local Transport"))
            .setCertificateSerialNumber(BigInteger.valueOf(now.epochSecond.coerceAtLeast(1L)))
            .setCertificateNotBefore(notBefore)
            .setCertificateNotAfter(notAfter)
            .build()

        KeyPairGenerator
            .getInstance(KeyProperties.KEY_ALGORITHM_EC, ANDROID_KEYSTORE)
            .apply { initialize(spec) }
            .generateKeyPair()
    }

    private fun descriptorFrom(keyStore: KeyStore): LocalCertificateDescriptor {
        val certificate = keyStore.getCertificate(alias)
            ?: error("missing ShareSync local certificate for alias $alias")
        val x509Certificate = certificate as? X509Certificate
        return LocalCertificateDescriptor(
            alias = alias,
            certificateDer = certificate.encoded,
            notBefore = x509Certificate?.notBefore?.toInstant()?.toString(),
            notAfter = x509Certificate?.notAfter?.toInstant()?.toString(),
        )
    }

    private fun loadedKeyStore(): KeyStore {
        return KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    }

    companion object {
        const val DEFAULT_ALIAS = "sharesync-local-transport"
        val DEFAULT_VALIDITY: Duration = Duration.ofDays(365)
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    }
}
