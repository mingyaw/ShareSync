package com.sharesync.android.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DeviceCredentialStoreTest {
    @Test
    fun rotationAcceptsActiveAndPendingSecretsUntilCommit() {
        val secrets = ArrayDeque(listOf("secret-one", "secret-two"))
        val store = InMemoryDeviceCredentialStore { secrets.removeFirst() }
        val first = store.beginRotation("mac-001")
        store.commit(first)

        val second = store.beginRotation("mac-001")

        assertEquals(listOf("secret-one", "secret-two"), store.authorizationSecrets("mac-001"))
        store.commit(second)
        assertEquals(listOf("secret-two"), store.authorizationSecrets("mac-001"))
    }

    @Test
    fun cancelledFirstPairingReturnsDeviceToUnregisteredState() {
        val store = InMemoryDeviceCredentialStore { "pending-secret" }
        val rotation = store.beginRotation("mac-001")

        store.cancel(rotation)

        assertNull(store.authorizationSecrets("mac-001"))
    }

    @Test
    fun revokedDeviceHasNoAuthorizationSecretsOrBootstrapFallback() {
        val store = InMemoryDeviceCredentialStore { "device-secret" }
        store.commit(store.beginRotation("mac-001"))

        store.revoke("mac-001")

        assertEquals(emptyList<String>(), store.authorizationSecrets("mac-001"))
    }
}
