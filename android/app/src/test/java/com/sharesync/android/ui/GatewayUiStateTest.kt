package com.sharesync.android.ui

import com.sharesync.android.sync.GatewayDevice
import org.junit.Assert.assertEquals
import org.junit.Test

class GatewayUiStateTest {
    @Test
    fun activeGatewayIsFirstAndRevokedGatewayCannotBeSelected() {
        val now = 40L * DAY
        val items = buildGatewayUiItems(
            registered = listOf(
                GatewayDevice("ios-device-001", "iPhone", now - HOUR),
                GatewayDevice("mac-device-001", "Studio Mac", now - 2 * DAY),
            ),
            revoked = listOf(
                GatewayDevice("mac-device-old", "Old Mac", now - 60 * DAY),
            ),
            activeDeviceId = "mac-device-001",
            credentialSecrets = { id -> if (id == "mac-device-old") emptyList() else listOf("secret") },
            nowEpochMillis = now,
        )

        assertEquals(
            listOf(GatewayUiStatus.ACTIVE, GatewayUiStatus.AVAILABLE, GatewayUiStatus.REVOKED),
            items.map(GatewayUiItem::status),
        )
        assertEquals("mac-device-001", items.first().deviceId)
        assertEquals(false, items.last().canSelect)
        assertEquals(false, items.last().canRemove)
    }

    @Test
    fun staleAndLegacyGatewaysHaveDistinctActionableStates() {
        val now = 60L * DAY
        val items = buildGatewayUiItems(
            registered = listOf(
                GatewayDevice("ios-legacy", "Old iPhone", now - DAY),
                GatewayDevice("mac-stale", "Travel Mac", now - 31 * DAY),
            ),
            revoked = emptyList(),
            activeDeviceId = null,
            credentialSecrets = { id -> if (id == "ios-legacy") null else listOf("secret") },
            nowEpochMillis = now,
        )

        assertEquals(GatewayUiStatus.STALE, items[0].status)
        assertEquals(GatewayUiStatus.REPAIR_REQUIRED, items[1].status)
        assertEquals(true, items.all(GatewayUiItem::canSelect))
        assertEquals(false, items.first { it.deviceId == "ios-legacy" }.canRemove)
    }

    @Test
    fun recencyUsesStableProductBuckets() {
        val now = 10L * DAY
        val devices = listOf(
            GatewayDevice("now", "Now", now - MINUTE),
            GatewayDevice("today", "Today", now - HOUR),
            GatewayDevice("week", "Week", now - 3 * DAY),
            GatewayDevice("older", "Older", now - 8 * DAY),
        )

        val items = buildGatewayUiItems(
            registered = devices,
            revoked = emptyList(),
            activeDeviceId = null,
            credentialSecrets = { listOf("secret") },
            nowEpochMillis = now,
        ).associateBy(GatewayUiItem::deviceId)

        assertEquals(GatewayRecency.JUST_NOW, items.getValue("now").recency)
        assertEquals(GatewayRecency.TODAY, items.getValue("today").recency)
        assertEquals(GatewayRecency.THIS_WEEK, items.getValue("week").recency)
        assertEquals(GatewayRecency.OLDER, items.getValue("older").recency)
    }

    private companion object {
        const val MINUTE = 60 * 1_000L
        const val HOUR = 60 * MINUTE
        const val DAY = 24 * HOUR
    }
}
