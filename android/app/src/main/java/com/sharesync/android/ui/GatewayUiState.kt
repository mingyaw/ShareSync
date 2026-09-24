package com.sharesync.android.ui

import com.sharesync.android.sync.GatewayDevice

enum class GatewayUiStatus {
    ACTIVE,
    AVAILABLE,
    STALE,
    REPAIR_REQUIRED,
    REVOKED,
}

enum class GatewayRecency {
    JUST_NOW,
    TODAY,
    THIS_WEEK,
    OLDER,
}

data class GatewayUiItem(
    val deviceId: String,
    val displayName: String,
    val status: GatewayUiStatus,
    val recency: GatewayRecency,
    val canSelect: Boolean,
    val canRemove: Boolean,
)

fun buildGatewayUiItems(
    registered: List<GatewayDevice>,
    revoked: List<GatewayDevice>,
    activeDeviceId: String?,
    credentialSecrets: (String) -> List<String>?,
    nowEpochMillis: Long = System.currentTimeMillis(),
): List<GatewayUiItem> {
    val registeredItems = registered.map { device ->
        val secrets = credentialSecrets(device.deviceId)
        val status = when {
            secrets?.isEmpty() == true -> GatewayUiStatus.REVOKED
            device.deviceId == activeDeviceId -> GatewayUiStatus.ACTIVE
            secrets == null -> GatewayUiStatus.REPAIR_REQUIRED
            nowEpochMillis - device.lastSeenEpochMillis >= STALE_AFTER_MILLIS -> GatewayUiStatus.STALE
            else -> GatewayUiStatus.AVAILABLE
        }
        GatewayUiItem(
            deviceId = device.deviceId,
            displayName = device.displayName,
            status = status,
            recency = recency(device.lastSeenEpochMillis, nowEpochMillis),
            canSelect = status != GatewayUiStatus.ACTIVE && status != GatewayUiStatus.REVOKED,
            canRemove = secrets != null && status != GatewayUiStatus.REVOKED,
        )
    }
    val registeredIds = registered.mapTo(mutableSetOf(), GatewayDevice::deviceId)
    val revokedItems = revoked
        .filterNot { it.deviceId in registeredIds }
        .map { device ->
            GatewayUiItem(
                deviceId = device.deviceId,
                displayName = device.displayName,
                status = GatewayUiStatus.REVOKED,
                recency = recency(device.lastSeenEpochMillis, nowEpochMillis),
                canSelect = false,
                canRemove = false,
            )
        }

    return (registeredItems + revokedItems).sortedWith(
        compareBy<GatewayUiItem> { STATUS_ORDER.getValue(it.status) }
            .thenBy { it.displayName.lowercase() },
    )
}

private fun recency(lastSeenEpochMillis: Long, nowEpochMillis: Long): GatewayRecency {
    val age = (nowEpochMillis - lastSeenEpochMillis).coerceAtLeast(0L)
    return when {
        age < FIVE_MINUTES_MILLIS -> GatewayRecency.JUST_NOW
        age < ONE_DAY_MILLIS -> GatewayRecency.TODAY
        age < ONE_WEEK_MILLIS -> GatewayRecency.THIS_WEEK
        else -> GatewayRecency.OLDER
    }
}

private val STATUS_ORDER = mapOf(
    GatewayUiStatus.ACTIVE to 0,
    GatewayUiStatus.AVAILABLE to 1,
    GatewayUiStatus.STALE to 2,
    GatewayUiStatus.REPAIR_REQUIRED to 3,
    GatewayUiStatus.REVOKED to 4,
)

private const val FIVE_MINUTES_MILLIS = 5 * 60 * 1_000L
private const val ONE_DAY_MILLIS = 24 * 60 * 60 * 1_000L
private const val ONE_WEEK_MILLIS = 7 * ONE_DAY_MILLIS
private const val STALE_AFTER_MILLIS = 30 * ONE_DAY_MILLIS
