package com.sharesync.android.pairing

import com.sharesync.android.security.LocalCertificateProvider
import com.sharesync.android.sync.PairingTransportSecurity
import com.sharesync.android.sync.PairingTransportSecurityMode

class PairingTransportSecurityFactory(
    private val certificateProvider: LocalCertificateProvider,
) {
    fun currentTransportSecurity(): PairingTransportSecurity {
        val certificate = certificateProvider.currentCertificate()
        return PairingTransportSecurity(
            mode = PairingTransportSecurityMode.qr_pinned_https,
            certificateFingerprintSha256 = certificate.fingerprintSha256Hex,
            certificateFingerprintEncoding = "hex",
            certificateNotBefore = certificate.notBefore,
            certificateNotAfter = certificate.notAfter,
        )
    }
}
