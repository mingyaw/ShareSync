package com.sharesync.android

import com.sharesync.android.security.LocalCertificateDescriptor
import com.sharesync.android.security.LocalCertificateProvider
import com.sharesync.android.security.LocalServerTlsContextProvider
import com.sharesync.android.transfer.server.EmbeddedLocalHttpsServerBinder
import com.sharesync.android.transfer.server.EmbeddedLocalServerBinder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import javax.net.ssl.SSLContext

class AndroidM0TransportConfigurationFactoryTest {
    @Test
    fun qrPinnedHttpsBuildFlagDefaultsOff() {
        assertEquals(false, AndroidM0TransportFlags.enableQrPinnedHttps)
    }

    @Test
    fun signedHttpConfigurationUsesHttpBinderWithoutTransportSecurityMetadata() {
        val configuration = AndroidM0TransportConfigurationFactory.signedHttp()

        assertEquals(AndroidM0TransportSecurityMode.SIGNED_HTTP, configuration.mode)
        assertTrue(configuration.serverBinder is EmbeddedLocalServerBinder)
        assertNull(configuration.transportSecurityFactory)
    }

    @Test
    fun qrPinnedHttpsConfigurationCouplesHttpsBinderWithPairingMetadata() {
        val certificateProvider = FixedLocalCertificateProvider()
        val configuration = AndroidM0TransportConfigurationFactory.qrPinnedHttps(certificateProvider)

        assertEquals(AndroidM0TransportSecurityMode.QR_PINNED_HTTPS, configuration.mode)
        assertTrue(configuration.serverBinder is EmbeddedLocalHttpsServerBinder)
        assertEquals(
            "55c53f5d490297900cefa825d0c8e8e9532ee8a118abe7d8570762cd38be9818",
            configuration.transportSecurityFactory?.currentTransportSecurity()?.certificateFingerprintSha256,
        )
    }

    @Test
    fun qrPinnedHttpsConfigurationRequiresTlsContextSupport() {
        try {
            AndroidM0TransportConfigurationFactory.qrPinnedHttps(
                object : LocalCertificateProvider {
                    override fun currentCertificate() = descriptor()
                    override fun rotateCertificate() = descriptor()
                }
            )
            fail("Expected QR-pinned HTTPS config to require TLS context support")
        } catch (error: IllegalArgumentException) {
            assertTrue(error.message.orEmpty().contains("TLS server context"))
        }
    }

    private class FixedLocalCertificateProvider : LocalCertificateProvider, LocalServerTlsContextProvider {
        private val descriptor = LocalCertificateDescriptor(
            alias = "sharesync-local-transport",
            certificateDer = byteArrayOf(
                0x01,
                0x23,
                0x45,
                0x67,
                0x89.toByte(),
                0xab.toByte(),
                0xcd.toByte(),
                0xef.toByte(),
            ),
            notBefore = "2026-09-10T00:00:00Z",
            notAfter = "2027-09-10T00:00:00Z",
        )

        override fun currentCertificate(): LocalCertificateDescriptor = descriptor
        override fun rotateCertificate(): LocalCertificateDescriptor = descriptor
        override fun serverSSLContext(): SSLContext = SSLContext.getDefault()
    }

    private fun descriptor(): LocalCertificateDescriptor {
        return LocalCertificateDescriptor(
            alias = "sharesync-local-transport",
            certificateDer = byteArrayOf(0x01),
        )
    }
}
