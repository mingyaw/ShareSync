package com.sharesync.android.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class LocalCertificateProviderTest {
    @Test
    fun fingerprintUsesLowercaseSha256HexOfCertificateDer() {
        val descriptor = LocalCertificateDescriptor(
            alias = "sharesync-local-transport",
            certificateDer = byteArrayOf(0x01, 0x23, 0x45, 0x67, 0x89.toByte(), 0xab.toByte(), 0xcd.toByte(), 0xef.toByte()),
        )

        assertEquals(
            "55c53f5d490297900cefa825d0c8e8e9532ee8a118abe7d8570762cd38be9818",
            descriptor.fingerprintSha256Hex,
        )
    }

    @Test
    fun descriptorRejectsEmptyCertificateDer() {
        assertThrows(IllegalArgumentException::class.java) {
            LocalCertificateDescriptor(alias = "sharesync-local-transport", certificateDer = byteArrayOf())
        }
    }

    @Test
    fun descriptorRejectsBlankAlias() {
        assertThrows(IllegalArgumentException::class.java) {
            LocalCertificateDescriptor(alias = " ", certificateDer = byteArrayOf(0x01))
        }
    }
}
