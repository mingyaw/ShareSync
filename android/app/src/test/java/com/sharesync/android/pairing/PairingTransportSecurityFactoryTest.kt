package com.sharesync.android.pairing

import com.sharesync.android.security.LocalCertificateDescriptor
import com.sharesync.android.security.LocalCertificateProvider
import com.sharesync.android.sync.PairingTransportSecurityMode
import org.junit.Assert.assertEquals
import org.junit.Test

class PairingTransportSecurityFactoryTest {
    @Test
    fun currentTransportSecurityUsesCurrentCertificateFingerprintAndValidity() {
        val factory = PairingTransportSecurityFactory(
            certificateProvider = FixedLocalCertificateProvider(
                LocalCertificateDescriptor(
                    alias = "sharesync-local-transport",
                    certificateDer = byteArrayOf(0x01, 0x23, 0x45, 0x67, 0x89.toByte(), 0xab.toByte(), 0xcd.toByte(), 0xef.toByte()),
                    notBefore = "2026-09-09T00:00:00Z",
                    notAfter = "2027-09-09T00:00:00Z",
                )
            )
        )

        val security = factory.currentTransportSecurity()

        assertEquals(PairingTransportSecurityMode.qr_pinned_https, security.mode)
        assertEquals("hex", security.certificateFingerprintEncoding)
        assertEquals(
            "55c53f5d490297900cefa825d0c8e8e9532ee8a118abe7d8570762cd38be9818",
            security.certificateFingerprintSha256,
        )
        assertEquals("2026-09-09T00:00:00Z", security.certificateNotBefore)
        assertEquals("2027-09-09T00:00:00Z", security.certificateNotAfter)
    }

    private class FixedLocalCertificateProvider(
        private val descriptor: LocalCertificateDescriptor,
    ) : LocalCertificateProvider {
        override fun currentCertificate(): LocalCertificateDescriptor = descriptor
        override fun rotateCertificate(): LocalCertificateDescriptor = descriptor
    }
}
