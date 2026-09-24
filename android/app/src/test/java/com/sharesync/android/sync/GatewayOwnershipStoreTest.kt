package com.sharesync.android.sync

import org.junit.Assert.assertEquals
import org.junit.Test

class GatewayOwnershipStoreTest {
    @Test
    fun firstObservedDeviceBecomesActiveGateway() {
        val store = InMemoryGatewayOwnershipStore(clock = { 100L })

        store.observe("ios-local")

        assertEquals("ios-local", store.activeDeviceId())
        assertEquals(true, store.canSync("ios-local"))
        assertEquals(false, store.canSync("mac-device-001"))
    }

    @Test
    fun selectingObservedDeviceTransfersOwnership() {
        var now = 100L
        val store = InMemoryGatewayOwnershipStore(clock = { now })
        store.observe("ios-local")
        now = 200L
        store.observe("mac-device-001", "Studio Mac")

        store.select("mac-device-001")

        assertEquals("mac-device-001", store.activeDeviceId())
        assertEquals(false, store.canSync("ios-local"))
        assertEquals(true, store.canSync("mac-device-001"))
        assertEquals("Studio Mac", store.devices().first().displayName)
    }

    @Test(expected = IllegalArgumentException::class)
    fun cannotSelectUnknownDevice() {
        InMemoryGatewayOwnershipStore().select("unknown")
    }

    @Test
    fun gatewayOwnershipIsIndependentFromSyncHistoryReset() {
        val gatewayStore = InMemoryGatewayOwnershipStore()
        val resultStore = InMemorySyncResultStore()
        gatewayStore.observe("ios-local")
        gatewayStore.observe("mac-device-001", "Studio Mac")
        gatewayStore.select("mac-device-001")

        com.sharesync.android.SuspendBridge.runBlocking { resultStore.clear() }

        assertEquals("mac-device-001", gatewayStore.activeDeviceId())
        assertEquals(2, gatewayStore.devices().size)
    }
}
